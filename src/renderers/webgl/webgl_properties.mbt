// Upstream src/renderers/webgl/WebGLProperties.js, plus the typed records that replace
// upstream's free-form `properties.get( object )` bags.
//
// Upstream keeps one `WeakMap` from any object to `{}` and every module adds `__foo` keys.
// Here the map is the same JS `WeakMap`, but each key kind has a record type listing every
// key any upstream module reads or writes: `get_material`, `get_texture`,
// `get_render_target`, `get_source`. A key object is only ever read with one getter.
// `undefined` keys are `None` (or `false` where upstream only tests truthiness).

///|
pub struct WebGLProperties {
  mut properties : WeakMap[@core.JsValue, @core.JsValue]
}

///|
/// `new WebGLProperties()`.
pub fn WebGLProperties::new() -> WebGLProperties {
  { properties: WeakMap::new(), }
}

///|
/// `properties.has( object )`.
pub fn[T] WebGLProperties::has(self : WebGLProperties, object : T) -> Bool {
  self.properties.has(@core.JsValue::of(object))
}

///|
fn[T, R] WebGLProperties::get_or_create(
  self : WebGLProperties,
  object : T,
  create : () -> R,
) -> R {
  let key = @core.JsValue::of(object)
  match self.properties.get(key) {
    Some(map) => map.cast()
    None => {
      let map = create()
      self.properties.set(key, @core.JsValue::of(map))
      map
    }
  }
}

///|
/// `properties.get( material )`.
pub fn WebGLProperties::get_material(
  self : WebGLProperties,
  material : @core.Material,
) -> MaterialProperties {
  self.get_or_create(material, MaterialProperties::new)
}

///|
/// `properties.get( texture )`.
pub fn WebGLProperties::get_texture(
  self : WebGLProperties,
  texture : @core.Texture,
) -> TextureProperties {
  self.get_or_create(texture, TextureProperties::new)
}

///|
/// `properties.get( renderTarget )`.
pub fn WebGLProperties::get_render_target(
  self : WebGLProperties,
  render_target : @core.RenderTarget,
) -> RenderTargetProperties {
  self.get_or_create(render_target, RenderTargetProperties::new)
}

///|
/// `properties.get( texture.source )`.
pub fn WebGLProperties::get_source(
  self : WebGLProperties,
  source : @core.TextureSource,
) -> SourceProperties {
  self.get_or_create(source, SourceProperties::new)
}

///|
/// `properties.remove( object )`.
pub fn[T] WebGLProperties::remove(self : WebGLProperties, object : T) -> Unit {
  self.properties.delete(@core.JsValue::of(object))
}

///|
/// `properties.dispose()`.
pub fn WebGLProperties::dispose(self : WebGLProperties) -> Unit {
  self.properties = WeakMap::new()
}

///|
/// `properties.get( material )`: what `WebGLRenderer`, `WebGLClipping`, `WebGLMaterials`
/// and `WebGLShadowMap` store per material.
pub(all) struct MaterialProperties {
  /// `material.version` the program was last checked against.
  mut __version : Int32?
  mut batching : Bool?
  mut batching_color : Bool?
  mut instancing : Bool?
  mut instancing_color : Bool?
  mut instancing_morph : Bool?
  mut skinning : Bool?
  mut morph_targets : Bool?
  mut morph_normals : Bool?
  mut morph_colors : Bool?
  mut morph_targets_count : Int32?
  mut num_clipping_planes : Int32?
  mut num_intersection : Int32?
  mut num_light_probe_grids : Int32?
  mut vertex_alphas : Bool?
  mut vertex_tangents : Bool?
  mut tone_mapping : Int32?
  mut output_color_space : String?
  mut receive_shadow : Bool?
  mut needs_lights : Bool
  mut lights_state_version : Int32?
  /// `WebGLClipping`'s per-material plane array.
  mut clipping_state : @core.TypedArray?
  mut current_program : WebGLProgram?
  /// program cache key -> program.
  mut programs : Map[String, WebGLProgram]?
  /// `program.id + ',' + colorSpace + ',' + toneMapping` -> program.
  mut program_variants : Map[String, WebGLProgram]?
  mut uniforms : Map[String, @core.Uniform]?
  mut uniforms_list : Array[WebGLUniformSetter]?
  mut environment : @core.Texture?
  mut env_map : @core.Texture?
  mut env_map_rotation : @math.Euler?
  /// `scene.fog`, compared by identity.
  mut fog : @core.SceneFog?
  /// The point light a `MeshDistanceMaterial` renders shadows for (`WebGLShadowMap`).
  mut light : @core.Object3D?
}

///|
pub fn MaterialProperties::new() -> MaterialProperties {
  {
    __version: None,
    batching: None,
    batching_color: None,
    instancing: None,
    instancing_color: None,
    instancing_morph: None,
    skinning: None,
    morph_targets: None,
    morph_normals: None,
    morph_colors: None,
    morph_targets_count: None,
    num_clipping_planes: None,
    num_intersection: None,
    num_light_probe_grids: None,
    vertex_alphas: None,
    vertex_tangents: None,
    tone_mapping: None,
    output_color_space: None,
    receive_shadow: None,
    needs_lights: false,
    lights_state_version: None,
    clipping_state: None,
    current_program: None,
    programs: None,
    program_variants: None,
    uniforms: None,
    uniforms_list: None,
    environment: None,
    env_map: None,
    env_map_rotation: None,
    fog: None,
    light: None,
  }
}

///|
/// `properties.get( texture )`: what `WebGLTextures` and `WebGLRenderer` store per texture.
pub(all) struct TextureProperties {
  mut __webgl_texture : GLTexture?
  /// `__webglInit === true`.
  mut __webgl_init : Bool
  mut __version : Int32?
  /// key into the per-source map of GL textures.
  mut __cache_key : String?
  /// the render target this texture is attached to.
  mut __render_target : @core.RenderTarget?
  mut __current_anisotropy : Int32?
  /// `WebGLRenderer.getReadableState` cache.
  mut __read_format : Int32?
  mut __read_type : Int32?
  mut __format_readable : Bool
  mut __type_readable : Bool
  /// `WebGLTextures.track`.
  mut __ref : WeakRef[@core.Texture]?
}

///|
pub fn TextureProperties::new() -> TextureProperties {
  {
    __webgl_texture: None,
    __webgl_init: false,
    __version: None,
    __cache_key: None,
    __render_target: None,
    __current_anisotropy: None,
    __read_format: None,
    __read_type: None,
    __format_readable: false,
    __type_readable: false,
    __ref: None,
  }
}

///|
/// `renderTargetProperties.__webglFramebuffer`: one framebuffer, one per mip level, or one
/// entry per cube face (each a framebuffer or per-level array).
pub(all) enum WebGLFramebufferSlot {
  /// A single framebuffer. `None` is the default framebuffer, as with
  /// `setRenderTargetFramebuffer( target, null )`.
  Framebuffer(GLFramebuffer?)
  /// `__webglFramebuffer[ level ]`.
  Mipmaps(Array[GLFramebuffer])
  /// `__webglFramebuffer[ face ]`, each `Framebuffer` or `Mipmaps`.
  CubeFaces(Array[WebGLFramebufferSlot])
}

///|
/// `renderTargetProperties.__webglDepthbuffer`: one renderbuffer, or one per cube face.
pub(all) enum WebGLRenderbufferSlot {
  Renderbuffer(GLRenderbuffer)
  CubeFaces(Array[GLRenderbuffer?])
}

///|
/// `properties.get( renderTarget )`.
pub(all) struct RenderTargetProperties {
  mut __webgl_framebuffer : WebGLFramebufferSlot?
  mut __webgl_multisampled_framebuffer : GLFramebuffer?
  mut __webgl_depthbuffer : WebGLRenderbufferSlot?
  mut __webgl_depth_renderbuffer : GLRenderbuffer?
  /// one per color texture of a multisampled target.
  mut __webgl_color_renderbuffer : Array[GLRenderbuffer?]?
  /// `undefined` until `setRenderTargetFramebuffer`; then whether its framebuffer was
  /// `undefined`.
  mut __use_default_framebuffer : Bool?
  mut __has_external_textures : Bool
  mut __auto_allocate_depth_buffer : Bool
  /// `false` disables `WEBGL_multisampled_render_to_texture`; `None` is upstream's
  /// `undefined`.
  mut __use_render_to_texture : Bool?
  /// `None` is `undefined` (never bound); `Some(None)` is a bound `null`.
  mut __bound_depth_texture : @core.Texture??
  mut __depth_dispose_callback : (() -> Unit)?
  /// `WebGLTextures.track`.
  mut __ref : WeakRef[@core.RenderTarget]?
}

///|
pub fn RenderTargetProperties::new() -> RenderTargetProperties {
  {
    __webgl_framebuffer: None,
    __webgl_multisampled_framebuffer: None,
    __webgl_depthbuffer: None,
    __webgl_depth_renderbuffer: None,
    __webgl_color_renderbuffer: None,
    __use_default_framebuffer: None,
    __has_external_textures: false,
    __auto_allocate_depth_buffer: false,
    __use_render_to_texture: None,
    __bound_depth_texture: None,
    __depth_dispose_callback: None,
    __ref: None,
  }
}

///|
/// `properties.get( texture.source )`.
pub(all) struct SourceProperties {
  mut __version : Int32?
}

///|
pub fn SourceProperties::new() -> SourceProperties {
  { __version: None, }
}
