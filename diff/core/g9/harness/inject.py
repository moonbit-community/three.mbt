#!/usr/bin/env python3
# python3 inject.py [index ...]: injects deliberate bugs into the G9 sources one at a time,
# rebuilds the MoonBit harness module, runs every scenario (run.mjs) and checks that the
# harness catches the bug; the source is restored after each one.
import subprocess, sys, os
import pathlib, sys
sys.path.insert(0, str(next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'lib/env.py').exists())))
from lib.env import REPO  # noqa: E402
from lib.inject import patched, run as run_cmd, DRY_RUN  # noqa: E402
SRC_DIR = 'src/renderers/webgpu/'
HERE = os.path.dirname(os.path.abspath(__file__))
MBT = os.path.join(HERE, '..', 'mbt')
EXCLUDE = []  # scenarios that differ before any injection (none since the module-level node ids and the fallback init rejection were fixed)
BUGS = [
  ('web_gpu_backend.mbt', 'ced.label = Some("renderContext_" + render_context.id.to_string())', 'ced.label = Some("renderCtx_" + render_context.id.to_string())', 'command encoder label of a render'),
  ('web_gpu_backend.mbt', '''    if discard_depth {
      dsa.depth_store_op = Some(GPUStoreOp_Discard)''', '''    if !discard_depth {
      dsa.depth_store_op = Some(GPUStoreOp_Discard)''', 'depth store op'),
  ('web_gpu_backend.mbt', 'dsa.depth_clear_value = Some(renderer.get_clear_depth())', 'dsa.depth_clear_value = Some(1.0 - renderer.get_clear_depth())', 'clear() depth value'),
  ('web_gpu_backend_draw.mbt', '''      if !same {
        let buffer : @gpu.GPUBuffer = self.get(key).get("buffer").cast()''', '''      if true || !same {
        let buffer : @gpu.GPUBuffer = self.get(key).get("buffer").cast()''', 'index buffer state cache'),
  ('web_gpu_backend_draw.mbt', '''        let index_format = if index.array().type_name() == "Uint16Array" {''', '''        let index_format = if index.array().type_name() == "Uint32Array" {''', 'index format'),
  ('web_gpu_backend_draw.mbt', '''            pass_encoder_gpu.draw_indexed(
              vertex_count,
              instance_count.to_int(),''', '''            pass_encoder_gpu.draw_indexed(
              vertex_count,
              1,''', 'instance count of indexed draws'),
  ('web_gpu_backend_resources.mbt', '''    if (uniform_buffer.visibility & GPUShaderStage_VERTEX) != 0 {
      visibilities.push("vertex")
    }''', '''    if (uniform_buffer.visibility & GPUShaderStage_VERTEX) != 0 {
      visibilities.push("vert")
    }''', 'uniform buffer label'),
  ('web_gpu_backend_resources.mbt', '(if program.name != "" { "_\\{program.name}" } else { "" }),', '"_\\{program.name}",', 'shader module label'),
  ('utils_web_gpu_utils.mbt', '''  if sample_count >= 4 {
    4''', '''  if sample_count > 4 {
    4''', 'getSampleCount'),
  ('utils_web_gpu_utils.mbt', '''        } else if self.backend().renderer().reversed_depth_buffer == true {
          format = Some(GPUTextureFormat_Depth32Float)''', '''        } else if self.backend().renderer().reversed_depth_buffer == true {
          format = Some(GPUTextureFormat_Depth24Plus)''', 'reversed depth format'),
  ('utils_web_gpu_attribute_utils.mbt', '    Some(s) if s > 1 && s * bpe % 4 != 0 => {', '    Some(s) if s > 1 && s * bpe % 8 == 1 => {', 'vertex padding'),
  ('utils_web_gpu_attribute_utils.mbt', '''              if b.is_instanced_buffer_attribute() {
                GPUInputStepMode_Instance''', '''              if b.is_instanced_buffer_attribute() {
                GPUInputStepMode_Vertex''', 'instance step mode'),
  ('utils_web_gpu_attribute_utils.mbt', '    Interleaved(a) => a.offset * bytes_per_element', '    Interleaved(a) => a.offset', 'interleaved offset'),
  ('utils_web_gpu_binding_utils.mbt', '''            access == Some(@nodes.node_access_write_only) {
            buffer.type_ = Some(GPUBufferBindingType_Storage)''', '''            access == Some(@nodes.node_access_write_only) {
            buffer.type_ = Some(GPUBufferBindingType_ReadOnlyStorage)''', 'storage buffer access'),
  ('utils_web_gpu_binding_utils.mbt', '''            let dimension_view_gpu = if binding.has_flag("isSampledCubeTexture") {
              GPUTextureViewDimension_Cube''', '''            let dimension_view_gpu = if binding.has_flag("isSampledCubeTexture") {
              GPUTextureViewDimension_TwoD''', 'cube view dimension'),
  ('utils_web_gpu_binding_utils.mbt', '''    if cache_key != "" {
      bindings_data.get("groups").set(cache_key, bind_group_gpu)''', '''    if cache_key == "!" {
      bindings_data.get("groups").set(cache_key, bind_group_gpu)''', 'bind group cache'),
  ('utils_web_gpu_pipeline_utils.mbt', '''          GPUBlendFactor_SrcAlpha,
          GPUBlendFactor_OneMinusSrcAlpha,
          GPUBlendFactor_One,
          GPUBlendFactor_OneMinusSrcAlpha,''', '''          GPUBlendFactor_SrcAlpha,
          GPUBlendFactor_One,
          GPUBlendFactor_One,
          GPUBlendFactor_OneMinusSrcAlpha,''', 'normal blending factors'),
  ('web_gpu_backend_draw.mbt', '''        _web_gpu_backend_blend_constant.b = blend_color.b''', '''        _web_gpu_backend_blend_constant.b = blend_color.g''', 'blend constant'),
  ('utils_web_gpu_pipeline_utils.mbt', '''    @core.ReverseSubtractEquation => Some(GPUBlendOperation_ReverseSubtract)''', '''    @core.ReverseSubtractEquation => Some(GPUBlendOperation_Subtract)''', 'blend operation'),
  ('utils_web_gpu_pipeline_utils.mbt', '''    if material.side == @core.DoubleSide {
      GPUCullMode_None''', '''    if material.side == @core.BackSide {
      GPUCullMode_None''', 'cull mode'),
  ('utils_web_gpu_pipeline_utils.mbt', '    @core.LessDepth => Some(@core.GreaterDepth)', '    @core.LessDepth => Some(@core.GreaterEqualDepth)', 'reversed depth function'),
  ('utils_web_gpu_pipeline_utils.mbt', '  multisample.count = Some(sample_count)', '  multisample.count = Some(1)', 'multisample count'),
  ('utils_web_gpu_texture_utils.mbt', '''  if value == @core.RepeatWrapping {
    GPUAddressMode_Repeat''', '''  if value == @core.RepeatWrapping {
    GPUAddressMode_MirrorRepeat''', 'address mode'),
  ('utils_web_gpu_texture_utils.mbt', '''  let mut usage = @gpu.GPU_TEXTURE_USAGE_TEXTURE_BINDING |
    @gpu.GPU_TEXTURE_USAGE_COPY_DST |
    @gpu.GPU_TEXTURE_USAGE_COPY_SRC''', '''  let mut usage = @gpu.GPU_TEXTURE_USAGE_TEXTURE_BINDING |
    @gpu.GPU_TEXTURE_USAGE_COPY_DST''', 'texture usage'),
  ('utils_web_gpu_texture_utils.mbt', 'let bytes_per_row = wgpu_ceil_div(unpadded_bytes_per_row, 256) * 256', 'let bytes_per_row = wgpu_ceil_div(unpadded_bytes_per_row, 128) * 128', 'readback row alignment'),
  ('utils_web_gpu_texture_utils.mbt', '''  if value == @core.NearestMipmapLinearFilter ||
    value == @core.LinearMipmapLinearFilter {''', '''  if value == @core.NearestMipmapLinearFilter {''', 'mipmap filter'),
  ('utils_web_gpu_texture_pass_utils.mbt', '''  pass(
    flip_transfer_pipeline, temp_texture, 0, texture_gpu, base_array_layer, true,
  )''', '''  pass(
    flip_transfer_pipeline, temp_texture, 0, texture_gpu, base_array_layer, false,
  )''', 'flipY uniform'),
  ('utils_web_gpu_timestamp_query_pool.mbt', '  pool.current_query_index += 2', '  pool.current_query_index += 1', 'timestamp query allocation'),
  ('web_gpu_backend_draw.mbt', '''fn wgpu_ceil_div(a : Int32, b : Int32) -> Int32 {
  (a.to_double() / b.to_double()).ceil().to_int()''', '''fn wgpu_ceil_div(a : Int32, b : Int32) -> Int32 {
  (a.to_double() / b.to_double()).floor().to_int()''', 'dispatch size rounding'),
  ('web_gpu_backend_resources.mbt', '  dst.origin = Some(@gpu.GPUOrigin3D::new(x=dst_x, y=dst_y, z=dst_z))', '  dst.origin = Some(@gpu.GPUOrigin3D::new(x=dst_x, y=0, z=dst_z))', 'copy destination origin'),
  ('web_gpu_backend_draw.mbt', '''                  occlusion_data.set(
                    "occlusionQueryIndex",
                    @core.JsValue::of(index + 1),
                  )''', '''                  occlusion_data.set(
                    "occlusionQueryIndex",
                    @core.JsValue::of(index),
                  )''', 'occlusion query index'),
  ('web_gpu_backend.mbt', '''    if render_context.clear_color || discard_color || clear_external_color {''', '''    if render_context.clear_color || clear_external_color {''', 'MSAA color discard clear'),
]

def run(cmd, cwd):
  return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)

def main():
  idx = [int(a) for a in sys.argv[1:]] or list(range(len(BUGS)))
  caught = []
  for i in idx:
    f, old, new, what = BUGS[i]
    p = SRC_DIR + f
    src = (REPO / p).read_text()
    n = src.count(old)
    if n != 1:
      print(f'bug {i} ({what}): pattern found {n} times, skipped')
      continue
    with patched(p, old, new):
      if DRY_RUN:
        print(f'bug {i} ({what}): pattern ok')
        continue
      b = run(['moon', 'build', '--target', 'js'], MBT)
      if b.returncode != 0:
        print(f'bug {i} ({what}): BUILD FAILED\n' + (b.stdout + b.stderr)[-800:])
        continue
      names = [l for l in run(['node', '-e', "import('./scenarios.mjs').then(m=>console.log(Object.keys(m.scenarios).join('\\n')))"], HERE).stdout.split() if l not in EXCLUDE]
      r = run(['node', 'run.mjs', '--quiet'] + names, HERE)
      last = r.stdout.strip().split('\n')[-1]
      ok = r.returncode != 0
      print(f'bug {i} ({what}): {"CAUGHT" if ok else "MISSED"} -- {last}')
      if ok: caught.append(i)
  if not DRY_RUN:
    run(['moon', 'build', '--target', 'js'], MBT)  # rebuild from the restored sources
  print(f'caught {len(caught)} of {len(idx)}')

main()
