// renderers/common/StorageTexture.js: a core `Texture` with a `TextureExtension`.

///|
/// The extension of a `StorageTexture`.
pub(all) struct StorageTexture {}

///|
pub impl @core.TextureExtension for StorageTexture with fn type_name(_) {
  "StorageTexture"
}

///|
pub impl @core.TextureExtension for StorageTexture with fn construct(_) {
  StorageTexture::new()
}

///|
pub impl @core.TextureExtension for StorageTexture with fn has_flag(_, flag) {
  flag == "isStorageTexture"
}

///|
/// `new StorageTexture( width = 1, height = 1 )`.
pub fn StorageTexture::new(
  width~ : Int32 = 1,
  height~ : Int32 = 1,
) -> @core.Texture {
  let texture = @core.Texture::new()
  texture.set_image(
    DataImage({ data: None, width, height, depth: None, mipmaps: None, }),
  )
  texture.mag_filter = @core.LinearFilter
  texture.min_filter = @core.LinearFilter
  texture.set_extension(StorageTexture::{ })
}

///|
/// `texture.isStorageTexture`, for any of the storage texture classes.
pub fn is_storage_texture(texture : @core.Texture) -> Bool {
  texture.has_extension_flag("isStorageTexture")
}

///|
/// `setSize( width, height )`: resizes the image and disposes the texture on change.
pub fn StorageTexture::set_size(
  texture : @core.Texture,
  width : Int32,
  height : Int32,
) -> Unit {
  match texture.image() {
    DataImage(image) =>
      if image.width != width || image.height != height {
        image.width = width
        image.height = height
        texture.dispose()
      }
    _ =>
      abort("StorageTexture::set_size: image is not a { width, height } object")
  }
}
