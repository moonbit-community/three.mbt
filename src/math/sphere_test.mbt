///|
test "Sphere/Instancing" {
  let mut a = Sphere::new()
  assert_true(a.center.equals(g_zero3))
  assert_true(a.radius == -1.0)
  a = Sphere::new(center=g_one3.clone(), radius=1.0)
  assert_true(a.center.equals(g_one3))
  assert_true(a.radius == 1.0)
}

///|
test "Sphere/set" {
  let a = Sphere::new()
  assert_true(a.center.equals(g_zero3))
  assert_true(a.radius == -1.0)
  a.set(g_one3, 1.0) |> ignore
  assert_true(a.center.equals(g_one3))
  assert_true(a.radius == 1.0)
}

///|
test "Sphere/setFromPoints" {
  let a = Sphere::new()
  let expected_center = g_v3(0.9330126941204071, 0.0, 0.0)
  let mut expected_radius = 1.3676668773461689
  let optional_center = g_v3(1.0, 1.0, 1.0)
  let points = [
    g_v3(1.0, 1.0, 0.0),
    g_v3(1.0, 1.0, 0.0),
    g_v3(1.0, 1.0, 0.0),
    g_v3(1.0, 1.0, 0.0),
    g_v3(1.0, 1.0, 0.0),
    g_v3(0.8660253882408142, 0.5, 0.0),
    g_v3(-0.0, 0.5, 0.8660253882408142),
    g_v3(1.8660253882408142, 0.5, 0.0),
    g_v3(0.0, 0.5, -0.8660253882408142),
    g_v3(0.8660253882408142, 0.5, -0.0),
    g_v3(0.8660253882408142, -0.5, 0.0),
    g_v3(-0.0, -0.5, 0.8660253882408142),
    g_v3(1.8660253882408142, -0.5, 0.0),
    g_v3(0.0, -0.5, -0.8660253882408142),
    g_v3(0.8660253882408142, -0.5, -0.0),
    g_v3(-0.0, -1.0, 0.0),
    g_v3(-0.0, -1.0, 0.0),
    g_v3(0.0, -1.0, 0.0),
    g_v3(0.0, -1.0, -0.0),
    g_v3(-0.0, -1.0, -0.0),
  ]
  a.set_from_points(points) |> ignore
  assert_true((a.center.x - expected_center.x).abs() <= g_eps)
  assert_true((a.center.y - expected_center.y).abs() <= g_eps)
  assert_true((a.center.z - expected_center.z).abs() <= g_eps)
  assert_true((a.radius - expected_radius).abs() <= g_eps)
  expected_radius = 2.5946195770400102
  a.set_from_points(points, optional_center~) |> ignore
  assert_true((a.center.x - optional_center.x).abs() <= g_eps)
  assert_true((a.center.y - optional_center.y).abs() <= g_eps)
  assert_true((a.center.z - optional_center.z).abs() <= g_eps)
  assert_true((a.radius - expected_radius).abs() <= g_eps)
}

///|
test "Sphere/copy" {
  let a = Sphere::new(center=g_one3.clone(), radius=1.0)
  let b = Sphere::new().copy(a)
  assert_true(b.center.equals(g_one3))
  assert_true(b.radius == 1.0)
  // ensure that it is a true copy
  a.center = g_zero3
  a.radius = 0.0
  assert_true(b.center.equals(g_one3))
  assert_true(b.radius == 1.0)
}

///|
test "Sphere/isEmpty" {
  let a = Sphere::new()
  assert_true(a.is_empty())
  a.set(g_one3, 1.0) |> ignore
  assert_true(!a.is_empty())
  // Negative radius contains no points
  a.set(g_one3, -1.0) |> ignore
  assert_true(a.is_empty())
  // Zero radius contains only the center point
  a.set(g_one3, 0.0) |> ignore
  assert_true(!a.is_empty())
}

///|
test "Sphere/makeEmpty" {
  let a = Sphere::new(center=g_one3.clone(), radius=1.0)
  assert_true(!a.is_empty())
  a.make_empty() |> ignore
  assert_true(a.is_empty())
  assert_true(a.center.equals(g_zero3))
}

///|
test "Sphere/containsPoint" {
  let a = Sphere::new(center=g_one3.clone(), radius=1.0)
  assert_true(!a.contains_point(g_zero3))
  assert_true(a.contains_point(g_one3))
  a.set(g_zero3, 0.0) |> ignore
  assert_true(a.contains_point(a.center))
}

///|
test "Sphere/distanceToPoint" {
  let a = Sphere::new(center=g_one3.clone(), radius=1.0)
  assert_true(a.distance_to_point(g_zero3) - 0.7320 < 0.001)
  assert_true(a.distance_to_point(g_one3) == -1.0)
}

///|
test "Sphere/intersectsSphere" {
  let a = Sphere::new(center=g_one3.clone(), radius=1.0)
  let b = Sphere::new(center=g_zero3.clone(), radius=1.0)
  let c = Sphere::new(center=g_zero3.clone(), radius=0.25)
  assert_true(a.intersects_sphere(b))
  assert_true(!a.intersects_sphere(c))
}

///|
test "Sphere/intersectsBox" {
  let a = Sphere::new(center=g_zero3, radius=1.0)
  let b = Sphere::new(center=g_v3(-5.0, -5.0, -5.0), radius=1.0)
  let box = Box3::new(min=g_zero3, max=g_one3)
  assert_true(a.intersects_box(box))
  assert_false(b.intersects_box(box))
}

///|
test "Sphere/intersectsPlane" {
  let a = Sphere::new(center=g_zero3.clone(), radius=1.0)
  let b = Plane::new(normal=g_v3(0.0, 1.0, 0.0), constant=1.0)
  let c = Plane::new(normal=g_v3(0.0, 1.0, 0.0), constant=1.25)
  let d = Plane::new(normal=g_v3(0.0, -1.0, 0.0), constant=1.25)
  assert_true(a.intersects_plane(b))
  assert_true(!a.intersects_plane(c))
  assert_true(!a.intersects_plane(d))
}

///|
test "Sphere/clampPoint" {
  let a = Sphere::new(center=g_one3.clone(), radius=1.0)
  let point = g_v3(0.0, 0.0, 0.0)
  a.clamp_point(g_v3(1.0, 1.0, 3.0), point) |> ignore
  assert_true(point.equals(g_v3(1.0, 1.0, 2.0)))
  a.clamp_point(g_v3(1.0, 1.0, -3.0), point) |> ignore
  assert_true(point.equals(g_v3(1.0, 1.0, 0.0)))
}

///|
test "Sphere/getBoundingBox" {
  let a = Sphere::new(center=g_one3.clone(), radius=1.0)
  let aabb = Box3::new()
  a.get_bounding_box(aabb) |> ignore
  assert_true(aabb.equals(Box3::new(min=g_zero3, max=g_two3)))
  a.set(g_zero3, 0.0) |> ignore
  a.get_bounding_box(aabb) |> ignore
  assert_true(aabb.equals(Box3::new(min=g_zero3, max=g_zero3)))
  // Empty sphere produces empty bounding box
  a.make_empty() |> ignore
  a.get_bounding_box(aabb) |> ignore
  assert_true(aabb.is_empty())
}

///|
test "Sphere/applyMatrix4" {
  let a = Sphere::new(center=g_one3.clone(), radius=1.0)
  let m = g_m4().make_translation(1.0, -2.0, 1.0)
  let aabb1 = Box3::new()
  let aabb2 = Box3::new()
  a.clone().apply_matrix4(m).get_bounding_box(aabb1) |> ignore
  a.get_bounding_box(aabb2) |> ignore
  assert_true(aabb1.equals(aabb2.apply_matrix4(m)))
}

///|
test "Sphere/translate" {
  let a = Sphere::new(center=g_one3.clone(), radius=1.0)
  a.translate(g_one3.clone().negate()) |> ignore
  assert_true(a.center.equals(g_zero3))
}

///|
test "Sphere/expandByPoint" {
  let a = Sphere::new(center=g_zero3.clone(), radius=1.0)
  let p = g_v3(2.0, 0.0, 0.0)
  assert_true(a.contains_point(p) == false)
  a.expand_by_point(p) |> ignore
  assert_true(a.contains_point(p) == true)
  assert_true(a.center.equals(g_v3(0.5, 0.0, 0.0)))
  assert_true(a.radius == 1.5)
}

///|
test "Sphere/union" {
  let a = Sphere::new(center=g_zero3.clone(), radius=1.0)
  let b = Sphere::new(center=g_v3(2.0, 0.0, 0.0), radius=1.0)
  a.union(b) |> ignore
  assert_true(a.center.equals(g_v3(1.0, 0.0, 0.0)))
  assert_true(a.radius == 2.0)
  // d contains c (demonstrates why it is necessary to process two points in union)
  let c = Sphere::new(center=g_v3(0.0, 0.0, 0.0), radius=1.0)
  let d = Sphere::new(center=g_v3(1.0, 0.0, 0.0), radius=4.0)
  c.union(d) |> ignore
  assert_true(c.center.equals(g_v3(1.0, 0.0, 0.0)))
  assert_true(c.radius == 4.0)
  // edge case: both spheres have the same center point
  let e = Sphere::new(center=g_v3(0.0, 0.0, 0.0), radius=1.0)
  let f = Sphere::new(center=g_v3(0.0, 0.0, 0.0), radius=4.0)
  e.union(f) |> ignore
  assert_true(e.center.equals(g_v3(0.0, 0.0, 0.0)))
  assert_true(e.radius == 4.0)
}

///|
test "Sphere/equals" {
  let a = Sphere::new()
  let b = Sphere::new(center=g_v3(1.0, 0.0, 0.0))
  let c = Sphere::new(center=g_v3(1.0, 0.0, 0.0), radius=1.0)
  assert_false(a.equals(b))
  assert_false(a.equals(c))
  assert_false(b.equals(c))
  a.copy(b) |> ignore
  assert_true(a.equals(b))
}

///|
/// Upstream has no toJSON/fromJSON test for Sphere.
test "Sphere/toJSON/fromJSON" {
  let a = Sphere::new(center=g_v3(1.0, 2.0, 3.0), radius=4.5)
  let json = a.to_json()
  assert_true(json is { "radius": Number(4.5, ..), "center": [_, _, _], .. })
  let b = Sphere::new().from_json(json)
  assert_true(b.equals(a))
}
