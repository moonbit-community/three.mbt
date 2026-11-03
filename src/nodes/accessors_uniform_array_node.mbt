// nodes/accessors/UniformArrayNode.js: an array of uniforms packed into a buffer whose
// elements are padded to vec4 (or mat4).

///|
/// `UniformArrayElementNode`: one element of a uniform array.
pub(all) struct UniformArrayElementNode {
  array_element : ArrayElementNode
}

///|
pub impl NodeClass for UniformArrayElementNode with fn class_name(_) {
  "UniformArrayElementNode"
}

///|
pub impl NodeClass for UniformArrayElementNode with fn parent(self) {
  Some(self.array_element)
}

///|
pub impl NodeClass for UniformArrayElementNode with fn has_flag(self, flag) {
  flag == "isArrayBufferElementNode" || self.array_element.has_flag(flag)
}

///|
pub impl NodeClass for UniformArrayElementNode with fn generate(
  self,
  node,
  builder,
  output,
) {
  let snippet = self.array_element.generate(node, builder, output).unwrap_or("")
  let type_ = node.get_node_type(builder)
  let padded_type = UniformArrayNode::get_padded_type(
    self.array_element.node,
    builder,
  )
  Some(builder.format(snippet, Some(padded_type), type_))
}

///|
/// `new UniformArrayElementNode( uniformArrayNode, indexNode )`.
pub fn UniformArrayElementNode::new(
  uniform_array_node : Node,
  index_node : Node,
) -> Node {
  let node = Node::alloc()
  node.set_class(UniformArrayElementNode::{
    array_element: ArrayElementNode::construct(
      node, uniform_array_node, index_node,
    ),
  })
}

///|
pub fn UniformArrayElementNode::of(node : Node) -> UniformArrayElementNode? {
  match node.class_payload("UniformArrayElementNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
pub(all) struct UniformArrayNode {
  buffer : BufferNode
  /// `this.array`: the values (numbers, vectors, colors, matrices); `[]` for `null`.
  mut array : Array[TslValue]
  mut element_type : String?
}

///|
pub impl NodeClass for UniformArrayNode with fn class_name(_) {
  "UniformArrayNode"
}

///|
pub impl NodeClass for UniformArrayNode with fn parent(self) {
  Some(self.buffer)
}

///|
pub impl NodeClass for UniformArrayNode with fn has_flag(self, flag) {
  flag == "isArrayBufferNode" || self.buffer.has_flag(flag)
}

///|
pub impl NodeClass for UniformArrayNode with fn generate_node_type(
  _,
  node,
  builder,
  _,
) {
  Some(UniformArrayNode::get_padded_type(node, builder))
}

///|
pub impl NodeClass for UniformArrayNode with fn get_element_type(self, _, _) {
  self.element_type
}

///|
pub impl NodeClass for UniformArrayNode with fn update(_, node, _) {
  UniformArrayNode::update_buffer(node)
  None
}

///|
pub impl NodeClass for UniformArrayNode with fn on_update(
  self,
  node,
  callback,
  update_type,
) {
  let wrapped = fn(n : Node, frame : NodeFrame) -> Bool? {
    callback(n, frame) |> ignore
    UniformArrayNode::update_buffer(node)
    None
  }
  match self.buffer.on_update(node, wrapped, update_type) {
    Some(n) => Some(n)
    None => Some(node.on_update_base(wrapped, update_type))
  }
}

///|
pub impl NodeClass for UniformArrayNode with fn setup(self, node, builder) {
  let length = self.array.length()
  let element_type = self.element_type.unwrap_or("")
  let mut array_type : @math.TypedArrayKind = Float32Array
  let padded_type = UniformArrayNode::get_padded_type(node, builder)
  let padded_element_length = builder.get_type_length(Some(padded_type))
  if element_type.has_prefix("i") {
    array_type = Int32Array
  }
  if element_type.has_prefix("u") {
    array_type = Uint32Array
  }
  InputNode::set_value(
    node,
    Js(
      @core.JsValue::of(
        @core.TypedArray::new(array_type, length * padded_element_length),
      ),
    ),
  )
  self.buffer.buffer_count = length
  self.buffer.buffer_type = Some(padded_type)
  // initialize the buffer values
  UniformArrayNode::update_buffer(node)
  self.buffer.setup(node, builder)
}

///|
pub impl NodeClass for UniformArrayNode with fn element(_, node, index_node) {
  Some(UniformArrayElementNode::new(node, index_node))
}

///|
/// The constructor body.
pub fn UniformArrayNode::construct(
  node : Node,
  value : TslValue,
  element_type : String?,
) -> UniformArrayNode {
  let buffer = BufferNode::construct(node, Null, None, 0)
  let array = match value {
    Array(a) => a
    _ => []
  }
  let element_type = match element_type {
    Some(t) => Some(t)
    None =>
      get_value_type(
        match value {
          Array(a) if a.length() > 0 => a[0]
          _ => Undefined
        },
      )
  }
  node.update_type = NodeUpdateType::render()
  { buffer, array, element_type, }
}

///|
/// `new UniformArrayNode( value, elementType = null )`.
pub fn UniformArrayNode::new(value : TslValue, element_type? : String) -> Node {
  let node = Node::alloc()
  let u = UniformArrayNode::construct(node, value, element_type)
  u.buffer.uniform.input.class_ = u.buffer
  node.set_class(u)
}

///|
pub fn UniformArrayNode::of(node : Node) -> UniformArrayNode? {
  match node.class_payload("UniformArrayNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn uniform_array_node_payload(node : Node) -> UniformArrayNode {
  match UniformArrayNode::of(node) {
    Some(u) => u
    None => abort("TypeError: \{node.type_()} is not a UniformArrayNode")
  }
}

///|
/// `getPaddedType( builder )`: the buffer element type.
pub fn UniformArrayNode::get_padded_type(
  node : Node,
  builder : NodeBuilder,
) -> String {
  let element_type = uniform_array_node_payload(node).element_type.unwrap_or("")
  let mut padded_type = "vec4"
  if element_type == "mat2" {
    padded_type = if builder.renderer.backend.has_flag("isWebGLBackend") {
      "vec4"
    } else {
      "mat2"
    }
  } else if element_type.contains("mat") {
    padded_type = "mat4"
  } else if element_type.has_prefix("i") {
    padded_type = "ivec4"
  } else if element_type.has_prefix("u") {
    padded_type = "uvec4"
  }
  padded_type
}

///|
/// `updateBuffer()`: copies `array` into the padded `value`.
pub fn UniformArrayNode::update_buffer(node : Node) -> Unit {
  let u = uniform_array_node_payload(node)
  let array = u.array
  let value : @core.TypedArray = match InputNode::get_value(node) {
    Js(v) => v.cast()
    _ => return
  }
  let element_type = u.element_type.unwrap_or("")
  if element_type == "float" || element_type == "int" || element_type == "uint" {
    for i in 0..<array.length() {
      let index = i * 4
      value[index] = uniform_array_number(array[i])
    }
  } else if element_type == "color" {
    for i in 0..<array.length() {
      let index = i * 4
      match array[i] {
        Color(c) => {
          value[index] = c.r
          value[index + 1] = c.g
          value[index + 2] = c.b
        }
        _ => ()
      }
    }
  } else if element_type == "mat2" {
    for i in 0..<array.length() {
      let index = i * 4
      match array[i] {
        Matrix2(m) => {
          value[index] = m.elements[0]
          value[index + 1] = m.elements[1]
          value[index + 2] = m.elements[2]
          value[index + 3] = m.elements[3]
        }
        _ => ()
      }
    }
  } else if element_type == "mat3" {
    for i in 0..<array.length() {
      let index = i * 16
      match array[i] {
        Matrix3(m) => {
          value[index] = m.elements[0]
          value[index + 1] = m.elements[1]
          value[index + 2] = m.elements[2]
          value[index + 4] = m.elements[3]
          value[index + 5] = m.elements[4]
          value[index + 6] = m.elements[5]
          value[index + 8] = m.elements[6]
          value[index + 9] = m.elements[7]
          value[index + 10] = m.elements[8]
          value[index + 15] = 1.0
        }
        _ => ()
      }
    }
  } else if element_type == "mat4" {
    for i in 0..<array.length() {
      let index = i * 16
      match array[i] {
        Matrix4(m) =>
          for j in 0..<m.elements.length() {
            value[index + j] = m.elements[j]
          }
        _ => ()
      }
    }
  } else {
    for i in 0..<array.length() {
      let index = i * 4
      // `vector.z || 0`, `vector.w || 0`.
      let (x, y, z, w) = match array[i] {
        Vector2(v) => (v.x, v.y, 0.0, 0.0)
        Vector3(v) => (v.x, v.y, v.z, 0.0)
        Vector4(v) => (v.x, v.y, v.z, v.w)
        _ => (0.0 / 0.0, 0.0 / 0.0, 0.0, 0.0)
      }
      value[index] = x
      value[index + 1] = y
      value[index + 2] = if z.is_nan() { 0.0 } else { z }
      value[index + 3] = if w.is_nan() { 0.0 } else { w }
    }
  }
}

///|
fn uniform_array_number(value : TslValue) -> Double {
  match value {
    Number(x) => x
    Bool(b) => if b { 1.0 } else { 0.0 }
    _ => 0.0 / 0.0
  }
}

///|
/// `uniformArray( values, nodeType )`: `values` is an array (or `null`).
pub fn uniform_array(values : &IntoTsl, element_type? : String) -> Node {
  UniformArrayNode::new(values.to_tsl(), element_type?)
}
