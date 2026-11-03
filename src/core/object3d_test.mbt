///|
let test_rad_to_deg : Double = 180.0 / test_pi()

///|
let test_identity : Array[Double] = [
  1.0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1,
]

///|
fn translation(x : Double, y : Double, z : Double) -> Array[Double] {
  [1.0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, y, z, 1]
}

///|
test "Object3D type" {
  assert_eq(@core.Object3D::new().type_, "Object3D")
}

///|
test "Object3D DEFAULT_UP" {
  let current = vec3(0, 0, 0).copy(@core.object3d_default_up)
  assert_true(@core.object3d_default_up.equals(vec3(0, 1, 0)))
  let object = @core.Object3D::new()
  assert_true(object.up.equals(vec3(0, 1, 0)))
  ignore(@core.object3d_default_up.set(0, 0, 1))
  let object2 = @core.Object3D::new()
  assert_true(object2.up.equals(vec3(0, 0, 1)))
  ignore(@core.object3d_default_up.copy(current))
}

///|
test "Object3D DEFAULT_MATRIX_AUTO_UPDATE" {
  assert_true(@core.object3d_default_matrix_auto_update.val)
  let object = @core.Object3D::new()
  assert_true(object.matrix_auto_update)
  @core.object3d_default_matrix_auto_update.val = false
  let object2 = @core.Object3D::new()
  assert_false(object2.matrix_auto_update)
  @core.object3d_default_matrix_auto_update.val = true
}

///|
test "Object3D applyMatrix4" {
  let a = @core.Object3D::new()
  let m = @math.Matrix4::new()
  let expected_pos = vec3(test_x, test_y, test_z)
  let expected_quat = @math.Quaternion::new(
    0.5 * 2.0.sqrt(),
    0,
    0,
    0.5 * 2.0.sqrt(),
  )
  ignore(m.make_rotation_x(test_pi() / 2.0))
  ignore(m.set_position_vector(vec3(test_x, test_y, test_z)))
  a.apply_matrix4(m)
  assert_true(a.position.equals(expected_pos))
  assert_true(
    approx(a.quaternion.x, expected_quat.x) &&
    approx(a.quaternion.y, expected_quat.y) &&
    approx(a.quaternion.z, expected_quat.z),
  )
}

///|
test "Object3D applyMatrix4 (pivot)" {
  let object = @core.Object3D::new()
  ignore(object.position.set(1, 2, 3))
  ignore(object.rotation.set(0.3, -0.7, 1.2))
  ignore(object.scale.set(2, 3, 4))
  object.pivot = Some(vec3(1, -2, 3))
  object.update_matrix()
  let m = @math.Matrix4::new().make_rotation_y(0.4).set_position(3, -2, 1)
  let expected_matrix = m.clone().multiply(object.matrix)
  object.apply_matrix4(m)
  object.update_matrix()
  assert_true(matrix_equals4(object.matrix, expected_matrix))
}

///|
test "Object3D applyQuaternion" {
  let a = @core.Object3D::new()
  let sqrt = 0.5 * 2.0.sqrt()
  let quat = @math.Quaternion::new(0, sqrt, 0, sqrt)
  let expected = @math.Quaternion::new(sqrt / 2.0, sqrt / 2.0, 0, 0)
  ignore(a.quaternion.set(0.25, 0.25, 0.25, 0.25))
  ignore(a.apply_quaternion(quat))
  assert_true(
    approx(a.quaternion.x, expected.x) &&
    approx(a.quaternion.y, expected.y) &&
    approx(a.quaternion.z, expected.z),
  )
}

///|
test "Object3D setRotationFromAxisAngle" {
  let a = @core.Object3D::new()
  let axis = vec3(0, 1, 0)
  let expected = @math.Euler::new(-test_pi(), 0, -test_pi())
  let euler = @math.Euler::new(0, 0, 0)
  a.set_rotation_from_axis_angle(axis, test_pi())
  ignore(
    euler.set_from_quaternion(
      a.get_world_quaternion(@math.Quaternion::new(0, 0, 0, 1)),
    ),
  )
  assert_true(euler_equals(euler, expected))
  ignore(axis.set(1, 0, 0))
  ignore(expected.set(0, 0, 0))
  a.set_rotation_from_axis_angle(axis, 0)
  ignore(
    euler.set_from_quaternion(
      a.get_world_quaternion(@math.Quaternion::new(0, 0, 0, 1)),
    ),
  )
  assert_true(euler_equals(euler, expected))
}

///|
test "Object3D setRotationFromEuler" {
  let a = @core.Object3D::new()
  let rotation = @math.Euler::new(45.0 / test_rad_to_deg, 0, test_pi())
  let expected = rotation.clone()
  let euler = @math.Euler::new(0, 0, 0)
  a.set_rotation_from_euler(rotation)
  ignore(
    euler.set_from_quaternion(
      a.get_world_quaternion(@math.Quaternion::new(0, 0, 0, 1)),
    ),
  )
  assert_true(euler_equals(euler, expected))
}

///|
test "Object3D setRotationFromMatrix" {
  let a = @core.Object3D::new()
  let m = @math.Matrix4::new()
  let euler = @math.Euler::new(0, 0, 0)
  ignore(m.look_at(vec3(0, 0, 0), vec3(0, 1, -1), vec3(0, 1, 0)))
  a.set_rotation_from_matrix(m)
  ignore(
    euler.set_from_quaternion(
      a.get_world_quaternion(@math.Quaternion::new(0, 0, 0, 1)),
    ),
  )
  assert_true(approx(euler.x * test_rad_to_deg, 45))
}

///|
test "Object3D setRotationFromQuaternion" {
  let a = @core.Object3D::new()
  let rotation = @math.Quaternion::new(0, 0, 0, 1).set_from_euler(
    @math.Euler::new(test_pi(), 0, -test_pi()),
  )
  let euler = @math.Euler::new(0, 0, 0)
  a.set_rotation_from_quaternion(rotation)
  ignore(
    euler.set_from_quaternion(
      a.get_world_quaternion(@math.Quaternion::new(0, 0, 0, 1)),
    ),
  )
  assert_true(euler_equals(euler, @math.Euler::new(test_pi(), 0, -test_pi())))
}

///|
test "Object3D rotateX" {
  let obj = @core.Object3D::new()
  ignore(obj.rotate_x(1.562))
  assert_true(approx(obj.rotation.x, 1.562))
}

///|
test "Object3D rotateY" {
  let obj = @core.Object3D::new()
  ignore(obj.rotate_y(-0.346))
  assert_true(approx(obj.rotation.y, -0.346))
}

///|
test "Object3D rotateZ" {
  let obj = @core.Object3D::new()
  ignore(obj.rotate_z(1))
  assert_true(approx(obj.rotation.z, 1))
}

///|
test "Object3D rotateOnWorldAxis" {
  let obj = @core.Object3D::new()
  ignore(obj.rotate_on_world_axis(vec3(0, 1, 0), 0.5))
  assert_true(approx(obj.rotation.y, 0.5))
}

///|
test "rotation and quaternion stay in sync" {
  let obj = @core.Object3D::new()
  // writing the Euler updates the quaternion
  obj.rotation.set_x(1)
  let expected = @math.Quaternion::new(0, 0, 0, 1).set_from_euler(
    @math.Euler::new(1, 0, 0),
  )
  assert_true(obj.quaternion.equals(expected))
  ignore(obj.rotation.set(0.1, 0.2, 0.3))
  let expected = @math.Quaternion::new(0, 0, 0, 1).set_from_euler(
    @math.Euler::new(0.1, 0.2, 0.3),
  )
  assert_true(obj.quaternion.equals(expected))
  // writing the quaternion updates the Euler
  obj.quaternion.set_x(0.5)
  let expected = @math.Euler::new(0, 0, 0).set_from_quaternion(obj.quaternion)
  assert_true(obj.rotation.equals(expected))
  ignore(obj.quaternion.set(0, 0, 0, 1))
  assert_true(obj.rotation.equals(@math.Euler::new(0, 0, 0)))
  // reordering keeps the rotation in sync through the setter
  ignore(obj.rotation.set(0.1, 0.2, 0.3))
  obj.rotation.set_order("ZYX")
  let expected = @math.Quaternion::new(0, 0, 0, 1).set_from_euler(
    @math.Euler::new(0.1, 0.2, 0.3, order="ZYX"),
  )
  assert_true(obj.quaternion.equals(expected))
}

///|
test "Object3D translateOnAxis" {
  let obj = @core.Object3D::new()
  ignore(obj.translate_on_axis(vec3(1, 0, 0), 1))
  ignore(obj.translate_on_axis(vec3(0, 1, 0), 1.23))
  ignore(obj.translate_on_axis(vec3(0, 0, 1), -4.56))
  assert_true(obj.position.equals(vec3(1, 1.23, -4.56)))
}

///|
test "Object3D translateX" {
  let obj = @core.Object3D::new()
  ignore(obj.translate_x(1.234))
  assert_true(approx(obj.position.x, 1.234))
}

///|
test "Object3D translateY" {
  let obj = @core.Object3D::new()
  ignore(obj.translate_y(1.234))
  assert_true(approx(obj.position.y, 1.234))
}

///|
test "Object3D translateZ" {
  let obj = @core.Object3D::new()
  ignore(obj.translate_z(1.234))
  assert_true(approx(obj.position.z, 1.234))
}

///|
fn parent_child_pair() -> (@core.Object3D, @core.Object3D) {
  let parent = @core.Object3D::new()
  let child = @core.Object3D::new()
  ignore(parent.position.set(1, 0, 0))
  ignore(parent.rotation.set(0, test_pi() / 2.0, 0))
  ignore(parent.scale.set(2, 1, 1))
  ignore(child.position.set(0, 1, 0))
  ignore(child.rotation.set(test_pi() / 2.0, 0, 0))
  ignore(child.scale.set(1, 2, 1))
  ignore(parent.add(child))
  parent.update_matrix_world()
  (parent, child)
}

///|
test "Object3D localToWorld" {
  let v = vec3(0, 0, 0)
  let (_, child) = parent_child_pair()
  ignore(child.local_to_world(v.set(2, 2, 2)))
  assert_true(approx(v.x, 5) && approx(v.y, -1) && approx(v.z, -4))
}

///|
test "Object3D worldToLocal" {
  let v = vec3(0, 0, 0)
  let (_, child) = parent_child_pair()
  ignore(child.world_to_local(v.set(2, 2, 2)))
  assert_true(approx(v.x, -1) && approx(v.y, 0.5) && approx(v.z, -1))
}

///|
test "Object3D lookAt" {
  let obj = @core.Object3D::new()
  obj.look_at(vec3(0, -1, 1))
  assert_true(approx(obj.rotation.x * test_rad_to_deg, 45))
  let obj2 = @core.Object3D::new()
  obj2.look_at_xyz(0, -1, 1)
  assert_true(obj2.quaternion.equals(obj.quaternion))
}

///|
fn test_camera_object() -> @core.Object3D {
  @core.Object3D::new(
    kind=Camera({
      matrix_world_inverse: @math.Matrix4::new(),
      projection_matrix: @math.Matrix4::new(),
      projection_matrix_inverse: @math.Matrix4::new(),
      coordinate_system: @core.WebGLCoordinateSystem,
      _reversed_depth: false,
      kind: BaseCamera,
    }),
    type_="Camera",
  )
}

///|
fn test_light_object() -> @core.Object3D {
  @core.Object3D::new(
    kind=Light({
      color: @math.Color::new(1, 1, 1),
      intensity: 1,
      shadow: None,
      color_node: None,
      kind: AmbientLight,
    }),
    type_="Light",
  )
}

///|
test "Object3D lookAt faces the other way for cameras and lights" {
  let target = vec3(1, 2, 3)
  let plain = @core.Object3D::new()
  let light = test_light_object()
  plain.look_at(target)
  light.look_at(target)
  let m = @math.Matrix4::new().look_at(vec3(0, 0, 0), target, vec3(0, 1, 0))
  assert_true(
    light.quaternion.equals(
      @math.Quaternion::new(0, 0, 0, 1).set_from_rotation_matrix(m),
    ),
  )
  assert_false(light.quaternion.equals(plain.quaternion))
  // `look_at` takes the same branch for both; `update_world_matrix` on a camera needs
  // the camera hook, so this checks the predicate here
  assert_true(test_camera_object().is_camera() && light.is_light())
}

///|
test "Object3D lookAt with a rotated parent" {
  let parent = @core.Object3D::new()
  let child = @core.Object3D::new()
  ignore(parent.add(child))
  ignore(parent.rotation.set(0.3, 0.4, 0.5))
  ignore(parent.position.set(1, 2, 3))
  child.look_at(vec3(4, 5, 6))
  child.update_world_matrix(true, false)
  let direction = child.get_world_direction(vec3(0, 0, 0))
  let expected = vec3(4, 5, 6)
    .sub(child.get_world_position(vec3(0, 0, 0)))
    .normalize()
  assert_true(
    approx(direction.x, expected.x) &&
    approx(direction.y, expected.y) &&
    approx(direction.z, expected.z),
  )
}

///|
test "Object3D add/remove/removeFromParent/clear" {
  let a = @core.Object3D::new()
  let child1 = @core.Object3D::new()
  let child2 = @core.Object3D::new()
  assert_eq(a.children.length(), 0)
  ignore(a.add(child1))
  assert_eq(a.children.length(), 1)
  assert_true(physical_equal(a.children[0], child1))
  ignore(a.add(child2))
  assert_eq(a.children.length(), 2)
  assert_true(physical_equal(a.children[1], child2))
  assert_true(physical_equal(a.children[0], child1))
  ignore(a.remove(child1))
  assert_eq(a.children.length(), 1)
  assert_true(physical_equal(a.children[0], child2))
  ignore(a.add(child1))
  ignore(a.remove_all([child1, child2]))
  assert_eq(a.children.length(), 0)
  ignore(child1.add(child2))
  assert_eq(child1.children.length(), 1)
  ignore(a.add(child2))
  assert_eq(a.children.length(), 1)
  assert_true(physical_equal(a.children[0], child2))
  assert_eq(child1.children.length(), 0)
  ignore(a.add(child1))
  assert_eq(a.children.length(), 2)
  ignore(a.clear())
  assert_eq(a.children.length(), 0)
  assert_true(child1.parent is None)
  assert_true(child2.parent is None)
  ignore(a.add(child1))
  assert_eq(a.children.length(), 1)
  ignore(child1.remove_from_parent())
  assert_eq(a.children.length(), 0)
  assert_true(child1.parent is None)
}

///|
test "Object3D add refuses itself" {
  let a = @core.Object3D::new()
  ignore(a.add(a))
  assert_eq(a.children.length(), 0)
  assert_true(a.parent is None)
}

///|
test "Object3D add and remove fire events" {
  let parent = @core.Object3D::new()
  let child = @core.Object3D::new()
  let events = []
  child.add_event_listener("added", event => {
    guard event.target is Some(Object3D(target)) &&
      physical_equal(target, child) else {
      abort("wrong target")
    }
    events.push("added")
  })
  child.add_event_listener("removed", _ => events.push("removed"))
  parent.add_event_listener("childadded", event => {
    guard event.child is Some(added) && physical_equal(added, child) else {
      abort("wrong child")
    }
    events.push("childadded")
  })
  parent.add_event_listener("childremoved", event => {
    guard event.child is Some(removed) && physical_equal(removed, child) else {
      abort("wrong child")
    }
    events.push("childremoved")
  })
  ignore(parent.add(child))
  ignore(parent.remove(child))
  assert_eq(events, ["added", "childadded", "removed", "childremoved"])
  // `child` is reset after each dispatch, as upstream
  let late = @core.Event::new("x")
  assert_true(late.child is None)
}

///|
test "Object3D attach" {
  let object = @core.Object3D::new()
  let old_parent = @core.Object3D::new()
  let new_parent = @core.Object3D::new()
  let expected_matrix_world = @math.Matrix4::new()
  // Attach to a parent
  ignore(object.position.set(1, 2, 3))
  ignore(object.rotation.set(test_pi() / 2.0, test_pi() / 3.0, test_pi() / 4.0))
  ignore(object.scale.set(2, 3, 4))
  ignore(new_parent.position.set(4, 5, 6))
  ignore(
    new_parent.rotation.set(test_pi() / 5.0, test_pi() / 6.0, test_pi() / 7.0),
  )
  ignore(new_parent.scale.set(5, 5, 5))
  object.update_matrix_world()
  new_parent.update_matrix_world()
  ignore(expected_matrix_world.copy(object.matrix_world))
  ignore(new_parent.attach(object))
  assert_true(object.parent is Some(p) && physical_equal(p, new_parent))
  assert_true(matrix_equals4(expected_matrix_world, object.matrix_world))
  // Attach to a new parent from an old parent
  ignore(object.position.set(1, 2, 3))
  ignore(object.rotation.set(test_pi() / 2.0, test_pi() / 3.0, test_pi() / 4.0))
  ignore(object.scale.set(2, 3, 4))
  ignore(old_parent.position.set(4, 5, 6))
  ignore(
    old_parent.rotation.set(test_pi() / 5.0, test_pi() / 6.0, test_pi() / 7.0),
  )
  ignore(old_parent.scale.set(5, 5, 5))
  ignore(new_parent.position.set(7, 8, 9))
  ignore(
    new_parent.rotation.set(test_pi() / 8.0, test_pi() / 9.0, test_pi() / 10.0),
  )
  ignore(new_parent.scale.set(6, 6, 6))
  ignore(old_parent.add(object))
  old_parent.update_matrix_world()
  new_parent.update_matrix_world()
  ignore(expected_matrix_world.copy(object.matrix_world))
  ignore(new_parent.attach(object))
  assert_true(object.parent is Some(p) && physical_equal(p, new_parent))
  assert_eq(new_parent.children.length(), 1)
  assert_eq(old_parent.children.length(), 0)
  assert_true(matrix_equals4(expected_matrix_world, object.matrix_world))
}

///|
test "Object3D attach (pivot)" {
  let object = @core.Object3D::new()
  ignore(object.position.set(1, 2, 3))
  ignore(object.rotation.set(0.3, -0.7, 1.2))
  ignore(object.scale.set(2, 3, 4))
  object.pivot = Some(vec3(1, -2, 3))
  object.update_matrix_world()
  let expected_matrix_world = object.matrix_world.clone()
  let parent = @core.Object3D::new()
  ignore(parent.position.set(4, 5, 6))
  ignore(parent.rotation.set(0.2, 0.4, 0.6))
  ignore(parent.attach(object))
  assert_true(matrix_equals4(object.matrix_world, expected_matrix_world))
}

///|
test "Object3D getObjectById/getObjectByName/getObjectByProperty" {
  let parent = @core.Object3D::new()
  let child_name = @core.Object3D::new()
  let child_id = @core.Object3D::new()
  let child_nothing = @core.Object3D::new()
  parent.cast_shadow = true
  child_name.name = "foo"
  ignore(parent.add_all([child_name, child_id, child_nothing]))
  assert_true(
    parent.get_object_by_property("castShadow", Json::boolean(true)) is Some(o) &&
    physical_equal(o, parent),
  )
  assert_true(
    parent.get_object_by_name("foo") is Some(o) && physical_equal(o, child_name),
  )
  assert_true(
    parent.get_object_by_id(parent.id + 2) is Some(o) &&
    physical_equal(o, child_id),
  )
  assert_true(
    parent.get_object_by_property("no-property", Json::string("no-value"))
    is None,
  )
}

///|
test "Object3D getObjectsByProperty" {
  let parent = @core.Object3D::new()
  let child_name = @core.Object3D::new()
  let child_nothing = @core.Object3D::new()
  let child_name2 = @core.Object3D::new()
  let child_name3 = @core.Object3D::new()
  child_name.name = "foo"
  child_name2.name = "foo"
  child_name3.name = "foo"
  ignore(child_name2.add(child_name3))
  ignore(child_name.add(child_name2))
  ignore(parent.add_all([child_name, child_nothing]))
  let found = parent.get_objects_by_property("name", Json::string("foo"))
  assert_eq(found.length(), 3)
  assert_false(found.iter().any(obj => obj.name != "foo"))
}

///|
test "Object3D getWorldPosition" {
  let a = @core.Object3D::new()
  let b = @core.Object3D::new()
  let position = vec3(0, 0, 0)
  ignore(a.translate_x(test_x))
  ignore(a.translate_y(test_y))
  ignore(a.translate_z(test_z))
  assert_true(
    a.get_world_position(position).equals(vec3(test_x, test_y, test_z)),
  )
  // translate child and then parent
  ignore(b.translate_z(7))
  ignore(a.add(b))
  ignore(a.translate_z(-test_z))
  assert_true(a.get_world_position(position).equals(vec3(test_x, test_y, 0)))
  assert_true(b.get_world_position(position).equals(vec3(test_x, test_y, 7)))
}

///|
test "Object3D getWorldScale" {
  let a = @core.Object3D::new()
  let m = @math.Matrix4::new().make_scale(test_x, test_y, test_z)
  a.apply_matrix4(m)
  assert_true(
    a.get_world_scale(vec3(0, 0, 0)).equals(vec3(test_x, test_y, test_z)),
  )
}

///|
test "Object3D getWorldDirection" {
  let a = @core.Object3D::new()
  let expected = vec3(0, -0.5 * 2.0.sqrt(), 0.5 * 2.0.sqrt())
  let direction = vec3(0, 0, 0)
  a.look_at(vec3(0, -1, 1))
  ignore(a.get_world_direction(direction))
  assert_true(
    approx(direction.x, expected.x) &&
    approx(direction.y, expected.y) &&
    approx(direction.z, expected.z),
  )
}

///|
test "Object3D localTransformVariableInstantiation" {
  let a = @core.Object3D::new()
  let b = @core.Object3D::new()
  let c = @core.Object3D::new()
  let d = @core.Object3D::new()
  ignore(a.get_world_direction(vec3(0, 0, 0)))
  a.look_at(vec3(0, -1, 1))
  ignore(b.get_world_position(vec3(0, 0, 0)))
  b.look_at(vec3(0, -1, 1))
  ignore(c.get_world_quaternion(@math.Quaternion::new(0, 0, 0, 1)))
  c.look_at(vec3(0, -1, 1))
  ignore(d.get_world_scale(vec3(0, 0, 0)))
  d.look_at(vec3(0, -1, 1))
  assert_true(a.quaternion.equals(d.quaternion))
}

///|
test "Object3D traverse/traverseVisible/traverseAncestors" {
  let a = @core.Object3D::new()
  let b = @core.Object3D::new()
  let c = @core.Object3D::new()
  let d = @core.Object3D::new()
  a.name = "parent"
  b.name = "child"
  c.name = "childchild 1"
  c.visible = false
  d.name = "childchild 2"
  ignore(b.add(c))
  ignore(b.add(d))
  ignore(a.add(b))
  let names = []
  a.traverse(obj => names.push(obj.name))
  assert_eq(names, ["parent", "child", "childchild 1", "childchild 2"])
  let names = []
  a.traverse_visible(obj => names.push(obj.name))
  assert_eq(names, ["parent", "child", "childchild 2"])
  let names = []
  c.traverse_ancestors(obj => names.push(obj.name))
  assert_eq(names, ["child", "parent"])
}

///|
test "Object3D updateMatrix" {
  let a = @core.Object3D::new()
  ignore(a.position.set(2, 3, 4))
  ignore(a.quaternion.set(5, 6, 7, 8))
  ignore(a.scale.set(9, 10, 11))
  assert_eq(a.matrix.elements, test_identity)
  a.update_matrix()
  assert_eq(a.matrix.elements, [
    -1521.0, 1548, -234, 0, -520, -1470, 1640, 0, 1826, 44, -1331, 0, 2, 3, 4, 1,
  ])
  assert_true(a.matrix_world_needs_update)
}

///|
test "Object3D updateMatrix with pivot" {
  let a = @core.Object3D::new()
  ignore(a.rotation.set(0, 0, test_pi() / 2.0))
  a.pivot = Some(vec3(1, 0, 0))
  a.update_matrix()
  // a rotation about the pivot leaves the pivot in place
  let p = vec3(1, 0, 0).apply_matrix4(a.matrix)
  assert_true(approx(p.x, 1) && approx(p.y, 0) && approx(p.z, 0))
}

///|
test "Object3D updateMatrixWorld" {
  let parent = @core.Object3D::new()
  let child = @core.Object3D::new()
  // -- Standard usage test
  ignore(parent.position.set(1, 2, 3))
  ignore(child.position.set(4, 5, 6))
  ignore(parent.add(child))
  parent.update_matrix_world()
  assert_eq(parent.matrix.elements, translation(1, 2, 3))
  assert_eq(parent.matrix_world.elements, translation(1, 2, 3))
  assert_eq(child.matrix.elements, translation(4, 5, 6))
  assert_eq(child.matrix_world.elements, translation(5, 7, 9))
  assert_false(
    parent.matrix_world_needs_update || child.matrix_world_needs_update,
  )
  // -- No sync between local position/quaternion/scale/matrix and world matrix test
  ignore(parent.position.set(0, 0, 0))
  parent.update_matrix()
  assert_eq(parent.matrix_world.elements, translation(1, 2, 3))
  // -- matrixAutoUpdate = false test
  // Resetting local and world matrices to the origin
  ignore(child.position.set(0, 0, 0))
  parent.update_matrix_world()
  ignore(parent.position.set(1, 2, 3))
  parent.matrix_auto_update = false
  child.matrix_auto_update = false
  parent.update_matrix_world()
  assert_eq(parent.matrix.elements, test_identity)
  assert_eq(parent.matrix_world.elements, test_identity)
  assert_eq(child.matrix_world.elements, test_identity)
  // -- matrixWorldAutoUpdate = false test
  ignore(parent.position.set(3, 2, 1))
  parent.update_matrix()
  parent.matrix_auto_update = true
  child.matrix_auto_update = true
  parent.matrix_world_needs_update = true
  child.matrix_world_auto_update = false
  parent.update_matrix_world()
  assert_eq(child.matrix_world.elements, test_identity)
  // -- Propagation to children world matrices test
  ignore(child.position.set(0, 0, 0))
  ignore(parent.position.set(1, 2, 3))
  child.matrix_world_auto_update = true
  parent.update_matrix_world()
  assert_eq(child.matrix_world.elements, translation(1, 2, 3))
  // -- force argument test
  // Resetting the local and world matrices to the origin
  ignore(child.position.set(0, 0, 0))
  child.matrix_auto_update = true
  parent.update_matrix_world()
  ignore(parent.position.set(1, 2, 3))
  parent.update_matrix()
  parent.matrix_auto_update = false
  parent.matrix_world_needs_update = false
  parent.update_matrix_world(force=true)
  assert_eq(parent.matrix_world.elements, translation(1, 2, 3))
  // -- Restriction test: No effect to parent matrices
  // Resetting the local and world matrices to the origin
  ignore(parent.position.set(0, 0, 0))
  ignore(child.position.set(0, 0, 0))
  parent.matrix_auto_update = true
  child.matrix_auto_update = true
  parent.update_matrix_world()
  ignore(parent.position.set(1, 2, 3))
  ignore(child.position.set(4, 5, 6))
  child.update_matrix_world()
  assert_eq(parent.matrix.elements, test_identity)
  assert_eq(parent.matrix_world.elements, test_identity)
  assert_eq(child.matrix_world.elements, translation(4, 5, 6))
}

///|
test "Object3D updateWorldMatrix" {
  let object = @core.Object3D::new()
  let parent = @core.Object3D::new()
  let child = @core.Object3D::new()
  let m = @math.Matrix4::new()
  let v = vec3(0, 0, 0)
  ignore(parent.add(object))
  ignore(object.add(child))
  ignore(parent.position.set(1, 2, 3))
  ignore(object.position.set(4, 5, 6))
  ignore(child.position.set(7, 8, 9))
  // Update the world matrix of an object
  object.update_world_matrix(false, false)
  assert_eq(parent.matrix.elements, m.elements)
  assert_eq(parent.matrix_world.elements, m.elements)
  assert_eq(
    object.matrix.elements,
    m.set_position_vector(object.position).elements,
  )
  assert_eq(
    object.matrix_world.elements,
    m.set_position_vector(object.position).elements,
  )
  assert_eq(child.matrix.elements, m.identity().elements)
  assert_eq(child.matrix_world.elements, m.elements)
  // Update the world matrices of an object and its parents
  ignore(object.matrix.identity())
  ignore(object.matrix_world.identity())
  object.update_world_matrix(true, false)
  assert_eq(
    parent.matrix.elements,
    m.set_position_vector(parent.position).elements,
  )
  assert_eq(
    parent.matrix_world.elements,
    m.set_position_vector(parent.position).elements,
  )
  assert_eq(
    object.matrix.elements,
    m.set_position_vector(object.position).elements,
  )
  assert_eq(
    object.matrix_world.elements,
    m.set_position_vector(v.copy(parent.position).add(object.position)).elements,
  )
  assert_eq(child.matrix.elements, m.identity().elements)
  assert_eq(child.matrix_world.elements, m.identity().elements)
  // Update the world matrices of an object and its children
  ignore(parent.matrix.identity())
  ignore(parent.matrix_world.identity())
  ignore(object.matrix.identity())
  ignore(object.matrix_world.identity())
  object.update_world_matrix(false, true)
  assert_eq(parent.matrix.elements, m.elements)
  assert_eq(parent.matrix_world.elements, m.elements)
  assert_eq(
    object.matrix.elements,
    m.set_position_vector(object.position).elements,
  )
  assert_eq(
    object.matrix_world.elements,
    m.set_position_vector(object.position).elements,
  )
  assert_eq(
    child.matrix.elements,
    m.set_position_vector(child.position).elements,
  )
  assert_eq(
    child.matrix_world.elements,
    m.set_position_vector(v.copy(object.position).add(child.position)).elements,
  )
  // Update the world matrices of an object and its parents and children
  ignore(object.matrix.identity())
  ignore(object.matrix_world.identity())
  ignore(child.matrix.identity())
  ignore(child.matrix_world.identity())
  object.update_world_matrix(true, true)
  assert_eq(
    parent.matrix.elements,
    m.set_position_vector(parent.position).elements,
  )
  assert_eq(
    parent.matrix_world.elements,
    m.set_position_vector(parent.position).elements,
  )
  assert_eq(
    object.matrix.elements,
    m.set_position_vector(object.position).elements,
  )
  assert_eq(
    object.matrix_world.elements,
    m.set_position_vector(v.copy(parent.position).add(object.position)).elements,
  )
  assert_eq(
    child.matrix.elements,
    m.set_position_vector(child.position).elements,
  )
  assert_eq(
    child.matrix_world.elements,
    m.set_position_vector(
      v.copy(parent.position).add(object.position).add(child.position),
    ).elements,
  )
  // object.matrixAutoUpdate = false test
  ignore(object.matrix.identity())
  ignore(object.matrix_world.identity())
  object.matrix_auto_update = false
  object.matrix_world_needs_update = true
  object.update_world_matrix(true, false)
  assert_eq(object.matrix.elements, m.identity().elements)
  assert_eq(
    object.matrix_world.elements,
    m.set_position_vector(parent.position).elements,
  )
  // object.matrixWorldAutoUpdate = false test
  parent.matrix_world_auto_update = false
  child.matrix_world_auto_update = false
  ignore(child.matrix_world.identity())
  ignore(parent.matrix_world.identity())
  child.update_world_matrix(true, true)
  assert_eq(child.matrix_world.elements, m.identity().elements)
  assert_eq(parent.matrix_world.elements, m.identity().elements)
}

///|
fn gold_object(
  uuid : String,
  name : String,
  flag : Bool,
  matrix : Array[Double],
  up : Array[Double],
  children? : Array[Json],
  user_data? : Json,
) -> Json {
  let object : Map[String, Json] = {
    "uuid": Json::string(uuid),
    "type": Json::string("Object3D"),
    "name": Json::string(name),
    "castShadow": Json::boolean(flag),
    "receiveShadow": Json::boolean(flag),
    "visible": Json::boolean(!flag),
    "frustumCulled": Json::boolean(true),
    "renderOrder": Json::number(0),
    "static": Json::boolean(false),
    "matrixAutoUpdate": Json::boolean(true),
    "layers": Json::number(1),
    "matrix": Json::array(matrix.map(v => Json::number(v))),
    "up": Json::array(up.map(v => Json::number(v))),
  }
  if user_data is Some(user_data) {
    object["userData"] = user_data
  }
  if children is Some(children) {
    object["children"] = Json::array(children)
  }
  Json::object(object)
}

///|
test "Object3D toJSON" {
  let a = @core.Object3D::new()
  let child = @core.Object3D::new()
  let child_child = @core.Object3D::new()
  a.name = "a's name"
  ignore(a.matrix.set(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1))
  a.visible = false
  a.cast_shadow = true
  a.receive_shadow = true
  a.user_data.set("foo", @core.JsValue::of("bar"))
  ignore(a.up.set(1, 0, 0))
  child.uuid = "5D4E9AE8-DA61-4912-A575-71A5BE3D72CD"
  child_child.uuid = "B43854B3-E970-4E85-BD41-AAF8D7BFA189"
  ignore(child.add(child_child))
  ignore(a.add(child))
  a.uuid = "0A1E4F43-CB5B-4097-8F82-DC2969C0B8C2"
  let gold_grandchild = gold_object(
    "B43854B3-E970-4E85-BD41-AAF8D7BFA189",
    "",
    false,
    test_identity,
    [0.0, 1, 0],
  )
  let gold_child = gold_object(
    "5D4E9AE8-DA61-4912-A575-71A5BE3D72CD",
    "",
    false,
    test_identity,
    [0.0, 1, 0],
    children=[gold_grandchild],
  )
  let gold = Json::object({
    "metadata": Json::object({
      "version": Json::number(4.7),
      "type": Json::string("Object"),
      "generator": Json::string("Object3D.toJSON"),
    }),
    "object": gold_object(
      "0A1E4F43-CB5B-4097-8F82-DC2969C0B8C2",
      "a's name",
      true,
      Array::make(16, 1.0),
      [1.0, 0, 0],
      children=[gold_child],
      user_data=Json::object({ "foo": Json::string("bar") }),
    ),
  })
  assert_eq(a.to_json(), gold)
}

///|
test "Object3D toJSON pivot" {
  let a = @core.Object3D::new()
  a.pivot = Some(vec3(1, 2, 3))
  guard a.to_json() is Object(output) &&
    output.get("object") is Some(Object(object)) else {
    fail("no object")
  }
  assert_eq(
    object.get("pivot").unwrap(),
    Json::array([1.0, 2, 3].map(v => Json::number(v))),
  )
}

///|
test "Object3D clone" {
  let b = @core.Object3D::new()
  ignore(b.position.set(1, 2, 3))
  let a = b.clone()
  assert_false(physical_equal(a, b))
  assert_true(a.uuid != b.uuid)
  assert_true(a.position.equals(b.position))
  assert_true(a.quaternion.equals(b.quaternion))
  assert_true(a.scale.equals(b.scale))
  assert_eq(a.type_, b.type_)
}

///|
test "Object3D clone without descendants" {
  let a = @core.Object3D::new()
  ignore(a.add(@core.Object3D::new()))
  assert_eq(a.clone().children.length(), 1)
  assert_eq(a.clone(recursive=false).children.length(), 0)
}

///|
test "Object3D copy" {
  let a = @core.Object3D::new()
  let b = @core.Object3D::new()
  let child = @core.Object3D::new()
  let child_child = @core.Object3D::new()
  a.name = "original"
  b.name = "to-be-copied"
  ignore(b.position.set(test_x, test_y, test_z))
  ignore(b.quaternion.set(test_x, test_y, test_z, test_w))
  ignore(b.scale.set(2, 3, 4))
  // bogus QUnit.test values
  ignore(b.matrix.set(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1))
  ignore(b.matrix_world.set(2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2))
  b.matrix_auto_update = false
  b.matrix_world_needs_update = true
  b.layers.mask = 2
  b.visible = false
  b.cast_shadow = true
  b.receive_shadow = true
  b.frustum_culled = false
  b.render_order = 1
  b.user_data.set("foo", @core.JsValue::of("bar"))
  ignore(child.add(child_child))
  ignore(b.add(child))
  ignore(a.copy(b, recursive=true))
  // check they're all unique instances
  assert_true(
    a.uuid != b.uuid &&
    a.children[0].uuid != b.children[0].uuid &&
    a.children[0].children[0].uuid != b.children[0].children[0].uuid,
  )
  // and the values were copied
  assert_eq(a.name, "to-be-copied")
  assert_true(a.position.equals(b.position))
  assert_true(a.quaternion.equals(b.quaternion))
  assert_true(a.scale.equals(b.scale))
  assert_eq(a.matrix.elements, b.matrix.elements)
  assert_eq(a.matrix_world.elements, b.matrix_world.elements)
  assert_false(a.matrix_auto_update)
  assert_true(a.matrix_world_needs_update)
  assert_eq(a.layers.mask, 2)
  assert_false(a.layers.mask == 1)
  assert_false(a.visible)
  assert_true(a.cast_shadow && a.receive_shadow)
  assert_false(a.frustum_culled)
  assert_eq(a.render_order, 1)
  assert_eq(a.user_data.to_json(), Json::object({ "foo": Json::string("bar") }))
  // userData is deep copied
  assert_false(a.user_data.strict_equal(b.user_data))
  assert_eq(a.children.length(), 1)
  assert_eq(a.children[0].children.length(), 1)
}

///|
test "Object3D events on dispose" {
  let a = @core.Object3D::new()
  let mut disposed = false
  a.add_event_listener("dispose", _ => disposed = true)
  a.dispose()
  assert_true(disposed)
}

///|
test "Object3D intersectsFrustum defaults to true and raycast to nothing" {
  let a = @core.Object3D::new()
  assert_true(a.intersects_frustum(Single(@math.Frustum::new())))
  let raycaster : @core.Raycaster = {
    ray: @math.Ray::new(),
    near: 0,
    far: 1,
    camera: None,
    layers: @core.Layers::new(),
    params: {
      mesh: @core.JsValue::object(),
      line: { threshold: 1, },
      lod: @core.JsValue::object(),
      points: { threshold: 1, },
      sprite: @core.JsValue::object(),
    },
  }
  let intersects = []
  a.raycast(raycaster, intersects)
  assert_eq(intersects.length(), 0)
}

///|
test "kind predicates" {
  let group = @core.Object3D::new(kind=Group, type_="Group")
  assert_true(group.is_group())
  assert_false(group.is_clipping_group())
  assert_false(group.is_mesh())
  let clipping = @core.Object3D::new(
    kind=ClippingGroup({
      clipping_planes: [],
      enabled: true,
      clip_intersection: false,
      clip_shadows: false,
    }),
    type_="Group",
  )
  assert_true(clipping.is_group() && clipping.is_clipping_group())
  assert_true(@core.Object3D::new(kind=Bone).is_bone())
  // Group, Bone and ClippingGroup clone without a hook
  assert_true(clipping.clone().is_clipping_group())
  assert_eq(group.clone().type_, "Group")
}

///|
test "camera matrices satisfy math CameraMatrices" {
  let camera = test_camera_object()
  guard camera.kind is Camera(data) else { fail("not a camera") }
  ignore(data.projection_matrix.make_scale(2, 2, 2))
  let v = vec3(1, 1, 1).project(camera)
  assert_eq(v.x, 2)
}
