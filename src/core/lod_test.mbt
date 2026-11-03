///|
fn test_lod_data(object : @core.Object3D) -> @core.LOD {
  guard object.kind is LOD(lod) else { abort("not a LOD") }
  lod
}

///|
test "LOD type" {
  let lod = @core.LOD::new()
  assert_eq(lod.type_, "LOD")
  assert_true(lod.is_lod())
  assert_eq(test_lod_data(lod).levels.length(), 0)
  assert_true(test_lod_data(lod).auto_update)
}

///|
test "LOD copy" {
  let lod1 = @core.LOD::new()
  let lod2 = @core.LOD::new()
  ignore(lod1.add_level(@core.Object3D::new(), distance=5))
  ignore(lod1.add_level(@core.Object3D::new(), distance=25))
  ignore(lod1.add_level(@core.Object3D::new(), distance=50))
  test_lod_data(lod1).auto_update = false
  ignore(lod2.copy(lod1))
  assert_false(test_lod_data(lod2).auto_update)
  assert_eq(test_lod_data(lod2).levels.length(), 3)
  assert_eq(lod2.children.length(), 3)
}

///|
test "LOD addLevel" {
  let lod = @core.LOD::new()
  let high = @core.Object3D::new()
  let mid = @core.Object3D::new()
  let low = @core.Object3D::new()
  ignore(lod.add_level(low, distance=50, hysteresis=0.10))
  ignore(lod.add_level(high, distance=5, hysteresis=0.00))
  ignore(lod.add_level(mid, distance=-25, hysteresis=0.05))
  let levels = test_lod_data(lod).levels
  assert_eq(levels.length(), 3)
  assert_true(physical_equal(levels[0].object, high))
  assert_eq(levels[0].distance, 5)
  assert_true(physical_equal(levels[1].object, mid))
  assert_eq((levels[1].distance, levels[1].hysteresis), (25, 0.05))
  assert_true(physical_equal(levels[2].object, low))
  assert_eq((levels[2].distance, levels[2].hysteresis), (50, 0.10))
}

///|
test "LOD removeLevel" {
  let lod = @core.LOD::new()
  let high = @core.Object3D::new()
  ignore(lod.add_level(high, distance=5))
  assert_false(lod.remove_level(6))
  assert_true(lod.remove_level(5))
  assert_eq(test_lod_data(lod).levels.length(), 0)
  assert_eq(lod.children.length(), 0)
}

///|
test "LOD getObjectForDistance" {
  let lod = @core.LOD::new()
  let high = @core.Object3D::new()
  let mid = @core.Object3D::new()
  let low = @core.Object3D::new()
  assert_true(lod.get_object_for_distance(5) is None)
  ignore(lod.add_level(high, distance=5))
  assert_true(physical_equal(lod.get_object_for_distance(0).unwrap(), high))
  assert_true(physical_equal(lod.get_object_for_distance(10).unwrap(), high))
  ignore(lod.add_level(mid, distance=25))
  ignore(lod.add_level(low, distance=50))
  assert_true(physical_equal(lod.get_object_for_distance(0).unwrap(), high))
  assert_true(physical_equal(lod.get_object_for_distance(10).unwrap(), high))
  assert_true(physical_equal(lod.get_object_for_distance(25).unwrap(), mid))
  assert_true(physical_equal(lod.get_object_for_distance(50).unwrap(), low))
  assert_true(physical_equal(lod.get_object_for_distance(60).unwrap(), low))
}

///|
test "LOD raycast" {
  let lod = @core.LOD::new()
  let raycaster = @core.Raycaster::new()
  let intersections = []
  lod.raycast(raycaster, intersections)
  assert_eq(intersections.length(), 0)
}

///|
test "LOD update" {
  let lod = @core.LOD::new()
  let high = @core.Object3D::new()
  let low = @core.Object3D::new()
  ignore(lod.add_level(high, distance=0))
  ignore(lod.add_level(low, distance=10))
  let camera = @core.PerspectiveCamera::new()
  camera.position.z = 20
  camera.update_matrix_world()
  lod.update_matrix_world()
  lod.update(camera)
  assert_eq(lod.get_current_level(), 1)
  assert_false(high.visible)
  assert_true(low.visible)
  camera.position.z = 5
  camera.update_matrix_world()
  lod.update(camera)
  assert_eq(lod.get_current_level(), 0)
  assert_true(high.visible)
  assert_false(low.visible)
}

///|
test "LOD toJSON" {
  let lod = @core.LOD::new()
  let high = @core.Object3D::new()
  ignore(lod.add_level(high, distance=5, hysteresis=0.5))
  guard lod.to_json() is Object(output) else { fail("not an object") }
  guard output["object"] is Object(object) else { fail("not an object") }
  assert_eq(object["autoUpdate"], Json::boolean(true))
  assert_eq(
    object["levels"],
    Json::array([
      Json::object({
        "object": Json::string(high.uuid),
        "distance": Json::number(5),
        "hysteresis": Json::number(0.5),
      }),
    ]),
  )
}
