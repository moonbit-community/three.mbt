// examples/jsm/utils/CameraUtils.js

///|
let _camera_utils_va : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0) // from pe to pa

///|
let _camera_utils_vb : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0) // from pe to pb

///|
let _camera_utils_vc : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0) // from pe to pc

///|
let _camera_utils_vr : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0) // right axis of screen

///|
let _camera_utils_vu : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0) // up axis of screen

///|
let _camera_utils_vn : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0) // normal vector of screen

///|
let _camera_utils_vec : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0) // temporary vector

///|
let _camera_utils_quat : @math.Quaternion = @math.Quaternion::new(
  0.0, 0.0, 0.0, 1.0,
) // temporary quaternion

///|
extern "js" fn camera_utils_js_atan(x : Double) -> Double = "Math.atan"

///|
extern "js" fn camera_utils_js_min(a : Double, b : Double) -> Double = "Math.min"

///|
/// `frameCorners( camera, bottomLeftCorner, bottomRightCorner, topLeftCorner,
/// estimateViewFrustum = false )`: sets the camera's rotation and an off-axis projection so
/// the three corners frame the view (a generalized perspective projection).
pub fn frame_corners(
  camera : @core.Object3D,
  bottom_left_corner : @math.Vector3,
  bottom_right_corner : @math.Vector3,
  top_left_corner : @math.Vector3,
  estimate_view_frustum~ : Bool = false,
) -> Unit {
  let pa = bottom_left_corner
  let pb = bottom_right_corner
  let pc = top_left_corner
  let pe = camera.position // eye position
  let cam = camera.as_camera()
  let (n, f) = match cam.kind {
    PerspectiveCamera(p) => (p.near, p.far)
    OrthographicCamera(o) => (o.near, o.far)
    BaseCamera => (0.0 / 0.0, 0.0 / 0.0)
  }
  _camera_utils_vr.copy(pb).sub(pa).normalize() |> ignore
  _camera_utils_vu.copy(pc).sub(pa).normalize() |> ignore
  _camera_utils_vn.cross_vectors(_camera_utils_vr, _camera_utils_vu).normalize()
  |> ignore
  _camera_utils_va.copy(pa).sub(pe) |> ignore // from pe to pa
  _camera_utils_vb.copy(pb).sub(pe) |> ignore // from pe to pb
  _camera_utils_vc.copy(pc).sub(pe) |> ignore // from pe to pc
  let d = -_camera_utils_va.dot(_camera_utils_vn) // distance from eye to screen
  let l = _camera_utils_vr.dot(_camera_utils_va) * n / d // distance to left screen edge
  let r = _camera_utils_vr.dot(_camera_utils_vb) * n / d // distance to right screen edge
  let b = _camera_utils_vu.dot(_camera_utils_va) * n / d // distance to bottom screen edge
  let t = _camera_utils_vu.dot(_camera_utils_vc) * n / d // distance to top screen edge
  // Set the camera rotation to match the focal plane to the corners' plane
  _camera_utils_quat.set_from_unit_vectors(
    _camera_utils_vec.set(0.0, 1.0, 0.0),
    _camera_utils_vu,
  )
  |> ignore
  camera.quaternion
  .set_from_unit_vectors(
    _camera_utils_vec.set(0.0, 0.0, 1.0).apply_quaternion(_camera_utils_quat),
    _camera_utils_vn,
  )
  .multiply(_camera_utils_quat)
  |> ignore
  // Set the off-axis projection matrix to match the corners
  cam.projection_matrix.set(
    2.0 * n / (r - l),
    0.0,
    (r + l) / (r - l),
    0.0,
    0.0,
    2.0 * n / (t - b),
    (t + b) / (t - b),
    0.0,
    0.0,
    0.0,
    (f + n) / (n - f),
    2.0 * f * n / (n - f),
    0.0,
    0.0,
    -1.0,
    0.0,
  )
  |> ignore
  cam.projection_matrix_inverse.copy(cam.projection_matrix).invert() |> ignore
  // FoV estimation to fix frustum culling
  if estimate_view_frustum {
    // Set fieldOfView to a conservative estimate
    // to make frustum tall/wide enough to encompass it
    match cam.kind {
      PerspectiveCamera(p) =>
        p.fov = @math.RAD2DEG /
          camera_utils_js_min(1.0, p.aspect) *
          camera_utils_js_atan(
            (
              _camera_utils_vec.copy(pb).sub(pa).length() +
              _camera_utils_vec.copy(pc).sub(pa).length()
            ) /
            _camera_utils_va.length(),
          )
      _ => ()
    }
  }
}
