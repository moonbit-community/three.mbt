// Upstream src/renderers/webgl/WebGLTextures.js. GROUP 1.
//
// Per-texture and per-render-target state goes through `WebGLProperties`
// (`TextureProperties`, `RenderTargetProperties`, `SourceProperties`). The private
// fields below mirror the closure's locals; group 1 may reshape private state, but the
// public methods' signatures are fixed.
//
// Values upstream hands to GL unchanged are passed unchanged here too: a `null` format
// from `utils.convert` (`textures_gl_enum`), the fractional mip level count
// `Math.log2( size ) + 1` (`textures_js_number`) and `undefined` table lookups reach GL
// as the same JS values, so call logs match upstream exactly.

///|
/// `webglTextures[ cacheKey ]` in the per-source map.
pub(all) struct TextureCacheEntry {
  texture : GLTexture
  mut used_times : Int32
}

///|
/// An entry of `_tracked`: what `track` registered.
pub(all) enum TrackedRef {
  TextureRef(WeakRef[@core.Texture])
  RenderTargetRef(WeakRef[@core.RenderTarget])
}

///|
pub struct WebGLTextures {
  gl : WebGL2RenderingContext
  extensions : WebGLExtensions
  state : WebGLState
  properties : WebGLProperties
  capabilities : WebGLCapabilities
  utils : WebGLUtils
  info : WebGLInfo
  multisampled_rtt_ext : GLExtension?
  supports_invalidate_framebuffer : Bool
  _image_dimensions : @math.Vector2
  /// texture -> last `info.render.frame` it was updated in
  _video_textures : WeakMap[@core.Texture, Int32]
  /// the `Set` of HTML textures, by texture id
  _html_textures : Map[Int32, @core.Texture]
  mut _canvas : HTMLCanvasElement?
  /// source -> cache key -> GL texture
  _sources : WeakMap[@core.TextureSource, Map[String, TextureCacheEntry]]
  /// the `Set` of `WeakRef`s from `track`
  _tracked : Array[TrackedRef]
  _registry : FinalizationRegistry[TrackedRef]
  use_offscreen_canvas : Bool
  mut texture_units : Int32
  wrapping_to_gl : Map[Int32, Int32]
  filter_to_gl : Map[Int32, Int32]
  compare_to_gl : Map[Int32, Int32]
  invalidation_array_read : Array[Int32]
  /// `onTextureDispose`, kept so it can be removed
  mut on_texture_dispose : (@core.Event) -> Unit
  /// `onRenderTargetDispose`, kept so it can be removed
  mut on_render_target_dispose : (@core.Event) -> Unit
}

// --- JS value helpers -------------------------------------------------------------

///|
/// A GL enum from `utils.convert` / `getInternalFormat`: `None` reaches GL as `null`, as
/// upstream passes it.
fn textures_gl_enum(value : Int32?) -> Int32 {
  match value {
    Some(v) => v
    None => @core.JsValue::null().cast()
  }
}

///|
/// A JS number handed to an integer GL parameter unchanged (GL truncates it), as
/// upstream passes `Math.log2( size ) + 1` mip level counts and DOM image sizes.
fn textures_js_number(value : Double) -> Int32 {
  @core.JsValue::of(value).cast()
}

///|
/// `table[ key ]`: a missing key is `undefined`, as with upstream's object tables.
fn textures_lookup(table : Map[Int32, Int32], key : Int32) -> Int32 {
  match table.get(key) {
    Some(v) => v
    None => @core.JsValue::undefined().cast()
  }
}

///|
/// An optional handle as JS sees it, with `None` as `undefined`.
fn[T] textures_undefined_or(value : T?) -> @core.JsValue {
  match value {
    Some(v) => @core.JsValue::of(v)
    None => @core.JsValue::undefined()
  }
}

///|
extern "js" fn textures_ffi_delete_framebuffer(
  gl : WebGL2RenderingContext,
  framebuffer : @core.JsValue,
) -> Unit = "(gl, f) => gl.deleteFramebuffer(f)"

///|
extern "js" fn textures_ffi_delete_renderbuffer(
  gl : WebGL2RenderingContext,
  renderbuffer : @core.JsValue,
) -> Unit = "(gl, r) => gl.deleteRenderbuffer(r)"

///|
extern "js" fn textures_ffi_delete_texture(
  gl : WebGL2RenderingContext,
  texture : @core.JsValue,
) -> Unit = "(gl, t) => gl.deleteTexture(t)"

///|
/// `data.subarray( layerIndex * layerByteLength / data.BYTES_PER_ELEMENT, ... )`.
extern "js" fn textures_layer_data(
  data : @core.JsValue,
  layer_byte_length : Double,
  layer_index : Int32,
) -> @core.JsValue =
  #|(d, l, i) => d.subarray(i * l / d.BYTES_PER_ELEMENT, (i + 1) * l / d.BYTES_PER_ELEMENT)

///|
/// `image.complete === false`.
extern "js" fn textures_image_incomplete(image : @core.JsValue) -> Bool = "(i) => i.complete === false"

///|
/// `image.naturalWidth || image.width`.
extern "js" fn textures_natural_width(image : @core.JsValue) -> Double = "(i) => i.naturalWidth || i.width"

///|
/// `image.naturalHeight || image.height`.
extern "js" fn textures_natural_height(image : @core.JsValue) -> Double = "(i) => i.naturalHeight || i.height"

///|
extern "js" fn textures_display_width(image : @core.JsValue) -> Double = "(i) => i.displayWidth"

///|
extern "js" fn textures_display_height(image : @core.JsValue) -> Double = "(i) => i.displayHeight"

///|
extern "js" fn textures_js_width(image : @core.JsValue) -> Double = "(i) => i.width"

///|
extern "js" fn textures_js_height(image : @core.JsValue) -> Double = "(i) => i.height"

///|
extern "js" fn textures_canvas_has_attribute(
  canvas : HTMLCanvasElement,
  name : String,
) -> Bool = "(c, n) => c.hasAttribute(n)"

///|
extern "js" fn textures_parent_is(
  image : @core.JsValue,
  canvas : HTMLCanvasElement,
) -> Bool = "(i, c) => i.parentNode === c"

///|
extern "js" fn textures_append_child(
  canvas : HTMLCanvasElement,
  image : @core.JsValue,
) -> Unit = "(c, i) => { c.appendChild(i); }"

///|
extern "js" fn textures_set_onpaint(
  canvas : HTMLCanvasElement,
  callback : (@core.JsValue) -> Unit,
) -> Unit = "(c, f) => { c.onpaint = f; }"

///|
extern "js" fn textures_request_paint(canvas : HTMLCanvasElement) -> Unit = "(c) => { c.requestPaint(); }"

///|
/// `event.changedElements.includes( image )`.
extern "js" fn textures_changed_includes(
  event : @core.JsValue,
  image : @core.JsValue,
) -> Bool = "(e, i) => e.changedElements.includes(i)"

///|
extern "js" fn textures_math_log2(x : Double) -> Double = "Math.log2"

///|
extern "js" fn textures_math_floor(x : Double) -> Double = "Math.floor"

///|
extern "js" fn textures_math_ceil(x : Double) -> Double = "Math.ceil"

///|
extern "js" fn textures_js_array_items(
  value : @core.JsValue,
) -> FixedArray[@core.JsValue] = "(a) => Array.from(a)"

// --- what `image` can be ----------------------------------------------------------

///|
/// `image.width` as JS passes it.
fn textures_image_width(image : @core.TextureImage) -> Int32 {
  match image {
    DataImage(d) => d.width
    DomImage(v) => textures_js_number(textures_js_width(v))
    _ => textures_js_number(image.width())
  }
}

///|
/// `image.height` as JS passes it.
fn textures_image_height(image : @core.TextureImage) -> Int32 {
  match image {
    DataImage(d) => d.height
    DomImage(v) => textures_js_number(textures_js_height(v))
    _ => textures_js_number(image.height())
  }
}

///|
/// `image.depth`.
fn textures_image_depth(image : @core.TextureImage) -> Int32 {
  match image {
    DataImage(d) =>
      match d.depth {
        Some(depth) => depth
        None => @core.JsValue::undefined().cast()
      }
    DomImage(v) => v.get("depth").cast()
    _ => textures_js_number(image.depth())
  }
}

///|
/// `image.width = width; image.height = height`.
fn textures_image_set_size(
  image : @core.TextureImage,
  width : Int32,
  height : Int32,
) -> Unit {
  match image {
    DataImage(d) => {
      d.width = width
      d.height = height
    }
    _ => {
      let value = image.to_js()
      value.set("width", @core.JsValue::of(width))
      value.set("height", @core.JsValue::of(height))
    }
  }
}

///|
/// `image.data`.
fn textures_image_data(image : @core.TextureImage) -> @core.JsValue {
  match image {
    DataImage(d) =>
      match d.data {
        Some(data) => @core.JsValue::of(data)
        None => @core.JsValue::null()
      }
    NoImage => abort("WebGLTextures: image is null")
    _ => image.to_js().get("data")
  }
}

///|
/// `image.mipmaps` (compressed images).
fn textures_image_mipmaps(
  image : @core.TextureImage,
) -> Array[@core.TextureImage] {
  match image {
    DataImage(d) =>
      match d.mipmaps {
        Some(mipmaps) => mipmaps.map(m => @core.TextureImage::DataImage(m))
        None => []
      }
    TextureImage(texture) => texture.mipmaps
    DomImage(v) =>
      Array::from_fixed_array(textures_js_array_items(v.get("mipmaps"))).map(
        @core.TextureImage::from_js,
      )
    _ => []
  }
}

///|
/// `image.image`: the image of a texture entry.
fn textures_image_image(image : @core.TextureImage) -> @core.TextureImage {
  match image {
    TextureImage(texture) => texture.image()
    DomImage(v) => @core.TextureImage::from_js(v.get("image"))
    _ => abort("WebGLTextures: image has no image")
  }
}

///|
/// `images[ i ]`.
fn textures_image_at(
  image : @core.TextureImage,
  i : Int32,
) -> @core.TextureImage {
  match image {
    ImageArray(images) => images[i]
    _ => abort("WebGLTextures: image is not an array")
  }
}

///|
/// `'data' in image`.
fn textures_image_has_data(image : @core.TextureImage) -> Bool {
  match image {
    DataImage(_) => true
    DomImage(v) => js_has_key(v, "data")
    _ => false
  }
}

///|
/// Upstream `getByteLength` from src/extras/TextureUtils.js. This package does not import
/// `extras`, so the function is repeated here.
fn textures_get_byte_length(
  width : Int32,
  height : Int32,
  format : Int32,
  type_ : Int32,
) -> Double {
  let (byte_length, components) = match type_ {
    @core.UnsignedByteType | @core.ByteType => (1.0, 1.0)
    @core.UnsignedShortType | @core.ShortType | @core.HalfFloatType =>
      (2.0, 1.0)
    @core.UnsignedShort4444Type | @core.UnsignedShort5551Type => (2.0, 4.0)
    @core.UnsignedIntType | @core.IntType | @core.FloatType => (4.0, 1.0)
    @core.UnsignedInt5999Type | @core.UnsignedInt101111Type => (4.0, 3.0)
    _ => abort("THREE.TextureUtils: Unknown texture type \{type_}.")
  }
  let w = width.to_double()
  let h = height.to_double()
  let blocks = (n : Double, m : Double, bytes : Double) => {
    textures_math_floor((w + n - 1.0) / n) *
    textures_math_floor((h + m - 1.0) / m) *
    bytes
  }
  match format {
    @core.AlphaFormat => w * h
    @core.RedFormat | @core.RedIntegerFormat => w * h / components * byte_length
    @core.RGFormat | @core.RGIntegerFormat =>
      w * h * 2.0 / components * byte_length
    @core.RGBFormat => w * h * 3.0 / components * byte_length
    @core.RGBAFormat | @core.RGBAIntegerFormat =>
      w * h * 4.0 / components * byte_length
    @core.RGB_S3TC_DXT1_Format | @core.RGBA_S3TC_DXT1_Format =>
      blocks(4.0, 4.0, 8.0)
    @core.RGBA_S3TC_DXT3_Format | @core.RGBA_S3TC_DXT5_Format =>
      blocks(4.0, 4.0, 16.0)
    @core.RGB_PVRTC_2BPPV1_Format | @core.RGBA_PVRTC_2BPPV1_Format =>
      js_math_max(w, 16.0) * js_math_max(h, 8.0) / 4.0
    @core.RGB_PVRTC_4BPPV1_Format | @core.RGBA_PVRTC_4BPPV1_Format =>
      js_math_max(w, 8.0) * js_math_max(h, 8.0) / 2.0
    @core.RGB_ETC1_Format
    | @core.RGB_ETC2_Format
    | @core.R11_EAC_Format
    | @core.SIGNED_R11_EAC_Format => blocks(4.0, 4.0, 8.0)
    @core.RGBA_ETC2_EAC_Format
    | @core.RG11_EAC_Format
    | @core.SIGNED_RG11_EAC_Format => blocks(4.0, 4.0, 16.0)
    @core.RGBA_ASTC_4x4_Format => blocks(4.0, 4.0, 16.0)
    @core.RGBA_ASTC_5x4_Format => blocks(5.0, 4.0, 16.0)
    @core.RGBA_ASTC_5x5_Format => blocks(5.0, 5.0, 16.0)
    @core.RGBA_ASTC_6x5_Format => blocks(6.0, 5.0, 16.0)
    @core.RGBA_ASTC_6x6_Format => blocks(6.0, 6.0, 16.0)
    @core.RGBA_ASTC_8x5_Format => blocks(8.0, 5.0, 16.0)
    @core.RGBA_ASTC_8x6_Format => blocks(8.0, 6.0, 16.0)
    @core.RGBA_ASTC_8x8_Format => blocks(8.0, 8.0, 16.0)
    @core.RGBA_ASTC_10x5_Format => blocks(10.0, 5.0, 16.0)
    @core.RGBA_ASTC_10x6_Format => blocks(10.0, 6.0, 16.0)
    @core.RGBA_ASTC_10x8_Format => blocks(10.0, 8.0, 16.0)
    @core.RGBA_ASTC_10x10_Format => blocks(10.0, 10.0, 16.0)
    @core.RGBA_ASTC_12x10_Format => blocks(12.0, 10.0, 16.0)
    @core.RGBA_ASTC_12x12_Format => blocks(12.0, 12.0, 16.0)
    @core.RGBA_BPTC_Format
    | @core.RGB_BPTC_SIGNED_Format
    | @core.RGB_BPTC_UNSIGNED_Format =>
      textures_math_ceil(w / 4.0) * textures_math_ceil(h / 4.0) * 16.0
    @core.RED_RGTC1_Format | @core.SIGNED_RED_RGTC1_Format =>
      textures_math_ceil(w / 4.0) * textures_math_ceil(h / 4.0) * 8.0
    @core.RED_GREEN_RGTC2_Format | @core.SIGNED_RED_GREEN_RGTC2_Format =>
      textures_math_ceil(w / 4.0) * textures_math_ceil(h / 4.0) * 16.0
    _ => abort("Unable to determine texture byte length for \{format} format.")
  }
}

// --- render target kinds -----------------------------------------------------------

///|
fn textures_is_cube_target(render_target : @core.RenderTarget) -> Bool {
  render_target.has_extension_flag("isWebGLCubeRenderTarget")
}

///|
fn textures_is_3d_target(render_target : @core.RenderTarget) -> Bool {
  render_target.has_extension_flag("isWebGL3DRenderTarget")
}

///|
fn textures_is_array_target(render_target : @core.RenderTarget) -> Bool {
  render_target.has_extension_flag("isWebGLArrayRenderTarget")
}

///|
/// `renderTargetProperties.__webglFramebuffer` as JS sees it.
fn textures_framebuffer_js(slot : WebGLFramebufferSlot?) -> @core.JsValue {
  match slot {
    None => @core.JsValue::undefined()
    Some(Framebuffer(Some(framebuffer))) => @core.JsValue::of(framebuffer)
    Some(Framebuffer(None)) => @core.JsValue::null()
    Some(Mipmaps(framebuffers)) => @core.JsValue::of(framebuffers)
    Some(CubeFaces(faces)) =>
      @core.JsValue::of(faces.map(face => textures_framebuffer_js(Some(face))))
  }
}

///|
/// `__webglFramebuffer` handed to `bindFramebuffer`, as JS passes it (a mip level array
/// reaches GL as the array, as upstream).
fn textures_framebuffer(slot : WebGLFramebufferSlot?) -> GLFramebuffer? {
  match slot {
    Some(Framebuffer(framebuffer)) => framebuffer
    None => None
    Some(_) => Some(textures_framebuffer_js(slot).cast())
  }
}

///|
/// `__webglFramebuffer[ i ]`.
fn textures_framebuffer_at(
  slot : WebGLFramebufferSlot?,
  i : Int32,
) -> WebGLFramebufferSlot? {
  match slot {
    Some(Mipmaps(framebuffers)) =>
      if i < framebuffers.length() {
        Some(Framebuffer(Some(framebuffers[i])))
      } else {
        None
      }
    Some(CubeFaces(faces)) =>
      if i < faces.length() {
        Some(faces[i])
      } else {
        None
      }
    None => abort("WebGLTextures: __webglFramebuffer is undefined")
    Some(Framebuffer(_)) => None
  }
}

// --- WebGLTextures ------------------------------------------------------------------

///|
/// `new WebGLTextures( gl, extensions, state, properties, capabilities, utils, info )`.
pub fn WebGLTextures::new(
  gl : WebGL2RenderingContext,
  extensions : WebGLExtensions,
  state : WebGLState,
  properties : WebGLProperties,
  capabilities : WebGLCapabilities,
  utils : WebGLUtils,
  info : WebGLInfo,
) -> WebGLTextures {
  let multisampled_rtt_ext = if extensions.has(
      "WEBGL_multisampled_render_to_texture",
    ) {
    extensions.get("WEBGL_multisampled_render_to_texture")
  } else {
    None
  }
  let supports_invalidate_framebuffer = match navigator_user_agent() {
    Some(user_agent) => user_agent.contains("OculusBrowser")
    None => false
  }
  let tracked : Array[TrackedRef] = []
  let self : WebGLTextures = {
    gl,
    extensions,
    state,
    properties,
    capabilities,
    utils,
    info,
    multisampled_rtt_ext,
    supports_invalidate_framebuffer,
    _image_dimensions: @math.Vector2::new(0.0, 0.0),
    _video_textures: WeakMap::new(),
    _html_textures: Map([]),
    _canvas: None,
    _sources: WeakMap::new(),
    _tracked: tracked,
    _registry: FinalizationRegistry::new(ref_ => {
      textures_tracked_delete(tracked, ref_)
    }),
    use_offscreen_canvas: offscreen_canvas_2d_supported(),
    texture_units: 0,
    wrapping_to_gl: Map::from_array([
      (@core.RepeatWrapping, GL_REPEAT),
      (@core.ClampToEdgeWrapping, GL_CLAMP_TO_EDGE),
      (@core.MirroredRepeatWrapping, GL_MIRRORED_REPEAT),
    ]),
    filter_to_gl: Map::from_array([
      (@core.NearestFilter, GL_NEAREST),
      (@core.NearestMipmapNearestFilter, GL_NEAREST_MIPMAP_NEAREST),
      (@core.NearestMipmapLinearFilter, GL_NEAREST_MIPMAP_LINEAR),
      (@core.LinearFilter, GL_LINEAR),
      (@core.LinearMipmapNearestFilter, GL_LINEAR_MIPMAP_NEAREST),
      (@core.LinearMipmapLinearFilter, GL_LINEAR_MIPMAP_LINEAR),
    ]),
    compare_to_gl: Map::from_array([
      (@core.NeverCompare, GL_NEVER),
      (@core.AlwaysCompare, GL_ALWAYS),
      (@core.LessCompare, GL_LESS),
      (@core.LessEqualCompare, GL_LEQUAL),
      (@core.EqualCompare, GL_EQUAL),
      (@core.GreaterEqualCompare, GL_GEQUAL),
      (@core.GreaterCompare, GL_GREATER),
      (@core.NotEqualCompare, GL_NOTEQUAL),
    ]),
    invalidation_array_read: [],
    on_texture_dispose: _ => (),
    on_render_target_dispose: _ => (),
  }
  self.on_texture_dispose = event => {
    match event.target {
      Some(Texture(texture)) => self.destroy_texture(texture)
      _ => ()
    }
  }
  self.on_render_target_dispose = event => {
    match event.target {
      Some(RenderTarget(render_target)) =>
        self.destroy_render_target(render_target)
      _ => ()
    }
  }
  self
}

///|
fn textures_tracked_same(a : TrackedRef, b : TrackedRef) -> Bool {
  match (a, b) {
    (TextureRef(x), TextureRef(y)) => physical_equal(x, y)
    (RenderTargetRef(x), RenderTargetRef(y)) => physical_equal(x, y)
    _ => false
  }
}

///|
/// `_tracked.delete( ref )`.
fn textures_tracked_delete(
  tracked : Array[TrackedRef],
  ref_ : TrackedRef,
) -> Unit {
  for i, item in tracked {
    if textures_tracked_same(item, ref_) {
      ignore(tracked.remove(i))
      return
    }
  }
}

///|
fn textures_tracked_has(tracked : Array[TrackedRef], ref_ : TrackedRef) -> Bool {
  for item in tracked {
    if textures_tracked_same(item, ref_) {
      return true
    }
  }
  false
}

///|
/// `createCanvas( width, height )`.
fn WebGLTextures::create_canvas(
  self : WebGLTextures,
  width : Int32,
  height : Int32,
) -> HTMLCanvasElement {
  if self.use_offscreen_canvas {
    new_offscreen_canvas(width, height)
  } else {
    create_element_ns("canvas").cast()
  }
}

///|
/// `resizeImage( image, needsNewCanvas, maxSize )`.
fn WebGLTextures::resize_image(
  self : WebGLTextures,
  image : @core.TextureImage,
  needs_new_canvas : Bool,
  max_size : Int32,
) -> @core.TextureImage {
  let mut scale = 1.0
  let dimensions = self.get_dimensions(image)
  let max_size = max_size.to_double()
  // handle case if texture exceeds max size
  if dimensions.x > max_size || dimensions.y > max_size {
    scale = max_size / js_math_max(dimensions.x, dimensions.y)
  }
  // only perform resize if necessary
  if scale < 1.0 {
    // only perform resize for certain image types
    match image {
      DomImage(value) if is_html_image_element(value) ||
        is_html_canvas_element(value) ||
        is_image_bitmap(value) ||
        is_video_frame(value) => {
        let width_d = textures_math_floor(scale * dimensions.x)
        let height_d = textures_math_floor(scale * dimensions.y)
        let width = textures_js_number(width_d)
        let height = textures_js_number(height_d)
        if self._canvas is None {
          self._canvas = Some(self.create_canvas(width, height))
        }
        // cube textures can't reuse the same canvas
        let canvas = if needs_new_canvas {
          self.create_canvas(width, height)
        } else {
          self._canvas.unwrap()
        }
        canvas.set_width(width)
        canvas.set_height(height)
        let context = canvas.get_context_2d().unwrap()
        context.draw_image(value, 0.0, 0.0, width_d, height_d)
        @core.warn(
          "WebGLRenderer: Texture has been resized from (\{dimensions.x}x\{dimensions.y}) to (\{width_d}x\{height_d}).",
        )
        return DomImage(@core.JsValue::of(canvas))
      }
      _ => {
        if textures_image_has_data(image) {
          @core.warn(
            "WebGLRenderer: Image in DataTexture is too big (\{dimensions.x}x\{dimensions.y}).",
          )
        }
        return image
      }
    }
  }
  image
}

///|
/// `textureNeedsGenerateMipmaps( texture )`.
fn textures_needs_generate_mipmaps(texture : @core.Texture) -> Bool {
  texture.generate_mipmaps
}

///|
/// `generateMipmap( target )`.
fn WebGLTextures::generate_mipmap(self : WebGLTextures, target : Int32) -> Unit {
  self.gl.generate_mipmap(target)
}

///|
/// `getTargetType( renderTarget )`.
fn textures_get_target_type(render_target : @core.RenderTarget) -> Int32 {
  if textures_is_cube_target(render_target) {
    return GL_TEXTURE_CUBE_MAP
  }
  if textures_is_3d_target(render_target) {
    return GL_TEXTURE_3D
  }
  if textures_is_array_target(render_target) {
    return GL_TEXTURE_2D_ARRAY
  }
  GL_TEXTURE_2D
}

///|
/// `getInternalFormat( internalFormatName, glFormat, glType, normalized, colorSpace,
/// forceLinearTransfer )`.
fn WebGLTextures::get_internal_format(
  self : WebGLTextures,
  internal_format_name : String?,
  gl_format : Int32?,
  gl_type : Int32?,
  normalized : Bool,
  color_space : String,
  force_linear_transfer~ : Bool = false,
) -> Int32? {
  if internal_format_name is Some(name) {
    if self.gl.get_constant(name) is Some(value) {
      return Some(value)
    }
    @core.warn(
      "WebGLRenderer: Attempt to use non-existing WebGL internal format '\{name}'",
    )
  }
  let mut ext_texture_norm16 : GLExtension? = None
  if normalized {
    ext_texture_norm16 = self.extensions.get("EXT_texture_norm16")
    if ext_texture_norm16 is None {
      @core.warn(
        "WebGLRenderer: Unable to use normalized textures without EXT_texture_norm16 extension",
      )
    }
  }
  let norm16 = (name : String) => {
    match ext_texture_norm16 {
      Some(ext) => Some(ext.constant(name))
      None => None
    }
  }
  let mut internal_format = gl_format
  let eq = (value : Int32?, constant : Int32) => value == Some(constant)
  if eq(gl_format, GL_RED) {
    if eq(gl_type, GL_FLOAT) {
      internal_format = Some(GL_R32F)
    }
    if eq(gl_type, GL_HALF_FLOAT) {
      internal_format = Some(GL_R16F)
    }
    if eq(gl_type, GL_UNSIGNED_BYTE) {
      internal_format = Some(GL_R8)
    }
    if eq(gl_type, GL_UNSIGNED_SHORT) && ext_texture_norm16 is Some(_) {
      internal_format = norm16("R16_EXT")
    }
    if eq(gl_type, GL_SHORT) && ext_texture_norm16 is Some(_) {
      internal_format = norm16("R16_SNORM_EXT")
    }
  }
  if eq(gl_format, GL_RED_INTEGER) {
    if eq(gl_type, GL_UNSIGNED_BYTE) {
      internal_format = Some(GL_R8UI)
    }
    if eq(gl_type, GL_UNSIGNED_SHORT) {
      internal_format = Some(GL_R16UI)
    }
    if eq(gl_type, GL_UNSIGNED_INT) {
      internal_format = Some(GL_R32UI)
    }
    if eq(gl_type, GL_BYTE) {
      internal_format = Some(GL_R8I)
    }
    if eq(gl_type, GL_SHORT) {
      internal_format = Some(GL_R16I)
    }
    if eq(gl_type, GL_INT) {
      internal_format = Some(GL_R32I)
    }
  }
  if eq(gl_format, GL_RG) {
    if eq(gl_type, GL_FLOAT) {
      internal_format = Some(GL_RG32F)
    }
    if eq(gl_type, GL_HALF_FLOAT) {
      internal_format = Some(GL_RG16F)
    }
    if eq(gl_type, GL_UNSIGNED_BYTE) {
      internal_format = Some(GL_RG8)
    }
    if eq(gl_type, GL_UNSIGNED_SHORT) && ext_texture_norm16 is Some(_) {
      internal_format = norm16("RG16_EXT")
    }
    if eq(gl_type, GL_SHORT) && ext_texture_norm16 is Some(_) {
      internal_format = norm16("RG16_SNORM_EXT")
    }
  }
  if eq(gl_format, GL_RG_INTEGER) {
    if eq(gl_type, GL_UNSIGNED_BYTE) {
      internal_format = Some(GL_RG8UI)
    }
    if eq(gl_type, GL_UNSIGNED_SHORT) {
      internal_format = Some(GL_RG16UI)
    }
    if eq(gl_type, GL_UNSIGNED_INT) {
      internal_format = Some(GL_RG32UI)
    }
    if eq(gl_type, GL_BYTE) {
      internal_format = Some(GL_RG8I)
    }
    if eq(gl_type, GL_SHORT) {
      internal_format = Some(GL_RG16I)
    }
    if eq(gl_type, GL_INT) {
      internal_format = Some(GL_RG32I)
    }
  }
  if eq(gl_format, GL_RGB_INTEGER) {
    if eq(gl_type, GL_UNSIGNED_BYTE) {
      internal_format = Some(GL_RGB8UI)
    }
    if eq(gl_type, GL_UNSIGNED_SHORT) {
      internal_format = Some(GL_RGB16UI)
    }
    if eq(gl_type, GL_UNSIGNED_INT) {
      internal_format = Some(GL_RGB32UI)
    }
    if eq(gl_type, GL_BYTE) {
      internal_format = Some(GL_RGB8I)
    }
    if eq(gl_type, GL_SHORT) {
      internal_format = Some(GL_RGB16I)
    }
    if eq(gl_type, GL_INT) {
      internal_format = Some(GL_RGB32I)
    }
  }
  if eq(gl_format, GL_RGBA_INTEGER) {
    if eq(gl_type, GL_UNSIGNED_BYTE) {
      internal_format = Some(GL_RGBA8UI)
    }
    if eq(gl_type, GL_UNSIGNED_SHORT) {
      internal_format = Some(GL_RGBA16UI)
    }
    if eq(gl_type, GL_UNSIGNED_INT) {
      internal_format = Some(GL_RGBA32UI)
    }
    if eq(gl_type, GL_BYTE) {
      internal_format = Some(GL_RGBA8I)
    }
    if eq(gl_type, GL_SHORT) {
      internal_format = Some(GL_RGBA16I)
    }
    if eq(gl_type, GL_INT) {
      internal_format = Some(GL_RGBA32I)
    }
  }
  if eq(gl_format, GL_RGB) {
    if eq(gl_type, GL_UNSIGNED_SHORT) && ext_texture_norm16 is Some(_) {
      internal_format = norm16("RGB16_EXT")
    }
    if eq(gl_type, GL_SHORT) && ext_texture_norm16 is Some(_) {
      internal_format = norm16("RGB16_SNORM_EXT")
    }
    if eq(gl_type, GL_UNSIGNED_INT_5_9_9_9_REV) {
      internal_format = Some(GL_RGB9_E5)
    }
    if eq(gl_type, GL_UNSIGNED_INT_10F_11F_11F_REV) {
      internal_format = Some(GL_R11F_G11F_B10F)
    }
  }
  if eq(gl_format, GL_RGBA) {
    let transfer = if force_linear_transfer {
      @core.LinearTransfer
    } else {
      @math.color_management.get_transfer(color_space)
    }
    if eq(gl_type, GL_FLOAT) {
      internal_format = Some(GL_RGBA32F)
    }
    if eq(gl_type, GL_HALF_FLOAT) {
      internal_format = Some(GL_RGBA16F)
    }
    if eq(gl_type, GL_UNSIGNED_BYTE) {
      internal_format = Some(
        if transfer == @core.SRGBTransfer {
          GL_SRGB8_ALPHA8
        } else {
          GL_RGBA8
        },
      )
    }
    if eq(gl_type, GL_UNSIGNED_SHORT) && ext_texture_norm16 is Some(_) {
      internal_format = norm16("RGBA16_EXT")
    }
    if eq(gl_type, GL_SHORT) && ext_texture_norm16 is Some(_) {
      internal_format = norm16("RGBA16_SNORM_EXT")
    }
    if eq(gl_type, GL_UNSIGNED_SHORT_4_4_4_4) {
      internal_format = Some(GL_RGBA4)
    }
    if eq(gl_type, GL_UNSIGNED_SHORT_5_5_5_1) {
      internal_format = Some(GL_RGB5_A1)
    }
  }
  if eq(internal_format, GL_R16F) ||
    eq(internal_format, GL_R32F) ||
    eq(internal_format, GL_RG16F) ||
    eq(internal_format, GL_RG32F) ||
    eq(internal_format, GL_RGBA16F) ||
    eq(internal_format, GL_RGBA32F) {
    ignore(self.extensions.get("EXT_color_buffer_float"))
  }
  internal_format
}

///|
/// `getInternalDepthFormat( useStencil, depthType )`; `None` depth type is `null`, and
/// an unknown type gives `undefined` (`None`).
fn textures_get_internal_depth_format(
  use_stencil : Bool,
  depth_type : Int32?,
) -> Int32? {
  let default = depth_type
    is (None | Some(@core.UnsignedIntType | @core.UnsignedInt248Type))
  if use_stencil {
    if default {
      Some(GL_DEPTH24_STENCIL8)
    } else if depth_type == Some(@core.FloatType) {
      Some(GL_DEPTH32F_STENCIL8)
    } else if depth_type == Some(@core.UnsignedShortType) {
      @core.warn(
        "DepthTexture: 16 bit depth attachment is not supported with stencil. Using 24-bit attachment.",
      )
      Some(GL_DEPTH24_STENCIL8)
    } else {
      None
    }
  } else if default {
    Some(GL_DEPTH_COMPONENT24)
  } else if depth_type == Some(@core.FloatType) {
    Some(GL_DEPTH_COMPONENT32F)
  } else if depth_type == Some(@core.UnsignedShortType) {
    Some(GL_DEPTH_COMPONENT16)
  } else {
    None
  }
}

///|
/// An internal depth format as JS passes it (`undefined` when unknown).
fn textures_depth_enum(value : Int32?) -> Int32 {
  match value {
    Some(v) => v
    None => @core.JsValue::undefined().cast()
  }
}

///|
/// `getMipLevels( texture, image )`; may be fractional, as upstream.
fn textures_get_mip_levels(
  texture : @core.Texture,
  image : @core.TextureImage,
) -> Double {
  if textures_needs_generate_mipmaps(texture) ||
    (
      texture.texture_type is FramebufferTexture &&
      texture.min_filter != @core.NearestFilter &&
      texture.min_filter != @core.LinearFilter
    ) {
    textures_math_log2(
      js_math_max(
        textures_image_width(image).to_double(),
        textures_image_height(image).to_double(),
      ),
    ) +
    1.0
  } else if texture.mipmaps.length() > 0 {
    // user-defined mipmaps
    texture.mipmaps.length().to_double()
  } else if texture.is_compressed_texture() && texture.image() is ImageArray(_) {
    textures_image_mipmaps(image).length().to_double()
  } else {
    // texture without mipmaps (only base level)
    1.0
  }
}

// --- tracking and disposal -----------------------------------------------------------

///|
/// `track( texture )`.
fn WebGLTextures::track_texture(
  self : WebGLTextures,
  texture : @core.Texture,
) -> Unit {
  let ref_ = WeakRef::new(texture)
  self.properties.get_texture(texture).__ref = Some(ref_)
  let tracked = TextureRef(ref_)
  self._tracked.push(tracked)
  self._registry.register(texture, tracked, ref_)
}

///|
/// `track( renderTarget )`.
fn WebGLTextures::track_render_target(
  self : WebGLTextures,
  render_target : @core.RenderTarget,
) -> Unit {
  let ref_ = WeakRef::new(render_target)
  self.properties.get_render_target(render_target).__ref = Some(ref_)
  let tracked = RenderTargetRef(ref_)
  self._tracked.push(tracked)
  self._registry.register(render_target, tracked, ref_)
}

///|
/// `untrack( texture )`.
fn WebGLTextures::untrack_texture(
  self : WebGLTextures,
  texture : @core.Texture,
) -> Unit {
  guard self.properties.get_texture(texture).__ref is Some(ref_) else { return }
  textures_tracked_delete(self._tracked, TextureRef(ref_))
  self._registry.unregister(ref_)
}

///|
/// `untrack( renderTarget )`.
fn WebGLTextures::untrack_render_target(
  self : WebGLTextures,
  render_target : @core.RenderTarget,
) -> Unit {
  guard self.properties.get_render_target(render_target).__ref is Some(ref_) else {
    return
  }
  textures_tracked_delete(self._tracked, RenderTargetRef(ref_))
  self._registry.unregister(ref_)
}

///|
/// `destroyTexture( texture )`.
fn WebGLTextures::destroy_texture(
  self : WebGLTextures,
  texture : @core.Texture,
) -> Unit {
  texture.remove_event_listener("dispose", self.on_texture_dispose)
  self.untrack_texture(texture)
  self.deallocate_texture(texture)
  if texture.is_video_texture() {
    self._video_textures.delete(texture)
  }
  if texture.texture_type is HTMLTexture {
    self._html_textures.remove(texture.id)
  }
}

///|
/// `destroyRenderTarget( renderTarget )`.
fn WebGLTextures::destroy_render_target(
  self : WebGLTextures,
  render_target : @core.RenderTarget,
) -> Unit {
  render_target.remove_event_listener("dispose", self.on_render_target_dispose)
  self.untrack_render_target(render_target)
  self.deallocate_render_target(render_target)
}

///|
/// `textures.dispose()`: frees every tracked texture and render target.
pub fn WebGLTextures::dispose(self : WebGLTextures) -> Unit {
  // a `Set` iteration: entries deleted before they are reached are skipped
  let entries = self._tracked.copy()
  for tracked in entries {
    if !textures_tracked_has(self._tracked, tracked) {
      continue
    }
    match tracked {
      RenderTargetRef(ref_) =>
        match ref_.deref() {
          Some(render_target) => self.destroy_render_target(render_target)
          None => continue
        }
      TextureRef(ref_) =>
        match ref_.deref() {
          Some(texture) => self.destroy_texture(texture)
          None => continue
        }
    }
  }
  self._tracked.clear()
  self._html_textures.clear()
}

///|
/// `deallocateTexture( texture )`.
fn WebGLTextures::deallocate_texture(
  self : WebGLTextures,
  texture : @core.Texture,
) -> Unit {
  let texture_properties = self.properties.get_texture(texture)
  if !texture_properties.__webgl_init {
    return
  }
  // check if it's necessary to remove the WebGLTexture object
  let source = texture.source
  if self._sources.get(source) is Some(webgl_textures) {
    let key = texture_properties.__cache_key.unwrap_or("undefined")
    guard webgl_textures.get(key) is Some(webgl_texture) else {
      abort("WebGLTextures: no WebGLTexture for cache key " + key)
    }
    webgl_texture.used_times -= 1
    // the WebGLTexture object is not used anymore, remove it
    if webgl_texture.used_times == 0 {
      self.delete_texture(texture)
    }
    // remove the weak map entry if no WebGLTexture uses the source anymore
    if webgl_textures.is_empty() {
      self._sources.delete(source)
    }
  }
  self.properties.remove(texture)
}

///|
/// `deleteTexture( texture )`.
fn WebGLTextures::delete_texture(
  self : WebGLTextures,
  texture : @core.Texture,
) -> Unit {
  let texture_properties = self.properties.get_texture(texture)
  textures_ffi_delete_texture(
    self.gl,
    textures_undefined_or(texture_properties.__webgl_texture),
  )
  let source = texture.source
  if self._sources.get(source) is Some(webgl_textures) {
    webgl_textures.remove(texture_properties.__cache_key.unwrap_or("undefined"))
  }
  self.info.memory.textures -= 1
}

///|
/// `_gl.deleteFramebuffer( slot )`, or each level of an array.
fn WebGLTextures::delete_framebuffer_slot(
  self : WebGLTextures,
  slot : WebGLFramebufferSlot?,
) -> Unit {
  match slot {
    Some(Mipmaps(framebuffers)) =>
      for framebuffer in framebuffers {
        self.gl.delete_framebuffer(framebuffer)
      }
    Some(Framebuffer(Some(framebuffer))) =>
      self.gl.delete_framebuffer(framebuffer)
    Some(CubeFaces(faces)) =>
      for face in faces {
        textures_ffi_delete_framebuffer(
          self.gl,
          textures_framebuffer_js(Some(face)),
        )
      }
    _ => textures_ffi_delete_framebuffer(self.gl, textures_framebuffer_js(slot))
  }
}

///|
/// `deallocateRenderTarget( renderTarget )`.
fn WebGLTextures::deallocate_render_target(
  self : WebGLTextures,
  render_target : @core.RenderTarget,
) -> Unit {
  let gl = self.gl
  let render_target_properties = self.properties.get_render_target(
    render_target,
  )
  if render_target_properties.__depth_dispose_callback is Some(callback) {
    callback()
  }
  // only destroy depth texture the render target owns
  if render_target.depth_texture() is Some(depth_texture) &&
    depth_texture.render_target is Some(owner) &&
    physical_equal(owner, render_target) {
    self.destroy_texture(depth_texture)
  }
  if textures_is_cube_target(render_target) {
    for i in 0..<6 {
      let face = match render_target_properties.__webgl_framebuffer {
        Some(CubeFaces(faces)) =>
          if i < faces.length() {
            Some(faces[i])
          } else {
            None
          }
        None => abort("WebGLTextures: __webglFramebuffer is undefined")
        Some(Mipmaps(framebuffers)) =>
          if i < framebuffers.length() {
            Some(Framebuffer(Some(framebuffers[i])))
          } else {
            None
          }
        Some(Framebuffer(_)) => None
      }
      self.delete_framebuffer_slot(face)
      match render_target_properties.__webgl_depthbuffer {
        Some(CubeFaces(renderbuffers)) =>
          textures_ffi_delete_renderbuffer(
            gl,
            if i < renderbuffers.length() {
              textures_undefined_or(renderbuffers[i])
            } else {
              @core.JsValue::undefined()
            },
          )
        Some(Renderbuffer(_)) =>
          textures_ffi_delete_renderbuffer(gl, @core.JsValue::undefined())
        None => ()
      }
    }
  } else {
    self.delete_framebuffer_slot(render_target_properties.__webgl_framebuffer)
    match render_target_properties.__webgl_depthbuffer {
      Some(Renderbuffer(renderbuffer)) => gl.delete_renderbuffer(renderbuffer)
      Some(CubeFaces(renderbuffers)) =>
        textures_ffi_delete_renderbuffer(gl, @core.JsValue::of(renderbuffers))
      None => ()
    }
    if render_target_properties.__webgl_multisampled_framebuffer
      is Some(framebuffer) {
      gl.delete_framebuffer(framebuffer)
    }
    if render_target_properties.__webgl_color_renderbuffer
      is Some(renderbuffers) {
      for renderbuffer in renderbuffers {
        if renderbuffer is Some(renderbuffer) {
          gl.delete_renderbuffer(renderbuffer)
        }
      }
    }
    if render_target_properties.__webgl_depth_renderbuffer is Some(renderbuffer) {
      gl.delete_renderbuffer(renderbuffer)
    }
  }
  let textures = render_target.textures
  for texture in textures {
    let attachment_properties = self.properties.get_texture(texture)
    if attachment_properties.__webgl_texture is Some(webgl_texture) {
      gl.delete_texture(webgl_texture)
      self.info.memory.textures -= 1
    }
    self.properties.remove(texture)
  }
  self.properties.remove(render_target)
}

// --- texture units -------------------------------------------------------------------

///|
/// `textures.allocateTextureUnit()`.
pub fn WebGLTextures::allocate_texture_unit(self : WebGLTextures) -> Int32 {
  let texture_unit = self.texture_units
  if texture_unit >= self.capabilities.max_textures {
    @core.warn(
      "WebGLTextures: Trying to use \{texture_unit + 1} texture units while this GPU supports only \{self.capabilities.max_textures}",
    )
  }
  self.texture_units += 1
  texture_unit
}

///|
/// `textures.resetTextureUnits()`.
pub fn WebGLTextures::reset_texture_units(self : WebGLTextures) -> Unit {
  self.texture_units = 0
}

///|
/// `textures.getTextureUnits()`.
pub fn WebGLTextures::get_texture_units(self : WebGLTextures) -> Int32 {
  self.texture_units
}

///|
/// `textures.setTextureUnits( value )`.
pub fn WebGLTextures::set_texture_units(
  self : WebGLTextures,
  value : Int32,
) -> Unit {
  self.texture_units = value
}

///|
/// `getTextureCacheKey( texture )`: `array.join()` of the upload parameters.
fn textures_get_texture_cache_key(texture : @core.Texture) -> String {
  let array : Array[String] = [
    texture.wrap_s.to_string(),
    texture.wrap_t.to_string(),
    textures_wrap_r(texture).unwrap_or(0).to_string(),
    texture.mag_filter.to_string(),
    texture.min_filter.to_string(),
    texture.anisotropy.to_string(),
    texture.internal_format.unwrap_or(""),
    texture.format.to_string(),
    texture.type_.to_string(),
    texture.generate_mipmaps.to_string(),
    texture.mipmaps_auto_update.to_string(),
    texture.premultiply_alpha.to_string(),
    texture.flip_y.to_string(),
    texture.unpack_alignment.to_string(),
    texture.color_space,
  ]
  array.join(",")
}

// --- binding -------------------------------------------------------------------------

///|
/// `texture.sourceTexture ? texture.sourceTexture : null` for an `ExternalTexture`: the
/// GL handle in `external_source`.
fn textures_external_source(texture : @core.Texture) -> GLTexture? {
  match texture.external_source {
    Some(value) if js_truthy(value) => Some(value.cast())
    _ => None
  }
}

///|
/// `textures.setTexture2D( texture, slot )`.
pub fn WebGLTextures::set_texture2d(
  self : WebGLTextures,
  texture : @core.Texture,
  slot : Int32,
) -> Unit {
  let texture_properties = self.properties.get_texture(texture)
  if texture.is_video_texture() {
    self.update_video_texture(texture)
  }
  if !texture.is_render_target_texture &&
    !(texture.texture_type is ExternalTexture) &&
    texture.version > 0 &&
    texture_properties.__version != Some(texture.version) {
    match texture.image() {
      NoImage =>
        @core.warn(
          "WebGLRenderer: Texture marked for update but no image data found.",
        )
      DomImage(value) if textures_image_incomplete(value) =>
        @core.warn(
          "WebGLRenderer: Texture marked for update but image is incomplete",
        )
      _ => {
        self.upload_texture(texture_properties, texture, slot)
        return
      }
    }
  } else if texture.texture_type is ExternalTexture {
    texture_properties.__webgl_texture = textures_external_source(texture)
  }
  self.state.bind_texture(
    GL_TEXTURE_2D,
    texture_properties.__webgl_texture,
    webgl_slot=GL_TEXTURE0 + slot,
  )
}

///|
/// `textures.setTexture2DArray( texture, slot )`.
pub fn WebGLTextures::set_texture2d_array(
  self : WebGLTextures,
  texture : @core.Texture,
  slot : Int32,
) -> Unit {
  let texture_properties = self.properties.get_texture(texture)
  if !texture.is_render_target_texture &&
    texture.version > 0 &&
    texture_properties.__version != Some(texture.version) {
    self.upload_texture(texture_properties, texture, slot)
    return
  } else if texture.texture_type is ExternalTexture {
    texture_properties.__webgl_texture = textures_external_source(texture)
  }
  self.state.bind_texture(
    GL_TEXTURE_2D_ARRAY,
    texture_properties.__webgl_texture,
    webgl_slot=GL_TEXTURE0 + slot,
  )
}

///|
/// `textures.setTexture3D( texture, slot )`.
pub fn WebGLTextures::set_texture3d(
  self : WebGLTextures,
  texture : @core.Texture,
  slot : Int32,
) -> Unit {
  let texture_properties = self.properties.get_texture(texture)
  if !texture.is_render_target_texture &&
    texture.version > 0 &&
    texture_properties.__version != Some(texture.version) {
    self.upload_texture(texture_properties, texture, slot)
    return
  }
  self.state.bind_texture(
    GL_TEXTURE_3D,
    texture_properties.__webgl_texture,
    webgl_slot=GL_TEXTURE0 + slot,
  )
}

///|
/// `textures.setTextureCube( texture, slot )`.
pub fn WebGLTextures::set_texture_cube(
  self : WebGLTextures,
  texture : @core.Texture,
  slot : Int32,
) -> Unit {
  let texture_properties = self.properties.get_texture(texture)
  if texture.version > 0 &&
    texture_properties.__version != Some(texture.version) {
    self.upload_cube_texture(texture_properties, texture, slot)
    return
  }
  self.state.bind_texture(
    GL_TEXTURE_CUBE_MAP,
    texture_properties.__webgl_texture,
    webgl_slot=GL_TEXTURE0 + slot,
  )
}

///|
fn textures_is_linear_filter(filter : Int32) -> Bool {
  filter == @core.LinearFilter ||
  filter == @core.LinearMipmapNearestFilter ||
  filter == @core.NearestMipmapLinearFilter ||
  filter == @core.LinearMipmapLinearFilter
}

///|
/// `setTextureParameters( textureType, texture )`.
fn WebGLTextures::set_texture_parameters(
  self : WebGLTextures,
  texture_type : Int32,
  texture : @core.Texture,
) -> Unit {
  let gl = self.gl
  if texture.type_ == @core.FloatType &&
    !self.extensions.has("OES_texture_float_linear") &&
    (
      textures_is_linear_filter(texture.mag_filter) ||
      textures_is_linear_filter(texture.min_filter)
    ) {
    @core.warn(
      "WebGLRenderer: Unable to use linear filtering with floating point textures. OES_texture_float_linear not supported on this device.",
    )
  }
  gl.tex_parameteri(
    texture_type,
    GL_TEXTURE_WRAP_S,
    textures_lookup(self.wrapping_to_gl, texture.wrap_s),
  )
  gl.tex_parameteri(
    texture_type,
    GL_TEXTURE_WRAP_T,
    textures_lookup(self.wrapping_to_gl, texture.wrap_t),
  )
  if texture_type == GL_TEXTURE_3D || texture_type == GL_TEXTURE_2D_ARRAY {
    gl.tex_parameteri(
      texture_type,
      GL_TEXTURE_WRAP_R,
      match textures_wrap_r(texture) {
        Some(wrap_r) => textures_lookup(self.wrapping_to_gl, wrap_r)
        None => @core.JsValue::undefined().cast()
      },
    )
  }
  gl.tex_parameteri(
    texture_type,
    GL_TEXTURE_MAG_FILTER,
    textures_lookup(self.filter_to_gl, texture.mag_filter),
  )
  gl.tex_parameteri(
    texture_type,
    GL_TEXTURE_MIN_FILTER,
    textures_lookup(self.filter_to_gl, texture.min_filter),
  )
  if texture.compare_function is Some(compare_function) && compare_function != 0 {
    gl.tex_parameteri(
      texture_type,
      GL_TEXTURE_COMPARE_MODE,
      GL_COMPARE_REF_TO_TEXTURE,
    )
    gl.tex_parameteri(
      texture_type,
      GL_TEXTURE_COMPARE_FUNC,
      textures_lookup(self.compare_to_gl, compare_function),
    )
  }
  if self.extensions.has("EXT_texture_filter_anisotropic") {
    if texture.mag_filter == @core.NearestFilter {
      return
    }
    if texture.min_filter != @core.NearestMipmapLinearFilter &&
      texture.min_filter != @core.LinearMipmapLinearFilter {
      return
    }
    if texture.type_ == @core.FloatType &&
      !self.extensions.has("OES_texture_float_linear") {
      return // verify extension
    }
    let current = self.properties.get_texture(texture).__current_anisotropy
    if texture.anisotropy > 1 || (current is Some(value) && value != 0) {
      guard self.extensions.get("EXT_texture_filter_anisotropic")
        is Some(extension) else {
        abort("WebGLTextures: EXT_texture_filter_anisotropic is missing")
      }
      gl.tex_parameterf(
        texture_type,
        extension.constant("TEXTURE_MAX_ANISOTROPY_EXT"),
        js_math_min(
          texture.anisotropy.to_double(),
          self.capabilities.get_max_anisotropy(),
        ),
      )
      self.properties.get_texture(texture).__current_anisotropy = Some(
        texture.anisotropy,
      )
    }
  }
}

///|
/// `initTexture( textureProperties, texture )`: true when a new GL texture was created.
fn WebGLTextures::init_texture(
  self : WebGLTextures,
  texture_properties : TextureProperties,
  texture : @core.Texture,
) -> Bool {
  let mut force_upload = false
  if !texture_properties.__webgl_init {
    texture_properties.__webgl_init = true
    texture.add_event_listener("dispose", self.on_texture_dispose)
    self.track_texture(texture)
  }
  // create TextureSource <-> WebGLTextures mapping if necessary
  let source = texture.source
  let webgl_textures = match self._sources.get(source) {
    Some(webgl_textures) => webgl_textures
    None => {
      let webgl_textures : Map[String, TextureCacheEntry] = Map([])
      self._sources.set(source, webgl_textures)
      webgl_textures
    }
  }
  // check if there is already a WebGLTexture object for the given texture parameters
  let texture_cache_key = textures_get_texture_cache_key(texture)
  if texture_properties.__cache_key != Some(texture_cache_key) {
    // if not, create a new instance of WebGLTexture
    if !webgl_textures.contains(texture_cache_key) {
      // create new entry
      webgl_textures[texture_cache_key] = {
        texture: self.gl.create_texture(),
        used_times: 0,
      }
      self.info.memory.textures += 1
      // when a new instance of WebGLTexture was created, a texture upload is required
      // even if the image contents are identical
      force_upload = true
    }
    webgl_textures[texture_cache_key].used_times += 1
    // every time the texture cache key changes, it's necessary to check if an instance of
    // WebGLTexture can be deleted in order to avoid a memory leak.
    let old_key = texture_properties.__cache_key.unwrap_or("undefined")
    if webgl_textures.get(old_key) is Some(webgl_texture) {
      webgl_texture.used_times -= 1
      if webgl_texture.used_times == 0 {
        self.delete_texture(texture)
      }
    }
    // store references to cache key and WebGLTexture object
    texture_properties.__cache_key = Some(texture_cache_key)
    texture_properties.__webgl_texture = Some(
      webgl_textures[texture_cache_key].texture,
    )
  }
  force_upload
}

///|
/// `getRow( index, rowLength, componentStride )`.
fn textures_get_row(
  index : Int32,
  row_length : Int32,
  component_stride : Int32,
) -> Double {
  textures_math_floor(
    textures_math_floor(index.to_double() / component_stride.to_double()) /
    row_length.to_double(),
  )
}

///|
/// `updateTexture( texture, image, glFormat, glType )`: uploads a data texture, merging
/// its update ranges.
fn WebGLTextures::update_texture(
  self : WebGLTextures,
  texture : @core.Texture,
  image : @core.TextureImage,
  gl_format : Int32,
  gl_type : Int32,
) -> Unit {
  let state = self.state
  let component_stride = 4 // only RGBA supported
  let update_ranges = texture.update_ranges
  let width = textures_image_width(image)
  let height = textures_image_height(image)
  let data = textures_image_data(image)
  if update_ranges.length() == 0 {
    state.tex_sub_image2d(
      GL_TEXTURE_2D,
      0,
      0,
      0,
      width,
      height,
      gl_format,
      gl_type,
      data,
    )
  } else {
    // merge adjacent / overlapping ranges in place
    stable_sort_by(update_ranges, (a, b) => (a.start - b.start).to_double())
    let mut merge_index = 0
    for i in 1..<update_ranges.length() {
      let previous_range = update_ranges[merge_index]
      let range = update_ranges[i]
      // Only merge if in the same row and overlapping/adjacent
      let previous_end = previous_range.start + previous_range.count
      let current_row = textures_get_row(range.start, width, component_stride)
      let previous_row = textures_get_row(
        previous_range.start,
        width,
        component_stride,
      )
      if range.start <= previous_end + 1 &&
        current_row == previous_row &&
        textures_get_row(range.start + range.count - 1, width, component_stride) ==
        current_row {
        previous_range.count = js_math_max(
          previous_range.count.to_double(),
          (range.start + range.count - previous_range.start).to_double(),
        ).to_int()
      } else {
        merge_index += 1
        update_ranges[merge_index] = range
      }
    }
    // Trim the array to only contain the merged ranges.
    truncate_array(update_ranges, merge_index + 1)
    let current_unpack_row_len = state.get_parameter(GL_UNPACK_ROW_LENGTH)
    let current_unpack_skip_pixels = state.get_parameter(GL_UNPACK_SKIP_PIXELS)
    let current_unpack_skip_rows = state.get_parameter(GL_UNPACK_SKIP_ROWS)
    state.pixel_storei(GL_UNPACK_ROW_LENGTH, width)
    for range in update_ranges {
      let pixel_start = textures_math_floor(
        range.start.to_double() / component_stride.to_double(),
      )
      let pixel_count = textures_math_ceil(
        range.count.to_double() / component_stride.to_double(),
      )
      let x = textures_js_number(pixel_start % width.to_double())
      let y = textures_js_number(
        textures_math_floor(pixel_start / width.to_double()),
      )
      // Assumes update ranges refer to contiguous memory
      state.pixel_storei(GL_UNPACK_SKIP_PIXELS, x)
      state.pixel_storei(GL_UNPACK_SKIP_ROWS, y)
      state.tex_sub_image2d(
        GL_TEXTURE_2D,
        0,
        x,
        y,
        textures_js_number(pixel_count),
        1,
        gl_format,
        gl_type,
        data,
      )
    }
    texture.clear_update_ranges()
    state.pixel_storei(GL_UNPACK_ROW_LENGTH, current_unpack_row_len.cast())
    state.pixel_storei(GL_UNPACK_SKIP_PIXELS, current_unpack_skip_pixels.cast())
    state.pixel_storei(GL_UNPACK_SKIP_ROWS, current_unpack_skip_rows.cast())
  }
}

///|
/// `UNPACK_COLORSPACE_CONVERSION_WEBGL` for `texture`.
fn textures_unpack_conversion(texture : @core.Texture) -> Int32 {
  let color_management = @math.color_management
  let working_primaries = color_management.get_primaries(
    color_management.working_color_space,
  )
  let texture_primaries = if texture.color_space == @core.NoColorSpace {
    None
  } else {
    Some(color_management.get_primaries(texture.color_space))
  }
  if texture.color_space == @core.NoColorSpace ||
    (texture_primaries is Some(p) && physical_equal(working_primaries, p)) {
    GL_NONE
  } else {
    GL_BROWSER_DEFAULT_WEBGL
  }
}

///|
/// `uploadTexture( textureProperties, texture, slot )`.
fn WebGLTextures::upload_texture(
  self : WebGLTextures,
  texture_properties : TextureProperties,
  texture : @core.Texture,
  slot : Int32,
) -> Unit {
  let gl = self.gl
  let state = self.state
  let mut texture_type = GL_TEXTURE_2D
  if texture.texture_type is (DataArrayTexture | CompressedArrayTexture) {
    texture_type = GL_TEXTURE_2D_ARRAY
  }
  if texture.texture_type is Data3DTexture {
    texture_type = GL_TEXTURE_3D
  }
  let force_upload = self.init_texture(texture_properties, texture)
  let source = texture.source
  state.bind_texture(
    texture_type,
    texture_properties.__webgl_texture,
    webgl_slot=GL_TEXTURE0 + slot,
  )
  let source_properties = self.properties.get_source(source)
  if source_properties.__version != Some(source.version) || force_upload {
    state.active_texture(webgl_slot=GL_TEXTURE0 + slot)
    let is_image_bitmap = match texture.image() {
      DomImage(value) => is_image_bitmap(value)
      _ => false
    }
    if !is_image_bitmap {
      let unpack_conversion = textures_unpack_conversion(texture)
      state.pixel_storei_bool(GL_UNPACK_FLIP_Y_WEBGL, texture.flip_y)
      state.pixel_storei_bool(
        GL_UNPACK_PREMULTIPLY_ALPHA_WEBGL,
        texture.premultiply_alpha,
      )
      state.pixel_storei(
        GL_UNPACK_COLORSPACE_CONVERSION_WEBGL,
        unpack_conversion,
      )
    }
    state.pixel_storei(GL_UNPACK_ALIGNMENT, texture.unpack_alignment)
    let mut image = self.resize_image(
      texture.image(),
      false,
      self.capabilities.max_texture_size,
    )
    image = self.verify_color_space(texture, image)
    let gl_format_opt = self.utils.convert(
      texture.format,
      color_space=texture.color_space,
    )
    let gl_format = textures_gl_enum(gl_format_opt)
    let gl_type = textures_gl_enum(self.utils.convert(texture.type_))
    let mut gl_internal_format = textures_gl_enum(
      self.get_internal_format(
        texture.internal_format,
        gl_format_opt,
        self.utils.convert(texture.type_),
        texture.normalized,
        texture.color_space,
        force_linear_transfer=texture.is_video_texture(),
      ),
    )
    self.set_texture_parameters(texture_type, texture)
    let mipmaps = texture.mipmaps
    let use_tex_storage = !texture.is_video_texture()
    let allocate_memory = source_properties.__version is None || force_upload
    let data_ready = source.data_ready
    let levels_d = textures_get_mip_levels(texture, image)
    let levels = textures_js_number(levels_d)
    if texture.is_depth_texture() {
      gl_internal_format = textures_depth_enum(
        textures_get_internal_depth_format(
          texture.format == @core.DepthStencilFormat,
          Some(texture.type_),
        ),
      )
      if allocate_memory {
        if use_tex_storage {
          state.tex_storage2d(
            GL_TEXTURE_2D,
            1,
            gl_internal_format,
            textures_image_width(image),
            textures_image_height(image),
          )
        } else {
          state.tex_image2d(
            GL_TEXTURE_2D,
            0,
            gl_internal_format,
            textures_image_width(image),
            textures_image_height(image),
            0,
            gl_format,
            gl_type,
            @core.JsValue::null(),
          )
        }
      }
    } else if texture.texture_type is DataTexture {
      // use manually created mipmaps if available
      // if there are no manual mipmaps
      // set 0 level mipmap and then use GL to generate other mipmap levels
      if mipmaps.length() > 0 {
        if use_tex_storage && allocate_memory {
          state.tex_storage2d(
            GL_TEXTURE_2D,
            levels,
            gl_internal_format,
            textures_image_width(mipmaps[0]),
            textures_image_height(mipmaps[0]),
          )
        }
        for i, mipmap in mipmaps {
          if use_tex_storage {
            if data_ready {
              state.tex_sub_image2d(
                GL_TEXTURE_2D,
                i,
                0,
                0,
                textures_image_width(mipmap),
                textures_image_height(mipmap),
                gl_format,
                gl_type,
                textures_image_data(mipmap),
              )
            }
          } else {
            state.tex_image2d(
              GL_TEXTURE_2D,
              i,
              gl_internal_format,
              textures_image_width(mipmap),
              textures_image_height(mipmap),
              0,
              gl_format,
              gl_type,
              textures_image_data(mipmap),
            )
          }
        }
        texture.generate_mipmaps = false
      } else if use_tex_storage {
        if allocate_memory {
          state.tex_storage2d(
            GL_TEXTURE_2D,
            levels,
            gl_internal_format,
            textures_image_width(image),
            textures_image_height(image),
          )
        }
        if data_ready {
          self.update_texture(texture, image, gl_format, gl_type)
        }
      } else {
        state.tex_image2d(
          GL_TEXTURE_2D,
          0,
          gl_internal_format,
          textures_image_width(image),
          textures_image_height(image),
          0,
          gl_format,
          gl_type,
          textures_image_data(image),
        )
      }
    } else if texture.is_compressed_texture() {
      if texture.texture_type is CompressedArrayTexture {
        if use_tex_storage && allocate_memory {
          state.tex_storage3d(
            GL_TEXTURE_2D_ARRAY,
            levels,
            gl_internal_format,
            textures_image_width(mipmaps[0]),
            textures_image_height(mipmaps[0]),
            textures_image_depth(image),
          )
        }
        let layer_updates = texture.layer_updates.unwrap_or([])
        for i, mipmap in mipmaps {
          if texture.format != @core.RGBAFormat {
            if gl_format_opt is Some(_) {
              if use_tex_storage {
                if data_ready {
                  if layer_updates.length() > 0 {
                    let layer_byte_length = textures_get_byte_length(
                      textures_image_width(mipmap),
                      textures_image_height(mipmap),
                      texture.format,
                      texture.type_,
                    )
                    for layer_index in layer_updates {
                      let layer_data = textures_layer_data(
                        textures_image_data(mipmap),
                        layer_byte_length,
                        layer_index,
                      )
                      state.compressed_tex_sub_image3d(
                        GL_TEXTURE_2D_ARRAY,
                        i,
                        0,
                        0,
                        layer_index,
                        textures_image_width(mipmap),
                        textures_image_height(mipmap),
                        1,
                        gl_format,
                        layer_data,
                      )
                    }
                  } else {
                    state.compressed_tex_sub_image3d(
                      GL_TEXTURE_2D_ARRAY,
                      i,
                      0,
                      0,
                      0,
                      textures_image_width(mipmap),
                      textures_image_height(mipmap),
                      textures_image_depth(image),
                      gl_format,
                      textures_image_data(mipmap),
                    )
                  }
                }
              } else {
                state.compressed_tex_image3d(
                  GL_TEXTURE_2D_ARRAY,
                  i,
                  gl_internal_format,
                  textures_image_width(mipmap),
                  textures_image_height(mipmap),
                  textures_image_depth(image),
                  0,
                  textures_image_data(mipmap),
                  0,
                  0,
                )
              }
            } else {
              @core.warn(
                "WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()",
              )
            }
          } else if use_tex_storage {
            if data_ready {
              state.tex_sub_image3d(
                GL_TEXTURE_2D_ARRAY,
                i,
                0,
                0,
                0,
                textures_image_width(mipmap),
                textures_image_height(mipmap),
                textures_image_depth(image),
                gl_format,
                gl_type,
                textures_image_data(mipmap),
              )
            }
          } else {
            state.tex_image3d(
              GL_TEXTURE_2D_ARRAY,
              i,
              gl_internal_format,
              textures_image_width(mipmap),
              textures_image_height(mipmap),
              textures_image_depth(image),
              0,
              gl_format,
              gl_type,
              textures_image_data(mipmap),
            )
          }
        }
        if layer_updates.length() > 0 {
          texture.clear_layer_updates()
        }
      } else {
        if use_tex_storage && allocate_memory {
          state.tex_storage2d(
            GL_TEXTURE_2D,
            levels,
            gl_internal_format,
            textures_image_width(mipmaps[0]),
            textures_image_height(mipmaps[0]),
          )
        }
        for i, mipmap in mipmaps {
          if texture.format != @core.RGBAFormat {
            if gl_format_opt is Some(_) {
              if use_tex_storage {
                if data_ready {
                  state.compressed_tex_sub_image2d(
                    GL_TEXTURE_2D,
                    i,
                    0,
                    0,
                    textures_image_width(mipmap),
                    textures_image_height(mipmap),
                    gl_format,
                    textures_image_data(mipmap),
                  )
                }
              } else {
                state.compressed_tex_image2d(
                  GL_TEXTURE_2D,
                  i,
                  gl_internal_format,
                  textures_image_width(mipmap),
                  textures_image_height(mipmap),
                  0,
                  textures_image_data(mipmap),
                )
              }
            } else {
              @core.warn(
                "WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()",
              )
            }
          } else if use_tex_storage {
            if data_ready {
              state.tex_sub_image2d(
                GL_TEXTURE_2D,
                i,
                0,
                0,
                textures_image_width(mipmap),
                textures_image_height(mipmap),
                gl_format,
                gl_type,
                textures_image_data(mipmap),
              )
            }
          } else {
            state.tex_image2d(
              GL_TEXTURE_2D,
              i,
              gl_internal_format,
              textures_image_width(mipmap),
              textures_image_height(mipmap),
              0,
              gl_format,
              gl_type,
              textures_image_data(mipmap),
            )
          }
        }
      }
    } else if texture.texture_type is DataArrayTexture {
      if use_tex_storage {
        if allocate_memory {
          state.tex_storage3d(
            GL_TEXTURE_2D_ARRAY,
            levels,
            gl_internal_format,
            textures_image_width(image),
            textures_image_height(image),
            textures_image_depth(image),
          )
        }
        if data_ready {
          let layer_updates = texture.layer_updates.unwrap_or([])
          if layer_updates.length() > 0 {
            let layer_byte_length = textures_get_byte_length(
              textures_image_width(image),
              textures_image_height(image),
              texture.format,
              texture.type_,
            )
            for layer_index in layer_updates {
              let layer_data = textures_layer_data(
                textures_image_data(image),
                layer_byte_length,
                layer_index,
              )
              state.tex_sub_image3d(
                GL_TEXTURE_2D_ARRAY,
                0,
                0,
                0,
                layer_index,
                textures_image_width(image),
                textures_image_height(image),
                1,
                gl_format,
                gl_type,
                layer_data,
              )
            }
            texture.clear_layer_updates()
          } else {
            state.tex_sub_image3d(
              GL_TEXTURE_2D_ARRAY,
              0,
              0,
              0,
              0,
              textures_image_width(image),
              textures_image_height(image),
              textures_image_depth(image),
              gl_format,
              gl_type,
              textures_image_data(image),
            )
          }
        }
      } else {
        state.tex_image3d(
          GL_TEXTURE_2D_ARRAY,
          0,
          gl_internal_format,
          textures_image_width(image),
          textures_image_height(image),
          textures_image_depth(image),
          0,
          gl_format,
          gl_type,
          textures_image_data(image),
        )
      }
    } else if texture.texture_type is Data3DTexture {
      if use_tex_storage {
        if allocate_memory {
          state.tex_storage3d(
            GL_TEXTURE_3D,
            levels,
            gl_internal_format,
            textures_image_width(image),
            textures_image_height(image),
            textures_image_depth(image),
          )
        }
        if data_ready {
          state.tex_sub_image3d(
            GL_TEXTURE_3D,
            0,
            0,
            0,
            0,
            textures_image_width(image),
            textures_image_height(image),
            textures_image_depth(image),
            gl_format,
            gl_type,
            textures_image_data(image),
          )
        }
      } else {
        state.tex_image3d(
          GL_TEXTURE_3D,
          0,
          gl_internal_format,
          textures_image_width(image),
          textures_image_height(image),
          textures_image_depth(image),
          0,
          gl_format,
          gl_type,
          textures_image_data(image),
        )
      }
    } else if texture.texture_type is FramebufferTexture {
      if allocate_memory {
        if use_tex_storage {
          state.tex_storage2d(
            GL_TEXTURE_2D,
            levels,
            gl_internal_format,
            textures_image_width(image),
            textures_image_height(image),
          )
        } else {
          let mut width = textures_image_width(image)
          let mut height = textures_image_height(image)
          let mut i = 0
          while i.to_double() < levels_d {
            state.tex_image2d(
              GL_TEXTURE_2D,
              i,
              gl_internal_format,
              width,
              height,
              0,
              gl_format,
              gl_type,
              @core.JsValue::null(),
            )
            width = width >> 1
            height = height >> 1
            i += 1
          }
        }
      }
    } else if texture.texture_type is HTMLTexture {
      if gl.has_tex_element_image2d() {
        let canvas = gl.canvas()
        let element = image.to_js()
        // Ensure the canvas supports HTML-in-Canvas and the element is a child.
        if !textures_canvas_has_attribute(canvas, "layoutsubtree") {
          canvas.set_attribute("layoutsubtree", "true")
        }
        if !textures_parent_is(element, canvas) {
          textures_append_child(canvas, element)
          // Register and set up a shared paint callback for all HTMLTextures.
          self._html_textures[texture.id] = texture
          let html_textures = self._html_textures
          textures_set_onpaint(canvas, event => {
            for _, t in html_textures {
              if textures_changed_includes(event, t.image().to_js()) {
                t.set_needs_update(true)
              }
            }
          })
          textures_request_paint(canvas)
          return
        }
        if gl.tex_element_image2d_length() == 3 {
          // Chrome 150+
          gl.tex_element_image2d(GL_TEXTURE_2D, GL_RGBA8, element)
        } else {
          // Chrome 138 - 149
          gl.tex_element_image2d_full(
            GL_TEXTURE_2D,
            0,
            GL_RGBA,
            GL_RGBA,
            GL_UNSIGNED_BYTE,
            element,
          )
        }
        gl.tex_parameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
        gl.tex_parameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        gl.tex_parameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
      }
    } else if mipmaps.length() > 0 {
      // regular Texture (image, video, canvas)
      if use_tex_storage && allocate_memory {
        let dimensions = self.get_dimensions(mipmaps[0])
        state.tex_storage2d(
          GL_TEXTURE_2D,
          levels,
          gl_internal_format,
          textures_js_number(dimensions.x),
          textures_js_number(dimensions.y),
        )
      }
      for i, mipmap in mipmaps {
        if use_tex_storage {
          if data_ready {
            state.tex_sub_image2d_source(
              GL_TEXTURE_2D,
              i,
              0,
              0,
              gl_format,
              gl_type,
              mipmap.to_js(),
            )
          }
        } else {
          state.tex_image2d_source(
            GL_TEXTURE_2D,
            i,
            gl_internal_format,
            gl_format,
            gl_type,
            mipmap.to_js(),
          )
        }
      }
      texture.generate_mipmaps = false
    } else if use_tex_storage {
      if allocate_memory {
        let dimensions = self.get_dimensions(image)
        state.tex_storage2d(
          GL_TEXTURE_2D,
          levels,
          gl_internal_format,
          textures_js_number(dimensions.x),
          textures_js_number(dimensions.y),
        )
      }
      if data_ready {
        state.tex_sub_image2d_source(
          GL_TEXTURE_2D,
          0,
          0,
          0,
          gl_format,
          gl_type,
          image.to_js(),
        )
      }
    } else {
      state.tex_image2d_source(
        GL_TEXTURE_2D,
        0,
        gl_internal_format,
        gl_format,
        gl_type,
        image.to_js(),
      )
    }
    if textures_needs_generate_mipmaps(texture) && texture.mipmaps_auto_update {
      self.generate_mipmap(texture_type)
    }
    source_properties.__version = Some(source.version)
    if texture.on_update is Some(on_update) {
      on_update(texture)
    }
  }
  texture_properties.__version = Some(texture.version)
}

///|
/// `uploadCubeTexture( textureProperties, texture, slot )`.
fn WebGLTextures::upload_cube_texture(
  self : WebGLTextures,
  texture_properties : TextureProperties,
  texture : @core.Texture,
  slot : Int32,
) -> Unit {
  let state = self.state
  guard texture.image() is ImageArray(images) && images.length() == 6 else {
    return
  }
  let force_upload = self.init_texture(texture_properties, texture)
  let source = texture.source
  state.bind_texture(
    GL_TEXTURE_CUBE_MAP,
    texture_properties.__webgl_texture,
    webgl_slot=GL_TEXTURE0 + slot,
  )
  let source_properties = self.properties.get_source(source)
  if source_properties.__version != Some(source.version) || force_upload {
    state.active_texture(webgl_slot=GL_TEXTURE0 + slot)
    let unpack_conversion = textures_unpack_conversion(texture)
    state.pixel_storei_bool(GL_UNPACK_FLIP_Y_WEBGL, texture.flip_y)
    state.pixel_storei_bool(
      GL_UNPACK_PREMULTIPLY_ALPHA_WEBGL,
      texture.premultiply_alpha,
    )
    state.pixel_storei(GL_UNPACK_ALIGNMENT, texture.unpack_alignment)
    state.pixel_storei(GL_UNPACK_COLORSPACE_CONVERSION_WEBGL, unpack_conversion)
    let is_compressed = texture.is_compressed_texture() ||
      (images[0] is TextureImage(face) && face.is_compressed_texture())
    let is_data_texture = images[0] is TextureImage(face) &&
      face.texture_type is DataTexture
    let cube_image : Array[@core.TextureImage] = []
    for i in 0..<6 {
      let face = if !is_compressed && !is_data_texture {
        self.resize_image(images[i], true, self.capabilities.max_cubemap_size)
      } else if is_data_texture {
        textures_image_image(images[i])
      } else {
        images[i]
      }
      cube_image.push(self.verify_color_space(texture, face))
    }
    let image = cube_image[0]
    let gl_format_opt = self.utils.convert(
      texture.format,
      color_space=texture.color_space,
    )
    let gl_format = textures_gl_enum(gl_format_opt)
    let gl_type_opt = self.utils.convert(texture.type_)
    let gl_type = textures_gl_enum(gl_type_opt)
    let mut gl_internal_format = textures_gl_enum(
      self.get_internal_format(
        texture.internal_format,
        gl_format_opt,
        gl_type_opt,
        texture.normalized,
        texture.color_space,
      ),
    )
    let use_tex_storage = !texture.is_video_texture()
    let allocate_memory = source_properties.__version is None || force_upload
    let data_ready = source.data_ready
    let mut levels = textures_get_mip_levels(texture, image)
    self.set_texture_parameters(GL_TEXTURE_CUBE_MAP, texture)
    if texture.is_depth_texture() {
      gl_internal_format = textures_depth_enum(
        textures_get_internal_depth_format(
          texture.format == @core.DepthStencilFormat,
          Some(texture.type_),
        ),
      )
      if allocate_memory {
        if use_tex_storage {
          state.tex_storage2d(
            GL_TEXTURE_CUBE_MAP,
            1,
            gl_internal_format,
            textures_image_width(image),
            textures_image_height(image),
          )
        } else {
          for i in 0..<6 {
            state.tex_image2d(
              GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
              0,
              gl_internal_format,
              textures_image_width(image),
              textures_image_height(image),
              0,
              gl_format,
              gl_type,
              @core.JsValue::null(),
            )
          }
        }
      }
    } else if is_compressed {
      if use_tex_storage && allocate_memory {
        state.tex_storage2d(
          GL_TEXTURE_CUBE_MAP,
          textures_js_number(levels),
          gl_internal_format,
          textures_image_width(image),
          textures_image_height(image),
        )
      }
      for i in 0..<6 {
        let mipmaps = textures_image_mipmaps(cube_image[i])
        for j, mipmap in mipmaps {
          if texture.format != @core.RGBAFormat {
            if gl_format_opt is Some(_) {
              if use_tex_storage {
                if data_ready {
                  state.compressed_tex_sub_image2d(
                    GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
                    j,
                    0,
                    0,
                    textures_image_width(mipmap),
                    textures_image_height(mipmap),
                    gl_format,
                    textures_image_data(mipmap),
                  )
                }
              } else {
                state.compressed_tex_image2d(
                  GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
                  j,
                  gl_internal_format,
                  textures_image_width(mipmap),
                  textures_image_height(mipmap),
                  0,
                  textures_image_data(mipmap),
                )
              }
            } else {
              @core.warn(
                "WebGLRenderer: Attempt to load unsupported compressed texture format in .setTextureCube()",
              )
            }
          } else if use_tex_storage {
            if data_ready {
              state.tex_sub_image2d(
                GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
                j,
                0,
                0,
                textures_image_width(mipmap),
                textures_image_height(mipmap),
                gl_format,
                gl_type,
                textures_image_data(mipmap),
              )
            }
          } else {
            state.tex_image2d(
              GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
              j,
              gl_internal_format,
              textures_image_width(mipmap),
              textures_image_height(mipmap),
              0,
              gl_format,
              gl_type,
              textures_image_data(mipmap),
            )
          }
        }
      }
    } else {
      let mipmaps = texture.mipmaps
      if use_tex_storage && allocate_memory {
        // Uncompressed cube textures use their mipmap array only for mips (no base level)
        if mipmaps.length() > 0 {
          levels = levels + 1.0
        }
        let dimensions = self.get_dimensions(cube_image[0])
        state.tex_storage2d(
          GL_TEXTURE_CUBE_MAP,
          textures_js_number(levels),
          gl_internal_format,
          textures_js_number(dimensions.x),
          textures_js_number(dimensions.y),
        )
      }
      for i in 0..<6 {
        let target = GL_TEXTURE_CUBE_MAP_POSITIVE_X + i
        if is_data_texture {
          if use_tex_storage {
            if data_ready {
              state.tex_sub_image2d(
                target,
                0,
                0,
                0,
                textures_image_width(cube_image[i]),
                textures_image_height(cube_image[i]),
                gl_format,
                gl_type,
                textures_image_data(cube_image[i]),
              )
            }
          } else {
            state.tex_image2d(
              target,
              0,
              gl_internal_format,
              textures_image_width(cube_image[i]),
              textures_image_height(cube_image[i]),
              0,
              gl_format,
              gl_type,
              textures_image_data(cube_image[i]),
            )
          }
          for j, mipmap in mipmaps {
            let mipmap_image = textures_image_image(
              textures_image_at(textures_image_image(mipmap), i),
            )
            if use_tex_storage {
              if data_ready {
                state.tex_sub_image2d(
                  target,
                  j + 1,
                  0,
                  0,
                  textures_image_width(mipmap_image),
                  textures_image_height(mipmap_image),
                  gl_format,
                  gl_type,
                  textures_image_data(mipmap_image),
                )
              }
            } else {
              state.tex_image2d(
                target,
                j + 1,
                gl_internal_format,
                textures_image_width(mipmap_image),
                textures_image_height(mipmap_image),
                0,
                gl_format,
                gl_type,
                textures_image_data(mipmap_image),
              )
            }
          }
        } else {
          if use_tex_storage {
            if data_ready {
              state.tex_sub_image2d_source(
                target,
                0,
                0,
                0,
                gl_format,
                gl_type,
                cube_image[i].to_js(),
              )
            }
          } else {
            state.tex_image2d_source(
              target,
              0,
              gl_internal_format,
              gl_format,
              gl_type,
              cube_image[i].to_js(),
            )
          }
          for j, mipmap in mipmaps {
            let mipmap_face = textures_image_at(textures_image_image(mipmap), i).to_js()
            if use_tex_storage {
              if data_ready {
                state.tex_sub_image2d_source(
                  target,
                  j + 1,
                  0,
                  0,
                  gl_format,
                  gl_type,
                  mipmap_face,
                )
              }
            } else {
              state.tex_image2d_source(
                target,
                j + 1,
                gl_internal_format,
                gl_format,
                gl_type,
                mipmap_face,
              )
            }
          }
        }
      }
    }
    if textures_needs_generate_mipmaps(texture) && texture.mipmaps_auto_update {
      // We assume images for cube map have the same size.
      self.generate_mipmap(GL_TEXTURE_CUBE_MAP)
    }
    source_properties.__version = Some(source.version)
    if texture.on_update is Some(on_update) {
      on_update(texture)
    }
  }
  texture_properties.__version = Some(texture.version)
}

// --- render targets ------------------------------------------------------------------

///|
/// `textures.setupFrameBufferTexture( framebuffer, renderTarget, texture, attachment,
/// textureTarget, level )`.
pub fn WebGLTextures::setup_frame_buffer_texture(
  self : WebGLTextures,
  framebuffer : GLFramebuffer?,
  render_target : @core.RenderTarget,
  texture : @core.Texture,
  attachment : Int32,
  texture_target : Int32,
  level : Int32,
) -> Unit {
  let gl = self.gl
  let state = self.state
  let gl_format_opt = self.utils.convert(
    texture.format,
    color_space=texture.color_space,
  )
  let gl_type_opt = self.utils.convert(texture.type_)
  let gl_internal_format = textures_gl_enum(
    self.get_internal_format(
      texture.internal_format,
      gl_format_opt,
      gl_type_opt,
      texture.normalized,
      texture.color_space,
    ),
  )
  let render_target_properties = self.properties.get_render_target(
    render_target,
  )
  let texture_properties = self.properties.get_texture(texture)
  texture_properties.__render_target = Some(render_target)
  if !render_target_properties.__has_external_textures {
    let width = {
      let v = render_target.width >> level
      if v > 1 {
        v
      } else {
        1
      }
    }
    let height = {
      let v = render_target.height >> level
      if v > 1 {
        v
      } else {
        1
      }
    }
    if texture_target == GL_TEXTURE_3D || texture_target == GL_TEXTURE_2D_ARRAY {
      state.tex_image3d(
        texture_target,
        level,
        gl_internal_format,
        width,
        height,
        render_target.depth,
        0,
        textures_gl_enum(gl_format_opt),
        textures_gl_enum(gl_type_opt),
        @core.JsValue::null(),
      )
    } else {
      state.tex_image2d(
        texture_target,
        level,
        gl_internal_format,
        width,
        height,
        0,
        textures_gl_enum(gl_format_opt),
        textures_gl_enum(gl_type_opt),
        @core.JsValue::null(),
      )
    }
  }
  ignore(state.bind_framebuffer(GL_FRAMEBUFFER, framebuffer))
  if self.use_multisampled_rtt(render_target) {
    self.multisampled_rtt_ext
    .unwrap()
    .framebuffer_texture2d_multisample_ext(
      GL_FRAMEBUFFER,
      attachment,
      texture_target,
      texture_properties.__webgl_texture,
      0,
      self.get_render_target_samples(render_target),
    )
  } else if texture_target == GL_TEXTURE_2D ||
    (
      texture_target >= GL_TEXTURE_CUBE_MAP_POSITIVE_X &&
      texture_target <= GL_TEXTURE_CUBE_MAP_NEGATIVE_Z
    ) { // see #24753
    gl.framebuffer_texture2d(
      GL_FRAMEBUFFER,
      attachment,
      texture_target,
      texture_properties.__webgl_texture,
      level,
    )
  }
  ignore(state.bind_framebuffer(GL_FRAMEBUFFER, None))
}

///|
/// `setupRenderBufferStorage( renderbuffer, renderTarget, useMultisample )`.
fn WebGLTextures::setup_render_buffer_storage(
  self : WebGLTextures,
  renderbuffer : GLRenderbuffer,
  render_target : @core.RenderTarget,
  use_multisample : Bool,
) -> Unit {
  let gl = self.gl
  gl.bind_renderbuffer(GL_RENDERBUFFER, Some(renderbuffer))
  let storage = (gl_internal_format : Int32) => {
    if self.use_multisampled_rtt(render_target) {
      self.multisampled_rtt_ext
      .unwrap()
      .renderbuffer_storage_multisample_ext(
        GL_RENDERBUFFER,
        self.get_render_target_samples(render_target),
        gl_internal_format,
        render_target.width,
        render_target.height,
      )
    } else if use_multisample {
      gl.renderbuffer_storage_multisample(
        GL_RENDERBUFFER,
        self.get_render_target_samples(render_target),
        gl_internal_format,
        render_target.width,
        render_target.height,
      )
    } else {
      gl.renderbuffer_storage(
        GL_RENDERBUFFER,
        gl_internal_format,
        render_target.width,
        render_target.height,
      )
    }
  }
  if render_target.depth_buffer {
    // retrieve the depth attachment types
    let depth_type = match render_target.depth_texture() {
      Some(depth_texture) if depth_texture.is_depth_texture() =>
        Some(depth_texture.type_)
      _ => None
    }
    let gl_internal_format = textures_depth_enum(
      textures_get_internal_depth_format(
        render_target.stencil_buffer,
        depth_type,
      ),
    )
    let gl_attachment_type = if render_target.stencil_buffer {
      GL_DEPTH_STENCIL_ATTACHMENT
    } else {
      GL_DEPTH_ATTACHMENT
    }
    // set up the attachment
    storage(gl_internal_format)
    gl.framebuffer_renderbuffer(
      GL_FRAMEBUFFER,
      gl_attachment_type,
      GL_RENDERBUFFER,
      Some(renderbuffer),
    )
  } else {
    for texture in render_target.textures {
      let gl_format = self.utils.convert(
        texture.format,
        color_space=texture.color_space,
      )
      let gl_type = self.utils.convert(texture.type_)
      let gl_internal_format = textures_gl_enum(
        self.get_internal_format(
          texture.internal_format,
          gl_format,
          gl_type,
          texture.normalized,
          texture.color_space,
        ),
      )
      storage(gl_internal_format)
    }
  }
  gl.bind_renderbuffer(GL_RENDERBUFFER, None)
}

///|
/// `setupDepthTexture( framebuffer, renderTarget, cubeFace )`.
fn WebGLTextures::setup_depth_texture(
  self : WebGLTextures,
  framebuffer : GLFramebuffer?,
  render_target : @core.RenderTarget,
  cube_face : Int32,
) -> Unit {
  let gl = self.gl
  let is_cube = textures_is_cube_target(render_target)
  ignore(self.state.bind_framebuffer(GL_FRAMEBUFFER, framebuffer))
  guard render_target.depth_texture() is Some(depth_texture) &&
    depth_texture.is_depth_texture() else {
    abort(
      "THREE.WebGLTextures: renderTarget.depthTexture must be an instance of THREE.DepthTexture.",
    )
  }
  let texture_properties = self.properties.get_texture(depth_texture)
  texture_properties.__render_target = Some(render_target)
  // upload an empty depth texture with framebuffer size
  let image = if is_cube {
    textures_image_at(depth_texture.image(), 0)
  } else {
    depth_texture.image()
  }
  if texture_properties.__webgl_texture is None ||
    textures_image_width(image) != render_target.width ||
    textures_image_height(image) != render_target.height {
    textures_image_set_size(image, render_target.width, render_target.height)
    depth_texture.set_needs_update(true)
  }
  if is_cube {
    self.set_texture_cube(depth_texture, 0)
  } else {
    self.set_texture2d(depth_texture, 0)
  }
  let webgl_depth_texture = texture_properties.__webgl_texture
  let samples = self.get_render_target_samples(render_target)
  let gl_texture_type = if is_cube {
    GL_TEXTURE_CUBE_MAP_POSITIVE_X + cube_face
  } else {
    GL_TEXTURE_2D
  }
  let gl_attachment_type = if depth_texture.format == @core.DepthStencilFormat {
    GL_DEPTH_STENCIL_ATTACHMENT
  } else {
    GL_DEPTH_ATTACHMENT
  }
  if depth_texture.format == @core.DepthFormat ||
    depth_texture.format == @core.DepthStencilFormat {
    if self.use_multisampled_rtt(render_target) {
      self.multisampled_rtt_ext
      .unwrap()
      .framebuffer_texture2d_multisample_ext(
        GL_FRAMEBUFFER,
        gl_attachment_type,
        gl_texture_type,
        webgl_depth_texture,
        0,
        samples,
      )
    } else {
      gl.framebuffer_texture2d(
        GL_FRAMEBUFFER,
        gl_attachment_type,
        gl_texture_type,
        webgl_depth_texture,
        0,
      )
    }
  } else {
    abort("THREE.WebGLTextures: Unknown depthTexture format.")
  }
}

///|
/// `renderTargetProperties.__boundDepthTexture !== renderTarget.depthTexture`.
fn textures_bound_depth_changed(
  bound : @core.Texture??,
  current : @core.Texture?,
) -> Bool {
  match (bound, current) {
    (None, _) => true
    (Some(None), None) => false
    (Some(Some(a)), Some(b)) => !physical_equal(a, b)
    _ => true
  }
}

///|
/// `textures.setupDepthRenderbuffer( renderTarget )`.
pub fn WebGLTextures::setup_depth_renderbuffer(
  self : WebGLTextures,
  render_target : @core.RenderTarget,
) -> Unit {
  let gl = self.gl
  let state = self.state
  let render_target_properties = self.properties.get_render_target(
    render_target,
  )
  let is_cube = textures_is_cube_target(render_target)
  // if the bound depth texture has changed
  if textures_bound_depth_changed(
      render_target_properties.__bound_depth_texture,
      render_target.depth_texture(),
    ) {
    // fire the dispose event to get rid of stored state associated with the previously
    // bound depth buffer
    let depth_texture = render_target.depth_texture()
    if render_target_properties.__depth_dispose_callback is Some(callback) {
      callback()
    }
    // set up dispose listeners to track when the currently attached buffer is
    // implicitly unbound
    if depth_texture is Some(depth_texture) {
      let listener : Ref[(@core.Event) -> Unit] = Ref(_ => ())
      let dispose_event = () => {
        render_target_properties.__bound_depth_texture = None
        render_target_properties.__depth_dispose_callback = None
        depth_texture.remove_event_listener("dispose", listener.val)
      }
      listener.val = _ => dispose_event()
      depth_texture.add_event_listener("dispose", listener.val)
      render_target_properties.__depth_dispose_callback = Some(dispose_event)
    }
    render_target_properties.__bound_depth_texture = Some(depth_texture)
  }
  if render_target.depth_texture() is Some(_) &&
    !render_target_properties.__auto_allocate_depth_buffer {
    if is_cube {
      // For cube render targets with depth texture, setup each face
      for i in 0..<6 {
        self.setup_depth_texture(
          textures_framebuffer(
            textures_framebuffer_at(
              render_target_properties.__webgl_framebuffer,
              i,
            ),
          ),
          render_target,
          i,
        )
      }
    } else {
      let mipmaps = render_target.texture().mipmaps
      if mipmaps.length() > 0 {
        self.setup_depth_texture(
          textures_framebuffer(
            textures_framebuffer_at(
              render_target_properties.__webgl_framebuffer,
              0,
            ),
          ),
          render_target,
          0,
        )
      } else {
        self.setup_depth_texture(
          textures_framebuffer(render_target_properties.__webgl_framebuffer),
          render_target,
          0,
        )
      }
    }
  } else if is_cube {
    let depthbuffers : Array[GLRenderbuffer?] = []
    render_target_properties.__webgl_depthbuffer = Some(CubeFaces(depthbuffers))
    for i in 0..<6 {
      ignore(
        state.bind_framebuffer(
          GL_FRAMEBUFFER,
          textures_framebuffer(
            textures_framebuffer_at(
              render_target_properties.__webgl_framebuffer,
              i,
            ),
          ),
        ),
      )
      if i >= depthbuffers.length() || depthbuffers[i] is None {
        let renderbuffer = gl.create_renderbuffer()
        while depthbuffers.length() <= i {
          depthbuffers.push(None)
        }
        depthbuffers[i] = Some(renderbuffer)
        self.setup_render_buffer_storage(renderbuffer, render_target, false)
      } else {
        // attach buffer if it's been created already
        let gl_attachment_type = if render_target.stencil_buffer {
          GL_DEPTH_STENCIL_ATTACHMENT
        } else {
          GL_DEPTH_ATTACHMENT
        }
        let renderbuffer = depthbuffers[i]
        gl.bind_renderbuffer(GL_RENDERBUFFER, renderbuffer)
        gl.framebuffer_renderbuffer(
          GL_FRAMEBUFFER,
          gl_attachment_type,
          GL_RENDERBUFFER,
          renderbuffer,
        )
      }
    }
  } else {
    let mipmaps = render_target.texture().mipmaps
    if mipmaps.length() > 0 {
      ignore(
        state.bind_framebuffer(
          GL_FRAMEBUFFER,
          textures_framebuffer(
            textures_framebuffer_at(
              render_target_properties.__webgl_framebuffer,
              0,
            ),
          ),
        ),
      )
    } else {
      ignore(
        state.bind_framebuffer(
          GL_FRAMEBUFFER,
          textures_framebuffer(render_target_properties.__webgl_framebuffer),
        ),
      )
    }
    match render_target_properties.__webgl_depthbuffer {
      None => {
        let renderbuffer = gl.create_renderbuffer()
        render_target_properties.__webgl_depthbuffer = Some(
          Renderbuffer(renderbuffer),
        )
        self.setup_render_buffer_storage(renderbuffer, render_target, false)
      }
      Some(slot) => {
        // attach buffer if it's been created already
        let gl_attachment_type = if render_target.stencil_buffer {
          GL_DEPTH_STENCIL_ATTACHMENT
        } else {
          GL_DEPTH_ATTACHMENT
        }
        let renderbuffer : GLRenderbuffer? = match slot {
          Renderbuffer(renderbuffer) => Some(renderbuffer)
          CubeFaces(renderbuffers) =>
            Some(@core.JsValue::of(renderbuffers).cast())
        }
        gl.bind_renderbuffer(GL_RENDERBUFFER, renderbuffer)
        gl.framebuffer_renderbuffer(
          GL_FRAMEBUFFER,
          gl_attachment_type,
          GL_RENDERBUFFER,
          renderbuffer,
        )
      }
    }
  }
  ignore(state.bind_framebuffer(GL_FRAMEBUFFER, None))
}

///|
/// `textures.rebindTextures( renderTarget, colorTexture, depthTexture )`.
pub fn WebGLTextures::rebind_textures(
  self : WebGLTextures,
  render_target : @core.RenderTarget,
  color_texture : GLTexture?,
  depth_texture : GLTexture?,
) -> Unit {
  let render_target_properties = self.properties.get_render_target(
    render_target,
  )
  if color_texture is Some(_) {
    self.setup_frame_buffer_texture(
      textures_framebuffer(render_target_properties.__webgl_framebuffer),
      render_target,
      render_target.texture(),
      GL_COLOR_ATTACHMENT0,
      GL_TEXTURE_2D,
      0,
    )
  }
  if depth_texture is Some(_) {
    self.setup_depth_renderbuffer(render_target)
  }
}

///|
/// `textures.setupRenderTarget( renderTarget )`.
pub fn WebGLTextures::setup_render_target(
  self : WebGLTextures,
  render_target : @core.RenderTarget,
) -> Unit {
  let gl = self.gl
  let state = self.state
  let texture = render_target.texture()
  let render_target_properties = self.properties.get_render_target(
    render_target,
  )
  let texture_properties = self.properties.get_texture(texture)
  render_target.add_event_listener("dispose", self.on_render_target_dispose)
  self.track_render_target(render_target)
  let textures = render_target.textures
  let is_cube = textures_is_cube_target(render_target)
  let is_multiple_render_targets = textures.length() > 1
  if !is_multiple_render_targets {
    if texture_properties.__webgl_texture is None {
      texture_properties.__webgl_texture = Some(gl.create_texture())
    }
    texture_properties.__version = Some(texture.version)
    self.info.memory.textures += 1
  }
  // Setup framebuffer
  if is_cube {
    let faces : Array[WebGLFramebufferSlot] = []
    for _ in 0..<6 {
      if texture.mipmaps.length() > 0 {
        let levels : Array[GLFramebuffer] = []
        for _ in 0..<texture.mipmaps.length() {
          levels.push(gl.create_framebuffer())
        }
        faces.push(Mipmaps(levels))
      } else {
        faces.push(Framebuffer(Some(gl.create_framebuffer())))
      }
    }
    render_target_properties.__webgl_framebuffer = Some(CubeFaces(faces))
  } else {
    if texture.mipmaps.length() > 0 {
      let levels : Array[GLFramebuffer] = []
      for _ in 0..<texture.mipmaps.length() {
        levels.push(gl.create_framebuffer())
      }
      render_target_properties.__webgl_framebuffer = Some(Mipmaps(levels))
    } else {
      render_target_properties.__webgl_framebuffer = Some(
        Framebuffer(Some(gl.create_framebuffer())),
      )
    }
    if is_multiple_render_targets {
      for attachment in textures {
        let attachment_properties = self.properties.get_texture(attachment)
        if attachment_properties.__webgl_texture is None {
          attachment_properties.__webgl_texture = Some(gl.create_texture())
          self.info.memory.textures += 1
        }
      }
    }
    if render_target.samples > 0 && !self.use_multisampled_rtt(render_target) {
      let multisampled_framebuffer = gl.create_framebuffer()
      render_target_properties.__webgl_multisampled_framebuffer = Some(
        multisampled_framebuffer,
      )
      let color_renderbuffers : Array[GLRenderbuffer?] = []
      render_target_properties.__webgl_color_renderbuffer = Some(
        color_renderbuffers,
      )
      ignore(
        state.bind_framebuffer(GL_FRAMEBUFFER, Some(multisampled_framebuffer)),
      )
      for i, attachment in textures {
        let renderbuffer = gl.create_renderbuffer()
        color_renderbuffers.push(Some(renderbuffer))
        gl.bind_renderbuffer(GL_RENDERBUFFER, Some(renderbuffer))
        let gl_format = self.utils.convert(
          attachment.format,
          color_space=attachment.color_space,
        )
        let gl_type = self.utils.convert(attachment.type_)
        let gl_internal_format = textures_gl_enum(
          self.get_internal_format(
            attachment.internal_format,
            gl_format,
            gl_type,
            attachment.normalized,
            attachment.color_space,
            force_linear_transfer=render_target.has_extension_flag(
              "isXRRenderTarget",
            ),
          ),
        )
        let samples = self.get_render_target_samples(render_target)
        gl.renderbuffer_storage_multisample(
          GL_RENDERBUFFER,
          samples,
          gl_internal_format,
          render_target.width,
          render_target.height,
        )
        gl.framebuffer_renderbuffer(
          GL_FRAMEBUFFER,
          GL_COLOR_ATTACHMENT0 + i,
          GL_RENDERBUFFER,
          Some(renderbuffer),
        )
      }
      gl.bind_renderbuffer(GL_RENDERBUFFER, None)
      if render_target.depth_buffer {
        let renderbuffer = gl.create_renderbuffer()
        render_target_properties.__webgl_depth_renderbuffer = Some(renderbuffer)
        self.setup_render_buffer_storage(renderbuffer, render_target, true)
      }
      ignore(state.bind_framebuffer(GL_FRAMEBUFFER, None))
    }
  }
  // Setup color buffer
  if is_cube {
    state.bind_texture(GL_TEXTURE_CUBE_MAP, texture_properties.__webgl_texture)
    self.set_texture_parameters(GL_TEXTURE_CUBE_MAP, texture)
    for i in 0..<6 {
      let face = textures_framebuffer_at(
        render_target_properties.__webgl_framebuffer,
        i,
      )
      if texture.mipmaps.length() > 0 {
        for level in 0..<texture.mipmaps.length() {
          self.setup_frame_buffer_texture(
            textures_framebuffer(textures_framebuffer_at(face, level)),
            render_target,
            texture,
            GL_COLOR_ATTACHMENT0,
            GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
            level,
          )
        }
      } else {
        self.setup_frame_buffer_texture(
          textures_framebuffer(face),
          render_target,
          texture,
          GL_COLOR_ATTACHMENT0,
          GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
          0,
        )
      }
    }
    if textures_needs_generate_mipmaps(texture) {
      self.generate_mipmap(GL_TEXTURE_CUBE_MAP)
    } else if texture.mipmaps.length() > 0 {
      // Limit the max level to keep partial mip chains complete.
      gl.tex_parameteri(
        GL_TEXTURE_CUBE_MAP,
        GL_TEXTURE_MAX_LEVEL,
        texture.mipmaps.length() - 1,
      )
    }
    state.unbind_texture()
  } else if is_multiple_render_targets {
    for i, attachment in textures {
      let attachment_properties = self.properties.get_texture(attachment)
      let mut gl_texture_type = GL_TEXTURE_2D
      if textures_is_3d_target(render_target) ||
        textures_is_array_target(render_target) {
        gl_texture_type = if textures_is_3d_target(render_target) {
          GL_TEXTURE_3D
        } else {
          GL_TEXTURE_2D_ARRAY
        }
      }
      state.bind_texture(gl_texture_type, attachment_properties.__webgl_texture)
      self.set_texture_parameters(gl_texture_type, attachment)
      self.setup_frame_buffer_texture(
        textures_framebuffer(render_target_properties.__webgl_framebuffer),
        render_target,
        attachment,
        GL_COLOR_ATTACHMENT0 + i,
        gl_texture_type,
        0,
      )
      if textures_needs_generate_mipmaps(attachment) {
        self.generate_mipmap(gl_texture_type)
      }
    }
    state.unbind_texture()
  } else {
    let mut gl_texture_type = GL_TEXTURE_2D
    if textures_is_3d_target(render_target) ||
      textures_is_array_target(render_target) {
      gl_texture_type = if textures_is_3d_target(render_target) {
        GL_TEXTURE_3D
      } else {
        GL_TEXTURE_2D_ARRAY
      }
    }
    state.bind_texture(gl_texture_type, texture_properties.__webgl_texture)
    self.set_texture_parameters(gl_texture_type, texture)
    if texture.mipmaps.length() > 0 {
      for level in 0..<texture.mipmaps.length() {
        self.setup_frame_buffer_texture(
          textures_framebuffer(
            textures_framebuffer_at(
              render_target_properties.__webgl_framebuffer,
              level,
            ),
          ),
          render_target,
          texture,
          GL_COLOR_ATTACHMENT0,
          gl_texture_type,
          level,
        )
      }
    } else {
      self.setup_frame_buffer_texture(
        textures_framebuffer(render_target_properties.__webgl_framebuffer),
        render_target,
        texture,
        GL_COLOR_ATTACHMENT0,
        gl_texture_type,
        0,
      )
    }
    if textures_needs_generate_mipmaps(texture) {
      self.generate_mipmap(gl_texture_type)
    } else if texture.mipmaps.length() > 0 {
      // Limit the max level to keep partial mip chains complete.
      gl.tex_parameteri(
        gl_texture_type,
        GL_TEXTURE_MAX_LEVEL,
        texture.mipmaps.length() - 1,
      )
    }
    state.unbind_texture()
  }
  // Setup depth and stencil buffers
  if render_target.depth_buffer {
    self.setup_depth_renderbuffer(render_target)
  }
}

///|
/// `textures.updateRenderTargetMipmap( renderTarget )`.
pub fn WebGLTextures::update_render_target_mipmap(
  self : WebGLTextures,
  render_target : @core.RenderTarget,
) -> Unit {
  for texture in render_target.textures {
    if textures_needs_generate_mipmaps(texture) && texture.mipmaps_auto_update {
      let target_type = textures_get_target_type(render_target)
      let webgl_texture = self.properties.get_texture(texture).__webgl_texture
      self.state.bind_texture(target_type, webgl_texture)
      self.generate_mipmap(target_type)
      self.state.unbind_texture()
    }
  }
}

///|
/// `textures.updateMultisampleRenderTarget( renderTarget )`.
pub fn WebGLTextures::update_multisample_render_target(
  self : WebGLTextures,
  render_target : @core.RenderTarget,
) -> Unit {
  let gl = self.gl
  let state = self.state
  if render_target.samples <= 0 {
    return
  }
  if !self.use_multisampled_rtt(render_target) {
    let textures = render_target.textures
    let width = render_target.width
    let height = render_target.height
    let mut mask = GL_COLOR_BUFFER_BIT
    let depth_style = if render_target.stencil_buffer {
      GL_DEPTH_STENCIL_ATTACHMENT
    } else {
      GL_DEPTH_ATTACHMENT
    }
    let render_target_properties = self.properties.get_render_target(
      render_target,
    )
    let is_multiple_render_targets = textures.length() > 1
    let multisampled_framebuffer = render_target_properties.__webgl_multisampled_framebuffer
    let framebuffer = textures_framebuffer(
      render_target_properties.__webgl_framebuffer,
    )
    let color_renderbuffer = (i : Int32) => {
      match render_target_properties.__webgl_color_renderbuffer {
        Some(renderbuffers) if i < renderbuffers.length() => renderbuffers[i]
        _ => None
      }
    }
    // If MRT we need to remove FBO attachments
    if is_multiple_render_targets {
      for i in 0..<textures.length() {
        ignore(state.bind_framebuffer(GL_FRAMEBUFFER, multisampled_framebuffer))
        gl.framebuffer_renderbuffer(
          GL_FRAMEBUFFER,
          GL_COLOR_ATTACHMENT0 + i,
          GL_RENDERBUFFER,
          None,
        )
        ignore(state.bind_framebuffer(GL_FRAMEBUFFER, framebuffer))
        gl.framebuffer_texture2d(
          GL_DRAW_FRAMEBUFFER,
          GL_COLOR_ATTACHMENT0 + i,
          GL_TEXTURE_2D,
          None,
          0,
        )
      }
    }
    ignore(
      state.bind_framebuffer(GL_READ_FRAMEBUFFER, multisampled_framebuffer),
    )
    let mipmaps = render_target.texture().mipmaps
    if mipmaps.length() > 0 {
      ignore(
        state.bind_framebuffer(
          GL_DRAW_FRAMEBUFFER,
          textures_framebuffer(
            textures_framebuffer_at(
              render_target_properties.__webgl_framebuffer,
              0,
            ),
          ),
        ),
      )
    } else {
      ignore(state.bind_framebuffer(GL_DRAW_FRAMEBUFFER, framebuffer))
    }
    for i in 0..<textures.length() {
      if render_target.resolve_depth_buffer {
        if render_target.depth_buffer {
          mask = mask | GL_DEPTH_BUFFER_BIT
        }
        // resolving stencil is slow with a D3D backend. disable it for all transmission
        // render targets (see #27799)
        if render_target.stencil_buffer && render_target.resolve_stencil_buffer {
          mask = mask | GL_STENCIL_BUFFER_BIT
        }
      }
      if is_multiple_render_targets {
        gl.framebuffer_renderbuffer(
          GL_READ_FRAMEBUFFER,
          GL_COLOR_ATTACHMENT0,
          GL_RENDERBUFFER,
          color_renderbuffer(i),
        )
        let webgl_texture = self.properties.get_texture(textures[i]).__webgl_texture
        gl.framebuffer_texture2d(
          GL_DRAW_FRAMEBUFFER,
          GL_COLOR_ATTACHMENT0,
          GL_TEXTURE_2D,
          webgl_texture,
          0,
        )
      }
      gl.blit_framebuffer(
        0,
        0,
        width,
        height,
        0,
        0,
        width,
        height,
        mask,
        GL_NEAREST,
      )
      if self.supports_invalidate_framebuffer {
        self.invalidation_array_read.clear()
        self.invalidation_array_read.push(GL_COLOR_ATTACHMENT0 + i)
        if render_target.depth_buffer &&
          !render_target.store_multisampled_depth_buffer {
          self.invalidation_array_read.push(depth_style)
        }
        gl.invalidate_framebuffer(
          GL_READ_FRAMEBUFFER,
          self.invalidation_array_read,
        )
      }
    }
    ignore(state.bind_framebuffer(GL_READ_FRAMEBUFFER, None))
    ignore(state.bind_framebuffer(GL_DRAW_FRAMEBUFFER, None))
    // If MRT since pre-blit we removed the FBO we need to reconstruct the attachments
    if is_multiple_render_targets {
      for i in 0..<textures.length() {
        ignore(state.bind_framebuffer(GL_FRAMEBUFFER, multisampled_framebuffer))
        gl.framebuffer_renderbuffer(
          GL_FRAMEBUFFER,
          GL_COLOR_ATTACHMENT0 + i,
          GL_RENDERBUFFER,
          color_renderbuffer(i),
        )
        let webgl_texture = self.properties.get_texture(textures[i]).__webgl_texture
        ignore(state.bind_framebuffer(GL_FRAMEBUFFER, framebuffer))
        gl.framebuffer_texture2d(
          GL_DRAW_FRAMEBUFFER,
          GL_COLOR_ATTACHMENT0 + i,
          GL_TEXTURE_2D,
          webgl_texture,
          0,
        )
      }
    }
    ignore(
      state.bind_framebuffer(GL_DRAW_FRAMEBUFFER, multisampled_framebuffer),
    )
  } else if render_target.depth_buffer &&
    !render_target.store_multisampled_depth_buffer &&
    self.supports_invalidate_framebuffer {
    let depth_style = if render_target.stencil_buffer {
      GL_DEPTH_STENCIL_ATTACHMENT
    } else {
      GL_DEPTH_ATTACHMENT
    }
    gl.invalidate_framebuffer(GL_DRAW_FRAMEBUFFER, [depth_style])
  }
}

///|
/// `getRenderTargetSamples( renderTarget )`.
fn WebGLTextures::get_render_target_samples(
  self : WebGLTextures,
  render_target : @core.RenderTarget,
) -> Int32 {
  let max_samples = self.capabilities.max_samples
  if max_samples < render_target.samples {
    max_samples
  } else {
    render_target.samples
  }
}

///|
/// `textures.useMultisampledRTT( renderTarget )`.
pub fn WebGLTextures::use_multisampled_rtt(
  self : WebGLTextures,
  render_target : @core.RenderTarget,
) -> Bool {
  let render_target_properties = self.properties.get_render_target(
    render_target,
  )
  render_target.samples > 0 &&
  self.extensions.has("WEBGL_multisampled_render_to_texture") &&
  render_target_properties.__use_render_to_texture != Some(false)
}

///|
/// `updateVideoTexture( texture )`.
fn WebGLTextures::update_video_texture(
  self : WebGLTextures,
  texture : @core.Texture,
) -> Unit {
  let frame = self.info.render.frame
  // Check the last frame we updated the VideoTexture
  if self._video_textures.get(texture) != Some(frame) {
    self._video_textures.set(texture, frame)
    texture.update()
  }
}

///|
/// `verifyColorSpace( texture, image )`.
fn WebGLTextures::verify_color_space(
  _self : WebGLTextures,
  texture : @core.Texture,
  image : @core.TextureImage,
) -> @core.TextureImage {
  let color_space = texture.color_space
  let format = texture.format
  let type_ = texture.type_
  if texture.is_compressed_texture() || texture.is_video_texture() {
    return image
  }
  if color_space != @core.LinearSRGBColorSpace &&
    color_space != @core.NoColorSpace {
    // sRGB
    if @math.color_management.get_transfer(color_space) == @core.SRGBTransfer {
      // in WebGL 2 uncompressed textures can only be sRGB encoded if they have the RGBA8
      // format
      if format != @core.RGBAFormat || type_ != @core.UnsignedByteType {
        @core.warn(
          "WebGLTextures: sRGB encoded textures have to use RGBAFormat and UnsignedByteType.",
        )
      }
    } else {
      @core.error(
        "WebGLTextures: Unsupported texture color space: " + color_space,
      )
    }
  }
  image
}

///|
/// `getDimensions( image )`: the shared `_imageDimensions`.
fn WebGLTextures::get_dimensions(
  self : WebGLTextures,
  image : @core.TextureImage,
) -> @math.Vector2 {
  let dimensions = self._image_dimensions
  match image {
    DomImage(value) if is_html_image_element(value) => {
      // if intrinsic data are not available, fallback to width/height
      dimensions.x = textures_natural_width(value)
      dimensions.y = textures_natural_height(value)
    }
    DomImage(value) if is_video_frame(value) => {
      dimensions.x = textures_display_width(value)
      dimensions.y = textures_display_height(value)
    }
    DomImage(value) => {
      dimensions.x = textures_js_width(value)
      dimensions.y = textures_js_height(value)
    }
    _ => {
      dimensions.x = textures_image_width(image).to_double()
      dimensions.y = textures_image_height(image).to_double()
    }
  }
  dimensions
}

///|
/// `texture.wrapR`, which only 3D and array textures have (`undefined` elsewhere).
fn textures_wrap_r(texture : @core.Texture) -> Int32? {
  if texture.texture_type
    is (CompressedArrayTexture | Data3DTexture | DataArrayTexture) {
    Some(texture.wrap_r)
  } else {
    None
  }
}
