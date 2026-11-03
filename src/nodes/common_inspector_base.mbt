// renderers/common/InspectorBase.js. Inspectors (the addon `Inspector`) override the
// hooks through `InspectorBaseClass`; the base methods do nothing.

///|
/// The overridable methods of `InspectorBase`; every default is the base body.
pub(open) trait InspectorBaseClass {
  /// The JS class name (`inspector.constructor !== InspectorBase` checks it).
  fn class_name(Self) -> String
  fn begin(Self, InspectorBase) -> Unit = _
  fn finish(Self, InspectorBase) -> Unit = _
  fn inspect(Self, InspectorBase, Node) -> Unit = _
  fn compute_async(Self, InspectorBase, Node, @core.JsValue) -> Unit = _
  fn begin_compute(Self, InspectorBase, String, Node) -> Unit = _
  fn finish_compute(Self, InspectorBase, String) -> Unit = _
  fn begin_render(
    Self,
    InspectorBase,
    String,
    @core.Object3D,
    @core.Object3D,
    @core.RenderTarget?,
  ) -> Unit = _
  fn finish_render(Self, InspectorBase, String) -> Unit = _
  fn copy_texture_to_texture(Self, InspectorBase, @core.Texture, @core.Texture) -> Unit = _
  fn copy_framebuffer_to_texture(Self, InspectorBase, @core.Texture) -> Unit = _
}

///|
impl InspectorBaseClass with fn begin(_, inspector) {
  inspector.is_running = true
}

///|
impl InspectorBaseClass with fn finish(_, inspector) {
  inspector.is_running = false
}

///|
impl InspectorBaseClass with fn inspect(_, _, _) {

}

///|
impl InspectorBaseClass with fn compute_async(_, _, _, _) {

}

///|
impl InspectorBaseClass with fn begin_compute(_, _, _, _) {

}

///|
impl InspectorBaseClass with fn finish_compute(_, _, _) {

}

///|
impl InspectorBaseClass with fn begin_render(_, _, _, _, _, _) {

}

///|
impl InspectorBaseClass with fn finish_render(_, _, _) {

}

///|
impl InspectorBaseClass with fn copy_texture_to_texture(_, _, _, _) {

}

///|
impl InspectorBaseClass with fn copy_framebuffer_to_texture(_, _, _) {

}

///|
/// The class of a plain `new InspectorBase()`.
pub(all) struct BaseInspector {}

///|
pub impl InspectorBaseClass for BaseInspector with fn class_name(_) {
  "InspectorBase"
}

///|
/// Upstream's `InspectorBase` fields; `class_` is the most derived inspector.
pub(all) struct InspectorBase {
  dispatcher : @core.EventDispatcher
  mut class_ : &InspectorBaseClass
  mut _renderer : Renderer?
  mut current_frame : @core.JsValue?
  mut is_running : Bool
  mut enabled : Bool
}

///|
/// `new InspectorBase()`; subclasses pass their class payload.
pub fn InspectorBase::new(class_? : &InspectorBaseClass) -> InspectorBase {
  {
    dispatcher: @core.EventDispatcher::new(),
    class_: match class_ {
      Some(c) => c
      None => BaseInspector::{ }
    },
    _renderer: None,
    current_frame: None,
    is_running: false,
    enabled: true,
  }
}

///|
/// `inspector.constructor === InspectorBase`.
pub fn InspectorBase::is_base(self : InspectorBase) -> Bool {
  self.class_.class_name() == "InspectorBase"
}

///|
/// `get nodeFrame()`: the renderer's `_nodes.nodeFrame`.
pub fn InspectorBase::node_frame(self : InspectorBase) -> NodeFrame {
  self._renderer.unwrap().node_frame()
}

///|
pub fn InspectorBase::set_renderer(
  self : InspectorBase,
  renderer : Renderer?,
) -> InspectorBase {
  self._renderer = renderer
  self
}

///|
pub fn InspectorBase::get_renderer(self : InspectorBase) -> Renderer? {
  self._renderer
}

///|
pub fn InspectorBase::begin(self : InspectorBase) -> Unit {
  self.class_.begin(self)
}

///|
pub fn InspectorBase::finish(self : InspectorBase) -> Unit {
  self.class_.finish(self)
}

///|
pub fn InspectorBase::inspect(self : InspectorBase, node : Node) -> Unit {
  self.class_.inspect(self, node)
}

///|
/// `computeAsync( computeNode, dispatchSizeOrCount )`.
pub fn InspectorBase::compute_async(
  self : InspectorBase,
  compute_node : Node,
  dispatch_size_or_count : @core.JsValue,
) -> Unit {
  self.class_.compute_async(self, compute_node, dispatch_size_or_count)
}

///|
pub fn InspectorBase::begin_compute(
  self : InspectorBase,
  uid : String,
  compute_node : Node,
) -> Unit {
  self.class_.begin_compute(self, uid, compute_node)
}

///|
pub fn InspectorBase::finish_compute(
  self : InspectorBase,
  uid : String,
) -> Unit {
  self.class_.finish_compute(self, uid)
}

///|
pub fn InspectorBase::begin_render(
  self : InspectorBase,
  uid : String,
  scene : @core.Object3D,
  camera : @core.Object3D,
  render_target : @core.RenderTarget?,
) -> Unit {
  self.class_.begin_render(self, uid, scene, camera, render_target)
}

///|
pub fn InspectorBase::finish_render(self : InspectorBase, uid : String) -> Unit {
  self.class_.finish_render(self, uid)
}

///|
pub fn InspectorBase::copy_texture_to_texture(
  self : InspectorBase,
  src_texture : @core.Texture,
  dst_texture : @core.Texture,
) -> Unit {
  self.class_.copy_texture_to_texture(self, src_texture, dst_texture)
}

///|
pub fn InspectorBase::copy_framebuffer_to_texture(
  self : InspectorBase,
  framebuffer_texture : @core.Texture,
) -> Unit {
  self.class_.copy_framebuffer_to_texture(self, framebuffer_texture)
}

///|
pub fn InspectorBase::dispose(self : InspectorBase) -> Unit {
  if self.is_running {
    self.finish()
  }
  self.dispatcher.dispatch_event(@core.Event::new("dispose"))
}
