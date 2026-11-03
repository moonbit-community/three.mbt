///|
test "GridHelper extends LineSegments" {
  let object = @helpers.GridHelper::new()
  assert_true(object.is_line_segments())
}

///|
test "GridHelper instancing and type" {
  let object = @helpers.GridHelper::new()
  assert_eq(object.type_, "GridHelper")
}

///|
test "GridHelper dispose" {
  let object = @helpers.GridHelper::new()
  object.dispose()
}

///|
test "GridHelper vertices and center color" {
  let object = @helpers.GridHelper::new(size=4.0, divisions=2.0)
  let geometry = object.get_geometry().unwrap()
  assert_eq(geometry.attributes["position"].count(), 12)
  assert_eq(geometry.attributes["position"].get_x(0), -2.0)
  // the middle line (i = 1) has color1
  let center = @math.Color::from_hex(0x444444)
  assert_eq(
    geometry.attributes["color"].get_x(4),
    helpers_test_fround(center.r),
  )
}
