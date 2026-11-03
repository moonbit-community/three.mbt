// renderers/common/CubeRenderTarget.js: a render target whose texture is a cube map.
// `CubeRenderTarget::new` returns a core `RenderTarget` with a
// `CubeRenderTargetExtension` (`has_extension_flag("isCubeRenderTarget")`).

///|
/// Marker for `CubeRenderTarget`; `CubeRenderTarget::new` returns a core `RenderTarget`.
pub(all) struct CubeRenderTarget {
  mut _placeholder : Unit
}

///|
/// The extension of a `CubeRenderTarget`.
pub(all) struct CubeRenderTargetExtension {}

///|
pub impl @core.RenderTargetExtension for CubeRenderTargetExtension with fn construct(
  _,
) {
  CubeRenderTarget::new()
}

///|
pub impl @core.RenderTargetExtension for CubeRenderTargetExtension with fn has_flag(
  _,
  flag,
) {
  flag == "isCubeRenderTarget"
}

///|
/// `new CubeRenderTarget( size = 1, options = {} )`.
pub fn CubeRenderTarget::new(
  size~ : Int32 = 1,
  options? : RenderTargetOptions,
) -> @core.RenderTarget {
  let options = match options {
    Some(o) => o
    None => RenderTargetOptions::new()
  }
  let target = @core.RenderTarget::new(
    width=size,
    height=size,
    type_?=options.type_,
    format?=options.format,
    depth_buffer?=options.depth_buffer,
    stencil_buffer?=options.stencil_buffer,
    samples?=options.samples,
    depth_texture?=options.depth_texture,
    min_filter?=options.min_filter,
    mag_filter?=options.mag_filter,
    generate_mipmaps?=options.generate_mipmaps,
    color_space?=options.color_space,
    count?=options.count,
    depth?=options.depth,
  )
  target.set_extension(CubeRenderTargetExtension::{ }) |> ignore
  // upstream shares one { width, height, depth } object between the six faces
  let image = @core.TextureImage::DataImage(
    @core.DataImage::new(width=size, height=size, depth=1),
  )
  target.set_texture(
    @core.CubeTexture::new(images=[image, image, image, image, image, image]),
  )
  target._set_texture_options(
    mag_filter?=options.mag_filter,
    min_filter?=options.min_filter,
    format?=options.format,
    type_?=options.type_,
    color_space?=options.color_space,
    generate_mipmaps?=options.generate_mipmaps,
  )
  // the flip of px and nx is not required for render target cube textures
  target.texture().is_render_target_texture = true
  target
}

///|
/// `fromEquirectangularTexture( renderer, texture )`: renders the equirectangular
/// texture into the six faces.
pub fn CubeRenderTarget::from_equirectangular_texture(
  target : @core.RenderTarget,
  renderer : Renderer,
  tex : @core.Texture,
) -> @core.RenderTarget {
  let current_min_filter = tex.min_filter
  let current_generate_mipmaps = tex.generate_mipmaps
  tex.generate_mipmaps = true
  let cube_texture = target.texture()
  cube_texture.type_ = tex.type_
  cube_texture.color_space = tex.color_space
  cube_texture.generate_mipmaps = tex.generate_mipmaps
  cube_texture.min_filter = tex.min_filter
  cube_texture.mag_filter = tex.mag_filter
  let geometry = @geometries.BoxGeometry::new(width=5.0, height=5.0, depth=5.0)
  let uv_node = equirect_uv.call([position_world_direction])
  let material = NodeMaterial::new()
  NodeMaterial::of(material).unwrap().color_node = Some(
    texture(tex, uv_node~, level_node=0),
  )
  material.side = @core.BackSide
  material.blending = @core.NoBlending
  let mesh = @core.Mesh::new(geometry~, material=Single(material))
  let scene = @core.Scene::new()
  scene.add(mesh) |> ignore
  // Avoid blurred poles
  if tex.min_filter == @core.LinearMipmapLinearFilter {
    tex.min_filter = @core.LinearFilter
  }
  let camera = @core.CubeCamera::new(near=1.0, far=10.0, render_target=target)
  let current_mrt = renderer.get_mrt()
  renderer.set_mrt(None) |> ignore
  camera.update_cube_camera(renderer, scene)
  renderer.set_mrt(current_mrt) |> ignore
  tex.min_filter = current_min_filter
  tex.generate_mipmaps = current_generate_mipmaps
  geometry.dispose()
  material.dispose()
  target
}

///|
/// `clear( renderer, color = true, depth = true, stencil = true )`: clears the six faces.
pub fn CubeRenderTarget::clear(
  target : @core.RenderTarget,
  renderer : Renderer,
  color~ : Bool = true,
  depth~ : Bool = true,
  stencil~ : Bool = true,
) -> Unit {
  let current_render_target = renderer.get_render_target()
  for i in 0..<6 {
    renderer.set_render_target(Some(target), active_cube_face=i)
    renderer.clear(color~, depth~, stencil~)
  }
  renderer.set_render_target(current_render_target)
}
