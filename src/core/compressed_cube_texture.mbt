// Upstream src/textures/CompressedCubeTexture.js.

///|
#external
pub type CompressedCubeTexture

///|
pub fn CompressedCubeTexture::new(
  images : Array[TextureImage],
  format? : Int32,
  type_? : Int32,
) -> Texture {
  let texture = CompressedTexture::new(
    width=images[0].width().to_int(),
    height=images[0].height().to_int(),
    format?,
    type_?,
    mapping=CubeReflectionMapping,
  )
  texture.texture_type = CompressedCubeTexture
  texture.set_image(ImageArray(images))
  texture
}
