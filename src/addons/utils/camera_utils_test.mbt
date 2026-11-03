// CameraUtils.frameCorners against upstream: with CAMERA_UTILS_DIFF=1 the test prints one
// line per case (quaternion, projection matrix, its inverse, fov), compared with
// diff/addons/tsl/a5/camera_utils/upstream.mjs by compare.sh; on its own it checks one case.

///|
extern "js" fn camera_utils_diff_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.CAMERA_UTILS_DIFF === '1'"

///|
extern "js" fn camera_utils_line(values : FixedArray[Double]) -> String = "(v) => JSON.stringify(Array.from(v))"

///|
fn camera_utils_case(
  camera : @core.Object3D,
  corners : Array[Double],
  estimate : Bool,
) -> String {
  let v = fn(i : Int32) {
    @math.Vector3::new(corners[i], corners[i + 1], corners[i + 2])
  }
  @utils.frame_corners(camera, v(0), v(3), v(6), estimate_view_frustum=estimate)
  let q = camera.quaternion
  let cam = camera.as_camera()
  let out = [q.x, q.y, q.z, q.w]
  out.append(cam.projection_matrix.elements)
  out.append(cam.projection_matrix_inverse.elements)
  match cam.kind {
    PerspectiveCamera(p) => out.push(p.fov)
    _ => out.push(-1.0)
  }
  camera_utils_line(FixedArray::from_array(out))
}

///|
fn camera_utils_cases() -> Array[String] {
  let lines = []
  let corner_sets = [
    [-1.0, -1.0, -2.0, 1.0, -1.0, -2.0, -1.0, 1.0, -2.0],
    [-0.5, -0.3, -3.0, 0.7, -0.2, -3.1, -0.4, 0.9, -2.8],
    [2.0, 0.0, 1.0, 2.0, 0.0, -1.0, 2.0, 1.5, 1.0],
    [-3.0, -1.0, 4.0, -1.0, -1.0, 5.0, -3.0, 2.0, 4.5],
  ]
  let positions = [(0.0, 0.0, 0.0), (0.3, -0.2, 0.5), (-1.0, 2.0, 3.0)]
  for corners in corner_sets {
    for p in positions {
      for estimate in [false, true] {
        for aspect in [0.5, 1.0, 1.7777777777777777] {
          let camera = @core.PerspectiveCamera::new(
            fov=60.0,
            aspect~,
            near=0.1,
            far=50.0,
          )
          camera.position.set(p.0, p.1, p.2) |> ignore
          lines.push(camera_utils_case(camera, corners, estimate))
        }
      }
      let ortho = @core.OrthographicCamera::new(near=0.5, far=20.0)
      ortho.position.set(p.0, p.1, p.2) |> ignore
      lines.push(camera_utils_case(ortho, corners, true))
    }
  }
  lines
}

///|
test "frameCorners matches upstream (CAMERA_UTILS_DIFF=1 prints the cases)" {
  let lines = camera_utils_cases()
  if camera_utils_diff_enabled() {
    for line in lines {
      println("@@CAM " + line)
    }
  }
  // the first case: a square screen at z = -2 seen from the origin
  let camera = @core.PerspectiveCamera::new(
    fov=60.0,
    aspect=1.0,
    near=0.1,
    far=50.0,
  )
  @utils.frame_corners(
    camera,
    @math.Vector3::new(-1.0, -1.0, -2.0),
    @math.Vector3::new(1.0, -1.0, -2.0),
    @math.Vector3::new(-1.0, 1.0, -2.0),
  )
  let e = camera.as_camera().projection_matrix.elements
  assert_true((e[0] - 2.0).abs() < 1.0e-12)
  assert_true((e[5] - 2.0).abs() < 1.0e-12)
  assert_eq(e[11], -1.0)
}
