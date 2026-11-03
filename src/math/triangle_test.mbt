///|
test "Triangle/Instancing" {
  let mut a = Triangle::new()
  assert_true(a.a.equals(g_zero3))
  assert_true(a.b.equals(g_zero3))
  assert_true(a.c.equals(g_zero3))
  a = Triangle::new(
    a=g_one3.clone().negate(),
    b=g_one3.clone(),
    c=g_two3.clone(),
  )
  assert_true(a.a.equals(g_one3.clone().negate()))
  assert_true(a.b.equals(g_one3))
  assert_true(a.c.equals(g_two3))
}

///|
test "Triangle/set" {
  let a = Triangle::new()
  a.set(g_one3.clone().negate(), g_one3, g_two3) |> ignore
  assert_true(a.a.equals(g_one3.clone().negate()))
  assert_true(a.b.equals(g_one3))
  assert_true(a.c.equals(g_two3))
}

///|
test "Triangle/setFromPointsAndIndices" {
  let a = Triangle::new()
  let points = [g_one3, g_one3.clone().negate(), g_two3]
  a.set_from_points_and_indices(points, 1, 0, 2) |> ignore
  assert_true(a.a.equals(g_one3.clone().negate()))
  assert_true(a.b.equals(g_one3))
  assert_true(a.c.equals(g_two3))
}

///|
test "Triangle/copy" {
  let a = Triangle::new(
    a=g_one3.clone().negate(),
    b=g_one3.clone(),
    c=g_two3.clone(),
  )
  let b = Triangle::new().copy(a)
  assert_true(b.a.equals(g_one3.clone().negate()))
  assert_true(b.b.equals(g_one3))
  assert_true(b.c.equals(g_two3))
  // ensure that it is a true copy
  a.a = g_one3
  a.b = g_zero3
  a.c = g_zero3
  assert_true(b.a.equals(g_one3.clone().negate()))
  assert_true(b.b.equals(g_one3))
  assert_true(b.c.equals(g_two3))
}

///|
test "Triangle/getArea" {
  let mut a = Triangle::new()
  assert_true(a.get_area() == 0.0)
  a = Triangle::new(
    a=g_v3(0.0, 0.0, 0.0),
    b=g_v3(1.0, 0.0, 0.0),
    c=g_v3(0.0, 1.0, 0.0),
  )
  assert_true(a.get_area() == 0.5)
  a = Triangle::new(
    a=g_v3(2.0, 0.0, 0.0),
    b=g_v3(0.0, 0.0, 0.0),
    c=g_v3(0.0, 0.0, 2.0),
  )
  assert_true(a.get_area() == 2.0)
  // colinear triangle.
  a = Triangle::new(
    a=g_v3(2.0, 0.0, 0.0),
    b=g_v3(0.0, 0.0, 0.0),
    c=g_v3(3.0, 0.0, 0.0),
  )
  assert_true(a.get_area() == 0.0)
}

///|
test "Triangle/getMidpoint" {
  let mut a = Triangle::new()
  let midpoint = g_v3(0.0, 0.0, 0.0)
  assert_true(a.get_midpoint(midpoint).equals(g_v3(0.0, 0.0, 0.0)))
  a = Triangle::new(
    a=g_v3(0.0, 0.0, 0.0),
    b=g_v3(1.0, 0.0, 0.0),
    c=g_v3(0.0, 1.0, 0.0),
  )
  assert_true(a.get_midpoint(midpoint).equals(g_v3(1.0 / 3.0, 1.0 / 3.0, 0.0)))
  a = Triangle::new(
    a=g_v3(2.0, 0.0, 0.0),
    b=g_v3(0.0, 0.0, 0.0),
    c=g_v3(0.0, 0.0, 2.0),
  )
  assert_true(a.get_midpoint(midpoint).equals(g_v3(2.0 / 3.0, 0.0, 2.0 / 3.0)))
}

///|
test "Triangle/getNormal" {
  let mut a = Triangle::new()
  let normal = g_v3(0.0, 0.0, 0.0)
  assert_true(a.get_normal(normal).equals(g_v3(0.0, 0.0, 0.0)))
  a = Triangle::new(
    a=g_v3(0.0, 0.0, 0.0),
    b=g_v3(1.0, 0.0, 0.0),
    c=g_v3(0.0, 1.0, 0.0),
  )
  assert_true(a.get_normal(normal).equals(g_v3(0.0, 0.0, 1.0)))
  a = Triangle::new(
    a=g_v3(2.0, 0.0, 0.0),
    b=g_v3(0.0, 0.0, 0.0),
    c=g_v3(0.0, 0.0, 2.0),
  )
  assert_true(a.get_normal(normal).equals(g_v3(0.0, 1.0, 0.0)))
}

///|
test "Triangle/getPlane" {
  let mut a = Triangle::new()
  let plane = Plane::new()
  let normal = g_v3(0.0, 0.0, 0.0)
  a.get_plane(plane) |> ignore
  assert_false(plane.distance_to_point(a.a).is_nan())
  assert_false(plane.distance_to_point(a.b).is_nan())
  assert_false(plane.distance_to_point(a.c).is_nan())
  assert_false(
    plane.normal.x.is_nan() &&
    plane.normal.y.is_nan() &&
    plane.normal.z.is_nan(),
  )
  a = Triangle::new(
    a=g_v3(0.0, 0.0, 0.0),
    b=g_v3(1.0, 0.0, 0.0),
    c=g_v3(0.0, 1.0, 0.0),
  )
  a.get_plane(plane) |> ignore
  a.get_normal(normal) |> ignore
  assert_true(plane.distance_to_point(a.a) == 0.0)
  assert_true(plane.distance_to_point(a.b) == 0.0)
  assert_true(plane.distance_to_point(a.c) == 0.0)
  assert_true(plane.normal.equals(normal))
  a = Triangle::new(
    a=g_v3(2.0, 0.0, 0.0),
    b=g_v3(0.0, 0.0, 0.0),
    c=g_v3(0.0, 0.0, 2.0),
  )
  a.get_plane(plane) |> ignore
  a.get_normal(normal) |> ignore
  assert_true(plane.distance_to_point(a.a) == 0.0)
  assert_true(plane.distance_to_point(a.b) == 0.0)
  assert_true(plane.distance_to_point(a.c) == 0.0)
  assert_true(plane.normal.clone().normalize().equals(normal))
}

///|
test "Triangle/getBarycoord" {
  let mut a = Triangle::new()
  let barycoord = g_v3(0.0, 0.0, 0.0)
  let midpoint = g_v3(0.0, 0.0, 0.0)
  assert_true(a.get_barycoord(a.a, barycoord) is None)
  assert_true(a.get_barycoord(a.b, barycoord) is None)
  assert_true(a.get_barycoord(a.c, barycoord) is None)
  a = Triangle::new(
    a=g_v3(0.0, 0.0, 0.0),
    b=g_v3(1.0, 0.0, 0.0),
    c=g_v3(0.0, 1.0, 0.0),
  )
  a.get_midpoint(midpoint) |> ignore
  a.get_barycoord(a.a, barycoord) |> ignore
  assert_true(barycoord.equals(g_v3(1.0, 0.0, 0.0)))
  a.get_barycoord(a.b, barycoord) |> ignore
  assert_true(barycoord.equals(g_v3(0.0, 1.0, 0.0)))
  a.get_barycoord(a.c, barycoord) |> ignore
  assert_true(barycoord.equals(g_v3(0.0, 0.0, 1.0)))
  a.get_barycoord(midpoint, barycoord) |> ignore
  assert_true(
    barycoord.distance_to(g_v3(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0)) < 0.0001,
  )
  a = Triangle::new(
    a=g_v3(2.0, 0.0, 0.0),
    b=g_v3(0.0, 0.0, 0.0),
    c=g_v3(0.0, 0.0, 2.0),
  )
  a.get_midpoint(midpoint) |> ignore
  a.get_barycoord(a.a, barycoord) |> ignore
  assert_true(barycoord.equals(g_v3(1.0, 0.0, 0.0)))
  a.get_barycoord(a.b, barycoord) |> ignore
  assert_true(barycoord.equals(g_v3(0.0, 1.0, 0.0)))
  a.get_barycoord(a.c, barycoord) |> ignore
  assert_true(barycoord.equals(g_v3(0.0, 0.0, 1.0)))
  a.get_barycoord(midpoint, barycoord) |> ignore
  assert_true(
    barycoord.distance_to(g_v3(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0)) < 0.0001,
  )
}

///|
test "Triangle/containsPoint" {
  let mut a = Triangle::new()
  let midpoint = g_v3(0.0, 0.0, 0.0)
  assert_true(!a.contains_point(a.a))
  assert_true(!a.contains_point(a.b))
  assert_true(!a.contains_point(a.c))
  a = Triangle::new(
    a=g_v3(0.0, 0.0, 0.0),
    b=g_v3(1.0, 0.0, 0.0),
    c=g_v3(0.0, 1.0, 0.0),
  )
  a.get_midpoint(midpoint) |> ignore
  assert_true(a.contains_point(a.a))
  assert_true(a.contains_point(a.b))
  assert_true(a.contains_point(a.c))
  assert_true(a.contains_point(midpoint))
  assert_true(!a.contains_point(g_v3(-1.0, -1.0, -1.0)))
  a = Triangle::new(
    a=g_v3(2.0, 0.0, 0.0),
    b=g_v3(0.0, 0.0, 0.0),
    c=g_v3(0.0, 0.0, 2.0),
  )
  a.get_midpoint(midpoint) |> ignore
  assert_true(a.contains_point(a.a))
  assert_true(a.contains_point(a.b))
  assert_true(a.contains_point(a.c))
  assert_true(a.contains_point(midpoint))
  assert_true(!a.contains_point(g_v3(-1.0, -1.0, -1.0)))
}

///|
test "Triangle/intersectsBox" {
  let a = Box3::new(min=g_one3.clone(), max=g_two3.clone())
  let b = Triangle::new(
    a=g_v3(1.5, 1.5, 2.5),
    b=g_v3(2.5, 1.5, 1.5),
    c=g_v3(1.5, 2.5, 1.5),
  )
  let c = Triangle::new(
    a=g_v3(1.5, 1.5, 3.5),
    b=g_v3(3.5, 1.5, 1.5),
    c=g_v3(1.5, 1.5, 1.5),
  )
  let d = Triangle::new(
    a=g_v3(1.5, 1.75, 3.0),
    b=g_v3(3.0, 1.75, 1.5),
    c=g_v3(1.5, 2.5, 1.5),
  )
  let e = Triangle::new(
    a=g_v3(1.5, 1.8, 3.0),
    b=g_v3(3.0, 1.8, 1.5),
    c=g_v3(1.5, 2.5, 1.5),
  )
  let f = Triangle::new(
    a=g_v3(1.5, 2.5, 3.0),
    b=g_v3(3.0, 2.5, 1.5),
    c=g_v3(1.5, 2.5, 1.5),
  )
  assert_true(b.intersects_box(a))
  assert_true(c.intersects_box(a))
  assert_true(d.intersects_box(a))
  assert_true(!e.intersects_box(a))
  assert_true(!f.intersects_box(a))
}

///|
test "Triangle/closestPointToPoint" {
  let a = Triangle::new(
    a=g_v3(-1.0, 0.0, 0.0),
    b=g_v3(1.0, 0.0, 0.0),
    c=g_v3(0.0, 1.0, 0.0),
  )
  let point = g_v3(0.0, 0.0, 0.0)
  // point lies inside the triangle
  a.closest_point_to_point(g_v3(0.0, 0.5, 0.0), point) |> ignore
  assert_true(point.equals(g_v3(0.0, 0.5, 0.0)))
  // point lies on a vertex
  a.closest_point_to_point(a.a, point) |> ignore
  assert_true(point.equals(a.a))
  a.closest_point_to_point(a.b, point) |> ignore
  assert_true(point.equals(a.b))
  a.closest_point_to_point(a.c, point) |> ignore
  assert_true(point.equals(a.c))
  // point lies on an edge
  a.closest_point_to_point(g_zero3.clone(), point) |> ignore
  assert_true(point.equals(g_zero3.clone()))
  // point lies outside the triangle
  a.closest_point_to_point(g_v3(-2.0, 0.0, 0.0), point) |> ignore
  assert_true(point.equals(g_v3(-1.0, 0.0, 0.0)))
  a.closest_point_to_point(g_v3(2.0, 0.0, 0.0), point) |> ignore
  assert_true(point.equals(g_v3(1.0, 0.0, 0.0)))
  a.closest_point_to_point(g_v3(0.0, 2.0, 0.0), point) |> ignore
  assert_true(point.equals(g_v3(0.0, 1.0, 0.0)))
  a.closest_point_to_point(g_v3(0.0, -2.0, 0.0), point) |> ignore
  assert_true(point.equals(g_v3(0.0, 0.0, 0.0)))
  // degenerate triangle where a and b coincide
  a.set(g_zero3, g_zero3, g_v3(2.0, 0.0, 0.0)) |> ignore
  a.closest_point_to_point(g_v3(1.0, 1.0, 0.0), point) |> ignore
  assert_true(point.equals(g_v3(1.0, 0.0, 0.0)))
}

///|
test "Triangle/isFrontFacing" {
  let mut a = Triangle::new()
  let mut dir = g_v3(0.0, 0.0, 0.0)
  assert_true(!a.is_front_facing(dir))
  a = Triangle::new(
    a=g_v3(0.0, 0.0, 0.0),
    b=g_v3(1.0, 0.0, 0.0),
    c=g_v3(0.0, 1.0, 0.0),
  )
  dir = g_v3(0.0, 0.0, -1.0)
  assert_true(a.is_front_facing(dir))
  a = Triangle::new(
    a=g_v3(0.0, 0.0, 0.0),
    b=g_v3(0.0, 1.0, 0.0),
    c=g_v3(1.0, 0.0, 0.0),
  )
  assert_true(!a.is_front_facing(dir))
}

///|
test "Triangle/equals" {
  let a = Triangle::new(
    a=g_v3(1.0, 0.0, 0.0),
    b=g_v3(0.0, 1.0, 0.0),
    c=g_v3(0.0, 0.0, 1.0),
  )
  let b = Triangle::new(
    a=g_v3(0.0, 0.0, 1.0),
    b=g_v3(0.0, 1.0, 0.0),
    c=g_v3(1.0, 0.0, 0.0),
  )
  let c = Triangle::new(
    a=g_v3(-1.0, 0.0, 0.0),
    b=g_v3(0.0, 1.0, 0.0),
    c=g_v3(0.0, 0.0, 1.0),
  )
  assert_true(a.equals(a))
  assert_false(a.equals(b))
  assert_false(a.equals(c))
  assert_false(b.equals(c))
  a.copy(b) |> ignore
  assert_true(a.equals(a))
}
