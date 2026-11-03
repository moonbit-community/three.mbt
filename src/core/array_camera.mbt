// Upstream src/cameras/ArrayCamera.js. `ArrayCamera` is the payload struct, so
// `ArrayCamera::new` returns the `Object3D` that holds it. Upstream's `type` stays
// `PerspectiveCamera`, and `copy` and `toJSON` are those of `PerspectiveCamera`.

///|
/// `new ArrayCamera( array )`.
pub fn ArrayCamera::new(array~ : Array[Object3D] = []) -> Object3D {
  let array_camera : ArrayCamera = {
    is_multi_view_camera: false,
    cameras: array,
    per_camera_frustum_culled: false,
  }
  let camera = Object3D::new(
    kind=Camera(
      camera_data_new(
        PerspectiveCamera(
          perspective_camera_data_new(
            50.0,
            1.0,
            0.1,
            2000.0,
            Some(array_camera),
          ),
        ),
      ),
    ),
    type_="PerspectiveCamera",
  )
  camera.update_projection_matrix()
  camera
}
