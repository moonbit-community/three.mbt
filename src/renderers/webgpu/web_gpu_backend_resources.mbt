// WebGPUBackend.js, continued: textures, programs, pipelines, bundles, bindings,
// attributes, the canvas, features, copies and disposal.

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn update_sampler(
  self,
  _,
  binding,
) {
  self.texture_utils.update_sampler(binding)
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn destroy_sampler(
  self,
  _,
  binding,
) {
  self.texture_utils.destroy_sampler(binding)
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn create_default_texture(
  self,
  _,
  texture,
) {
  self.texture_utils.create_default_texture(texture)
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn create_texture(
  self,
  _,
  texture,
  options,
) {
  self.texture_utils.create_texture(texture, options)
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn update_texture(
  self,
  _,
  texture,
  options,
) {
  self.texture_utils.update_texture(texture, options)
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn generate_mipmaps(
  self,
  _,
  texture,
) {
  self.texture_utils.generate_mipmaps(texture)
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn destroy_texture(
  self,
  _,
  texture,
  is_default_texture,
) {
  self.texture_utils.destroy_texture(
    texture,
    is_default_texture=is_default_texture.unwrap_or(false),
  )
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn copy_texture_to_buffer(
  self,
  _,
  texture,
  x,
  y,
  width,
  height,
  face_index,
  on_done,
) {
  self.texture_utils.copy_texture_to_buffer(
    texture,
    x,
    y,
    width,
    height,
    face_index,
    fn(data) { on_done(Some(data)) },
  )
}

///|
/// `this.timestampQueryPool[ type ]`.
fn WebGPUBackend::timestamp_query_pool(
  self : WebGPUBackend,
  type_ : String,
) -> @nodes.TimestampQueryPool? {
  if type_ == @core.TimestampQuery_COMPUTE {
    self.base().timestamp_query_pool_compute
  } else {
    self.base().timestamp_query_pool_render
  }
}

///|
/// `initTimestampQuery( type, uid, descriptor )`: `set_timestamp_writes` is
/// `descriptor.timestampWrites = ...`.
pub fn WebGPUBackend::init_timestamp_query(
  self : WebGPUBackend,
  type_ : String,
  uid : String?,
  set_timestamp_writes : (@gpu.GPURenderPassTimestampWrites?) -> Unit,
) -> Unit {
  let base = self.base()
  if !base.track_timestamp {
    set_timestamp_writes(None)
    return
  }
  let timestamp_query_pool = match self.timestamp_query_pool(type_) {
    Some(p) => p
    None => {
      // TODO: Variable maxQueries?
      let p = WebGPUTimestampQueryPool::new(
        self.gpu_device(),
        type_,
        max_queries=2048,
      )
      if type_ == @core.TimestampQuery_COMPUTE {
        base.timestamp_query_pool_compute = Some(p)
      } else {
        base.timestamp_query_pool_render = Some(p)
      }
      p
    }
  }
  let base_offset = timestamp_query_pool.allocate_queries_for_context(
    uid.unwrap_or("undefined"),
  )
  let tw = _web_gpu_backend_render_pass_timestamp_writes
  tw.query_set = WebGPUTimestampQueryPool::of(timestamp_query_pool).query_set
  tw.beginning_of_pass_write_index = base_offset
  tw.end_of_pass_write_index = base_offset.map(fn(o) { o + 1 })
  set_timestamp_writes(Some(tw))
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn create_node_builder(
  _,
  _,
  object,
  renderer,
) {
  WGSLNodeBuilder::new(object, renderer)
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn create_program(
  self,
  _,
  program,
) {
  let program_gpu = self.get(@core.JsValue::of(program))
  let smd = _web_gpu_backend_shader_module_descriptor
  smd.label = Some(
    program.stage + (if program.name != "" { "_\{program.name}" } else { "" }),
  )
  smd.code = program.code
  let module_ = self.gpu_device().create_shader_module(smd)
  program_gpu.set(
    "module",
    @core.JsValue::of(WebGPUProgramModule::{ module_, entry_point: "main", }),
  )
  smd.reset()
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn destroy_program(
  self,
  _,
  program,
) {
  self.delete(@core.JsValue::of(program))
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn create_render_pipeline(
  self,
  _,
  render_object,
  promises,
) {
  self.pipeline_utils.create_render_pipeline(render_object, promises)
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn create_compute_pipeline(
  self,
  _,
  compute_pipeline,
  bindings,
  promises,
) {
  self.pipeline_utils.create_compute_pipeline(
    compute_pipeline, bindings, promises,
  )
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn has_bundles(_) {
  true
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn begin_bundle(
  self,
  _,
  render_context,
) {
  let render_context_data = self.render_context_data(render_context)
  render_context_data.set(
    "_currentPass",
    render_context_data.get("currentPass"),
  )
  render_context_data.set(
    "_currentSets",
    render_context_data.get("currentSets"),
  )
  render_context_data.set(
    "currentSets",
    @core.JsValue::of(WebGPUCurrentSets::new()),
  )
  wgpu_set_current_pass(
    render_context_data,
    Some(Bundle(self.pipeline_utils.create_bundle_encoder(render_context))),
  )
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn finish_bundle(
  self,
  _,
  render_context,
  bundle,
) {
  let render_context_data = self.render_context_data(render_context)
  let bundle_encoder = match wgpu_current_pass(render_context_data) {
    Some(Bundle(b)) => b
    _ => abort("TypeError: bundleEncoder.finish is not a function")
  }
  let bundle_gpu = bundle_encoder.finish()
  self
  .get(@core.JsValue::of(bundle))
  .set("bundleGPU", @core.JsValue::of(bundle_gpu))
  // restore render pass state
  render_context_data.set(
    "currentSets",
    render_context_data.get("_currentSets"),
  )
  render_context_data.set(
    "currentPass",
    render_context_data.get("_currentPass"),
  )
  render_context_data.set("_currentPass", @core.JsValue::null())
  render_context_data.set("_currentSets", @core.JsValue::null())
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn add_bundle(
  self,
  _,
  render_context,
  bundle,
) {
  let render_context_data = self.render_context_data(render_context)
  let render_bundles : Array[@gpu.GPURenderBundle] = render_context_data
    .get("renderBundles")
    .cast()
  render_bundles.push(
    self.get(@core.JsValue::of(bundle)).get("bundleGPU").cast(),
  )
}

///|
/// `uniformBuffer.id` (`NodeUniformsGroup` only; `undefined` otherwise).
fn wgpu_binding_id(binding : @nodes.Binding) -> String {
  match @nodes.NodeUniformsGroup::of(binding) {
    Some(g) => g.id.to_string()
    None => "undefined"
  }
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn create_uniform_buffer(
  self,
  _,
  uniform_buffer,
) {
  let uniform_buffer_data = self.get(@core.JsValue::of(uniform_buffer))
  if uniform_buffer_data.get("buffer").is_undefined() {
    let byte_length = uniform_buffer.byte_length()
    let usage = @gpu.GPU_BUFFER_USAGE_UNIFORM | @gpu.GPU_BUFFER_USAGE_COPY_DST
    let visibilities = []
    if (uniform_buffer.visibility & GPUShaderStage_VERTEX) != 0 {
      visibilities.push("vertex")
    }
    if (uniform_buffer.visibility & GPUShaderStage_FRAGMENT) != 0 {
      visibilities.push("fragment")
    }
    if (uniform_buffer.visibility & GPUShaderStage_COMPUTE) != 0 {
      visibilities.push("compute")
    }
    let buffer_visibility = "(\{visibilities.join(",")})"
    let bd = _web_gpu_backend_buffer_descriptor
    bd.label = Some(
      "bindingBuffer\{wgpu_binding_id(uniform_buffer)}_\{uniform_buffer.name}_\{buffer_visibility}",
    )
    bd.size = byte_length
    bd.usage = usage
    let buffer_gpu = self.gpu_device().create_buffer(bd)
    bd.reset()
    uniform_buffer_data.set("buffer", @core.JsValue::of(buffer_gpu))
  }
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn destroy_uniform_buffer(
  self,
  _,
  uniform_buffer,
) {
  let uniform_buffer_data = self.get(@core.JsValue::of(uniform_buffer))
  let buffer : @gpu.GPUBuffer = uniform_buffer_data.get("buffer").cast()
  buffer.destroy()
  self.delete(@core.JsValue::of(uniform_buffer))
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn create_bindings(
  self,
  _,
  bind_group,
  bindings,
  cache_key,
) {
  self.binding_utils.create_bindings(bind_group, bindings, cache_key, 0)
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn update_bindings(
  self,
  _,
  bind_group,
  bindings,
  cache_key,
  version,
) {
  self.binding_utils.create_bindings(bind_group, bindings, cache_key, version)
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn update_binding(
  self,
  _,
  binding,
) {
  self.binding_utils.update_binding(binding)
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn delete_bind_group_data(
  self,
  _,
  bind_group,
) {
  self.binding_utils.delete_bind_group_data(bind_group)
}

///|
/// `attribute.isStorageBufferAttribute || attribute.isStorageInstancedBufferAttribute`.
fn wgpu_is_storage_attribute(attribute : @nodes.AttributeBuffer) -> Bool {
  match attribute {
    Buffer(a) => a.kind is (StorageAttribute | StorageInstancedAttribute)
    _ => false
  }
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn create_index_attribute(
  self,
  _,
  attribute,
) {
  let mut usage = @gpu.GPU_BUFFER_USAGE_INDEX |
    @gpu.GPU_BUFFER_USAGE_COPY_SRC |
    @gpu.GPU_BUFFER_USAGE_COPY_DST
  if wgpu_is_storage_attribute(attribute) {
    usage = usage | @gpu.GPU_BUFFER_USAGE_STORAGE
  }
  self.attribute_utils.create_attribute(attribute, usage)
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn create_attribute(
  self,
  _,
  attribute,
) {
  self.attribute_utils.create_attribute(
    attribute,
    @gpu.GPU_BUFFER_USAGE_VERTEX |
    @gpu.GPU_BUFFER_USAGE_COPY_SRC |
    @gpu.GPU_BUFFER_USAGE_COPY_DST,
  )
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn create_storage_attribute(
  self,
  _,
  attribute,
) {
  self.attribute_utils.create_attribute(
    attribute,
    @gpu.GPU_BUFFER_USAGE_STORAGE |
    @gpu.GPU_BUFFER_USAGE_VERTEX |
    @gpu.GPU_BUFFER_USAGE_COPY_SRC |
    @gpu.GPU_BUFFER_USAGE_COPY_DST,
  )
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn create_indirect_storage_attribute(
  self,
  _,
  attribute,
) {
  self.attribute_utils.create_attribute(
    attribute,
    @gpu.GPU_BUFFER_USAGE_STORAGE |
    @gpu.GPU_BUFFER_USAGE_INDIRECT |
    @gpu.GPU_BUFFER_USAGE_COPY_SRC |
    @gpu.GPU_BUFFER_USAGE_COPY_DST,
  )
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn update_attribute(
  self,
  _,
  attribute,
) {
  self.attribute_utils.update_attribute(attribute)
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn destroy_attribute(
  self,
  _,
  attribute,
) {
  self.attribute_utils.destroy_attribute(attribute)
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn update_size(self, _) {
  self.update_size_()
}

///|
/// `updateSize()`: triggers an update of the default render pass descriptor.
fn WebGPUBackend::update_size_(self : WebGPUBackend) -> Unit {
  self.delete(@core.JsValue::of(self.renderer().get_canvas_target()))
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn destroy_canvas_target(
  self,
  _,
  canvas_target,
) {
  self.texture_utils.destroy_texture(canvas_target.color_texture)
  self.texture_utils.destroy_texture(canvas_target.depth_texture)
  self.delete(@core.JsValue::of(canvas_target))
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn has_feature(
  self,
  _,
  name,
) {
  self.has_feature_(name)
}

///|
/// `hasFeature( name )`.
pub fn WebGPUBackend::has_feature_(self : WebGPUBackend, name : String) -> Bool {
  let name = match gpu_feature_map(name) {
    Some(n) => n
    None => name
  }
  match self.device {
    Some(device) => device.features().has(name)
    None =>
      abort("TypeError: Cannot read properties of null (reading 'features')")
  }
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn copy_texture_to_texture(
  self,
  _,
  src_texture,
  dst_texture,
  src_region,
  dst_position,
  src_level,
  dst_level,
) {
  let mut dst_x = 0
  let mut dst_y = 0
  let mut dst_z = 0
  let mut src_x = 0
  let mut src_y = 0
  let mut src_z = 0
  let mut src_width = src_texture.image().width().to_int()
  let mut src_height = src_texture.image().height().to_int()
  let mut src_depth = 1
  match src_region {
    Some(Box3(r)) => {
      src_x = r.min.x.to_int()
      src_y = r.min.y.to_int()
      src_z = r.min.z.to_int()
      src_width = (r.max.x - r.min.x).to_int()
      src_height = (r.max.y - r.min.y).to_int()
      src_depth = (r.max.z - r.min.z).to_int()
    }
    Some(Box2(r)) => {
      // Assume it's a Box2
      src_x = r.min.x.to_int()
      src_y = r.min.y.to_int()
      src_width = (r.max.x - r.min.x).to_int()
      src_height = (r.max.y - r.min.y).to_int()
      src_depth = 1
    }
    None => ()
  }
  match dst_position {
    Some(Vec3(p)) => {
      dst_x = p.x.to_int()
      dst_y = p.y.to_int()
      dst_z = p.z.to_int()
    }
    Some(Vec2(p)) => {
      dst_x = p.x.to_int()
      dst_y = p.y.to_int()
      dst_z = 0
    }
    None => ()
  }
  let ced = _web_gpu_backend_command_encoder_descriptor
  ced.label = Some("copyTextureToTexture_\{src_texture.id}_\{dst_texture.id}")
  let encoder = self.gpu_device().create_command_encoder(descriptor=ced)
  ced.reset()
  let source_gpu : @gpu.GPUTexture? = wgpu_opt(
    self.get(@core.JsValue::of(src_texture)),
    "texture",
  )
  let destination_gpu : @gpu.GPUTexture? = wgpu_opt(
    self.get(@core.JsValue::of(dst_texture)),
    "texture",
  )
  let src = _web_gpu_backend_texel_copy_texture_info_src
  let dst = _web_gpu_backend_texel_copy_texture_info_dst
  src.texture = source_gpu
  src.mip_level = Some(src_level)
  src.origin = Some(@gpu.GPUOrigin3D::new(x=src_x, y=src_y, z=src_z))
  dst.texture = destination_gpu
  dst.mip_level = Some(dst_level)
  dst.origin = Some(@gpu.GPUOrigin3D::new(x=dst_x, y=dst_y, z=dst_z))
  let extent = _web_gpu_backend_extent3d
  extent.width = src_width
  extent.height = Some(src_height)
  extent.depth_or_array_layers = Some(src_depth)
  encoder.copy_texture_to_texture(src, dst, extent)
  src.reset()
  dst.reset()
  extent.reset()
  wgpu_submit(self.gpu_device(), encoder.finish())
  if dst_level == 0 &&
    dst_texture.generate_mipmaps == true &&
    dst_texture.mipmaps_auto_update == true {
    self.texture_utils.generate_mipmaps(dst_texture)
  }
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn copy_framebuffer_to_texture(
  self,
  _,
  texture,
  render_context,
  rectangle,
) {
  // the source: the render context, or the render target's record outside a render
  let (key, render_target, depth_texture, textures, depth, stencil, context) = match
    render_context {
    Context(rc) =>
      (
        @core.JsValue::of(rc),
        rc.render_target,
        rc.depth_texture,
        rc.textures,
        rc.depth,
        rc.stencil,
        Some(rc),
      )
    TargetData(data) =>
      (
        @core.JsValue::of(data),
        data.render_target,
        data.depth_texture,
        data.textures,
        data.depth.unwrap_or(false),
        data.stencil.unwrap_or(false),
        None,
      )
    NoContext => abort("TypeError: Invalid value used as weak map key")
  }
  let render_context_data = self.get(key)
  let source_gpu : @gpu.GPUTexture = match render_target {
    Some(_) =>
      if texture.is_depth_texture() {
        self
        .get(@core.JsValue::of(depth_texture.unwrap()))
        .get("texture")
        .cast()
      } else {
        self.get(@core.JsValue::of(textures.unwrap()[0])).get("texture").cast()
      }
    None =>
      if texture.is_depth_texture() {
        self.texture_utils.get_depth_buffer(depth~, stencil~)
      } else {
        self.context().get_current_texture()
      }
  }
  let destination_gpu : @gpu.GPUTexture = self
    .get(@core.JsValue::of(texture))
    .get("texture")
    .cast()
  if source_gpu.format() != destination_gpu.format() {
    @core.error(
      "WebGPUBackend: copyFramebufferToTexture: Source and destination formats do not match. \{source_gpu.format()} \{destination_gpu.format()}",
    )
    return
  }
  let generate_mipmaps = texture.generate_mipmaps == true &&
    texture.mipmaps_auto_update == true &&
    destination_gpu.mip_level_count() > 1
  match context {
    Some(rc) if wgpu_truthy(render_context_data.get("encoder")) &&
      self._is_render_camera_depth_array(rc) == true => {
      // Layered draws are only executed in finishRender(), so preserve this copy as a render-stage boundary.
      let bundles = self._finish_array_camera_bundle_encoders(
        render_context_data,
      )
      let stages : Array[WebGPURenderStage] = render_context_data
        .get("arrayCameraRenderStages")
        .cast()
      stages.push({
        bundles,
        framebuffer_copy: Some({
          texture,
          source_gpu,
          destination_gpu,
          rectangle: @math.Vector4::new(
            rectangle.x,
            rectangle.y,
            rectangle.z,
            rectangle.w,
          ),
          // ViewportTextureNode restores this flag before the deferred copy executes.
          generate_mipmaps,
        }),
      })
      self._create_array_camera_bundle_encoders(rc, render_context_data)
      return
    }
    _ => ()
  }
  let current_pass = wgpu_current_pass(render_context_data)
  let encoder = match current_pass {
    Some(pass) => {
      pass.pass("end").end()
      render_context_data.get("encoder").cast()
    }
    None => {
      let ced = _web_gpu_backend_command_encoder_descriptor
      ced.label = Some("copyFramebufferToTexture_\{texture.id}")
      let e = self.gpu_device().create_command_encoder(descriptor=ced)
      ced.reset()
      e
    }
  }
  // mipmaps must be genereated with the same encoder otherwise the copied texture data
  // might be out-of-sync, see #31768
  self._copy_framebuffer_to_texture(
    encoder, texture, source_gpu, destination_gpu, rectangle, 0, generate_mipmaps,
  )
  match current_pass {
    Some(_) => {
      let rc = context.unwrap()
      let descriptor : @gpu.GPURenderPassDescriptor = render_context_data
        .get("descriptor")
        .cast()
      for attachment in descriptor.color_attachments {
        attachment.load_op = Some(GPULoadOp_Load)
      }
      if rc.depth {
        descriptor.depth_stencil_attachment.unwrap().depth_load_op = Some(
          GPULoadOp_Load,
        )
      }
      if rc.stencil {
        descriptor.depth_stencil_attachment.unwrap().stencil_load_op = Some(
          GPULoadOp_Load,
        )
      }
      wgpu_set_current_pass(
        render_context_data,
        Some(Pass(encoder.begin_render_pass(descriptor))),
      )
      self._reset_render_context_data(render_context_data)
      if rc.viewport {
        self.update_viewport_(rc)
      }
      if rc.scissor {
        self.update_scissor(rc)
      }
    }
    None => wgpu_submit(self.gpu_device(), encoder.finish())
  }
}

///|
/// `_copyFramebufferToTexture( encoder, texture, sourceGPU, destinationGPU, rectangle,
/// sourceLayer = 0, generateMipmaps = texture.generateMipmaps )`.
fn WebGPUBackend::_copy_framebuffer_to_texture(
  self : WebGPUBackend,
  encoder : @gpu.GPUCommandEncoder,
  texture : @core.Texture,
  source_gpu : @gpu.GPUTexture,
  destination_gpu : @gpu.GPUTexture,
  rectangle : @math.Vector4,
  source_layer : Int32,
  generate_mipmaps : Bool,
) -> Unit {
  let src = _web_gpu_backend_texel_copy_texture_info_src
  let dst = _web_gpu_backend_texel_copy_texture_info_dst
  src.texture = Some(source_gpu)
  src.origin = Some(
    @gpu.GPUOrigin3D::new(
      x=rectangle.x.to_int(),
      y=rectangle.y.to_int(),
      z=source_layer,
    ),
  )
  dst.texture = Some(destination_gpu)
  let extent = _web_gpu_backend_extent3d
  extent.width = rectangle.z.to_int()
  extent.height = Some(rectangle.w.to_int())
  encoder.copy_texture_to_texture(src, dst, extent)
  src.reset()
  dst.reset()
  extent.reset()
  if generate_mipmaps == true && destination_gpu.mip_level_count() > 1 {
    self.texture_utils.generate_mipmaps(texture, encoder~)
  }
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn has_compatibility(
  self,
  _,
  name,
) {
  match self._compatibility.get(name) {
    Some(v) => v
    None => false
  }
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn dispose(
  self,
  backend,
  on_done,
) {
  backend.dispose_base()
  self.binding_utils.dispose()
  self.texture_utils.dispose()
  for _, buffer in self.occluded_resolve_cache {
    buffer.destroy()
  }
  self.occluded_resolve_cache.clear()
  match self.device {
    Some(device) if backend.parameters.get("device").is_undefined() =>
      device.destroy()
    _ => ()
  }
  on_done()
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn get_max_anisotropy(
  self,
  _,
) {
  self.capabilities.get_max_anisotropy()
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn get_uniform_buffer_limit(
  self,
  _,
) {
  self.capabilities.get_uniform_buffer_limit()
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn device(self, _) {
  match self.device {
    Some(d) => @core.JsValue::of(d)
    None => @core.JsValue::null()
  }
}
