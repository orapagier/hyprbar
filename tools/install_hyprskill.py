#!/usr/bin/env python3
"""Link the repo skill into global agent discovery paths without replacing files."""
import argparse
import os
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--agent', action='append', choices=['codex', 'claude', 'opencode'],
                        help='repeat to select agents; default: codex + claude (also discovered by OpenCode)')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1] / 'docs/skills/hyprskill'
    if not (source / 'SKILL.md').is_file():
        parser.error(f'Missing skill: {source}')
    home = Path.home()
    config = Path(os.environ.get('XDG_CONFIG_HOME') or home / '.config')
    targets = {'codex': home / '.agents/skills/hyprskill',
               'claude': home / '.claude/skills/hyprskill',
               'opencode': config / 'opencode/skills/hyprskill'}
    selected = [targets[name] for name in dict.fromkeys(args.agent or ['codex', 'claude'])]
    # Check all conflicts before making any changes. Never overwrite local skills.
    for target in selected:
        if os.path.lexists(target) and not (target.is_symlink() and target.resolve() == source):
            parser.error(f'Refusing to replace existing skill: {target}')
    for target in selected:
        if target.is_symlink():
            print(f'Already linked: {target}')
        elif args.dry_run:
            print(f'Would link: {target} -> {source}')
        else:
            try:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.symlink_to(source, target_is_directory=True)
            except OSError as exc:
                parser.exit(1, f'Cannot install {target}: {exc}\nRun this command in your normal terminal if agent configuration is protected.\n')
            print(f'Linked: {target} -> {source}')


if __name__ == '__main__':
    main()
