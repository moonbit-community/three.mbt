///|
test "DirectionalLightShadow Extending" {
  let object = @core.DirectionalLightShadow::new()
  assert_true(object.kind is DirectionalLightShadow)
  assert_true(object.camera.is_orthographic_camera())
}

///|
test "DirectionalLightShadow clone/copy" {
  let a = @core.DirectionalLightShadow::new()
  let b = @core.DirectionalLightShadow::new()
  let c = a.clone()
  assert_true(c.kind is DirectionalLightShadow)
  assert_eq(
    light_test_strip_ids(a.to_json()),
    light_test_strip_ids(c.to_json()),
  )
  ignore(c.map_size.set(1024, 1024))
  assert_false(
    light_test_strip_ids(a.to_json()) == light_test_strip_ids(c.to_json()),
  )
  a.bias = 2.0
  ignore(b.copy(a))
  assert_eq(
    light_test_strip_ids(a.to_json()),
    light_test_strip_ids(b.to_json()),
  )
  ignore(b.map_size.set(256, 256))
  assert_eq(a.map_size.x, 512.0)
}

///|
test "DirectionalLightShadow toJSON" {
  let light = @core.DirectionalLight::new()
  let shadow = @core.DirectionalLightShadow::new()
  shadow.bias = 10.0
  shadow.radius = 5.0
  ignore(shadow.map_size.set(1024, 1024))
  light.as_light().shadow = Some(shadow)
  let object = light_test_object(light)
  guard object.get("shadow") is Some(Object(json)) else { fail("no shadow") }
  assert_true(json.get("bias") is Some(Number(10.0, ..)))
  assert_true(json.get("radius") is Some(Number(5.0, ..)))
  guard json.get("mapSize") is Some(Array(size)) else { fail("no size") }
  assert_true(size[0] is Number(1024.0, ..))
  assert_true(json.get("mapType") is Some(Number(1009.0, ..)))
}
