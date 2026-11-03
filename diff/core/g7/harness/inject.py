#!/usr/bin/env python3
# Bug injection: applies one deliberate bug at a time to a G7 source file, runs the
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
    ('std140 padding uses the chunk instead of the boundary', 'common_uniforms_group.mbt',
     'let chunk_padding = chunk_offset % boundary', 'let chunk_padding = chunk_offset % 16', ['uniforms_layout']),
    ('int uniforms written through the Float32Array', 'common_uniforms_group.mbt',
     'return @core.TypedArray::view_by_name("Int32Array", buffer.buffer())',
     'return buffer', ['uniforms_types']),
    ('matrix3 columns not padded', 'common_uniforms_group.mbt',
     'let slots = [0, 1, 2, 4, 5, 6, 8, 9, 10]', 'let slots = [0, 1, 2, 3, 4, 5, 6, 7, 8]', ['uniforms_layout']),
    ('values mirror the float32-rounded buffer instead of the JS values', 'common_uniforms_group.mbt',
     '  uniforms_group_set_value(b, offset, v)\n  _uniforms_group_set_array(a, offset, v)',
     '  uniforms_group_set_value(b, offset, v)\n  _uniforms_group_set_array(a, offset, @core.JsValue::of(b.get(offset)))', ['uniforms_layout']),
    ('painter sort compares z the wrong way', 'common_render_list.mbt',
     '    _render_list_num(a.z) - _render_list_num(b.z)\n  } else {\n    _render_list_int(a.id) - _render_list_int(b.id)\n  }\n}\n\n///|\n/// `reversePainterSortStable',
     '    _render_list_num(b.z) - _render_list_num(a.z)\n  } else {\n    _render_list_int(a.id) - _render_list_int(b.id)\n  }\n}\n\n///|\n/// `reversePainterSortStable', ['render_list']),
    ('shared group uniforms not sorted by node id', 'common_bindings.mbt',
     '      @webgl.stable_sort_by(uniforms, fn(a, b) {', '      @webgl.stable_sort_by([], fn(a : Uniform, b : Uniform) {', ['bindings']),
    ('chain map delete always reports success', 'common_chain_map.mbt',
     '    if next.is_undefined() {\n      return false\n    }\n    map = next.cast()\n  }\n  chain_map_delete(',
     '    if next.is_undefined() {\n      return true\n    }\n    map = next.cast()\n  }\n  chain_map_delete(', ['buffer_utils_chain_map']),
    ('geometry cache key ignores normalized attributes', 'common_render_object.mbt',
     '      cache_key += "n,"', '      cache_key += ""', ['render_objects']),
    ('dynamic attributes not re-uploaded', 'common_attributes.mbt',
     'attribute.usage() == Some(@core.DynamicDrawUsage)', 'attribute.usage() == Some(-1)', ['attributes_geometries']),
    ('mip chain estimate rounded differently', 'common_info.mbt',
     'size = size * 1.333', 'size = size * 1.33', ['info', 'textures']),
    ('mip level count off by one', 'common_textures.mbt',
     'textures_math_log2(max.to_double()).floor().to_int() + 1', 'textures_math_log2(max.to_double()).floor().to_int() + 2', ['textures']),
    ('released programs stay in the program cache', 'common_pipelines.mbt',
     '  self.programs.stage(stage).remove(code)', '  ignore(stage)', ['pipelines']),
    ('clipping planes projected without negating the normal', 'common_clipping_context.mbt',
     '    v.x = -normal.x', '    v.x = normal.x', ['clipping_context']),
    ('updateGroup ignores the group version', 'common_nodes_node_manager.mbt',
     '  if group_data.version != Some(group_node.version) {', '  if true {', ['node_manager', 'bindings']),
    ('clone does not consume a SampledTexture id', 'common_sampled_texture.mbt',
     'pub fn SampledTexture::copy_payload(self : SampledTexture) -> SampledTexture {\n  _sampled_texture_id.val += 1',
     'pub fn SampledTexture::copy_payload(self : SampledTexture) -> SampledTexture {\n  _sampled_texture_id.val += 0', ['misc_classes', 'bindings']),
    ('render contexts keyed without the call depth', 'common_render_contexts.mbt',
     'let render_state_key = state_key + "-" + call_depth.to_string()', 'let render_state_key = state_key', ['render_contexts', 'bindings']),
    ('wireframe index edges not closed', 'common_geometries.mbt',
     '    indices.set(j + 5, a)', '    indices.set(j + 5, b)', ['attributes_geometries']),
    ('texture key drops the channel', 'common_render_object.mbt',
     '      value_key += t.channel.to_string()', '      value_key += ""', ['render_objects']),
    ('update ranges not cleared after a uniform upload', 'common_bindings.mbt',
     '    if binding.has_flag("isBuffer") && binding.update_ranges().length() > 0 {\n      binding.clear_update_ranges()',
     '    if binding.has_flag("isBuffer") && binding.update_ranges().length() > 99 {\n      binding.clear_update_ranges()', ['bindings', 'render_bindings']),
    ('storage buffer access not read from the node', 'common_nodes_node_storage_buffer.mbt',
     '    Some(s) => s.access', '    Some(_) => "readWrite"', ['node_buffers']),
    ('storage generations left out of the bind group version', 'common_bindings.mbt',
     '      version += generation\n', '      version += 0\n', ['node_buffers']),
    ('cube environments sampled as 2D textures', 'common_nodes_node_manager.mbt',
     '            if environment.is_cube_texture() {', '            if !environment.is_cube_texture() {', ['scene_nodes']),
    ('render list finish keeps the lights when lighting is off', 'common_render_list.mbt',
     '    if self.lighting.enabled {\n      self.lights_array', '    if true {\n      self.lights_array', ['render_list']),
    ('animation does not reset info', 'common_animation.mbt',
     '    if self.info.auto_reset {', '    if false {', ['animation']),
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
            print(f'[{i}] CAUGHT {name}: ' + '; '.join(l.split(' (')[0] for l in fails))
        else:
            print(f'[{i}] MISSED {name}: ' + out[-1])
print(f'{caught}/{len(sel)} injected bugs caught')
