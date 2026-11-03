///|
test "Box3/Instancing" {
  let mut a = Box3::new()
  assert_true(a.min.equals(g_pos_inf3))
  assert_true(a.max.equals(g_neg_inf3))
  a = Box3::new(min=g_zero3.clone(), max=g_zero3.clone())
  assert_true(a.min.equals(g_zero3))
  assert_true(a.max.equals(g_zero3))
  a = Box3::new(min=g_zero3.clone(), max=g_one3.clone())
  assert_true(a.min.equals(g_zero3))
  assert_true(a.max.equals(g_one3))
}

///|
test "Box3/set" {
  let a = Box3::new()
  a.set(g_zero3, g_one3) |> ignore
  assert_true(a.min.equals(g_zero3))
  assert_true(a.max.equals(g_one3))
}

///|
test "Box3/setFromArray" {
  let a = Box3::new()
  a.set_from_array([0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 2.0, 2.0, 2.0]) |> ignore
  assert_true(a.min.equals(g_zero3))
  assert_true(a.max.equals(g_two3))
}

///|
test "Box3/setFromPoints" {
  let a = Box3::new()
  a.set_from_points([g_zero3, g_one3, g_two3]) |> ignore
  assert_true(a.min.equals(g_zero3))
  assert_true(a.max.equals(g_two3))
  a.set_from_points([g_one3]) |> ignore
  assert_true(a.min.equals(g_one3))
  assert_true(a.max.equals(g_one3))
  a.set_from_points([]) |> ignore
  assert_true(a.is_empty())
}

///|
test "Box3/setFromCenterAndSize" {
  let a = Box3::new(min=g_zero3.clone(), max=g_one3.clone())
  let b = a.clone()
  let center_a = g_v3(0.0, 0.0, 0.0)
  let size_a = g_v3(0.0, 0.0, 0.0)
  let size_b = g_v3(0.0, 0.0, 0.0)
  let new_center = g_one3
  let new_size = g_two3
  a.get_center(center_a) |> ignore
  a.get_size(size_a) |> ignore
  a.set_from_center_and_size(center_a, size_a) |> ignore
  assert_true(a.equals(b))
  a.set_from_center_and_size(new_center, size_a) |> ignore
  a.get_center(center_a) |> ignore
  a.get_size(size_a) |> ignore
  b.get_size(size_b) |> ignore
  assert_true(center_a.equals(new_center))
  assert_true(size_a.equals(size_b))
  assert_false(a.equals(b))
  a.set_from_center_and_size(center_a, new_size) |> ignore
  a.get_center(center_a) |> ignore
  a.get_size(size_a) |> ignore
  assert_true(center_a.equals(new_center))
  assert_true(size_a.equals(new_size))
  assert_false(a.equals(b))
}

///|
test "Box3/clone" {
  let mut a = Box3::new(min=g_zero3.clone(), max=g_one3.clone())
  let mut b = a.clone()
  assert_true(b.min.equals(g_zero3))
  assert_true(b.max.equals(g_one3))
  a = Box3::new()
  b = a.clone()
  assert_true(b.min.equals(g_pos_inf3))
  assert_true(b.max.equals(g_neg_inf3))
}

///|
test "Box3/copy" {
  let a = Box3::new(min=g_zero3.clone(), max=g_one3.clone())
  let b = Box3::new().copy(a)
  assert_true(b.min.equals(g_zero3))
  assert_true(b.max.equals(g_one3))
  // ensure that it is a true copy
  a.min = g_zero3
  a.max = g_one3
  assert_true(b.min.equals(g_zero3))
  assert_true(b.max.equals(g_one3))
}

///|
test "Box3/empty/makeEmpty" {
  let mut a = Box3::new()
  assert_true(a.is_empty())
  a = Box3::new(min=g_zero3.clone(), max=g_one3.clone())
  assert_true(!a.is_empty())
  a.make_empty() |> ignore
  assert_true(a.is_empty())
}

///|
test "Box3/isEmpty" {
  let mut a = Box3::new(min=g_zero3.clone(), max=g_zero3.clone())
  assert_true(!a.is_empty())
  a = Box3::new(min=g_zero3.clone(), max=g_one3.clone())
  assert_true(!a.is_empty())
  a = Box3::new(min=g_two3.clone(), max=g_one3.clone())
  assert_true(a.is_empty())
  a = Box3::new(min=g_pos_inf3.clone(), max=g_neg_inf3.clone())
  assert_true(a.is_empty())
}

///|
test "Box3/getCenter" {
  let mut a = Box3::new(min=g_zero3.clone(), max=g_zero3.clone())
  let center = g_v3(0.0, 0.0, 0.0)
  assert_true(a.get_center(center).equals(g_zero3))
  a = Box3::new(min=g_zero3.clone(), max=g_one3.clone())
  let midpoint = g_one3.clone().multiply_scalar(0.5)
  assert_true(a.get_center(center).equals(midpoint))
}

///|
test "Box3/getSize" {
  let mut a = Box3::new(min=g_zero3.clone(), max=g_zero3.clone())
  let size = g_v3(0.0, 0.0, 0.0)
  assert_true(a.get_size(size).equals(g_zero3))
  a = Box3::new(min=g_zero3.clone(), max=g_one3.clone())
  assert_true(a.get_size(size).equals(g_one3))
}

///|
test "Box3/expandByPoint" {
  let a = Box3::new(min=g_zero3.clone(), max=g_zero3.clone())
  let center = g_v3(0.0, 0.0, 0.0)
  let size = g_v3(0.0, 0.0, 0.0)
  a.expand_by_point(g_zero3) |> ignore
  assert_true(a.get_size(size).equals(g_zero3))
  a.expand_by_point(g_one3) |> ignore
  assert_true(a.get_size(size).equals(g_one3))
  a.expand_by_point(g_one3.clone().negate()) |> ignore
  assert_true(a.get_size(size).equals(g_one3.clone().multiply_scalar(2.0)))
  assert_true(a.get_center(center).equals(g_zero3))
}

///|
test "Box3/expandByVector" {
  let a = Box3::new(min=g_zero3.clone(), max=g_zero3.clone())
  let center = g_v3(0.0, 0.0, 0.0)
  let size = g_v3(0.0, 0.0, 0.0)
  a.expand_by_vector(g_zero3) |> ignore
  assert_true(a.get_size(size).equals(g_zero3))
  a.expand_by_vector(g_one3) |> ignore
  assert_true(a.get_size(size).equals(g_one3.clone().multiply_scalar(2.0)))
  assert_true(a.get_center(center).equals(g_zero3))
}

///|
test "Box3/expandByScalar" {
  let a = Box3::new(min=g_zero3.clone(), max=g_zero3.clone())
  let center = g_v3(0.0, 0.0, 0.0)
  let size = g_v3(0.0, 0.0, 0.0)
  a.expand_by_scalar(0.0) |> ignore
  assert_true(a.get_size(size).equals(g_zero3))
  a.expand_by_scalar(1.0) |> ignore
  assert_true(a.get_size(size).equals(g_one3.clone().multiply_scalar(2.0)))
  assert_true(a.get_center(center).equals(g_zero3))
}

///|
test "Box3/containsPoint" {
  let a = Box3::new(min=g_zero3.clone(), max=g_zero3.clone())
  assert_true(a.contains_point(g_zero3))
  assert_true(!a.contains_point(g_one3))
  a.expand_by_scalar(1.0) |> ignore
  assert_true(a.contains_point(g_zero3))
  assert_true(a.contains_point(g_one3))
  assert_true(a.contains_point(g_one3.clone().negate()))
}

///|
test "Box3/containsBox" {
  let a = Box3::new(min=g_zero3.clone(), max=g_zero3.clone())
  let b = Box3::new(min=g_zero3.clone(), max=g_one3.clone())
  let c = Box3::new(min=g_one3.clone().negate(), max=g_one3.clone())
  assert_true(a.contains_box(a))
  assert_true(!a.contains_box(b))
  assert_true(!a.contains_box(c))
  assert_true(b.contains_box(a))
  assert_true(c.contains_box(a))
  assert_true(!b.contains_box(c))
}

///|
test "Box3/getParameter" {
  let a = Box3::new(min=g_zero3.clone(), max=g_one3.clone())
  let b = Box3::new(min=g_one3.clone().negate(), max=g_one3.clone())
  let parameter = g_v3(0.0, 0.0, 0.0)
  a.get_parameter(g_zero3, parameter) |> ignore
  assert_true(parameter.equals(g_zero3))
  a.get_parameter(g_one3, parameter) |> ignore
  assert_true(parameter.equals(g_one3))
  b.get_parameter(g_one3.clone().negate(), parameter) |> ignore
  assert_true(parameter.equals(g_zero3))
  b.get_parameter(g_zero3, parameter) |> ignore
  assert_true(parameter.equals(g_v3(0.5, 0.5, 0.5)))
  b.get_parameter(g_one3, parameter) |> ignore
  assert_true(parameter.equals(g_one3))
}

///|
test "Box3/intersectsBox" {
  let a = Box3::new(min=g_zero3.clone(), max=g_zero3.clone())
  let b = Box3::new(min=g_zero3.clone(), max=g_one3.clone())
  let c = Box3::new(min=g_one3.clone().negate(), max=g_one3.clone())
  assert_true(a.intersects_box(a))
  assert_true(a.intersects_box(b))
  assert_true(a.intersects_box(c))
  assert_true(b.intersects_box(a))
  assert_true(c.intersects_box(a))
  assert_true(b.intersects_box(c))
  b.translate(g_v3(2.0, 2.0, 2.0)) |> ignore
  assert_true(!a.intersects_box(b))
  assert_true(!b.intersects_box(a))
  assert_true(!b.intersects_box(c))
}

///|
test "Box3/intersectsSphere" {
  let a = Box3::new(min=g_zero3.clone(), max=g_one3.clone())
  let b = Sphere::new(center=g_zero3.clone(), radius=1.0)
  assert_true(a.intersects_sphere(b))
  b.translate(g_v3(2.0, 2.0, 2.0)) |> ignore
  assert_true(!a.intersects_sphere(b))
}

///|
test "Box3/intersectsPlane" {
  let a = Box3::new(min=g_zero3.clone(), max=g_one3.clone())
  let b = Plane::new(normal=g_v3(0.0, 1.0, 0.0), constant=1.0)
  let c = Plane::new(normal=g_v3(0.0, 1.0, 0.0), constant=1.25)
  let d = Plane::new(normal=g_v3(0.0, -1.0, 0.0), constant=1.25)
  let e = Plane::new(normal=g_v3(0.0, 1.0, 0.0), constant=0.25)
  let f = Plane::new(normal=g_v3(0.0, 1.0, 0.0), constant=-0.25)
  let g = Plane::new(normal=g_v3(0.0, 1.0, 0.0), constant=-0.75)
  let h = Plane::new(normal=g_v3(0.0, 1.0, 0.0), constant=-1.0)
  let i = Plane::new(normal=g_v3(1.0, 1.0, 1.0).normalize(), constant=-1.732)
  let j = Plane::new(normal=g_v3(1.0, 1.0, 1.0).normalize(), constant=-1.733)
  assert_true(!a.intersects_plane(b))
  assert_true(!a.intersects_plane(c))
  assert_true(!a.intersects_plane(d))
  assert_true(!a.intersects_plane(e))
  assert_true(a.intersects_plane(f))
  assert_true(a.intersects_plane(g))
  assert_true(a.intersects_plane(h))
  assert_true(a.intersects_plane(i))
  assert_true(!a.intersects_plane(j))
}

///|
test "Box3/intersectsTriangle" {
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
  assert_true(a.intersects_triangle(b))
  assert_true(a.intersects_triangle(c))
  assert_true(a.intersects_triangle(d))
  assert_true(!a.intersects_triangle(e))
  assert_true(!a.intersects_triangle(f))
}

///|
test "Box3/clampPoint" {
  let a = Box3::new(min=g_zero3.clone(), max=g_zero3.clone())
  let b = Box3::new(min=g_one3.clone().negate(), max=g_one3.clone())
  let point = g_v3(0.0, 0.0, 0.0)
  a.clamp_point(g_zero3, point) |> ignore
  assert_true(point.equals(g_zero3))
  a.clamp_point(g_one3, point) |> ignore
  assert_true(point.equals(g_zero3))
  a.clamp_point(g_one3.clone().negate(), point) |> ignore
  assert_true(point.equals(g_zero3))
  b.clamp_point(g_v3(2.0, 2.0, 2.0), point) |> ignore
  assert_true(point.equals(g_one3))
  b.clamp_point(g_one3, point) |> ignore
  assert_true(point.equals(g_one3))
  b.clamp_point(g_zero3, point) |> ignore
  assert_true(point.equals(g_zero3))
  b.clamp_point(g_one3.clone().negate(), point) |> ignore
  assert_true(point.equals(g_one3.clone().negate()))
  b.clamp_point(g_v3(-2.0, -2.0, -2.0), point) |> ignore
  assert_true(point.equals(g_one3.clone().negate()))
}

///|
test "Box3/distanceToPoint" {
  let a = Box3::new(min=g_zero3.clone(), max=g_zero3.clone())
  let b = Box3::new(min=g_one3.clone().negate(), max=g_one3.clone())
  assert_true(a.distance_to_point(g_v3(0.0, 0.0, 0.0)) == 0.0)
  assert_true(a.distance_to_point(g_v3(1.0, 1.0, 1.0)) == 3.0.sqrt())
  assert_true(a.distance_to_point(g_v3(-1.0, -1.0, -1.0)) == 3.0.sqrt())
  assert_true(b.distance_to_point(g_v3(2.0, 2.0, 2.0)) == 3.0.sqrt())
  assert_true(b.distance_to_point(g_v3(1.0, 1.0, 1.0)) == 0.0)
  assert_true(b.distance_to_point(g_v3(0.0, 0.0, 0.0)) == 0.0)
  assert_true(b.distance_to_point(g_v3(-1.0, -1.0, -1.0)) == 0.0)
  assert_true(b.distance_to_point(g_v3(-2.0, -2.0, -2.0)) == 3.0.sqrt())
}

///|
test "Box3/getBoundingSphere" {
  let a = Box3::new(min=g_zero3.clone(), max=g_zero3.clone())
  let b = Box3::new(min=g_zero3.clone(), max=g_one3.clone())
  let c = Box3::new(min=g_one3.clone().negate(), max=g_one3.clone())
  let sphere = Sphere::new()
  assert_true(
    a
    .get_bounding_sphere(sphere)
    .equals(Sphere::new(center=g_zero3, radius=0.0)),
  )
  assert_true(
    b
    .get_bounding_sphere(sphere)
    .equals(
      Sphere::new(
        center=g_one3.clone().multiply_scalar(0.5),
        radius=3.0.sqrt() * 0.5,
      ),
    ),
  )
  assert_true(
    c
    .get_bounding_sphere(sphere)
    .equals(Sphere::new(center=g_zero3, radius=12.0.sqrt() * 0.5)),
  )
  let d = Box3::new().make_empty()
  assert_true(d.get_bounding_sphere(sphere).is_empty())
}

///|
test "Box3/intersect" {
  let a = Box3::new(min=g_zero3.clone(), max=g_zero3.clone())
  let b = Box3::new(min=g_zero3.clone(), max=g_one3.clone())
  let c = Box3::new(min=g_one3.clone().negate(), max=g_one3.clone())
  assert_true(a.clone().intersect(a).equals(a))
  assert_true(a.clone().intersect(b).equals(a))
  assert_true(b.clone().intersect(b).equals(b))
  assert_true(a.clone().intersect(c).equals(a))
  assert_true(b.clone().intersect(c).equals(b))
  assert_true(c.clone().intersect(c).equals(c))
}

///|
test "Box3/union" {
  let a = Box3::new(min=g_zero3.clone(), max=g_zero3.clone())
  let b = Box3::new(min=g_zero3.clone(), max=g_one3.clone())
  let c = Box3::new(min=g_one3.clone().negate(), max=g_one3.clone())
  assert_true(a.clone().union(a).equals(a))
  assert_true(a.clone().union(b).equals(b))
  assert_true(a.clone().union(c).equals(c))
  assert_true(b.clone().union(c).equals(c))
}

///|
test "Box3/applyMatrix4" {
  let a = Box3::new(min=g_zero3.clone(), max=g_zero3.clone())
  let b = Box3::new(min=g_zero3.clone(), max=g_one3.clone())
  let c = Box3::new(min=g_one3.clone().negate(), max=g_one3.clone())
  let d = Box3::new(min=g_one3.clone().negate(), max=g_zero3.clone())
  let m = g_m4().make_translation(1.0, -2.0, 1.0)
  let t1 = g_v3(1.0, -2.0, 1.0)
  assert_true(
    g_compare_box(a.clone().apply_matrix4(m), a.clone().translate(t1)),
  )
  assert_true(
    g_compare_box(b.clone().apply_matrix4(m), b.clone().translate(t1)),
  )
  assert_true(
    g_compare_box(c.clone().apply_matrix4(m), c.clone().translate(t1)),
  )
  assert_true(
    g_compare_box(d.clone().apply_matrix4(m), d.clone().translate(t1)),
  )
}

///|
test "Box3/translate" {
  let a = Box3::new(min=g_zero3.clone(), max=g_zero3.clone())
  let b = Box3::new(min=g_zero3.clone(), max=g_one3.clone())
  let c = Box3::new(min=g_one3.clone().negate(), max=g_zero3.clone())
  assert_true(
    a.clone().translate(g_one3).equals(Box3::new(min=g_one3, max=g_one3)),
  )
  assert_true(
    a.clone().translate(g_one3).translate(g_one3.clone().negate()).equals(a),
  )
  assert_true(c.clone().translate(g_one3).equals(b))
  assert_true(b.clone().translate(g_one3.clone().negate()).equals(c))
}

///|
test "Box3/equals" {
  let mut a = Box3::new()
  let mut b = Box3::new()
  assert_true(b.equals(a))
  assert_true(a.equals(b))
  a = Box3::new(min=g_one3, max=g_two3)
  b = Box3::new(min=g_one3, max=g_two3)
  assert_true(b.equals(a))
  assert_true(a.equals(b))
  a = Box3::new(min=g_one3, max=g_two3)
  b = a.clone()
  assert_true(b.equals(a))
  assert_true(a.equals(b))
  a = Box3::new(min=g_one3, max=g_two3)
  b = Box3::new(min=g_one3, max=g_one3)
  assert_true(!b.equals(a))
  assert_true(!a.equals(b))
  a = Box3::new()
  b = Box3::new(min=g_one3, max=g_one3)
  assert_true(!b.equals(a))
  assert_true(!a.equals(b))
}

///|
/// Upstream has no toJSON/fromJSON test for Box3.
test "Box3/toJSON/fromJSON" {
  let a = Box3::new(min=g_v3(1.0, 2.0, 3.0), max=g_v3(4.0, 5.0, 6.5))
  let json = a.to_json()
  assert_true(
    json
    is {
      "min": [Number(1.0, ..), Number(2.0, ..), Number(3.0, ..)],
      "max": [_, _, Number(6.5, ..)],
      ..
    },
  )
  let b = Box3::new().from_json(json)
  assert_true(b.equals(a))
}
