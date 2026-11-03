#!/usr/bin/env python3
# A4 ao-group bug injection (GTAO, SSGI, SSS, godrays): one bug at a time, runs the shader
# harness (group ao) and every A4 mock-GPU scenario, reports whether each was caught; the
# file is restored after each (diff/lib/inject.py).
#   python3 diff/addons/tsl/a4/inject_ao.py [index ...]   (INJECT_DRY_RUN=1: check patterns)
import pathlib, subprocess, sys
sys.path.insert(0, str(next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'lib/env.py').exists())))
from lib.env import REPO, DIFF  # noqa: E402
from lib.inject import patched, DRY_RUN  # noqa: E402
TSL = 'src/addons/tsl/'                   # the A4 sources (repo-relative)
SD = DIFF / 'core/webgpu/shader_diff'     # run_a4.mjs --group <g>: WGSL/GLSL byte-diff
G9 = DIFF / 'core/g9'                     # mbt/ (MoonBit side) and harness/run_a4.mjs: mock GPU
bugs = [
  ('display_gtao_node.mbt', 'if samples < 30 { 3.0 } else { 5.0 }', 'if samples < 30 { 5.0 } else { 3.0 }', 'GTAO direction count swapped'),
  ('display_gtao_node.mbt', '_gtao_node_temporal_rotations[frame_id % 6] / 360.0', '_gtao_node_temporal_rotations[frame_id % 6] / 180.0', 'GTAO temporal rotation divisor'),
  ('display_gtao_node.mbt', 'data.set(inx * 4 + 2, 127)', 'data.set(inx * 4 + 2, 128)', 'GTAO noise texture blue channel'),
  ('display_gtao_node.mbt', '.select(@nodes.float(1), else_node=@nodes.float(-1))', '.select(@nodes.float(-1), else_node=@nodes.float(1))', 'GTAO sign of nSin swapped'),
  ('display_ssgi_node.mbt', 'use_temporal_filtering: true,', 'use_temporal_filtering: false,', 'SSGI temporal filtering default'),
  ('display_ssgi_node.mbt', '      2\n    ) *\n    0.5,', '      2\n    ) *\n    1.0,', 'SSGI halfProjScale factor'),
  ('display_ssgi_node.mbt', '@nodes.uint(32).sub(max_ray).add(max_ray.sub(angle_horizon_int))', '@nodes.uint(32).sub(max_ray).add(angle_horizon_int)', 'SSGI bitfield shift'),
  ('display_sss_node.mbt', '.or(xy.y().greater_than(self._resolution.y()))', '.or(xy.y().greater_than(self._resolution.x()))', 'SSS screen bound uses x'),
  ('display_sss_node.mbt', 'a4_set_uniform_number(self._temporal_offset, 0)', 'a4_set_uniform_number(self._temporal_offset, 0.5)', 'SSS temporal offset when off'),
  ('display_godrays_node.mbt', 'constants.array[i] = Number(plane.constant)\n', 'constants.array[i] = Number(-plane.constant)\n', 'Godrays point-light plane constant sign'),
  ('display_godrays_node.mbt', '@nodes.vec2_of([result.one_minus().add(0.005), view_z.negate()])', '@nodes.vec2_of([result.one_minus().add(0.05), view_z.negate()])', 'Godrays point shadow bias'),
  ('display_godrays_node.mbt', 'resolution_scale: 0.5,', 'resolution_scale: 1.0,', 'Godrays default resolution scale'),
]
only = [int(a) for a in sys.argv[1:]]
for i, (f, old, new, desc) in enumerate(bugs):
    if only and i not in only: continue
    src = (REPO / TSL / f).read_text()
    assert src.count(old) == 1, (desc, src.count(old))
    with patched(TSL + f, old, new):
        if DRY_RUN:
            print(f'{i:2} pattern ok: {desc}'); continue
        subprocess.run(['moon', 'build', '--target', 'js'], cwd=G9 / 'mbt', capture_output=True)
        sh = subprocess.run(['node', 'run_a4.mjs', '--group', 'ao'], cwd=SD, capture_output=True, text=True).stdout
        mk = subprocess.run(['node', 'run_a4.mjs', '--quiet'], cwd=G9 / 'harness', capture_output=True, text=True).stdout
        shs = ([l for l in sh.splitlines() if 'identical' in l] or ['(no shader summary)'])[-1]
        mks = ([l for l in mk.splitlines() if 'identical' in l] or ['(no mock summary)'])[-1]
        caught = ('0 different' not in shs) or ('failed' in mks)
        print(f'{i:2} {"CAUGHT" if caught else "MISSED"}  {desc}: shader [{shs}] mock [{mks}]', flush=True)
if not DRY_RUN: subprocess.run(['moon', 'build', '--target', 'js'], cwd=G9 / 'mbt', capture_output=True)
