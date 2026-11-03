// nodes/core/constants.js

///|
/// `NodeShaderStage`.
pub(all) struct NodeShaderStage {}

///|
pub let node_shader_stage_vertex : String = "vertex"

///|
pub let node_shader_stage_fragment : String = "fragment"

///|
/// `NodeUpdateType` values.
pub(all) struct NodeUpdateType {}

///|
pub fn NodeUpdateType::none() -> String {
  "none"
}

///|
pub fn NodeUpdateType::frame() -> String {
  "frame"
}

///|
pub fn NodeUpdateType::render() -> String {
  "render"
}

///|
pub fn NodeUpdateType::object() -> String {
  "object"
}

///|
/// `NodeType` values.
pub let node_type_boolean : String = "bool"

///|
pub let node_type_integer : String = "int"

///|
pub let node_type_float : String = "float"

///|
pub let node_type_vector2 : String = "vec2"

///|
pub let node_type_vector3 : String = "vec3"

///|
pub let node_type_vector4 : String = "vec4"

///|
pub let node_type_matrix2 : String = "mat2"

///|
pub let node_type_matrix3 : String = "mat3"

///|
pub let node_type_matrix4 : String = "mat4"

///|
/// `NodeAccess` values.
pub let node_access_read_only : String = "readOnly"

///|
pub let node_access_write_only : String = "writeOnly"

///|
pub let node_access_read_write : String = "readWrite"

///|
pub let default_shader_stages : Array[String] = ["fragment", "vertex"]

///|
pub let default_build_stages : Array[String] = ["setup", "analyze", "generate"]

///|
pub let shader_stages : Array[String] = ["fragment", "vertex", "compute"]

///|
pub let vector_components : Array[String] = ["x", "y", "z", "w"]
