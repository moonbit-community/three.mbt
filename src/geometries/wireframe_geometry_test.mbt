///|
test "WireframeGeometry: type" {
  assert_eq(@geometries.WireframeGeometry::new().type_, "WireframeGeometry")
}

///|
test "WireframeGeometry: parameters.geometry is serialized when toJSON runs" {
  let source = @geometries.BoxGeometry::new()
  let geometry = @geometries.WireframeGeometry::new(geometry=source)
  source.name = "renamed"
  assert_eq(json_get(geometry.to_json(), "geometry"), Some(source.to_json()))
}
