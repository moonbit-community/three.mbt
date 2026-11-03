// renderers/webgpu/utils/WebGPUUtils.js: formats, sample counts and topologies of the
// current render context, and `submit( device, command )`.

///|
/// `WebGPUUtils`.
pub(all) struct WebGPUUtils {
  /// `backend`, linked right after the backend is built.
  mut backend_ : WebGPUBackend?
  /// `_preferredCanvasFormat`; `None` is `null`.
  mut _preferred_canvas_format : String?
}

///|
/// `new WebGPUUtils( backend )` (the backend is linked by `WebGPUBackend::new`).
fn WebGPUUtils::new() -> WebGPUUtils {
  { backend_: None, _preferred_canvas_format: None, }
}

///|
/// `this.backend`.
pub fn WebGPUUtils::backend(self : WebGPUUtils) -> WebGPUBackend {
  self.backend_.unwrap()
}

///|
/// `getCurrentDepthStencilFormat( renderContext )`; `None` is `undefined`.
pub fn WebGPUUtils::get_current_depth_stencil_format(
  self : WebGPUUtils,
  render_context : @nodes.RenderContext,
) -> String? {
  let mut format = None
  if render_context.depth {
    match render_context.depth_texture {
      Some(depth_texture) => format = self.get_texture_format_gpu(depth_texture)
      None =>
        if render_context.stencil {
          if self.backend().renderer().reversed_depth_buffer == true {
            format = Some(GPUTextureFormat_Depth32FloatStencil8)
          } else {
            format = Some(GPUTextureFormat_Depth24PlusStencil8)
          }
        } else if self.backend().renderer().reversed_depth_buffer == true {
          format = Some(GPUTextureFormat_Depth32Float)
        } else {
          format = Some(GPUTextureFormat_Depth24Plus)
        }
    }
  }
  format
}

///|
/// `getTextureFormatGPU( texture )`: `backend.get( texture ).format`.
pub fn WebGPUUtils::get_texture_format_gpu(
  self : WebGPUUtils,
  texture : @core.Texture,
) -> String? {
  wgpu_opt(self.backend().get(@core.JsValue::of(texture)), "format")
}

///|
/// The result of `getTextureSampleData( texture )`.
pub(all) struct WebGPUTextureSampleData {
  samples : Int32
  primary_samples : Int32
  is_msaa : Bool
}

///|
/// `getTextureSampleData( texture )`.
pub fn WebGPUUtils::get_texture_sample_data(
  self : WebGPUUtils,
  texture : @core.Texture,
) -> WebGPUTextureSampleData {
  let is_framebuffer_texture = texture.texture_type is FramebufferTexture
  let mut samples = 0
  if is_framebuffer_texture {
    samples = 1
  } else if texture.is_depth_texture() && texture.render_target is None {
    let texture_data = self.backend().get(@core.JsValue::of(texture))
    match wgpu_opt(texture_data, "texture") {
      Some(t) => {
        let t : @gpu.GPUTexture = t
        // use the effective sample count of the allocated texture
        samples = t.sample_count()
      }
      // otherwise use the current samples of the renderer
      None => samples = self.backend().renderer().current_samples()
    }
  } else {
    match texture.render_target {
      Some(render_target) => samples = render_target.samples
      None => ()
    }
  }
  let samples = self.get_sample_count(if samples == 0 { 1 } else { samples })
  let has_render_target = texture.render_target is Some(_)
  let is_msaa = samples > 1 &&
    has_render_target &&
    texture.is_depth_texture() != true &&
    is_framebuffer_texture != true
  let is_msaa_array_depth_texture = samples > 1 &&
    has_render_target &&
    texture.is_depth_texture() == true &&
    texture.is_array_texture == true
  let primary_samples = if is_msaa || is_msaa_array_depth_texture {
    1
  } else {
    samples
  }
  { samples, primary_samples, is_msaa, }
}

///|
/// `getCurrentColorFormat( renderContext )`; `None` is `null` / `undefined`.
pub fn WebGPUUtils::get_current_color_format(
  self : WebGPUUtils,
  render_context : @nodes.RenderContext,
) -> String? {
  match render_context.textures {
    Some(textures) =>
      if textures.length() > 0 {
        self.get_texture_format_gpu(textures[0])
      } else {
        None
      }
    None => Some(self.get_preferred_canvas_format()) // default context format
  }
}

///|
/// `getCurrentColorFormat( renderTarget )`, as `createTexture` calls it with
/// `options.renderTarget` (a render target has `textures`).
pub fn WebGPUUtils::get_current_color_format_render_target(
  self : WebGPUUtils,
  render_target : @core.RenderTarget,
) -> String? {
  let textures = render_target.textures
  if textures.length() > 0 {
    self.get_texture_format_gpu(textures[0])
  } else {
    None
  }
}

///|
/// `getCurrentColorFormats( renderContext )`.
pub fn WebGPUUtils::get_current_color_formats(
  self : WebGPUUtils,
  render_context : @nodes.RenderContext,
) -> Array[String?] {
  match render_context.textures {
    Some(textures) => textures.map(fn(t) { self.get_texture_format_gpu(t) })
    None => [Some(self.get_preferred_canvas_format())] // default context format
  }
}

///|
/// `getCurrentColorSpace( renderContext )`; `None` is `undefined`.
pub fn WebGPUUtils::get_current_color_space(
  self : WebGPUUtils,
  render_context : @nodes.RenderContext,
) -> String? {
  match render_context.textures {
    Some(textures) =>
      if textures.length() > 0 {
        Some(textures[0].color_space)
      } else {
        None
      }
    None => Some(self.backend().renderer().output_color_space)
  }
}

///|
/// `getPrimitiveTopology( object, material )`; `None` is `undefined`.
pub fn WebGPUUtils::get_primitive_topology(
  self : WebGPUUtils,
  object : @core.Object3D,
  material : @core.Material,
) -> String? {
  ignore(self)
  if object.is_points() {
    Some(GPUPrimitiveTopology_PointList)
  } else if object.is_line_segments() ||
    (object.is_mesh() && material.wireframe == Some(true)) {
    Some(GPUPrimitiveTopology_LineList)
  } else if object.is_line() {
    Some(GPUPrimitiveTopology_LineStrip)
  } else if object.is_mesh() {
    Some(GPUPrimitiveTopology_TriangleList)
  } else {
    None
  }
}

///|
/// `getStripIndexFormat( object, geometry )`; `None` is `undefined`.
pub fn WebGPUUtils::get_strip_index_format(
  self : WebGPUUtils,
  object : @core.Object3D,
  geometry : @core.BufferGeometry,
) -> String? {
  ignore(self)
  match geometry.index {
    Some(index) if object.is_line() == true && object.is_line_segments() != true =>
      if index.array().type_name() == "Uint16Array" {
        Some(GPUIndexFormat_Uint16)
      } else {
        Some(GPUIndexFormat_Uint32)
      }
    _ => None
  }
}

///|
/// `getSampleCount( sampleCount )`.
pub fn WebGPUUtils::get_sample_count(
  self : WebGPUUtils,
  sample_count : Int32,
) -> Int32 {
  ignore(self)
  if sample_count >= 4 {
    4
  } else {
    1
  }
}

///|
/// `getSampleCountRenderContext( renderContext )`.
pub fn WebGPUUtils::get_sample_count_render_context(
  self : WebGPUUtils,
  render_context : @nodes.RenderContext,
) -> Int32 {
  if render_context.textures is Some(_) {
    return self.get_sample_count(render_context.sample_count)
  }
  self.get_sample_count(self.backend().renderer().current_samples())
}

///|
/// `getPreferredCanvasFormat()`.
pub fn WebGPUUtils::get_preferred_canvas_format(self : WebGPUUtils) -> String {
  let parameters = self.backend().base().parameters
  let buffer_type = parameters.get("outputType")
  if buffer_type.is_undefined() {
    match self._preferred_canvas_format {
      Some(f) => f
      None => {
        let f = wgpu_navigator_gpu().get_preferred_canvas_format()
        self._preferred_canvas_format = Some(f)
        f
      }
    }
  } else if buffer_type.strict_equal(@core.JsValue::of(@core.UnsignedByteType)) {
    GPUTextureFormat_BGRA8Unorm
  } else if buffer_type.strict_equal(@core.JsValue::of(@core.HalfFloatType)) {
    GPUTextureFormat_RGBA16Float
  } else {
    abort("THREE.WebGPUUtils: Unsupported output buffer type.")
  }
}

///|
/// `submit( device, command )`: `device.queue.submit( [ command ] )`.
pub fn wgpu_submit(
  device : @gpu.GPUDevice,
  command : @gpu.GPUCommandBuffer,
) -> Unit {
  device.queue().submit([command])
}
