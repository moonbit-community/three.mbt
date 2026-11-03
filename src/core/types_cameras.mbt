// Types for upstream src/cameras.

///|
/// The subclass of a `Camera`. `ArrayCamera` extends `PerspectiveCamera`, so it is
/// `PerspectiveCamera` with `array_camera` set.
pub(all) enum CameraKind {
  BaseCamera
  PerspectiveCamera(PerspectiveCamera)
  OrthographicCamera(OrthographicCamera)
}

///|
pub(all) struct Camera {
  mut matrix_world_inverse : @math.Matrix4
  mut projection_matrix : @math.Matrix4
  mut projection_matrix_inverse : @math.Matrix4
  mut coordinate_system : Int32
  mut _reversed_depth : Bool
  mut kind : CameraKind
}

///|
/// The `view` set by `setViewOffset`.
pub(all) struct CameraView {
  mut enabled : Bool
  mut full_width : Double
  mut full_height : Double
  mut offset_x : Double
  mut offset_y : Double
  mut width : Double
  mut height : Double
}

///|
pub(all) struct PerspectiveCamera {
  mut fov : Double
  mut zoom : Double
  mut near : Double
  mut far : Double
  mut focus : Double
  mut aspect : Double
  mut view : CameraView?
  mut film_gauge : Double
  mut film_offset : Double
  mut array_camera : ArrayCamera?
}

///|
pub(all) struct ArrayCamera {
  mut is_multi_view_camera : Bool
  mut cameras : Array[Object3D]
  mut per_camera_frustum_culled : Bool
}

///|
pub(all) struct OrthographicCamera {
  mut zoom : Double
  mut view : CameraView?
  mut left : Double
  mut right : Double
  mut top : Double
  mut bottom : Double
  mut near : Double
  mut far : Double
}

///|
/// `coordinate_system` is `null` until `updateCoordinateSystem` runs.
pub(all) struct CubeCamera {
  mut render_target : RenderTarget?
  mut coordinate_system : Int32?
  mut active_mipmap_level : Int32
}

///|
/// The `_cache` of `StereoCamera`; `None` until the first update.
pub(all) struct StereoCameraCache {
  mut focus : Double?
  mut fov : Double?
  mut aspect : Double?
  mut near : Double?
  mut far : Double?
  mut zoom : Double?
  mut eye_sep : Double?
}

///|
/// Not an `Object3D` upstream either. `camera_l` and `camera_r` are perspective cameras.
pub(all) struct StereoCamera {
  mut type_ : String
  mut aspect : Double
  mut eye_sep : Double
  mut camera_l : Object3D
  mut camera_r : Object3D
  _cache : StereoCameraCache
}
