// Private helpers shared by the display add-ons of TSL agent A4 (not an upstream file).

///|
/// `textureNode.uvNode`: `None` when the node has no `uvNode` (not a texture node) or
/// it is `null`.
fn a4_texture_uv_node(node : @nodes.Node) -> @nodes.Node? {
  match @nodes.TextureNode::of(node) {
    Some(t) => t.uv_node
    None => None
  }
}

///|
/// `nodeObject( value )` with upstream's default parameter value for `undefined`.
fn a4_node_object_or(
  value : &@nodes.IntoTsl?,
  default : @nodes.TslValue,
) -> @nodes.Node {
  match value {
    Some(v) => @nodes.node_object(v.to_tsl())
    None => @nodes.node_object(default)
  }
}

///|
/// The `Vector2` value of a `uniform( new Vector2() )` node (`node.value`), mutated in
/// place as upstream does.
fn a4_uniform_vector2(node : @nodes.Node) -> @math.Vector2 {
  match @nodes.InputNode::get_value(node) {
    Vector2(v) => v
    _ => abort("uniform value is not a Vector2")
  }
}

///|
/// The `Vector3` value of a `uniform( new Vector3() )` node.
fn a4_uniform_vector3(node : @nodes.Node) -> @math.Vector3 {
  match @nodes.InputNode::get_value(node) {
    Vector3(v) => v
    _ => abort("uniform value is not a Vector3")
  }
}

///|
/// `node.value = x` of a number uniform.
fn a4_set_uniform_number(node : @nodes.Node, value : Double) -> Unit {
  @nodes.InputNode::set_value(node, Number(value))
}

///|
/// `node.value` of a number uniform.
fn a4_uniform_number(node : @nodes.Node) -> Double {
  match @nodes.InputNode::get_value(node) {
    Number(v) => v
    _ => abort("uniform value is not a number")
  }
}

///|
/// The `i`-th `Fn` parameter, or upstream's JS default value when it is `undefined`
/// (`( [ a, opacity = 1 ] )`: a number, not a node).
fn a4_arg_or(
  inputs : @nodes.FnInputs,
  i : Int32,
  default : @nodes.TslValue,
) -> @nodes.TslValue {
  match inputs.get(i) {
    Some(n) => Node(n)
    None => default
  }
}

///|
/// `nodeObject( options.key ) || make()`.
fn a4_option_node_or(
  options : @nodes.TslValue,
  key : String,
  make : () -> @nodes.Node,
) -> @nodes.Node {
  match addon_option(options, key) {
    Undefined | Null => make()
    v => @nodes.node_object(v)
  }
}
