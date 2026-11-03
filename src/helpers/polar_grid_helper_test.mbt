///|
test "PolarGridHelper extends LineSegments" {
  let object = @helpers.PolarGridHelper::new()
  assert_true(object.is_line_segments())
}

///|
test "PolarGridHelper instancing and type" {
  let object = @helpers.PolarGridHelper::new()
  assert_eq(object.type_, "PolarGridHelper")
}

///|
test "PolarGridHelper dispose" {
  let object = @helpers.PolarGridHelper::new()
  object.dispose()
}

///|
test "PolarGridHelper vertex count" {
  let object = @helpers.PolarGridHelper::new()
  // 16 sectors * 2 + 8 rings * 64 divisions * 2
  assert_eq(
    object.get_geometry().unwrap().attributes["position"].count(),
    16 * 2 + 8 * 64 * 2,
  )
}
