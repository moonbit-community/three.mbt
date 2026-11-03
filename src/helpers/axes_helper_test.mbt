///|
test "AxesHelper extends LineSegments" {
  let object = @helpers.AxesHelper::new()
  assert_true(object.is_line_segments())
}

///|
test "AxesHelper instancing and type" {
  let object = @helpers.AxesHelper::new()
  assert_eq(object.type_, "AxesHelper")
}

///|
test "AxesHelper dispose" {
  let object = @helpers.AxesHelper::new()
  let mut disposed = 0
  object
  .get_geometry()
  .unwrap()
  .add_event_listener("dispose", _ => disposed += 1)
  object.add_event_listener("dispose", _ => disposed += 1)
  object.dispose()
  assert_eq(disposed, 2)
}

///|
test "AxesHelper setColors" {
  let object = @helpers.AxesHelper::new(size=2.0)
  let geometry = object.get_geometry().unwrap()
  assert_eq(geometry.attributes["position"].get_y(3), 2.0)
  let color = geometry.attributes["color"]
  let version = color.version()
  ignore(
    @helpers.AxesHelper::set_colors(
      object,
      @math.Color::new(0.5, 0.25, 0.0),
      @math.Color::new(0.0, 0.5, 0.25),
      @math.Color::new(0.25, 0.0, 0.5),
    ),
  )
  assert_eq(color.get_x(1), 0.5)
  assert_eq(color.get_y(1), 0.25)
  assert_eq(color.get_z(3), 0.25)
  assert_eq(color.get_x(5), 0.25)
  assert_eq(color.version(), version + 1)
}
