// Upstream src/cameras/StereoCamera.js.

///|
let _stereo_camera_eye_right : @math.Matrix4 = @math.Matrix4::new()

///|
let _stereo_camera_eye_left : @math.Matrix4 = @math.Matrix4::new()

///|
let _stereo_camera_projection_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
/// `new StereoCamera()`.
pub fn StereoCamera::new() -> StereoCamera {
  let camera_l = PerspectiveCamera::new()
  camera_l.layers.enable(1)
  camera_l.matrix_auto_update = false
  let camera_r = PerspectiveCamera::new()
  camera_r.layers.enable(2)
  camera_r.matrix_auto_update = false
  {
    type_: "StereoCamera",
    aspect: 1.0,
    eye_sep: 0.064,
    camera_l,
    camera_r,
    _cache: {
      focus: None,
      fov: None,
      aspect: None,
      near: None,
      far: None,
      zoom: None,
      eye_sep: None,
    },
  }
}

///|
/// Updates the eye cameras from `camera`, a `PerspectiveCamera`.
pub fn StereoCamera::update(self : StereoCamera, camera : Object3D) -> Unit {
  let cache = self._cache
  let perspective = camera.as_perspective_camera()
  let camera_data = camera.camera_data()
  let aspect = perspective.aspect * self.aspect
  let needs_update = cache.focus != Some(perspective.focus) ||
    cache.fov != Some(perspective.fov) ||
    cache.aspect != Some(aspect) ||
    cache.near != Some(perspective.near) ||
    cache.far != Some(perspective.far) ||
    cache.zoom != Some(perspective.zoom) ||
    cache.eye_sep != Some(self.eye_sep)
  if needs_update {
    let focus = perspective.focus
    let fov = perspective.fov
    let near = perspective.near
    let zoom = perspective.zoom
    let eye_sep = self.eye_sep
    cache.focus = Some(focus)
    cache.fov = Some(fov)
    cache.aspect = Some(aspect)
    cache.near = Some(near)
    cache.far = Some(perspective.far)
    cache.zoom = Some(zoom)
    cache.eye_sep = Some(eye_sep)

    // Off-axis stereoscopic effect based on
    // http://paulbourke.net/stereographics/stereorender/

    ignore(_stereo_camera_projection_matrix.copy(camera_data.projection_matrix))
    let projection = _stereo_camera_projection_matrix.elements
    let eye_sep_half = eye_sep / 2.0
    let eye_sep_on_projection = eye_sep_half * near / focus
    let ymax = near * _camera_math_tan(@math.DEG2RAD * fov * 0.5) / zoom

    // translate xOffset
    _stereo_camera_eye_left.elements[12] = -eye_sep_half
    _stereo_camera_eye_right.elements[12] = eye_sep_half

    // for left eye
    let xmin = -ymax * aspect + eye_sep_on_projection
    let xmax = ymax * aspect + eye_sep_on_projection
    projection[0] = 2.0 * near / (xmax - xmin)
    projection[8] = (xmax + xmin) / (xmax - xmin)
    ignore(
      self.camera_l.camera_data().projection_matrix.copy(
        _stereo_camera_projection_matrix,
      ),
    )

    // for right eye
    let xmin = -ymax * aspect - eye_sep_on_projection
    let xmax = ymax * aspect - eye_sep_on_projection
    projection[0] = 2.0 * near / (xmax - xmin)
    projection[8] = (xmax + xmin) / (xmax - xmin)
    ignore(
      self.camera_r.camera_data().projection_matrix.copy(
        _stereo_camera_projection_matrix,
      ),
    )
  }
  ignore(
    self.camera_l.matrix
    .copy(camera.matrix_world)
    .multiply(_stereo_camera_eye_left),
  )
  self.camera_l.matrix_world_needs_update = true
  ignore(
    self.camera_r.matrix
    .copy(camera.matrix_world)
    .multiply(_stereo_camera_eye_right),
  )
  self.camera_r.matrix_world_needs_update = true
}
