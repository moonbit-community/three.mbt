///|
test "Box2/Instancing" {
  let mut a = Box2::new()
  assert_true(a.min.equals(g_pos_inf2))
  assert_true(a.max.equals(g_neg_inf2))
  a = Box2::new(min=g_zero2.clone(), max=g_zero2.clone())
  assert_true(a.min.equals(g_zero2))
  assert_true(a.max.equals(g_zero2))
  a = Box2::new(min=g_zero2.clone(), max=g_one2.clone())
  assert_true(a.min.equals(g_zero2))
  assert_true(a.max.equals(g_one2))
}

///|
test "Box2/set" {
  let a = Box2::new()
  a.set(g_zero2, g_one2) |> ignore
  assert_true(a.min.equals(g_zero2))
  assert_true(a.max.equals(g_one2))
}

///|
test "Box2/setFromPoints" {
  let a = Box2::new()
  a.set_from_points([g_zero2, g_one2, g_two2]) |> ignore
  assert_true(a.min.equals(g_zero2))
  assert_true(a.max.equals(g_two2))
  a.set_from_points([g_one2]) |> ignore
  assert_true(a.min.equals(g_one2))
  assert_true(a.max.equals(g_one2))
  a.set_from_points([]) |> ignore
  assert_true(a.is_empty())
}

///|
test "Box2/setFromCenterAndSize" {
  let a = Box2::new()
  a.set_from_center_and_size(g_zero2, g_two2) |> ignore
  assert_true(a.min.equals(g_neg_one2))
  assert_true(a.max.equals(g_one2))
  a.set_from_center_and_size(g_one2, g_two2) |> ignore
  assert_true(a.min.equals(g_zero2))
  assert_true(a.max.equals(g_two2))
  a.set_from_center_and_size(g_zero2, g_zero2) |> ignore
  assert_true(a.min.equals(g_zero2))
  assert_true(a.max.equals(g_zero2))
}

///|
test "Box2/clone" {
  let mut a = Box2::new(min=g_zero2, max=g_zero2)
  let mut b = a.clone()
  assert_true(b.min.equals(g_zero2))
  assert_true(b.max.equals(g_zero2))
  a = Box2::new()
  b = a.clone()
  assert_true(b.min.equals(g_pos_inf2))
  assert_true(b.max.equals(g_neg_inf2))
}

///|
test "Box2/copy" {
  let a = Box2::new(min=g_zero2.clone(), max=g_one2.clone())
  let b = Box2::new().copy(a)
  assert_true(b.min.equals(g_zero2))
  assert_true(b.max.equals(g_one2))
  // ensure that it is a true copy
  a.min = g_zero2
  a.max = g_one2
  assert_true(b.min.equals(g_zero2))
  assert_true(b.max.equals(g_one2))
}

///|
test "Box2/empty/makeEmpty" {
  let mut a = Box2::new()
  assert_true(a.is_empty())
  a = Box2::new(min=g_zero2.clone(), max=g_one2.clone())
  assert_true(!a.is_empty())
  a.make_empty() |> ignore
  assert_true(a.is_empty())
}

///|
test "Box2/isEmpty" {
  let mut a = Box2::new(min=g_zero2.clone(), max=g_zero2.clone())
  assert_true(!a.is_empty())
  a = Box2::new(min=g_zero2.clone(), max=g_one2.clone())
  assert_true(!a.is_empty())
  a = Box2::new(min=g_two2.clone(), max=g_one2.clone())
  assert_true(a.is_empty())
  a = Box2::new(min=g_pos_inf2.clone(), max=g_neg_inf2.clone())
  assert_true(a.is_empty())
}

///|
test "Box2/getCenter" {
  let mut a = Box2::new(min=g_zero2.clone(), max=g_zero2.clone())
  let center = g_v2(0.0, 0.0)
  assert_true(a.get_center(center).equals(g_zero2))
  a = Box2::new(min=g_zero2, max=g_one2)
  let midpoint = g_one2.clone().multiply_scalar(0.5)
  assert_true(a.get_center(center).equals(midpoint))
}

///|
test "Box2/getSize" {
  let mut a = Box2::new(min=g_zero2.clone(), max=g_zero2.clone())
  let size = g_v2(0.0, 0.0)
  assert_true(a.get_size(size).equals(g_zero2))
  a = Box2::new(min=g_zero2.clone(), max=g_one2.clone())
  assert_true(a.get_size(size).equals(g_one2))
}

///|
test "Box2/expandByPoint" {
  let a = Box2::new(min=g_zero2.clone(), max=g_zero2.clone())
  let size = g_v2(0.0, 0.0)
  let center = g_v2(0.0, 0.0)
  a.expand_by_point(g_zero2) |> ignore
  assert_true(a.get_size(size).equals(g_zero2))
  a.expand_by_point(g_one2) |> ignore
  assert_true(a.get_size(size).equals(g_one2))
  a.expand_by_point(g_one2.clone().negate()) |> ignore
  assert_true(a.get_size(size).equals(g_one2.clone().multiply_scalar(2.0)))
  assert_true(a.get_center(center).equals(g_zero2))
}

///|
test "Box2/expandByVector" {
  let a = Box2::new(min=g_zero2.clone(), max=g_zero2.clone())
  let size = g_v2(0.0, 0.0)
  let center = g_v2(0.0, 0.0)
  a.expand_by_vector(g_zero2) |> ignore
  assert_true(a.get_size(size).equals(g_zero2))
  a.expand_by_vector(g_one2) |> ignore
  assert_true(a.get_size(size).equals(g_one2.clone().multiply_scalar(2.0)))
  assert_true(a.get_center(center).equals(g_zero2))
}

///|
test "Box2/expandByScalar" {
  let a = Box2::new(min=g_zero2.clone(), max=g_zero2.clone())
  let size = g_v2(0.0, 0.0)
  let center = g_v2(0.0, 0.0)
  a.expand_by_scalar(0.0) |> ignore
  assert_true(a.get_size(size).equals(g_zero2))
  a.expand_by_scalar(1.0) |> ignore
  assert_true(a.get_size(size).equals(g_one2.clone().multiply_scalar(2.0)))
  assert_true(a.get_center(center).equals(g_zero2))
}

///|
test "Box2/containsPoint" {
  let a = Box2::new(min=g_zero2.clone(), max=g_zero2.clone())
  assert_true(a.contains_point(g_zero2))
  assert_true(!a.contains_point(g_one2))
  a.expand_by_scalar(1.0) |> ignore
  assert_true(a.contains_point(g_zero2))
  assert_true(a.contains_point(g_one2))
  assert_true(a.contains_point(g_one2.clone().negate()))
}

///|
test "Box2/containsBox" {
  let a = Box2::new(min=g_zero2.clone(), max=g_zero2.clone())
  let b = Box2::new(min=g_zero2.clone(), max=g_one2.clone())
  let c = Box2::new(min=g_one2.clone().negate(), max=g_one2.clone())
  assert_true(a.contains_box(a))
  assert_true(!a.contains_box(b))
  assert_true(!a.contains_box(c))
  assert_true(b.contains_box(a))
  assert_true(c.contains_box(a))
  assert_true(!b.contains_box(c))
}

///|
test "Box2/getParameter" {
  let a = Box2::new(min=g_zero2.clone(), max=g_one2.clone())
  let b = Box2::new(min=g_one2.clone().negate(), max=g_one2.clone())
  let parameter = g_v2(0.0, 0.0)
  a.get_parameter(g_zero2, parameter) |> ignore
  assert_true(parameter.equals(g_zero2))
  a.get_parameter(g_one2, parameter) |> ignore
  assert_true(parameter.equals(g_one2))
  b.get_parameter(g_one2.clone().negate(), parameter) |> ignore
  assert_true(parameter.equals(g_zero2))
  b.get_parameter(g_zero2, parameter) |> ignore
  assert_true(parameter.equals(g_v2(0.5, 0.5)))
  b.get_parameter(g_one2, parameter) |> ignore
  assert_true(parameter.equals(g_one2))
}

///|
test "Box2/intersectsBox" {
  let a = Box2::new(min=g_zero2.clone(), max=g_zero2.clone())
  let b = Box2::new(min=g_zero2.clone(), max=g_one2.clone())
  let c = Box2::new(min=g_one2.clone().negate(), max=g_one2.clone())
  assert_true(a.intersects_box(a))
  assert_true(a.intersects_box(b))
  assert_true(a.intersects_box(c))
  assert_true(b.intersects_box(a))
  assert_true(c.intersects_box(a))
  assert_true(b.intersects_box(c))
  b.translate(g_two2) |> ignore
  assert_true(!a.intersects_box(b))
  assert_true(!b.intersects_box(a))
  assert_true(!b.intersects_box(c))
}

///|
test "Box2/clampPoint" {
  let a = Box2::new(min=g_zero2.clone(), max=g_zero2.clone())
  let b = Box2::new(min=g_one2.clone().negate(), max=g_one2.clone())
  let point = g_v2(0.0, 0.0)
  a.clamp_point(g_zero2, point) |> ignore
  assert_true(point.equals(g_v2(0.0, 0.0)))
  a.clamp_point(g_one2, point) |> ignore
  assert_true(point.equals(g_v2(0.0, 0.0)))
  a.clamp_point(g_one2.clone().negate(), point) |> ignore
  assert_true(point.equals(g_v2(0.0, 0.0)))
  b.clamp_point(g_two2, point) |> ignore
  assert_true(point.equals(g_v2(1.0, 1.0)))
  b.clamp_point(g_one2, point) |> ignore
  assert_true(point.equals(g_v2(1.0, 1.0)))
  b.clamp_point(g_zero2, point) |> ignore
  assert_true(point.equals(g_v2(0.0, 0.0)))
  b.clamp_point(g_one2.clone().negate(), point) |> ignore
  assert_true(point.equals(g_v2(-1.0, -1.0)))
  b.clamp_point(g_two2.clone().negate(), point) |> ignore
  assert_true(point.equals(g_v2(-1.0, -1.0)))
}

///|
test "Box2/distanceToPoint" {
  let a = Box2::new(min=g_zero2.clone(), max=g_zero2.clone())
  let b = Box2::new(min=g_one2.clone().negate(), max=g_one2.clone())
  assert_true(a.distance_to_point(g_v2(0.0, 0.0)) == 0.0)
  assert_true(a.distance_to_point(g_v2(1.0, 1.0)) == 2.0.sqrt())
  assert_true(a.distance_to_point(g_v2(-1.0, -1.0)) == 2.0.sqrt())
  assert_true(b.distance_to_point(g_v2(2.0, 2.0)) == 2.0.sqrt())
  assert_true(b.distance_to_point(g_v2(1.0, 1.0)) == 0.0)
  assert_true(b.distance_to_point(g_v2(0.0, 0.0)) == 0.0)
  assert_true(b.distance_to_point(g_v2(-1.0, -1.0)) == 0.0)
  assert_true(b.distance_to_point(g_v2(-2.0, -2.0)) == 2.0.sqrt())
}

///|
test "Box2/intersect" {
  let a = Box2::new(min=g_zero2.clone(), max=g_zero2.clone())
  let b = Box2::new(min=g_zero2.clone(), max=g_one2.clone())
  let c = Box2::new(min=g_one2.clone().negate(), max=g_one2.clone())
  assert_true(a.clone().intersect(a).equals(a))
  assert_true(a.clone().intersect(b).equals(a))
  assert_true(b.clone().intersect(b).equals(b))
  assert_true(a.clone().intersect(c).equals(a))
  assert_true(b.clone().intersect(c).equals(b))
  assert_true(c.clone().intersect(c).equals(c))
  let d = Box2::new(min=g_one2.clone().negate(), max=g_zero2.clone())
  let e = Box2::new(min=g_one2.clone(), max=g_two2.clone()).intersect(d)
  assert_true(e.min.equals(g_pos_inf2) && e.max.equals(g_neg_inf2))
}

///|
test "Box2/union" {
  let a = Box2::new(min=g_zero2.clone(), max=g_zero2.clone())
  let b = Box2::new(min=g_zero2.clone(), max=g_one2.clone())
  let c = Box2::new(min=g_one2.clone().negate(), max=g_one2.clone())
  assert_true(a.clone().union(a).equals(a))
  assert_true(a.clone().union(b).equals(b))
  assert_true(a.clone().union(c).equals(c))
  assert_true(b.clone().union(c).equals(c))
}

///|
test "Box2/translate" {
  let a = Box2::new(min=g_zero2.clone(), max=g_zero2.clone())
  let b = Box2::new(min=g_zero2.clone(), max=g_one2.clone())
  let c = Box2::new(min=g_one2.clone().negate(), max=g_zero2.clone())
  assert_true(
    a.clone().translate(g_one2).equals(Box2::new(min=g_one2, max=g_one2)),
  )
  assert_true(
    a.clone().translate(g_one2).translate(g_one2.clone().negate()).equals(a),
  )
  assert_true(c.clone().translate(g_one2).equals(b))
  assert_true(b.clone().translate(g_one2.clone().negate()).equals(c))
}

///|
test "Box2/equals" {
  let mut a = Box2::new()
  let mut b = Box2::new()
  assert_true(b.equals(a))
  assert_true(a.equals(b))
  a = Box2::new(min=g_one2, max=g_two2)
  b = Box2::new(min=g_one2, max=g_two2)
  assert_true(b.equals(a))
  assert_true(a.equals(b))
  a = Box2::new(min=g_one2, max=g_two2)
  b = a.clone()
  assert_true(b.equals(a))
  assert_true(a.equals(b))
  a = Box2::new(min=g_one2, max=g_two2)
  b = Box2::new(min=g_one2, max=g_one2)
  assert_true(!b.equals(a))
  assert_true(!a.equals(b))
  a = Box2::new()
  b = Box2::new(min=g_one2, max=g_one2)
  assert_true(!b.equals(a))
  assert_true(!a.equals(b))
  a = Box2::new(min=g_one2, max=g_two2)
  b = Box2::new(min=g_one2, max=g_one2)
  assert_true(!b.equals(a))
  assert_true(!a.equals(b))
}
