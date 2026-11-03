// nodes/accessors/RendererReferenceNode.js: a reference to a renderer property, in the
// render group.

///|
pub(all) struct RendererReferenceNode {
  reference_base : ReferenceBaseNode
  renderer : Renderer?
}

///|
pub impl NodeClass for RendererReferenceNode with fn class_name(_) {
  "RendererReferenceNode"
}

///|
pub impl NodeClass for RendererReferenceNode with fn parent(self) {
  Some(self.reference_base)
}

///|
pub impl NodeClass for RendererReferenceNode with fn update_reference(
  self,
  _,
  state,
) {
  let renderer = match self.renderer {
    Some(r) => Some(r)
    None =>
      match state {
        Builder(b) => Some(b.renderer)
        Frame(f) => f.renderer
      }
  }
  self.reference_base.reference = renderer.map(fn(r) { Renderer(r) })
  self.reference_base.reference_identity()
}

///|
/// `new RendererReferenceNode( property, inputType, renderer = null )`.
pub fn RendererReferenceNode::new(
  property : String,
  input_type : String?,
  renderer? : Renderer,
) -> Node {
  let node = Node::alloc()
  let reference_base = ReferenceBaseNode::construct(
    node,
    property,
    input_type,
    renderer.map(fn(r) { Renderer(r) }),
    None,
  )
  reference_base.group = Some(render_group)
  node.set_class(RendererReferenceNode::{ reference_base, renderer, })
}

///|
pub fn RendererReferenceNode::of(node : Node) -> RendererReferenceNode? {
  match node.class_payload("RendererReferenceNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `rendererReference( name, type, renderer = null )`.
pub fn renderer_reference(
  name : String,
  type_ : String,
  renderer? : Renderer,
) -> Node {
  RendererReferenceNode::new(name, Some(type_), renderer?)
}
