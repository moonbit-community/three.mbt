// Upstream src/renderers/WebGLRenderTarget.js, WebGL3DRenderTarget.js,
// WebGLArrayRenderTarget.js and WebGLCubeRenderTarget.js. GROUP 4.
//
// Subclasses of core `RenderTarget` through its `extension` hook: constructors return the
// core struct with a `WebGLRenderTargetExtension` attached, which answers
// `has_flag("isWebGLRenderTarget")` (and `isWebGL3DRenderTarget`, ...) and rebuilds the
// right kind in `clone`. The constructors are foundation code; group 4 fills the
// `WebGLCubeRenderTarget` methods. Options are upstream's `options` object as labelled
// arguments, as in `RenderTarget::new`.

///|
/// Marker for `WebGLRenderTarget::new`; values are core `RenderTarget`s.
#external
pub type WebGLRenderTarget

///|
/// Marker for `WebGL3DRenderTarget::new`.
#external
pub type WebGL3DRenderTarget

///|
/// Marker for `WebGLArrayRenderTarget::new`.
#external
pub type WebGLArrayRenderTarget

///|
/// Marker for `WebGLCubeRenderTarget::new` and its methods, which take the core
/// `RenderTarget` as `self`.
#external
pub type WebGLCubeRenderTarget

///|
#derive(Eq)
pub(all) enum WebGLRenderTargetKind {
  WebGLRenderTarget
  WebGL3DRenderTarget
  WebGLArrayRenderTarget
  WebGLCubeRenderTarget
}

///|
pub extend WebGLRenderTargetKind with Eq::{equal, not_equal}

///|
/// The `extension` of every WebGL render target.
pub(all) struct WebGLRenderTargetExtension {
  kind : WebGLRenderTargetKind
}

///|
pub impl @core.RenderTargetExtension for WebGLRenderTargetExtension with fn construct(
  self,
) {
  match self.kind {
    WebGLRenderTarget => WebGLRenderTarget::new()
    WebGL3DRenderTarget => WebGL3DRenderTarget::new()
    WebGLArrayRenderTarget => WebGLArrayRenderTarget::new()
    WebGLCubeRenderTarget => WebGLCubeRenderTarget::new()
  }
}

///|
pub impl @core.RenderTargetExtension for WebGLRenderTargetExtension with fn has_flag(
  self,
  flag,
) {
  match flag {
    "isWebGLRenderTarget" => true
    "isWebGL3DRenderTarget" => self.kind == WebGL3DRenderTarget
    "isWebGLArrayRenderTarget" => self.kind == WebGLArrayRenderTarget
    "isWebGLCubeRenderTarget" => self.kind == WebGLCubeRenderTarget
    _ => false
  }
}

///|
#deprecated
pub extend WebGLRenderTargetExtension with @core.RenderTargetExtension::{
  construct,
  has_flag,
  payload,
  copy_from,
}

///|
/// The kind of a WebGL render target; `None` for a plain core `RenderTarget`.
pub fn webgl_render_target_kind(
  render_target : @core.RenderTarget,
) -> WebGLRenderTargetKind? {
  match render_target.extension {
    Some(extension) =>
      if extension.has_flag("isWebGLRenderTarget") {
        let payload : WebGLRenderTargetExtension = extension.payload().cast()
        Some(payload.kind)
      } else {
        None
      }
    None => None
  }
}

///|
/// `new WebGLRenderTarget( width, height, options )`.
pub fn WebGLRenderTarget::new(
  width~ : Int32 = 1,
  height~ : Int32 = 1,
  depth? : Int32,
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
  depth_texture? : @core.Texture,
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
) -> @core.RenderTarget {
  let target = @core.RenderTarget::new(
    width~,
    height~,
    depth?,
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
  target.set_extension({ kind: WebGLRenderTarget, })
}

///|
/// `new WebGL3DRenderTarget( width, height, depth, options )`.
pub fn WebGL3DRenderTarget::new(
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
  depth_texture? : @core.Texture,
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
) -> @core.RenderTarget {
  let target = @core.RenderTarget::new(
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
  ignore(target.set_extension({ kind: WebGL3DRenderTarget, }))
  target.depth = depth
  target.set_texture(@core.Data3DTexture::new(width~, height~, depth~))
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
  target.texture().is_render_target_texture = true
  target
}

///|
/// `new WebGLArrayRenderTarget( width, height, depth, options )`.
pub fn WebGLArrayRenderTarget::new(
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
  depth_texture? : @core.Texture,
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
) -> @core.RenderTarget {
  let target = @core.RenderTarget::new(
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
  ignore(target.set_extension({ kind: WebGLArrayRenderTarget, }))
  target.depth = depth
  target.set_texture(@core.DataArrayTexture::new(width~, height~, depth~))
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
  target.texture().is_render_target_texture = true
  target
}

///|
/// `new WebGLCubeRenderTarget( size, options )`.
pub fn WebGLCubeRenderTarget::new(
  size~ : Int32 = 1,
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
  depth_texture? : @core.Texture,
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
) -> @core.RenderTarget {
  let target = @core.RenderTarget::new(
    width=size,
    height=size,
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
  ignore(target.set_extension({ kind: WebGLCubeRenderTarget, }))
  // upstream shares one { width, height, depth } object between the six faces
  let image = @core.TextureImage::DataImage(
    @core.DataImage::new(width=size, height=size, depth=1),
  )
  target.set_texture(
    @core.CubeTexture::new(images=[image, image, image, image, image, image]),
  )
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
  target.texture().is_render_target_texture = true
  target
}

///|
let webgl_cube_render_target_vertex_shader : String = (
    #|
    #|
    #|				varying vec3 vWorldDirection;
    #|
    #|				vec3 transformDirection( in vec3 dir, in mat4 matrix ) {
    #|
    #|					return normalize( ( matrix * vec4( dir, 0.0 ) ).xyz );
    #|
    #|				}
    #|
    #|				void main() {
    #|
    #|					vWorldDirection = transformDirection( position, modelMatrix );
    #|
    #|					#include <begin_vertex>
    #|					#include <project_vertex>
    #|
    #|				}
  ) +
  // upstream's template literal ends with the indentation before its backtick
  "\n\t\t\t"

///|
let webgl_cube_render_target_fragment_shader : String = (
    #|
    #|
    #|				uniform sampler2D tEquirect;
    #|
    #|				varying vec3 vWorldDirection;
    #|
    #|				#include <common>
    #|
    #|				void main() {
    #|
    #|					vec3 direction = normalize( vWorldDirection );
    #|
    #|					vec2 sampleUV = equirectUv( direction );
    #|
    #|					gl_FragColor = texture2D( tEquirect, sampleUV );
    #|
    #|				}
  ) +
  // upstream's template literal ends with the indentation before its backtick
  "\n\t\t\t"

///|
/// `cubeRenderTarget.fromEquirectangularTexture( renderer, texture )`.
pub fn WebGLCubeRenderTarget::from_equirectangular_texture(
  self : @core.RenderTarget,
  renderer : WebGLRenderer,
  texture : @core.Texture,
) -> @core.RenderTarget {
  let target_texture = self.texture()
  target_texture.type_ = texture.type_
  target_texture.color_space = texture.color_space
  target_texture.generate_mipmaps = texture.generate_mipmaps
  target_texture.min_filter = texture.min_filter
  target_texture.mag_filter = texture.mag_filter
  let shader_uniforms : Map[String, @core.Uniform] = {
    "tEquirect": { value: Null, },
  }
  let geometry = @geometries.BoxGeometry::new(width=5.0, height=5.0, depth=5.0)
  let material = @core.ShaderMaterial::new()
  material.name = "CubemapFromEquirect"
  material.uniforms = Some(@core.clone_uniforms(shader_uniforms))
  material.vertex_shader = Some(webgl_cube_render_target_vertex_shader)
  material.fragment_shader = Some(webgl_cube_render_target_fragment_shader)
  material.side = @core.BackSide
  material.blending = @core.NoBlending
  material.uniforms.unwrap()["tEquirect"].value = Texture(texture)
  let mesh = @core.Mesh::new(geometry~, material=Single(material))
  let current_min_filter = texture.min_filter
  // Avoid blurred poles
  if texture.min_filter == @core.LinearMipmapLinearFilter {
    texture.min_filter = @core.LinearFilter
  }
  let camera = @core.CubeCamera::new(near=1.0, far=10.0, render_target=self)
  camera.update_cube_camera(renderer, mesh)
  texture.min_filter = current_min_filter
  geometry.dispose()
  material.dispose()
  self
}

///|
/// `cubeRenderTarget.clear( renderer, color, depth, stencil )`.
pub fn WebGLCubeRenderTarget::clear(
  self : @core.RenderTarget,
  renderer : WebGLRenderer,
  color~ : Bool = true,
  depth~ : Bool = true,
  stencil~ : Bool = true,
) -> Unit {
  let current_render_target = renderer.get_render_target()
  for i in 0..<6 {
    renderer.set_render_target(Some(self), active_cube_face=i)
    renderer.clear(color~, depth~, stencil~)
  }
  renderer.set_render_target(current_render_target)
}
