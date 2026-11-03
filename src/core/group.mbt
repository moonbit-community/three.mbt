// Upstream src/objects/Group.js.

///|
/// `new Group()`.
#external
pub type Group

///|
pub fn Group::new() -> Object3D {
  Object3D::new(kind=Group, type_="Group")
}
