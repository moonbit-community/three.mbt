// nodes/accessors/MaterialReferenceNode.js: a reference to a property of the material
// being rendered (or of a given material).

///|
pub(all) struct MaterialReferenceNode {
  reference_node : ReferenceNode
  material : @core.Material?
}

///|
pub impl NodeClass for MaterialReferenceNode with fn class_name(_) {
  "MaterialReferenceNode"
}

///|
pub impl NodeClass for MaterialReferenceNode with fn parent(self) {
  Some(self.reference_node)
}

///|
pub impl NodeClass for MaterialReferenceNode with fn has_flag(self, flag) {
  flag == "isMaterialReferenceNode" || self.reference_node.has_flag(flag)
}

///|
pub impl NodeClass for MaterialReferenceNode with fn update_reference(
  self,
  _,
  state,
) {
  let material = match self.material {
    Some(m) => Some(m)
    None =>
      match state {
        Builder(b) => b.material
        Frame(f) => f.material
      }
  }
  self.reference_node.reference = material.map(fn(m) { Material(m) })
  self.reference_node.reference_identity()
}

///|
/// `new MaterialReferenceNode( property, inputType, material = null )`.
pub fn MaterialReferenceNode::new(
  property : String,
  input_type : String?,
  material? : @core.Material,
) -> Node {
  let node = Node::alloc()
  let reference_node = ReferenceNode::construct(
    node,
    property,
    input_type,
    material.map(fn(m) { Material(m) }),
    None,
  )
  node.set_class(MaterialReferenceNode::{ reference_node, material, })
}

///|
pub fn MaterialReferenceNode::of(node : Node) -> MaterialReferenceNode? {
  match node.class_payload("MaterialReferenceNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `materialReference( name, type, material = null )`.
pub fn material_reference(
  name : String,
  type_ : String,
  material? : @core.Material,
) -> Node {
  MaterialReferenceNode::new(name, Some(type_), material?)
}
