///|
test "Sprite type" {
  let object = @core.Sprite::new()
  assert_eq(object.type_, "Sprite")
  assert_true(object.is_sprite())
}

///|
test "Sprite shares its geometry" {
  guard @core.Sprite::new().kind is Sprite(a) else { fail("not a Sprite") }
  guard @core.Sprite::new().kind is Sprite(b) else { fail("not a Sprite") }
  assert_true(physical_equal(a.geometry, b.geometry))
  assert_eq(a.geometry.index.unwrap().count(), 6)
  assert_eq((a.center.x, a.center.y, a.count), (0.5, 0.5, 1))
}

///|
test "Sprite raycast" {
  let sprite = @core.Sprite::new()
  sprite.position.z = -5
  sprite.update_matrix_world()
  let camera = @core.PerspectiveCamera::new(fov=90, aspect=1, near=1, far=1000)
  let raycaster = @core.Raycaster::new()
  raycaster.set_from_camera(@math.Vector2::new(0, 0), camera)
  let intersects = []
  sprite.raycast(raycaster, intersects)
  assert_eq(intersects.length(), 1)
  assert_true(approx(intersects[0].distance, 5))
  let uv = intersects[0].uv.unwrap()
  assert_true(approx(uv.x, 0.5) && approx(uv.y, 0.5))
  assert_true(physical_equal(intersects[0].object, sprite))
}

///|
test "Sprite copy keeps center and material" {
  let sprite = @core.Sprite::new()
  guard sprite.kind is Sprite(data) else { fail("not a Sprite") }
  ignore(data.center.set(0.25, 0.75))
  guard sprite.clone().kind is Sprite(copy) else { fail("not a Sprite") }
  assert_eq((copy.center.x, copy.center.y), (0.25, 0.75))
  assert_true(physical_equal(copy.material, data.material))
  assert_false(physical_equal(copy.center, data.center))
}
