// nodes/display/RenderOutputNode.js

///|
/// The final output step: tone mapping and the output color space, with alpha
/// unpremultiplied around them.
pub(all) struct RenderOutputNode {
  /// `None` is `null`: the context's `color`.
  mut color_node : Node?
  /// `None` is `null`: the context's `toneMapping`.
  mut _tone_mapping : Int32?
  /// `None` is `null`: the context's `outputColorSpace`.
  mut output_color_space : String?
  mut premultiplied_alpha : Bool
}

///|
pub impl NodeClass for RenderOutputNode with fn class_name(_) {
  "RenderOutputNode"
}

///|
pub impl NodeClass for RenderOutputNode with fn has_flag(_, flag) {
  flag == "isRenderOutputNode"
}

///|
pub impl NodeClass for RenderOutputNode with fn children(self, _, out) {
  push_child(out, "colorNode", self.color_node)
}

///|
pub impl NodeClass for RenderOutputNode with fn setup(self, _, builder) {
  let context = builder.context
  let mut output_node = match self.color_node {
    Some(c) => c
    None =>
      match context.get_node("color") {
        Some(c) => c
        None =>
          abort(
            "TypeError: Cannot read properties of undefined (reading 'rgb')",
          )
      }
  }
  // clamp alpha
  output_node = vec4_of([
    output_node.rgb(),
    output_node.a().clamp(low=0.0, high=1.0),
  ])
  // unpremultiply
  if self.premultiplied_alpha == true {
    output_node = unpremultiply_alpha.call([output_node])
  }
  // tone mapping
  let tone_mapping = match self._tone_mapping {
    Some(t) => t
    None =>
      match context.get("toneMapping") {
        Number(n) => n.to_int()
        _ => @core.NoToneMapping
      }
  }
  let output_color_space = match self.output_color_space {
    Some(c) => c
    None =>
      match context.get("outputColorSpace") {
        String(s) => s
        _ => @core.NoColorSpace
      }
  }
  // `|| NoToneMapping`, `|| NoColorSpace`: falsy values are the defaults
  if tone_mapping != @core.NoToneMapping {
    output_node = output_node.tone_mapping(tone_mapping)
  }
  // working to output color space
  if output_color_space != @core.NoColorSpace &&
    output_color_space != @math.color_management.working_color_space {
    output_node = output_node.working_to_color_space(output_color_space)
  }
  // premultiply in output color space
  if self.premultiplied_alpha == true {
    output_node = premultiply_alpha.call([output_node])
  }
  Some(output_node)
}

///|
pub fn RenderOutputNode::construct(
  _node : Node,
  color_node : Node?,
  tone_mapping : Int32?,
  output_color_space : String?,
) -> RenderOutputNode {
  {
    color_node,
    _tone_mapping: tone_mapping,
    output_color_space,
    premultiplied_alpha: true,
  }
}

///|
/// `new RenderOutputNode( colorNode, toneMapping, outputColorSpace )`.
pub fn RenderOutputNode::new(
  color_node : Node?,
  tone_mapping : Int32?,
  output_color_space : String?,
) -> Node {
  let node = Node::alloc(node_type="vec4")
  node.set_class(
    RenderOutputNode::construct(
      node, color_node, tone_mapping, output_color_space,
    ),
  )
}

///|
pub fn RenderOutputNode::of(node : Node) -> RenderOutputNode? {
  match node.class_payload("RenderOutputNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `renderOutput( color, toneMapping = null, outputColorSpace = null )`.
pub fn render_output(
  color : &IntoTsl,
  tone_mapping? : Int32,
  output_color_space? : String,
) -> Node {
  let color_node = match node_object_value(color.to_tsl()) {
    Node(n) => Some(n)
    _ => None
  }
  RenderOutputNode::new(color_node, tone_mapping, output_color_space)
}

///|
/// `color.renderOutput( toneMapping, outputColorSpace )`.
pub fn Node::render_output(
  self : Node,
  tone_mapping? : Int32,
  output_color_space? : String,
) -> Node {
  self.chain(
    fn(params) {
      match params {
        [color, ..] => render_output(color, tone_mapping?, output_color_space?)
        [] => render_output(TslValue::Null, tone_mapping?, output_color_space?)
      }
    },
    [],
  )
}
