// renderers/common/RenderContext.js

///|
let _render_context_id : Ref[Int32] = Ref(0)

///|
/// `{ r, g, b, a }` of `clearColorValue`.
pub(all) struct RenderContextClearColor {
  mut r : Double
  mut g : Double
  mut b : Double
  mut a : Double
}

///|
/// The state of one render pass: attachments, clear values, viewport and scissor.
pub(all) struct RenderContext {
  id : Int32
  mut state_key : String
  /// `frustumArray`; `None` is `null`.
  mut frustum_array : @math.FrustumArray?
  /// The `MRTNode`; `None` is `null`.
  mut mrt : Node?
  mut color : Bool
  mut clear_color : Bool
  mut clear_color_value : RenderContextClearColor
  mut depth : Bool
  mut clear_depth : Bool
  mut clear_depth_value : Double
  mut stencil : Bool
  mut clear_stencil : Bool
  mut clear_stencil_value : Int32
  mut viewport : Bool
  viewport_value : @math.Vector4
  /// `viewportValue.minDepth` / `maxDepth`, set by the renderer (added by G6);
  /// `None` is `undefined`.
  mut viewport_min_depth : Double?
  mut viewport_max_depth : Double?
  mut scissor : Bool
  scissor_value : @math.Vector4
  mut render_target : @core.RenderTarget?
  mut textures : Array[@core.Texture]?
  mut depth_texture : @core.Texture?
  mut active_cube_face : Int32
  mut active_mipmap_level : Int32
  mut sample_count : Int32
  mut width : Int32
  mut height : Int32
  mut occlusion_query_count : Int32
  mut clipping_context : ClippingContext?
  mut camera : @core.Object3D?
  mut fullscreen_pass : Bool
}

///|
/// `new RenderContext()`.
pub fn RenderContext::new() -> RenderContext {
  let id = _render_context_id.val
  _render_context_id.val += 1
  {
    id,
    state_key: "",
    frustum_array: None,
    mrt: None,
    color: true,
    clear_color: true,
    clear_color_value: { r: 0.0, g: 0.0, b: 0.0, a: 1.0, },
    depth: true,
    clear_depth: true,
    clear_depth_value: 1.0,
    stencil: false,
    clear_stencil: true,
    clear_stencil_value: 1,
    viewport: false,
    viewport_value: @math.Vector4::new(0.0, 0.0, 0.0, 1.0),
    viewport_min_depth: None,
    viewport_max_depth: None,
    scissor: false,
    scissor_value: @math.Vector4::new(0.0, 0.0, 0.0, 1.0),
    render_target: None,
    textures: None,
    depth_texture: None,
    active_cube_face: 0,
    active_mipmap_level: 0,
    sample_count: 1,
    width: 0,
    height: 0,
    occlusion_query_count: 0,
    clipping_context: None,
    camera: None,
    fullscreen_pass: false,
  }
}

///|
/// `getCacheKey()`.
pub fn RenderContext::get_cache_key(self : RenderContext) -> Double {
  get_cache_key(self)
}

///|
/// `getCacheKey( renderContext )`: a hash of the attachments and the target face/level.
pub fn get_cache_key(render_context : RenderContext) -> Double {
  let values = [
    render_context.active_cube_face.to_double(),
    render_context.active_mipmap_level.to_double(),
  ]
  match render_context.textures {
    Some(textures) =>
      for texture in textures {
        values.push(texture.id.to_double())
      }
    None => abort("TypeError: textures is not iterable")
  }
  match render_context.depth_texture {
    Some(t) => values.push(t.id.to_double())
    None => ()
  }
  hash_array(values)
}
