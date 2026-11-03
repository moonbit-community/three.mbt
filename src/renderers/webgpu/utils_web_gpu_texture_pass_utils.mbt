// renderers/webgpu/utils/WebGPUTexturePassUtils.js: mipmap generation and flipY with
// render passes (a DataMap keyed by GPU texture).

///|
/// The WGSL of the mipmap and flipY passes (`mipmapSource`).
let _web_gpu_texture_pass_utils_mipmap_source : String =
  #|
  #|struct VarysStruct {
  #|	@builtin( position ) Position: vec4f,
  #|	@location( 0 ) vTex : vec2f,
  #|	@location( 1 ) @interpolate(flat, either) vBaseArrayLayer: u32,
  #|};
  #|
  #|@group( 0 ) @binding ( 2 )
  #|var<uniform> flipY: u32;
  #|
  #|@vertex
  #|fn mainVS(
  #|		@builtin( vertex_index ) vertexIndex : u32,
  #|		@builtin( instance_index ) instanceIndex : u32 ) -> VarysStruct {
  #|
  #|	var Varys : VarysStruct;
  #|
  #|	var pos = array(
  #|		vec2f( -1, -1 ),
  #|		vec2f( -1,  3 ),
  #|		vec2f(  3, -1 ),
  #|	);
  #|
  #|	let p = pos[ vertexIndex ];
  #|	let mult = select( vec2f( 0.5, -0.5 ), vec2f( 0.5, 0.5 ), flipY != 0 );
  #|	Varys.vTex = p * mult + vec2f( 0.5 );
  #|	Varys.Position = vec4f( p, 0, 1 );
  #|	Varys.vBaseArrayLayer = instanceIndex;
  #|
  #|	return Varys;
  #|
  #|}
  #|
  #|@group( 0 ) @binding( 0 )
  #|var imgSampler : sampler;
  #|
  #|@group( 0 ) @binding( 1 )
  #|var img2d : texture_2d<f32>;
  #|
  #|@fragment
  #|fn main_2d( Varys: VarysStruct ) -> @location( 0 ) vec4<f32> {
  #|
  #|	return textureSample( img2d, imgSampler, Varys.vTex );
  #|
  #|}
  #|
  #|@group( 0 ) @binding( 1 )
  #|var img2dArray : texture_2d_array<f32>;
  #|
  #|@fragment
  #|fn main_2d_array( Varys: VarysStruct ) -> @location( 0 ) vec4<f32> {
  #|
  #|	return textureSample( img2dArray, imgSampler, Varys.vTex, Varys.vBaseArrayLayer );
  #|
  #|}
  #|
  #|const faceMat = array(
  #|  mat3x3f(  0,  0,  -2,  0, -2,   0,  1,  1,   1 ),   // pos-x
  #|  mat3x3f(  0,  0,   2,  0, -2,   0, -1,  1,  -1 ),   // neg-x
  #|  mat3x3f(  2,  0,   0,  0,  0,   2, -1,  1,  -1 ),   // pos-y
  #|  mat3x3f(  2,  0,   0,  0,  0,  -2, -1, -1,   1 ),   // neg-y
  #|  mat3x3f(  2,  0,   0,  0, -2,   0, -1,  1,   1 ),   // pos-z
  #|  mat3x3f( -2,  0,   0,  0, -2,   0,  1,  1,  -1 ),   // neg-z
  #|);
  #|
  #|@group( 0 ) @binding( 1 )
  #|var imgCube : texture_cube<f32>;
  #|
  #|@fragment
  #|fn main_cube( Varys: VarysStruct ) -> @location( 0 ) vec4<f32> {
  #|
  #|	return textureSample( imgCube, imgSampler, faceMat[ Varys.vBaseArrayLayer ] * vec3f( fract( Varys.vTex ), 1 ) );
  #|
  #|}
  #|

///|
let _web_gpu_texture_pass_utils_bind_group_descriptor : @gpu.GPUBindGroupDescriptor = @gpu.GPUBindGroupDescriptor::default()

///|
let _web_gpu_texture_pass_utils_buffer_descriptor : @gpu.GPUBufferDescriptor = @gpu.GPUBufferDescriptor::default()

///|
let _web_gpu_texture_pass_utils_command_encoder_descriptor : @gpu.GPUCommandEncoderDescriptor = @gpu.GPUCommandEncoderDescriptor::default()

///|
let _web_gpu_texture_pass_utils_render_bundle_encoder_descriptor : @gpu.GPURenderBundleEncoderDescriptor = @gpu.GPURenderBundleEncoderDescriptor::default()

///|
let _web_gpu_texture_pass_utils_render_pass_descriptor : @gpu.GPURenderPassDescriptor = @gpu.GPURenderPassDescriptor::default()

///|
let _web_gpu_texture_pass_utils_render_pipeline_descriptor : @gpu.GPURenderPipelineDescriptor = @gpu.GPURenderPipelineDescriptor::default()

///|
let _web_gpu_texture_pass_utils_color_attachment : @gpu.GPURenderPassColorAttachment = @gpu.GPURenderPassColorAttachment::default()

///|
let _web_gpu_texture_pass_utils_shader_module_descriptor : @gpu.GPUShaderModuleDescriptor = @gpu.GPUShaderModuleDescriptor::default()

///|
let _web_gpu_texture_pass_utils_texture_descriptor : @gpu.GPUTextureDescriptor = @gpu.GPUTextureDescriptor::default()

///|
let _web_gpu_texture_pass_utils_view_descriptor : @gpu.GPUTextureViewDescriptor = @gpu.GPUTextureViewDescriptor::default()

///|
/// A mipmap pass: `{ renderBundles, passDescriptor }`.
priv struct WebGPUMipmapPass {
  render_bundles : Array[@gpu.GPURenderBundle]
  pass_descriptor : @gpu.GPURenderPassDescriptor
}

///|
/// The record of a GPU texture (`DataMap.get( textureGPU )`).
priv struct WebGPUTexturePassData {
  mut layers : Array[WebGPUMipmapPass]?
}

///|
/// `WebGPUTexturePassUtils`: mipmap generation and flipY with render passes.
pub(all) struct WebGPUTexturePassUtils {
  priv data : @webgl.WeakMap[@core.JsValue, WebGPUTexturePassData]
  device : @gpu.GPUDevice
  mipmap_sampler : @gpu.GPUSampler
  flip_y_sampler : @gpu.GPUSampler
  flip_uniform_buffer : @gpu.GPUBuffer
  no_flip_uniform_buffer : @gpu.GPUBuffer
  /// `transferPipelines`, keyed by `${ format }-${ textureBindingViewDimension }`.
  transfer_pipelines : Map[String, @gpu.GPURenderPipeline]
  mipmap_shader_module : @gpu.GPUShaderModule
}

///|
/// `new WebGPUTexturePassUtils( device )`.
pub fn WebGPUTexturePassUtils::new(
  device : @gpu.GPUDevice,
) -> WebGPUTexturePassUtils {
  let mipmap_sampler = device.create_sampler(
    descriptor=@gpu.GPUSamplerDescriptor::new(min_filter=GPUFilterMode_Linear),
  )
  let flip_y_sampler = device.create_sampler(
    descriptor=@gpu.GPUSamplerDescriptor::new(min_filter=GPUFilterMode_Nearest),
  ) //@TODO?: Consider using textureLoad()
  let bd = _web_gpu_texture_pass_utils_buffer_descriptor
  bd.size = 4
  bd.usage = @gpu.GPU_BUFFER_USAGE_UNIFORM | @gpu.GPU_BUFFER_USAGE_COPY_DST
  let flip_uniform_buffer = device.create_buffer(bd)
  bd.reset()
  device
  .queue()
  .write_buffer(flip_uniform_buffer, 0, @core.TypedArray::uint32([1]))
  bd.size = 4
  bd.usage = @gpu.GPU_BUFFER_USAGE_UNIFORM
  let no_flip_uniform_buffer = device.create_buffer(bd)
  bd.reset()
  let smd = _web_gpu_texture_pass_utils_shader_module_descriptor
  smd.label = Some("mipmap")
  smd.code = _web_gpu_texture_pass_utils_mipmap_source
  let mipmap_shader_module = device.create_shader_module(smd)
  smd.reset()
  {
    data: @webgl.WeakMap::new(),
    device,
    mipmap_sampler,
    flip_y_sampler,
    flip_uniform_buffer,
    no_flip_uniform_buffer,
    transfer_pipelines: Map([]),
    mipmap_shader_module,
  }
}

///|
/// `this.get( textureGPU )` of the DataMap.
fn WebGPUTexturePassUtils::get(
  self : WebGPUTexturePassUtils,
  texture_gpu : @gpu.GPUTexture,
) -> WebGPUTexturePassData {
  let key = @core.JsValue::of(texture_gpu)
  match self.data.get(key) {
    Some(d) => d
    None => {
      let d = { layers: None, }
      self.data.set(key, d)
      d
    }
  }
}

///|
/// `getTransferPipeline( format, textureBindingViewDimension )`.
pub fn WebGPUTexturePassUtils::get_transfer_pipeline(
  self : WebGPUTexturePassUtils,
  format : String,
  texture_binding_view_dimension : String?,
) -> @gpu.GPURenderPipeline {
  let texture_binding_view_dimension = match texture_binding_view_dimension {
    Some(d) if d != "" => d
    _ => "2d-array"
  }
  let key = "\{format}-\{texture_binding_view_dimension}"
  match self.transfer_pipelines.get(key) {
    Some(p) => p
    None => {
      let rpd = _web_gpu_texture_pass_utils_render_pipeline_descriptor
      rpd.label = Some("mipmap-\{format}-\{texture_binding_view_dimension}")
      rpd.vertex = Some(
        @gpu.GPUVertexState::new(module_=self.mipmap_shader_module),
      )
      rpd.fragment = Some(
        @gpu.GPUFragmentState::new(
          module_=self.mipmap_shader_module,
          entry_point="main_\{texture_binding_view_dimension.replace(old="-", new="_")}",
          targets=[@gpu.GPUColorTargetState::new(format~)],
        ),
      )
      rpd.layout = Some(Auto)
      let pipeline = self.device.create_render_pipeline(rpd)
      rpd.reset()
      self.transfer_pipelines[key] = pipeline
      pipeline
    }
  }
}

///|
/// `flipY( textureGPU, textureGPUDescriptor, baseArrayLayer = 0 )`.
pub fn WebGPUTexturePassUtils::flip_y(
  self : WebGPUTexturePassUtils,
  texture_gpu : @gpu.GPUTexture,
  texture_gpu_descriptor : @gpu.GPUTextureDescriptor,
  base_array_layer~ : Int32 = 0,
) -> Unit {
  let format = texture_gpu_descriptor.format.unwrap()
  let width = texture_gpu_descriptor.size.width
  let height = texture_gpu_descriptor.size.height
  let td = _web_gpu_texture_pass_utils_texture_descriptor
  td.size.width = width
  td.size.height = height
  td.format = Some(format)
  td.usage = Some(
    @gpu.GPU_TEXTURE_USAGE_RENDER_ATTACHMENT |
    @gpu.GPU_TEXTURE_USAGE_TEXTURE_BINDING,
  )
  let temp_texture = self.device.create_texture(td)
  td.reset()
  let copy_transfer_pipeline = self.get_transfer_pipeline(
    format,
    texture_gpu.texture_binding_view_dimension(),
  )
  let flip_transfer_pipeline = self.get_transfer_pipeline(
    format,
    temp_texture.texture_binding_view_dimension(),
  )
  let command_encoder = self.device.create_command_encoder(
    descriptor=_web_gpu_texture_pass_utils_command_encoder_descriptor,
  )
  let pass = fn(
    pipeline : @gpu.GPURenderPipeline,
    source_texture : @gpu.GPUTexture,
    source_array_layer : Int32,
    destination_texture : @gpu.GPUTexture,
    destination_array_layer : Int32,
    flip_y : Bool,
  ) {
    let bind_group_layout = pipeline.get_bind_group_layout(0) // @TODO: Consider making this static.
    let vd = _web_gpu_texture_pass_utils_view_descriptor
    vd.dimension = Some(
      match source_texture.texture_binding_view_dimension() {
        Some(d) if d != "" => d
        _ => "2d-array"
      },
    )
    vd.mip_level_count = Some(1)
    let source_view = source_texture.create_view(descriptor=vd)
    vd.reset()
    let bgd = _web_gpu_texture_pass_utils_bind_group_descriptor
    bgd.layout = Some(bind_group_layout)
    bgd.entries.push(
      @gpu.GPUBindGroupEntry::new(
        binding=0,
        resource=Sampler(self.flip_y_sampler),
      ),
    )
    bgd.entries.push(
      @gpu.GPUBindGroupEntry::new(binding=1, resource=TextureView(source_view)),
    )
    bgd.entries.push(
      @gpu.GPUBindGroupEntry::new(
        binding=2,
        resource=BufferBinding(
          @gpu.GPUBufferBinding::new(
            buffer=if flip_y {
              self.flip_uniform_buffer
            } else {
              self.no_flip_uniform_buffer
            },
          ),
        ),
      ),
    )
    let bind_group = self.device.create_bind_group(bgd)
    bgd.reset()
    vd.dimension = Some("2d")
    vd.mip_level_count = Some(1)
    vd.base_array_layer = Some(destination_array_layer)
    vd.array_layer_count = Some(1)
    let destination_view = destination_texture.create_view(descriptor=vd)
    vd.reset()
    let ca = _web_gpu_texture_pass_utils_color_attachment
    ca.view = Some(destination_view)
    ca.load_op = Some(GPULoadOp_Clear)
    ca.store_op = Some(GPUStoreOp_Store)
    let rpd = _web_gpu_texture_pass_utils_render_pass_descriptor
    rpd.color_attachments.push(ca)
    let pass_encoder = command_encoder.begin_render_pass(rpd)
    rpd.reset()
    ca.reset()
    pass_encoder.set_pipeline(pipeline)
    pass_encoder.set_bind_group(0, bind_group)
    pass_encoder.draw(
      3,
      instance_count=1,
      first_vertex=0,
      first_instance=source_array_layer,
    )
    pass_encoder.end()
  }
  pass(
    copy_transfer_pipeline, texture_gpu, base_array_layer, temp_texture, 0, false,
  )
  pass(
    flip_transfer_pipeline, temp_texture, 0, texture_gpu, base_array_layer, true,
  )
  wgpu_submit(self.device, command_encoder.finish())
  temp_texture.destroy()
}

///|
/// `generateMipmaps( textureGPU, encoder = null )`.
pub fn WebGPUTexturePassUtils::generate_mipmaps(
  self : WebGPUTexturePassUtils,
  texture_gpu : @gpu.GPUTexture,
  encoder? : @gpu.GPUCommandEncoder,
) -> Unit {
  let texture_data = self.get(texture_gpu)
  let passes = match texture_data.layers {
    Some(layers) => layers
    None => self._mipmap_create_bundles(texture_gpu)
  }
  let command_encoder = match encoder {
    Some(e) => e
    None => {
      let ced = _web_gpu_texture_pass_utils_command_encoder_descriptor
      ced.label = Some("mipmapEncoder")
      let e = self.device.create_command_encoder(descriptor=ced)
      ced.reset()
      e
    }
  }
  self._mipmap_run_bundles(command_encoder, passes)
  if encoder is None {
    wgpu_submit(self.device, command_encoder.finish())
  }
  texture_data.layers = Some(passes)
}

///|
/// `_mipmapCreateBundles( textureGPU )`.
fn WebGPUTexturePassUtils::_mipmap_create_bundles(
  self : WebGPUTexturePassUtils,
  texture_gpu : @gpu.GPUTexture,
) -> Array[WebGPUMipmapPass] {
  let texture_binding_view_dimension = match
    texture_gpu.texture_binding_view_dimension() {
    Some(d) if d != "" => d
    _ => "2d-array"
  }
  let pipeline = self.get_transfer_pipeline(
    texture_gpu.format(),
    Some(texture_binding_view_dimension),
  )
  let bind_group_layout = pipeline.get_bind_group_layout(0) // @TODO: Consider making this static.
  let passes = []
  let vd = _web_gpu_texture_pass_utils_view_descriptor
  let bgd = _web_gpu_texture_pass_utils_bind_group_descriptor
  for base_mip_level = 1
      base_mip_level < texture_gpu.mip_level_count()
      base_mip_level = base_mip_level + 1 {
    for base_array_layer = 0
        base_array_layer < texture_gpu.depth_or_array_layers()
        base_array_layer = base_array_layer + 1 {
      vd.dimension = Some(texture_binding_view_dimension)
      vd.base_mip_level = Some(base_mip_level - 1)
      vd.mip_level_count = Some(1)
      let source_view = texture_gpu.create_view(descriptor=vd)
      vd.reset()
      bgd.layout = Some(bind_group_layout)
      bgd.entries.push(
        @gpu.GPUBindGroupEntry::new(
          binding=0,
          resource=Sampler(self.mipmap_sampler),
        ),
      )
      bgd.entries.push(
        @gpu.GPUBindGroupEntry::new(
          binding=1,
          resource=TextureView(source_view),
        ),
      )
      bgd.entries.push(
        @gpu.GPUBindGroupEntry::new(
          binding=2,
          resource=BufferBinding(
            @gpu.GPUBufferBinding::new(buffer=self.no_flip_uniform_buffer),
          ),
        ),
      )
      let bind_group = self.device.create_bind_group(bgd)
      bgd.reset()
      vd.dimension = Some("2d")
      vd.base_mip_level = Some(base_mip_level)
      vd.mip_level_count = Some(1)
      vd.base_array_layer = Some(base_array_layer)
      vd.array_layer_count = Some(1)
      let destination_view = texture_gpu.create_view(descriptor=vd)
      vd.reset()
      let pass_color_attachment = @gpu.GPURenderPassColorAttachment::default()
      pass_color_attachment.view = Some(destination_view)
      pass_color_attachment.load_op = Some(GPULoadOp_Clear)
      pass_color_attachment.store_op = Some(GPUStoreOp_Store)
      let pass_descriptor = @gpu.GPURenderPassDescriptor::default()
      pass_descriptor.color_attachments.push(pass_color_attachment)
      let rbd = _web_gpu_texture_pass_utils_render_bundle_encoder_descriptor
      rbd.color_formats = Some([texture_gpu.format()])
      let pass_encoder = self.device.create_render_bundle_encoder(rbd)
      rbd.reset()
      pass_encoder.set_pipeline(pipeline)
      pass_encoder.set_bind_group(0, bind_group)
      pass_encoder.draw(
        3,
        instance_count=1,
        first_vertex=0,
        first_instance=base_array_layer,
      )
      passes.push({ render_bundles: [pass_encoder.finish()], pass_descriptor, })
    }
  }
  passes
}

///|
/// `_mipmapRunBundles( commandEncoder, passes )`.
fn WebGPUTexturePassUtils::_mipmap_run_bundles(
  self : WebGPUTexturePassUtils,
  command_encoder : @gpu.GPUCommandEncoder,
  passes : Array[WebGPUMipmapPass],
) -> Unit {
  ignore(self)
  for pass in passes {
    let pass_encoder = command_encoder.begin_render_pass(pass.pass_descriptor)
    pass_encoder.execute_bundles(pass.render_bundles)
    pass_encoder.end()
  }
}
