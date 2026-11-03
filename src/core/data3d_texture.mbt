// Upstream src/textures/Data3DTexture.js. `copy` is in texture.mbt.

///|
#external
pub type Data3DTexture

///|
pub fn Data3DTexture::new(
  data? : TypedArray,
  width~ : Int32 = 1,
  height~ : Int32 = 1,
  depth~ : Int32 = 1,
) -> Texture {
  let texture = Texture::new(image=NoImage)
  texture.texture_type = Data3DTexture
  texture.set_image(DataImage(DataImage::new(data?, width~, height~, depth~)))
  texture.mag_filter = NearestFilter
  texture.min_filter = NearestFilter
  texture.wrap_r = ClampToEdgeWrapping
  texture.generate_mipmaps = false
  texture.flip_y = false
  texture.unpack_alignment = 1
  texture
}
