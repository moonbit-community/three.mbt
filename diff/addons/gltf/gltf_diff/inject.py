#!/usr/bin/env python3
"""Bug injection for the GLTFLoader port: applies each bug alone, rebuilds the harness,
runs run.mjs, records whether a mismatch was caught, restores the file.

    python3 inject.py [index ...]
"""
import subprocess, sys, pathlib
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(next(p for p in HERE.parents if (p / 'lib/env.py').exists())))
from lib.env import REPO  # noqa: E402
from lib.inject import patched, DRY_RUN  # noqa: E402
# INJECT_DRY_RUN=1 only checks that every pattern applies; after a hard kill,
# `python3 diff/lib/inject.py --restore` restores the patched file.

SRC = 'src/addons/loaders/'

BUGS = [
    ('interleaved attribute offset not reduced modulo stride', 'gltf_parser.mbt',
     'byte_offset % byte_stride / element_bytes', 'byte_offset / element_bytes'),
    ('texture flipY left true', 'gltf_parser.mbt',
     'texture.flip_y = false', 'texture.flip_y = true'),
    ('default minFilter Linear', 'gltf_parser.mbt',
     '@core.LinearMipmapLinearFilter,\n      )', '@core.LinearFilter,\n      )'),
    ('sparse keeps normalized off', 'gltf_parser.mbt',
     '      gltf_set_normalized(buffer_attribute, normalized)\n', '\n'),
    ('unique name suffix not incremented', 'gltf_parser.mbt',
     'gltf_string(gltf_pre_increment(self.node_names_used, sanitized_name))', '"1"'),
    ('derivative tangents do not flip normalScale.y', 'gltf_parser.mbt',
     '        if cached_material.normal_scale is Some(s) {\n          s.y = s.y * -1.0', '        if cached_material.normal_scale is Some(s) {\n          s.y = s.y * 1.0'),
    ('vertex colors not enabled', 'gltf_parser.mbt',
     'cached_material.vertex_colors = true', 'cached_material.vertex_colors = false'),
    ('BLEND keeps depthWrite', 'gltf_parser.mbt',
     'material_params["depthWrite"] = Bool(false)', 'material_params["depthWrite"] = Bool(true)'),
    ('alphaCutoff default 0.4', 'gltf_parser.mbt',
     'Number(0.5)\n      }', 'Number(0.4)\n      }'),
    ('extendMaterialParams invoked in reverse plugin order', 'gltf_parser.mbt',
     '  for p in self.plugins.values() {\n    extensions.push(p)\n  }', '  for p in self.plugins.values().collect().rev() {\n    extensions.push(p)\n  }'),
    ('instance clone name uses refs', 'gltf_parser.mbt',
     '      cache.uses[index] = u + 1\n      u.to_string()', '      cache.uses[index] = u + 1\n      (u + 1).to_string()'),
    ('cubic spline: out tangent not scaled by td', 'gltf_interpolant.mbt',
     'let m0 = values[offset0 + i + stride2] * td', 'let m0 = values[offset0 + i + stride2]'),
    ('cubic spline quaternion not normalized', 'gltf_interpolant.mbt',
     '  .from_array(result)\n  .normalize()\n', '  .from_array(result)\n'),
    ('spot penumbra uses outer/inner', 'gltf_extensions.mbt',
     'spot.penumbra = 1.0 - inner / outer', 'spot.penumbra = 1.0 - outer / inner'),
    ('texture transform: three.js order (no matrix override)', 'gltf_extensions.mbt',
     '    texture.matrix_auto_update = false\n', '\n'),
    ('volume attenuationDistance default 0', 'gltf_extensions.mbt',
     'gltf_js_number(1.0 / 0.0)', 'gltf_js_number(0.0)'),
    ('ior 0 not mapped to 1000', 'gltf_extensions.mbt',
     'material_params["ior"] = Number(1000)', 'material_params["ior"] = Number(0)'),
    ('sheen color texture without sRGB', 'gltf_extensions.mbt',
     '"sheenColorMap",\n        extension.get("sheenColorTexture"),\n        color_space=@core.SRGBColorSpace,', '"sheenColorMap",\n        extension.get("sheenColorTexture"),'),
    ('draco normalized flags not applied', 'gltf_extensions.mbt',
     '              gltf_set_normalized(attribute, normalized)', '              ignore(normalized)'),
    ('morph targets not relative', 'gltf_parser.mbt',
     '    geometry.morph_targets_relative = true', '    geometry.morph_targets_relative = false'),
    ('normalized animation output not rescaled', 'gltf_parser.mbt',
     '  if accessor.normalized() {\n    let scale', '  if false && accessor.normalized() {\n    let scale'),
    ('loadMesh result resolves one tick later', 'gltf_parser.mbt',
     '      return AddonPromise::resolve(meshes[0])', '      return AddonPromise::resolve(meshes[0]).then_(fn(m : JsValue) { m })'),
    ('bounding sphere radius is full diagonal', 'gltf_parser.mbt',
     'sphere.radius = box_.min.distance_to(box_.max) / 2.0', 'sphere.radius = box_.min.distance_to(box_.max)'),
    ('reduceAssociations drops textures', 'gltf_parser.mbt',
     '(Material(_) as key, value) | (Texture(_) as key, value) =>', '(Material(_) as key, value) =>'),
    ('gpu instancing ignores SCALE', 'gltf_extensions.mbt',
     '          if attributes.get("SCALE") is Some(a) {', '          if attributes.get("SCALE_") is Some(a) {'),
    ('glb BIN chunk offset off by 4', 'gltf_extensions.mbt',
     '      let byte_offset = gltf_BINARY_EXTENSION_HEADER_LENGTH + chunk_index\n', '      let byte_offset = gltf_BINARY_EXTENSION_HEADER_LENGTH + chunk_index + 4\n'),
]

def run(cmd, cwd):
    return subprocess.run(cmd, cwd=cwd, shell=True, capture_output=True, text=True)

def main():
    picks = [int(a) for a in sys.argv[1:]] or list(range(len(BUGS)))
    results = []
    for i in picks:
        name, f, old, new = BUGS[i]
        path = SRC + f
        orig = (REPO / path).read_text()
        if orig.count(old) != 1:
            results.append((i, name, 'PATTERN NOT UNIQUE (%d)' % orig.count(old)))
            print(results[-1], flush=True)
            continue
        with patched(path, old, new):
            if DRY_RUN:
                status = 'APPLIES (dry run)'
            else:
                b = run('moon build --target js', HERE)
                if b.returncode != 0:
                    status = 'BUILD FAILED: ' + (b.stdout + b.stderr)[-300:]
                else:
                    r = run('node --import ../register.mjs run.mjs --no-build', HERE)
                    fails = [l for l in r.stdout.splitlines() if l.startswith('FAIL')]
                    status = ('CAUGHT by %d case(s): %s' % (len(fails), ', '.join(l.split(' ')[1] for l in fails[:4]))) if fails else 'NOT CAUGHT'
        results.append((i, name, status))
        print(results[-1], flush=True)
    if not DRY_RUN:
        run('moon build --target js', HERE)
    print('\n%s %d / %d' % ('applies' if DRY_RUN else 'caught', sum(1 for r in results if r[2].startswith(('CAUGHT', 'APPLIES'))), len(results)))

main()
