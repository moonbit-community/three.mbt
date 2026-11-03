#!/usr/bin/env python3
"""A5 bug injection in A5's own utils/math files and CameraUtils: each bug is applied to the
real file, then the shader group `utils` (diff/core/webgpu/shader_diff/run_a5.mjs) or the
CameraUtils comparison (camera_utils/compare.sh) runs, and the file is restored.
    python3 inject_shader.py [index ...]
    INJECT_DRY_RUN=1 python3 inject_shader.py   # only check that every pattern still occurs
"""
import subprocess, sys, pathlib
sys.path.insert(0, str(next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'lib/env.py').exists())))
from lib.env import DIFF, REPO  # noqa: E402
from lib.inject import patched, DRY_RUN  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
H = DIFF / 'core/webgpu/shader_diff'
BUGS = [
  ('src/addons/tsl/utils_specular_helpers.mbt', '@nodes.float(0.298475)', '@nodes.float(0.29847)', 'utils', 'specular dominant factor constant'),
  ('src/addons/tsl/utils_specular_helpers.mbt', 'let ay = a.to_var()\n', 'let ay = ax.to_var()\n', 'utils', 'GGX ay aliases ax (extra var)'),
  ('src/addons/tsl/utils_taa_utils.mbt', '.add(1.0e-7)', '.add(1.0e-6)', 'utils', 'clipAABB epsilon'),
  ('src/addons/tsl/utils_taa_utils.mbt', 'for y in -1..=1 {', 'for y in -1..<1 {', 'utils', 'depth neighbourhood misses a row'),
  ('src/addons/tsl/utils_r_noise.mbt', '.mul(0.7548776662)', '.mul(0.754877666)', 'utils', 'R2 offset constant'),
  ('src/addons/tsl/math_curl_noise.mbt', '@nodes.mul(0.142857142857, d.wyz())', '@nodes.mul(0.14285714285, d.wyz())', 'utils', 'simplex ns constant'),
  ('src/addons/tsl/utils_grounded_skybox.mbt', '@nodes.float(1.0e6)', '@nodes.float(1.0e5)', 'utils', 'disk intersection far value'),
  ('src/addons/tsl/math_bayer.mbt', '.mul(17.0)', '.mul(16.0)', 'utils', 'Bayer approximation factor'),
  ('src/addons/utils/camera_utils.mbt', '(r + l) / (r - l),', '(r - l) / (r + l),', 'camera', 'frameCorners off-axis term'),
  ('src/addons/utils/camera_utils.mbt', 'camera_utils_js_min(1.0, p.aspect)', 'camera_utils_js_min(2.0, p.aspect)', 'camera', 'frustum estimate clamp'),
]
only = [int(a) for a in sys.argv[1:]]
for i, (f, old, new, kind, desc) in enumerate(BUGS):
    if only and i not in only:
        continue
    src = (REPO / f).read_text()
    if src.count(old) != 1:
        print(f'[{i}] SKIP {f}: pattern found {src.count(old)} times')
        continue
    with patched(f, old, new):
        if DRY_RUN:
            print(f'[{i}] pattern found: {desc}')
            continue
        if kind == 'utils':
            r = subprocess.run(['node', 'run_a5.mjs', '--group', 'utils'], cwd=H, capture_output=True, text=True)
            caught = r.returncode != 0
        else:
            r = subprocess.run(['bash', str(HERE / 'camera_utils/compare.sh')], capture_output=True, text=True)
            caught = r.returncode != 0
    last = r.stdout.strip().split('\n')[-1] if r.stdout.strip() else ''
    print(f'[{i}] {"CAUGHT" if caught else "MISSED"} {f.split("/")[-1]}: {desc} -> {last}', flush=True)
