// Upstream src/cameras/PerspectiveCamera.js. `PerspectiveCamera` is the payload struct, so
// `PerspectiveCamera::new` returns the `Object3D` that holds it.

///|
let _perspective_camera_v3 : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _perspective_camera_min_target : @math.Vector2 = @math.Vector2::new(
  0.0, 0.0,
)

///|
let _perspective_camera_max_target : @math.Vector2 = @math.Vector2::new(
  0.0, 0.0,
)

///|
extern "js" fn _perspective_camera_math_min(a : Double, b : Double) -> Double = "Math.min"

///|
extern "js" fn _perspective_camera_math_max(a : Double, b : Double) -> Double = "Math.max"

///|
/// The `PerspectiveCamera` fields with upstream's defaults.
fn perspective_camera_data_new(
  fov : Double,
  aspect : Double,
  near : Double,
  far : Double,
  array_camera : ArrayCamera?,
) -> PerspectiveCamera {
  {
    fov,
    zoom: 1.0,
    near,
    far,
    focus: 10.0,
    aspect,
    view: None,
    film_gauge: 35.0,
    film_offset: 0.0,
    array_camera,
  }
}

///|
/// `new PerspectiveCamera( fov, aspect, near, far )`.
pub fn PerspectiveCamera::new(
  fov~ : Double = 50.0,
  aspect~ : Double = 1.0,
  near~ : Double = 0.1,
  far~ : Double = 2000.0,
) -> Object3D {
  let camera = Object3D::new(
    kind=Camera(
      camera_data_new(
        PerspectiveCamera(
          perspective_camera_data_new(fov, aspect, near, far, None),
        ),
      ),
    ),
    type_="PerspectiveCamera",
  )
  camera.update_projection_matrix()
  camera
}

///|
/// The `PerspectiveCamera` data of a camera. Aborts on other kinds.
pub fn Object3D::as_perspective_camera(self : Object3D) -> PerspectiveCamera {
  guard self.kind is Camera({ kind: PerspectiveCamera(perspective), .. }) else {
    abort("Object3D: not a PerspectiveCamera")
  }
  perspective
}

///|
fn PerspectiveCamera::copy_fields(
  self : PerspectiveCamera,
  source : PerspectiveCamera,
) -> Unit {
  self.fov = source.fov
  self.zoom = source.zoom
  self.near = source.near
  self.far = source.far
  self.focus = source.focus
  self.aspect = source.aspect
  self.view = match source.view {
    Some(view) => Some(view.clone())
    None => None
  }
  self.film_gauge = source.film_gauge
  self.film_offset = source.film_offset
}

///|
/// `camera.setFocalLength( focalLength )`.
pub fn Object3D::set_focal_length(
  self : Object3D,
  focal_length : Double,
) -> Unit {
  // see {@link http://www.bobatkins.com/photography/technical/field_of_view.html}
  let v_extent_slope = 0.5 * self.get_film_height() / focal_length
  self.as_perspective_camera().fov = @math.RAD2DEG *
    2.0 *
    _camera_math_atan(v_extent_slope)
  self.update_projection_matrix()
}

///|
/// `camera.getFocalLength()`.
pub fn Object3D::get_focal_length(self : Object3D) -> Double {
  let v_extent_slope = _camera_math_tan(
    @math.DEG2RAD * 0.5 * self.as_perspective_camera().fov,
  )
  0.5 * self.get_film_height() / v_extent_slope
}

///|
/// `camera.getEffectiveFOV()`.
pub fn Object3D::get_effective_fov(self : Object3D) -> Double {
  let perspective = self.as_perspective_camera()
  @math.RAD2DEG *
  2.0 *
  _camera_math_atan(
    _camera_math_tan(@math.DEG2RAD * 0.5 * perspective.fov) / perspective.zoom,
  )
}

///|
fn PerspectiveCamera::film_width(self : PerspectiveCamera) -> Double {
  // film not completely covered in portrait format (aspect < 1)
  self.film_gauge * _perspective_camera_math_min(self.aspect, 1.0)
}

///|
/// `camera.getFilmWidth()`.
pub fn Object3D::get_film_width(self : Object3D) -> Double {
  self.as_perspective_camera().film_width()
}

///|
/// `camera.getFilmHeight()`.
pub fn Object3D::get_film_height(self : Object3D) -> Double {
  // film not completely covered in landscape format (aspect > 1)
  let perspective = self.as_perspective_camera()
  perspective.film_gauge / _perspective_camera_math_max(perspective.aspect, 1.0)
}

///|
/// `camera.getViewBounds( distance, minTarget, maxTarget )`.
pub fn Object3D::get_view_bounds(
  self : Object3D,
  distance : Double,
  min_target : @math.Vector2,
  max_target : @math.Vector2,
) -> Unit {
  let projection_matrix_inverse = self.camera_data().projection_matrix_inverse
  ignore(
    _perspective_camera_v3
    .set(-1.0, -1.0, 0.5)
    .apply_matrix4(projection_matrix_inverse),
  )
  ignore(
    min_target
    .set(_perspective_camera_v3.x, _perspective_camera_v3.y)
    .multiply_scalar(-distance / _perspective_camera_v3.z),
  )
  ignore(
    _perspective_camera_v3
    .set(1.0, 1.0, 0.5)
    .apply_matrix4(projection_matrix_inverse),
  )
  ignore(
    max_target
    .set(_perspective_camera_v3.x, _perspective_camera_v3.y)
    .multiply_scalar(-distance / _perspective_camera_v3.z),
  )
}

///|
/// `camera.getViewSize( distance, target )`.
pub fn Object3D::get_view_size(
  self : Object3D,
  distance : Double,
  target : @math.Vector2,
) -> @math.Vector2 {
  self.get_view_bounds(
    distance, _perspective_camera_min_target, _perspective_camera_max_target,
  )
  target.sub_vectors(
    _perspective_camera_max_target, _perspective_camera_min_target,
  )
}

///|
fn PerspectiveCamera::update_projection_matrix(
  self : PerspectiveCamera,
  camera : Camera,
) -> Unit {
  let near = self.near
  let mut top = near *
    _camera_math_tan(@math.DEG2RAD * 0.5 * self.fov) /
    self.zoom
  let mut height = 2.0 * top
  let mut width = self.aspect * height
  let mut left = -0.5 * width
  if self.view is Some(view) && view.enabled {
    let full_width = view.full_width
    let full_height = view.full_height
    left = left + view.offset_x * width / full_width
    top = top - view.offset_y * height / full_height
    width = width * (view.width / full_width)
    height = height * (view.height / full_height)
  }
  let skew = self.film_offset
  if skew != 0.0 {
    left = left + near * skew / self.film_width()
  }
  ignore(
    camera.projection_matrix.make_perspective(
      left,
      left + width,
      top,
      top - height,
      near,
      self.far,
      coordinate_system=camera.coordinate_system,
      reversed_depth=camera._reversed_depth,
    ),
  )
  ignore(
    camera.projection_matrix_inverse.copy(camera.projection_matrix).invert(),
  )
}

///|
fn PerspectiveCamera::add_to_json(
  self : PerspectiveCamera,
  data : Map[String, Json],
) -> Unit {
  data["fov"] = @math.json_number(self.fov)
  data["zoom"] = @math.json_number(self.zoom)
  data["near"] = @math.json_number(self.near)
  data["far"] = @math.json_number(self.far)
  data["focus"] = @math.json_number(self.focus)
  data["aspect"] = @math.json_number(self.aspect)
  if self.view is Some(view) {
    data["view"] = view.to_json()
  }
  data["filmGauge"] = @math.json_number(self.film_gauge)
  data["filmOffset"] = @math.json_number(self.film_offset)
}
