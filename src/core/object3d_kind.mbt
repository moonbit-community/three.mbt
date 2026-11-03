// Upstream `isFoo` checks and common accessors over `Object3D.kind`. Classes above core
// answer flags through `Object3D::has_extension_flag`.

///|
/// `isCamera`.
pub fn Object3D::is_camera(self : Object3D) -> Bool {
  self.kind is Camera(_)
}

///|
/// `isPerspectiveCamera`; also true for `ArrayCamera`.
pub fn Object3D::is_perspective_camera(self : Object3D) -> Bool {
  self.kind is Camera({ kind: PerspectiveCamera(_), .. })
}

///|
/// `isOrthographicCamera`.
pub fn Object3D::is_orthographic_camera(self : Object3D) -> Bool {
  self.kind is Camera({ kind: OrthographicCamera(_), .. })
}

///|
/// `isArrayCamera`.
pub fn Object3D::is_array_camera(self : Object3D) -> Bool {
  self.kind
  is Camera({ kind: PerspectiveCamera({ array_camera: Some(_), .. }), .. })
}

///|
/// `isLight`.
pub fn Object3D::is_light(self : Object3D) -> Bool {
  self.kind is Light(_)
}

///|
/// `isMesh`; also true for skinned, instanced and batched meshes.
pub fn Object3D::is_mesh(self : Object3D) -> Bool {
  self.kind is Mesh(_)
}

///|
/// `isSkinnedMesh`.
pub fn Object3D::is_skinned_mesh(self : Object3D) -> Bool {
  self.kind is Mesh({ kind: SkinnedMesh(_), .. })
}

///|
/// `isInstancedMesh`.
pub fn Object3D::is_instanced_mesh(self : Object3D) -> Bool {
  self.kind is Mesh({ kind: InstancedMesh(_), .. })
}

///|
/// `isBatchedMesh`.
pub fn Object3D::is_batched_mesh(self : Object3D) -> Bool {
  self.kind is Mesh({ kind: BatchedMesh(_), .. })
}

///|
/// `isLine`; also true for `LineLoop` and `LineSegments`.
pub fn Object3D::is_line(self : Object3D) -> Bool {
  self.kind is Line(_)
}

///|
/// `isLineLoop`.
pub fn Object3D::is_line_loop(self : Object3D) -> Bool {
  self.kind is Line({ kind: LineLoop, .. })
}

///|
/// `isLineSegments`.
pub fn Object3D::is_line_segments(self : Object3D) -> Bool {
  self.kind is Line({ kind: LineSegments, .. })
}

///|
/// `isPoints`.
pub fn Object3D::is_points(self : Object3D) -> Bool {
  self.kind is Points(_)
}

///|
/// `isSprite`.
pub fn Object3D::is_sprite(self : Object3D) -> Bool {
  self.kind is Sprite(_)
}

///|
/// `isLOD`.
pub fn Object3D::is_lod(self : Object3D) -> Bool {
  self.kind is LOD(_)
}

///|
/// `isGroup`; also true for `ClippingGroup`.
pub fn Object3D::is_group(self : Object3D) -> Bool {
  self.kind is (Group | ClippingGroup(_))
}

///|
/// `isClippingGroup`.
pub fn Object3D::is_clipping_group(self : Object3D) -> Bool {
  self.kind is ClippingGroup(_)
}

///|
/// `isBone`.
pub fn Object3D::is_bone(self : Object3D) -> Bool {
  self.kind is Bone
}

///|
/// `isScene`.
pub fn Object3D::is_scene(self : Object3D) -> Bool {
  self.kind is Scene(_)
}

///|
/// `object.geometry`, for the classes that have one.
pub fn Object3D::get_geometry(self : Object3D) -> BufferGeometry? {
  match self.kind {
    Mesh(mesh) => Some(mesh.geometry)
    Line(line) => Some(line.geometry)
    Points(points) => Some(points.geometry)
    Sprite(sprite) => Some(sprite.geometry)
    _ => None
  }
}

///|
/// `object.material`, for the classes that have one.
pub fn Object3D::get_material(self : Object3D) -> MaterialSlot? {
  match self.kind {
    Mesh(mesh) => Some(mesh.material)
    Line(line) => Some(line.material)
    Points(points) => Some(points.material)
    Sprite(sprite) => Some(Single(sprite.material))
    _ => None
  }
}

///|
/// `object.morphTargetDictionary` and `object.morphTargetInfluences`.
pub fn Object3D::morph_targets(
  self : Object3D,
) -> (Map[String, Int32]?, Array[Double]?) {
  match self.kind {
    Mesh(mesh) => (mesh.morph_target_dictionary, mesh.morph_target_influences)
    Line(line) => (line.morph_target_dictionary, line.morph_target_influences)
    Points(points) =>
      (points.morph_target_dictionary, points.morph_target_influences)
    _ => (None, None)
  }
}

///|
fn Object3D::camera_data(self : Object3D) -> Camera {
  guard self.kind is Camera(camera) else { abort("Object3D: not a camera") }
  camera
}

///|
/// Lets `Vector3::project` and `unproject` take a camera. Aborts on other kinds.
pub impl @math.CameraMatrices for Object3D with fn matrix_world(self) {
  self.matrix_world
}

///|
pub impl @math.CameraMatrices for Object3D with fn matrix_world_inverse(self) {
  self.camera_data().matrix_world_inverse
}

///|
pub impl @math.CameraMatrices for Object3D with fn projection_matrix(self) {
  self.camera_data().projection_matrix
}

///|
pub impl @math.CameraMatrices for Object3D with fn projection_matrix_inverse(
  self,
) {
  self.camera_data().projection_matrix_inverse
}

///|
pub extend Object3D with @math.CameraMatrices::{
  matrix_world,
  matrix_world_inverse,
  projection_matrix,
  projection_matrix_inverse,
}
