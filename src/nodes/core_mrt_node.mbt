// nodes/core/MRTNode.js

///|
let _mrt_node_no_blending : BlendMode = BlendMode::new(
  blending=@core.NoBlending,
)

///|
let _mrt_node_material_blending : BlendMode = BlendMode::new(
  blending=@core.MaterialBlending,
)

///|
/// `getTextureIndex( textures, name )`: the index of the texture named `name`, or -1.
pub fn get_texture_index(
  textures : Array[@core.Texture],
  name : String,
) -> Int32 {
  for i, texture in textures {
    if texture.name == name {
      return i
    }
  }
  -1
}

///|
/// Multiple render targets: one output node per render target texture name.
pub(all) struct MRTNode {
  output_struct : OutputStructNode
  mut output_nodes : Map[String, Node]
  mut blend_modes : Map[String, BlendMode]
  mut clear_colors : Map[String, Color4]
}

///|
pub impl NodeClass for MRTNode with fn class_name(_) {
  "MRTNode"
}

///|
pub impl NodeClass for MRTNode with fn parent(self) {
  Some(self.output_struct)
}

///|
pub impl NodeClass for MRTNode with fn has_flag(self, flag) {
  flag == "isMRTNode" || self.output_struct.has_flag(flag)
}

///|
pub impl NodeClass for MRTNode with fn children(self, node, out) {
  self.output_struct.children(node, out)
  push_child_object(out, "outputNodes", self.output_nodes)
}

///|
pub impl NodeClass for MRTNode with fn setup(self, node, builder) {
  let output_nodes = self.output_nodes
  let mrt = builder.renderer.get_render_target().unwrap()
  let members : Array[Node?] = []
  let textures = mrt.textures
  for name, output_node in output_nodes {
    let index = get_texture_index(textures, name)
    if index == -1 {
      continue
    }
    let type_ = builder.get_output_type(index~)
    while members.length() <= index {
      members.push(None)
    }
    members[index] = Some(output_node.convert(type_))
  }
  self.output_struct.members = members
  self.output_struct.setup(node, builder)
}

///|
pub fn MRTNode::construct(
  node : Node,
  output_nodes : Map[String, Node],
) -> MRTNode {
  let output_struct = OutputStructNode::construct(node, [])
  let blend_modes = Map([])
  blend_modes.set("output", _mrt_node_material_blending)
  { output_struct, output_nodes, blend_modes, clear_colors: Map([]), }
}

///|
/// `new MRTNode( outputNodes )`.
pub fn MRTNode::new(output_nodes : Map[String, Node]) -> Node {
  let node = Node::alloc()
  node.set_class(MRTNode::construct(node, output_nodes))
}

///|
pub fn MRTNode::of(node : Node) -> MRTNode? {
  match node.class_payload("MRTNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn mrt_node_payload(node : Node, method_name : String) -> MRTNode {
  match MRTNode::of(node) {
    Some(m) => m
    None => abort("\{method_name}: \{node.type_()} is not an MRTNode")
  }
}

///|
/// `setBlendMode( name, blend )`, chained.
pub fn Node::set_blend_mode(
  self : Node,
  name : String,
  blend : BlendMode,
) -> Node {
  mrt_node_payload(self, "setBlendMode").blend_modes.set(name, blend)
  self
}

///|
/// `getBlendMode( name )`: the blend mode of an output, `NoBlending` by default.
pub fn MRTNode::get_blend_mode(self : MRTNode, name : String) -> BlendMode {
  match self.blend_modes.get(name) {
    Some(b) => b
    None => _mrt_node_no_blending
  }
}

///|
/// `setClearColor( name, color, alpha = 1 )`, chained.
pub fn Node::set_clear_color(
  self : Node,
  name : String,
  color : @math.Color,
  alpha~ : Double = 1.0,
) -> Node {
  let mrt = mrt_node_payload(self, "setClearColor")
  let clear_color = match mrt.clear_colors.get(name) {
    Some(c) => c
    None => {
      let c = Color4::new()
      mrt.clear_colors.set(name, c)
      c
    }
  }
  clear_color.set_color(color) |> ignore
  clear_color.a = alpha
  self
}

///|
/// `getClearColor( name )`, or `null`.
pub fn MRTNode::get_clear_color(self : MRTNode, name : String) -> Color4? {
  self.clear_colors.get(name)
}

///|
/// `has( name )`.
pub fn MRTNode::has(self : MRTNode, name : String) -> Bool {
  self.output_nodes.contains(name)
}

///|
/// `get( name )`.
pub fn MRTNode::get(self : MRTNode, name : String) -> Node? {
  self.output_nodes.get(name)
}

///|
fn[V] mrt_node_spread(a : Map[String, V], b : Map[String, V]) -> Map[String, V] {
  let out = Map([])
  for k, v in a {
    out.set(k, v)
  }
  for k, v in b {
    out.set(k, v)
  }
  out
}

///|
/// `merge( mrtNode )`: a new MRT node with the settings of both.
pub fn MRTNode::merge(self : MRTNode, mrt_node : MRTNode) -> Node {
  let outputs = mrt_node_spread(self.output_nodes, mrt_node.output_nodes)
  let blend_modes = mrt_node_spread(self.blend_modes, mrt_node.blend_modes)
  let clear_colors = mrt_node_spread(self.clear_colors, mrt_node.clear_colors)
  let mrt_target = mrt(outputs)
  let payload = MRTNode::of(mrt_target).unwrap()
  payload.blend_modes = blend_modes
  payload.clear_colors = clear_colors
  mrt_target
}

///|
/// `mrt( outputNodes )`.
pub fn mrt(output_nodes : Map[String, Node]) -> Node {
  MRTNode::new(output_nodes)
}
