// renderers/webgpu/utils/WebGPUTextureUtils.js: GPU textures, samplers, uploads, the
// canvas color and depth buffers, readback, and `getFormat( texture, device )`.

///|
let _web_gpu_texture_utils_buffer_descriptor : @gpu.GPUBufferDescriptor = @gpu.GPUBufferDescriptor::default()

///|
let _web_gpu_texture_utils_command_encoder_descriptor : @gpu.GPUCommandEncoderDescriptor = @gpu.GPUCommandEncoderDescriptor::default()

///|
let _web_gpu_texture_utils_sampler_descriptor : @gpu.GPUSamplerDescriptor = @gpu.GPUSamplerDescriptor::default()

///|
let _web_gpu_texture_utils_texel_copy_texture_info : @gpu.GPUTexelCopyTextureInfo = @gpu.GPUTexelCopyTextureInfo::default()

///|
let _web_gpu_texture_utils_texel_copy_buffer_info : @gpu.GPUTexelCopyBufferInfo = @gpu.GPUTexelCopyBufferInfo::default()

///|
let _web_gpu_texture_utils_texel_copy_buffer_layout : @gpu.GPUTexelCopyBufferLayout = @gpu.GPUTexelCopyBufferLayout::default()

///|
let _web_gpu_texture_utils_copy_external_image_source_info : @gpu.GPUCopyExternalImageSourceInfo = @gpu.GPUCopyExternalImageSourceInfo::default()

///|
let _web_gpu_texture_utils_copy_external_image_dest_info : @gpu.GPUCopyExternalImageDestInfo = @gpu.GPUCopyExternalImageDestInfo::default()

///|
let _web_gpu_texture_utils_texture_descriptor : @gpu.GPUTextureDescriptor = @gpu.GPUTextureDescriptor::default()

///|
let _web_gpu_texture_utils_extent3d : @gpu.GPUExtent3D = @gpu.GPUExtent3D::default()

///|
/// `_compareToWebGPU[ compareFunction ]`.
fn _web_gpu_texture_utils_compare_to_web_gpu(compare : Int32) -> String? {
  match compare {
    @core.NeverCompare => Some("never")
    @core.LessCompare => Some("less")
    @core.EqualCompare => Some("equal")
    @core.LessEqualCompare => Some("less-equal")
    @core.GreaterCompare => Some("greater")
    @core.GreaterEqualCompare => Some("greater-equal")
    @core.AlwaysCompare => Some("always")
    @core.NotEqualCompare => Some("not-equal")
    _ => None
  }
}

///|
/// `_flipMap`.
let _web_gpu_texture_utils_flip_map : Array[Int32] = [0, 1, 3, 2, 4, 5]

///|
/// The texel copy origin of a copy info with `origin.z = z`.
fn wgpu_origin_z(info : @gpu.GPUTexelCopyTextureInfo, z : Int32) -> Unit {
  match info.origin {
    Some(o) => o.z = Some(z)
    None => info.origin = Some(@gpu.GPUOrigin3D::new(x=0, y=0, z~))
  }
}

///|
/// `writeTextureLayer( device, textureGPU, mipLevel, layerIndex, mipmap, dataOffset,
/// bytesPerRow, rowsPerImage, textureWidth, textureHeight )`.
fn _web_gpu_texture_utils_write_texture_layer(
  device : @gpu.GPUDevice,
  texture_gpu : @gpu.GPUTexture,
  mip_level : Int32,
  layer_index : Int32,
  mipmap : @core.DataImage,
  data_offset : Int32,
  bytes_per_row : Int32,
  rows_per_image : Int32,
  texture_width : Int32,
  texture_height : Int32,
) -> Unit {
  let info = _web_gpu_texture_utils_texel_copy_texture_info
  info.texture = Some(texture_gpu)
  info.mip_level = Some(mip_level)
  wgpu_origin_z(info, layer_index)
  let layout = _web_gpu_texture_utils_texel_copy_buffer_layout
  layout.offset = Some(data_offset)
  layout.bytes_per_row = Some(bytes_per_row)
  layout.rows_per_image = Some(rows_per_image)
  let extent = _web_gpu_texture_utils_extent3d
  extent.width = texture_width
  extent.height = Some(texture_height)
  device
  .queue()
  .write_texture(info, wgpu_image_data(mipmap.data), layout, extent)
  info.reset()
  layout.reset()
  extent.reset()
}

///|
/// `image.data` as a buffer source (`undefined` when absent).
fn wgpu_image_data(data : @core.TypedArray?) -> @core.JsValue {
  match data {
    Some(d) => @core.JsValue::of(d)
    None => @core.JsValue::undefined()
  }
}

///|
/// A cached sampler: `{ sampler, usedTimes }`.
priv struct WebGPUSamplerData {
  sampler : @gpu.GPUSampler
  mut used_times : Int32
}

///|
/// `WebGPUTextureUtils`.
pub(all) struct WebGPUTextureUtils {
  /// `backend`, linked right after the backend is built.
  mut backend_ : WebGPUBackend?
  /// `_passUtils`; `None` is `null`.
  mut _pass_utils : WebGPUTexturePassUtils?
  /// `defaultTexture`, keyed by format.
  default_texture : Map[String, @core.Texture]
  /// `defaultCubeTexture`, keyed by format.
  default_cube_texture : Map[String, @core.Texture]
  /// `defaultVideoFrame` (always `null` in upstream).
  mut default_video_frame : @core.JsValue?
  /// `_samplerCache`.
  priv _sampler_cache : Map[String, WebGPUSamplerData]
}

///|
/// `new WebGPUTextureUtils( backend )` (the backend is linked by `WebGPUBackend::new`).
fn WebGPUTextureUtils::new() -> WebGPUTextureUtils {
  {
    backend_: None,
    _pass_utils: None,
    default_texture: Map([]),
    default_cube_texture: Map([]),
    default_video_frame: None,
    _sampler_cache: Map([]),
  }
}

///|
fn WebGPUTextureUtils::backend(self : WebGPUTextureUtils) -> WebGPUBackend {
  self.backend_.unwrap()
}

///|
/// `updateSampler( binding )`: the sampler key.
pub fn WebGPUTextureUtils::update_sampler(
  self : WebGPUTextureUtils,
  binding : @nodes.Binding,
) -> String {
  let backend = self.backend()
  let texture = binding.texture().unwrap()
  let texture_node = binding.texture_node()
  let is_comparison = texture.is_depth_texture() == true &&
    texture.compare_function is Some(_) &&
    @nodes.TextureNode::is_sample_compare(texture_node.unwrap()) &&
    backend.base().has_compatibility(@core.Compatibility_TEXTURE_COMPARE)
  let sampler_key = "\{texture.min_filter}-\{texture.mag_filter}-\{texture.wrap_s}-\{texture.wrap_t}-" +
    (if _web_gpu_texture_utils_has_wrap_r(texture) && texture.wrap_r != 0 {
      texture.wrap_r.to_string()
    } else {
      "0"
    }) +
    "-\{texture.anisotropy}-" +
    (if texture.is_depth_texture() == true { "1" } else { "0" }) +
    "-" +
    (if is_comparison {
      texture.compare_function.unwrap().to_string()
    } else {
      "0"
    })
  let sampler_data = match self._sampler_cache.get(sampler_key) {
    Some(d) => d
    None => {
      let sd = _web_gpu_texture_utils_sampler_descriptor
      sd.address_mode_u = Some(self._convert_address_mode(texture.wrap_s))
      sd.address_mode_v = Some(self._convert_address_mode(texture.wrap_t))
      sd.address_mode_w = Some(self._convert_address_mode(texture.wrap_r))
      sd.mag_filter = Some(self._convert_filter_mode(texture.mag_filter))
      sd.min_filter = Some(self._convert_filter_mode(texture.min_filter))
      sd.mipmap_filter = Some(
        self._convert_mipmap_filter_mode(texture.min_filter),
      )
      // Depth textures without compare function must use non-filtering (nearest) sampling
      if texture.is_depth_texture() && is_comparison == false {
        sd.mag_filter = Some(GPUFilterMode_Nearest)
        sd.min_filter = Some(GPUFilterMode_Nearest)
        sd.mipmap_filter = Some(GPUFilterMode_Nearest)
      }
      // anisotropy can only be used when all filter modes are set to linear.
      if sd.mag_filter == Some(GPUFilterMode_Linear) &&
        sd.min_filter == Some(GPUFilterMode_Linear) &&
        sd.mipmap_filter == Some(GPUFilterMode_Linear) {
        sd.max_anisotropy = Some(texture.anisotropy)
      }
      if is_comparison {
        sd.compare = _web_gpu_texture_utils_compare_to_web_gpu(
          texture.compare_function.unwrap(),
        )
      }
      let sampler = backend.gpu_device().create_sampler(descriptor=sd)
      sd.reset()
      let d = { sampler, used_times: 0, }
      self._sampler_cache[sampler_key] = d
      d
    }
  }
  let binding_data = backend.get(@core.JsValue::of(binding))
  if !binding_data
    .get("sampler")
    .strict_equal(@core.JsValue::of(sampler_data.sampler)) {
    // release the previous sampler (if any) so it can be deleted when unused
    self._release_sampler(binding_data)
    // update to new sampler data
    binding_data.set("samplerKey", @core.JsValue::of(sampler_key))
    binding_data.set("sampler", @core.JsValue::of(sampler_data.sampler))
    sampler_data.used_times += 1
  }
  sampler_key
}

///|
/// `destroySampler( binding )`.
pub fn WebGPUTextureUtils::destroy_sampler(
  self : WebGPUTextureUtils,
  binding : @nodes.Binding,
) -> Unit {
  self._release_sampler(self.backend().get(@core.JsValue::of(binding)))
}

///|
/// `_releaseSampler( bindingData )`.
fn WebGPUTextureUtils::_release_sampler(
  self : WebGPUTextureUtils,
  binding_data : @core.JsValue,
) -> Unit {
  if !binding_data.get("sampler").is_undefined() {
    let key : String = binding_data.get("samplerKey").cast()
    let sampler_data = self._sampler_cache.get(key).unwrap()
    sampler_data.used_times -= 1
    if sampler_data.used_times == 0 {
      self._sampler_cache.remove(key)
    }
    binding_data.set("sampler", @core.JsValue::undefined())
    binding_data.set("samplerKey", @core.JsValue::undefined())
  }
}

///|
/// `createDefaultTexture( texture )`.
pub fn WebGPUTextureUtils::create_default_texture(
  self : WebGPUTextureUtils,
  texture : @core.Texture,
) -> Unit {
  let format = wgpu_get_format_device(texture, self.backend().device)
  let texture_gpu = if texture.is_cube_texture() {
    self._get_default_cube_texture_gpu(format)
  } else {
    self._get_default_texture_gpu(format)
  }
  self
  .backend()
  .get(@core.JsValue::of(texture))
  .set("texture", @core.JsValue::of(texture_gpu))
}

///|
/// `texture.samples` (the canvas color and depth textures record their sample count).
let _web_gpu_texture_utils_samples : @webgl.WeakMap[@core.Texture, Int32] = @webgl.WeakMap::new()

///|
/// `createTexture( texture, options = {} )`.
pub fn WebGPUTextureUtils::create_texture(
  self : WebGPUTextureUtils,
  texture : @core.Texture,
  options : @nodes.TextureOptions,
) -> Unit {
  self._create_texture(texture, options, None)
}

///|
/// `createTexture` with `options.format`.
fn WebGPUTextureUtils::_create_texture(
  self : WebGPUTextureUtils,
  texture : @core.Texture,
  options : @nodes.TextureOptions,
  options_format : String?,
) -> Unit {
  let backend = self.backend()
  let texture_data = backend.get(@core.JsValue::of(texture))
  if wgpu_truthy(texture_data.get("initialized")) {
    // Skip creation for external XR textures - they are already set up
    if texture_data.get("externalTexture").strict_equal(@core.JsValue::of(true)) {
      return
    }
    abort("THREE.WebGPUTextureUtils: Texture already initialized.")
  }
  if texture.texture_type is ExternalTexture {
    texture_data.set(
      "texture",
      match texture.external_source {
        Some(s) => s
        None =>
          match texture.source_texture {
            Some(t) => @core.JsValue::of(t)
            None => @core.JsValue::null()
          }
      },
    )
    texture_data.set("initialized", @core.JsValue::of(true))
    return
  }
  let levels = if options.levels == 0 { 1 } else { options.levels }
  let depth = if options.depth == 0 { 1 } else { options.depth }
  let width = options.width
  let height = options.height
  let mut options_format = options_format
  if texture.texture_type is FramebufferTexture {
    match options.render_target {
      Some(rt) =>
        options_format = backend.utils.get_current_color_format_render_target(
          rt,
        )
      None => options_format = Some(backend.utils.get_preferred_canvas_format())
    }
  }
  let dimension = self._get_dimension(texture)
  let format = match texture.internal_format {
    Some(f) if f != "" => Some(f)
    _ =>
      match options_format {
        Some(f) if f != "" => Some(f)
        _ => wgpu_get_format_device(texture, backend.device)
      }
  }
  wgpu_set_opt(texture_data, "format", format)
  let { samples, primary_samples, is_msaa, } = backend.utils.get_texture_sample_data(
    texture,
  )
  let render_target = texture.render_target
  // WebGPU multisampled 2D textures can only have a single array layer.
  let use_separate_msaa_textures = samples > 1 &&
    render_target is Some(_) &&
    depth > 1 &&
    dimension == GPUTextureDimension_TwoD
  let supports_transient_attachments = @gpu.has_texture_usage_transient_attachment()
  // Layered rendering can resume after a framebuffer copy, so its attachments must support loading.
  let use_transient_attachments = supports_transient_attachments &&
    use_separate_msaa_textures == false
  let use_transient_depth_attachment = texture.is_depth_texture() == true &&
    use_transient_attachments &&
    (match render_target {
      Some(rt) =>
        rt.store_multisampled_depth_buffer == false &&
        (
          rt.stencil_buffer == false ||
          rt.store_multisampled_stencil_buffer == false
        )
      None => false
    })
  let use_transient_color_attachment = texture.is_depth_texture() != true &&
    use_transient_attachments &&
    (match render_target {
      Some(rt) => rt.store_multisampled_color_buffer == false
      None => false
    })
  let mut usage = @gpu.GPU_TEXTURE_USAGE_TEXTURE_BINDING |
    @gpu.GPU_TEXTURE_USAGE_COPY_DST |
    @gpu.GPU_TEXTURE_USAGE_COPY_SRC
  if texture.has_extension_flag("isStorageTexture") == true {
    usage = usage | @gpu.GPU_TEXTURE_USAGE_STORAGE_BINDING
  }
  if texture.is_compressed_texture() != true &&
    format != Some(GPUTextureFormat_RGB9E5UFloat) {
    usage = usage | @gpu.GPU_TEXTURE_USAGE_RENDER_ATTACHMENT
  }
  // when the multisampled data are discarded, try to use a transient attachment if possible
  if primary_samples > 1 && use_transient_depth_attachment {
    usage = @gpu.GPU_TEXTURE_USAGE_RENDER_ATTACHMENT |
      @gpu.GPU_TEXTURE_USAGE_TRANSIENT_ATTACHMENT
  }
  let texture_descriptor_gpu = @gpu.GPUTextureDescriptor::default()
  texture_descriptor_gpu.label = Some(texture.name)
  texture_descriptor_gpu.size.width = width
  texture_descriptor_gpu.size.height = Some(height)
  texture_descriptor_gpu.size.depth_or_array_layers = Some(depth)
  texture_descriptor_gpu.mip_level_count = Some(levels)
  texture_descriptor_gpu.sample_count = Some(primary_samples)
  texture_descriptor_gpu.dimension = Some(dimension)
  texture_descriptor_gpu.format = format
  texture_descriptor_gpu.usage = Some(usage)
  // texture creation
  if format is None {
    @core.warn("WebGPURenderer: Texture format not supported.")
    self.create_default_texture(texture)
    return
  }
  if texture.is_cube_texture() {
    texture_descriptor_gpu.texture_binding_view_dimension = Some(
      GPUTextureViewDimension_Cube,
    )
  }
  match
    wgpu_try(fn() {
      backend.gpu_device().create_texture(texture_descriptor_gpu)
    }) {
    Some(t) => texture_data.set("texture", @core.JsValue::of(t))
    None => {
      @core.warn(
        "WebGPURenderer: Failed to create texture with descriptor: [object Object]",
      )
      self.create_default_texture(texture)
      return
    }
  }
  if is_msaa || use_separate_msaa_textures {
    let msaa_texture_descriptor_gpu = texture_descriptor_gpu.copy()
    msaa_texture_descriptor_gpu.label = Some(
      msaa_texture_descriptor_gpu.label.unwrap() + "-msaa",
    )
    msaa_texture_descriptor_gpu.sample_count = Some(samples)
    msaa_texture_descriptor_gpu.mip_level_count = Some(1) // See https://www.w3.org/TR/webgpu/#texture-creation
    // when the multisampled data are discarded, try to use a transient attachment if possible
    if use_transient_depth_attachment || use_transient_color_attachment {
      msaa_texture_descriptor_gpu.usage = Some(
        @gpu.GPU_TEXTURE_USAGE_RENDER_ATTACHMENT |
        @gpu.GPU_TEXTURE_USAGE_TRANSIENT_ATTACHMENT,
      )
    }
    if use_separate_msaa_textures {
      let size = msaa_texture_descriptor_gpu.size
      msaa_texture_descriptor_gpu.size = @gpu.GPUExtent3D::new(
        width=size.width,
        height?=size.height,
        depth_or_array_layers=1,
      )
      let msaa_textures = []
      texture_data.set("msaaTextures", @core.JsValue::of(msaa_textures))
      for i = 0; i < depth; i = i + 1 {
        msaa_texture_descriptor_gpu.label = Some(
          texture_descriptor_gpu.label.unwrap() + "-msaa-" + i.to_string(),
        )
        msaa_textures.push(
          backend.gpu_device().create_texture(msaa_texture_descriptor_gpu),
        )
      }
    } else {
      texture_data.set(
        "msaaTexture",
        @core.JsValue::of(
          backend.gpu_device().create_texture(msaa_texture_descriptor_gpu),
        ),
      )
    }
  }
  texture_data.set("initialized", @core.JsValue::of(true))
  texture_data.set(
    "textureDescriptorGPU",
    @core.JsValue::of(texture_descriptor_gpu),
  )
}

///|
/// `try { f() } catch { }`: `None` when `f` throws.
extern "js" fn wgpu_try_js(f : () -> @core.JsValue) -> @core.JsValue = "(f) => { try { return f(); } catch ( e ) { return undefined; } }"

///|
fn[T] wgpu_try(f : () -> T) -> T? {
  let v = wgpu_try_js(fn() { @core.JsValue::of(f()) })
  if v.is_undefined() {
    None
  } else {
    Some(v.cast())
  }
}

///|
/// `destroyTexture( texture, isDefaultTexture = false )`.
pub fn WebGPUTextureUtils::destroy_texture(
  self : WebGPUTextureUtils,
  texture : @core.Texture,
  is_default_texture~ : Bool = false,
) -> Unit {
  let backend = self.backend()
  let texture_data = backend.get(@core.JsValue::of(texture))
  if !texture_data.get("texture").is_undefined() &&
    is_default_texture == false &&
    !(texture.texture_type is ExternalTexture) &&
    !texture_data.get("externalTexture").strict_equal(@core.JsValue::of(true)) {
    let t : @gpu.GPUTexture = texture_data.get("texture").cast()
    t.destroy()
  }
  match wgpu_opt(texture_data, "msaaTexture") {
    Some(t) => {
      let t : @gpu.GPUTexture = t
      t.destroy()
    }
    None => ()
  }
  match wgpu_msaa_textures(texture_data) {
    Some(m) =>
      for msaa_texture in m {
        msaa_texture.destroy()
      }
    None => ()
  }
  backend.delete(@core.JsValue::of(texture))
}

///|
/// `generateMipmaps( texture, encoder = null )`.
pub fn WebGPUTextureUtils::generate_mipmaps(
  self : WebGPUTextureUtils,
  texture : @core.Texture,
  encoder? : @gpu.GPUCommandEncoder,
) -> Unit {
  let texture_data = self.backend().get(@core.JsValue::of(texture))
  self._generate_mipmaps(texture_data.get("texture").cast(), encoder?)
}

///|
/// `image.width = width; image.height = height` of the canvas textures.
fn wgpu_set_image_size(
  texture : @core.Texture,
  width : Int32,
  height : Int32,
) -> Unit {
  match texture.image() {
    DataImage(image) => {
      image.width = width
      image.height = height
    }
    DomImage(image) => {
      image.set("width", @core.JsValue::of(width))
      image.set("height", @core.JsValue::of(height))
    }
    _ => ()
  }
}

///|
/// `texture.samples === samples`.
fn wgpu_samples_equal(texture : @core.Texture, samples : Int32) -> Bool {
  _web_gpu_texture_utils_samples.get(texture) == Some(samples)
}

///|
/// `getColorBuffer()`: the multisampled color buffer of the canvas.
pub fn WebGPUTextureUtils::get_color_buffer(
  self : WebGPUTextureUtils,
) -> @gpu.GPUTexture {
  let backend = self.backend()
  let canvas_target = backend.renderer().get_canvas_target()
  let size = backend.base().get_drawing_buffer_size()
  let width = size.x.to_int()
  let height = size.y.to_int()
  let samples = backend.renderer().current_samples()
  let color_texture = canvas_target.color_texture
  let color_texture_data = backend.get(@core.JsValue::of(color_texture))
  let current : @gpu.GPUTexture? = wgpu_opt(color_texture_data, "texture")
  match current {
    Some(t) if color_texture.width() == width.to_double() &&
      color_texture.height() == height.to_double() &&
      wgpu_samples_equal(color_texture, samples) => return t
    _ => ()
  }
  // recreate
  match current {
    Some(t) => t.destroy()
    None => ()
  }
  let td = _web_gpu_texture_utils_texture_descriptor
  td.label = Some("colorBuffer")
  td.size.width = width
  td.size.height = Some(height)
  td.sample_count = Some(
    backend.utils.get_sample_count(backend.renderer().current_samples()),
  )
  td.format = Some(backend.utils.get_preferred_canvas_format())
  td.usage = Some(
    @gpu.GPU_TEXTURE_USAGE_RENDER_ATTACHMENT | @gpu.GPU_TEXTURE_USAGE_COPY_SRC,
  )
  let color_buffer = backend.gpu_device().create_texture(td)
  td.reset()
  //
  wgpu_set_image_size(color_texture, width, height)
  _web_gpu_texture_utils_samples.set(color_texture, samples)
  color_texture_data.set("texture", @core.JsValue::of(color_buffer))
  color_buffer
}

///|
/// `getDepthBuffer( depth = true, stencil = false )`: the depth buffer of the canvas.
pub fn WebGPUTextureUtils::get_depth_buffer(
  self : WebGPUTextureUtils,
  depth~ : Bool = true,
  stencil~ : Bool = false,
) -> @gpu.GPUTexture {
  let backend = self.backend()
  let canvas_target = backend.renderer().get_canvas_target()
  let size = backend.base().get_drawing_buffer_size()
  let width = size.x.to_int()
  let height = size.y.to_int()
  let samples = backend.renderer().current_samples()
  let depth_texture = canvas_target.depth_texture
  // `depthTexture.depth` / `.stencil` are never set, so upstream's first early return
  // (which compares them with `depth` / `stencil`) never applies.
  //
  let depth_texture_gpu : @gpu.GPUTexture? = wgpu_opt(
    backend.get(@core.JsValue::of(depth_texture)),
    "texture",
  )
  let mut format = None
  let mut type_ = None
  if stencil {
    format = Some(@core.DepthStencilFormat)
    type_ = Some(
      if backend.renderer().reversed_depth_buffer == true {
        @core.FloatType
      } else {
        @core.UnsignedInt248Type
      },
    )
  } else if depth {
    format = Some(@core.DepthFormat)
    type_ = Some(
      if backend.renderer().reversed_depth_buffer == true {
        @core.FloatType
      } else {
        @core.UnsignedIntType
      },
    )
  }
  match depth_texture_gpu {
    Some(t) => {
      if depth_texture.image().width() == width.to_double() &&
        depth_texture.image().height() == height.to_double() &&
        Some(depth_texture.format) == format &&
        Some(depth_texture.type_) == type_ &&
        wgpu_samples_equal(depth_texture, samples) {
        return t
      }
      self.destroy_texture(depth_texture)
    }
    None => ()
  }
  // recreate
  depth_texture.name = "depthBuffer"
  depth_texture.format = format.unwrap()
  depth_texture.type_ = type_.unwrap()
  wgpu_set_image_size(depth_texture, width, height)
  _web_gpu_texture_utils_samples.set(depth_texture, samples)
  let options = @nodes.TextureOptions::new()
  options.width = width
  options.height = height
  self.create_texture(depth_texture, options)
  backend.get(@core.JsValue::of(depth_texture)).get("texture").cast()
}

///|
/// `texture.isDataTexture`.
fn wgpu_is_data_texture(texture : @core.Texture) -> Bool {
  texture.texture_type is DataTexture
}

///|
/// A data image (`{ data, width, height }`) of a texture image.
fn wgpu_data_image(image : @core.TextureImage) -> @core.DataImage {
  match image {
    DataImage(d) => d
    TextureImage(t) => wgpu_data_image(t.image())
    DomImage(js) => {
      let data = js.get("data")
      @core.DataImage::new(
        data?=if data.is_undefined() || data.is_null() {
          None
        } else {
          Some(data.cast())
        },
        width=js.get("width").cast(),
        height=js.get("height").cast(),
      )
    }
    _ =>
      abort("TypeError: Cannot read properties of undefined (reading 'data')")
  }
}

///|
/// `updateTexture( texture, options )`: uploads the texture data.
pub fn WebGPUTextureUtils::update_texture(
  self : WebGPUTextureUtils,
  texture : @core.Texture,
  options : @nodes.TextureOptions,
) -> Unit {
  let texture_data = self.backend().get(@core.JsValue::of(texture))
  let mipmaps = texture.mipmaps
  let texture_descriptor_gpu : @gpu.GPUTextureDescriptor? = wgpu_opt(
    texture_data, "textureDescriptorGPU",
  )
  if texture.is_render_target_texture || texture_descriptor_gpu is None { // unsupported texture format
    return
  }
  let texture_descriptor_gpu = texture_descriptor_gpu.unwrap()
  let texture_gpu : @gpu.GPUTexture = texture_data.get("texture").cast()
  // transfer texture data
  if wgpu_is_data_texture(texture) {
    if mipmaps.length() > 0 {
      for i = 0; i < mipmaps.length(); i = i + 1 {
        let mipmap = mipmaps[i]
        self._copy_buffer_to_texture(
          wgpu_data_image(mipmap),
          texture_gpu,
          texture_descriptor_gpu,
          0,
          texture.flip_y,
          mip_level=i,
        )
      }
    } else {
      self._copy_buffer_to_texture(
        wgpu_data_image(options.image.unwrap()),
        texture_gpu,
        texture_descriptor_gpu,
        0,
        texture.flip_y,
      )
    }
  } else if texture.is_array_texture ||
    texture.texture_type is (DataArrayTexture | Data3DTexture) {
    let image = wgpu_data_image(options.image.unwrap())
    match texture.layer_updates {
      Some(layer_updates) if layer_updates.length() > 0 => {
        for layer_index in layer_updates {
          self._copy_buffer_to_texture(
            image,
            texture_gpu,
            texture_descriptor_gpu,
            layer_index,
            texture.flip_y,
            depth=layer_index,
          )
        }
        texture.clear_layer_updates()
      }
      _ =>
        for i = 0; i < image.depth.unwrap_or(0); i = i + 1 {
          self._copy_buffer_to_texture(
            image,
            texture_gpu,
            texture_descriptor_gpu,
            i,
            texture.flip_y,
            depth=i,
          )
        }
    }
  } else if texture.is_compressed_texture() {
    if texture.texture_type is CompressedCubeTexture {
      match texture.image() {
        ImageArray(faces) =>
          for i = 0; i < 6; i = i + 1 {
            let face_mipmaps = match faces[i] {
              DataImage(d) => d.mipmaps.unwrap_or([])
              TextureImage(t) => t.mipmaps.map(wgpu_data_image)
              _ => []
            }
            self._copy_compressed_buffer_to_texture(
              face_mipmaps,
              texture_gpu,
              texture_descriptor_gpu,
              None,
              face_index=i,
            )
          }
        _ => ()
      }
    } else if texture.texture_type is CompressedArrayTexture &&
      texture.layer_updates.unwrap_or([]).length() > 0 {
      self._copy_compressed_buffer_to_texture(
        texture.mipmaps.map(wgpu_data_image),
        texture_gpu,
        texture_descriptor_gpu,
        texture.layer_updates,
      )
      texture.clear_layer_updates()
    } else {
      self._copy_compressed_buffer_to_texture(
        texture.mipmaps.map(wgpu_data_image),
        texture_gpu,
        texture_descriptor_gpu,
        None,
      )
    }
  } else if texture.is_cube_texture() {
    self._copy_cube_map_to_texture(texture, texture_gpu, texture_descriptor_gpu)
  } else if texture.texture_type is HTMLTexture {
    let device = self.backend().gpu_device()
    let canvas = self.backend().renderer().dom_element()
    let image = texture.image().to_js()
    if !device.queue().has_copy_element_image_to_texture() {
      return
    }
    // Skip the first frame — the element needs a paint record first.
    if !wgpu_truthy(texture_data.get("hasPaintCallback")) {
      texture_data.set("hasPaintCallback", @core.JsValue::of(true))
      wgpu_request_paint(canvas)
      return
    }
    let width = texture_descriptor_gpu.size.width
    let height = texture_descriptor_gpu.size.height.unwrap_or(1)
    if device.queue().copy_element_image_to_texture_length() == 2 {
      // Chrome 150+
      device
      .queue()
      .copy_element_image_to_texture(
        wgpu_element_image_source(image),
        wgpu_element_image_destination(texture_gpu, width, height),
      )
    } else {
      // Chrome 138 - 149
      device
      .queue()
      .copy_element_image_to_texture_sized(
        image,
        width,
        height,
        wgpu_texture_destination(texture_gpu),
      )
    }
    if texture.flip_y {
      self._flip_y(texture_gpu, texture_descriptor_gpu)
    }
  } else if mipmaps.length() > 0 {
    for i = 0; i < mipmaps.length(); i = i + 1 {
      let mipmap = mipmaps[i]
      self._copy_image_to_texture(
        mipmap,
        texture_gpu,
        texture_descriptor_gpu,
        0,
        texture.flip_y,
        texture.premultiply_alpha,
        mip_level=i,
      )
    }
  } else {
    self._copy_image_to_texture(
      options.image.unwrap(),
      texture_gpu,
      texture_descriptor_gpu,
      0,
      texture.flip_y,
      texture.premultiply_alpha,
    )
  }
  //
  texture_data.set("version", @core.JsValue::of(texture.version))
}

///|
extern "js" fn wgpu_request_paint(canvas : @core.JsValue) -> Unit = "(c) => { c.requestPaint(); }"

///|
extern "js" fn wgpu_element_image_source(
  image : @core.JsValue,
) -> @core.JsValue = "(i) => ( { source: i } )"

///|
extern "js" fn wgpu_element_image_destination(
  texture : @gpu.GPUTexture,
  width : Int32,
  height : Int32,
) -> @core.JsValue = "(t, w, h) => ( { destination: { texture: t }, width: w, height: h } )"

///|
extern "js" fn wgpu_texture_destination(
  texture : @gpu.GPUTexture,
) -> @core.JsValue = "(t) => ( { texture: t } )"

///|
/// `async copyTextureToBuffer( texture, x, y, width, height, faceIndex )`: calls back
/// with the tightly packed pixels.
pub fn WebGPUTextureUtils::copy_texture_to_buffer(
  self : WebGPUTextureUtils,
  texture : @core.Texture,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  face_index : Int32,
  on_done : (@core.TypedArray) -> Unit,
) -> Unit {
  let device = self.backend().gpu_device()
  let texture_data = self.backend().get(@core.JsValue::of(texture))
  let texture_gpu : @gpu.GPUTexture = texture_data.get("texture").cast()
  let descriptor : @gpu.GPUTextureDescriptor = texture_data
    .get("textureDescriptorGPU")
    .cast()
  let format = descriptor.format.unwrap()
  let bytes_per_texel = self._get_bytes_per_texel(format).unwrap()
  let unpadded_bytes_per_row = width * bytes_per_texel
  let bytes_per_row = wgpu_ceil_div(unpadded_bytes_per_row, 256) * 256 // copyTextureToBuffer() requires a multiple of 256
  let bd = _web_gpu_texture_utils_buffer_descriptor
  bd.size = height * bytes_per_row // multiple of 256, so it also meets the 4-byte size alignment required by mapAsync()
  bd.usage = @gpu.GPU_BUFFER_USAGE_COPY_DST | @gpu.GPU_BUFFER_USAGE_MAP_READ
  let read_buffer = device.create_buffer(bd)
  bd.reset()
  let encoder = device.create_command_encoder(
    descriptor=_web_gpu_texture_utils_command_encoder_descriptor,
  )
  let info = _web_gpu_texture_utils_texel_copy_texture_info
  info.texture = Some(texture_gpu)
  info.origin = Some(@gpu.GPUOrigin3D::new(x~, y~, z=face_index))
  let buffer_info = _web_gpu_texture_utils_texel_copy_buffer_info
  buffer_info.buffer = Some(read_buffer)
  buffer_info.bytes_per_row = Some(bytes_per_row)
  let extent = _web_gpu_texture_utils_extent3d
  extent.width = width
  extent.height = Some(height)
  encoder.copy_texture_to_buffer(info, buffer_info, extent)
  info.reset()
  buffer_info.reset()
  extent.reset()
  let typed_array_type = self._get_typed_array_type(format)
  wgpu_submit(device, encoder.finish())
  wgpu_await(
    read_buffer.map_async_promise(@gpu.GPU_MAP_MODE_READ),
    fn(_) {
      // remove the row padding so the result is tightly packed
      let padded_data = @core.TypedArray::view_by_name(
        "Uint8Array",
        read_buffer.get_mapped_range(),
      )
      let data = @core.TypedArray::uint8(unpadded_bytes_per_row * height)
      for row = 0; row < height; row = row + 1 {
        let offset = row * bytes_per_row
        data.set_from(
          padded_data.subarray(
            start=offset,
            end=offset + unpadded_bytes_per_row,
          ),
          offset=row * unpadded_bytes_per_row,
        )
      }
      read_buffer.destroy()
      on_done(@core.TypedArray::view_by_name(typed_array_type, data.buffer()))
    },
    fn(e) { abort(wgpu_error_string(e)) },
  )
}

///|
/// `dispose()`.
pub fn WebGPUTextureUtils::dispose(self : WebGPUTextureUtils) -> Unit {
  self._sampler_cache.clear()
}

///|
/// `_getDefaultTextureGPU( format )`.
fn WebGPUTextureUtils::_get_default_texture_gpu(
  self : WebGPUTextureUtils,
  format : String?,
) -> @gpu.GPUTexture {
  let key = format.unwrap_or("undefined")
  let default_texture = match self.default_texture.get(key) {
    Some(t) => t
    None => {
      let texture = @core.Texture::new()
      texture.min_filter = @core.NearestFilter
      texture.mag_filter = @core.NearestFilter
      let options = @nodes.TextureOptions::new()
      options.width = 1
      options.height = 1
      self._create_texture(texture, options, format)
      self.default_texture[key] = texture
      texture
    }
  }
  self.backend().get(@core.JsValue::of(default_texture)).get("texture").cast()
}

///|
/// `_getDefaultCubeTextureGPU( format )`.
fn WebGPUTextureUtils::_get_default_cube_texture_gpu(
  self : WebGPUTextureUtils,
  format : String?,
) -> @gpu.GPUTexture {
  let key = format.unwrap_or("undefined")
  let default_cube_texture = match self.default_cube_texture.get(key) {
    Some(t) => t
    None => {
      let texture = @core.CubeTexture::new()
      texture.min_filter = @core.NearestFilter
      texture.mag_filter = @core.NearestFilter
      let options = @nodes.TextureOptions::new()
      options.width = 1
      options.height = 1
      options.depth = 6
      self.create_texture(texture, options)
      self.default_cube_texture[key] = texture
      texture
    }
  }
  self
  .backend()
  .get(@core.JsValue::of(default_cube_texture))
  .get("texture")
  .cast()
}

///|
/// `_copyCubeMapToTexture( texture, textureGPU, textureDescriptorGPU )`.
fn WebGPUTextureUtils::_copy_cube_map_to_texture(
  self : WebGPUTextureUtils,
  texture : @core.Texture,
  texture_gpu : @gpu.GPUTexture,
  texture_descriptor_gpu : @gpu.GPUTextureDescriptor,
) -> Unit {
  let images = match texture.images() {
    ImageArray(a) => a
    _ => abort("TypeError: Cannot read properties of undefined (reading '0')")
  }
  let mipmaps = texture.mipmaps
  for i = 0; i < 6; i = i + 1 {
    let image = images[i]
    let flip_index = if texture.flip_y == true {
      _web_gpu_texture_utils_flip_map[i]
    } else {
      i
    }
    match image {
      TextureImage(t) if wgpu_is_data_texture(t) =>
        self._copy_buffer_to_texture(
          wgpu_data_image(t.image()),
          texture_gpu,
          texture_descriptor_gpu,
          flip_index,
          texture.flip_y,
        )
      _ =>
        self._copy_image_to_texture(
          image,
          texture_gpu,
          texture_descriptor_gpu,
          flip_index,
          texture.flip_y,
          texture.premultiply_alpha,
        )
    }
    for j = 0; j < mipmaps.length(); j = j + 1 {
      let mipmap_images = match mipmaps[j] {
        TextureImage(m) =>
          match m.images() {
            ImageArray(a) => a
            _ => []
          }
        ImageArray(a) => a
        _ => []
      }
      let image = mipmap_images[i]
      match image {
        TextureImage(t) if wgpu_is_data_texture(t) =>
          self._copy_buffer_to_texture(
            wgpu_data_image(t.image()),
            texture_gpu,
            texture_descriptor_gpu,
            flip_index,
            texture.flip_y,
            mip_level=j + 1,
          )
        _ =>
          self._copy_image_to_texture(
            image,
            texture_gpu,
            texture_descriptor_gpu,
            flip_index,
            texture.flip_y,
            texture.premultiply_alpha,
            mip_level=j + 1,
          )
      }
    }
  }
}

///|
/// `_copyImageToTexture( image, textureGPU, textureDescriptorGPU, originDepth, flipY,
/// premultiplyAlpha, mipLevel = 0 )`.
fn WebGPUTextureUtils::_copy_image_to_texture(
  self : WebGPUTextureUtils,
  image : @core.TextureImage,
  texture_gpu : @gpu.GPUTexture,
  texture_descriptor_gpu : @gpu.GPUTextureDescriptor,
  origin_depth : Int32,
  flip_y : Bool,
  premultiply_alpha : Bool,
  mip_level~ : Int32 = 0,
) -> Unit {
  let device = self.backend().gpu_device()
  let width = if mip_level > 0 {
    image.width().to_int()
  } else {
    texture_descriptor_gpu.size.width
  }
  let height = if mip_level > 0 {
    image.height().to_int()
  } else {
    texture_descriptor_gpu.size.height.unwrap_or(1)
  }
  let source = _web_gpu_texture_utils_copy_external_image_source_info
  source.source = Some(image.to_js())
  source.flip_y = Some(flip_y)
  let dest = _web_gpu_texture_utils_copy_external_image_dest_info
  dest.texture = Some(texture_gpu)
  dest.mip_level = Some(mip_level)
  match dest.origin {
    Some(o) => o.z = Some(origin_depth)
    None => ()
  }
  dest.premultiplied_alpha = Some(premultiply_alpha)
  let extent = _web_gpu_texture_utils_extent3d
  extent.width = width
  extent.height = Some(height)
  // try/catch has been added to fix bad video frame data on certain devices, see #32391
  ignore(
    wgpu_try(fn() {
      device.queue().copy_external_image_to_texture(source, dest, extent)
      true
    }),
  )
  source.reset()
  dest.reset()
  extent.reset()
}

///|
/// `_getPassUtils()`.
fn WebGPUTextureUtils::_get_pass_utils(
  self : WebGPUTextureUtils,
) -> WebGPUTexturePassUtils {
  match self._pass_utils {
    Some(p) => p
    None => {
      let p = WebGPUTexturePassUtils::new(self.backend().gpu_device())
      self._pass_utils = Some(p)
      p
    }
  }
}

///|
/// `_generateMipmaps( textureGPU, encoder = null )`.
fn WebGPUTextureUtils::_generate_mipmaps(
  self : WebGPUTextureUtils,
  texture_gpu : @gpu.GPUTexture,
  encoder? : @gpu.GPUCommandEncoder,
) -> Unit {
  self._get_pass_utils().generate_mipmaps(texture_gpu, encoder?)
}

///|
/// `_flipY( textureGPU, textureDescriptorGPU, originDepth = 0 )`.
fn WebGPUTextureUtils::_flip_y(
  self : WebGPUTextureUtils,
  texture_gpu : @gpu.GPUTexture,
  texture_descriptor_gpu : @gpu.GPUTextureDescriptor,
  origin_depth~ : Int32 = 0,
) -> Unit {
  self
  ._get_pass_utils()
  .flip_y(texture_gpu, texture_descriptor_gpu, base_array_layer=origin_depth)
}

///|
/// `_copyBufferToTexture( image, textureGPU, textureDescriptorGPU, originDepth, flipY,
/// depth = 0, mipLevel = 0 )`.
fn WebGPUTextureUtils::_copy_buffer_to_texture(
  self : WebGPUTextureUtils,
  image : @core.DataImage,
  texture_gpu : @gpu.GPUTexture,
  texture_descriptor_gpu : @gpu.GPUTextureDescriptor,
  origin_depth : Int32,
  flip_y : Bool,
  depth~ : Int32 = 0,
  mip_level~ : Int32 = 0,
) -> Unit {
  // @TODO: Consider to use GPUCommandEncoder.copyBufferToTexture()
  // @TODO: Consider to support valid buffer layouts with other formats like RGB
  let device = self.backend().gpu_device()
  let data = image.data
  let bytes_per_texel = self
    ._get_bytes_per_texel(texture_descriptor_gpu.format.unwrap())
    .unwrap()
  let bytes_per_row = image.width * bytes_per_texel
  let info = _web_gpu_texture_utils_texel_copy_texture_info
  info.texture = Some(texture_gpu)
  info.mip_level = Some(mip_level)
  wgpu_origin_z(info, origin_depth)
  let layout = _web_gpu_texture_utils_texel_copy_buffer_layout
  layout.offset = Some(image.width * image.height * bytes_per_texel * depth)
  layout.bytes_per_row = Some(bytes_per_row)
  let extent = _web_gpu_texture_utils_extent3d
  extent.width = image.width
  extent.height = Some(image.height)
  device.queue().write_texture(info, wgpu_image_data(data), layout, extent)
  info.reset()
  layout.reset()
  extent.reset()
  if flip_y == true {
    self._flip_y(texture_gpu, texture_descriptor_gpu, origin_depth~)
  }
}

///|
/// `_copyCompressedBufferToTexture( mipmaps, textureGPU, textureDescriptorGPU,
/// layerUpdates = null, faceIndex = - 1 )`.
fn WebGPUTextureUtils::_copy_compressed_buffer_to_texture(
  self : WebGPUTextureUtils,
  mipmaps : Array[@core.DataImage],
  texture_gpu : @gpu.GPUTexture,
  texture_descriptor_gpu : @gpu.GPUTextureDescriptor,
  layer_updates : Array[Int32]?,
  face_index~ : Int32 = -1,
) -> Unit {
  // @TODO: Consider to use GPUCommandEncoder.copyBufferToTexture()
  let device = self.backend().gpu_device()
  let block_data = self._get_block_data(texture_descriptor_gpu.format.unwrap())
  let layers = texture_descriptor_gpu.size.depth_or_array_layers.unwrap_or(1)
  let is_array_texture = layers > 1
  let active_layer_updates = match layer_updates {
    Some(l) if l.length() > 0 => Some(l)
    _ => None
  }
  for i = 0; i < mipmaps.length(); i = i + 1 {
    let mipmap = mipmaps[i]
    let width = mipmap.width
    let height = mipmap.height
    let depth = if is_array_texture { layers } else { 1 }
    let bytes_per_row = wgpu_ceil_div(width, block_data.width) *
      block_data.byte_length
    let rows_per_image = wgpu_ceil_div(height, block_data.height)
    let bytes_per_image = bytes_per_row * rows_per_image
    let texture_width = wgpu_ceil_div(width, block_data.width) *
      block_data.width
    let texture_height = rows_per_image * block_data.height
    if face_index != -1 {
      _web_gpu_texture_utils_write_texture_layer(
        device, texture_gpu, i, face_index, mipmap, 0, bytes_per_row, rows_per_image,
        texture_width, texture_height,
      )
    } else {
      match active_layer_updates {
        Some(updates) =>
          for layer_index in updates {
            _web_gpu_texture_utils_write_texture_layer(
              device,
              texture_gpu,
              i,
              layer_index,
              mipmap,
              layer_index * bytes_per_image,
              bytes_per_row,
              rows_per_image,
              texture_width,
              texture_height,
            )
          }
        None =>
          for layer_index = 0
              layer_index < depth
              layer_index = layer_index + 1 {
            _web_gpu_texture_utils_write_texture_layer(
              device,
              texture_gpu,
              i,
              layer_index,
              mipmap,
              layer_index * bytes_per_image,
              bytes_per_row,
              rows_per_image,
              texture_width,
              texture_height,
            )
          }
      }
    }
  }
}

///|
/// `{ byteLength, width, height }` of a block format.
priv struct WebGPUBlockData {
  byte_length : Int32
  width : Int32
  height : Int32
}

///|
/// `_getBlockData( format )`.
fn WebGPUTextureUtils::_get_block_data(
  self : WebGPUTextureUtils,
  format : String,
) -> WebGPUBlockData {
  let b = fn(byte_length, width, height) -> WebGPUBlockData {
    { byte_length, width, height, }
  }
  match format {
    "bc1-rgba-unorm" | "bc1-rgba-unorm-srgb" => b(8, 4, 4) // DXT1
    "bc2-rgba-unorm" | "bc2-rgba-unorm-srgb" => b(16, 4, 4) // DXT3
    "bc3-rgba-unorm" | "bc3-rgba-unorm-srgb" => b(16, 4, 4) // DXT5
    "bc4-r-unorm" | "bc4-r-snorm" => b(8, 4, 4) // RGTC1
    "bc5-rg-unorm" | "bc5-rg-snorm" => b(16, 4, 4) // RGTC2
    "bc6h-rgb-ufloat" | "bc6h-rgb-float" => b(16, 4, 4) // BPTC (float)
    "bc7-rgba-unorm" | "bc7-rgba-unorm-srgb" => b(16, 4, 4) // BPTC (unorm)
    "etc2-rgb8unorm" | "etc2-rgb8unorm-srgb" => b(8, 4, 4)
    "etc2-rgb8a1unorm" | "etc2-rgb8a1unorm-srgb" => b(8, 4, 4)
    "etc2-rgba8unorm" | "etc2-rgba8unorm-srgb" => b(16, 4, 4)
    "eac-r11unorm" => b(8, 4, 4)
    "eac-r11snorm" => b(8, 4, 4)
    "eac-rg11unorm" => b(16, 4, 4)
    "eac-rg11snorm" => b(16, 4, 4)
    "astc-4x4-unorm" | "astc-4x4-unorm-srgb" => b(16, 4, 4)
    "astc-5x4-unorm" | "astc-5x4-unorm-srgb" => b(16, 5, 4)
    "astc-5x5-unorm" | "astc-5x5-unorm-srgb" => b(16, 5, 5)
    "astc-6x5-unorm" | "astc-6x5-unorm-srgb" => b(16, 6, 5)
    "astc-6x6-unorm" | "astc-6x6-unorm-srgb" => b(16, 6, 6)
    "astc-8x5-unorm" | "astc-8x5-unorm-srgb" => b(16, 8, 5)
    "astc-8x6-unorm" | "astc-8x6-unorm-srgb" => b(16, 8, 6)
    "astc-8x8-unorm" | "astc-8x8-unorm-srgb" => b(16, 8, 8)
    "astc-10x5-unorm" | "astc-10x5-unorm-srgb" => b(16, 10, 5)
    "astc-10x6-unorm" | "astc-10x6-unorm-srgb" => b(16, 10, 6)
    "astc-10x8-unorm" | "astc-10x8-unorm-srgb" => b(16, 10, 8)
    "astc-10x10-unorm" | "astc-10x10-unorm-srgb" => b(16, 10, 10)
    "astc-12x10-unorm" | "astc-12x10-unorm-srgb" => b(16, 12, 10)
    "astc-12x12-unorm" | "astc-12x12-unorm-srgb" => b(16, 12, 12)
    _ => b(self._get_bytes_per_texel(format).unwrap_or(0), 1, 1) // uncompressed data
  }
}

///|
/// `_convertAddressMode( value )`.
fn WebGPUTextureUtils::_convert_address_mode(
  self : WebGPUTextureUtils,
  value : Int32,
) -> String {
  ignore(self)
  if value == @core.RepeatWrapping {
    GPUAddressMode_Repeat
  } else if value == @core.MirroredRepeatWrapping {
    GPUAddressMode_MirrorRepeat
  } else {
    GPUAddressMode_ClampToEdge
  }
}

///|
/// `_convertFilterMode( value )`.
fn WebGPUTextureUtils::_convert_filter_mode(
  self : WebGPUTextureUtils,
  value : Int32,
) -> String {
  ignore(self)
  if value == @core.NearestFilter ||
    value == @core.NearestMipmapNearestFilter ||
    value == @core.NearestMipmapLinearFilter {
    GPUFilterMode_Nearest
  } else {
    GPUFilterMode_Linear
  }
}

///|
/// `_convertMipmapFilterMode( value )`.
fn WebGPUTextureUtils::_convert_mipmap_filter_mode(
  self : WebGPUTextureUtils,
  value : Int32,
) -> String {
  ignore(self)
  if value == @core.NearestMipmapLinearFilter ||
    value == @core.LinearMipmapLinearFilter {
    GPUFilterMode_Linear
  } else {
    GPUFilterMode_Nearest
  }
}

///|
/// `_getBytesPerTexel( format )`; `None` is `undefined` (compressed formats).
fn WebGPUTextureUtils::_get_bytes_per_texel(
  self : WebGPUTextureUtils,
  format : String,
) -> Int32? {
  ignore(self)
  match format {
    // 8-bit formats
    "r8unorm" | "r8snorm" | "r8uint" | "r8sint" => Some(1)
    // 16-bit formats
    "r16uint"
    | "r16sint"
    | "r16float"
    | "rg8unorm"
    | "rg8snorm"
    | "rg8uint"
    | "rg8sint"
    | "r16unorm"
    | "r16snorm" => Some(2)
    // 32-bit formats
    "r32uint"
    | "r32sint"
    | "r32float"
    | "rg16uint"
    | "rg16sint"
    | "rg16float"
    | "rgba8unorm"
    | "rgba8unorm-srgb"
    | "rgba8snorm"
    | "rgba8uint"
    | "rgba8sint"
    | "bgra8unorm"
    | "bgra8unorm-srgb"
    | "rg16unorm"
    | "rg16snorm"
    // Packed 32-bit formats
    | "rgb9e5ufloat"
    | "rgb10a2unorm"
    | "rg11b10ufloat"
    | "depth32float"
    | "depth24plus"
    | "depth24plus-stencil8"
    | "depth32float-stencil8" => Some(4)
    // 64-bit formats
    "rg32uint"
    | "rg32sint"
    | "rg32float"
    | "rgba16uint"
    | "rgba16sint"
    | "rgba16float"
    | "rgba16unorm"
    | "rgba16snorm" => Some(8)
    // 128-bit formats
    "rgba32uint" | "rgba32sint" | "rgba32float" => Some(16)
    _ => None
  }
}

///|
/// `_getTypedArrayType( format )`: the name of the typed array class.
fn WebGPUTextureUtils::_get_typed_array_type(
  self : WebGPUTextureUtils,
  format : String,
) -> String {
  ignore(self)
  match format {
    "r8uint" | "r8unorm" | "rg8uint" | "rg8unorm" | "rgba8uint" => "Uint8Array"
    "rgba8unorm" | "rgba8unorm-srgb" => "Uint8Array"
    "r8sint"
    | "r8snorm"
    | "rg8sint"
    | "rg8snorm"
    | "rgba8sint"
    | "rgba8snorm" => "Int8Array"
    "r16uint" | "rg16uint" | "rgba16uint" => "Uint16Array"
    "r16sint" | "rg16sint" | "rgba16sint" => "Int16Array"
    "r16float" | "rg16float" | "rgba16float" => "Uint16Array"
    "r16unorm" | "rg16unorm" | "rgba16unorm" => "Uint16Array"
    "r16snorm" | "rg16snorm" | "rgba16snorm" => "Int16Array"
    "r32uint" | "rg32uint" | "rgba32uint" => "Uint32Array"
    "r32sint" | "rg32sint" | "rgba32sint" => "Int32Array"
    "r32float" | "rg32float" | "rgba32float" => "Float32Array"
    "bgra8unorm" | "bgra8unorm-srgb" => "Uint8Array"
    "rgb10a2unorm" | "rgb9e5ufloat" | "rg11b10ufloat" => "Uint32Array"
    "depth32float" => "Float32Array"
    "depth24plus" | "depth24plus-stencil8" => "Uint32Array"
    "depth32float-stencil8" => "Float32Array"
    _ => abort("TypeError: typedArrayType is not a constructor (\{format})")
  }
}

///|
/// `_getDimension( texture )`.
fn WebGPUTextureUtils::_get_dimension(
  self : WebGPUTextureUtils,
  texture : @core.Texture,
) -> String {
  ignore(self)
  if texture.has_extension_flag("is3DTexture") ||
    texture.texture_type is Data3DTexture {
    GPUTextureDimension_ThreeD
  } else {
    GPUTextureDimension_TwoD
  }
}

///|
/// `device.features.has( name )` of an optional device (`device` is `null` before
/// `init()`).
fn wgpu_device_has(device : @gpu.GPUDevice?, name : String) -> Bool {
  match device {
    Some(d) => d.features().has(name)
    None =>
      abort("TypeError: Cannot read properties of null (reading 'features')")
  }
}

///|
/// `getFormat( texture, device )`: the GPU format of a texture; `None` is `undefined`.
pub fn wgpu_get_format_device(
  texture : @core.Texture,
  device : @gpu.GPUDevice?,
) -> String? {
  wgpu_get_format_with(texture, fn(name) { wgpu_device_has(device, name) }, fn() {
    device is Some(_)
  })
}

///|
/// `getFormat` with `device.features.has` and the `device &&` test as functions (the
/// WGSL builder's stand-in device answers them without a backend).
fn wgpu_get_format_with(
  texture : @core.Texture,
  device_has : (String) -> Bool,
  has_device : () -> Bool,
) -> String? {
  let format = texture.format
  let type_ = texture.type_
  let normalized = texture.normalized
  let color_space = texture.color_space
  let transfer = @math.color_management.get_transfer(color_space)
  let mut texture_formats_tier1 = false
  if normalized {
    texture_formats_tier1 = device_has(GPUFeatureName_TextureFormatsTier1)
    if texture_formats_tier1 == false {
      @core.warn(
        "WebGPURenderer: Unable to use normalized textures without texture-formats-tier1 feature.",
      )
    }
  }
  let srgb = transfer == @math.SRGBTransfer
  let unsupported = fn(message : String, value : Int32) -> String? {
    @core.error("\{message} \{value}")
    None
  }
  if texture.is_compressed_texture() == true {
    match format {
      @core.RGB_S3TC_DXT1_Format | @core.RGBA_S3TC_DXT1_Format =>
        Some(
          if srgb {
            GPUTextureFormat_BC1RGBAUnormSRGB
          } else {
            GPUTextureFormat_BC1RGBAUnorm
          },
        )
      @core.RGBA_S3TC_DXT3_Format =>
        Some(
          if srgb {
            GPUTextureFormat_BC2RGBAUnormSRGB
          } else {
            GPUTextureFormat_BC2RGBAUnorm
          },
        )
      @core.RGBA_S3TC_DXT5_Format =>
        Some(
          if srgb {
            GPUTextureFormat_BC3RGBAUnormSRGB
          } else {
            GPUTextureFormat_BC3RGBAUnorm
          },
        )
      @core.RED_RGTC1_Format => Some(GPUTextureFormat_BC4RUnorm)
      @core.SIGNED_RED_RGTC1_Format => Some(GPUTextureFormat_BC4RSnorm)
      @core.RED_GREEN_RGTC2_Format => Some(GPUTextureFormat_BC5RGUnorm)
      @core.SIGNED_RED_GREEN_RGTC2_Format => Some(GPUTextureFormat_BC5RGSnorm)
      @core.RGBA_BPTC_Format =>
        Some(
          if srgb {
            GPUTextureFormat_BC7RGBAUnormSRGB
          } else {
            GPUTextureFormat_BC7RGBAUnorm
          },
        )
      @core.RGB_BPTC_SIGNED_Format => Some(GPUTextureFormat_BC6HRGBFloat)
      @core.RGB_BPTC_UNSIGNED_Format => Some(GPUTextureFormat_BC6HRGBUFloat)
      @core.RGB_ETC2_Format | @core.RGB_ETC1_Format =>
        Some(
          if srgb {
            GPUTextureFormat_ETC2RGB8UnormSRGB
          } else {
            GPUTextureFormat_ETC2RGB8Unorm
          },
        )
      @core.RGBA_ETC2_EAC_Format =>
        Some(
          if srgb {
            GPUTextureFormat_ETC2RGBA8UnormSRGB
          } else {
            GPUTextureFormat_ETC2RGBA8Unorm
          },
        )
      @core.R11_EAC_Format => Some(GPUTextureFormat_EACR11Unorm)
      @core.SIGNED_R11_EAC_Format => Some(GPUTextureFormat_EACR11Snorm)
      @core.RG11_EAC_Format => Some(GPUTextureFormat_EACRG11Unorm)
      @core.SIGNED_RG11_EAC_Format => Some(GPUTextureFormat_EACRG11Snorm)
      @core.RGBA_ASTC_4x4_Format =>
        Some(
          if srgb {
            GPUTextureFormat_ASTC4x4UnormSRGB
          } else {
            GPUTextureFormat_ASTC4x4Unorm
          },
        )
      @core.RGBA_ASTC_5x4_Format =>
        Some(
          if srgb {
            GPUTextureFormat_ASTC5x4UnormSRGB
          } else {
            GPUTextureFormat_ASTC5x4Unorm
          },
        )
      @core.RGBA_ASTC_5x5_Format =>
        Some(
          if srgb {
            GPUTextureFormat_ASTC5x5UnormSRGB
          } else {
            GPUTextureFormat_ASTC5x5Unorm
          },
        )
      @core.RGBA_ASTC_6x5_Format =>
        Some(
          if srgb {
            GPUTextureFormat_ASTC6x5UnormSRGB
          } else {
            GPUTextureFormat_ASTC6x5Unorm
          },
        )
      @core.RGBA_ASTC_6x6_Format =>
        Some(
          if srgb {
            GPUTextureFormat_ASTC6x6UnormSRGB
          } else {
            GPUTextureFormat_ASTC6x6Unorm
          },
        )
      @core.RGBA_ASTC_8x5_Format =>
        Some(
          if srgb {
            GPUTextureFormat_ASTC8x5UnormSRGB
          } else {
            GPUTextureFormat_ASTC8x5Unorm
          },
        )
      @core.RGBA_ASTC_8x6_Format =>
        Some(
          if srgb {
            GPUTextureFormat_ASTC8x6UnormSRGB
          } else {
            GPUTextureFormat_ASTC8x6Unorm
          },
        )
      @core.RGBA_ASTC_8x8_Format =>
        Some(
          if srgb {
            GPUTextureFormat_ASTC8x8UnormSRGB
          } else {
            GPUTextureFormat_ASTC8x8Unorm
          },
        )
      @core.RGBA_ASTC_10x5_Format =>
        Some(
          if srgb {
            GPUTextureFormat_ASTC10x5UnormSRGB
          } else {
            GPUTextureFormat_ASTC10x5Unorm
          },
        )
      @core.RGBA_ASTC_10x6_Format =>
        Some(
          if srgb {
            GPUTextureFormat_ASTC10x6UnormSRGB
          } else {
            GPUTextureFormat_ASTC10x6Unorm
          },
        )
      @core.RGBA_ASTC_10x8_Format =>
        Some(
          if srgb {
            GPUTextureFormat_ASTC10x8UnormSRGB
          } else {
            GPUTextureFormat_ASTC10x8Unorm
          },
        )
      @core.RGBA_ASTC_10x10_Format =>
        Some(
          if srgb {
            GPUTextureFormat_ASTC10x10UnormSRGB
          } else {
            GPUTextureFormat_ASTC10x10Unorm
          },
        )
      @core.RGBA_ASTC_12x10_Format =>
        Some(
          if srgb {
            GPUTextureFormat_ASTC12x10UnormSRGB
          } else {
            GPUTextureFormat_ASTC12x10Unorm
          },
        )
      @core.RGBA_ASTC_12x12_Format =>
        Some(
          if srgb {
            GPUTextureFormat_ASTC12x12UnormSRGB
          } else {
            GPUTextureFormat_ASTC12x12Unorm
          },
        )
      @core.RGBAFormat =>
        if type_ == @core.HalfFloatType {
          Some(GPUTextureFormat_RGBA16Float)
        } else {
          Some(
            if srgb {
              GPUTextureFormat_RGBA8UnormSRGB
            } else {
              GPUTextureFormat_RGBA8Unorm
            },
          )
        }
      _ => unsupported("WebGPURenderer: Unsupported texture format.", format)
    }
  } else if format == @core.RGBAFormat {
    if type_ == @core.ByteType {
      Some(GPUTextureFormat_RGBA8Snorm)
    } else if type_ == @core.ShortType {
      Some(
        if texture_formats_tier1 {
          GPUTextureFormat_RGBA16Snorm
        } else {
          GPUTextureFormat_RGBA16Sint
        },
      )
    } else if type_ == @core.UnsignedShortType {
      Some(
        if texture_formats_tier1 {
          GPUTextureFormat_RGBA16Unorm
        } else {
          GPUTextureFormat_RGBA16Uint
        },
      )
    } else if type_ == @core.UnsignedIntType {
      Some(GPUTextureFormat_RGBA32Uint)
    } else if type_ == @core.IntType {
      Some(GPUTextureFormat_RGBA32Sint)
    } else if type_ == @core.UnsignedByteType {
      Some(
        if srgb {
          GPUTextureFormat_RGBA8UnormSRGB
        } else {
          GPUTextureFormat_RGBA8Unorm
        },
      )
    } else if type_ == @core.HalfFloatType {
      Some(GPUTextureFormat_RGBA16Float)
    } else if type_ == @core.FloatType {
      Some(GPUTextureFormat_RGBA32Float)
    } else {
      unsupported(
        "WebGPURenderer: Unsupported texture type with RGBAFormat.", type_,
      )
    }
  } else if format == @core.RGBFormat {
    if type_ == @core.UnsignedInt5999Type {
      Some(GPUTextureFormat_RGB9E5UFloat)
    } else if type_ == @core.UnsignedInt101111Type {
      Some(GPUTextureFormat_RG11B10UFloat)
    } else {
      unsupported(
        "WebGPURenderer: Unsupported texture type with RGBFormat.", type_,
      )
    }
  } else if format == @core.RedFormat {
    if type_ == @core.ByteType {
      Some(GPUTextureFormat_R8Snorm)
    } else if type_ == @core.ShortType {
      Some(
        if texture_formats_tier1 {
          GPUTextureFormat_R16Snorm
        } else {
          GPUTextureFormat_R16Sint
        },
      )
    } else if type_ == @core.UnsignedShortType {
      Some(
        if texture_formats_tier1 {
          GPUTextureFormat_R16Unorm
        } else {
          GPUTextureFormat_R16Uint
        },
      )
    } else if type_ == @core.UnsignedIntType {
      Some(GPUTextureFormat_R32Uint)
    } else if type_ == @core.IntType {
      Some(GPUTextureFormat_R32Sint)
    } else if type_ == @core.UnsignedByteType {
      Some(GPUTextureFormat_R8Unorm)
    } else if type_ == @core.HalfFloatType {
      Some(GPUTextureFormat_R16Float)
    } else if type_ == @core.FloatType {
      Some(GPUTextureFormat_R32Float)
    } else {
      unsupported(
        "WebGPURenderer: Unsupported texture type with RedFormat.", type_,
      )
    }
  } else if format == @core.RGFormat {
    if type_ == @core.ByteType {
      Some(GPUTextureFormat_RG8Snorm)
    } else if type_ == @core.ShortType {
      Some(
        if texture_formats_tier1 {
          GPUTextureFormat_RG16Snorm
        } else {
          GPUTextureFormat_RG16Sint
        },
      )
    } else if type_ == @core.UnsignedShortType {
      Some(
        if texture_formats_tier1 {
          GPUTextureFormat_RG16Unorm
        } else {
          GPUTextureFormat_RG16Uint
        },
      )
    } else if type_ == @core.UnsignedIntType {
      Some(GPUTextureFormat_RG32Uint)
    } else if type_ == @core.IntType {
      Some(GPUTextureFormat_RG32Sint)
    } else if type_ == @core.UnsignedByteType {
      Some(GPUTextureFormat_RG8Unorm)
    } else if type_ == @core.HalfFloatType {
      Some(GPUTextureFormat_RG16Float)
    } else if type_ == @core.FloatType {
      Some(GPUTextureFormat_RG32Float)
    } else {
      unsupported(
        "WebGPURenderer: Unsupported texture type with RGFormat.", type_,
      )
    }
  } else if format == @core.DepthFormat {
    if type_ == @core.UnsignedShortType {
      Some(GPUTextureFormat_Depth16Unorm)
    } else if type_ == @core.UnsignedIntType {
      Some(GPUTextureFormat_Depth24Plus)
    } else if type_ == @core.FloatType {
      Some(GPUTextureFormat_Depth32Float)
    } else {
      unsupported(
        "WebGPURenderer: Unsupported texture type with DepthFormat.", type_,
      )
    }
  } else if format == @core.DepthStencilFormat {
    if type_ == @core.UnsignedInt248Type {
      Some(GPUTextureFormat_Depth24PlusStencil8)
    } else if type_ == @core.FloatType {
      if has_device() &&
        device_has(GPUFeatureName_Depth32FloatStencil8) == false {
        @core.error(
          "WebGPURenderer: Depth textures with DepthStencilFormat + FloatType can only be used with the \"depth32float-stencil8\" GPU feature.",
        )
      }
      Some(GPUTextureFormat_Depth32FloatStencil8)
    } else {
      unsupported(
        "WebGPURenderer: Unsupported texture type with DepthStencilFormat.", type_,
      )
    }
  } else if format == @core.RedIntegerFormat {
    if type_ == @core.IntType {
      Some(GPUTextureFormat_R32Sint)
    } else if type_ == @core.UnsignedIntType {
      Some(GPUTextureFormat_R32Uint)
    } else {
      unsupported(
        "WebGPURenderer: Unsupported texture type with RedIntegerFormat.", type_,
      )
    }
  } else if format == @core.RGIntegerFormat {
    if type_ == @core.IntType {
      Some(GPUTextureFormat_RG32Sint)
    } else if type_ == @core.UnsignedIntType {
      Some(GPUTextureFormat_RG32Uint)
    } else {
      unsupported(
        "WebGPURenderer: Unsupported texture type with RGIntegerFormat.", type_,
      )
    }
  } else if format == @core.RGBAIntegerFormat {
    if type_ == @core.IntType {
      Some(GPUTextureFormat_RGBA32Sint)
    } else if type_ == @core.UnsignedIntType {
      Some(GPUTextureFormat_RGBA32Uint)
    } else {
      unsupported(
        "WebGPURenderer: Unsupported texture type with RGBAIntegerFormat.", type_,
      )
    }
  } else {
    unsupported("WebGPURenderer: Unsupported texture format.", format)
  }
}

///|
/// Whether `texture.wrapR` is defined upstream: only the 3D and array textures set it, so
/// `( texture.wrapR || '0' )` reads `'0'` for every other texture although the port's
/// textures all carry a `wrap_r` field.
fn _web_gpu_texture_utils_has_wrap_r(texture : @core.Texture) -> Bool {
  texture.texture_type
  is (Data3DTexture | DataArrayTexture | CompressedArrayTexture) ||
  texture.has_extension_flag("is3DTexture")
}
