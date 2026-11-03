#!/usr/bin/env python3
"""Injects plausible bugs into the objects add-ons (src/addons/objects) one at a time, runs
the harness that should catch each (classic mock-GL scenario, a6 shader records, or the
mock-GPU scenario), records whether it did, and restores the file (diff/lib/inject.py).
    python3 inject.py [index ...]
    INJECT_DRY_RUN=1 python3 inject.py   # only check that every pattern still occurs
Results also go to OUT/addons_objects/inject_results.json.
"""
import json, subprocess, sys, pathlib
sys.path.insert(0, str(next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'lib/env.py').exists())))
from lib.env import DIFF, out_dir  # noqa: E402
from lib.inject import patched, DRY_RUN  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
R = 'src/addons/objects/'
BUGS = [
  ('reflector.mbt', '  e[8] *= -1.0\n', '', 'webgl:a6_reflector', 'Reflector: view offset not mirrored (elements[8])'),
  ('reflector.mbt', '    pe[14] = self.clip_plane.w - 1.0\n', '    pe[14] = self.clip_plane.w\n', 'webgl:a6_reflector', 'Reflector: orthographic oblique plane constant without -1'),
  ('refractor.mbt', '  self.plane_normal.negate() |> ignore\n', '', 'webgl:a6_refractor', 'Refractor: clip plane normal not flipped'),
  ('refractor.mbt', '  self.visible_view.dot(self.visible_normal) < 0.0\n', '  self.visible_view.dot(self.visible_normal) > 0.0\n', 'webgl:a6_refractor', 'Refractor: visible() true from behind'),
  ('water.mbt', '  self.eye.set_from_matrix_position(camera.matrix_world) |> ignore\n', '', 'webgl:a6_sky_water', 'Water: eye uniform not updated'),
  ('water2.mbt', '  config.x += self.flow_speed * delta // flowMapOffset0\n', '  config.x += self.flow_speed * delta * 2.0 // flowMapOffset0\n', 'webgl:a6_water2', 'Water2: flow advances twice as fast'),
  ('lensflare.mbt', '  let vec_y = -self.position_screen.y * 2.0\n', '  let vec_y = self.position_screen.y * 2.0\n', 'webgl:a6_lensflare', 'Lensflare: element offset y sign'),
  ('sky.mbt', '    ("mieDirectionalG", { value: Number(0.8), }),\n', '    ("mieDirectionalG", { value: Number(0.08), }),\n', 'webgl:a6_sky_water', 'Sky: mieDirectionalG default'),
  ('marching_cubes.mbt', '  if field2 < isol {\n    cubeindex = cubeindex | 8\n  }\n  if field3 < isol {\n    cubeindex = cubeindex | 4\n  }\n', '  if field2 < isol {\n    cubeindex = cubeindex | 4\n  }\n  if field3 < isol {\n    cubeindex = cubeindex | 8\n  }\n', 'webgl:a6_misc_objects', 'MarchingCubes: corner bits 2/3 swapped'),
  ('marching_cubes.mbt', '                    count += 1\n                    val += intensity * (val2 - val) / count.to_double()\n', '                    val += intensity * (val2 - val) / count.to_double()\n                    count += 1\n', 'webgl:a6_misc_objects', 'MarchingCubes: blur count incremented after use'),
  ('shadow_mesh.mbt', '  sme[13] = -light_position4d.y * -plane.constant\n', '  sme[13] = light_position4d.y * -plane.constant\n', 'webgl:a6_misc_objects', 'ShadowMesh: matrix element 13 sign'),
  ('grounded_skybox.mbt', '      let y1 = -height * 3.0 / 2.0\n', '      let y1 = -height * 2.0 / 3.0\n', 'webgl:a6_misc_objects', 'GroundedSkybox: floor transition height'),
  ('sky_mesh.mbt', '@nodes.exp(sky.sun_position.y().div(450000.0))', '@nodes.exp(sky.sun_position.y().div(45000.0))', 'shader', 'SkyMesh: sun fade constant'),
  ('water_mesh.mbt', '@nodes.div(offset, -19)', '@nodes.div(offset, 19)', 'shader', 'WaterMesh: noise uv1 scroll sign'),
  ('water2_mesh.mbt', '    flow.x().mul_assign(-1)\n', '', 'shader', 'Water2Mesh: flow x not negated'),
  ('water2_mesh.mbt', '  config.z = self._half_cycle\n', '', 'gpu:water2_mesh', 'Water2Mesh: flowConfig.z (halfCycle) never set'),
  ('lensflare_mesh.mbt', '  pixels.y = viewport.y -\n', '  pixels.y = viewport.y +\n', 'gpu:lensflare_mesh', 'LensflareMesh: copy rectangle y sign (WebGPU y-down)'),
  ('lensflare_mesh.mbt', '  material2.depth_test = false\n', '  material2.depth_test = true\n', 'gpu:lensflare_mesh', 'LensflareMesh: element material depth-tested'),
  ('water_mesh.mbt', '      = water.resolution_scale\n', '      = 1.0\n', 'gpu:water_mesh', 'WaterMesh: reflector resolutionScale ignored'),
  ('sky_mesh.mbt', '  material.depth_write = false\n', '', 'gpu:sky_mesh', 'SkyMesh: depthWrite left on'),
]


def run(check):
    if check.startswith('webgl:'):
        r = subprocess.run(['node', 'harness/run_diff.mjs', check[6:]], cwd=DIFF / 'core/webgl', capture_output=True, text=True)
    elif check == 'shader':
        r = subprocess.run(['node', 'shader_cmp.mjs'], cwd=HERE, capture_output=True, text=True)
    else:
        b = subprocess.run(['moon', 'build', '--target', 'js'], cwd=HERE / 'mbt', capture_output=True, text=True)
        if b.returncode != 0:
            return False, 'build failed'
        r = subprocess.run(['node', 'run.mjs', check[4:]], cwd=HERE / 'gpu', capture_output=True, text=True)
    out = (r.stdout + r.stderr).strip().split('\n')
    return r.returncode != 0, [l for l in out if l.startswith(('MISMATCH', 'DIFF', 'MISSING', 'FAIL', 'ok')) or 'identical' in l][:3]


idx = [int(a) for a in sys.argv[1:]] or range(len(BUGS))
results = []
for i in idx:
    f, old, new, check, what = BUGS[i]
    with patched(R + f, old, new):
        if DRY_RUN:
            print(f'{i:2} pattern found: {what}')
            continue
        caught, detail = run(check)
    results.append((i, what, check, caught, detail))
    print(f'{i:2} {"CAUGHT" if caught else "MISSED"} {what} [{check}] {detail}', flush=True)
if not DRY_RUN:
    subprocess.run(['moon', 'build', '--target', 'js'], cwd=HERE / 'mbt', capture_output=True)
    json.dump(results, open(out_dir('addons_objects') / 'inject_results.json', 'w'), indent=1)
