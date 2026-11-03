// Upstream src/textures/DataArrayTexture.js, including the layer update methods it
// shares with CompressedArrayTexture. `copy` is in texture.mbt.

///|
#external
pub type DataArrayTexture

///|
pub fn DataArrayTexture::new(
  data? : TypedArray,
  width~ : Int32 = 1,
  height~ : Int32 = 1,
  depth~ : Int32 = 1,
) -> Texture {
  let texture = Texture::new(image=NoImage)
  texture.texture_type = DataArrayTexture
  texture.set_image(DataImage(DataImage::new(data?, width~, height~, depth~)))
  texture.mag_filter = NearestFilter
  texture.min_filter = NearestFilter
  texture.wrap_r = ClampToEdgeWrapping
  texture.generate_mipmaps = false
  texture.flip_y = false
  texture.unpack_alignment = 1
  texture.layer_updates = Some([])
  texture
}

///|
/// Upstream's `layerUpdates` is a `Set`: repeated indices are stored once.
pub fn Texture::add_layer_update(self : Texture, layer_index : Int32) -> Unit {
  guard self.layer_updates is Some(layer_updates) else {
    abort("Texture::add_layer_update: not an array texture")
  }
  if !layer_updates.contains(layer_index) {
    layer_updates.push(layer_index)
  }
}

///|
pub fn Texture::clear_layer_updates(self : Texture) -> Unit {
  guard self.layer_updates is Some(layer_updates) else {
    abort("Texture::clear_layer_updates: not an array texture")
  }
  layer_updates.clear()
}
