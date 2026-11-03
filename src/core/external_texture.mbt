// Upstream src/textures/ExternalTexture.js. `copy` is in texture.mbt.

///|
#external
pub type ExternalTexture

///|
/// `sourceTexture` is a `Texture` in `source_texture` or a GPU handle in
/// `external_source`.
pub fn ExternalTexture::new(
  source_texture? : Texture,
  external_source? : JsValue,
) -> Texture {
  let texture = Texture::new()
  texture.texture_type = ExternalTexture
  texture.source_texture = source_texture
  texture.external_source = external_source
  texture
}
