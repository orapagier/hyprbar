/* In-memory brightness sampling; no images or window titles leave this process.
 * Wire layouts: wlr-screencopy v1 and hyprland-toplevel-export v1.
 * https://github.com/swaywm/wlr-protocols
 * https://github.com/hyprwm/hyprland-protocols
 */
#define _GNU_SOURCE
#include <wayland-client.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <limits.h>

static const struct wl_interface screen_frame, window_frame;
static const struct wl_interface *screen_capture_types[] = {&screen_frame, NULL, &wl_output_interface};
static const struct wl_interface *region_types[] = {&screen_frame, NULL, &wl_output_interface, NULL, NULL, NULL, NULL};
static const struct wl_interface *window_capture_types[] = {&window_frame, NULL, NULL};
static const struct wl_interface *copy_types[] = {&wl_buffer_interface, NULL};
static const struct wl_message screen_requests[] = {
    {"capture_output", "nio", screen_capture_types},
    {"capture_output_region", "nioiiii", region_types}, {"destroy", "", NULL}
};
static const struct wl_message window_requests[] = {
    {"capture_toplevel", "niu", window_capture_types}, {"destroy", "", NULL}
};
static const struct wl_message screen_copy[] = {{"copy", "o", copy_types}, {"destroy", "", NULL}};
static const struct wl_message window_copy[] = {{"copy", "oi", copy_types}, {"destroy", "", NULL}};
static const struct wl_message screen_events[] = {
    {"buffer", "uuuu", NULL}, {"flags", "u", NULL},
    {"ready", "uuu", NULL}, {"failed", "", NULL}
};
static const struct wl_message window_events[] = {
    {"buffer", "uuuu", NULL}, {"damage", "uuuu", NULL}, {"flags", "u", NULL},
    {"ready", "uuu", NULL}, {"failed", "", NULL},
    {"linux_dmabuf", "uuu", NULL}, {"buffer_done", "", NULL}
};
static const struct wl_interface screen_manager = {"zwlr_screencopy_manager_v1", 1, 3, screen_requests, 0, NULL};
static const struct wl_interface window_manager = {"hyprland_toplevel_export_manager_v1", 1, 2, window_requests, 0, NULL};
static const struct wl_interface screen_frame = {"zwlr_screencopy_frame_v1", 1, 2, screen_copy, 4, screen_events};
static const struct wl_interface window_frame = {"hyprland_toplevel_export_frame_v1", 1, 2, window_copy, 7, window_events};

static struct wl_shm *shm;
static struct wl_proxy *screen_mgr, *window_mgr;
static struct wl_output *output;
static const char *output_name;
static int done, failed, window_mode, inverted;
static uint32_t width, height, stride, format;
static void *pixels;
static struct wl_buffer *capture_buffer;
static size_t bytes;
static double crop[4] = {0, 0, 1, 1};

static void output_geometry(void *d, struct wl_output *o, int32_t x, int32_t y,
    int32_t pw, int32_t ph, int32_t subpixel, const char *make, const char *model, int32_t transform) {}
static void output_mode(void *d, struct wl_output *o, uint32_t f, int32_t w, int32_t h, int32_t r) {}
static void output_done(void *d, struct wl_output *o) {}
static void output_scale(void *d, struct wl_output *o, int32_t factor) {}
static void output_description(void *d, struct wl_output *o, const char *s) {}
static void output_named(void *d, struct wl_output *o, const char *name) {
    if (output_name && !strcmp(name, output_name)) output = o;
}
static const struct wl_output_listener output_listener = {
    output_geometry, output_mode, output_done, output_scale, output_named, output_description
};
static void registry_global(void *d, struct wl_registry *reg, uint32_t id, const char *name, uint32_t version) {
    if (!strcmp(name, "wl_shm")) shm = wl_registry_bind(reg, id, &wl_shm_interface, 1);
    else if (!strcmp(name, screen_manager.name)) screen_mgr = wl_registry_bind(reg, id, &screen_manager, 1);
    else if (!strcmp(name, window_manager.name)) window_mgr = wl_registry_bind(reg, id, &window_manager, 1);
    else if (!strcmp(name, "wl_output") && version >= 4) {
        struct wl_output *o = wl_registry_bind(reg, id, &wl_output_interface, 4);
        wl_output_add_listener(o, &output_listener, NULL);
    }
}
static void registry_removed(void *d, struct wl_registry *reg, uint32_t id) {}
static const struct wl_registry_listener registry_listener = {registry_global, registry_removed};
static void buffer_event(void *d, struct wl_proxy *f, uint32_t fmt, uint32_t w, uint32_t h, uint32_t s) {
    format = fmt; width = w; height = h; stride = s;
    /* Only accept the usual little-endian 8-bit RGB(A) formats. */
    if ((fmt != 0 && fmt != 1 && fmt != 0x34324241 && fmt != 0x34324258) ||
        !w || !h || w > 32768 || h > 32768 || s < (uint64_t)w * 4 ||
        (uint64_t)s * h > 256 * 1024 * 1024) { failed = done = 1; return; }
    bytes = (size_t)s * h;
    int fd = memfd_create("hyprbar-brightness", MFD_CLOEXEC);
    if (fd < 0 || ftruncate(fd, bytes)) { if (fd >= 0) close(fd); failed = done = 1; return; }
    pixels = mmap(NULL, bytes, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (pixels == MAP_FAILED) { close(fd); failed = done = 1; return; }
    struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, (int)bytes);
    capture_buffer = wl_shm_pool_create_buffer(pool, 0, w, h, s, fmt);
    wl_shm_pool_destroy(pool); close(fd);
    if (!window_mode) wl_proxy_marshal_flags(f, 0, NULL, 1, 0, capture_buffer);
}
static void flags_event(void *d, struct wl_proxy *f, uint32_t flags) { inverted = flags & 1; }
static void ready_event(void *d, struct wl_proxy *f, uint32_t hi, uint32_t lo, uint32_t ns) { done = 1; }
static void failed_event(void *d, struct wl_proxy *f) { failed = done = 1; }
static void damage_event(void *d, struct wl_proxy *f, uint32_t x, uint32_t y, uint32_t w, uint32_t h) {}
static void dmabuf_event(void *d, struct wl_proxy *f, uint32_t fmt, uint32_t w, uint32_t h) {}
static void buffer_done_event(void *d, struct wl_proxy *f) {
    if (!done && capture_buffer) wl_proxy_marshal_flags(f, 0, NULL, 1, 0, capture_buffer, 1);
}
static void (*screen_listener[])(void) = {
    (void (*)(void))buffer_event, (void (*)(void))flags_event,
    (void (*)(void))ready_event, (void (*)(void))failed_event
};
static void (*window_listener[])(void) = {
    (void (*)(void))buffer_event, (void (*)(void))damage_event,
    (void (*)(void))flags_event, (void (*)(void))ready_event, (void (*)(void))failed_event,
    (void (*)(void))dmabuf_event, (void (*)(void))buffer_done_event
};

static int brightness(void) {
    int x0 = window_mode ? crop[0] * width : 0;
    int y0 = window_mode ? crop[1] * height : 0;
    int x1 = window_mode ? (crop[0] + crop[2]) * width : (int)width;
    int y1 = window_mode ? (crop[1] + crop[3]) * height : (int)height;
    if (x0 < 0) x0 = 0;
    if (y0 < 0) y0 = 0;
    if (x1 > (int)width) x1 = width;
    if (y1 > (int)height) y1 = height;
    if (x1 <= x0 || y1 <= y0) return -1;
    unsigned histogram[256] = {0}, count = 0;
    int sx = (x1 - x0) / 64 + 1, sy = (y1 - y0) / 64 + 1;
    for (int y = y0; y < y1; y += sy) for (int x = x0; x < x1; x += sx) {
        uint32_t p;
        memcpy(&p, (uint8_t *)pixels + (inverted ? height - 1 - y : (uint32_t)y) * stride + x * 4, 4);
        unsigned r = (p >> 16) & 255, g = (p >> 8) & 255, b = p & 255;
        if (format == 0x34324241 || format == 0x34324258) { unsigned t = r; r = b; b = t; }
        /* Transparent windows may expose a bright wallpaper. SHM ARGB/ABGR
         * channels are premultiplied; composite over white conservatively. */
        if (format == 0 || format == 0x34324241) {
            unsigned transparent = 255 - (p >> 24);
            r += transparent; g += transparent; b += transparent;
            if (r > 255) r = 255;
            if (g > 255) g = 255;
            if (b > 255) b = 255;
        }
        /* Max channel conservatively covers saturated backdrops as well. */
        unsigned value = r > g ? r : g;
        if (b > value) value = b;
        histogram[value]++; count++;
    }
    unsigned accumulated = 0;
    for (unsigned i = 0; i < 256; ++i) {
        accumulated += histogram[i];
        if (accumulated * 100 >= count * 99) return i;
    }
    return -1;
}

int main(int argc, char **argv) {
    if (argc != 7 || (strcmp(argv[1], "screen") && strcmp(argv[1], "window"))) return 2;
    alarm(2); /* The Python caller also enforces a shorter deadline. */
    window_mode = !strcmp(argv[1], "window");
    if (!window_mode) output_name = argv[2];
    for (int i = 0; i < 4; ++i) {
        char *end;
        crop[i] = strtod(argv[3 + i], &end);
        if (end == argv[3 + i] || *end || !(crop[i] >= 0) || crop[i] > (window_mode ? 1 : 32768)) return 2;
    }
    if (crop[2] <= 0 || crop[3] <= 0) return 2;
    struct wl_display *display = wl_display_connect(NULL);
    if (!display) return 1;
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    if (wl_display_roundtrip(display) < 0 || wl_display_roundtrip(display) < 0 || !shm) return 1;
    struct wl_proxy *frame;
    if (window_mode && window_mgr) {
        char *end;
        uint32_t handle = (uint32_t)strtoull(argv[2], &end, 16);
        if (*end) return 2;
        frame = wl_proxy_marshal_flags(window_mgr, 0, &window_frame, 1, 0, NULL, 0, handle);
    } else if (!window_mode && screen_mgr && output) {
        frame = wl_proxy_marshal_flags(screen_mgr, 1, &screen_frame, 1, 0, NULL, 0, output,
            (int)crop[0], (int)crop[1], (int)crop[2], (int)crop[3]);
    } else return 1;
    wl_proxy_add_listener(frame, window_mode ? window_listener : screen_listener, NULL);
    while (!done) if (wl_display_dispatch(display) < 0) return 1;
    if (failed || !pixels || pixels == MAP_FAILED) return 1;
    int level = brightness();
    if (level < 0) return 1;
    printf("%d\n", level);
    munmap(pixels, bytes);
    wl_display_disconnect(display);
    return 0;
}
