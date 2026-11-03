// Upstream src/core/RenderTarget3D.js.

///|
#external
pub type RenderTarget3D

///|
/// Takes the options of `RenderTarget::new`; `depth` is its own argument, as upstream.
pub fn RenderTarget3D::new(
  width~ : Int32 = 1,
  height~ : Int32 = 1,
  depth~ : Int32 = 1,
  generate_mipmaps? : Bool,
  internal_format? : String,
  min_filter? : Int32,
  depth_buffer? : Bool,
  stencil_buffer? : Bool,
  resolve_color_buffer? : Bool,
  resolve_depth_buffer? : Bool,
  resolve_stencil_buffer? : Bool,
  store_multisampled_color_buffer? : Bool,
  store_multisampled_depth_buffer? : Bool,
  store_multisampled_stencil_buffer? : Bool,
  depth_texture? : Texture,
  samples? : Int32,
  count? : Int32,
  multiview? : Bool,
  use_array_depth_texture? : Bool,
  mapping? : Int32,
  wrap_s? : Int32,
  wrap_t? : Int32,
  wrap_r? : Int32,
  mag_filter? : Int32,
  format? : Int32,
  type_? : Int32,
  anisotropy? : Int32,
  color_space? : String,
  flip_y? : Bool,
  mipmaps_auto_update? : Bool,
) -> RenderTarget {
  let target = RenderTarget::new(
    width~,
    height~,
    generate_mipmaps?,
    internal_format?,
    min_filter?,
    depth_buffer?,
    stencil_buffer?,
    resolve_color_buffer?,
    resolve_depth_buffer?,
    resolve_stencil_buffer?,
    store_multisampled_color_buffer?,
    store_multisampled_depth_buffer?,
    store_multisampled_stencil_buffer?,
    depth_texture?,
    samples?,
    count?,
    multiview?,
    use_array_depth_texture?,
    mapping?,
    wrap_s?,
    wrap_t?,
    wrap_r?,
    mag_filter?,
    format?,
    type_?,
    anisotropy?,
    color_space?,
    flip_y?,
    mipmaps_auto_update?,
  )
  target.render_target_type = RenderTarget3D
  target.depth = depth
  // overwrite attachments with 3D textures
  for i in 0..<target.textures.length() {
    let texture = Data3DTexture::new(width~, height~, depth~)
    texture.is_render_target_texture = true
    texture.render_target = Some(target)
    target.textures[i] = texture
  }
  target._set_texture_options(
    mapping?,
    wrap_s?,
    wrap_t?,
    wrap_r?,
    mag_filter?,
    min_filter?,
    format?,
    type_?,
    anisotropy?,
    color_space?,
    flip_y?,
    generate_mipmaps?,
    mipmaps_auto_update?,
    internal_format?,
  )
  target
}
