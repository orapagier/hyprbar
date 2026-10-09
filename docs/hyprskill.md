# Hyprskill: machine context for coding agents

[Hyprskill](skills/hyprskill/SKILL.md) teaches local agents where to inspect this
Arch/Hyprland/Quickshell desktop, including requests that only say “my machine”
or “my bar”. Its short entrypoint loads detailed desktop and machine references
only when relevant, reducing repeated discovery and context use. It contains a
profile of ramlej's laptop; other users should replace that profile with their
own verified facts.

Open **Hyprshell Settings → Hyprskill → Install Hyprskill**, then restart your
agents. The button uses the recorded checkout location and reports errors without
replacing existing custom skills.

Alternatively, run once from any directory, using the checkout's actual path:

```bash
python3 ~/repos/hyprshell/tools/install_hyprskill.py --dry-run
python3 ~/repos/hyprshell/tools/install_hyprskill.py
```

This creates global symlinks for Codex at `~/.agents/skills/hyprskill` and Claude
Code at `~/.claude/skills/hyprskill`. OpenCode also discovers those directories;
it needs no third copy. To install for OpenCode alone, use `--agent opencode`
(native target `${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills/hyprskill`).
Use repeated `--agent` flags to choose other combinations. Avoid installing
multiple copies of the same skill unnecessarily. Existing unrelated skills are
never replaced. To uninstall, remove only the symlinks created by this installer.
Keep the checkout available; links follow edits immediately. If you move the
checkout, remove the old links and rerun the installer from the new location.

These locations follow the documented global discovery rules for
[Codex](https://learn.chatgpt.com/docs/build-skills),
[Claude Code](https://code.claude.com/docs/en/skills), and
[OpenCode](https://opencode.ai/docs/skills/), checked 2026-10-09.
Restart the agent after installing so it discovers the skill. Local skills do
not automatically transfer to remote/cloud sessions. Sandboxed agents may be
unable to write global agent directories; run the installer in a normal terminal.

Automatic selection is enabled through the skill description, but selection
still depends on the agent and its configuration. Verify discovery with Codex's
skill selector, Claude Code's `/hyprskill`, or OpenCode's skill tool. A useful
smoke prompt from outside this repo is: “Where would you change my laptop's
monitor scale, and which files would you check before editing?” The answer
should identify live Lua config, its GUI override, the repository pointer, and
the separate checkout copy. If selection misses, invoke `hyprskill` explicitly.

No large global instruction file is installed, so unrelated tasks incur only
skill discovery metadata rather than the full system profile. Other agents
supporting Agent Skills can load the same folder; agents without skill discovery
need a pointer in their own global instructions to its absolute `SKILL.md` path.

The skill lives under `docs/`, already included in Hyprshell's GitHub sync
allowlist. Installing it does not run desktop setup, change the desktop, or push
to GitHub. Update the machine reference after verified hardware/setup changes;
avoid storing credentials or private logs. The initial inspection verified files,
packages, hardware, and native dependencies; sandbox restrictions prevented live
Hyprland IPC and D-Bus service checks.
