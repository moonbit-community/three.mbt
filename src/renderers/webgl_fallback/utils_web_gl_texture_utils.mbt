// renderers/webgl-fallback/utils/WebGLTextureUtils.js: texture creation, upload, copies
// and readback for the WebGL backend. Per-texture state lives in the backend's records
// (`backend.get( texture )`), plain JS objects with upstream's key names.

///|
/// `initialized`: the GL tables are built by the first `WebGLTextureUtils`.
let _web_gl_texture_utils_initialized : Ref[Bool] = Ref(false)

///|
/// `wrappingToGL`.
let _web_gl_texture_utils_wrapping_to_gl : Map[Int32, Int32] = Map([])

///|
/// `filterToGL`.
let _web_gl_texture_utils_filter_to_gl : Map[Int32, Int32] = Map([])

///|
/// `compareToGL`.
let _web_gl_texture_utils_compare_to_gl : Map[Int32, Int32] = Map([])

///|
pub(all) struct WebGLTextureUtils {
  backend : WebGLBackend
  gl : @webgl.WebGL2RenderingContext
  extensions : WebGLExtensions
  /// `defaultTextures[ glTextureType ]`.
  default_textures : Map[Int32, @webgl.GLTexture]
  mut _src_framebuffer : @webgl.GLFramebuffer?
  mut _dst_framebuffer : @webgl.GLFramebuffer?
}

///|
/// `new WebGLTextureUtils( backend )`.
pub fn WebGLTextureUtils::new(backend : WebGLBackend) -> WebGLTextureUtils {
  let utils : WebGLTextureUtils = {
    backend,
    gl: backend.gl.unwrap(),
    extensions: backend.extensions.unwrap(),
    default_textures: Map([]),
    _src_framebuffer: None,
    _dst_framebuffer: None,
  }
  if _web_gl_texture_utils_initialized.val == false {
    utils._init()
    _web_gl_texture_utils_initialized.val = true
  }
  utils
}

///|
/// `_init()`: fills the GL lookup tables.
fn WebGLTextureUtils::_init(self : WebGLTextureUtils) -> Unit {
  ignore(self)
  let w = _web_gl_texture_utils_wrapping_to_gl
  w.set(@core.RepeatWrapping, @webgl.GL_REPEAT)
  w.set(@core.ClampToEdgeWrapping, @webgl.GL_CLAMP_TO_EDGE)
  w.set(@core.MirroredRepeatWrapping, @webgl.GL_MIRRORED_REPEAT)
  let f = _web_gl_texture_utils_filter_to_gl
  f.set(@core.NearestFilter, @webgl.GL_NEAREST)
  f.set(@core.NearestMipmapNearestFilter, @webgl.GL_NEAREST_MIPMAP_NEAREST)
  f.set(@core.NearestMipmapLinearFilter, @webgl.GL_NEAREST_MIPMAP_LINEAR)
  f.set(@core.LinearFilter, @webgl.GL_LINEAR)
  f.set(@core.LinearMipmapNearestFilter, @webgl.GL_LINEAR_MIPMAP_NEAREST)
  f.set(@core.LinearMipmapLinearFilter, @webgl.GL_LINEAR_MIPMAP_LINEAR)
  let c = _web_gl_texture_utils_compare_to_gl
  c.set(@core.NeverCompare, @webgl.GL_NEVER)
  c.set(@core.AlwaysCompare, @webgl.GL_ALWAYS)
  c.set(@core.LessCompare, @webgl.GL_LESS)
  c.set(@core.LessEqualCompare, @webgl.GL_LEQUAL)
  c.set(@core.EqualCompare, @webgl.GL_EQUAL)
  c.set(@core.GreaterEqualCompare, @webgl.GL_GEQUAL)
  c.set(@core.GreaterCompare, @webgl.GL_GREATER)
  c.set(@core.NotEqualCompare, @webgl.GL_NOTEQUAL)
}

// --- JS record helpers ---------------------------------------------------------------

///|
extern "js" fn _tu_record5(
  texture_gpu : @core.JsValue,
  gl_texture_type : @core.JsValue,
  gl_format : @core.JsValue,
  gl_type : @core.JsValue,
  gl_internal_format : @core.JsValue,
) -> @core.JsValue = "(a, b, c, d, e) => ({ textureGPU: a, glTextureType: b, glFormat: c, glType: d, glInternalFormat: e })"

///|
extern "js" fn _tu_record2(
  texture_gpu : @core.JsValue,
  gl_texture_type : @core.JsValue,
) -> @core.JsValue = "(a, b) => ({ textureGPU: a, glTextureType: b })"

///|
/// `delete record[ key ]`.
extern "js" fn _tu_delete_key(record : @core.JsValue, key : String) -> Unit = "(o, k) => { delete o[ k ]; }"

///|
/// `record[ key ]` with a numeric key (`framebuffers[ renderContext.getCacheKey() ]`).
extern "js" fn _tu_get_number_key(
  record : @core.JsValue,
  key : Double,
) -> @core.JsValue = "(o, k) => o[ k ]"

///|
/// The keys of `for ( const key in record )`.
extern "js" fn _tu_keys(record : @core.JsValue) -> FixedArray[String] = "(o) => { const r = []; for ( const k in o ) r.push( k ); return r; }"

///|
/// JS truthiness.
extern "js" fn _tu_truthy(value : @core.JsValue) -> Bool = "(v) => v ? true : false"

///|
extern "js" fn _tu_length(value : @core.JsValue) -> Int32 = "(v) => v.length"

///|
extern "js" fn _tu_index(value : @core.JsValue, i : Int32) -> @core.JsValue = "(v, i) => v[ i ]"

///|
/// `getImage( source )` for a DOM value: the source when it is an image, canvas, bitmap
/// or offscreen canvas, else `source.data`.
extern "js" fn _tu_dom_image(source : @core.JsValue) -> @core.JsValue =
  #|( source ) => {
  #|  if ( ( typeof HTMLImageElement !== 'undefined' && source instanceof HTMLImageElement ) ||
  #|    ( typeof HTMLCanvasElement !== 'undefined' && source instanceof HTMLCanvasElement ) ||
  #|    ( typeof ImageBitmap !== 'undefined' && source instanceof ImageBitmap ) ||
  #|    ( typeof OffscreenCanvas !== 'undefined' && source instanceof OffscreenCanvas ) ) {
  #|    return source;
  #|  }
  #|  return source.data;
  #|}

///|
/// `new ( globalThis[ name ] )( length )`.
extern "js" fn _tu_new_typed_array(
  name : String,
  length : Double,
) -> @core.TypedArray = "(n, l) => new globalThis[ n ]( l )"

///|
/// `globalThis[ name ].BYTES_PER_ELEMENT`.
extern "js" fn _tu_bytes_per_element(name : String) -> Double = "(n) => globalThis[ n ].BYTES_PER_ELEMENT"

///|
/// A GL handle (or `undefined`/`null`) from a record as a nullable handle.
fn[T] _tu_handle(value : @core.JsValue) -> T? {
  if value.is_undefined() || value.is_null() {
    None
  } else {
    Some(value.cast())
  }
}

///|
/// An optional GL enum as JS sees it (`None` is `null`).
fn _tu_int_or_null(value : Int32?) -> @core.JsValue {
  match value {
    Some(v) => @core.JsValue::of(v)
    None => @core.JsValue::null()
  }
}

///|
/// A number from a record (`undefined` reads as 0).
fn _tu_int(value : @core.JsValue) -> Int32 {
  if value.is_undefined() || value.is_null() {
    0
  } else {
    @webgl.js_number_to_int(value)
  }
}

///|
/// `getImage( source )`.
fn _tu_get_image(source : @core.TextureImage) -> @core.JsValue {
  match source {
    TextureImage(texture) if texture.texture_type is DataTexture =>
      match texture.image() {
        DataImage(image) => _tu_data(image.data)
        image => _tu_dom_image(image.to_js())
      }
    TextureImage(texture) => _tu_dom_image(@core.JsValue::of(texture))
    DomImage(value) => _tu_dom_image(value)
    DataImage(image) => _tu_data(image.data)
    NoImage =>
      abort(
        "TypeError: Cannot read properties of null (reading 'isDataTexture')",
      )
    ImageArray(_) => @core.JsValue::undefined()
  }
}

///|
/// `image.data` as JS sees it.
fn _tu_data(data : @core.TypedArray?) -> @core.JsValue {
  match data {
    Some(d) => @core.JsValue::of(d)
    None => @core.JsValue::null()
  }
}

///|
/// `image.data` of a `TextureImage`.
fn _tu_image_data(image : @core.TextureImage) -> @core.JsValue {
  match image {
    DataImage(i) => _tu_data(i.data)
    NoImage =>
      abort("TypeError: Cannot read properties of null (reading 'data')")
    other => @core.JsValue::of(other.to_js()).get("data")
  }
}

///|
/// `image[ i ]` of a cube texture's image array.
fn _tu_image_at(image : @core.TextureImage, i : Int32) -> @core.TextureImage {
  match image {
    ImageArray(images) => images[i]
    _ => abort("WebGLTextureUtils: image is not an array")
  }
}

///|
/// The `mipmaps` of a per-face compressed cube image.
fn _tu_image_mipmaps(image : @core.TextureImage) -> Array[@core.DataImage] {
  match image {
    DataImage(i) =>
      match i.mipmaps {
        Some(m) => m
        None =>
          abort(
            "TypeError: Cannot read properties of undefined (reading 'length')",
          )
      }
    _ =>
      abort("TypeError: Cannot read properties of undefined (reading 'length')")
  }
}

///|
/// `Math.floor( x )`.
extern "js" fn _tu_floor(x : Double) -> Double = "(x) => Math.floor( x )"

///|
/// `Math.pow( x, y )`.
extern "js" fn _tu_pow(x : Double, y : Double) -> Double = "(x, y) => Math.pow( x, y )"

///|
/// `Math.ceil( x )`.
extern "js" fn _tu_ceil(x : Double) -> Double = "(x) => Math.ceil( x )"

///|
/// `getByteLength( width, height, format, type )` from src/extras/TextureUtils.js. This
/// package does not import `extras`, so the function is repeated here.
fn _tu_get_byte_length(
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
    _tu_floor((w + n - 1.0) / n) * _tu_floor((h + m - 1.0) / m) * bytes
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
      @webgl.js_math_max(w, 16.0) * @webgl.js_math_max(h, 8.0) / 4.0
    @core.RGB_PVRTC_4BPPV1_Format | @core.RGBA_PVRTC_4BPPV1_Format =>
      @webgl.js_math_max(w, 8.0) * @webgl.js_math_max(h, 8.0) / 2.0
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
      _tu_ceil(w / 4.0) * _tu_ceil(h / 4.0) * 16.0
    @core.RED_RGTC1_Format | @core.SIGNED_RED_RGTC1_Format =>
      _tu_ceil(w / 4.0) * _tu_ceil(h / 4.0) * 8.0
    @core.RED_GREEN_RGTC2_Format | @core.SIGNED_RED_GREEN_RGTC2_Format =>
      _tu_ceil(w / 4.0) * _tu_ceil(h / 4.0) * 16.0
    _ => abort("Unable to determine texture byte length for \{format} format.")
  }
}

// --- texture kinds -------------------------------------------------------------------

///|
/// `isArrayTexture || isDataArrayTexture || isCompressedArrayTexture`.
fn _tu_is_any_array(texture : @core.Texture) -> Bool {
  texture.is_array_texture ||
  texture.texture_type is DataArrayTexture ||
  texture.texture_type is CompressedArrayTexture
}

///|
fn _tu_is_data3d(texture : @core.Texture) -> Bool {
  texture.texture_type is Data3DTexture
}

///|
fn _tu_is_data_array(texture : @core.Texture) -> Bool {
  texture.texture_type is DataArrayTexture
}

// --- members -------------------------------------------------------------------------

///|
/// `getGLTextureType( texture )`.
pub fn WebGLTextureUtils::get_gl_texture_type(
  self : WebGLTextureUtils,
  texture : @core.Texture,
) -> Int32 {
  ignore(self)
  if texture.is_cube_texture() == true {
    @webgl.GL_TEXTURE_CUBE_MAP
  } else if _tu_is_any_array(texture) {
    @webgl.GL_TEXTURE_2D_ARRAY
  } else if _tu_is_data3d(texture) {
    // TODO: isCompressed3DTexture, wait for #26642
    @webgl.GL_TEXTURE_3D
  } else {
    @webgl.GL_TEXTURE_2D
  }
}

///|
/// `getInternalFormat( internalFormatName, glFormat, glType, normalized, colorSpace,
/// forceLinearTransfer = false )`.
pub fn WebGLTextureUtils::get_internal_format(
  self : WebGLTextureUtils,
  internal_format_name : String?,
  gl_format : Int32,
  gl_type : Int32,
  normalized : Bool,
  color_space : String,
  force_linear_transfer~ : Bool = false,
) -> Int32 {
  let { gl, extensions, .. } = self
  match internal_format_name {
    Some(name) => {
      match gl.get_constant(name) {
        Some(c) => return c
        None => ()
      }
      @core.warn(
        "WebGLBackend: Attempt to use non-existing WebGL internal format '" +
        name +
        "'",
      )
    }
    None => ()
  }
  let mut ext_texture_norm16 : @webgl.GLExtension? = None
  if normalized {
    ext_texture_norm16 = extensions.get("EXT_texture_norm16")
    if ext_texture_norm16 is None {
      @core.warn(
        "WebGLRenderer: Unable to use normalized textures without EXT_texture_norm16 extension",
      )
    }
  }
  let norm16 = fn(name : String) -> Int32? {
    match ext_texture_norm16 {
      Some(e) => Some(e.constant(name))
      None => None
    }
  }
  let mut internal_format = gl_format
  if gl_format == @webgl.GL_RED {
    if gl_type == @webgl.GL_FLOAT {
      internal_format = @webgl.GL_R32F
    }
    if gl_type == @webgl.GL_HALF_FLOAT {
      internal_format = @webgl.GL_R16F
    }
    if gl_type == @webgl.GL_UNSIGNED_BYTE {
      internal_format = @webgl.GL_R8
    }
    if gl_type == @webgl.GL_BYTE {
      internal_format = @webgl.GL_R8_SNORM
    }
    if gl_type == @webgl.GL_UNSIGNED_SHORT && norm16("R16_EXT") is Some(f) {
      internal_format = f
    }
    if gl_type == @webgl.GL_SHORT && norm16("R16_SNORM_EXT") is Some(f) {
      internal_format = f
    }
  }
  if gl_format == @webgl.GL_RED_INTEGER {
    if gl_type == @webgl.GL_UNSIGNED_BYTE {
      internal_format = @webgl.GL_R8UI
    }
    if gl_type == @webgl.GL_UNSIGNED_SHORT {
      internal_format = @webgl.GL_R16UI
    }
    if gl_type == @webgl.GL_UNSIGNED_INT {
      internal_format = @webgl.GL_R32UI
    }
    if gl_type == @webgl.GL_BYTE {
      internal_format = @webgl.GL_R8I
    }
    if gl_type == @webgl.GL_SHORT {
      internal_format = @webgl.GL_R16I
    }
    if gl_type == @webgl.GL_INT {
      internal_format = @webgl.GL_R32I
    }
  }
  if gl_format == @webgl.GL_RG {
    if gl_type == @webgl.GL_FLOAT {
      internal_format = @webgl.GL_RG32F
    }
    if gl_type == @webgl.GL_HALF_FLOAT {
      internal_format = @webgl.GL_RG16F
    }
    if gl_type == @webgl.GL_UNSIGNED_BYTE {
      internal_format = @webgl.GL_RG8
    }
    if gl_type == @webgl.GL_BYTE {
      internal_format = @webgl.GL_RG8_SNORM
    }
    if gl_type == @webgl.GL_UNSIGNED_SHORT && norm16("RG16_EXT") is Some(f) {
      internal_format = f
    }
    if gl_type == @webgl.GL_SHORT && norm16("RG16_SNORM_EXT") is Some(f) {
      internal_format = f
    }
  }
  if gl_format == @webgl.GL_RG_INTEGER {
    if gl_type == @webgl.GL_UNSIGNED_BYTE {
      internal_format = @webgl.GL_RG8UI
    }
    if gl_type == @webgl.GL_UNSIGNED_SHORT {
      internal_format = @webgl.GL_RG16UI
    }
    if gl_type == @webgl.GL_UNSIGNED_INT {
      internal_format = @webgl.GL_RG32UI
    }
    if gl_type == @webgl.GL_BYTE {
      internal_format = @webgl.GL_RG8I
    }
    if gl_type == @webgl.GL_SHORT {
      internal_format = @webgl.GL_RG16I
    }
    if gl_type == @webgl.GL_INT {
      internal_format = @webgl.GL_RG32I
    }
  }
  if gl_format == @webgl.GL_RGB {
    let transfer = if force_linear_transfer {
      @math.LinearTransfer
    } else {
      @math.color_management.get_transfer(color_space)
    }
    if gl_type == @webgl.GL_FLOAT {
      internal_format = @webgl.GL_RGB32F
    }
    if gl_type == @webgl.GL_HALF_FLOAT {
      internal_format = @webgl.GL_RGB16F
    }
    if gl_type == @webgl.GL_UNSIGNED_BYTE {
      internal_format = if transfer == @math.SRGBTransfer {
        @webgl.GL_SRGB8
      } else {
        @webgl.GL_RGB8
      }
    }
    if gl_type == @webgl.GL_BYTE {
      internal_format = @webgl.GL_RGB8_SNORM
    }
    if gl_type == @webgl.GL_UNSIGNED_SHORT && norm16("RGB16_EXT") is Some(f) {
      internal_format = f
    }
    if gl_type == @webgl.GL_SHORT && norm16("RGB16_SNORM_EXT") is Some(f) {
      internal_format = f
    }
    if gl_type == @webgl.GL_UNSIGNED_SHORT_5_6_5 {
      internal_format = @webgl.GL_RGB565
    }
    if gl_type == @webgl.GL_UNSIGNED_SHORT_5_5_5_1 {
      internal_format = @webgl.GL_RGB5_A1
    }
    if gl_type == @webgl.GL_UNSIGNED_SHORT_4_4_4_4 {
      internal_format = @webgl.GL_RGB4
    }
    if gl_type == @webgl.GL_UNSIGNED_INT_5_9_9_9_REV {
      internal_format = @webgl.GL_RGB9_E5
    }
    if gl_type == @webgl.GL_UNSIGNED_INT_10F_11F_11F_REV {
      internal_format = @webgl.GL_R11F_G11F_B10F
    }
  }
  if gl_format == @webgl.GL_RGB_INTEGER {
    if gl_type == @webgl.GL_UNSIGNED_BYTE {
      internal_format = @webgl.GL_RGB8UI
    }
    if gl_type == @webgl.GL_UNSIGNED_SHORT {
      internal_format = @webgl.GL_RGB16UI
    }
    if gl_type == @webgl.GL_UNSIGNED_INT {
      internal_format = @webgl.GL_RGB32UI
    }
    if gl_type == @webgl.GL_BYTE {
      internal_format = @webgl.GL_RGB8I
    }
    if gl_type == @webgl.GL_SHORT {
      internal_format = @webgl.GL_RGB16I
    }
    if gl_type == @webgl.GL_INT {
      internal_format = @webgl.GL_RGB32I
    }
  }
  if gl_format == @webgl.GL_RGBA {
    let transfer = if force_linear_transfer {
      @math.LinearTransfer
    } else {
      @math.color_management.get_transfer(color_space)
    }
    if gl_type == @webgl.GL_FLOAT {
      internal_format = @webgl.GL_RGBA32F
    }
    if gl_type == @webgl.GL_HALF_FLOAT {
      internal_format = @webgl.GL_RGBA16F
    }
    if gl_type == @webgl.GL_UNSIGNED_BYTE {
      internal_format = if transfer == @math.SRGBTransfer {
        @webgl.GL_SRGB8_ALPHA8
      } else {
        @webgl.GL_RGBA8
      }
    }
    if gl_type == @webgl.GL_BYTE {
      internal_format = @webgl.GL_RGBA8_SNORM
    }
    if gl_type == @webgl.GL_UNSIGNED_SHORT && norm16("RGBA16_EXT") is Some(f) {
      internal_format = f
    }
    if gl_type == @webgl.GL_SHORT && norm16("RGBA16_SNORM_EXT") is Some(f) {
      internal_format = f
    }
    if gl_type == @webgl.GL_UNSIGNED_SHORT_4_4_4_4 {
      internal_format = @webgl.GL_RGBA4
    }
    if gl_type == @webgl.GL_UNSIGNED_SHORT_5_5_5_1 {
      internal_format = @webgl.GL_RGB5_A1
    }
  }
  if gl_format == @webgl.GL_RGBA_INTEGER {
    if gl_type == @webgl.GL_UNSIGNED_BYTE {
      internal_format = @webgl.GL_RGBA8UI
    }
    if gl_type == @webgl.GL_UNSIGNED_SHORT {
      internal_format = @webgl.GL_RGBA16UI
    }
    if gl_type == @webgl.GL_UNSIGNED_INT {
      internal_format = @webgl.GL_RGBA32UI
    }
    if gl_type == @webgl.GL_BYTE {
      internal_format = @webgl.GL_RGBA8I
    }
    if gl_type == @webgl.GL_SHORT {
      internal_format = @webgl.GL_RGBA16I
    }
    if gl_type == @webgl.GL_INT {
      internal_format = @webgl.GL_RGBA32I
    }
  }
  if gl_format == @webgl.GL_DEPTH_COMPONENT {
    if gl_type == @webgl.GL_UNSIGNED_SHORT {
      internal_format = @webgl.GL_DEPTH_COMPONENT16
    }
    if gl_type == @webgl.GL_UNSIGNED_INT {
      internal_format = @webgl.GL_DEPTH_COMPONENT24
    }
    if gl_type == @webgl.GL_FLOAT {
      internal_format = @webgl.GL_DEPTH_COMPONENT32F
    }
  }
  if gl_format == @webgl.GL_DEPTH_STENCIL {
    if gl_type == @webgl.GL_UNSIGNED_INT_24_8 {
      internal_format = @webgl.GL_DEPTH24_STENCIL8
    }
    if gl_type == @webgl.GL_FLOAT {
      internal_format = @webgl.GL_DEPTH32F_STENCIL8
    }
  }
  if internal_format == @webgl.GL_R16F ||
    internal_format == @webgl.GL_R32F ||
    internal_format == @webgl.GL_RG16F ||
    internal_format == @webgl.GL_RG32F ||
    internal_format == @webgl.GL_RGBA16F ||
    internal_format == @webgl.GL_RGBA32F {
    extensions.get("EXT_color_buffer_float") |> ignore
  }
  internal_format
}

///|
/// `wrappingToGL[ wrap ]` (0 for an unknown mode, where upstream passes `undefined`).
fn _tu_wrap(wrap : Int32) -> Int32 {
  _web_gl_texture_utils_wrapping_to_gl.get(wrap).unwrap_or(0)
}

///|
/// `filterToGL[ filter ]`.
fn _tu_filter(filter : Int32) -> Int32 {
  _web_gl_texture_utils_filter_to_gl.get(filter).unwrap_or(0)
}

///|
/// `setTextureParameters( textureType, texture )`.
pub fn WebGLTextureUtils::set_texture_parameters(
  self : WebGLTextureUtils,
  texture_type : Int32,
  texture : @core.Texture,
) -> Unit {
  let { gl, extensions, backend, .. } = self
  let state = backend.state.unwrap()
  let color_management = @math.color_management
  let working_primaries = color_management.get_primaries(
    color_management.working_color_space,
  )
  let texture_primaries = if texture.color_space == @math.NoColorSpace {
    None
  } else {
    Some(color_management.get_primaries(texture.color_space))
  }
  let unpack_conversion = if texture.color_space == @math.NoColorSpace ||
    (texture_primaries is Some(p) && physical_equal(working_primaries, p)) {
    @webgl.GL_NONE
  } else {
    @webgl.GL_BROWSER_DEFAULT_WEBGL
  }
  state.pixel_storei_bool(@webgl.GL_UNPACK_FLIP_Y_WEBGL, texture.flip_y)
  state.pixel_storei_bool(
    @webgl.GL_UNPACK_PREMULTIPLY_ALPHA_WEBGL,
    texture.premultiply_alpha,
  )
  state.pixel_storei(@webgl.GL_UNPACK_ALIGNMENT, texture.unpack_alignment)
  state.pixel_storei(
    @webgl.GL_UNPACK_COLORSPACE_CONVERSION_WEBGL,
    unpack_conversion,
  )
  gl.tex_parameteri(
    texture_type,
    @webgl.GL_TEXTURE_WRAP_S,
    _tu_wrap(texture.wrap_s),
  )
  gl.tex_parameteri(
    texture_type,
    @webgl.GL_TEXTURE_WRAP_T,
    _tu_wrap(texture.wrap_t),
  )
  if texture_type == @webgl.GL_TEXTURE_3D ||
    texture_type == @webgl.GL_TEXTURE_2D_ARRAY {
    // WebGL 2 does not support wrapping for depth 2D array textures
    if !texture.is_array_texture {
      gl.tex_parameteri(
        texture_type,
        @webgl.GL_TEXTURE_WRAP_R,
        _tu_wrap(texture.wrap_r),
      )
    }
  }
  gl.tex_parameteri(
    texture_type,
    @webgl.GL_TEXTURE_MAG_FILTER,
    _tu_filter(texture.mag_filter),
  )
  let has_mipmaps = texture.mipmaps.length() > 0
  // follow WebGPU backend mapping for texture filtering
  let min_filter = if texture.min_filter == @core.LinearFilter && has_mipmaps {
    @core.LinearMipmapLinearFilter
  } else {
    texture.min_filter
  }
  gl.tex_parameteri(
    texture_type,
    @webgl.GL_TEXTURE_MIN_FILTER,
    _tu_filter(min_filter),
  )
  match texture.compare_function {
    Some(compare) if compare != 0 => {
      gl.tex_parameteri(
        texture_type,
        @webgl.GL_TEXTURE_COMPARE_MODE,
        @webgl.GL_COMPARE_REF_TO_TEXTURE,
      )
      gl.tex_parameteri(
        texture_type,
        @webgl.GL_TEXTURE_COMPARE_FUNC,
        _web_gl_texture_utils_compare_to_gl.get(compare).unwrap_or(0),
      )
    }
    _ => ()
  }
  if extensions.has("EXT_texture_filter_anisotropic") == true {
    if texture.mag_filter == @core.NearestFilter {
      return
    }
    if texture.min_filter != @core.NearestMipmapLinearFilter &&
      texture.min_filter != @core.LinearMipmapLinearFilter {
      return
    }
    if texture.type_ == @core.FloatType &&
      extensions.has("OES_texture_float_linear") == false {
      return
    }
    // verify extension for WebGL 1 and WebGL 2
    if texture.anisotropy > 1 {
      let extension = extensions.get("EXT_texture_filter_anisotropic").unwrap()
      gl.tex_parameterf(
        texture_type,
        extension.constant("TEXTURE_MAX_ANISOTROPY_EXT"),
        @webgl.js_math_min(
          texture.anisotropy.to_double(),
          backend.capabilities.unwrap().get_max_anisotropy().to_double(),
        ),
      )
    }
  }
}

///|
/// `createDefaultTexture( texture )`.
pub fn WebGLTextureUtils::create_default_texture(
  self : WebGLTextureUtils,
  texture : @core.Texture,
) -> Unit {
  let { gl, backend, default_textures, .. } = self
  let gl_texture_type = self.get_gl_texture_type(texture)
  let texture_gpu = match default_textures.get(gl_texture_type) {
    Some(t) => t
    None => {
      let texture_gpu = gl.create_texture()
      backend.state.unwrap().bind_texture(gl_texture_type, Some(texture_gpu))
      gl.tex_parameteri(
        gl_texture_type,
        @webgl.GL_TEXTURE_MIN_FILTER,
        @webgl.GL_NEAREST,
      )
      gl.tex_parameteri(
        gl_texture_type,
        @webgl.GL_TEXTURE_MAG_FILTER,
        @webgl.GL_NEAREST,
      )
      // gl.texImage2D( glTextureType, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, data );
      default_textures.set(gl_texture_type, texture_gpu)
      texture_gpu
    }
  }
  backend.set(
    @core.JsValue::of(texture),
    _tu_record2(
      @core.JsValue::of(texture_gpu),
      @core.JsValue::of(gl_texture_type),
    ),
  )
}

///|
/// `createTexture( texture, options )`.
pub fn WebGLTextureUtils::create_texture(
  self : WebGLTextureUtils,
  texture : @core.Texture,
  options : @nodes.TextureOptions,
) -> Unit {
  let { gl, backend, .. } = self
  let undefined = @core.JsValue::undefined()
  let mut texture_gpu = undefined
  let mut gl_texture_type = 0
  let mut gl_format = undefined
  let mut gl_type = undefined
  let mut gl_internal_format = undefined
  if texture.texture_type is ExternalTexture {
    texture_gpu = match texture.external_source {
      Some(source) => source
      None =>
        match texture.source_texture {
          Some(t) => @core.JsValue::of(t)
          None => @core.JsValue::null()
        }
    }
    gl_texture_type = self.get_gl_texture_type(texture)
  } else {
    let { levels, width, height, depth, .. } = options
    let utils = backend.utils.unwrap()
    let format_opt = utils.convert(
      texture.format,
      color_space=texture.color_space,
    )
    let type_opt = utils.convert(texture.type_)
    // `null` (an unsupported format) takes part in the comparisons as no value.
    let format = format_opt.unwrap_or(0)
    let type_ = type_opt.unwrap_or(0)
    let internal_format = self.get_internal_format(
      texture.internal_format,
      format,
      type_,
      texture.normalized,
      texture.color_space,
      force_linear_transfer=texture.is_video_texture(),
    )
    gl_format = _tu_int_or_null(format_opt)
    gl_type = _tu_int_or_null(type_opt)
    gl_internal_format = @core.JsValue::of(internal_format)
    let gpu = gl.create_texture()
    texture_gpu = @core.JsValue::of(gpu)
    gl_texture_type = self.get_gl_texture_type(texture)
    backend.state.unwrap().bind_texture(gl_texture_type, Some(gpu))
    self.set_texture_parameters(gl_texture_type, texture)
    if _tu_is_any_array(texture) {
      gl.tex_storage3d(
        @webgl.GL_TEXTURE_2D_ARRAY,
        levels,
        internal_format,
        width,
        height,
        depth,
      )
    } else if _tu_is_data3d(texture) {
      gl.tex_storage3d(
        @webgl.GL_TEXTURE_3D,
        levels,
        internal_format,
        width,
        height,
        depth,
      )
    } else if !texture.is_video_texture() {
      gl.tex_storage2d(gl_texture_type, levels, internal_format, width, height)
    }
  }
  backend.set(
    @core.JsValue::of(texture),
    _tu_record5(
      texture_gpu,
      @core.JsValue::of(gl_texture_type),
      gl_format,
      gl_type,
      gl_internal_format,
    ),
  )
}

///|
/// `copyBufferToTexture( buffer, texture )`: uploads a PBO into a texture.
pub fn WebGLTextureUtils::copy_buffer_to_texture(
  self : WebGLTextureUtils,
  buffer : @webgl.GLBuffer?,
  texture : @core.Texture,
) -> Unit {
  let { gl, backend, .. } = self
  let state = backend.state.unwrap()
  let data = backend.get(@core.JsValue::of(texture))
  let texture_gpu : @webgl.GLTexture? = _tu_handle(data.get("textureGPU"))
  let gl_texture_type = _tu_int(data.get("glTextureType"))
  let gl_format = _tu_int(data.get("glFormat"))
  let gl_type = _tu_int(data.get("glType"))
  let image = texture.source.data
  let width = image.width().to_int()
  let height = image.height().to_int()
  gl.bind_buffer(@webgl.GL_PIXEL_UNPACK_BUFFER, buffer)
  backend.state.unwrap().bind_texture(gl_texture_type, texture_gpu)
  state.pixel_storei_bool(@webgl.GL_UNPACK_FLIP_Y_WEBGL, false)
  state.pixel_storei_bool(@webgl.GL_UNPACK_PREMULTIPLY_ALPHA_WEBGL, false)
  gl.tex_sub_image2d(
    gl_texture_type,
    0,
    0,
    0,
    width,
    height,
    gl_format,
    gl_type,
    @core.JsValue::of(0),
  )
  gl.bind_buffer(@webgl.GL_PIXEL_UNPACK_BUFFER, None)
  backend.state.unwrap().unbind_texture()
}

///|
/// `updateTexture( texture, options )`: uploads the texture's data.
pub fn WebGLTextureUtils::update_texture(
  self : WebGLTextureUtils,
  texture : @core.Texture,
  options : @nodes.TextureOptions,
) -> Unit {
  let gl = self.gl
  let { width, height, .. } = options
  let data = self.backend.get(@core.JsValue::of(texture))
  let texture_gpu_js = data.get("textureGPU")
  let gl_texture_type = _tu_int(data.get("glTextureType"))
  let gl_format_js = data.get("glFormat")
  let gl_format = _tu_int(gl_format_js)
  let gl_type = _tu_int(data.get("glType"))
  let gl_internal_format = _tu_int(data.get("glInternalFormat"))
  if texture.is_render_target_texture || texture_gpu_js.is_undefined() {
    // unsupported texture format
    return
  }
  let texture_gpu : @webgl.GLTexture? = _tu_handle(texture_gpu_js)
  self.backend.state.unwrap().bind_texture(gl_texture_type, texture_gpu)
  self.set_texture_parameters(gl_texture_type, texture)
  let gl_format_is_null = gl_format_js.is_null() || gl_format_js.is_undefined()
  let option_image = fn() -> @core.TextureImage {
    match options.image {
      Some(i) => i
      None =>
        abort("TypeError: Cannot read properties of undefined (reading 'data')")
    }
  }
  if texture.texture_type is CompressedCubeTexture {
    for i in 0..<6 {
      let mipmaps = _tu_image_mipmaps(_tu_image_at(texture.image(), i))
      for j, mipmap in mipmaps {
        if gl_format == @webgl.GL_RGBA {
          gl.tex_sub_image2d(
            @webgl.GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
            j,
            0,
            0,
            mipmap.width,
            mipmap.height,
            gl_format,
            gl_type,
            mipmap.data,
          )
        } else if !gl_format_is_null {
          gl.compressed_tex_sub_image2d(
            @webgl.GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
            j,
            0,
            0,
            mipmap.width,
            mipmap.height,
            gl_format,
            mipmap.data,
          )
        } else {
          @core.warn("WebGLBackend: Unsupported compressed texture format")
        }
      }
    }
  } else if texture.is_compressed_texture() {
    let mipmaps = texture.mipmaps
    let is_compressed_format = !gl_format_is_null && gl_format != @webgl.GL_RGBA
    for i, mipmap_image in mipmaps {
      let mipmap = match mipmap_image {
        DataImage(m) => m
        _ => abort("WebGLTextureUtils: compressed mipmap is not a data image")
      }
      let mipmap_data = _tu_data(mipmap.data)
      if texture.texture_type is CompressedArrayTexture {
        let layer_updates = texture.layer_updates.unwrap_or([])
        if is_compressed_format {
          if layer_updates.length() > 0 {
            let layer_byte_length = _tu_get_byte_length(
              mipmap.width,
              mipmap.height,
              texture.format,
              texture.type_,
            )
            let mipmap_typed = mipmap.data.unwrap()
            let bpe = mipmap_typed.bytes_per_element().to_double()
            for layer_index in layer_updates {
              let layer_data = mipmap_typed.subarray(
                start=(layer_index.to_double() * layer_byte_length / bpe).to_int(),
                end=((layer_index + 1).to_double() * layer_byte_length / bpe).to_int(),
              )
              gl.compressed_tex_sub_image3d(
                @webgl.GL_TEXTURE_2D_ARRAY,
                i,
                0,
                0,
                layer_index,
                mipmap.width,
                mipmap.height,
                1,
                gl_format,
                layer_data,
              )
            }
          } else {
            gl.compressed_tex_sub_image3d(
              @webgl.GL_TEXTURE_2D_ARRAY,
              i,
              0,
              0,
              0,
              mipmap.width,
              mipmap.height,
              option_image().depth().to_int(),
              gl_format,
              mipmap_data,
            )
          }
        } else if gl_format == @webgl.GL_RGBA {
          gl.tex_sub_image3d(
            @webgl.GL_TEXTURE_2D_ARRAY,
            i,
            0,
            0,
            0,
            mipmap.width,
            mipmap.height,
            option_image().depth().to_int(),
            gl_format,
            gl_type,
            mipmap_data,
          )
        } else {
          @core.warn("WebGLBackend: Unsupported compressed texture format.")
        }
      } else if is_compressed_format {
        gl.compressed_tex_sub_image2d(
          @webgl.GL_TEXTURE_2D,
          i,
          0,
          0,
          mipmap.width,
          mipmap.height,
          gl_format,
          mipmap_data,
        )
      } else if gl_format == @webgl.GL_RGBA {
        gl.tex_sub_image2d(
          @webgl.GL_TEXTURE_2D,
          i,
          0,
          0,
          mipmap.width,
          mipmap.height,
          gl_format,
          gl_type,
          mipmap_data,
        )
      } else {
        @core.warn("WebGLBackend: Unsupported compressed texture format.")
      }
    }
    if texture.texture_type is CompressedArrayTexture &&
      texture.layer_updates.unwrap_or([]).length() > 0 {
      texture.clear_layer_updates()
    }
  } else if texture.is_cube_texture() {
    let images = match options.images {
      Some(images) => images
      None =>
        abort("TypeError: Cannot read properties of undefined (reading '0')")
    }
    let mipmaps = texture.mipmaps
    for i in 0..<6 {
      let image = _tu_get_image(images[i])
      gl.tex_sub_image2d(
        @webgl.GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
        0,
        0,
        0,
        width,
        height,
        gl_format,
        gl_type,
        image,
      )
      for j, mipmap in mipmaps {
        let face = _tu_image_at(mipmap, i)
        let image = _tu_get_image(face)
        gl.tex_sub_image2d(
          @webgl.GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
          j + 1,
          0,
          0,
          _tu_int(image.get("width")),
          _tu_int(image.get("height")),
          gl_format,
          gl_type,
          image,
        )
      }
    }
  } else if _tu_is_data_array(texture) || texture.is_array_texture {
    let image = option_image()
    let layer_updates = texture.layer_updates.unwrap_or([])
    let image_width = image.width().to_int()
    let image_height = image.height().to_int()
    if layer_updates.length() > 0 {
      let layer_byte_length = _tu_get_byte_length(
        image_width,
        image_height,
        texture.format,
        texture.type_,
      )
      let typed : @core.TypedArray = match image {
        DataImage({ data: Some(d), .. }) => d
        _ => _tu_image_data(image).cast()
      }
      let bpe = typed.bytes_per_element().to_double()
      for layer_index in layer_updates {
        let layer_data = typed.subarray(
          start=(layer_index.to_double() * layer_byte_length / bpe).to_int(),
          end=((layer_index + 1).to_double() * layer_byte_length / bpe).to_int(),
        )
        gl.tex_sub_image3d(
          @webgl.GL_TEXTURE_2D_ARRAY,
          0,
          0,
          0,
          layer_index,
          image_width,
          image_height,
          1,
          gl_format,
          gl_type,
          layer_data,
        )
      }
      texture.clear_layer_updates()
    } else {
      gl.tex_sub_image3d(
        @webgl.GL_TEXTURE_2D_ARRAY,
        0,
        0,
        0,
        0,
        image_width,
        image_height,
        image.depth().to_int(),
        gl_format,
        gl_type,
        _tu_image_data(image),
      )
    }
  } else if _tu_is_data3d(texture) {
    let image = option_image()
    gl.tex_sub_image3d(
      @webgl.GL_TEXTURE_3D,
      0,
      0,
      0,
      0,
      image.width().to_int(),
      image.height().to_int(),
      image.depth().to_int(),
      gl_format,
      gl_type,
      _tu_image_data(image),
    )
  } else if texture.is_video_texture() {
    texture.update()
    gl.tex_image2d_source(
      gl_texture_type,
      0,
      gl_internal_format,
      gl_format,
      gl_type,
      option_image().to_js(),
    )
  } else if texture.texture_type is HTMLTexture {
    if gl.has_tex_element_image2d() {
      if gl.tex_element_image2d_length() == 3 {
        // Chrome 150+
        gl.tex_element_image2d(
          @webgl.GL_TEXTURE_2D,
          @webgl.GL_RGBA8,
          option_image().to_js(),
        )
      } else {
        // Chrome 138 - 149
        gl.tex_element_image2d_full(
          @webgl.GL_TEXTURE_2D,
          0,
          @webgl.GL_RGBA,
          @webgl.GL_RGBA,
          @webgl.GL_UNSIGNED_BYTE,
          option_image().to_js(),
        )
      }
    }
  } else {
    let mipmaps = texture.mipmaps
    if mipmaps.length() > 0 {
      for i, mipmap in mipmaps {
        let image = _tu_get_image(mipmap)
        gl.tex_sub_image2d(
          gl_texture_type,
          i,
          0,
          0,
          mipmap.width().to_int(),
          mipmap.height().to_int(),
          gl_format,
          gl_type,
          image,
        )
      }
    } else {
      let image = _tu_get_image(option_image())
      gl.tex_sub_image2d(
        gl_texture_type, 0, 0, 0, width, height, gl_format, gl_type, image,
      )
    }
  }
}

///|
/// `generateMipmaps( texture )`.
pub fn WebGLTextureUtils::generate_mipmaps(
  self : WebGLTextureUtils,
  texture : @core.Texture,
) -> Unit {
  let { gl, backend, .. } = self
  let data = backend.get(@core.JsValue::of(texture))
  let gl_texture_type = _tu_int(data.get("glTextureType"))
  backend.state
  .unwrap()
  .bind_texture(gl_texture_type, _tu_handle(data.get("textureGPU")))
  gl.generate_mipmap(gl_texture_type)
}

///|
/// `deallocateRenderBuffers( renderTarget )`: deletes a render target's framebuffers
/// and renderbuffers (`None` is a falsy target).
pub fn WebGLTextureUtils::deallocate_render_buffers(
  self : WebGLTextureUtils,
  render_target : @core.RenderTarget?,
) -> Unit {
  let { gl, backend, .. } = self
  // remove framebuffer reference
  match render_target {
    Some(render_target) => {
      let render_context_data = backend.get(@core.JsValue::of(render_target))
      render_context_data.set(
        "renderBufferStorageSetup",
        @core.JsValue::undefined(),
      )
      let framebuffers = render_context_data.get("framebuffers")
      if _tu_truthy(framebuffers) {
        for cache_key in _tu_keys(framebuffers) {
          gl.delete_framebuffer(framebuffers.get(cache_key).cast())
        }
        _tu_delete_key(render_context_data, "framebuffers")
      }
      let depth_renderbuffer = render_context_data.get("depthRenderbuffer")
      if _tu_truthy(depth_renderbuffer) {
        gl.delete_renderbuffer(depth_renderbuffer.cast())
        _tu_delete_key(render_context_data, "depthRenderbuffer")
      }
      let stencil_renderbuffer = render_context_data.get("stencilRenderbuffer")
      if _tu_truthy(stencil_renderbuffer) {
        gl.delete_renderbuffer(stencil_renderbuffer.cast())
        _tu_delete_key(render_context_data, "stencilRenderbuffer")
      }
      let msaa_frame_buffer = render_context_data.get("msaaFrameBuffer")
      if _tu_truthy(msaa_frame_buffer) {
        gl.delete_framebuffer(msaa_frame_buffer.cast())
        _tu_delete_key(render_context_data, "msaaFrameBuffer")
      }
      let msaa_renderbuffers = render_context_data.get("msaaRenderbuffers")
      if _tu_truthy(msaa_renderbuffers) {
        for i in 0..<_tu_length(msaa_renderbuffers) {
          gl.delete_renderbuffer(_tu_index(msaa_renderbuffers, i).cast())
        }
        _tu_delete_key(render_context_data, "msaaRenderbuffers")
      }
    }
    None => ()
  }
}

///|
/// `destroyTexture( texture, isDefaultTexture = false )`.
pub fn WebGLTextureUtils::destroy_texture(
  self : WebGLTextureUtils,
  texture : @core.Texture,
  is_default_texture~ : Bool = false,
) -> Unit {
  let { gl, backend, .. } = self
  let data = backend.get(@core.JsValue::of(texture))
  let texture_gpu = data.get("textureGPU")
  let render_target = data.get("renderTarget")
  self.deallocate_render_buffers(
    if _tu_truthy(render_target) {
      Some(render_target.cast())
    } else {
      None
    },
  )
  if is_default_texture == false && !(texture.texture_type is ExternalTexture) {
    gl.delete_texture(texture_gpu.cast())
  }
  backend.delete(@core.JsValue::of(texture))
}

///|
/// `copyTextureToTexture( srcTexture, dstTexture, srcRegion = null, dstPosition = null,
/// srcLevel = 0, dstLevel = 0 )`.
pub fn WebGLTextureUtils::copy_texture_to_texture(
  self : WebGLTextureUtils,
  src_texture : @core.Texture,
  dst_texture : @core.Texture,
  src_region? : @nodes.TextureCopyRegion,
  dst_position? : @nodes.TextureCopyPosition,
  src_level~ : Int32 = 0,
  dst_level~ : Int32 = 0,
) -> Unit {
  let { gl, backend, .. } = self
  let state = backend.state.unwrap()
  let dst_data = backend.get(@core.JsValue::of(dst_texture))
  let dst_texture_gpu : @webgl.GLTexture? = _tu_handle(
    dst_data.get("textureGPU"),
  )
  let gl_texture_type = _tu_int(dst_data.get("glTextureType"))
  let gl_type = _tu_int(dst_data.get("glType"))
  let gl_format = _tu_int(dst_data.get("glFormat"))
  state.bind_texture(gl_texture_type, dst_texture_gpu)
  // gather the necessary dimensions to copy
  let image = if src_texture.is_compressed_texture() {
    src_texture.mipmaps[dst_level]
  } else {
    src_texture.image()
  }
  let (width, height, depth, min_x, min_y, min_z) = match src_region {
    Some(Box2(region)) =>
      (
        (region.max.x - region.min.x).to_int(),
        (region.max.y - region.min.y).to_int(),
        1,
        region.min.x.to_int(),
        region.min.y.to_int(),
        0,
      )
    Some(Box3(region)) =>
      (
        (region.max.x - region.min.x).to_int(),
        (region.max.y - region.min.y).to_int(),
        (region.max.z - region.min.z).to_int(),
        region.min.x.to_int(),
        region.min.y.to_int(),
        region.min.z.to_int(),
      )
    None => {
      let level_scale = _tu_pow(2.0, -src_level.to_double())
      let width = _tu_floor(image.width() * level_scale).to_int()
      let height = _tu_floor(image.height() * level_scale).to_int()
      let depth = if _tu_is_data_array(src_texture) ||
        src_texture.is_array_texture {
        image.depth().to_int()
      } else if _tu_is_data3d(src_texture) {
        _tu_floor(image.depth() * level_scale).to_int()
      } else {
        1
      }
      (width, height, depth, 0, 0, 0)
    }
  }
  let (dst_x, dst_y, dst_z) = match dst_position {
    // `dstPosition.z` of a Vector2 is `undefined` upstream.
    Some(Vec2(p)) => (p.x.to_int(), p.y.to_int(), 0)
    Some(Vec3(p)) => (p.x.to_int(), p.y.to_int(), p.z.to_int())
    None => (0, 0, 0)
  }
  state.pixel_storei_bool(@webgl.GL_UNPACK_FLIP_Y_WEBGL, dst_texture.flip_y)
  state.pixel_storei_bool(
    @webgl.GL_UNPACK_PREMULTIPLY_ALPHA_WEBGL,
    dst_texture.premultiply_alpha,
  )
  state.pixel_storei(@webgl.GL_UNPACK_ALIGNMENT, dst_texture.unpack_alignment)
  // used for copying data from cpu
  let current_unpack_row_len = state.get_parameter(@webgl.GL_UNPACK_ROW_LENGTH)
  let current_unpack_image_height = state.get_parameter(
    @webgl.GL_UNPACK_IMAGE_HEIGHT,
  )
  let current_unpack_skip_pixels = state.get_parameter(
    @webgl.GL_UNPACK_SKIP_PIXELS,
  )
  let current_unpack_skip_rows = state.get_parameter(@webgl.GL_UNPACK_SKIP_ROWS)
  let current_unpack_skip_images = state.get_parameter(
    @webgl.GL_UNPACK_SKIP_IMAGES,
  )
  state.pixel_storei(@webgl.GL_UNPACK_ROW_LENGTH, image.width().to_int())
  state.pixel_storei(@webgl.GL_UNPACK_IMAGE_HEIGHT, image.height().to_int())
  state.pixel_storei(@webgl.GL_UNPACK_SKIP_PIXELS, min_x)
  state.pixel_storei(@webgl.GL_UNPACK_SKIP_ROWS, min_y)
  state.pixel_storei(@webgl.GL_UNPACK_SKIP_IMAGES, min_z)
  // set up the src texture
  let is_src3d = _tu_is_data_array(src_texture) ||
    _tu_is_data3d(src_texture) ||
    src_texture.is_array_texture
  let is_dst3d = _tu_is_data_array(dst_texture) ||
    _tu_is_data3d(dst_texture) ||
    dst_texture.is_array_texture
  if src_texture.is_depth_texture() {
    let src_texture_data = backend.get(@core.JsValue::of(src_texture))
    let src_gpu : @webgl.GLTexture? = _tu_handle(
      src_texture_data.get("textureGPU"),
    )
    if self._src_framebuffer is None {
      self._src_framebuffer = Some(gl.create_framebuffer())
    }
    if self._dst_framebuffer is None {
      self._dst_framebuffer = Some(gl.create_framebuffer())
    }
    let attachment = if src_texture.format == @core.DepthStencilFormat {
      @webgl.GL_DEPTH_STENCIL_ATTACHMENT
    } else {
      @webgl.GL_DEPTH_ATTACHMENT
    }
    let prev_read_framebuffer = state.current_bound_framebuffers
      .get(@webgl.GL_READ_FRAMEBUFFER)
      .bind(x => x)
    let prev_draw_framebuffer = state.current_bound_framebuffers
      .get(@webgl.GL_DRAW_FRAMEBUFFER)
      .bind(x => x)
    state.bind_framebuffer(@webgl.GL_READ_FRAMEBUFFER, self._src_framebuffer)
    |> ignore
    state.bind_framebuffer(@webgl.GL_DRAW_FRAMEBUFFER, self._dst_framebuffer)
    |> ignore
    // color attachments of previous copies would make the framebuffers incomplete
    gl.framebuffer_texture2d(
      @webgl.GL_READ_FRAMEBUFFER,
      @webgl.GL_COLOR_ATTACHMENT0,
      @webgl.GL_TEXTURE_2D,
      None,
      0,
    )
    gl.framebuffer_texture2d(
      @webgl.GL_DRAW_FRAMEBUFFER,
      @webgl.GL_COLOR_ATTACHMENT0,
      @webgl.GL_TEXTURE_2D,
      None,
      0,
    )
    for i in 0..<depth {
      // if the source or destination are a 3d target then a layer needs to be bound
      if is_src3d {
        gl.framebuffer_texture_layer(
          @webgl.GL_READ_FRAMEBUFFER,
          attachment,
          src_gpu,
          src_level,
          min_z + i,
        )
      } else {
        gl.framebuffer_texture2d(
          @webgl.GL_READ_FRAMEBUFFER,
          attachment,
          @webgl.GL_TEXTURE_2D,
          src_gpu,
          src_level,
        )
      }
      if is_dst3d {
        gl.framebuffer_texture_layer(
          @webgl.GL_DRAW_FRAMEBUFFER,
          attachment,
          dst_texture_gpu,
          dst_level,
          dst_z + i,
        )
      } else {
        gl.framebuffer_texture2d(
          @webgl.GL_DRAW_FRAMEBUFFER,
          attachment,
          @webgl.GL_TEXTURE_2D,
          dst_texture_gpu,
          dst_level,
        )
      }
      gl.blit_framebuffer(
        min_x,
        min_y,
        min_x + width,
        min_y + height,
        dst_x,
        dst_y,
        dst_x + width,
        dst_y + height,
        @webgl.GL_DEPTH_BUFFER_BIT,
        @webgl.GL_NEAREST,
      )
    }
    // detach the depth textures so subsequent color copies can reuse the framebuffers
    gl.framebuffer_texture2d(
      @webgl.GL_READ_FRAMEBUFFER,
      attachment,
      @webgl.GL_TEXTURE_2D,
      None,
      0,
    )
    gl.framebuffer_texture2d(
      @webgl.GL_DRAW_FRAMEBUFFER,
      attachment,
      @webgl.GL_TEXTURE_2D,
      None,
      0,
    )
    state.bind_framebuffer(@webgl.GL_READ_FRAMEBUFFER, prev_read_framebuffer)
    |> ignore
    state.bind_framebuffer(@webgl.GL_DRAW_FRAMEBUFFER, prev_draw_framebuffer)
    |> ignore
  } else if src_level != 0 ||
    src_texture.is_render_target_texture ||
    backend.has(@core.JsValue::of(src_texture)) {
    // get the appropriate frame buffers
    let src_texture_data = backend.get(@core.JsValue::of(src_texture))
    let src_gpu : @webgl.GLTexture? = _tu_handle(
      src_texture_data.get("textureGPU"),
    )
    if self._src_framebuffer is None {
      self._src_framebuffer = Some(gl.create_framebuffer())
    }
    if self._dst_framebuffer is None {
      self._dst_framebuffer = Some(gl.create_framebuffer())
    }
    let prev_read_framebuffer = state.current_bound_framebuffers
      .get(@webgl.GL_READ_FRAMEBUFFER)
      .bind(x => x)
    let prev_draw_framebuffer = state.current_bound_framebuffers
      .get(@webgl.GL_DRAW_FRAMEBUFFER)
      .bind(x => x)
    // bind the frame buffer targets
    state.bind_framebuffer(@webgl.GL_READ_FRAMEBUFFER, self._src_framebuffer)
    |> ignore
    state.bind_framebuffer(@webgl.GL_DRAW_FRAMEBUFFER, self._dst_framebuffer)
    |> ignore
    for i in 0..<depth {
      // assign the correct layers and mip maps to the frame buffers
      if is_src3d {
        gl.framebuffer_texture_layer(
          @webgl.GL_READ_FRAMEBUFFER,
          @webgl.GL_COLOR_ATTACHMENT0,
          src_gpu,
          src_level,
          min_z + i,
        )
      } else {
        gl.framebuffer_texture2d(
          @webgl.GL_READ_FRAMEBUFFER,
          @webgl.GL_COLOR_ATTACHMENT0,
          @webgl.GL_TEXTURE_2D,
          src_gpu,
          src_level,
        )
      }
      if is_dst3d {
        gl.framebuffer_texture_layer(
          @webgl.GL_DRAW_FRAMEBUFFER,
          @webgl.GL_COLOR_ATTACHMENT0,
          dst_texture_gpu,
          dst_level,
          dst_z + i,
        )
      } else {
        gl.framebuffer_texture2d(
          @webgl.GL_DRAW_FRAMEBUFFER,
          @webgl.GL_COLOR_ATTACHMENT0,
          @webgl.GL_TEXTURE_2D,
          dst_texture_gpu,
          dst_level,
        )
      }
      // copy the data using the fastest function that can achieve the copy
      if src_level != 0 {
        gl.blit_framebuffer(
          min_x,
          min_y,
          min_x + width,
          min_y + height,
          dst_x,
          dst_y,
          dst_x + width,
          dst_y + height,
          @webgl.GL_COLOR_BUFFER_BIT,
          @webgl.GL_NEAREST,
        )
      } else if is_dst3d {
        gl.copy_tex_sub_image3d(
          gl_texture_type,
          dst_level,
          dst_x,
          dst_y,
          dst_z + i,
          min_x,
          min_y,
          width,
          height,
        )
      } else {
        gl.copy_tex_sub_image2d(
          gl_texture_type, dst_level, dst_x, dst_y, min_x, min_y, width, height,
        )
      }
    }
    // restore previous read, draw framebuffer bindings
    state.bind_framebuffer(@webgl.GL_READ_FRAMEBUFFER, prev_read_framebuffer)
    |> ignore
    state.bind_framebuffer(@webgl.GL_DRAW_FRAMEBUFFER, prev_draw_framebuffer)
    |> ignore
  } else if is_dst3d {
    // copy data into the 3d texture
    if src_texture.texture_type is (DataTexture | Data3DTexture) {
      gl.tex_sub_image3d(
        gl_texture_type,
        dst_level,
        dst_x,
        dst_y,
        dst_z,
        width,
        height,
        depth,
        gl_format,
        gl_type,
        _tu_image_data(image),
      )
    } else if dst_texture.texture_type is CompressedArrayTexture {
      gl.compressed_tex_sub_image3d(
        gl_texture_type,
        dst_level,
        dst_x,
        dst_y,
        dst_z,
        width,
        height,
        depth,
        gl_format,
        _tu_image_data(image),
      )
    } else {
      gl.tex_sub_image3d(
        gl_texture_type,
        dst_level,
        dst_x,
        dst_y,
        dst_z,
        width,
        height,
        depth,
        gl_format,
        gl_type,
        image.to_js(),
      )
    }
  } else if src_texture.texture_type is DataTexture {
    // copy data into the 2d texture
    gl.tex_sub_image2d(
      @webgl.GL_TEXTURE_2D,
      dst_level,
      dst_x,
      dst_y,
      width,
      height,
      gl_format,
      gl_type,
      _tu_image_data(image),
    )
  } else if src_texture.is_compressed_texture() {
    gl.compressed_tex_sub_image2d(
      @webgl.GL_TEXTURE_2D,
      dst_level,
      dst_x,
      dst_y,
      image.width().to_int(),
      image.height().to_int(),
      gl_format,
      _tu_image_data(image),
    )
  } else {
    gl.tex_sub_image2d(
      @webgl.GL_TEXTURE_2D,
      dst_level,
      dst_x,
      dst_y,
      width,
      height,
      gl_format,
      gl_type,
      image.to_js(),
    )
  }
  // reset values
  state.pixel_storei_js(@webgl.GL_UNPACK_ROW_LENGTH, current_unpack_row_len)
  state.pixel_storei_js(
    @webgl.GL_UNPACK_IMAGE_HEIGHT,
    current_unpack_image_height,
  )
  state.pixel_storei_js(
    @webgl.GL_UNPACK_SKIP_PIXELS,
    current_unpack_skip_pixels,
  )
  state.pixel_storei_js(@webgl.GL_UNPACK_SKIP_ROWS, current_unpack_skip_rows)
  state.pixel_storei_js(
    @webgl.GL_UNPACK_SKIP_IMAGES,
    current_unpack_skip_images,
  )
  // Generate mipmaps only when copying level 0
  if dst_level == 0 &&
    dst_texture.generate_mipmaps == true &&
    dst_texture.mipmaps_auto_update == true {
    gl.generate_mipmap(gl_texture_type)
  }
  state.unbind_texture()
}

///|
/// `renderContext.renderTarget` of a framebuffer source (`null` is a TypeError).
fn _tu_source_render_target(
  source : @nodes.FramebufferSource,
) -> @core.RenderTarget? {
  match source {
    Context(rc) => rc.render_target
    TargetData(data) => data.render_target
    NoContext =>
      abort(
        "TypeError: Cannot read properties of null (reading 'renderTarget')",
      )
  }
}

///|
/// `renderContext.depthTexture` of a framebuffer source.
fn _tu_source_depth_texture(
  source : @nodes.FramebufferSource,
) -> @core.Texture? {
  match source {
    Context(rc) => rc.depth_texture
    TargetData(data) => data.depth_texture
    NoContext =>
      abort(
        "TypeError: Cannot read properties of null (reading 'depthTexture')",
      )
  }
}

///|
/// `copyFramebufferToTexture( texture, renderContext, rectangle )`.
pub fn WebGLTextureUtils::copy_framebuffer_to_texture(
  self : WebGLTextureUtils,
  texture : @core.Texture,
  render_context : @nodes.FramebufferSource,
  rectangle : @math.Vector4,
) -> Unit {
  let gl = self.gl
  let state = self.backend.state.unwrap()
  let texture_gpu : @webgl.GLTexture? = _tu_handle(
    self.backend.get(@core.JsValue::of(texture)).get("textureGPU"),
  )
  let x = rectangle.x.to_int()
  let y = rectangle.y.to_int()
  let width = rectangle.z.to_int()
  let height = rectangle.w.to_int()
  let render_target = _tu_source_render_target(render_context)
  let require_draw_frame_buffer = texture.is_depth_texture() == true ||
    (render_target is Some(rt) && rt.samples > 0)
  let src_height = match render_target {
    Some(rt) => rt.height
    None => self.backend.get_drawing_buffer_size().y.to_int()
  }
  if require_draw_frame_buffer {
    let partial = x != 0 || y != 0
    let mut mask = 0
    let mut attachment = 0
    if texture.is_depth_texture() == true {
      mask = @webgl.GL_DEPTH_BUFFER_BIT
      attachment = @webgl.GL_DEPTH_ATTACHMENT
      let stencil = match render_context {
        Context(rc) => rc.stencil
        TargetData(data) => data.stencil.unwrap_or(false)
        NoContext => false
      }
      if stencil {
        mask = mask | @webgl.GL_STENCIL_BUFFER_BIT
      }
    } else {
      mask = @webgl.GL_COLOR_BUFFER_BIT
      attachment = @webgl.GL_COLOR_ATTACHMENT0
    }
    if partial {
      let render_target_context_data = match render_target {
        Some(rt) => self.backend.get(@core.JsValue::of(rt))
        None => self.backend.get(@core.JsValue::undefined())
      }
      let cache_key = match render_context {
        Context(rc) => rc.get_cache_key()
        _ => abort("TypeError: renderContext.getCacheKey is not a function")
      }
      let fb : @webgl.GLFramebuffer? = _tu_handle(
        _tu_get_number_key(
          render_target_context_data.get("framebuffers"),
          cache_key,
        ),
      )
      let msaa_frame_buffer : @webgl.GLFramebuffer? = _tu_handle(
        render_target_context_data.get("msaaFrameBuffer"),
      )
      state.bind_framebuffer(@webgl.GL_DRAW_FRAMEBUFFER, fb) |> ignore
      state.bind_framebuffer(@webgl.GL_READ_FRAMEBUFFER, msaa_frame_buffer)
      |> ignore
      let flipped_y = src_height - y - height
      gl.blit_framebuffer(
        x,
        flipped_y,
        x + width,
        flipped_y + height,
        x,
        flipped_y,
        x + width,
        flipped_y + height,
        mask,
        @webgl.GL_NEAREST,
      )
      state.bind_framebuffer(@webgl.GL_READ_FRAMEBUFFER, fb) |> ignore
      state.bind_texture(@webgl.GL_TEXTURE_2D, texture_gpu)
      gl.copy_tex_sub_image2d(
        @webgl.GL_TEXTURE_2D,
        0,
        0,
        0,
        x,
        flipped_y,
        width,
        height,
      )
      state.unbind_texture()
    } else {
      let fb = gl.create_framebuffer()
      state.bind_framebuffer(@webgl.GL_DRAW_FRAMEBUFFER, Some(fb)) |> ignore
      gl.framebuffer_texture2d(
        @webgl.GL_DRAW_FRAMEBUFFER,
        attachment,
        @webgl.GL_TEXTURE_2D,
        texture_gpu,
        0,
      )
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
        @webgl.GL_NEAREST,
      )
      gl.delete_framebuffer(fb)
    }
  } else {
    state.bind_texture(@webgl.GL_TEXTURE_2D, texture_gpu)
    gl.copy_tex_sub_image2d(
      @webgl.GL_TEXTURE_2D,
      0,
      0,
      0,
      x,
      src_height - height - y,
      width,
      height,
    )
    state.unbind_texture()
  }
  if texture.generate_mipmaps == true && texture.mipmaps_auto_update == true {
    self.generate_mipmaps(texture)
  }
  self.backend._set_framebuffer(render_context)
}

///|
/// `setupRenderBufferStorage( renderbuffer, renderContext, samples,
/// useMultisampledRTT = false )`: allocates the depth/stencil renderbuffer and attaches
/// it to the bound framebuffer.
pub fn WebGLTextureUtils::setup_render_buffer_storage(
  self : WebGLTextureUtils,
  renderbuffer : @webgl.GLRenderbuffer,
  render_context : @nodes.FramebufferSource,
  samples : Int32,
  use_multisampled_rtt~ : Bool = false,
) -> Unit {
  let gl = self.gl
  let depth_texture = _tu_source_depth_texture(render_context)
  let render_target = match _tu_source_render_target(render_context) {
    Some(rt) => rt
    None =>
      abort(
        "TypeError: Cannot destructure property 'depthBuffer' of 'renderTarget' as it is null.",
      )
  }
  let depth_buffer = render_target.depth_buffer
  let stencil_buffer = render_target.stencil_buffer
  let width = render_target.width
  let height = render_target.height
  gl.bind_renderbuffer(@webgl.GL_RENDERBUFFER, Some(renderbuffer))
  if depth_buffer && !stencil_buffer {
    let mut gl_internal_format = @webgl.GL_DEPTH_COMPONENT24
    if use_multisampled_rtt == true {
      let multisampled_rtt_ext = self.extensions
        .get("WEBGL_multisampled_render_to_texture")
        .unwrap()
      multisampled_rtt_ext.renderbuffer_storage_multisample_ext(
        @webgl.GL_RENDERBUFFER,
        render_target.samples,
        gl_internal_format,
        width,
        height,
      )
    } else if samples > 0 {
      match depth_texture {
        Some(t) if t.is_depth_texture() =>
          if t.type_ == @core.FloatType {
            gl_internal_format = @webgl.GL_DEPTH_COMPONENT32F
          }
        _ => ()
      }
      gl.renderbuffer_storage_multisample(
        @webgl.GL_RENDERBUFFER,
        samples,
        gl_internal_format,
        width,
        height,
      )
    } else {
      gl.renderbuffer_storage(
        @webgl.GL_RENDERBUFFER,
        gl_internal_format,
        width,
        height,
      )
    }
    gl.framebuffer_renderbuffer(
      @webgl.GL_FRAMEBUFFER,
      @webgl.GL_DEPTH_ATTACHMENT,
      @webgl.GL_RENDERBUFFER,
      Some(renderbuffer),
    )
  } else if depth_buffer && stencil_buffer {
    if samples > 0 {
      let mut gl_internal_format = @webgl.GL_DEPTH24_STENCIL8
      match depth_texture {
        Some(t) if t.is_depth_texture() =>
          if t.type_ == @core.FloatType {
            gl_internal_format = @webgl.GL_DEPTH32F_STENCIL8
          }
        _ => ()
      }
      gl.renderbuffer_storage_multisample(
        @webgl.GL_RENDERBUFFER,
        samples,
        gl_internal_format,
        width,
        height,
      )
    } else {
      gl.renderbuffer_storage(
        @webgl.GL_RENDERBUFFER,
        @webgl.GL_DEPTH_STENCIL,
        width,
        height,
      )
    }
    gl.framebuffer_renderbuffer(
      @webgl.GL_FRAMEBUFFER,
      @webgl.GL_DEPTH_STENCIL_ATTACHMENT,
      @webgl.GL_RENDERBUFFER,
      Some(renderbuffer),
    )
  }
  gl.bind_renderbuffer(@webgl.GL_RENDERBUFFER, None)
}

///|
/// `async copyTextureToBuffer( texture, x, y, width, height, faceIndex )`: reads the
/// texture back through a PBO; calls back with the typed array.
pub fn WebGLTextureUtils::copy_texture_to_buffer(
  self : WebGLTextureUtils,
  texture : @core.Texture,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  face_index : Int32,
  on_done : (@core.TypedArray) -> Unit,
) -> Unit {
  let { backend, gl, .. } = self
  let data = self.backend.get(@core.JsValue::of(texture))
  let texture_gpu : @webgl.GLTexture? = _tu_handle(data.get("textureGPU"))
  let gl_format = _tu_int(data.get("glFormat"))
  let gl_type = _tu_int(data.get("glType"))
  let fb = gl.create_framebuffer()
  backend.state.unwrap().bind_framebuffer(@webgl.GL_READ_FRAMEBUFFER, Some(fb))
  |> ignore
  if _tu_is_data3d(texture) ||
    _tu_is_data_array(texture) ||
    texture.is_array_texture {
    gl.framebuffer_texture_layer(
      @webgl.GL_READ_FRAMEBUFFER,
      @webgl.GL_COLOR_ATTACHMENT0,
      texture_gpu,
      0,
      face_index,
    )
  } else {
    let target = if texture.is_cube_texture() {
      @webgl.GL_TEXTURE_CUBE_MAP_POSITIVE_X + face_index
    } else {
      @webgl.GL_TEXTURE_2D
    }
    gl.framebuffer_texture2d(
      @webgl.GL_READ_FRAMEBUFFER,
      @webgl.GL_COLOR_ATTACHMENT0,
      target,
      texture_gpu,
      0,
    )
  }
  let typed_array_type = self._get_typed_array_type(gl_type)
  let bytes_per_texel = self._get_bytes_per_texel(gl_type, gl_format)
  let element_count = width * height
  let byte_length = element_count * bytes_per_texel
  let buffer = gl.create_buffer()
  backend.state.unwrap().pixel_storei(@webgl.GL_PACK_ALIGNMENT, 1)
  gl.bind_buffer(@webgl.GL_PIXEL_PACK_BUFFER, Some(buffer))
  gl.buffer_data_size(
    @webgl.GL_PIXEL_PACK_BUFFER,
    byte_length,
    @webgl.GL_STREAM_READ,
  )
  gl.read_pixels_offset(x, y, width, height, gl_format, gl_type, 0)
  gl.bind_buffer(@webgl.GL_PIXEL_PACK_BUFFER, None)
  backend.utils
  .unwrap()
  ._client_wait_async(fn(_) {
    let dst_buffer = _tu_new_typed_array(
      typed_array_type,
      byte_length.to_double() / _tu_bytes_per_element(typed_array_type),
    )
    gl.bind_buffer(@webgl.GL_PIXEL_PACK_BUFFER, Some(buffer))
    gl.get_buffer_sub_data(@webgl.GL_PIXEL_PACK_BUFFER, 0, dst_buffer)
    gl.bind_buffer(@webgl.GL_PIXEL_PACK_BUFFER, None)
    backend.state.unwrap().bind_framebuffer(@webgl.GL_READ_FRAMEBUFFER, None)
    |> ignore
    gl.delete_buffer(buffer)
    gl.delete_framebuffer(fb)
    on_done(dst_buffer)
  })
}

///|
/// `_getTypedArrayType( glType )`: the name of the typed array class.
pub fn WebGLTextureUtils::_get_typed_array_type(
  self : WebGLTextureUtils,
  gl_type : Int32,
) -> String {
  ignore(self)
  if gl_type == @webgl.GL_UNSIGNED_BYTE {
    return "Uint8Array"
  }
  if gl_type == @webgl.GL_BYTE {
    return "Int8Array"
  }
  if gl_type == @webgl.GL_UNSIGNED_SHORT_4_4_4_4 {
    return "Uint16Array"
  }
  if gl_type == @webgl.GL_UNSIGNED_SHORT_5_5_5_1 {
    return "Uint16Array"
  }
  if gl_type == @webgl.GL_UNSIGNED_SHORT_5_6_5 {
    return "Uint16Array"
  }
  if gl_type == @webgl.GL_UNSIGNED_SHORT {
    return "Uint16Array"
  }
  if gl_type == @webgl.GL_SHORT {
    return "Int16Array"
  }
  if gl_type == @webgl.GL_UNSIGNED_INT {
    return "Uint32Array"
  }
  if gl_type == @webgl.GL_INT {
    return "Int32Array"
  }
  if gl_type == @webgl.GL_UNSIGNED_INT_5_9_9_9_REV {
    return "Uint32Array"
  }
  if gl_type == @webgl.GL_UNSIGNED_INT_10F_11F_11F_REV {
    return "Uint32Array"
  }
  if gl_type == @webgl.GL_HALF_FLOAT {
    return "Uint16Array"
  }
  if gl_type == @webgl.GL_FLOAT {
    return "Float32Array"
  }
  abort("THREE.WebGLTextureUtils: Unsupported WebGL type: \{gl_type}")
}

///|
/// `_getBytesPerTexel( glType, glFormat )` (0 where upstream returns `undefined`).
pub fn WebGLTextureUtils::_get_bytes_per_texel(
  self : WebGLTextureUtils,
  gl_type : Int32,
  gl_format : Int32,
) -> Int32 {
  ignore(self)
  // packed types store all components of a texel in a single value
  if gl_type == @webgl.GL_UNSIGNED_SHORT_4_4_4_4 ||
    gl_type == @webgl.GL_UNSIGNED_SHORT_5_5_5_1 ||
    gl_type == @webgl.GL_UNSIGNED_SHORT_5_6_5 {
    return 2
  }
  if gl_type == @webgl.GL_UNSIGNED_INT_5_9_9_9_REV ||
    gl_type == @webgl.GL_UNSIGNED_INT_10F_11F_11F_REV {
    return 4
  }
  let mut bytes_per_component = 0
  if gl_type == @webgl.GL_UNSIGNED_BYTE || gl_type == @webgl.GL_BYTE {
    bytes_per_component = 1
  }
  if gl_type == @webgl.GL_UNSIGNED_SHORT ||
    gl_type == @webgl.GL_SHORT ||
    gl_type == @webgl.GL_HALF_FLOAT {
    bytes_per_component = 2
  }
  if gl_type == @webgl.GL_UNSIGNED_INT ||
    gl_type == @webgl.GL_INT ||
    gl_type == @webgl.GL_FLOAT {
    bytes_per_component = 4
  }
  if gl_format == @webgl.GL_RGBA || gl_format == @webgl.GL_RGBA_INTEGER {
    return bytes_per_component * 4
  }
  if gl_format == @webgl.GL_RGB {
    return bytes_per_component * 3
  }
  if gl_format == @webgl.GL_RG || gl_format == @webgl.GL_RG_INTEGER {
    return bytes_per_component * 2
  }
  if gl_format == @webgl.GL_RED ||
    gl_format == @webgl.GL_RED_INTEGER ||
    gl_format == @webgl.GL_ALPHA {
    return bytes_per_component
  }
  0
}

///|
/// `dispose()`: deletes the scratch framebuffers.
pub fn WebGLTextureUtils::dispose(self : WebGLTextureUtils) -> Unit {
  let gl = self.gl
  match self._src_framebuffer {
    Some(fb) => gl.delete_framebuffer(fb)
    None => ()
  }
  match self._dst_framebuffer {
    Some(fb) => gl.delete_framebuffer(fb)
    None => ()
  }
}
