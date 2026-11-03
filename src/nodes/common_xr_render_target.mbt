// renderers/common/XRRenderTarget.js, and the ad hoc render target properties the
// renderer and XRManager set on any core `RenderTarget` (`isPostProcessingRenderTarget`,
// `_autoAllocateDepthBuffer`, `_hasExternalTextures`, `isXRRenderTarget`, ...), kept
// beside the target as core has no such fields.

///|
/// The renderer's ad hoc properties of a render target; `None` is `undefined`.
pub(all) struct RenderTargetProps {
  mut is_post_processing_render_target : Bool?
  mut is_xr_render_target : Bool?
  mut _has_external_textures : Bool?
  mut _auto_allocate_depth_buffer : Bool?
  mut _is_opaque_framebuffer : Bool?
  /// `_xrFoveationTextureGPU`.
  mut _xr_foveation_texture_gpu : @core.JsValue?
}

///|
let _render_target_props : @webgl.WeakMap[@core.JsValue, RenderTargetProps] = @webgl.WeakMap::new()

///|
/// The ad hoc properties of `render_target`, created (all `undefined`) on first use.
pub fn render_target_props(
  render_target : @core.RenderTarget,
) -> RenderTargetProps {
  let key = @core.JsValue::of(render_target)
  match _render_target_props.get(key) {
    Some(p) => p
    None => {
      let p = {
        is_post_processing_render_target: None,
        is_xr_render_target: None,
        _has_external_textures: None,
        _auto_allocate_depth_buffer: None,
        _is_opaque_framebuffer: None,
        _xr_foveation_texture_gpu: None,
      }
      _render_target_props.set(key, p)
      p
    }
  }
}

///|
/// `renderTarget.isXRRenderTarget === true`.
pub fn is_xr_render_target(render_target : @core.RenderTarget) -> Bool {
  render_target.has_extension_flag("isXRRenderTarget")
}

///|
/// `renderTarget._hasExternalTextures === true`.
pub fn render_target_has_external_textures(
  render_target : @core.RenderTarget,
) -> Bool {
  render_target_props(render_target)._has_external_textures == Some(true)
}

///|
/// The extension of an `XRRenderTarget`; `has_flag("isXRRenderTarget")` reads the
/// target's writable `isXRRenderTarget`.
pub(all) struct XRRenderTargetExtension {
  props : RenderTargetProps
}

///|
pub impl @core.RenderTargetExtension for XRRenderTargetExtension with fn construct(
  _,
) {
  XRRenderTarget::new()
}

///|
pub impl @core.RenderTargetExtension for XRRenderTargetExtension with fn has_flag(
  self,
  flag,
) {
  flag == "isXRRenderTarget" && self.props.is_xr_render_target == Some(true)
}

///|
pub impl @core.RenderTargetExtension for XRRenderTargetExtension with fn copy_from(
  _,
  target,
  source,
) {
  let t = render_target_props(target)
  let s = render_target_props(source)
  t._has_external_textures = s._has_external_textures
  t._auto_allocate_depth_buffer = s._auto_allocate_depth_buffer
  t._is_opaque_framebuffer = s._is_opaque_framebuffer
}

///|
/// Marker for `XRRenderTarget`; `XRRenderTarget::new` returns a core `RenderTarget`.
pub(all) struct XRRenderTarget {
  mut _placeholder : Unit
}

///|
/// `new XRRenderTarget( width = 1, height = 1, options = {} )`.
pub fn XRRenderTarget::new(
  width~ : Int32 = 1,
  height~ : Int32 = 1,
  format? : Int32,
  type_? : Int32,
  color_space? : String,
  depth_texture? : @core.Texture,
  depth_buffer? : Bool,
  stencil_buffer? : Bool,
  samples? : Int32,
  resolve_depth_buffer? : Bool,
  resolve_stencil_buffer? : Bool,
  store_multisampled_color_buffer? : Bool,
  store_multisampled_depth_buffer? : Bool,
  store_multisampled_stencil_buffer? : Bool,
  depth? : Int32,
  multiview? : Bool,
) -> @core.RenderTarget {
  let target = @core.RenderTarget::new(
    width~,
    height~,
    format?,
    type_?,
    color_space?,
    depth_texture?,
    depth_buffer?,
    stencil_buffer?,
    samples?,
    resolve_depth_buffer?,
    resolve_stencil_buffer?,
    store_multisampled_color_buffer?,
    store_multisampled_depth_buffer?,
    store_multisampled_stencil_buffer?,
    depth?,
    multiview?,
  )
  let props = render_target_props(target)
  target.set_extension(XRRenderTargetExtension::{ props, }) |> ignore
  props.is_xr_render_target = Some(true)
  props._has_external_textures = Some(false)
  props._auto_allocate_depth_buffer = Some(true)
  props._is_opaque_framebuffer = Some(false)
  target
}
