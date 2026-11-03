///|
fn box_helper_geometries() -> Array[@core.BufferGeometry] {
  let box = @core.Mesh::new(geometry=@geometries.BoxGeometry::new())
  let box_helper = @helpers.BoxHelper::new(object=box)
  let sphere = @core.Mesh::new(geometry=@geometries.SphereGeometry::new())
  let sphere_box_helper = @helpers.BoxHelper::new(object=sphere)
  [
    box_helper.get_geometry().unwrap(),
    sphere_box_helper.get_geometry().unwrap(),
  ]
}

///|
test "BoxHelper extends LineSegments" {
  let object = @helpers.BoxHelper::new()
  assert_true(object.is_line_segments())
}

///|
test "BoxHelper instancing and type" {
  let object = @helpers.BoxHelper::new()
  assert_eq(object.type_, "BoxHelper")
}

///|
test "BoxHelper dispose" {
  let object = @helpers.BoxHelper::new()
  object.dispose()
}

///|
/// Upstream's `runStdGeometryTests`, without the `ObjectLoader` read-back (loaders are
/// not ported yet): clone and `toJSON` keep type, uuid rules and vertex count.
test "BoxHelper standard geometry tests" {
  for geometry in box_helper_geometries() {
    let copy = geometry.clone()
    assert_true(copy.uuid != geometry.uuid)
    assert_true(copy.id != geometry.id)
    assert_eq(copy.type_, geometry.type_)
    assert_eq(
      copy.get_attribute("position").unwrap().count(),
      geometry.get_attribute("position").unwrap().count(),
    )
    for g in [geometry, copy] {
      guard g.to_json() is Object(json) else { fail("not an object") }
      guard json.get("metadata") is Some(Object(metadata)) else {
        fail("no metadata")
      }
      assert_eq(metadata.get("version"), Some(Json::number(4.7)))
      assert_eq(json.get("type"), Some(Json::string(g.type_)))
      assert_eq(json.get("uuid"), Some(Json::string(g.uuid)))
      assert_eq(json.get("id"), None)
    }
  }
}

///|
test "BoxHelper fits the object's world box" {
  let mesh = @core.Mesh::new(geometry=@geometries.BoxGeometry::new())
  ignore(mesh.position.set(2.0, 0.0, 0.0))
  mesh.update_matrix_world()
  let helper = @helpers.BoxHelper::new(object=mesh)
  let position = helper.get_geometry().unwrap().attributes["position"]
  assert_eq(position.get_x(0), 2.5)
  assert_eq(position.get_x(1), 1.5)
  assert_eq(position.get_z(6), -0.5)
  assert_false(helper.matrix_auto_update)
  let copy = helper.clone()
  assert_true(
    physical_equal(@helpers.BoxHelper::of(copy).unwrap().object.unwrap(), mesh),
  )
}
