///|
test "FogExp2 Instancing" {
  let object = @core.FogExp2::new()
  assert_eq(object.density, 0.00025)
  assert_true(object.color.equals(@math.Color::new(1, 1, 1)))
  let object_all = @core.FogExp2::new(
    color=@math.Color::from_hex(0xffffff),
    density=0.0003,
  )
  assert_eq(object_all.density, 0.0003)
}

///|
test "FogExp2 clone does not keep the name" {
  let object = @core.FogExp2::new(density=0.5)
  object.name = "fog"
  let cloned = object.clone()
  assert_eq(cloned.name, "")
  assert_eq(cloned.density, 0.5)
}

///|
test "FogExp2 toJSON" {
  let object = @core.FogExp2::new(color=@math.Color::from_hex(0x00ff00))
  assert_eq(
    object.to_json(),
    Json::object({
      "type": Json::string("FogExp2"),
      "name": Json::string(""),
      "color": Json::number(65280.0),
      "density": Json::number(0.00025),
    }),
  )
}
