///|
test "box3_set_from_object" {
  let object = @core.Mesh::new(geometry=test_box_geometry())
  object.position.x = 2
  let child = @core.Mesh::new(geometry=test_box_geometry())
  child.position.y = 5
  ignore(object.add(child))
  object.update_matrix_world()
  let box_ = @core.box3_set_from_object(@math.Box3::new(), object)
  assert_true(box_.min.equals(vec3(1.5, -0.5, -0.5)))
  assert_true(box_.max.equals(vec3(2.5, 5.5, 0.5)))
}

///|
test "box3_expand_by_object precise" {
  let object = @core.Mesh::new(geometry=test_box_geometry())
  ignore(object.rotate_z(test_pi() / 4.0))
  object.update_matrix_world()
  let coarse = @core.box3_set_from_object(@math.Box3::new(), object)
  let precise = @core.box3_set_from_object(
    @math.Box3::new(),
    object,
    precise=true,
  )
  assert_true(approx(coarse.max.x, 2.0.sqrt() / 2.0))
  assert_true(approx(precise.max.x, 2.0.sqrt() / 2.0))
  assert_true(approx(precise.max.z, 0.5))
  let empty = @core.box3_set_from_object(@math.Box3::new(), @core.Group::new())
  assert_true(empty.is_empty())
}

///|
test "box3_expand_by_object uses object-level bounds" {
  let object = @core.InstancedMesh::new(geometry=test_box_geometry(), 2)
  ignore(
    object.set_matrix_at(1, @math.Matrix4::new().make_translation(10, 0, 0)),
  )
  object.update_matrix_world()
  let box_ = @core.box3_set_from_object(@math.Box3::new(), object)
  assert_true(box_.max.equals(vec3(10.5, 0.5, 0.5)))
}

///|
test "triangle_get_interpolated_attribute" {
  let attribute : @core.GeometryAttribute = Buffer(
    @core.Float32BufferAttribute::new([0.0, 0.0, 4.0, 0.0, 0.0, 8.0], 2),
  )
  let bary = vec3(0.5, 0.25, 0.25)
  let v2 = @core.triangle_get_interpolated_attribute(
    attribute,
    0,
    1,
    2,
    bary,
    @math.Vector2::new(9, 9),
  )
  assert_eq((v2.x, v2.y), (1, 2))
}

///|
test "triangle_set_from_attribute_and_indices" {
  let attribute : @core.GeometryAttribute = Buffer(
    @core.Float32BufferAttribute::new(
      [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0],
      3,
    ),
  )
  let triangle = @core.triangle_set_from_attribute_and_indices(
    @math.Triangle::new(),
    attribute,
    2,
    0,
    1,
  )
  assert_true(triangle.a.equals(vec3(7, 8, 9)))
  assert_true(triangle.b.equals(vec3(1, 2, 3)))
  assert_true(triangle.c.equals(vec3(4, 5, 6)))
}

///|
fn test_frustum() -> @math.Frustum {
  let m = @math.Matrix4::new().make_perspective(-1, 1, 1, -1, 1, 100)
  @math.Frustum::new().set_from_projection_matrix(m)
}

///|
test "frustum_intersects_object" {
  let object = @core.Mesh::new(geometry=test_box_geometry())
  ignore(object.position.set(0, 0, -10))
  object.update_matrix_world()
  assert_true(@core.frustum_intersects_object(test_frustum(), object))
  ignore(object.position.set(0, 0, 10))
  object.update_matrix_world()
  assert_false(@core.frustum_intersects_object(test_frustum(), object))
  assert_false(object.intersects_frustum(Single(test_frustum())))
}

///|
test "frustum_intersects_sprite" {
  let sprite = @core.Sprite::new()
  ignore(sprite.position.set(0, 0, -10))
  sprite.update_matrix_world()
  assert_true(@core.frustum_intersects_sprite(test_frustum(), sprite))
  ignore(sprite.position.set(0, 0, 10))
  sprite.update_matrix_world()
  assert_false(@core.frustum_intersects_sprite(test_frustum(), sprite))
  assert_false(sprite.intersects_frustum(Single(test_frustum())))
}

///|
test "frustum_array" {
  let left = @core.PerspectiveCamera::new(fov=60, aspect=1, near=1, far=100)
  let right = @core.PerspectiveCamera::new(fov=60, aspect=1, near=1, far=100)
  ignore(right.rotate_y(test_pi()))
  left.update_matrix_world()
  right.update_matrix_world()
  let array_camera = @core.ArrayCamera::new(array=[left, right])
  let frustums = @math.FrustumArray::new()
  ignore(@core.frustum_array_set_from_array_camera(frustums, array_camera))
  assert_eq(frustums.count, 2)
  let object = @core.Mesh::new(geometry=test_box_geometry())
  // in front of the second camera only
  ignore(object.position.set(0, 0, 10))
  object.update_matrix_world()
  assert_true(@core.frustum_array_intersects_object(frustums, object))
  assert_true(object.intersects_frustum(Array(frustums)))
  ignore(object.position.set(50, 0, 0))
  object.update_matrix_world()
  assert_false(@core.frustum_array_intersects_object(frustums, object))
  let sprite = @core.Sprite::new()
  ignore(sprite.position.set(0, 0, 10))
  sprite.update_matrix_world()
  assert_true(@core.frustum_array_intersects_sprite(frustums, sprite))
}
