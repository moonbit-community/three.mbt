///|
test "Fog Instancing" {
  let object = @core.Fog::new()
  assert_true(object.color.equals(@math.Color::new(1, 1, 1)))
  assert_eq(object.near, 1.0)
  assert_eq(object.far, 1000.0)
  assert_eq(object.name, "")
  let object_color = @core.Fog::new(color=@math.Color::from_hex(0xffffff))
  assert_true(object_color.color.equals(@math.Color::new(1, 1, 1)))
  let object_all = @core.Fog::new(
    color=@math.Color::from_hex(0xffffff),
    near=0.015,
    far=100.0,
  )
  assert_eq(object_all.near, 0.015)
  assert_eq(object_all.far, 100.0)
}

///|
test "Fog clone does not keep the name" {
  let object = @core.Fog::new(near=2.0, far=3.0)
  object.name = "fog"
  let cloned = object.clone()
  assert_eq(cloned.name, "")
  assert_eq(cloned.near, 2.0)
  assert_eq(cloned.far, 3.0)
  assert_false(physical_equal(cloned.color, object.color))
}

///|
test "Fog toJSON" {
  let object = @core.Fog::new(color=@math.Color::from_hex(0xff0000), far=10.0)
  object.name = "fog"
  assert_eq(
    object.to_json(),
    Json::object({
      "type": Json::string("Fog"),
      "name": Json::string("fog"),
      "color": Json::number(16711680.0),
      "near": Json::number(1.0),
      "far": Json::number(10.0),
    }),
  )
}
