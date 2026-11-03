"""Bug injection helpers: patch a repository file, run a harness, restore the file.

Every bug-injection script under diff/ edits the real files of the repository through
`patched()` and nothing else, so the original is restored on success, on an exception,
on Ctrl-C and on SIGTERM. Each original is also copied to OUT/inject_backup first; if a
run is killed hard (SIGKILL, power loss), restore with

    python3 diff/lib/inject.py --restore

Usage in a script (see any diff/**/inject*.py):

    from lib.inject import patched, run
    with patched('src/addons/tsl/display_fxaa_node.mbt', 'Number(1.5),', 'Number(1.25),'):
        out = run(['node', 'shader_diff/run.mjs', 'a4_fxaa'], cwd=DIFF / 'core/webgpu')
"""
import contextlib
import json
import os
import shutil
import signal
import subprocess
import sys
from pathlib import Path

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from lib.env import REPO, OUT  # noqa: E402

BACKUP = OUT / 'inject_backup'
# INJECT_DRY_RUN=1: patched() only checks that each pattern still occurs (no file is
# written) and run() returns '' without running anything. Use it to validate a script.
DRY_RUN = os.environ.get('INJECT_DRY_RUN') == '1'
MANIFEST = BACKUP / 'manifest.json'


def _load():
    try:
        return json.loads(MANIFEST.read_text())
    except (OSError, ValueError):
        return {}


def _save(m):
    BACKUP.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(m, indent=1))


def _resolve(path):
    p = Path(path)
    return p if p.is_absolute() else REPO / p


def restore_all():
    """Restores every file a killed run left patched. Returns the restored paths."""
    m = _load()
    done = []
    for target, saved in m.items():
        shutil.copyfile(saved, target)
        done.append(target)
    _save({})
    return done


class InjectionNotApplied(Exception):
    pass


def _raise_interrupt(signum, frame):
    raise KeyboardInterrupt


@contextlib.contextmanager
def patched(path, old, new, count=1):
    """Replaces `old` by `new` in `path` (repo-relative or absolute) for the duration
    of the block. `count` occurrences are replaced (0: all); `old` must occur."""
    target = _resolve(path)
    original = target.read_bytes()
    text = original.decode('utf8')
    if old not in text:
        raise InjectionNotApplied(f'{path}: pattern not found: {old[:80]!r}')
    if DRY_RUN:
        yield target
        return
    patched_text = text.replace(old, new) if count == 0 else text.replace(old, new, count)
    BACKUP.mkdir(parents=True, exist_ok=True)
    saved = BACKUP / (str(target.relative_to(REPO)).replace('/', '__') if target.is_relative_to(REPO) else target.name)
    m = _load()
    outer = str(target) in m  # nested patch of the same file: keep the first original
    if not outer:
        saved.write_bytes(original)
        m[str(target)] = str(saved)
        _save(m)
    prev = signal.signal(signal.SIGTERM, _raise_interrupt)
    try:
        target.write_text(patched_text, encoding='utf8')
        yield target
    finally:
        target.write_bytes(original)
        if not outer:
            m = _load()
            m.pop(str(target), None)
            _save(m)
        signal.signal(signal.SIGTERM, prev)


def run(cmd, cwd=None, timeout=3600, env=None, shell=False):
    """Runs a harness command; returns stdout+stderr (never raises on a non-zero exit)."""
    return run_rc(cmd, cwd, timeout, env, shell)[1]


def run_rc(cmd, cwd=None, timeout=3600, env=None, shell=False):
    """Like run(), but returns (exit code, stdout+stderr); the code is None on a timeout."""
    if DRY_RUN:
        return 0, ''
    e = dict(os.environ)
    if env:
        e.update(env)
    try:
        r = subprocess.run(cmd, cwd=cwd, env=e, shell=shell, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout or '') + (r.stderr or '')
    except subprocess.TimeoutExpired as err:
        return None, f'TIMEOUT after {timeout}s\n' + str(err.stdout or '')


if __name__ == '__main__':
    if '--restore' in sys.argv:
        restored = restore_all()
        print('\n'.join(restored) if restored else 'nothing to restore')
    else:
        print(__doc__)
