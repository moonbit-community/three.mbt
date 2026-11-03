///|
struct CubeCameraTestRenderer {
  log : Array[String]
  coordinate_system : Int32
  mut target : @core.RenderTarget?
  mut face : Int32
  mut level : Int32
  mut xr : Bool
  reversed : Bool
  mut auto_clear : Bool
}

///|
impl @core.CubeCameraRenderer for CubeCameraTestRenderer with fn coordinate_system(
  self,
) {
  self.coordinate_system
}

///|
impl @core.CubeCameraRenderer for CubeCameraTestRenderer with fn get_render_target(
  self,
) {
  self.target
}

///|
impl @core.CubeCameraRenderer for CubeCameraTestRenderer with fn get_active_cube_face(
  self,
) {
  self.face
}

///|
impl @core.CubeCameraRenderer for CubeCameraTestRenderer with fn get_active_mipmap_level(
  self,
) {
  self.level
}

///|
impl @core.CubeCameraRenderer for CubeCameraTestRenderer with fn xr_enabled(
  self,
) {
  self.xr
}

///|
impl @core.CubeCameraRenderer for CubeCameraTestRenderer with fn set_xr_enabled(
  self,
  value,
) {
  self.xr = value
}

///|
impl @core.CubeCameraRenderer for CubeCameraTestRenderer with fn reversed_depth_buffer(
  self,
) {
  self.reversed
}

///|
impl @core.CubeCameraRenderer for CubeCameraTestRenderer with fn auto_clear(
  self,
) {
  self.auto_clear
}

///|
impl @core.CubeCameraRenderer for CubeCameraTestRenderer with fn set_render_target(
  self,
  target,
  face,
  level,
) {
  self.log.push("target \{face} \{level}")
  self.target = target
  self.face = face
  self.level = level
}

///|
impl @core.CubeCameraRenderer for CubeCameraTestRenderer with fn clear_depth(
  self,
) {
  self.log.push("clear")
}

///|
impl @core.CubeCameraRenderer for CubeCameraTestRenderer with fn render(
  self,
  scene,
  camera,
) {
  guard scene.is_scene() && camera.is_perspective_camera() else {
    abort("bad render")
  }
  let parent_children = match camera.parent {
    Some(parent) => parent.children.length()
    None => 0
  }
  self.log.push("render \{self.xr} \{parent_children}")
}

///|
fn cube_camera_test_renderer(
  coordinate_system : Int32,
  reversed : Bool,
) -> CubeCameraTestRenderer {
  {
    log: [],
    coordinate_system,
    target: None,
    face: 3,
    level: 2,
    xr: true,
    reversed,
    auto_clear: false,
  }
}

///|
test "CubeCamera Extending" {
  let object = @core.CubeCamera::new()
  assert_true(object.kind is CubeCamera(_))
  assert_false(object.is_camera())
}

///|
test "CubeCamera type" {
  assert_eq(@core.CubeCamera::new().type_, "CubeCamera")
}

///|
test "CubeCamera children share the layers" {
  let object = @core.CubeCamera::new(near=1.0, far=10.0)
  assert_eq(object.children.length(), 6)
  object.layers.set(4)
  for camera in object.children {
    assert_true(camera.layers.is_enabled(4))
    let perspective = camera.as_perspective_camera()
    assert_eq(perspective.fov, -90.0)
    assert_eq(perspective.aspect, 1.0)
    assert_eq(perspective.near, 1.0)
    assert_eq(perspective.far, 10.0)
  }
}

///|
test "CubeCamera updateCoordinateSystem WebGL" {
  let object = @core.CubeCamera::new()
  object.as_cube_camera().coordinate_system = Some(@core.WebGLCoordinateSystem)
  object.update_coordinate_system()
  assert_eq(object.children.length(), 6)
  let up = [
    (0.0, 1.0, 0.0),
    (0.0, 1.0, 0.0),
    (0.0, 0.0, -1.0),
    (0.0, 0.0, 1.0),
    (0.0, 1.0, 0.0),
    (0.0, 1.0, 0.0),
  ]
  let look = [
    (1.0, 0.0, 0.0),
    (-1.0, 0.0, 0.0),
    (0.0, 1.0, 0.0),
    (0.0, -1.0, 0.0),
    (0.0, 0.0, 1.0),
    (0.0, 0.0, -1.0),
  ]
  for i, camera in object.children {
    let (ux, uy, uz) = up[i]
    let (lx, ly, lz) = look[i]
    assert_true(camera.up.equals(vec3(ux, uy, uz)))
    let direction = camera.get_world_direction(vec3(0, 0, 0))
    assert_true(direction.distance_to(vec3(lx, ly, lz)) < 0.0001)
  }
}

///|
test "CubeCamera updateCoordinateSystem WebGPU" {
  let object = @core.CubeCamera::new()
  object.as_cube_camera().coordinate_system = Some(@core.WebGPUCoordinateSystem)
  object.update_coordinate_system()
  let look = [
    (-1.0, 0.0, 0.0),
    (1.0, 0.0, 0.0),
    (0.0, 1.0, 0.0),
    (0.0, -1.0, 0.0),
    (0.0, 0.0, 1.0),
    (0.0, 0.0, -1.0),
  ]
  for i, camera in object.children {
    let (lx, ly, lz) = look[i]
    let direction = camera.get_world_direction(vec3(0, 0, 0))
    assert_true(direction.distance_to(vec3(lx, ly, lz)) < 0.0001)
  }
}

///|
test "CubeCamera update renders the six faces and restores the renderer" {
  let target = @core.RenderTarget::new(width=16, height=16)
  let object = @core.CubeCamera::new(render_target=target)
  object.as_cube_camera().active_mipmap_level = 1
  let renderer = cube_camera_test_renderer(@core.WebGLCoordinateSystem, true)
  let previous = @core.RenderTarget::new()
  renderer.target = Some(previous)
  let pmrem_version = target.textures[0].pmrem_version
  object.update_cube_camera(renderer, @core.Scene::new())
  assert_eq(
    object.as_cube_camera().coordinate_system,
    Some(@core.WebGLCoordinateSystem),
  )
  let expected = []
  for face in 0..<6 {
    expected.push("target \{face} 1")
    expected.push("clear")
    expected.push("render false 6")
  }
  expected.push("target 3 2")
  assert_eq(renderer.log, expected)
  assert_true(renderer.xr)
  assert_true(
    renderer.target is Some(restored) && physical_equal(restored, previous),
  )
  assert_eq(target.textures[0].pmrem_version, pmrem_version + 1)
  assert_true(target.textures[0].mipmaps_auto_update)
}

///|
test "CubeCamera update skips clearDepth unless depth is reversed" {
  let target = @core.RenderTarget::new(width=16, height=16)
  let object = @core.CubeCamera::new(render_target=target)
  let renderer = cube_camera_test_renderer(@core.WebGPUCoordinateSystem, false)
  object.update_cube_camera(renderer, @core.Scene::new())
  assert_false(renderer.log.contains("clear"))
  let renderer = cube_camera_test_renderer(@core.WebGPUCoordinateSystem, true)
  renderer.auto_clear = true
  object.update_cube_camera(renderer, @core.Scene::new())
  assert_false(renderer.log.contains("clear"))
}

///|
test "CubeCamera clone duplicates the faces, as upstream" {
  let object = @core.CubeCamera::new(near=1.0, far=10.0)
  let cloned = object.clone()
  assert_eq(cloned.children.length(), 12)
  assert_eq(cloned.children[0].as_perspective_camera().far, 2000.0)
  assert_eq(cloned.children[6].as_perspective_camera().far, 10.0)
}
