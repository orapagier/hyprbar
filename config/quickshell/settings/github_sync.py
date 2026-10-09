#!/usr/bin/env python3
"""Snapshot the live desktop into its checkout and push without rewriting history."""
import argparse
from datetime import datetime
import fcntl
import fnmatch
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys

FORK_URL = 'https://github.com/orapagier/hyprshell/fork'


def git(repo, *args):
    env = dict(os.environ, GIT_TERMINAL_PROMPT='0', GCM_INTERACTIVE='never')
    env.setdefault('GIT_SSH_COMMAND', 'ssh -oBatchMode=yes -oConnectTimeout=15')
    result = subprocess.run(['git', '-C', str(repo), *args], capture_output=True,
                            text=True, env=env, timeout=120)
    if result.returncode:
        raise RuntimeError((result.stderr or result.stdout).strip() or 'Git command failed')
    return result.stdout.strip()


def excluded(name):
    return name in ('__pycache__', '.git', 'audio-spectrum') or any(
        fnmatch.fnmatch(name, pattern) for pattern in ('*.pyc', '*.pyo', '*.bak*', '*.log', '.DS_Store'))


def mirror(source, destination):
    if source.resolve() == destination.resolve():
        return
    if source.is_symlink():
        raise RuntimeError(f'Cannot sync symbolic link: {source}')
    if source.is_dir():
        if destination.is_symlink() or (destination.exists() and not destination.is_dir()):
            raise RuntimeError(f'Conflicting destination: {destination}')
        destination.mkdir(parents=True, exist_ok=True)
        names = {p.name for p in source.iterdir() if not excluded(p.name)}
        for child in destination.iterdir():
            if child.name not in names and not excluded(child.name):
                if child.is_dir() and not child.is_symlink():
                    shutil.rmtree(child)
                else:
                    child.unlink()
        for name in sorted(names):
            mirror(source / name, destination / name)
    else:
        if not source.is_file() or destination.is_symlink():
            raise RuntimeError(f'Cannot sync file: {source}')
        shutil.copy2(source, destination)


def sync(repo, config, target, slug):
    repo = repo.resolve()
    if Path(git(repo, 'rev-parse', '--show-toplevel')).resolve() != repo:
        raise RuntimeError('Choose the root of the Hyprshell Git checkout.')
    git(repo, 'var', 'GIT_AUTHOR_IDENT')
    git(repo, 'var', 'GIT_COMMITTER_IDENT')
    branch = git(repo, 'symbolic-ref', '--quiet', '--short', 'HEAD')
    gitdir = Path(git(repo, 'rev-parse', '--absolute-git-dir'))
    with (gitdir / 'hyprshell-sync.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('Another GitHub sync is already running.')
        if any((gitdir / name).exists() for name in ('MERGE_HEAD', 'CHERRY_PICK_HEAD', 'rebase-merge', 'rebase-apply')):
            raise RuntimeError('Finish the current Git merge or rebase before syncing.')
        if git(repo, 'diff', '--cached', '--name-only'):
            raise RuntimeError('Commit or unstage your staged changes before syncing.')
        for name in ('hypr', 'quickshell'):
            if not (config / name).is_dir():
                raise RuntimeError(f'Missing live config: {config / name}')
        for name in ('hypr', 'quickshell'):
            mirror(config / name, repo / 'config' / name)
        paths = ['config/hypr', 'config/quickshell']
        settings = config / 'hyprshell/settings.json'
        if settings.exists():
            from backend import validate
            data = validate(json.loads(settings.read_text()))
            settings_target = repo / 'config/hyprshell/settings.json'
            settings_target.parent.mkdir(parents=True, exist_ok=True)
            settings_target.write_text(json.dumps(data, indent=2) + '\n')
            paths.append('config/hyprshell/settings.json')
        # Publish the project that installs the snapshot as well as live configs.
        # Keep this explicit so unrelated files in the checkout stay private.
        project_paths = ('config', 'bin', 'assets', 'tools', 'tests', 'docs',
                         '.github', '.gitignore', 'README.md', 'setup.sh',
                         'packages.txt', 'packages-apps.txt', 'packages-fallback.txt')
        tracked = git(repo, 'ls-files', '-z').split('\0')
        paths = [path for path in project_paths
                 if (repo / path).exists() or any(
                     name == path or name.startswith(path + '/') for name in tracked)]
        git(repo, 'add', '-A', '--', *paths)
        if git(repo, 'diff', '--cached', '--name-only'):
            git(repo, 'commit', '-m', 'Sync Hyprshell desktop ' + datetime.now().isoformat(timespec='seconds'))
        pushed = git(repo, 'push', '--porcelain', target, f'HEAD:refs/heads/{branch}')
        if any(line.startswith('=\t') for line in pushed.splitlines()):
            return 'Nothing to sync now.'
    return f'Synced to {slug} ({branch}).'


def identity(repo, name, email):
    name, email = name.strip(), email.strip()
    if not name or len(name) > 200 or any(c in name for c in '\r\n<>'):
        raise ValueError('Enter your commit name or GitHub username.')
    if len(email) > 254 or '@' not in email or any(c.isspace() or c in '<>' for c in email):
        raise ValueError('Enter a valid commit email (your GitHub noreply email also works).')
    git(repo, 'config', '--local', 'user.name', name)
    git(repo, 'config', '--local', 'user.email', email)


def api(endpoint, missing_ok=False):
    result = subprocess.run(['gh', 'api', '--hostname', 'github.com', endpoint],
                            capture_output=True, text=True, timeout=30)
    if result.returncode:
        if missing_ok and '(HTTP 404)' in result.stderr:
            return None
        raise RuntimeError(result.stderr.strip() or 'Could not contact GitHub. Authenticate and try again.')
    return json.loads(result.stdout)


def discover():
    if not shutil.which('gh'):
        return {'ok': True, 'ready': False, 'message': 'Click Authenticate to sign in to GitHub.'}
    user = api('user')
    login, user_id = user['login'], user['id']
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9-]*', login) or type(user_id) is not int:
        raise ValueError('GitHub returned an invalid account.')
    slug = login + '/hyprshell'
    result = {'ok': True, 'ready': False, 'login': login, 'repository': slug,
              'name': login, 'email': f'{user_id}+{login}@users.noreply.github.com'}
    repository = api('repos/' + slug, missing_ok=True)
    if repository is None:
        result.update(forkUrl=FORK_URL, createUrl=f'https://github.com/new?name=hyprshell&owner={login}',
                      message=f'{slug} was not found. Fork Hyprshell or create an empty repository named hyprshell in your account, then click Check again.')
    elif repository.get('full_name', '').lower() != slug.lower():
        result['message'] = f'{slug} was renamed. Fork or create a repository named hyprshell in your account, then check again.'
    elif not repository.get('permissions', {}).get('push') or repository.get('archived'):
        result['message'] = f'Your account cannot push to {slug}. Check repository permissions and authentication.'
    else:
        result.update(ready=True, target=f'https://github.com/{slug}.git',
                      message=f'Signed in as {login}. Ready to sync to {slug}.')
    return result


def login_terminal():
    try:
        if not shutil.which('gh'):
            print('GitHub CLI is needed for browser authentication.')
            if input('Install github-cli with pacman now? [y/N] ').lower() != 'y':
                return 1
            subprocess.run(['sudo', 'pacman', '-S', '--needed', 'github-cli'], check=True)
        subprocess.run(['gh', 'auth', 'login', '--hostname', 'github.com', '--git-protocol', 'https', '--web'], check=True)
        subprocess.run(['gh', 'auth', 'setup-git', '--hostname', 'github.com'], check=True)
        print('Authenticated. Return to Hyprshell and click Sync.')
        input('Press Enter to close…')
        return 0
    except (OSError, subprocess.SubprocessError, EOFError) as error:
        print('Authentication failed:', error)
        try:
            input('Press Enter to close…')
        except EOFError:
            pass
        return 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--status', action='store_true')
    parser.add_argument('--authenticate', action='store_true')
    parser.add_argument('--login-terminal', action='store_true')
    args = parser.parse_args()
    if args.login_terminal:
        return login_terminal()
    home = Path.home()
    state = Path(os.environ.get('XDG_STATE_HOME') or home / '.local/state') / 'hyprshell'
    config = Path(os.environ.get('XDG_CONFIG_HOME') or home / '.config')
    try:
        pointer = state / 'repository'
        repo = Path(pointer.read_text().strip()) if pointer.exists() else home / 'repos/hyprshell'
        if args.status:
            result = discover()
        elif args.authenticate:
            terminal = subprocess.run(['kitty', '--wait', '--title', 'Hyprshell GitHub authentication',
                            sys.executable, str(Path(__file__).resolve()), '--login-terminal'],
                            capture_output=True, text=True, timeout=900)
            if terminal.returncode:
                raise RuntimeError(terminal.stderr.strip() or 'Could not complete the authentication window.')
            if not shutil.which('gh'):
                raise RuntimeError('Authentication was not completed. Click Authenticate and finish GitHub CLI setup.')
            status = subprocess.run(['gh', 'auth', 'status', '--hostname', 'github.com'],
                                    capture_output=True, text=True, timeout=20)
            if status.returncode:
                raise RuntimeError('GitHub sign-in was not completed. Click Authenticate to retry.')
            result = discover()
        else:
            result = discover()
            if result['ready']:
                identity(repo, result['name'], result['email'])
                result['message'] = sync(repo, config, result['target'], result['repository'])
            else:
                result['ok'] = False
        print(json.dumps(result))
        return 0 if result['ok'] else 1
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(json.dumps({'ok': False, 'message': str(error)}))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
