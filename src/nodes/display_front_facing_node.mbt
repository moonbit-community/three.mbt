// nodes/display/FrontFacingNode.js

///|
/// Whether the fragment belongs to a front-facing primitive.
pub(all) struct FrontFacingNode {}

///|
pub impl NodeClass for FrontFacingNode with fn class_name(_) {
  "FrontFacingNode"
}

///|
pub impl NodeClass for FrontFacingNode with fn has_flag(_, flag) {
  flag == "isFrontFacingNode"
}

///|
pub impl NodeClass for FrontFacingNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for FrontFacingNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for FrontFacingNode with fn generate(_, _, builder, _) {
  if builder.shader_stage != Some("fragment") {
    return Some("true")
  }
  let material = match builder.material {
    Some(m) => m
    None => abort("TypeError: Cannot read properties of null (reading 'side')")
  }
  if material.side == @core.BackSide {
    return Some("false")
  }
  Some(builder.get_front_facing())
}

///|
/// `new FrontFacingNode()`.
pub fn FrontFacingNode::new() -> Node {
  let node = Node::alloc(node_type="bool")
  node.set_class(FrontFacingNode::{ })
}

///|
pub fn FrontFacingNode::of(node : Node) -> FrontFacingNode? {
  match node.class_payload("FrontFacingNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `frontFacing`: `true` for front-facing fragments.
pub let front_facing : Node = module_nodes(
  "nodes/display/FrontFacingNode.js:frontFacing",
  fn() { FrontFacingNode::new() },
)

///|
/// `faceDirection`: 1 for front-facing fragments, -1 for back-facing ones.
pub let face_direction : Node = module_nodes(
  "nodes/display/FrontFacingNode.js:faceDirection",
  fn() { float(front_facing).mul(2.0).sub(1.0) },
)

///|
/// `negateOnBackSide( vector )`: negates `vector` on back faces (by the material's
/// side, and per fragment for double-sided materials).
pub let negate_on_back_side : Node = module_nodes(
  "nodes/display/FrontFacingNode.js:negateOnBackSide",
  fn() {
    fn_(fn(inputs, builder) {
      let mut vector = inputs.get(0).unwrap()
      let side = match builder.material {
        Some(m) => m.side
        None =>
          abort("TypeError: Cannot read properties of null (reading 'side')")
      }
      if side == @core.BackSide {
        vector = vector.mul(-1.0)
      } else if side == @core.DoubleSide {
        vector = vector.mul(face_direction)
      }
      Some(vector)
    })
  },
)
