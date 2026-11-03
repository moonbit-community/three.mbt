#!/usr/bin/env python3
"""One ad-hoc bug in an A5 file, the shader group that covers it, then the file restored
(replaces the old linject.py / simple_tools/inject.sh, which patched mirror copies).
    python3 inject_one.py <group> <file under src/addons/tsl> <old> <new>
    e.g. python3 inject_one.py lighting lighting_tiled_lights_node.mbt '.mul(2)' '.mul(3)'
Groups: those of diff/core/webgpu/shader_diff/run_a5.mjs (simple, lighting, passes,
temporal, utils). Exit status 0 when the bug was caught.
"""
import subprocess, sys, pathlib
sys.path.insert(0, str(next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'lib/env.py').exists())))
from lib.env import DIFF, REPO  # noqa: E402
from lib.inject import patched, DRY_RUN  # noqa: E402

H = DIFF / 'core/webgpu/shader_diff'
if len(sys.argv) != 5:
    sys.exit(__doc__)
group, f, old, new = sys.argv[1:]
with patched('src/addons/tsl/' + f, old, new):
    if DRY_RUN:
        print('pattern found')
        sys.exit(0)
    r = subprocess.run(['node', 'run_a5.mjs', '--group', group], cwd=H, capture_output=True, text=True)
out = r.stdout + r.stderr
for line in out.split('\n'):
    if line.startswith(('MISMATCH', 'MISSING')) or 'identical' in line or 'exited' in line:
        print(line[:200])
print('CAUGHT' if r.returncode != 0 else 'MISSED')
sys.exit(0 if r.returncode != 0 else 1)
