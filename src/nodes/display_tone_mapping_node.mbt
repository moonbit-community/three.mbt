// nodes/display/ToneMappingNode.js

///|
/// Applies a tone mapping (one of the `*ToneMapping` constants) to a color.
pub(all) struct ToneMappingNode {
  mut _tone_mapping : Int32
  mut exposure_node : Node
  /// `None` is `null`: the context's `color`.
  mut color_node : Node?
}

///|
pub impl NodeClass for ToneMappingNode with fn class_name(_) {
  "ToneMappingNode"
}

///|
pub impl NodeClass for ToneMappingNode with fn children(self, _, out) {
  push_child(out, "exposureNode", Some(self.exposure_node))
  push_child(out, "colorNode", self.color_node)
}

///|
pub impl NodeClass for ToneMappingNode with fn custom_cache_key(self, _) {
  hash([self._tone_mapping.to_double()])
}

///|
pub impl NodeClass for ToneMappingNode with fn setup(self, _, builder) {
  let color_node = match self.color_node {
    Some(c) => c
    None =>
      match builder.context.get_node("color") {
        Some(c) => c
        None =>
          abort(
            "TypeError: Cannot read properties of undefined (reading 'rgb')",
          )
      }
  }
  let tone_mapping = self._tone_mapping
  if tone_mapping == @core.NoToneMapping {
    return Some(color_node)
  }
  let tone_mapping_fn = builder.renderer.library.get_tone_mapping_function(
    tone_mapping,
  )
  let output_node = match tone_mapping_fn {
    Some(f) =>
      vec4_of([f.call([color_node.rgb(), self.exposure_node]), color_node.a()])
    None => {
      @core.error(
        "ToneMappingNode: Unsupported Tone Mapping configuration. \{tone_mapping}",
      )
      color_node
    }
  }
  Some(output_node)
}

///|
pub fn ToneMappingNode::construct(
  _node : Node,
  tone_mapping : Int32,
  exposure_node : Node,
  color_node : Node?,
) -> ToneMappingNode {
  { _tone_mapping: tone_mapping, exposure_node, color_node, }
}

///|
/// `new ToneMappingNode( toneMapping, exposureNode = toneMappingExposure, colorNode = null )`.
pub fn ToneMappingNode::new(
  tone_mapping : Int32,
  exposure_node? : Node,
  color_node? : Node,
) -> Node {
  let node = Node::alloc(node_type="vec3")
  let exposure_node = match exposure_node {
    Some(e) => e
    None => tone_mapping_exposure
  }
  node.set_class(
    ToneMappingNode::construct(node, tone_mapping, exposure_node, color_node),
  )
}

///|
pub fn ToneMappingNode::of(node : Node) -> ToneMappingNode? {
  match node.class_payload("ToneMappingNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `setToneMapping( value )` of ToneMappingNode and RenderOutputNode.
pub fn Node::set_tone_mapping(self : Node, value : Int32) -> Node {
  match ToneMappingNode::of(self) {
    Some(t) => t._tone_mapping = value
    None =>
      match RenderOutputNode::of(self) {
        Some(r) => r._tone_mapping = Some(value)
        None =>
          abort("TypeError: \{self.type_()}.setToneMapping is not a function")
      }
  }
  self
}

///|
/// `getToneMapping()` of ToneMappingNode and RenderOutputNode (`None` is `null`).
pub fn Node::get_tone_mapping(self : Node) -> Int32? {
  match ToneMappingNode::of(self) {
    Some(t) => Some(t._tone_mapping)
    None =>
      match RenderOutputNode::of(self) {
        Some(r) => r._tone_mapping
        None =>
          abort("TypeError: \{self.type_()}.getToneMapping is not a function")
      }
  }
}

///|
/// `toneMappingExposure`: the renderer's `toneMappingExposure`.
pub let tone_mapping_exposure : Node = module_nodes(
  "nodes/display/ToneMappingNode.js:toneMappingExposure",
  fn() { renderer_reference("toneMappingExposure", "float") },
)

///|
fn tone_mapping_node_value(value : &IntoTsl?) -> Node? {
  match value {
    Some(v) =>
      match node_object_value(v.to_tsl()) {
        Node(n) => Some(n)
        _ => None
      }
    None => None
  }
}

///|
/// `toneMapping( mapping, exposure, color )`.
pub fn tone_mapping(
  mapping : Int32,
  exposure? : &IntoTsl,
  color? : &IntoTsl,
) -> Node {
  ToneMappingNode::new(
    mapping,
    exposure_node?=tone_mapping_node_value(exposure),
    color_node?=tone_mapping_node_value(color),
  )
}

///|
/// `color.toneMapping( mapping, exposure )`.
pub fn Node::tone_mapping(
  self : Node,
  mapping : Int32,
  exposure? : &IntoTsl,
) -> Node {
  self.chain(
    fn(params) {
      match params {
        [color, ..] => tone_mapping(mapping, exposure?, color~)
        [] => tone_mapping(mapping, exposure?)
      }
    },
    [],
  )
}
