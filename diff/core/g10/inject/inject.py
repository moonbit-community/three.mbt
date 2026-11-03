# Injects deliberate bugs into src/renderers/webgl_fallback one at a time, runs the harness
# that should catch it, and restores the file (diff/lib/inject.py). Usage:
#   python3 diff/core/g10/inject/inject.py [index ...]   (INJECT_DRY_RUN=1: only check the patterns)
import pathlib, subprocess, sys
sys.path.insert(0, str(next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'lib/env.py').exists())))
from lib.env import REPO, DIFF  # noqa: E402
from lib.inject import patched, DRY_RUN  # noqa: E402
PKG = 'src/renderers/webgl_fallback/'
SD = DIFF / 'core/webgpu/shader_diff'  # run_g10.mjs: the g10_ GLSL shader scenarios
GD = DIFF / 'core/g10/harness'         # run.mjs: the mock-GL scenarios
B = 'nodes_glsl_node_builder.mbt'
BC = 'nodes_glsl_node_builder_code.mbt'
BT = 'nodes_glsl_node_builder_texture.mbt'
W = 'web_gl_backend.mbt'
WF = 'web_gl_backend_framebuffer.mbt'
bugs = [
  # (description, file, old, new, harness, scenarios)
  ('getTernary swaps branches', B, 'Some("\\{cond_snippet} ? \\{if_snippet} : \\{else_snippet}")', 'Some("\\{cond_snippet} ? \\{else_snippet} : \\{if_snippet}")', 'shader', []),
  ('bitcast_float_int maps to floatBitsToUint', B, '"bitcast_float_int" => Some("floatBitsToInt")', '"bitcast_float_int" => Some("floatBitsToUint")', 'shader', []),
  ('vector select mix() argument order', B, 'return Some("mix( \\{else_snippet}, \\{if_snippet}, \\{cond_snippet} )")', 'return Some("mix( \\{if_snippet}, \\{else_snippet}, \\{cond_snippet} )")', 'shader', []),
  ('texel fetch of a depth texture keeps all channels', BT, '  if texture is Some(t) && t.is_depth_texture() {\n    snippet += ".x"', '  if texture is Some(t) && t.is_depth_texture() && false {\n    snippet += ".x"', 'shader', []),
  ('gather default offset', BT, '''  let offset_snippet = match offset_snippet {
    Some(o) => o
    None => "ivec2( 0 )"
  }
  let flip_y_snippet = match flip_y_snippet {
    Some(f) => f
    None => "false"
  }
  if _glsl_truthy(depth_snippet) {
    self._include(b, "textureGatherArray")''', '''  let offset_snippet = match offset_snippet {
    Some(o) => o
    None => "ivec2( 1 )"
  }
  let flip_y_snippet = match flip_y_snippet {
    Some(f) => f
    None => "false"
  }
  if _glsl_truthy(depth_snippet) {
    self._include(b, "textureGatherArray")''', 'shader', []),
  ('shadow sampler of array textures', BC, '"sampler2DArrayShadow \\{uniform.name};"', '"sampler2DShadow \\{uniform.name};"', 'shader', []),
  ('precision medium -> highp', B, '"medium" => "mediump"', '"medium" => "highp"', 'shader', []),
  ('flat qualifier misses ivec types', BC, 'type_.contains("int") || type_.contains("uv") || type_.contains("iv")', 'type_.contains("int") || type_.contains("uv")', 'shader', []),
  ('linear interpolation maps to smooth', B, '"linear" => "noperspective"', '"linear" => "smooth"', 'shader', []),
  ('fragColor output location', BC, '"layout( location = 0 ) out \\{b.get_output_type()} fragColor;"', '"layout( location = 1 ) out \\{b.get_output_type()} fragColor;"', 'shader', []),
  ('integer attributes keep the i/u prefix', BC, 'if (kind is Uint32Array || kind is Int32Array) == false {', 'if (kind is Uint32Array || kind is Int32Array) == true {', 'shader', []),
  ('function body loses the blank line after vars', B, '"\\{return_type} \\{layout.name}( \\{parameters.join(", ")} ) {\\n\\n\\t\\{vars}\\n\\n\\{flow_data.code}', '"\\{return_type} \\{layout.name}( \\{parameters.join(", ")} ) {\\n\\t\\{vars}\\n\\n\\{flow_data.code}', 'shader', []),
  ('multiview num_views', BC, '"layout(num_views = 2) in"', '"layout(num_views = 4) in"', 'shader', []),
  ('draw index without multi draw', BC, 'Some("nodeUniformDrawId") // fallback to uniform', 'Some("uint( gl_DrawID )") // fallback to uniform', 'shader', []),
  ('uniform buffer block names', BC, 'binding.name = "NodeBuffer_" + group_name + "_" + i.to_string()', 'binding.name = "NodeBuffer_" + i.to_string() + "_" + group_name', 'shader', []),
  ('PBO width rounds the exponent down', B, '"(n, s) => Math.pow( 2, Math.ceil( Math.log2( Math.sqrt( n / s ) ) ) )"', '"(n, s) => Math.pow( 2, Math.floor( Math.log2( Math.sqrt( n / s ) ) ) )"', 'diff', ['compute_pbo_render']),
  ('invocation local index size', BC, 'let size = workgroup_size.fold(init=1, fn(acc, curr) { acc * curr })', 'let size = workgroup_size.fold(init=1, fn(acc, curr) { acc + curr })', 'shader', []),
  ('extra MRT attachments cleared to transparent', W, 'gl.clear_bufferfv(@webgl.GL_COLOR, i, [0.0, 0, 0, 1])', 'gl.clear_bufferfv(@webgl.GL_COLOR, i, [0.0, 0, 0, 0])', 'diff', ['render_targets_mrt']),
  ('viewport y not flipped', W, 'state.viewport(v.x, render_context.height.to_double() - v.w - v.y, v.z, v.w)', 'state.viewport(v.x, v.y, v.z, v.w)', 'diff', ['clear_resize_dispose']),
  ('clear color not premultiplied', W, '  clear_color.color.r *= clear_color.a\n', '', 'diff', ['clear_resize_dispose']),
  ('compute dispatches one point too many', W, '    gl.draw_arrays(@webgl.GL_POINTS, 0, count)', '    gl.draw_arrays(@webgl.GL_POINTS, 0, count + 1)', 'diff', ['compute_transform_feedback']),
  ('transform feedback buffers left bound', W, '''  for i in 0..<transform_attributes.length() {
    gl.bind_buffer_base(@webgl.GL_TRANSFORM_FEEDBACK_BUFFER, i, None)
  }''', '', 'diff', ['compute_transform_feedback']),
  ('MSAA resolve skips depth', WF, '            mask = mask | @webgl.GL_DEPTH_BUFFER_BIT', '            mask = mask | 0', 'diff', ['render_targets']),
  ('depth-stencil attachment for depth-only targets', WF, '''      let depth_style = if stencil_buffer {
        @webgl.GL_DEPTH_STENCIL_ATTACHMENT
      } else {
        @webgl.GL_DEPTH_ATTACHMENT
      }
      if props._auto_allocate_depth_buffer == Some(true) {''', '''      let depth_style = if !stencil_buffer {
        @webgl.GL_DEPTH_STENCIL_ATTACHMENT
      } else {
        @webgl.GL_DEPTH_ATTACHMENT
      }
      if props._auto_allocate_depth_buffer == Some(true) {''', 'diff', ['render_basic']),
  ('sampler units start at 1', W, '''        let index = textures
        textures += 1
        let location = gl.get_uniform_location(program_gpu, binding.name)''', '''        textures += 1
        let index = textures
        let location = gl.get_uniform_location(program_gpu, binding.name)''', 'diff', ['textures_formats']),
  ('hasFeature ignores extensions', W, '    if entry.1 == name && extensions.has(entry.0) {', '    if entry.1 == name && extensions.has(entry.1 + "x") {', 'diff', ['batched_mesh']),
  ('mirrored meshes keep front face', 'utils_web_gl_state.mbt', '  if front_face_cw {\n    flip_sided = !flip_sided\n  }', '', 'diff', ['materials_unlit']),
  ('anisotropy clamps with max', 'utils_web_gl_texture_utils.mbt', '        @webgl.js_math_min(\n          texture.anisotropy.to_double(),', '        @webgl.js_math_max(\n          texture.anisotropy.to_double(),', 'diff', ['textures_formats']),
  ('multi draw with the arrays entry point', 'web_gl_buffer_renderer.mbt', '      if self.index != 0 {\n        extension.multi_draw_elements_webgl(', '      if self.index == 0 {\n        extension.multi_draw_elements_webgl(', 'diff', ['batched_mesh']),
  ('uniform update ranges merged across gaps', W, '        if next is Some(n) && n.start == end {', '        if next is Some(n) && n.start >= end {', 'diff', ['materials_lit']),
  ('occlusion query not ended before the next object', W, '''      if !last_object.is_null() &&
        @nodes.occlusion_test(last_object.cast()) == true {
        gl.end_query(@webgl.GL_ANY_SAMPLES_PASSED)''', '''      if !last_object.is_null() &&
        @nodes.occlusion_test(last_object.cast()) == false {
        gl.end_query(@webgl.GL_ANY_SAMPLES_PASSED)''', 'diff', ['queries']),
]

def run(harness, scenarios):
    if harness == 'shader':
        r = subprocess.run(['node', 'run_g10.mjs'], cwd=SD, capture_output=True, text=True)
    else:
        r = subprocess.run(['node', 'run.mjs', '--quiet', *scenarios], cwd=GD, capture_output=True, text=True)
    out = r.stdout + r.stderr
    caught = r.returncode != 0
    tail = [l for l in out.split('\n') if l.strip()][-1:] 
    return caught, (tail[0] if tail else '')

only = [int(x) for x in sys.argv[1:]]
results = []
for i, (desc, f, old, new, harness, scenarios) in enumerate(bugs):
    if only and i not in only:
        continue
    path = PKG + f
    src = (REPO / path).read_text()
    n = src.count(old)
    if n != 1:
        print(f'[{i}] SKIP {desc}: snippet found {n} times', flush=True)
        results.append((i, desc, 'skip'))
        continue
    with patched(path, old, new):
        if DRY_RUN:
            print(f'[{i}] pattern ok: {desc}')
            continue
        caught, tail = run(harness, scenarios)
    print(f'[{i}] {"CAUGHT" if caught else "MISSED"} {desc} ({harness} {" ".join(scenarios)}): {tail}', flush=True)
    results.append((i, desc, 'caught' if caught else 'missed'))
print('caught', sum(1 for r in results if r[2] == 'caught'), 'of', len(results))
