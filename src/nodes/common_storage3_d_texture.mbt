// renderers/common/Storage3DTexture.js: a core `Texture` with a `TextureExtension`.

///|
/// The extension of a `Storage3DTexture`.
pub(all) struct Storage3DTexture {}

///|
pub impl @core.TextureExtension for Storage3DTexture with fn type_name(_) {
  "Storage3DTexture"
}

///|
pub impl @core.TextureExtension for Storage3DTexture with fn construct(_) {
  Storage3DTexture::new()
}

///|
pub impl @core.TextureExtension for Storage3DTexture with fn has_flag(_, flag) {
  flag == "isStorageTexture" || flag == "is3DTexture"
}

///|
pub impl @core.TextureExtension for Storage3DTexture with fn copy_from(
  _,
  target,
  source,
) {
  target.wrap_r = source.wrap_r
}

///|
/// `new Storage3DTexture( width = 1, height = 1, depth = 1 )`.
pub fn Storage3DTexture::new(
  width~ : Int32 = 1,
  height~ : Int32 = 1,
  depth~ : Int32 = 1,
) -> @core.Texture {
  let texture = @core.Texture::new()
  texture.is_array_texture = false
  texture.set_image(
    DataImage({ data: None, width, height, depth: Some(depth), mipmaps: None, }),
  )
  texture.mag_filter = @core.LinearFilter
  texture.min_filter = @core.LinearFilter
  texture.wrap_r = @core.ClampToEdgeWrapping
  texture.mipmaps_auto_update = false
  texture.set_extension(Storage3DTexture::{ })
}

///|
/// `setSize( width, height, depth )`: resizes the image and disposes on change.
pub fn Storage3DTexture::set_size(
  texture : @core.Texture,
  width : Int32,
  height : Int32,
  depth : Int32,
) -> Unit {
  _storage_array_texture_set_size3(texture, width, height, depth)
}
