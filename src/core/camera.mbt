// Upstream src/cameras/Camera.js. The hooks also dispatch to the subclasses in
// perspective_camera.mbt, orthographic_camera.mbt and array_camera.mbt.

///|
let _camera_position : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _camera_quaternion : @math.Quaternion = @math.Quaternion::new(
  0.0, 0.0, 0.0, 1.0,
)

///|
let _camera_scale : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
extern "js" fn _camera_math_tan(x : Double) -> Double = "Math.tan"

///|
extern "js" fn _camera_math_atan(x : Double) -> Double = "Math.atan"

///|
/// The `Camera` fields with upstream's defaults.
fn camera_data_new(kind : CameraKind) -> Camera {
  {
    matrix_world_inverse: @math.Matrix4::new(),
    projection_matrix: @math.Matrix4::new(),
    projection_matrix_inverse: @math.Matrix4::new(),
    coordinate_system: WebGLCoordinateSystem,
    _reversed_depth: false,
    kind,
  }
}

///|
/// `new Camera()`.
pub fn Camera::new() -> Object3D {
  Object3D::new(kind=Camera(camera_data_new(BaseCamera)), type_="Camera")
}

///|
/// The `Camera` data of a camera. Aborts on other kinds.
pub fn Object3D::as_camera(self : Object3D) -> Camera {
  self.camera_data()
}

///|
/// `camera.reversedDepth`.
pub fn Object3D::reversed_depth(self : Object3D) -> Bool {
  self.camera_data()._reversed_depth
}

///|
/// The `view` a camera writes to in `setViewOffset`, with upstream's initial values.
fn CameraView::default_() -> CameraView {
  {
    enabled: true,
    full_width: 1.0,
    full_height: 1.0,
    offset_x: 0.0,
    offset_y: 0.0,
    width: 1.0,
    height: 1.0,
  }
}

///|
/// `Object.assign( {}, view )`.
pub fn CameraView::clone(self : CameraView) -> CameraView {
  { ..self, }
}

///|
fn CameraView::set_offset(
  self : CameraView,
  full_width : Double,
  full_height : Double,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit {
  self.enabled = true
  self.full_width = full_width
  self.full_height = full_height
  self.offset_x = x
  self.offset_y = y
  self.width = width
  self.height = height
}

///|
fn CameraView::to_json(self : CameraView) -> Json {
  Json::object({
    "enabled": Json::boolean(self.enabled),
    "fullWidth": @math.json_number(self.full_width),
    "fullHeight": @math.json_number(self.full_height),
    "offsetX": @math.json_number(self.offset_x),
    "offsetY": @math.json_number(self.offset_y),
    "width": @math.json_number(self.width),
    "height": @math.json_number(self.height),
  })
}

///|
/// `camera.updateProjectionMatrix()`.
pub fn Object3D::update_projection_matrix(self : Object3D) -> Unit {
  let camera = self.camera_data()
  match camera.kind {
    PerspectiveCamera(perspective) =>
      perspective.update_projection_matrix(camera)
    OrthographicCamera(orthographic) =>
      orthographic.update_projection_matrix(camera)
    BaseCamera => abort("Camera has no updateProjectionMatrix")
  }
}

///|
/// `camera.setViewOffset( fullWidth, fullHeight, x, y, width, height )`.
pub fn Object3D::set_view_offset(
  self : Object3D,
  full_width : Double,
  full_height : Double,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit {
  match self.camera_data().kind {
    PerspectiveCamera(perspective) => {
      perspective.aspect = full_width / full_height
      if perspective.view is None {
        perspective.view = Some(CameraView::default_())
      }
      if perspective.view is Some(view) {
        view.set_offset(full_width, full_height, x, y, width, height)
      }
    }
    OrthographicCamera(orthographic) => {
      if orthographic.view is None {
        orthographic.view = Some(CameraView::default_())
      }
      if orthographic.view is Some(view) {
        view.set_offset(full_width, full_height, x, y, width, height)
      }
    }
    BaseCamera => abort("Camera has no setViewOffset")
  }
  self.update_projection_matrix()
}

///|
/// `camera.clearViewOffset()`.
pub fn Object3D::clear_view_offset(self : Object3D) -> Unit {
  match self.camera_data().kind {
    PerspectiveCamera({ view: Some(view), .. })
    | OrthographicCamera({ view: Some(view), .. }) => view.enabled = false
    PerspectiveCamera(_) | OrthographicCamera(_) => ()
    BaseCamera => abort("Camera has no clearViewOffset")
  }
  self.update_projection_matrix()
}

///|
/// The view matrix excludes scale, to be glTF conformant.
fn camera_update_matrix_world_inverse(object : Object3D) -> Unit {
  let matrix_world_inverse = object.camera_data().matrix_world_inverse
  ignore(
    object.matrix_world.decompose(
      _camera_position, _camera_quaternion, _camera_scale,
    ),
  )
  if _camera_scale.x == 1.0 && _camera_scale.y == 1.0 && _camera_scale.z == 1.0 {
    ignore(matrix_world_inverse.copy(object.matrix_world).invert())
  } else {
    ignore(
      matrix_world_inverse
      .compose(
        _camera_position,
        _camera_quaternion,
        _camera_scale.set(1.0, 1.0, 1.0),
      )
      .invert(),
    )
  }
}

///|
/// Upstream `getWorldDirection`.
fn hook_camera_get_world_direction(
  object : Object3D,
  target : @math.Vector3,
) -> @math.Vector3 {
  object.get_world_direction_base(target).negate()
}

///|
/// Upstream `updateMatrixWorld`.
fn hook_camera_update_matrix_world(object : Object3D, force : Bool) -> Unit {
  object.update_matrix_world_base(force)
  camera_update_matrix_world_inverse(object)
}

///|
/// Upstream `updateWorldMatrix`.
fn hook_camera_update_world_matrix(
  object : Object3D,
  update_parents : Bool,
  update_children : Bool,
  force : Bool,
) -> Unit {
  object.update_world_matrix_base(update_parents, update_children, force)
  camera_update_matrix_world_inverse(object)
}

///|
/// `new this.constructor()`.
fn hook_camera_new_like(object : Object3D) -> Object3D {
  match object.camera_data().kind {
    BaseCamera => Camera::new()
    PerspectiveCamera({ array_camera: Some(_), .. }) => ArrayCamera::new()
    PerspectiveCamera(_) => PerspectiveCamera::new()
    OrthographicCamera(_) => OrthographicCamera::new()
  }
}

///|
/// Upstream `copy` of `Camera`, `PerspectiveCamera` and `OrthographicCamera`.
fn hook_camera_copy(
  object : Object3D,
  source : Object3D,
  recursive : Bool,
) -> Unit {
  object.copy_base(source, recursive)
  let camera = object.camera_data()
  let source_camera = source.camera_data()
  ignore(camera.matrix_world_inverse.copy(source_camera.matrix_world_inverse))
  ignore(camera.projection_matrix.copy(source_camera.projection_matrix))
  ignore(
    camera.projection_matrix_inverse.copy(
      source_camera.projection_matrix_inverse,
    ),
  )
  camera.coordinate_system = source_camera.coordinate_system
  match (camera.kind, source_camera.kind) {
    (BaseCamera, _) => ()
    (PerspectiveCamera(perspective), PerspectiveCamera(source_perspective)) =>
      perspective.copy_fields(source_perspective)
    (OrthographicCamera(orthographic), OrthographicCamera(source_orthographic)) =>
      orthographic.copy_fields(source_orthographic)
    _ => abort("Camera.copy: source has no fields of this camera's class")
  }
}

///|
/// Upstream `toJSON` of `PerspectiveCamera` and `OrthographicCamera`.
fn hook_camera_to_json(
  object : Object3D,
  _meta : ToJsonMeta,
  data : Map[String, Json],
) -> Unit {
  match object.camera_data().kind {
    BaseCamera => ()
    PerspectiveCamera(perspective) => perspective.add_to_json(data)
    OrthographicCamera(orthographic) => orthographic.add_to_json(data)
  }
}
