// Upstream src/textures/CompressedArrayTexture.js. `addLayerUpdate` and
// `clearLayerUpdates` are in data_array_texture.mbt, `copy` in texture.mbt.

///|
#external
pub type CompressedArrayTexture

///|
/// Upstream's undefined `width`, `height` and `depth` are 0 here.
pub fn CompressedArrayTexture::new(
  mipmaps? : Array[TextureImage],
  width~ : Int32 = 0,
  height~ : Int32 = 0,
  depth~ : Int32 = 0,
  format? : Int32,
  type_? : Int32,
) -> Texture {
  let texture = CompressedTexture::new(
    mipmaps?,
    width~,
    height~,
    format?,
    type_?,
  )
  texture.texture_type = CompressedArrayTexture
  texture.set_image(DataImage(DataImage::new(width~, height~, depth~)))
  texture.wrap_r = ClampToEdgeWrapping
  texture.layer_updates = Some([])
  texture
}
