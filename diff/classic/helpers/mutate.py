# Injects one deliberate bug at a time into src/helpers (the real repository files, through
# diff/lib/inject.py, which restores each file), rebuilds, runs the diff.
# Usage: python3 mutate.py   (INJECT_DRY_RUN=1 only checks that every pattern applies)
import subprocess, pathlib, sys
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(next(p for p in HERE.parents if (p / 'lib/env.py').exists())))
from lib.inject import patched, run, DRY_RUN  # noqa: E402
MUTANTS = [
  ('arrow threshold', 'arrow_helper.mbt', 'if dir.y > 0.99999 {', 'if dir.y > 0.9999 {'),
  ('arrow Math.max -> min', 'arrow_helper.mbt', 'helpers_math_max(0.0001, length - head_length)', '(length - head_length)'),
  ('grid k = i * step', 'grid_helper.mbt', '    k += step\n', '    k = -half_size + i.to_double() * step\n'),
  ('polar sector parity', 'polar_grid_helper.mbt', '      let color = if (i & 1) != 0 { color1 } else { color2 }\n      push_color(color)', '      let color = if (i & 1) == 0 { color1 } else { color2 }\n      push_color(color)'),
  ('box helper fresh box', 'box_helper.mbt', '  if payload.object is Some(object) {\n    ignore(@core.box3_set_from_object(_box_helper_box, object))\n  }', '  ignore(_box_helper_box.make_empty())\n  if payload.object is Some(object) {\n    ignore(@core.box3_set_from_object(_box_helper_box, object))\n  }'),
  ('box3 no half scale', 'box3_helper.mbt', 'object.scale.multiply_scalar(0.5)', 'object.scale.multiply_scalar(1.0)'),
  ('camera webgpu near', 'camera_helper.mbt', '(0.0, 1.0)\n', '(-1.0, 1.0)\n'),
  ('camera colors off by one', 'camera_helper.mbt', 'for i in 24..<32 {', 'for i in 23..<32 {'),
  ('camera reversed ignored', 'camera_helper.mbt', 'if camera.reversed_depth() {', 'if false {'),
  ('dir dispose once', 'directional_light_helper.mbt', '  geometry_of(self.target_line).dispose()\n  material_of(self.target_line).dispose()', '  geometry_of(self.target_line).dispose()'),
  ('dir scale before lookAt', 'directional_light_helper.mbt', 'payload.target_line.scale.z = _directional_light_helper_v3.length()', 'payload.target_line.scale.z = _directional_light_helper_v3.length_sq()'),
  ('hemi half <=', 'hemisphere_light_helper.mbt', 'if i.to_double() < l.to_double() / 2.0 {', 'if i.to_double() <= l.to_double() / 2.0 {'),
  ('hemi no negate', 'hemisphere_light_helper.mbt', '    .set_from_matrix_position(light.matrix_world)\n    .negate(),', '    .set_from_matrix_position(light.matrix_world),'),
  ('point no needs_update', 'point_light_helper.mbt', '  helper.matrix_world_needs_update = true\n', ''),
  ('spot NaN distance truthy', 'spot_light_helper.mbt', 'distance != 0.0 && distance == distance', 'distance != 0.0'),
  ('spot ignore parent', 'spot_light_helper.mbt', '  match helper.parent {', '  match (None : @core.Object3D?) {'),
  ('plane translate sign', 'plane_helper.mbt', 'object.translate_z(-plane.constant)', 'object.translate_z(plane.constant)'),
  ('plane super first', 'plane_helper.mbt', '  ignore(object.position.set(0.0, 0.0, 0.0))\n  ignore(object.scale.set(0.5 * self.size, 0.5 * self.size, 1.0))\n  object.look_at(plane.normal)\n  ignore(object.translate_z(-plane.constant))\n  object.update_matrix_world_kind(force)', '  object.update_matrix_world_kind(force)\n  ignore(object.position.set(0.0, 0.0, 0.0))\n  ignore(object.scale.set(0.5 * self.size, 0.5 * self.size, 1.0))\n  object.look_at(plane.normal)\n  ignore(object.translate_z(-plane.constant))'),
  ('skeleton any parent', 'skeleton_helper.mbt', '  for bone in bones {\n    if bone.parent is Some(parent) && parent.is_bone() {\n      for _ in 0..<6', '  for bone in bones {\n    if bone.parent is Some(_) {\n      for _ in 0..<6'),
  ('skeleton parent end swap', 'skeleton_helper.mbt', 'parent.matrix_world,\n', 'bone.matrix_world,\n'),
  ('axes color offset', 'axes_helper.mbt', '  to_array(9)\n', '  to_array(8)\n'),
]
results = []
for name, file, old, new in MUTANTS:
    with patched('src/helpers/' + file, old, new):
        if DRY_RUN:
            results.append((name, 'pattern ok'))
            continue
        build = subprocess.run(['moon', 'build', '--target', 'js'], cwd=HERE, capture_output=True, text=True)
        if build.returncode != 0:
            results.append((name, 'BUILD FAILED'))
            continue
        r = subprocess.run(['node', 'run_diff.mjs', '--show', '1'], cwd=HERE, capture_output=True, text=True)
        first = [l for l in r.stdout.splitlines() if l.startswith('  mbt:')]
        results.append((name, ('DETECTED ' + (first[0].strip()[:110] if first else '')) if r.returncode != 0 else 'MISSED'))
for name, r in results:
    print(f'{name:28} {r}')
if not DRY_RUN:
    run(['moon', 'build', '--target', 'js'], cwd=HERE)
    print(subprocess.run(['node', 'run_diff.mjs'], cwd=HERE, capture_output=True, text=True).stdout.splitlines()[-1])
