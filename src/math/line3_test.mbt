///|
test "Line3/Instancing" {
  let mut a = Line3::new()
  assert_true(a.start.equals(g_zero3))
  assert_true(a.end.equals(g_zero3))
  a = Line3::new(start=g_two3.clone(), end=g_one3.clone())
  assert_true(a.start.equals(g_two3))
  assert_true(a.end.equals(g_one3))
}

///|
test "Line3/set" {
  let a = Line3::new()
  a.set(g_one3, g_one3) |> ignore
  assert_true(a.start.equals(g_one3))
  assert_true(a.end.equals(g_one3))
}

///|
test "Line3/copy/equals" {
  let a = Line3::new(start=g_zero3.clone(), end=g_one3.clone())
  let b = Line3::new().copy(a)
  assert_true(b.start.equals(g_zero3))
  assert_true(b.end.equals(g_one3))
  // ensure that it is a true copy
  a.start = g_zero3
  a.end = g_one3
  assert_true(b.start.equals(g_zero3))
  assert_true(b.end.equals(g_one3))
}

///|
test "Line3/clone/equal" {
  let mut a = Line3::new()
  let b = Line3::new(start=g_zero3, end=g_v3(1.0, 1.0, 1.0))
  let c = Line3::new(start=g_zero3, end=g_v3(1.0, 1.0, 0.0))
  assert_false(a.equals(b))
  assert_false(a.equals(c))
  assert_false(b.equals(c))
  a = b.clone()
  assert_true(a.equals(b))
  assert_false(a.equals(c))
  a.set(g_zero3, g_zero3) |> ignore
  assert_false(a.equals(b))
}

///|
test "Line3/getCenter" {
  let center = g_v3(0.0, 0.0, 0.0)
  let a = Line3::new(start=g_zero3.clone(), end=g_two3.clone())
  assert_true(a.get_center(center).equals(g_one3.clone()))
}

///|
test "Line3/delta" {
  let delta = g_v3(0.0, 0.0, 0.0)
  let a = Line3::new(start=g_zero3.clone(), end=g_two3.clone())
  assert_true(a.delta(delta).equals(g_two3.clone()))
}

///|
test "Line3/distanceSq" {
  let a = Line3::new(start=g_zero3, end=g_zero3)
  let b = Line3::new(start=g_zero3, end=g_one3)
  let c = Line3::new(start=g_one3.clone().negate(), end=g_one3)
  let d = Line3::new(
    start=g_two3.clone().multiply_scalar(-2.0),
    end=g_two3.clone().negate(),
  )
  g_num_equal(a.distance_sq(), 0.0)
  g_num_equal(b.distance_sq(), 3.0)
  g_num_equal(c.distance_sq(), 12.0)
  g_num_equal(d.distance_sq(), 12.0)
}

///|
test "Line3/distance" {
  let a = Line3::new(start=g_zero3, end=g_zero3)
  let b = Line3::new(start=g_zero3, end=g_one3)
  let c = Line3::new(start=g_one3.clone().negate(), end=g_one3)
  let d = Line3::new(
    start=g_two3.clone().multiply_scalar(-2.0),
    end=g_two3.clone().negate(),
  )
  g_num_equal(a.distance(), 0.0)
  g_num_equal(b.distance(), 3.0.sqrt())
  g_num_equal(c.distance(), 12.0.sqrt())
  g_num_equal(d.distance(), 12.0.sqrt())
}

///|
test "Line3/at" {
  let a = Line3::new(start=g_one3.clone(), end=g_v3(1.0, 1.0, 2.0))
  let point = g_v3(0.0, 0.0, 0.0)
  a.at(-1.0, point) |> ignore
  assert_true(point.distance_to(g_v3(1.0, 1.0, 0.0)) < 0.0001)
  a.at(0.0, point) |> ignore
  assert_true(point.distance_to(g_one3.clone()) < 0.0001)
  a.at(1.0, point) |> ignore
  assert_true(point.distance_to(g_v3(1.0, 1.0, 2.0)) < 0.0001)
  a.at(2.0, point) |> ignore
  assert_true(point.distance_to(g_v3(1.0, 1.0, 3.0)) < 0.0001)
}

///|
test "Line3/closestPointToPoint/closestPointToPointParameter" {
  let a = Line3::new(start=g_one3.clone(), end=g_v3(1.0, 1.0, 2.0))
  let point = g_v3(0.0, 0.0, 0.0)
  // nearby the ray
  assert_true(a.closest_point_to_point_parameter(g_zero3.clone(), true) == 0.0)
  a.closest_point_to_point(g_zero3.clone(), true, point) |> ignore
  assert_true(point.distance_to(g_v3(1.0, 1.0, 1.0)) < 0.0001)
  // nearby the ray
  assert_true(
    a.closest_point_to_point_parameter(g_zero3.clone(), false) == -1.0,
  )
  a.closest_point_to_point(g_zero3.clone(), false, point) |> ignore
  assert_true(point.distance_to(g_v3(1.0, 1.0, 0.0)) < 0.0001)
  // nearby the ray
  assert_true(
    a.closest_point_to_point_parameter(g_v3(1.0, 1.0, 5.0), true) == 1.0,
  )
  a.closest_point_to_point(g_v3(1.0, 1.0, 5.0), true, point) |> ignore
  assert_true(point.distance_to(g_v3(1.0, 1.0, 2.0)) < 0.0001)
  // exactly on the ray
  assert_true(a.closest_point_to_point_parameter(g_one3.clone(), true) == 0.0)
  a.closest_point_to_point(g_one3.clone(), true, point) |> ignore
  assert_true(point.distance_to(g_one3.clone()) < 0.0001)
  // degenerate line (zero-length)
  let b = Line3::new(start=g_one3.clone(), end=g_one3.clone())
  assert_true(b.closest_point_to_point_parameter(g_zero3.clone(), true) == 0.0)
  b.closest_point_to_point(g_zero3.clone(), true, point) |> ignore
  assert_true(point.distance_to(g_one3.clone()) < 0.0001)
}

///|
test "Line3/applyMatrix4" {
  let a = Line3::new(start=g_zero3.clone(), end=g_two3.clone())
  let b = g_v4(g_two3.x, g_two3.y, g_two3.z, 1.0)
  let m = g_m4().make_translation(g_x, g_y, g_z)
  let v = g_v3(g_x, g_y, g_z)
  a.apply_matrix4(m) |> ignore
  assert_true(a.start.equals(v))
  assert_true(a.end.equals(g_v3(2.0 + g_x, 2.0 + g_y, 2.0 + g_z)))
  // reset starting conditions
  a.set(g_zero3.clone(), g_two3.clone()) |> ignore
  m.make_rotation_x(@cmath.PI) |> ignore
  a.apply_matrix4(m) |> ignore
  b.apply_matrix4(m) |> ignore
  assert_true(a.start.equals(g_zero3))
  g_num_equal(a.end.x, b.x / b.w)
  g_num_equal(a.end.y, b.y / b.w)
  g_num_equal(a.end.z, b.z / b.w)
  // reset starting conditions
  a.set(g_zero3.clone(), g_two3.clone()) |> ignore
  b.set(g_two3.x, g_two3.y, g_two3.z, 1.0) |> ignore
  m.set_position_vector(v) |> ignore
  a.apply_matrix4(m) |> ignore
  b.apply_matrix4(m) |> ignore
  assert_true(a.start.equals(v))
  g_num_equal(a.end.x, b.x / b.w)
  g_num_equal(a.end.y, b.y / b.w)
  g_num_equal(a.end.z, b.z / b.w)
}

///|
test "Line3/equals" {
  let a = Line3::new(start=g_zero3.clone(), end=g_zero3.clone())
  let b = Line3::new()
  assert_true(a.equals(b))
}

///|
test "Line3/distanceSqToLine3" {
  let line1 = Line3::new()
  line1.start.set(0.0, 0.0, 0.0) |> ignore
  line1.end.set(2.0, 0.0, 0.0) |> ignore
  let line2 = Line3::new()
  line2.start.set(1.0, 10.0, 0.0) |> ignore
  line2.end.set(1.0, -2.0, 0.0) |> ignore
  g_num_equal(line1.distance_sq_to_line3(line2), 0.0)
  // Parallel lines case
  line2.start.set(-2.0, 0.0, 2.0) |> ignore
  line2.end.set(20.0, 0.0, 2.0) |> ignore
  g_num_equal(line1.distance_sq_to_line3(line2), 4.0)
  // Closest point on lines from one side is out of segment
  line1.start.set(0.0, 4.0, 0.0) |> ignore
  line1.end.set(2.0, 2.0, 0.0) |> ignore
  line2.start.set(0.0, 0.0, 0.0) |> ignore
  line2.end.set(4.0, 0.0, 0.0) |> ignore
  g_num_equal(line1.distance_sq_to_line3(line2), 4.0)
  // Closest point on lines from another side is out of segment
  line1.start.set(0.0, 4.0, 0.0) |> ignore
  line1.end.set(3.0, 1.0, 0.0) |> ignore
  line2.start.set(0.0, 0.0, 0.0) |> ignore
  line2.end.set(1.0, 0.0, 0.0) |> ignore
  g_num_equal(line1.distance_sq_to_line3(line2), 4.5)
  // Closest point on lines from both sides is out of the segment
  line1.start.set(0.0, 4.0, 0.0) |> ignore
  line1.end.set(2.0, 2.0, 0.0) |> ignore
  line2.start.set(0.0, 0.0, 0.0) |> ignore
  line2.end.set(1.0, 0.0, 0.0) |> ignore
  g_num_equal(line1.distance_sq_to_line3(line2), 5.0)
  // General case with skew lines
  line1.start.set(4.0, 0.0, 0.0) |> ignore
  line1.end.set(-4.0, 0.0, 0.0) |> ignore
  line2.start.set(0.0, 4.0, 0.0) |> ignore
  line2.end.set(0.0, 0.0, 4.0) |> ignore
  g_num_equal(line1.distance_sq_to_line3(line2), 8.0)
  // Both segments degenerate into points
  line1.set(g_one3, g_one3) |> ignore
  line2.set(g_two3, g_two3) |> ignore
  let c1 = g_v3(0.0, 0.0, 0.0)
  let c2 = g_v3(0.0, 0.0, 0.0)
  g_num_equal(line1.distance_sq_to_line3(line2, c1~, c2~), 3.0)
  assert_true(c1.equals(g_one3))
  assert_true(c2.equals(g_two3))
}
