///|
fn camera_test_scaled_view(
  camera : @core.Object3D,
  parent_scale : Double,
) -> @core.Object3D {
  let parent = @core.Object3D::new()
  ignore(parent.scale.set(parent_scale, parent_scale, parent_scale))
  ignore(parent.position.set(1, 2, 3))
  ignore(camera.position.set(4, 5, 6))
  ignore(camera.rotate_y(0.5))
  ignore(parent.add(camera))
  parent
}

///|
test "Camera Extending" {
  let object = @core.Camera::new()
  assert_true(object.is_camera())
  assert_true(object.kind is Camera(_))
}

///|
test "Camera type" {
  assert_eq(@core.Camera::new().type_, "Camera")
}

///|
test "Camera clone" {
  let cam = @core.Camera::new()
  let data = cam.as_camera()
  ignore(
    data.matrix_world_inverse.set(
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
    ),
  )
  ignore(
    data.projection_matrix.set(
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
    ),
  )
  let cloned = cam.clone().as_camera()
  assert_true(data.matrix_world_inverse.equals(cloned.matrix_world_inverse))
  assert_true(data.projection_matrix.equals(cloned.projection_matrix))
}

///|
test "Camera clone keeps coordinate system" {
  let cam = @core.Camera::new()
  cam.as_camera().coordinate_system = @core.WebGPUCoordinateSystem
  assert_eq(
    cam.clone().as_camera().coordinate_system,
    @core.WebGPUCoordinateSystem,
  )
}

///|
test "Camera lookAt" {
  let cam = @core.Camera::new()
  cam.look_at(vec3(0, 1, -1))
  assert_true(approx(cam.rotation.x * (180.0 / test_pi()), 45.0))
}

///|
test "Camera getWorldDirection is negated" {
  let cam = @core.Camera::new()
  let direction = cam.get_world_direction(vec3(0, 0, 0))
  assert_true(direction.equals(vec3(0, 0, -1)))
}

///|
test "Camera updateMatrixWorld strips scale from the view matrix" {
  let camera = @core.Camera::new()
  camera_test_scaled_view(camera, 2.0).update_matrix_world()
  let position = vec3(0, 0, 0)
  let quaternion = @math.Quaternion::new(0, 0, 0, 1)
  let scale = vec3(0, 0, 0)
  ignore(camera.matrix_world.decompose(position, quaternion, scale))
  assert_true(approx(scale.x, 2.0))
  let expected = @math.Matrix4::new()
    .compose(position, quaternion, vec3(1, 1, 1))
    .invert()
  assert_true(camera.as_camera().matrix_world_inverse.equals(expected))
  // the world matrix keeps its scale
  assert_false(
    camera.as_camera().matrix_world_inverse.equals(
      camera.matrix_world.clone().invert(),
    ),
  )
}

///|
test "Camera updateWorldMatrix strips scale from the view matrix" {
  let camera = @core.Camera::new()
  ignore(camera_test_scaled_view(camera, 3.0))
  camera.update_world_matrix(true, false)
  let position = vec3(0, 0, 0)
  let quaternion = @math.Quaternion::new(0, 0, 0, 1)
  let scale = vec3(0, 0, 0)
  ignore(camera.matrix_world.decompose(position, quaternion, scale))
  assert_true(approx(scale.x, 3.0))
  let expected = @math.Matrix4::new()
    .compose(position, quaternion, vec3(1, 1, 1))
    .invert()
  assert_true(camera.as_camera().matrix_world_inverse.equals(expected))
}

///|
test "Camera with unit scale inverts the world matrix directly" {
  let camera = @core.Camera::new()
  ignore(camera.position.set(1, 2, 3))
  camera.update_matrix_world()
  assert_true(
    camera.as_camera().matrix_world_inverse.equals(
      camera.matrix_world.clone().invert(),
    ),
  )
}

///|
test "Camera is a CameraMatrices for Vector3 project" {
  let camera = @core.PerspectiveCamera::new()
  camera.update_matrix_world()
  let point = vec3(1, 2, -5).project(camera).unproject(camera)
  assert_true(point.distance_to(vec3(1, 2, -5)) < 0.0001)
}

///|
test "clone ignores recursive=false on cameras, as upstream" {
  let camera = @core.PerspectiveCamera::new()
  camera.add(@core.Object3D::new()) |> ignore
  inspect(camera.clone(recursive=false).children.length(), content="1")
  let object = @core.Object3D::new()
  object.add(@core.Object3D::new()) |> ignore
  inspect(object.clone(recursive=false).children.length(), content="0")
}
