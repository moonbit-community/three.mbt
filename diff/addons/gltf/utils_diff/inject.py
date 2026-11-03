# Bug injection: applies each mutation to the port, rebuilds the harness, runs it,
# restores the file. `python3 inject.py [index ...]`.
import subprocess, sys, re, pathlib
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(next(p for p in HERE.parents if (p / 'lib/env.py').exists())))
from lib.env import REPO  # noqa: E402
from lib.inject import patched, DRY_RUN  # noqa: E402
# INJECT_DRY_RUN=1 only checks that every pattern applies; after a hard kill,
# `python3 diff/lib/inject.py --restore` restores the patched file.
SRC = 'src/addons/utils/'
H = HERE
BUGS = [
  ('mergeVertices hashes with floor instead of Math.trunc', 'buffer_geometry_utils.mbt',
   '            bgu_math_trunc(\n              bgu_get(attribute, k, index)', '            Double::floor(\n              bgu_get(attribute, k, index)'),
  ('mergeAttributes drops gpuType', 'buffer_geometry_utils.mbt',
   '    result.gpu_type = gpu_type\n', '    ignore(gpu_type)\n'),
  ('toTrianglesDrawMode strip keeps winding on odd triangles', 'buffer_geometry_utils.mbt',
   '          new_indices.push(index.get_x(i + 2))\n          new_indices.push(index.get_x(i + 1))\n          new_indices.push(index.get_x(i))\n',
   '          new_indices.push(index.get_x(i))\n          new_indices.push(index.get_x(i + 1))\n          new_indices.push(index.get_x(i + 2))\n'),
  ('computeMorphedAttributes absolute morph not relative to base', 'buffer_geometry_utils.mbt',
   's.morph_a.add_scaled_vector(s.temp_a.sub(s.v_a), influence)', 's.morph_a.add_scaled_vector(s.temp_a, influence)'),
  ('toCreasedNormals uses >= for the crease test', 'buffer_geometry_utils.mbt',
   'if nx * ox + ny * oy + nz * oz > crease_dot {', 'if nx * ox + ny * oy + nz * oz >= crease_dot {'),
  ('remapAttribute does not share interleaved buffer copies', 'buffer_geometry_utils.mbt',
   '          buffers.set(source, data)\n', '          ignore(buffers)\n'),
  ('retarget skips the hip influence on z', 'skeleton_utils.mbt',
   '      e[14] *= options.scale * options.hip_influence.z\n', '      e[14] *= options.scale\n'),
  ('retarget hipPosition not scaled', 'skeleton_utils.mbt',
   '        e[14] += hip_position.z * options.scale\n', '        e[14] += hip_position.z\n'),
  ('retargetClip drops the last-frame epsilon', 'skeleton_utils.mbt',
   'ignore(mixer.update(delta - 0.0000001))', 'ignore(mixer.update(delta))'),
  ('clone does not copy bindMatrix (redundant with Object3D.copy upstream too)', 'skeleton_utils.mbt',
   '    ignore(cloned_mesh.bind_matrix.copy(source_mesh.bind_matrix))\n', ''),
  ('clone keeps the source bones', 'skeleton_utils.mbt',
   '        Some(cloned) => cloned\n', '        Some(_) => bone\n'),
  ('clone binds without the bind matrix (recomputes inverses)', 'skeleton_utils.mbt',
   '    node.bind(skeleton, bind_matrix=cloned_mesh.bind_matrix)', '    node.bind(skeleton)'),
  ('mergeGeometries group offset not advanced', 'buffer_geometry_utils.mbt',
   '      offset += count\n    }\n  }\n  // merge indices', '      offset += 0\n    }\n  }\n  // merge indices'),
  ('mergeGroups sorts by start only', 'buffer_geometry_utils.mbt',
   '    if a.material_index != b.material_index {', '    if false {'),
  ('deinterleaveAttribute ignores normalized', 'buffer_geometry_utils.mbt',
   '  let new_attribute = @core.BufferAttribute::new(array, item_size, normalized~)', '  let new_attribute = @core.BufferAttribute::new(array, item_size)'),
  ('mikktspace quantizes with the source normal type ignored (Float32 tangents)', 'buffer_geometry_utils.mbt',
   '(normal_type == "Int8Array" || normal_type == "Int16Array")', '(normal_type == "Int8Array")'),
  ('JS key order not mirrored (integer-like names)', 'buffer_geometry_utils.mbt',
   '  if indices.length() > 1 {\n    indices.sort_by(', '  if false {\n    indices.sort_by('),
  ('toCreasedNormals hash multiplier without 1e-10 bias', 'buffer_geometry_utils.mbt',
   'let hash_multiplier = (1.0 + 1.0e-10) * 1.0e2', 'let hash_multiplier = 1.0e2'),
  ('mergeVertices tolerance not clamped to EPSILON', 'buffer_geometry_utils.mbt',
   'let tolerance = bgu_math_max(tolerance, bgu_epsilon)', 'let tolerance = tolerance'),
  ('retarget localOffsets keyed by mapped name', 'skeleton_utils.mbt',
   'if local_offsets.get(bone.name) is Some(local_offset)', 'if local_offsets.get(name.unwrap_or("")) is Some(local_offset)'),
  ('computeMorphedAttributes ignores drawRange start for groups', 'buffer_geometry_utils.mbt',
   'let start = bgu_math_max(\n            group.start.to_double(),\n            draw_range.start.to_double(),\n          )\n          let end = bgu_math_min(\n            group.start.to_double() + group.count,\n            draw_range.start.to_double() + draw_range.count,\n          )\n          let mut j = start\n          while j < end {\n            let ji = j.to_int()\n            triangle(ji, ji + 1, ji + 2)',
   'let start = group.start.to_double()\n          let end = bgu_math_min(\n            group.start.to_double() + group.count,\n            draw_range.start.to_double() + draw_range.count,\n          )\n          let mut j = start\n          while j < end {\n            let ji = j.to_int()\n            triangle(ji, ji + 1, ji + 2)'),
]
sel = [int(x) for x in sys.argv[1:]] or range(len(BUGS))
for i in sel:
    label, f, old, new = BUGS[i]
    path = SRC + f
    orig = (REPO / path).read_text()
    n = orig.count(old)
    if n != 1:
        print(f'[{i}] {label}: pattern occurs {n} times, skipped'); continue
    with patched(path, old, new):
        if DRY_RUN:
            print(f'[{i}] {label}: applies (dry run)'); continue
        b = subprocess.run(['moon', 'build', '--target', 'js'], cwd=H, capture_output=True, text=True)
        if b.returncode != 0:
            print(f'[{i}] {label}: BUILD FAILED'); print((b.stdout + b.stderr)[-800:]); continue
        r = subprocess.run(['node', '--import', '../register.mjs', 'run.mjs'], cwd=H, capture_output=True, text=True)
        out = r.stdout.strip().splitlines()
        summary = out[-1] if out else r.stderr[-300:]
        fails = [l for l in out if l.startswith('FAIL')]
        print(f'[{i}] {label}: {"CAUGHT" if r.returncode else "NOT CAUGHT"} -- {summary}; first: {fails[0] if fails else "-"}')
if not DRY_RUN:
    subprocess.run(['moon', 'build', '--target', 'js'], cwd=H, capture_output=True, text=True)
