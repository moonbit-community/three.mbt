// Upstream src/cameras/OrthographicCamera.js. `OrthographicCamera` is the payload struct,
// so `OrthographicCamera::new` returns the `Object3D` that holds it.

///|
/// `new OrthographicCamera( left, right, top, bottom, near, far )`.
pub fn OrthographicCamera::new(
  left~ : Double = -1.0,
  right~ : Double = 1.0,
  top~ : Double = 1.0,
  bottom~ : Double = -1.0,
  near~ : Double = 0.1,
  far~ : Double = 2000.0,
) -> Object3D {
  let camera = Object3D::new(
    kind=Camera(
      camera_data_new(
        OrthographicCamera({
          zoom: 1.0,
          view: None,
          left,
          right,
          top,
          bottom,
          near,
          far,
        }),
      ),
    ),
    type_="OrthographicCamera",
  )
  camera.update_projection_matrix()
  camera
}

///|
/// The `OrthographicCamera` data of a camera. Aborts on other kinds.
pub fn Object3D::as_orthographic_camera(self : Object3D) -> OrthographicCamera {
  guard self.kind is Camera({ kind: OrthographicCamera(orthographic), .. }) else {
    abort("Object3D: not an OrthographicCamera")
  }
  orthographic
}

///|
fn OrthographicCamera::copy_fields(
  self : OrthographicCamera,
  source : OrthographicCamera,
) -> Unit {
  self.left = source.left
  self.right = source.right
  self.top = source.top
  self.bottom = source.bottom
  self.near = source.near
  self.far = source.far
  self.zoom = source.zoom
  self.view = match source.view {
    Some(view) => Some(view.clone())
    None => None
  }
}

///|
fn OrthographicCamera::update_projection_matrix(
  self : OrthographicCamera,
  camera : Camera,
) -> Unit {
  let dx = (self.right - self.left) / (2.0 * self.zoom)
  let dy = (self.top - self.bottom) / (2.0 * self.zoom)
  let cx = (self.right + self.left) / 2.0
  let cy = (self.top + self.bottom) / 2.0
  let mut left = cx - dx
  let mut right = cx + dx
  let mut top = cy + dy
  let mut bottom = cy - dy
  if self.view is Some(view) && view.enabled {
    let scale_w = (self.right - self.left) / view.full_width / self.zoom
    let scale_h = (self.top - self.bottom) / view.full_height / self.zoom
    left = left + scale_w * view.offset_x
    right = left + scale_w * view.width
    top = top - scale_h * view.offset_y
    bottom = top - scale_h * view.height
  }
  ignore(
    camera.projection_matrix.make_orthographic(
      left,
      right,
      top,
      bottom,
      self.near,
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
fn OrthographicCamera::add_to_json(
  self : OrthographicCamera,
  data : Map[String, Json],
) -> Unit {
  data["zoom"] = @math.json_number(self.zoom)
  data["left"] = @math.json_number(self.left)
  data["right"] = @math.json_number(self.right)
  data["top"] = @math.json_number(self.top)
  data["bottom"] = @math.json_number(self.bottom)
  data["near"] = @math.json_number(self.near)
  data["far"] = @math.json_number(self.far)
  if self.view is Some(view) {
    data["view"] = view.to_json()
  }
}
