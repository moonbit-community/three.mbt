// Upstream src/extras/TextureUtils.js.

///|
extern "js" fn texture_utils_dom_aspect(image : @core.JsValue) -> Double =
  #|(image) => ( image && image.width ) ? image.width / image.height : 1

///|
/// `( texture.image && texture.image.width ) ? width / height : 1`.
fn texture_utils_image_aspect(texture : @core.Texture) -> Double {
  match texture.image() {
    DomImage(image) => texture_utils_dom_aspect(image)
    DataImage({ width, height, .. }) if width != 0 =>
      width.to_double() / height.to_double()
    TextureImage(image) if image.width() != 0.0 =>
      image.width() / image.height()
    _ => 1.0
  }
}

///|
/// Scales the texture as large as possible within its surface without cropping
/// or stretching the texture. Akin to CSS `object-fit: contain`.
pub fn contain(texture : @core.Texture, aspect : Double) -> @core.Texture {
  let image_aspect = texture_utils_image_aspect(texture)
  if image_aspect > aspect {
    texture.repeat.x = 1.0
    texture.repeat.y = image_aspect / aspect
    texture.offset.x = 0.0
    texture.offset.y = (1.0 - texture.repeat.y) / 2.0
  } else {
    texture.repeat.x = aspect / image_aspect
    texture.repeat.y = 1.0
    texture.offset.x = (1.0 - texture.repeat.x) / 2.0
    texture.offset.y = 0.0
  }
  texture
}

///|
/// Scales the texture to the smallest possible size to fill the surface, leaving
/// no empty space. Akin to CSS `object-fit: cover`.
pub fn cover(texture : @core.Texture, aspect : Double) -> @core.Texture {
  let image_aspect = texture_utils_image_aspect(texture)
  if image_aspect > aspect {
    texture.repeat.x = aspect / image_aspect
    texture.repeat.y = 1.0
    texture.offset.x = (1.0 - texture.repeat.x) / 2.0
    texture.offset.y = 0.0
  } else {
    texture.repeat.x = 1.0
    texture.repeat.y = image_aspect / aspect
    texture.offset.x = 0.0
    texture.offset.y = (1.0 - texture.repeat.y) / 2.0
  }
  texture
}

///|
/// Configures the texture to the default transformation. Akin to CSS `object-fit: fill`.
pub fn fill(texture : @core.Texture) -> @core.Texture {
  texture.repeat.x = 1.0
  texture.repeat.y = 1.0
  texture.offset.x = 0.0
  texture.offset.y = 0.0
  texture
}

///|
extern "js" fn texture_utils_ceil(x : Double) -> Double = "Math.ceil"

///|
extern "js" fn texture_utils_max(a : Double, b : Double) -> Double = "Math.max"

///|
/// Upstream `getTextureTypeByteLength`: `(byteLength, components)`.
fn texture_utils_type_byte_length(type_ : Int32) -> (Double, Double) {
  match type_ {
    @core.UnsignedByteType | @core.ByteType => (1.0, 1.0)
    @core.UnsignedShortType | @core.ShortType | @core.HalfFloatType =>
      (2.0, 1.0)
    @core.UnsignedShort4444Type | @core.UnsignedShort5551Type => (2.0, 4.0)
    @core.UnsignedIntType | @core.IntType | @core.FloatType => (4.0, 1.0)
    @core.UnsignedInt5999Type | @core.UnsignedInt101111Type => (4.0, 3.0)
    _ => abort("THREE.TextureUtils: Unknown texture type \{type_}.")
  }
}

///|
/// Determines how many bytes must be used to represent the texture. The result is not
/// always whole: a packed type with fewer channels than components gives a fraction.
pub fn get_byte_length(
  width : Int32,
  height : Int32,
  format : Int32,
  type_ : Int32,
) -> Double {
  let (byte_length, components) = texture_utils_type_byte_length(type_)
  let w = width.to_double()
  let h = height.to_double()
  // Math.floor( ( width + n - 1 ) / n ) * Math.floor( ( height + m - 1 ) / m ) * bytes
  let blocks = (n : Double, m : Double, bytes : Double) => {
    curve_math_floor((w + n - 1.0) / n) *
    curve_math_floor((h + m - 1.0) / m) *
    bytes
  }
  match format {
    // https://registry.khronos.org/OpenGL-Refpages/es3.0/html/glTexImage2D.xhtml
    @core.AlphaFormat => w * h
    @core.RedFormat | @core.RedIntegerFormat => w * h / components * byte_length
    @core.RGFormat | @core.RGIntegerFormat =>
      w * h * 2.0 / components * byte_length
    @core.RGBFormat => w * h * 3.0 / components * byte_length
    @core.RGBAFormat | @core.RGBAIntegerFormat =>
      w * h * 4.0 / components * byte_length

    // https://registry.khronos.org/webgl/extensions/WEBGL_compressed_texture_s3tc_srgb/
    @core.RGB_S3TC_DXT1_Format | @core.RGBA_S3TC_DXT1_Format =>
      blocks(4.0, 4.0, 8.0)
    @core.RGBA_S3TC_DXT3_Format | @core.RGBA_S3TC_DXT5_Format =>
      blocks(4.0, 4.0, 16.0)

    // https://registry.khronos.org/webgl/extensions/WEBGL_compressed_texture_pvrtc/
    @core.RGB_PVRTC_2BPPV1_Format | @core.RGBA_PVRTC_2BPPV1_Format =>
      texture_utils_max(w, 16.0) * texture_utils_max(h, 8.0) / 4.0
    @core.RGB_PVRTC_4BPPV1_Format | @core.RGBA_PVRTC_4BPPV1_Format =>
      texture_utils_max(w, 8.0) * texture_utils_max(h, 8.0) / 2.0

    // https://registry.khronos.org/webgl/extensions/WEBGL_compressed_texture_etc/
    @core.RGB_ETC1_Format
    | @core.RGB_ETC2_Format
    | @core.R11_EAC_Format
    | @core.SIGNED_R11_EAC_Format => blocks(4.0, 4.0, 8.0)
    @core.RGBA_ETC2_EAC_Format
    | @core.RG11_EAC_Format
    | @core.SIGNED_RG11_EAC_Format => blocks(4.0, 4.0, 16.0)

    // https://registry.khronos.org/webgl/extensions/WEBGL_compressed_texture_astc/
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

    // https://registry.khronos.org/webgl/extensions/EXT_texture_compression_bptc/
    @core.RGBA_BPTC_Format
    | @core.RGB_BPTC_SIGNED_Format
    | @core.RGB_BPTC_UNSIGNED_Format =>
      texture_utils_ceil(w / 4.0) * texture_utils_ceil(h / 4.0) * 16.0

    // https://registry.khronos.org/webgl/extensions/EXT_texture_compression_rgtc/
    @core.RED_RGTC1_Format | @core.SIGNED_RED_RGTC1_Format =>
      texture_utils_ceil(w / 4.0) * texture_utils_ceil(h / 4.0) * 8.0
    @core.RED_GREEN_RGTC2_Format | @core.SIGNED_RED_GREEN_RGTC2_Format =>
      texture_utils_ceil(w / 4.0) * texture_utils_ceil(h / 4.0) * 16.0
    _ => abort("Unable to determine texture byte length for \{format} format.")
  }
}

///|
#external
pub type TextureUtils

///|
pub fn TextureUtils::contain(
  texture : @core.Texture,
  aspect : Double,
) -> @core.Texture {
  contain(texture, aspect)
}

///|
pub fn TextureUtils::cover(
  texture : @core.Texture,
  aspect : Double,
) -> @core.Texture {
  cover(texture, aspect)
}

///|
pub fn TextureUtils::fill(texture : @core.Texture) -> @core.Texture {
  fill(texture)
}

///|
pub fn TextureUtils::get_byte_length(
  width : Int32,
  height : Int32,
  format : Int32,
  type_ : Int32,
) -> Double {
  get_byte_length(width, height, format, type_)
}
