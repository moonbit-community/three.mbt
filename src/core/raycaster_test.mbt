///|
fn test_get_raycaster() -> @core.Raycaster {
  @core.Raycaster::new(
    origin=vec3(0, 0, 0),
    direction=vec3(0, 0, -1),
    near=1,
    far=100,
  )
}

///|
fn test_get_sphere() -> @core.Object3D {
  @core.Mesh::new(geometry=test_sphere_geometry(32))
}

///|
fn test_get_objects_to_check() -> Array[@core.Object3D] {
  let sphere1 = test_get_sphere()
  ignore(sphere1.position.set(0, 0, -10))
  let sphere11 = test_get_sphere()
  ignore(sphere11.position.set(0, 0, 1))
  ignore(sphere1.add(sphere11))
  let sphere12 = test_get_sphere()
  ignore(sphere12.position.set(0, 0, -1))
  ignore(sphere1.add(sphere12))
  let sphere2 = test_get_sphere()
  ignore(sphere2.position.set(-5, 0, -5))
  let objects = [sphere1, sphere2]
  for object in objects {
    object.update_matrix_world()
  }
  objects
}

///|
test "Raycaster set" {
  let origin = vec3(0, 0, 0)
  let direction = vec3(0, 0, -1)
  let a = @core.Raycaster::new(
    origin=origin.clone(),
    direction=direction.clone(),
  )
  assert_true(a.ray.origin.equals(origin))
  assert_true(a.ray.direction.equals(direction))
  ignore(origin.set(1, 1, 1))
  ignore(direction.set(-1, 0, 0))
  a.set(origin, direction)
  assert_true(a.ray.origin.equals(origin))
  assert_true(a.ray.direction.equals(direction))
}

///|
test "Raycaster setFromCamera (Perspective)" {
  let raycaster = @core.Raycaster::new()
  let ray_direction = raycaster.ray.direction
  let camera = @core.PerspectiveCamera::new(fov=90, aspect=1, near=1, far=1000)
  raycaster.set_from_camera(@math.Vector2::new(0, 0), camera)
  assert_eq(
    (ray_direction.x, ray_direction.y, ray_direction.z),
    (0.0, 0.0, -1.0),
  )
  let step = 0.1
  let mut x = -1.0
  while x <= 1.0 {
    let mut y = -1.0
    while y <= 1.0 {
      raycaster.set_from_camera(@math.Vector2::new(x, y), camera)
      let ref_vector = vec3(x, y, -1).normalize()
      let epsilon = 2.220446049250313e-16
      assert_true(
        ref_vector.x - ray_direction.x <= epsilon &&
        ref_vector.y - ray_direction.y <= epsilon &&
        ref_vector.z - ray_direction.z <= epsilon,
      )
      y = y + step
    }
    x = x + step
  }
}

///|
test "Raycaster setFromCamera (Orthographic)" {
  let raycaster = @core.Raycaster::new()
  let camera = @core.OrthographicCamera::new(
    left=-1,
    right=1,
    top=1,
    bottom=-1,
    near=0,
    far=1000,
  )
  raycaster.set_from_camera(@math.Vector2::new(0, 0), camera)
  assert_true(raycaster.ray.origin.equals(vec3(0, 0, 0)))
  assert_true(raycaster.ray.direction.equals(vec3(0, 0, -1)))
}

///|
test "Raycaster setFromCamera rejects other cameras" {
  let raycaster = @core.Raycaster::new()
  let camera = @core.Group::new()
  raycaster.set_from_camera(@math.Vector2::new(0, 0), camera)
  assert_true(raycaster.camera is None)
}

///|
test "Raycaster setFromXRController" {
  let controller = @core.Group::new()
  ignore(controller.position.set(1, 2, 3))
  ignore(controller.rotate_y(test_pi() / 2.0))
  controller.update_matrix_world()
  let raycaster = @core.Raycaster::new()
  ignore(raycaster.set_from_xr_controller(controller))
  assert_true(raycaster.ray.origin.equals(vec3(1, 2, 3)))
  assert_true(approx(raycaster.ray.direction.x, -1))
  assert_true(approx(raycaster.ray.direction.z, 0))
}

///|
test "Raycaster intersectObject" {
  let raycaster = test_get_raycaster()
  let objects_to_check = test_get_objects_to_check()
  assert_eq(
    raycaster.intersect_object(objects_to_check[0], recursive=false).length(),
    1,
  )
  assert_eq(raycaster.intersect_object(objects_to_check[0]).length(), 3)
  let intersections = raycaster.intersect_object(objects_to_check[0])
  for i in 0..<(intersections.length() - 1) {
    assert_true(intersections[i].distance <= intersections[i + 1].distance)
  }
}

///|
test "Raycaster intersectObjects" {
  let raycaster = test_get_raycaster()
  let objects_to_check = test_get_objects_to_check()
  assert_eq(
    raycaster.intersect_objects(objects_to_check, recursive=false).length(),
    1,
  )
  assert_eq(raycaster.intersect_objects(objects_to_check).length(), 3)
  let intersections = raycaster.intersect_objects(objects_to_check)
  for i in 0..<(intersections.length() - 1) {
    assert_true(intersections[i].distance <= intersections[i + 1].distance)
  }
}

///|
test "Raycaster layers filter objects but not their children" {
  let raycaster = test_get_raycaster()
  let objects_to_check = test_get_objects_to_check()
  objects_to_check[0].layers.set(1)
  assert_eq(raycaster.intersect_object(objects_to_check[0]).length(), 2)
}

///|
test "Raycaster keeps the hits of the array passed in" {
  let raycaster = test_get_raycaster()
  let objects_to_check = test_get_objects_to_check()
  let intersects = []
  ignore(
    raycaster.intersect_object(
      objects_to_check[0],
      recursive=false,
      intersects~,
    ),
  )
  let result = raycaster.intersect_object(
    objects_to_check[0],
    recursive=false,
    intersects~,
  )
  assert_true(physical_equal(result, intersects))
  assert_eq(intersects.length(), 2)
}

///|
fn test_front_and_behind() -> (@core.Object3D, @core.Object3D) {
  let front = test_get_sphere()
  ignore(front.position.set(0, 0, -5))
  front.update_matrix_world()
  let behind = test_get_sphere()
  ignore(behind.position.set(0, 0, 5))
  behind.update_matrix_world()
  (front, behind)
}

///|
test "Raycaster intersectObject (Perspective, WebGPU coordinate system)" {
  let camera = @core.PerspectiveCamera::new(fov=90, aspect=1, near=0.1, far=100)
  guard camera.kind is Camera(data) else { fail("not a camera") }
  data.coordinate_system = @math.WebGPUCoordinateSystem
  camera.update_projection_matrix()
  let (front, behind) = test_front_and_behind()
  let raycaster = @core.Raycaster::new()
  raycaster.set_from_camera(@math.Vector2::new(0, 0), camera)
  assert_eq(raycaster.intersect_object(front).length(), 1)
  assert_eq(raycaster.intersect_object(behind).length(), 0)
}

///|
test "Raycaster intersectObject (Orthographic, WebGPU coordinate system)" {
  let camera = @core.OrthographicCamera::new(
    left=-1,
    right=1,
    top=1,
    bottom=-1,
    near=0.1,
    far=10,
  )
  guard camera.kind is Camera(data) else { fail("not a camera") }
  data.coordinate_system = @math.WebGPUCoordinateSystem
  camera.update_projection_matrix()
  let (front, behind) = test_front_and_behind()
  let raycaster = @core.Raycaster::new()
  raycaster.set_from_camera(@math.Vector2::new(0, 0), camera)
  assert_eq(raycaster.intersect_object(front).length(), 1)
  assert_eq(raycaster.intersect_object(behind).length(), 0)
}

///|
test "Raycaster intersectObject (Perspective, reversed depth)" {
  let camera = @core.PerspectiveCamera::new(fov=90, aspect=1, near=0.1, far=100)
  guard camera.kind is Camera(data) else { fail("not a camera") }
  data._reversed_depth = true
  camera.update_projection_matrix()
  let (front, behind) = test_front_and_behind()
  let raycaster = @core.Raycaster::new()
  raycaster.set_from_camera(@math.Vector2::new(0, 0), camera)
  assert_eq(raycaster.intersect_object(front).length(), 1)
  assert_eq(raycaster.intersect_object(behind).length(), 0)
}

///|
test "Raycaster intersectObject (Orthographic, reversed depth)" {
  let camera = @core.OrthographicCamera::new(
    left=-1,
    right=1,
    top=1,
    bottom=-1,
    near=0.1,
    far=10,
  )
  guard camera.kind is Camera(data) else { fail("not a camera") }
  data._reversed_depth = true
  camera.update_projection_matrix()
  let (front, behind) = test_front_and_behind()
  let raycaster = @core.Raycaster::new()
  raycaster.set_from_camera(@math.Vector2::new(0, 0), camera)
  assert_eq(raycaster.intersect_object(front).length(), 1)
  assert_eq(raycaster.intersect_object(behind).length(), 0)
}

///|
test "Raycaster Line intersection threshold" {
  let raycaster = test_get_raycaster()
  let points = [vec3(-2, -10, -5), vec3(-2, 10, -5)]
  let geometry = @core.BufferGeometry::new().set_from_points(points)
  let line = @core.Line::new(geometry~)
  raycaster.params.line.threshold = 1.999
  assert_eq(raycaster.intersect_object(line).length(), 0)
  raycaster.params.line.threshold = 2.001
  assert_eq(raycaster.intersect_object(line).length(), 1)
}

///|
test "Raycaster Points intersection threshold" {
  let raycaster = test_get_raycaster()
  let coordinates = [vec3(-2, 0, -5)]
  let geometry = @core.BufferGeometry::new().set_from_points(coordinates)
  let points = @core.Points::new(geometry~)
  raycaster.params.points.threshold = 1.999
  assert_eq(raycaster.intersect_object(points).length(), 0)
  raycaster.params.points.threshold = 2.001
  assert_eq(raycaster.intersect_object(points).length(), 1)
}
