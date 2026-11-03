///|
test "Scene Extending" {
  assert_true(@core.Scene::new().kind is Scene(_))
}

///|
test "Scene isScene" {
  assert_true(@core.Scene::new().is_scene())
}

///|
test "Scene defaults" {
  let object = @core.Scene::new()
  assert_eq(object.type_, "Scene")
  let scene = object.as_scene()
  assert_true(scene.background is None)
  assert_true(scene.environment is None)
  assert_true(scene.fog is None)
  assert_eq(scene.background_blurriness, 0.0)
  assert_eq(scene.background_intensity, 1.0)
  assert_eq(scene.environment_intensity, 1.0)
  assert_true(scene.override_material is None)
}

///|
test "Scene copy" {
  let object = @core.Scene::new()
  let scene = object.as_scene()
  scene.background = Some(Color(@math.Color::from_hex(0xff0000)))
  scene.fog = Some(FogExp2(@core.FogExp2::new(density=0.5)))
  scene.background_blurriness = 0.5
  scene.background_intensity = 2.0
  ignore(scene.background_rotation.set(1, 2, 3))
  scene.environment_intensity = 3.0
  ignore(scene.environment_rotation.set(3, 2, 1))
  object.matrix_auto_update = false
  ignore(object.add(@core.Object3D::new()))
  let cloned_object = object.clone()
  let cloned = cloned_object.as_scene()
  assert_eq(cloned_object.children.length(), 1)
  assert_false(cloned_object.matrix_auto_update)
  guard cloned.background is Some(Color(color)) &&
    scene.background is Some(Color(original)) else {
    fail("no background")
  }
  assert_true(color.equals(original))
  assert_false(physical_equal(color, original))
  assert_true(cloned.fog is Some(FogExp2({ density: 0.5, .. })))
  assert_eq(cloned.background_blurriness, 0.5)
  assert_eq(cloned.background_intensity, 2.0)
  assert_true(
    euler_equals(cloned.background_rotation, scene.background_rotation),
  )
  assert_eq(cloned.environment_intensity, 3.0)
  assert_true(
    euler_equals(cloned.environment_rotation, scene.environment_rotation),
  )
  assert_true(cloned.override_material is None)
  // the copy clones the rotation, and the original keeps its callback
  ignore(scene.background_rotation.set(0, 0, 0))
  assert_eq(cloned.background_rotation.x, 1.0)
}

///|
test "Scene copy clones textures and the override material" {
  let object = @core.Scene::new()
  let scene = object.as_scene()
  let background = @core.Texture::new()
  let environment = @core.Texture::new()
  let material = @core.MeshBasicMaterial::new()
  scene.background = Some(Texture(background))
  scene.environment = Some(environment)
  scene.override_material = Some(material)
  let cloned = object.clone().as_scene()
  guard cloned.background is Some(Texture(cloned_background)) else {
    fail("no background")
  }
  assert_false(physical_equal(cloned_background, background))
  assert_true(
    cloned.environment is Some(copied) && !physical_equal(copied, environment),
  )
  assert_true(
    cloned.override_material is Some(copied) &&
    !physical_equal(copied, material),
  )
}

///|
test "Scene copy clears what the source lacks" {
  let target = @core.Scene::new()
  target.as_scene().fog = Some(Fog(@core.Fog::new()))
  ignore(target.copy(@core.Scene::new()))
  assert_true(target.as_scene().fog is None)
}

///|
test "Scene toJSON" {
  let object = @core.Scene::new()
  let scene = object.as_scene()
  scene.background = Some(Color(@math.Color::from_hex(0xff0000)))
  scene.fog = Some(Fog(@core.Fog::new(far=2.0)))
  scene.background_rotation.set_order("ZYX")
  guard object.to_json() is Object(json) &&
    json.get("object") is Some(Object(data)) else {
    fail("no object")
  }
  assert_true(data.get("background") is Some(Number(16711680.0, ..)))
  guard data.get("fog") is Some(Object(fog)) else { fail("no fog") }
  assert_true(fog.get("far") is Some(Number(2.0, ..)))
  assert_true(data.get("backgroundBlurriness") is Some(Number(0.0, ..)))
  assert_true(data.get("backgroundIntensity") is Some(Number(1.0, ..)))
  assert_true(data.get("environmentIntensity") is Some(Number(1.0, ..)))
  guard data.get("backgroundRotation") is Some(Array(rotation)) else {
    fail("no rotation")
  }
  assert_eq(rotation.length(), 4)
  assert_eq(rotation[3], Json::string("ZYX"))
}
