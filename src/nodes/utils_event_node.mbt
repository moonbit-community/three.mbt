// nodes/utils/EventNode.js: callbacks run when the object, material or frame updates,
// or before/after the render pipeline.

///|
/// `callback`: updates get the frame, the render pipeline callbacks nothing.
pub(all) enum EventCallback {
  OnFrame((NodeFrame) -> Unit)
  OnPipeline(() -> Unit)
}

///|
fn EventCallback::run(self : EventCallback, frame : NodeFrame) -> Unit {
  match self {
    OnFrame(f) => f(frame)
    OnPipeline(f) => f()
  }
}

///|
pub(all) struct EventNode {
  mut event_type : String
  mut callback : EventCallback
}

///|
pub impl NodeClass for EventNode with fn class_name(_) {
  "EventNode"
}

///|
pub impl NodeClass for EventNode with fn is_cacheable(_, _, _) {
  false
}

///|
/// `builder.context.onBeforePipelineCallbacks` / `onAfterPipelineCallbacks`: the
/// arrays RenderPipeline puts in the context, as `ContextValue::Other` of
/// `Array[() -> Unit]`.
pub fn NodeContext::get_pipeline_callbacks(
  self : NodeContext,
  key : String,
) -> Array[() -> Unit]? {
  match self.get(key) {
    Other(_) as v => v.cast()
    _ => None
  }
}

///|
pub impl NodeClass for EventNode with fn setup(self, node, builder) {
  let key = if self.event_type == EventNode::before_render_pipeline() {
    Some("onBeforePipelineCallbacks")
  } else if self.event_type == EventNode::after_render_pipeline() {
    Some("onAfterPipelineCallbacks")
  } else {
    None
  }
  if key is Some(key) &&
    builder.context.get_pipeline_callbacks(key) is Some(callbacks) {
    let callback = self.callback
    callbacks.push(
      match callback {
        OnPipeline(f) => f
        OnFrame(_) =>
          fn() { abort("EventNode: a frame callback has no frame here") }
      },
    )
  }
  node.setup_base(builder)
}

///|
pub impl NodeClass for EventNode with fn update(self, _, frame) {
  self.callback.run(frame)
  None
}

///|
pub impl NodeClass for EventNode with fn update_before(self, _, frame) {
  self.callback.run(frame)
  None
}

///|
pub impl NodeClass for EventNode with fn update_after(self, _, frame) {
  self.callback.run(frame)
  None
}

///|
pub fn EventNode::object() -> String {
  "object"
}

///|
pub fn EventNode::material() -> String {
  "material"
}

///|
pub fn EventNode::frame() -> String {
  "frame"
}

///|
pub fn EventNode::after_object() -> String {
  "afterObject"
}

///|
pub fn EventNode::before_object() -> String {
  "beforeObject"
}

///|
pub fn EventNode::before_material() -> String {
  "beforeMaterial"
}

///|
pub fn EventNode::before_frame() -> String {
  "beforeFrame"
}

///|
pub fn EventNode::before_render_pipeline() -> String {
  "beforeRenderPipeline"
}

///|
pub fn EventNode::after_render_pipeline() -> String {
  "afterRenderPipeline"
}

///|
/// The constructor body: `super( 'void' )` has run in `Node::alloc`.
pub fn EventNode::construct(
  node : Node,
  event_type : String,
  callback : EventCallback,
) -> EventNode {
  if event_type == EventNode::object() {
    node.update_type = NodeUpdateType::object()
  } else if event_type == EventNode::material() {
    node.update_type = NodeUpdateType::render()
  } else if event_type == EventNode::frame() {
    node.update_type = NodeUpdateType::frame()
  } else if event_type == EventNode::after_object() {
    node.update_after_type = NodeUpdateType::object()
  } else if event_type == EventNode::before_object() {
    node.update_before_type = NodeUpdateType::object()
  } else if event_type == EventNode::before_material() {
    node.update_before_type = NodeUpdateType::render()
  } else if event_type == EventNode::before_frame() {
    node.update_before_type = NodeUpdateType::frame()
  }
  { event_type, callback, }
}

///|
/// `new EventNode( eventType, callback )`.
pub fn EventNode::new(event_type : String, callback : EventCallback) -> Node {
  let node = Node::alloc(node_type="void")
  node.set_class(EventNode::construct(node, event_type, callback))
}

///|
pub fn EventNode::of(node : Node) -> EventNode? {
  match node.class_payload("EventNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `createEvent( type, callback )`.
fn utils_event_node_create(
  event_type : String,
  callback : EventCallback,
) -> Node {
  EventNode::new(event_type, callback).to_stack()
}

///|
/// `OnObjectUpdate( callback )`.
pub fn on_object_update(callback : (NodeFrame) -> Unit) -> Node {
  utils_event_node_create(EventNode::object(), OnFrame(callback))
}

///|
/// `OnMaterialUpdate( callback )`.
pub fn on_material_update(callback : (NodeFrame) -> Unit) -> Node {
  utils_event_node_create(EventNode::material(), OnFrame(callback))
}

///|
/// `OnFrameUpdate( callback )`.
pub fn on_frame_update(callback : (NodeFrame) -> Unit) -> Node {
  utils_event_node_create(EventNode::frame(), OnFrame(callback))
}

///|
/// `OnAfterObjectUpdate( callback )`.
pub fn on_after_object_update(callback : (NodeFrame) -> Unit) -> Node {
  utils_event_node_create(EventNode::after_object(), OnFrame(callback))
}

///|
/// `OnBeforeObjectUpdate( callback )`.
pub fn on_before_object_update(callback : (NodeFrame) -> Unit) -> Node {
  utils_event_node_create(EventNode::before_object(), OnFrame(callback))
}

///|
/// `OnBeforeMaterialUpdate( callback )`.
pub fn on_before_material_update(callback : (NodeFrame) -> Unit) -> Node {
  utils_event_node_create(EventNode::before_material(), OnFrame(callback))
}

///|
/// `OnBeforeFrameUpdate( callback )`.
pub fn on_before_frame_update(callback : (NodeFrame) -> Unit) -> Node {
  utils_event_node_create(EventNode::before_frame(), OnFrame(callback))
}

///|
/// `OnBeforeRenderPipeline( callback )`.
pub fn on_before_render_pipeline(callback : () -> Unit) -> Node {
  utils_event_node_create(
    EventNode::before_render_pipeline(),
    OnPipeline(callback),
  )
}

///|
/// `OnAfterRenderPipeline( callback )`.
pub fn on_after_render_pipeline(callback : () -> Unit) -> Node {
  utils_event_node_create(
    EventNode::after_render_pipeline(),
    OnPipeline(callback),
  )
}
