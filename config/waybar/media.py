#!/usr/bin/env python3
"""Waybar: output-monitor spectrum and a scrolling title from active players."""
from array import array
import ctypes
from ctypes.util import find_library
import html
import json
import math
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
import unicodedata
from urllib.parse import unquote, urlparse

import gi
gi.require_version("Playerctl", "2.0")
from gi.repository import Gio, GLib, Playerctl

SAMPLE_RATE = 16000
SAMPLE_COUNT = 1024
BAR_COUNT = 8
GLYPHS = "▁▂▃▄▅▆▇█"


def clean(value):
    return " ".join("".join(c for c in str(value or "") if c >= " " or c.isspace()).split())


def media_title(metadata, player_name):
    title = clean(metadata.get("xesam:title"))
    if not title and metadata.get("xesam:url"):
        title = clean(Path(unquote(urlparse(metadata["xesam:url"]).path)).name)
    artist = metadata.get("xesam:artist", [])
    if isinstance(artist, (list, tuple)):
        artist = ", ".join(clean(item) for item in artist if clean(item))
    else:
        artist = clean(artist)
    return f"{artist} — {title}" if artist and title else title or clean(player_name) or "Media playing"


def clusters(text):
    result = []
    for char in text:
        if result and (unicodedata.combining(char) or char == "\ufe0f" or char == "\u200d" or result[-1].endswith("\u200d")):
            result[-1] += char
        else:
            result.append(char)
    return result


def columns(cluster):
    return max((2 if unicodedata.east_asian_width(c) in "WF" else 1
                for c in cluster if not unicodedata.combining(c) and c not in "\ufe0f\u200d"), default=0)


class Marquee:
    def __init__(self, width=28):
        self.width = width
        self.key = None
        self.started = 0.0

    def frame(self, key, title, now):
        if key != self.key:
            self.key, self.started = key, now
        chars = clusters(title)
        if sum(map(columns, chars)) <= self.width:
            return title
        ring = chars + list("   •   ")
        # Pause at the beginning of each cycle; advance one character per 0.3s.
        cycle = 2.0 + len(ring) * 0.3
        elapsed = max(0.0, now - self.started) % cycle
        offset = max(0, int((elapsed - 2.0) / 0.3)) if elapsed >= 2.0 else 0
        result, used = [], 0
        for index in range(len(ring)):
            char = ring[(offset + index) % len(ring)]
            width = columns(char)
            if used + width > self.width:
                break
            result.append(char)
            used += width
        return "".join(result) + " " * (self.width - used)


class Spectrum:
    """Native FFTW transform with logarithmic frequency bands and smooth decay."""
    def __init__(self):
        self.library = ctypes.CDLL(find_library("fftw3") or "libfftw3.so.3")
        pointer = ctypes.POINTER(ctypes.c_double)
        self.library.fftw_plan_dft_r2c_1d.argtypes = [ctypes.c_int, pointer, pointer, ctypes.c_uint]
        self.library.fftw_plan_dft_r2c_1d.restype = ctypes.c_void_p
        self.library.fftw_execute.argtypes = [ctypes.c_void_p]
        self.library.fftw_execute.restype = None
        self.library.fftw_destroy_plan.argtypes = [ctypes.c_void_p]
        self.library.fftw_destroy_plan.restype = None
        self.input = (ctypes.c_double * SAMPLE_COUNT)()
        self.output = (ctypes.c_double * ((SAMPLE_COUNT // 2 + 1) * 2))()
        self.plan = self.library.fftw_plan_dft_r2c_1d(SAMPLE_COUNT, self.input, self.output, 64)
        if not self.plan:
            raise RuntimeError("Could not create audio spectrum transform")
        self.window = [0.5 - 0.5 * math.cos(math.tau * i / (SAMPLE_COUNT - 1)) for i in range(SAMPLE_COUNT)]
        edges = [40 * (7000 / 40) ** (i / BAR_COUNT) for i in range(BAR_COUNT + 1)]
        self.bands = [(max(1, int(a * SAMPLE_COUNT / SAMPLE_RATE)),
                       max(2, int(b * SAMPLE_COUNT / SAMPLE_RATE))) for a, b in zip(edges, edges[1:])]
        self.levels = [0.0] * BAR_COUNT
        self.reference = 0.02

    def frame(self, pcm):
        values = array("h")
        values.frombytes(pcm[-SAMPLE_COUNT * 2:])
        if sys.byteorder != "little":
            values.byteswap()
        if len(values) != SAMPLE_COUNT:
            return "▁" * BAR_COUNT, False
        rms = math.sqrt(sum(v * v for v in values) / SAMPLE_COUNT) / 32768
        for i, value in enumerate(values):
            self.input[i] = value / 32768 * self.window[i]
        self.library.fftw_execute(self.plan)
        magnitudes = [max(math.hypot(self.output[2 * k], self.output[2 * k + 1])
                          for k in range(start, max(start + 1, end))) * 4 / SAMPLE_COUNT
                      for start, end in self.bands]
        self.reference = max(0.01, max(magnitudes), self.reference * 0.985)
        for i, magnitude in enumerate(magnitudes):
            target = min(1.0, (magnitude / self.reference) ** 0.65) if rms > 0.00015 else 0.0
            self.levels[i] = max(target, self.levels[i] * 0.72)
        return "".join(GLYPHS[min(7, int(level * 7.99))] for level in self.levels), rms > 0.00015

    def close(self):
        if self.plan:
            self.library.fftw_destroy_plan(self.plan)
            self.plan = None


class Media:
    def __init__(self):
        self.loop = GLib.MainLoop()
        self.spectrum = Spectrum()
        self.marquee = Marquee()
        self.manager = Playerctl.PlayerManager()
        self.manager.connect("name-appeared", self.add_player)
        self.recency = {}
        for name in self.manager.props.player_names:
            self.add_player(self.manager, name)
        self.capture = None
        self.watch = None
        self.default_sink = None
        self.route_query = None
        self.retry_at = 0.0
        self.buffer = bytearray()
        self.received_at = 0.0
        self.sounded_at = -math.inf
        self.fallback_at = -math.inf
        self.fallback = ("Audio playing", "System audio")
        self.previous = None

    def add_player(self, manager, name):
        try:
            player = Playerctl.Player.new_from_name(name)
            player.connect("metadata", self.player_changed)
            player.connect("playback-status", self.player_changed)
            manager.manage_player(player)
            self.player_changed(player)
        except GLib.Error as error:
            print(f"Media player unavailable: {error}", file=sys.stderr)

    def player_changed(self, player, *_):
        if player.props.playback_status == Playerctl.PlaybackStatus.PLAYING:
            self.recency[player.props.player_instance] = time.monotonic()

    def active_player(self):
        players = [p for p in self.manager.props.players
                   if p.props.playback_status == Playerctl.PlaybackStatus.PLAYING]
        return max(players, key=lambda p: self.recency.get(p.props.player_instance, 0), default=None)

    def start_capture(self, now):
        if self.capture is not None or now < self.retry_at:
            return
        self.retry_at = now + 5
        try:
            # Monitor speaker output, never microphone input. Pulse compatibility
            # also works with PipeWire. @DEFAULT_MONITOR@ selects speaker output.
            self.capture = subprocess.Popen([
                "parec", f"--device={self.default_sink + '.monitor' if self.default_sink else '@DEFAULT_MONITOR@'}", "--format=s16le",
                f"--rate={SAMPLE_RATE}", "--channels=1", "--raw",
                "--latency-msec=80", "--process-time-msec=50",
                "--client-name=Waybar media visualizer",
            ], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            os.set_blocking(self.capture.stdout.fileno(), False)
            self.watch = GLib.io_add_watch(self.capture.stdout.fileno(),
                                          GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, self.read_audio)
        except OSError as error:
            print(f"Audio monitor unavailable: {error}", file=sys.stderr)
            self.stop_capture()

    def check_output(self):
        # Reattach when headphones/Bluetooth become the default output. Query
        # asynchronously so server startup or a slow response cannot freeze text.
        if self.route_query is None:
            try:
                self.route_query = Gio.Subprocess.new(
                    ["pactl", "get-default-sink"], Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE)
                self.route_query.communicate_utf8_async(None, None, self.output_changed)
            except GLib.Error:
                self.route_query = None
        return True

    def output_changed(self, process, result):
        self.route_query = None
        try:
            _, output, _ = process.communicate_utf8_finish(result)
            sink = output.strip()
            if process.get_successful() and sink and sink != self.default_sink:
                self.default_sink = sink
                self.stop_capture()
                self.retry_at = 0.0
        except GLib.Error:
            pass

    def stop_capture(self):
        if self.watch is not None:
            GLib.source_remove(self.watch)
            self.watch = None
        if self.capture is not None:
            self.capture.terminate()
            try:
                self.capture.wait(timeout=1)
            except subprocess.TimeoutExpired:
                self.capture.kill()
                self.capture.wait()
            self.capture.stdout.close()
            self.capture = None
        self.buffer.clear()

    def read_audio(self, fd, condition):
        if condition & (GLib.IO_HUP | GLib.IO_ERR):
            self.watch = None
            self.stop_capture()
            return False
        try:
            chunk = os.read(fd, 65536)
        except BlockingIOError:
            return True
        if not chunk:
            self.watch = None
            self.stop_capture()
            return False
        self.buffer.extend(chunk)
        del self.buffer[:-SAMPLE_COUNT * 2]
        self.received_at = time.monotonic()
        return True

    def audio_title(self, now):
        if now - self.fallback_at < 2:
            return self.fallback
        self.fallback_at = now
        self.fallback = ("Audio playing", "System audio")
        try:
            result = subprocess.run(["pactl", "--format=json", "list", "sink-inputs"],
                                    capture_output=True, text=True, check=True, timeout=1)
            streams = [s for s in json.loads(result.stdout) if not s.get("corked") and not s.get("mute")]
            if streams:
                props = streams[-1].get("properties", {})
                app = clean(props.get("application.name")) or "System audio"
                title = clean(props.get("media.name"))
                if title in ("", "AudioStream", "Playback Stream", "audio stream"):
                    title = app
                self.fallback = (title, app)
        except (OSError, ValueError, subprocess.SubprocessError):
            pass
        return self.fallback

    def emit(self, payload):
        if payload != self.previous:
            print(json.dumps(payload, ensure_ascii=False), flush=True)
            self.previous = payload

    def tick(self):
        now = time.monotonic()
        self.start_capture(now)
        pcm = bytes(self.buffer) if now - self.received_at < 0.4 else bytes(SAMPLE_COUNT * 2)
        bars, sounded = self.spectrum.frame(pcm)
        if sounded:
            self.sounded_at = now
        player = self.active_player()
        if player is not None:
            source = clean(player.props.player_name)
            title = media_title(player.props.metadata.unpack(), source)
            key = (player.props.player_instance, title)
        elif now - self.sounded_at < 1.0:
            title, source = self.audio_title(now)
            key = (source, title)
        else:
            self.marquee.key = None
            self.emit({"text": "", "tooltip": "", "class": "idle"})
            return True
        title_frame = html.escape(self.marquee.frame(key, title, now))
        text = (f'<span foreground="#94e2d5">{bars}</span>  '
                f'<span foreground="#cba6f7">{title_frame}</span>')
        self.emit({"text": text, "tooltip": html.escape(f"{title}\n{source}"), "class": "playing"})
        return True

    def run(self):
        for signum in (signal.SIGTERM, signal.SIGINT):
            GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signum, self.quit)
        self.tick()
        self.check_output()
        GLib.timeout_add(67, self.tick)
        GLib.timeout_add_seconds(3, self.check_output)
        try:
            self.loop.run()
        finally:
            self.stop_capture()
            if self.route_query is not None:
                self.route_query.force_exit()
            self.spectrum.close()

    def quit(self):
        self.loop.quit()
        return False


if __name__ == "__main__":
    try:
        Media().run()
    except BrokenPipeError:
        raise SystemExit(0)
    except (GLib.Error, OSError, RuntimeError) as error:
        print(f"Waybar media: {error}", file=sys.stderr)
        raise SystemExit(1)
