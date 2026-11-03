// renderers/common/nodes/NodeUniform.js: the uniforms of a node builder, which read
// their value and type from a `NodeUniform`.

///|
pub(all) struct NumberNodeUniform {
  parent_ : NumberUniform
  node_uniform : NodeUniform
}

///|
pub impl UniformClass for NumberNodeUniform with fn class_name(_) {
  "NumberNodeUniform"
}

///|
pub impl UniformClass for NumberNodeUniform with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl UniformClass for NumberNodeUniform with fn get_value(self, _) {
  self.node_uniform.value()
}

///|
pub impl UniformClass for NumberNodeUniform with fn get_type(self, _) {
  self.node_uniform.type_
}

///|
/// `new NumberNodeUniform( nodeUniform )`.
pub fn NumberNodeUniform::new(node_uniform : NodeUniform) -> Uniform {
  let uniform = NumberUniform::new(
    node_uniform.name,
    value=node_uniform.value(),
  )
  uniform.class_ = NumberNodeUniform::{
    parent_: NumberUniform::{ },
    node_uniform,
  }
  uniform
}

///|
pub fn NumberNodeUniform::of(uniform : Uniform) -> NumberNodeUniform? {
  match uniform.class_payload("NumberNodeUniform") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
pub(all) struct Vector2NodeUniform {
  parent_ : Vector2Uniform
  node_uniform : NodeUniform
}

///|
pub impl UniformClass for Vector2NodeUniform with fn class_name(_) {
  "Vector2NodeUniform"
}

///|
pub impl UniformClass for Vector2NodeUniform with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl UniformClass for Vector2NodeUniform with fn get_value(self, _) {
  self.node_uniform.value()
}

///|
pub impl UniformClass for Vector2NodeUniform with fn get_type(self, _) {
  self.node_uniform.type_
}

///|
/// `new Vector2NodeUniform( nodeUniform )`.
pub fn Vector2NodeUniform::new(node_uniform : NodeUniform) -> Uniform {
  let uniform = Vector2Uniform::new(
    node_uniform.name,
    value=node_uniform.value(),
  )
  uniform.class_ = Vector2NodeUniform::{
    parent_: Vector2Uniform::{ },
    node_uniform,
  }
  uniform
}

///|
pub fn Vector2NodeUniform::of(uniform : Uniform) -> Vector2NodeUniform? {
  match uniform.class_payload("Vector2NodeUniform") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
pub(all) struct Vector3NodeUniform {
  parent_ : Vector3Uniform
  node_uniform : NodeUniform
}

///|
pub impl UniformClass for Vector3NodeUniform with fn class_name(_) {
  "Vector3NodeUniform"
}

///|
pub impl UniformClass for Vector3NodeUniform with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl UniformClass for Vector3NodeUniform with fn get_value(self, _) {
  self.node_uniform.value()
}

///|
pub impl UniformClass for Vector3NodeUniform with fn get_type(self, _) {
  self.node_uniform.type_
}

///|
/// `new Vector3NodeUniform( nodeUniform )`.
pub fn Vector3NodeUniform::new(node_uniform : NodeUniform) -> Uniform {
  let uniform = Vector3Uniform::new(
    node_uniform.name,
    value=node_uniform.value(),
  )
  uniform.class_ = Vector3NodeUniform::{
    parent_: Vector3Uniform::{ },
    node_uniform,
  }
  uniform
}

///|
pub fn Vector3NodeUniform::of(uniform : Uniform) -> Vector3NodeUniform? {
  match uniform.class_payload("Vector3NodeUniform") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
pub(all) struct Vector4NodeUniform {
  parent_ : Vector4Uniform
  node_uniform : NodeUniform
}

///|
pub impl UniformClass for Vector4NodeUniform with fn class_name(_) {
  "Vector4NodeUniform"
}

///|
pub impl UniformClass for Vector4NodeUniform with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl UniformClass for Vector4NodeUniform with fn get_value(self, _) {
  self.node_uniform.value()
}

///|
pub impl UniformClass for Vector4NodeUniform with fn get_type(self, _) {
  self.node_uniform.type_
}

///|
/// `new Vector4NodeUniform( nodeUniform )`.
pub fn Vector4NodeUniform::new(node_uniform : NodeUniform) -> Uniform {
  let uniform = Vector4Uniform::new(
    node_uniform.name,
    value=node_uniform.value(),
  )
  uniform.class_ = Vector4NodeUniform::{
    parent_: Vector4Uniform::{ },
    node_uniform,
  }
  uniform
}

///|
pub fn Vector4NodeUniform::of(uniform : Uniform) -> Vector4NodeUniform? {
  match uniform.class_payload("Vector4NodeUniform") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
pub(all) struct ColorNodeUniform {
  parent_ : ColorUniform
  node_uniform : NodeUniform
}

///|
pub impl UniformClass for ColorNodeUniform with fn class_name(_) {
  "ColorNodeUniform"
}

///|
pub impl UniformClass for ColorNodeUniform with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl UniformClass for ColorNodeUniform with fn get_value(self, _) {
  self.node_uniform.value()
}

///|
pub impl UniformClass for ColorNodeUniform with fn get_type(self, _) {
  self.node_uniform.type_
}

///|
/// `new ColorNodeUniform( nodeUniform )`.
pub fn ColorNodeUniform::new(node_uniform : NodeUniform) -> Uniform {
  let uniform = ColorUniform::new(node_uniform.name, value=node_uniform.value())
  uniform.class_ = ColorNodeUniform::{
    parent_: ColorUniform::{ },
    node_uniform,
  }
  uniform
}

///|
pub fn ColorNodeUniform::of(uniform : Uniform) -> ColorNodeUniform? {
  match uniform.class_payload("ColorNodeUniform") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
pub(all) struct Matrix2NodeUniform {
  parent_ : Matrix2Uniform
  node_uniform : NodeUniform
}

///|
pub impl UniformClass for Matrix2NodeUniform with fn class_name(_) {
  "Matrix2NodeUniform"
}

///|
pub impl UniformClass for Matrix2NodeUniform with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl UniformClass for Matrix2NodeUniform with fn get_value(self, _) {
  self.node_uniform.value()
}

///|
pub impl UniformClass for Matrix2NodeUniform with fn get_type(self, _) {
  self.node_uniform.type_
}

///|
/// `new Matrix2NodeUniform( nodeUniform )`.
pub fn Matrix2NodeUniform::new(node_uniform : NodeUniform) -> Uniform {
  let uniform = Matrix2Uniform::new(
    node_uniform.name,
    value=node_uniform.value(),
  )
  uniform.class_ = Matrix2NodeUniform::{
    parent_: Matrix2Uniform::{ },
    node_uniform,
  }
  uniform
}

///|
pub fn Matrix2NodeUniform::of(uniform : Uniform) -> Matrix2NodeUniform? {
  match uniform.class_payload("Matrix2NodeUniform") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
pub(all) struct Matrix3NodeUniform {
  parent_ : Matrix3Uniform
  node_uniform : NodeUniform
}

///|
pub impl UniformClass for Matrix3NodeUniform with fn class_name(_) {
  "Matrix3NodeUniform"
}

///|
pub impl UniformClass for Matrix3NodeUniform with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl UniformClass for Matrix3NodeUniform with fn get_value(self, _) {
  self.node_uniform.value()
}

///|
pub impl UniformClass for Matrix3NodeUniform with fn get_type(self, _) {
  self.node_uniform.type_
}

///|
/// `new Matrix3NodeUniform( nodeUniform )`.
pub fn Matrix3NodeUniform::new(node_uniform : NodeUniform) -> Uniform {
  let uniform = Matrix3Uniform::new(
    node_uniform.name,
    value=node_uniform.value(),
  )
  uniform.class_ = Matrix3NodeUniform::{
    parent_: Matrix3Uniform::{ },
    node_uniform,
  }
  uniform
}

///|
pub fn Matrix3NodeUniform::of(uniform : Uniform) -> Matrix3NodeUniform? {
  match uniform.class_payload("Matrix3NodeUniform") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
pub(all) struct Matrix4NodeUniform {
  parent_ : Matrix4Uniform
  node_uniform : NodeUniform
}

///|
pub impl UniformClass for Matrix4NodeUniform with fn class_name(_) {
  "Matrix4NodeUniform"
}

///|
pub impl UniformClass for Matrix4NodeUniform with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl UniformClass for Matrix4NodeUniform with fn get_value(self, _) {
  self.node_uniform.value()
}

///|
pub impl UniformClass for Matrix4NodeUniform with fn get_type(self, _) {
  self.node_uniform.type_
}

///|
/// `new Matrix4NodeUniform( nodeUniform )`.
pub fn Matrix4NodeUniform::new(node_uniform : NodeUniform) -> Uniform {
  let uniform = Matrix4Uniform::new(
    node_uniform.name,
    value=node_uniform.value(),
  )
  uniform.class_ = Matrix4NodeUniform::{
    parent_: Matrix4Uniform::{ },
    node_uniform,
  }
  uniform
}

///|
pub fn Matrix4NodeUniform::of(uniform : Uniform) -> Matrix4NodeUniform? {
  match uniform.class_payload("Matrix4NodeUniform") {
    Some(p) => Some(p.cast())
    None => None
  }
}
