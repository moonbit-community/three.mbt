#!/usr/bin/env python3
# Bug injection: applies one deliberate bug at a time to a G6 source file, runs the
# scenarios that should catch it, and restores the file. Every injected bug must make
# at least one scenario fail.
#   python3 inject.py [index ...]
import subprocess, sys, os

import pathlib, sys
sys.path.insert(0, str(next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'lib/env.py').exists())))
from lib.env import REPO  # noqa: E402
from lib.inject import patched, run as run_cmd, DRY_RUN  # noqa: E402
SRC_DIR = 'src/nodes/'
HERE = os.path.dirname(os.path.abspath(__file__))

BUGS = [
    ('viewport not shifted by the mip level', 'common_renderer.mbt',
     'viewport_value.z = renderer_shr(viewport_value.z, active_mipmap_level)', 'viewport_value.z = renderer_shr(viewport_value.z, 0)', ['render_targets']),
    ('clear color premultiplied without alpha', 'common_background.mbt',
     'renderer.backend.has_flag("isWebGLBackend") || renderer.alpha == true', 'renderer.backend.has_flag("isWebGLBackend") || renderer.alpha == false', ['background_fog', 'render_scene']),
    ('frustum culling disabled', 'common_standard_drawing_pipeline.mbt',
     'if !object.frustum_culled || self._bundle_depth > 0 {', 'if !object.frustum_culled || self._bundle_depth >= 0 {', ['render_scene']),
    ('group render order ignored', 'common_standard_drawing_pipeline.mbt',
     'group_order = object.render_order.to_int()', 'group_order = 0', ['render_scene']),
    ('shadow side not flipped', 'common_renderer.mbt',
     'None => _renderer_shadow_side(material.side)', 'None => material.side', ['utils_misc']),
    ('clear stencil value not taken', 'common_renderer.mbt',
     'render_context.clear_stencil_value = self.get_clear_stencil()', 'render_context.clear_stencil_value = 0', ['init_size']),
    ('frame buffer target without the renderer samples', 'common_renderer.mbt',
     '        samples=self.samples(),', '        samples=0,', ['info_dispose']),
    ('compute frame calls not counted', 'common_renderer.mbt',
     'self.info.compute.frame_calls += 1', 'self.info.compute.frame_calls += 0', ['compute_copy']),
    ('canvas size ignores the pixel ratio', 'common_canvas_target.mbt',
     'canvas_target_math_floor(width * self._pixel_ratio),', 'canvas_target_math_floor(width),', ['init_size']),
    ('cube render target clears five faces', 'common_cube_render_target.mbt',
     'for i in 0..<6 {', 'for i in 0..<5 {', ['render_targets']),
    ('PMREM roughness formula', 'common_extras_pmrem_generator.mbt',
     '1.0 - pmrem_math_sqrt(1.0 - lod / max_lod)', 'pmrem_math_sqrt(lod / max_lod)', ['pmrem']),
    ('PMREM target misses the last mip', 'common_extras_pmrem_generator.mbt',
     'while lod.to_double() <= max_lod {', 'while lod.to_double() < max_lod {', ['pmrem']),
    ('render pipeline ignores tone mapping changes', 'common_render_pipeline.mbt',
     'if self._tone_mapping != self.renderer.tone_mapping {', 'if false && self._tone_mapping != self.renderer.tone_mapping {', ['pipelines']),
    ('XR quad layer texture not flipped', 'common_xr_manager.mbt',
     '  render_target.texture().offset.y = 1.0\n', '  render_target.texture().offset.y = 0.0\n', ['info_dispose']),
    ('quad geometry uv', 'common_quad_mesh.mbt',
     '[0.0, -1, 0, 1, 2, 1]', '[0.0, -1, 0, 1, 2, 2]', ['pipelines']),
    ('direct pipeline keeps its background node', 'common_direct_render_pipeline.mbt',
     '        s.background_node = current_background_node', '        ignore(current_background_node)', ['pipelines']),
    ('reflector resolution ignored', 'utils_reflector_node.mbt',
     'reflector_math_round(_reflector_size.x * resolution).to_int(),', 'reflector_math_round(_reflector_size.x).to_int(),', ['nodes_render']),
    ('copied rectangle not floored', 'common_renderer.mbt',
     'Some(r) => _renderer_vector4.copy(r).floor()', 'Some(r) => _renderer_vector4.copy(r)', ['compute_copy']),
    ('scissor test not passed to the backend', 'common_renderer.mbt',
     '  self.backend.set_scissor_test(boolean)\n', '  ignore(boolean)\n', ['init_size']),
    ('bundle version not compared', 'common_renderer.mbt',
     '.strict_equal(@core.JsValue::of(bundle_group.version)) ||', '.strict_equal(render_bundle_data.get("version")) ||', ['bundles_compile']),
    ('double-sided transparent passes in the wrong order', 'common_renderer.mbt',
     '    material.force_single_pass == false {\n    material.side = @core.BackSide', '    material.force_single_pass == false {\n    material.side = @core.FrontSide', ['render_scene']),
    ('background sphere drawn from the front', 'common_background.mbt',
     '          node_material.side = @core.BackSide', '          node_material.side = @core.FrontSide', ['background_fog']),
    ('lights of the scene not restored after a render', 'common_lighting.mbt',
     '  LightsNode::set_lights(self.get_node(scene), lights) |> ignore', '  ignore(lights)', ['render_scene', 'bundles_compile']),
]

sel = [int(x) for x in sys.argv[1:]] or range(len(BUGS))
caught = 0
for i in sel:
    name, f, old, new, scen = BUGS[i]
    path = SRC_DIR + f
    src = (REPO / path).read_text()
    if src.count(old) != 1:
        print(f'[{i}] SKIP {name}: pattern found {src.count(old)} times')
        continue
    with patched(path, old, new):
        if DRY_RUN:
            print(f'[{i}] pattern ok: {name}')
            continue
        r = subprocess.run(['node', os.path.join(HERE, 'run.mjs'), '--quiet', *scen], capture_output=True, text=True)
        out = r.stdout.strip().split('\n')
        fails = [l for l in out if l.startswith(('MISMATCH', 'MOON ERROR'))]
        if r.returncode != 0 and fails:
            caught += 1
            print(f'[{i}] CAUGHT {name}: ' + '; '.join(l.split(' (')[0] for l in fails), flush=True)
        else:
            print(f'[{i}] MISSED {name}: ' + out[-1], flush=True)
print(f'{caught}/{len(sel)} injected bugs caught')
