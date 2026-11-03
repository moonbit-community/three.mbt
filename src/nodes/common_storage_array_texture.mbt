// renderers/common/StorageArrayTexture.js: a core `Texture` with a `TextureExtension`.

///|
/// The extension of a `StorageArrayTexture`.
pub(all) struct StorageArrayTexture {}

///|
pub impl @core.TextureExtension for StorageArrayTexture with fn type_name(_) {
  "StorageArrayTexture"
}

///|
pub impl @core.TextureExtension for StorageArrayTexture with fn construct(_) {
  StorageArrayTexture::new()
}

///|
pub impl @core.TextureExtension for StorageArrayTexture with fn has_flag(
  _,
  flag,
) {
  flag == "isStorageTexture"
}

///|
/// `new StorageArrayTexture( width = 1, height = 1, depth = 1 )`.
pub fn StorageArrayTexture::new(
  width~ : Int32 = 1,
  height~ : Int32 = 1,
  depth~ : Int32 = 1,
) -> @core.Texture {
  let texture = @core.Texture::new()
  texture.is_array_texture = true
  texture.set_image(
    DataImage({ data: None, width, height, depth: Some(depth), mipmaps: None, }),
  )
  texture.mag_filter = @core.LinearFilter
  texture.min_filter = @core.LinearFilter
  texture.mipmaps_auto_update = false
  texture.set_extension(StorageArrayTexture::{ })
}

///|
/// `setSize( width, height, depth )`: resizes the image and disposes on change.
pub fn StorageArrayTexture::set_size(
  texture : @core.Texture,
  width : Int32,
  height : Int32,
  depth : Int32,
) -> Unit {
  _storage_array_texture_set_size3(texture, width, height, depth)
}

///|
fn _storage_array_texture_set_size3(
  texture : @core.Texture,
  width : Int32,
  height : Int32,
  depth : Int32,
) -> Unit {
  match texture.image() {
    DataImage(image) =>
      if image.width != width ||
        image.height != height ||
        image.depth != Some(depth) {
        image.width = width
        image.height = height
        image.depth = Some(depth)
        texture.dispose()
      }
    _ => abort("set_size: image is not a { width, height, depth } object")
  }
}
