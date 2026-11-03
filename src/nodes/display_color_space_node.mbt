// nodes/display/ColorSpaceNode.js

///|
let _color_space_node_working_color_space : String = "WorkingColorSpace"

///|
let _color_space_node_output_color_space : String = "OutputColorSpace"

///|
/// Converts a color from one color space to another.
pub(all) struct ColorSpaceNode {
  mut color_node : Node
  /// A color space, or `'WorkingColorSpace'` / `'OutputColorSpace'`.
  mut source : String
  mut target : String
}

///|
pub impl NodeClass for ColorSpaceNode with fn class_name(_) {
  "ColorSpaceNode"
}

///|
pub impl NodeClass for ColorSpaceNode with fn children(self, _, out) {
  push_child(out, "colorNode", Some(self.color_node))
}

///|
pub impl NodeClass for ColorSpaceNode with fn setup(self, _, builder) {
  let color_node = self.color_node
  let source = ColorSpaceNode::resolve_color_space(builder, self.source)
  let target = ColorSpaceNode::resolve_color_space(builder, self.target)
  let mut output_node = color_node
  let cm = @math.color_management
  if cm.enabled == false || source == target || source == "" || target == "" {
    return Some(output_node)
  }
  if cm.get_transfer(source) == @math.SRGBTransfer {
    output_node = vec4_of([
      s_rgb_transfer_eotf.call([output_node.rgb()]),
      output_node.a(),
    ])
  }
  // `getPrimaries()` compares the arrays by identity.
  if !physical_equal(cm.get_primaries(source), cm.get_primaries(target)) {
    output_node = vec4_of([
      mat3(cm._get_matrix(@math.Matrix3::new(), source, target)).mul(
        output_node.rgb(),
      ),
      output_node.a(),
    ])
  }
  if cm.get_transfer(target) == @math.SRGBTransfer {
    output_node = vec4_of([
      s_rgb_transfer_oetf.call([output_node.rgb()]),
      output_node.a(),
    ])
  }
  Some(output_node)
}

///|
/// `resolveColorSpace( builder, colorSpace )`: the working or output color space for
/// the placeholders, the color space itself otherwise.
pub fn ColorSpaceNode::resolve_color_space(
  builder : NodeBuilder,
  color_space : String,
) -> String {
  if color_space == _color_space_node_working_color_space {
    @math.color_management.working_color_space
  } else if color_space == _color_space_node_output_color_space {
    match builder.context.get("outputColorSpace") {
      String(s) if s != "" => s
      _ => builder.renderer.output_color_space
    }
  } else {
    color_space
  }
}

///|
pub fn ColorSpaceNode::construct(
  _node : Node,
  color_node : Node,
  source : String,
  target : String,
) -> ColorSpaceNode {
  { color_node, source, target, }
}

///|
/// `new ColorSpaceNode( colorNode, source, target )`.
pub fn ColorSpaceNode::new(
  color_node : Node,
  source : String,
  target : String,
) -> Node {
  let node = Node::alloc(node_type="vec4")
  node.set_class(ColorSpaceNode::construct(node, color_node, source, target))
}

///|
pub fn ColorSpaceNode::of(node : Node) -> ColorSpaceNode? {
  match node.class_payload("ColorSpaceNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `workingToColorSpace( node, targetColorSpace )`.
pub fn working_to_color_space(
  node : &IntoTsl,
  target_color_space : String,
) -> Node {
  ColorSpaceNode::new(
    node_object(node.to_tsl()),
    _color_space_node_working_color_space,
    target_color_space,
  )
}

///|
/// `colorSpaceToWorking( node, sourceColorSpace )`.
pub fn color_space_to_working(
  node : &IntoTsl,
  source_color_space : String,
) -> Node {
  ColorSpaceNode::new(
    node_object(node.to_tsl()),
    source_color_space,
    _color_space_node_working_color_space,
  )
}

///|
/// `convertColorSpace( node, sourceColorSpace, targetColorSpace )`.
pub fn convert_color_space(
  node : &IntoTsl,
  source_color_space : String,
  target_color_space : String,
) -> Node {
  ColorSpaceNode::new(
    node_object(node.to_tsl()),
    source_color_space,
    target_color_space,
  )
}

///|
fn color_space_node_element(
  f : (TslValue, String) -> Node,
) -> (Array[TslValue]) -> Node {
  fn(params) {
    match params {
      [node, String(color_space), ..] => f(node, color_space)
      [node, ..] => f(node, "")
      [] => f(Undefined, "")
    }
  }
}

///|
/// `node.workingToColorSpace( targetColorSpace )`.
pub fn Node::working_to_color_space(
  self : Node,
  target_color_space : String,
) -> Node {
  self.chain(
    color_space_node_element(fn(n, c) { working_to_color_space(n, c) }),
    [String(target_color_space)],
  )
}

///|
/// `node.colorSpaceToWorking( sourceColorSpace )`.
pub fn Node::color_space_to_working(
  self : Node,
  source_color_space : String,
) -> Node {
  self.chain(
    color_space_node_element(fn(n, c) { color_space_to_working(n, c) }),
    [String(source_color_space)],
  )
}
