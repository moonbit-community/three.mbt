///|
test "Plane/Instancing" {
  let mut a = Plane::new()
  assert_true(a.normal.x == 1.0)
  assert_true(a.normal.y == 0.0)
  assert_true(a.normal.z == 0.0)
  assert_true(a.constant == 0.0)
  a = Plane::new(normal=g_one3.clone(), constant=0.0)
  assert_true(a.normal.x == 1.0)
  assert_true(a.normal.y == 1.0)
  assert_true(a.normal.z == 1.0)
  assert_true(a.constant == 0.0)
  a = Plane::new(normal=g_one3.clone(), constant=1.0)
  assert_true(a.normal.x == 1.0)
  assert_true(a.normal.y == 1.0)
  assert_true(a.normal.z == 1.0)
  assert_true(a.constant == 1.0)
}

///|
test "Plane/set" {
  let a = Plane::new()
  assert_true(a.normal.x == 1.0)
  assert_true(a.normal.y == 0.0)
  assert_true(a.normal.z == 0.0)
  assert_true(a.constant == 0.0)
  let b = a.clone().set(g_v3(g_x, g_y, g_z), g_w)
  assert_true(b.normal.x == g_x)
  assert_true(b.normal.y == g_y)
  assert_true(b.normal.z == g_z)
  assert_true(b.constant == g_w)
}

///|
test "Plane/setComponents" {
  let a = Plane::new()
  assert_true(a.normal.x == 1.0)
  assert_true(a.normal.y == 0.0)
  assert_true(a.normal.z == 0.0)
  assert_true(a.constant == 0.0)
  let b = a.clone().set_components(g_x, g_y, g_z, g_w)
  assert_true(b.normal.x == g_x)
  assert_true(b.normal.y == g_y)
  assert_true(b.normal.z == g_z)
  assert_true(b.constant == g_w)
}

///|
test "Plane/setFromNormalAndCoplanarPoint" {
  let normal = g_one3.clone().normalize()
  let a = Plane::new().set_from_normal_and_coplanar_point(normal, g_zero3)
  assert_true(a.normal.equals(normal))
  assert_true(a.constant == 0.0)
}

///|
test "Plane/setFromCoplanarPoints" {
  let a = Plane::new()
  let v1 = g_v3(2.0, 0.5, 0.25)
  let v2 = g_v3(2.0, -0.5, 1.25)
  let v3 = g_v3(2.0, -3.5, 2.2)
  let normal = g_v3(1.0, 0.0, 0.0)
  let constant = -2.0
  a.set_from_coplanar_points(v1, v2, v3) |> ignore
  assert_true(a.normal.equals(normal))
  assert_true(a.constant == constant)
}

///|
test "Plane/clone" {
  let a = Plane::new(normal=g_v3(2.0, 0.5, 0.25))
  let b = a.clone()
  assert_true(a.equals(b))
}

///|
test "Plane/copy" {
  let a = Plane::new(normal=g_v3(g_x, g_y, g_z), constant=g_w)
  let b = Plane::new().copy(a)
  assert_true(b.normal.x == g_x)
  assert_true(b.normal.y == g_y)
  assert_true(b.normal.z == g_z)
  assert_true(b.constant == g_w)
  // ensure that it is a true copy
  a.normal.x = 0.0
  a.normal.y = -1.0
  a.normal.z = -2.0
  a.constant = -3.0
  assert_true(b.normal.x == g_x)
  assert_true(b.normal.y == g_y)
  assert_true(b.normal.z == g_z)
  assert_true(b.constant == g_w)
}

///|
test "Plane/normalize" {
  let a = Plane::new(normal=g_v3(2.0, 0.0, 0.0), constant=2.0)
  a.normalize() |> ignore
  assert_true(a.normal.length() == 1.0)
  assert_true(a.normal.equals(g_v3(1.0, 0.0, 0.0)))
  assert_true(a.constant == 1.0)
}

///|
test "Plane/negate/distanceToPoint" {
  let a = Plane::new(normal=g_v3(2.0, 0.0, 0.0), constant=-2.0)
  a.normalize() |> ignore
  assert_true(a.distance_to_point(g_v3(4.0, 0.0, 0.0)) == 3.0)
  assert_true(a.distance_to_point(g_v3(1.0, 0.0, 0.0)) == 0.0)
  a.negate() |> ignore
  assert_true(a.distance_to_point(g_v3(4.0, 0.0, 0.0)) == -3.0)
  assert_true(a.distance_to_point(g_v3(1.0, 0.0, 0.0)) == 0.0)
}

///|
test "Plane/distanceToPoint" {
  let a = Plane::new(normal=g_v3(2.0, 0.0, 0.0), constant=-2.0)
  let point = g_v3(0.0, 0.0, 0.0)
  a.normalize().project_point(g_zero3.clone(), point) |> ignore
  assert_true(a.distance_to_point(point) == 0.0)
  assert_true(a.distance_to_point(g_v3(4.0, 0.0, 0.0)) == 3.0)
}

///|
test "Plane/distanceToSphere" {
  let a = Plane::new(normal=g_v3(1.0, 0.0, 0.0), constant=0.0)
  let b = Sphere::new(center=g_v3(2.0, 0.0, 0.0), radius=1.0)
  assert_true(a.distance_to_sphere(b) == 1.0)
  a.set(g_v3(1.0, 0.0, 0.0), 2.0) |> ignore
  assert_true(a.distance_to_sphere(b) == 3.0)
  a.set(g_v3(1.0, 0.0, 0.0), -2.0) |> ignore
  assert_true(a.distance_to_sphere(b) == -1.0)
}

///|
test "Plane/projectPoint" {
  let mut a = Plane::new(normal=g_v3(1.0, 0.0, 0.0), constant=0.0)
  let point = g_v3(0.0, 0.0, 0.0)
  a.project_point(g_v3(10.0, 0.0, 0.0), point) |> ignore
  assert_true(point.equals(g_zero3))
  a.project_point(g_v3(-10.0, 0.0, 0.0), point) |> ignore
  assert_true(point.equals(g_zero3))
  a = Plane::new(normal=g_v3(0.0, 1.0, 0.0), constant=-1.0)
  a.project_point(g_v3(0.0, 0.0, 0.0), point) |> ignore
  assert_true(point.equals(g_v3(0.0, 1.0, 0.0)))
  a.project_point(g_v3(0.0, 1.0, 0.0), point) |> ignore
  assert_true(point.equals(g_v3(0.0, 1.0, 0.0)))
}

///|
test "Plane/intersectLine" {
  let mut a = Plane::new(normal=g_v3(1.0, 0.0, 0.0), constant=0.0)
  let point = g_v3(0.0, 0.0, 0.0)
  let l1 = Line3::new(start=g_v3(-10.0, 0.0, 0.0), end=g_v3(10.0, 0.0, 0.0))
  a.intersect_line(l1, point) |> ignore
  assert_true(point.equals(g_v3(0.0, 0.0, 0.0)))
  a = Plane::new(normal=g_v3(1.0, 0.0, 0.0), constant=-3.0)
  a.intersect_line(l1, point) |> ignore
  assert_true(point.equals(g_v3(3.0, 0.0, 0.0)))
  // plane lies outside the segment's endpoints
  a = Plane::new(normal=g_v3(1.0, 0.0, 0.0), constant=-20.0)
  let l2 = Line3::new(start=g_v3(-10.0, 0.0, 0.0), end=g_v3(10.0, 0.0, 0.0))
  assert_true(a.intersect_line(l2, point) is None)
  assert_true(a.intersect_line(l2, point, clamp_to_line=true) is None)
  let result = a.intersect_line(l2, point, clamp_to_line=false)
  assert_true(result is Some(r) && physical_equal(r, point))
  assert_true(point.equals(g_v3(20.0, 0.0, 0.0)))
}

///|
test "Plane/intersectsBox" {
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
  assert_true(!b.intersects_box(a))
  assert_true(!c.intersects_box(a))
  assert_true(!d.intersects_box(a))
  assert_true(!e.intersects_box(a))
  assert_true(f.intersects_box(a))
  assert_true(g.intersects_box(a))
  assert_true(h.intersects_box(a))
  assert_true(i.intersects_box(a))
  assert_true(!j.intersects_box(a))
}

///|
test "Plane/intersectsSphere" {
  let a = Sphere::new(center=g_zero3.clone(), radius=1.0)
  let b = Plane::new(normal=g_v3(0.0, 1.0, 0.0), constant=1.0)
  let c = Plane::new(normal=g_v3(0.0, 1.0, 0.0), constant=1.25)
  let d = Plane::new(normal=g_v3(0.0, -1.0, 0.0), constant=1.25)
  assert_true(b.intersects_sphere(a))
  assert_true(!c.intersects_sphere(a))
  assert_true(!d.intersects_sphere(a))
}

///|
test "Plane/coplanarPoint" {
  let point = g_v3(0.0, 0.0, 0.0)
  let mut a = Plane::new(normal=g_v3(1.0, 0.0, 0.0), constant=0.0)
  a.coplanar_point(point) |> ignore
  assert_true(a.distance_to_point(point) == 0.0)
  a = Plane::new(normal=g_v3(0.0, 1.0, 0.0), constant=-1.0)
  a.coplanar_point(point) |> ignore
  assert_true(a.distance_to_point(point) == 0.0)
}

///|
test "Plane/applyMatrix4/translate" {
  let mut a = Plane::new(normal=g_v3(1.0, 0.0, 0.0), constant=0.0)
  let m = g_m4()
  m.make_rotation_z(@cmath.PI * 0.5) |> ignore
  assert_true(
    g_compare_plane(
      a.clone().apply_matrix4(m),
      Plane::new(normal=g_v3(0.0, 1.0, 0.0), constant=0.0),
    ),
  )
  a = Plane::new(normal=g_v3(0.0, 1.0, 0.0), constant=-1.0)
  assert_true(
    g_compare_plane(
      a.clone().apply_matrix4(m),
      Plane::new(normal=g_v3(-1.0, 0.0, 0.0), constant=-1.0),
    ),
  )
  m.make_translation(1.0, 1.0, 1.0) |> ignore
  assert_true(
    g_compare_plane(
      a.clone().apply_matrix4(m),
      a.clone().translate(g_v3(1.0, 1.0, 1.0)),
    ),
  )
}

///|
test "Plane/equals" {
  let a = Plane::new(normal=g_v3(1.0, 0.0, 0.0), constant=0.0)
  let b = Plane::new(normal=g_v3(1.0, 0.0, 0.0), constant=1.0)
  let c = Plane::new(normal=g_v3(0.0, 1.0, 0.0), constant=0.0)
  assert_true(a.normal.equals(b.normal))
  assert_false(a.normal.equals(c.normal))
  assert_true(a.constant != b.constant)
  assert_true(a.constant == c.constant)
  assert_false(a.equals(b))
  assert_false(a.equals(c))
  a.copy(b) |> ignore
  assert_true(a.normal.equals(b.normal))
  assert_true(a.constant == b.constant)
  assert_true(a.equals(b))
}

///|
/// Upstream has no toJSON/fromJSON test for Plane.
test "Plane/toJSON/fromJSON" {
  let a = Plane::new(normal=g_v3(0.0, 1.0, 0.0), constant=-2.5)
  let json = a.to_json()
  assert_true(json is { "normal": [_, _, _], "constant": Number(-2.5, ..), .. })
  let b = Plane::new().from_json(json)
  assert_true(b.equals(a))
}
