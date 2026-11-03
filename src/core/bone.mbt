// Upstream src/objects/Bone.js.

///|
/// `new Bone()`.
#external
pub type Bone

///|
pub fn Bone::new() -> Object3D {
  Object3D::new(kind=Bone, type_="Bone")
}
