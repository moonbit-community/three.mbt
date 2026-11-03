#!/usr/bin/env python3
"""Applies each bug alone to src/addons/{utils,environments}, runs the harness that should
catch it (the CPU records, run.mjs, or the mock-GPU scenarios, gpu/run.mjs), reports
caught/missed and restores the file (diff/lib/inject.py).
    python3 inject.py [index ...]
    INJECT_DRY_RUN=1 python3 inject.py   # only check that every pattern still occurs
"""
import subprocess, sys, pathlib
sys.path.insert(0, str(next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'lib/env.py').exists())))
from lib.inject import patched, DRY_RUN  # noqa: E402

H = pathlib.Path(__file__).resolve().parent
R = 'src/addons/'
CPU = ['node', '--import', './register.mjs', 'run.mjs']


def gpu():
    subprocess.run(['moon', 'build', '--target', 'js'], cwd=H / 'mbt', capture_output=True)
    return subprocess.run(['node', 'run.mjs'], cwd=H / 'gpu', capture_output=True, text=True)


BUGS = [
  ('sort: insertion compare not strict', 'utils/sort_utils.mbt', 'fn(a, b) { a > b }', 'fn(a, b) { a >= b }', 'cpu'),
  ('sort: digit shift by 4 per depth', 'utils/sort_utils.mbt', '(3 - depth) << SORT_UTILS_POWER', '(3 - depth) << 2', 'cpu'),
  ('kelvin: blue log offset', 'utils/color_utils.mbt', 'color_utils_log(temp - 10.0)', 'color_utils_log(temp - 1.0)', 'cpu'),
  ('hilbert3d: permutation of octant 6', 'utils/geometry_utils.mbt', '..h(vec[6], v4, v3, v2, v5, v6, v1, v0, v7)', '..h(vec[6], v4, v3, v2, v5, v6, v1, v7, v0)', 'cpu'),
  ('gosper: y sign', 'utils/geometry_utils.mbt', 'curr_y += -size * geometry_utils_sin(angle)', 'curr_y += size * geometry_utils_sin(angle)', 'cpu'),
  ('sortInstancedMesh: color written at ref index', 'utils/scene_utils.mbt', 'let offset = i * instance_color.item_size', 'let offset = ref_index * instance_color.item_size', 'cpu'),
  ('traverse: visibility check in plain traversal', 'utils/scene_utils.mbt', 'if visible_only && frame.object.visible == false {', 'if frame.object.visible == false {', 'cpu'),
  ('reduceVertices: skinned check -> mesh check', 'utils/scene_utils.mbt', 'if !child.is_skinned_mesh() {', 'if child.is_mesh() {', 'cpu'),
  ('RoomEnvironment: -z panel position sign', 'environments/room_environment.mbt', '(3.235, 11.486, -12.541)', '(3.235, 11.486, 12.541)', 'cpu'),
  ('RoomEnvironment: area light material per panel shared', 'environments/room_environment.mbt', 'light(17.0,', 'light(71.0,', 'cpu'),
  ('environments: dispose without the Set', 'environments/debug_environment.mbt', '    if !seen {\n      resources.push(resource)\n    }', '    ignore(seen)\n    resources.push(resource)', 'cpu'),
  ('decompress: uv not flipped', 'utils/web_gpu_texture_utils.mbt', '@nodes.uv().flip_y()', '@nodes.uv()', 'gpu'),
  ('decompress: renderer disposed synchronously', 'utils/web_gpu_texture_utils.mbt', 'web_gpu_texture_utils_after_ticks(3, fn() { r.dispose() })', 'r.dispose()', 'gpu'),
  ('RoomEnvironment: box material shares room material (PMREM)', 'environments/room_environment.mbt', 'material=Single(box_material),', 'material=Single(room_material),', 'gpu'),
]

only = [int(a) for a in sys.argv[1:]]
for k, (name, f, old, new, kind) in enumerate(BUGS):
    if only and k not in only:
        continue
    with patched(R + f, old, new):
        if DRY_RUN:
            print(f'{k:2} pattern found: {name}')
            continue
        r = subprocess.run(CPU, cwd=H, capture_output=True, text=True) if kind == 'cpu' else gpu()
    out = r.stdout + r.stderr
    bad = [l for l in out.split('\n') if l.startswith(('MISMATCH', 'MISSING', 'DIFF', 'FAIL'))]
    print(f'{k:2} {"CAUGHT" if r.returncode != 0 else "MISSED"} {name}: {"; ".join(b[:90] for b in bad[:3])}', flush=True)
if not DRY_RUN:
    subprocess.run(['moon', 'build', '--target', 'js'], cwd=H / 'mbt', capture_output=True)
