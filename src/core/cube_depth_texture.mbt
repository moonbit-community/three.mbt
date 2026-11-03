// Upstream src/textures/CubeDepthTexture.js. `images` is in cube_texture.mbt.

///|
#external
pub type CubeDepthTexture

///|
/// Upstream's undefined `size` is 0 here.
pub fn CubeDepthTexture::new(
  size~ : Int32 = 0,
  type_~ : Int32 = UnsignedIntType,
  mapping~ : Int32 = CubeReflectionMapping,
  wrap_s? : Int32,
  wrap_t? : Int32,
  mag_filter~ : Int32 = NearestFilter,
  min_filter~ : Int32 = NearestFilter,
  anisotropy? : Int32,
  format~ : Int32 = DepthFormat,
) -> Texture {
  // Create 6 identical image descriptors for the cube faces
  let image = TextureImage::DataImage(
    DataImage::new(width=size, height=size, depth=1),
  )
  let images = [image, image, image, image, image, image]
  // Call DepthTexture constructor with width, height
  let texture = DepthTexture::new(
    width=size,
    height=size,
    type_~,
    mapping~,
    wrap_s?,
    wrap_t?,
    mag_filter~,
    min_filter~,
    anisotropy?,
    format~,
  )
  // Replace the single image with the array of 6 images
  texture.set_image(ImageArray(images))
  texture.texture_type = CubeDepthTexture
  texture
}
