///|
test "Ray/Instancing" {
  let mut a = Ray::new()
  assert_true(a.origin.equals(g_zero3))
  assert_true(a.direction.equals(g_v3(0.0, 0.0, -1.0)))
  a = Ray::new(origin=g_two3.clone(), direction=g_one3.clone())
  assert_true(a.origin.equals(g_two3))
  assert_true(a.direction.equals(g_one3))
}

///|
test "Ray/set" {
  let a = Ray::new()
  a.set(g_one3, g_one3) |> ignore
  assert_true(a.origin.equals(g_one3))
  assert_true(a.direction.equals(g_one3))
}

///|
test "Ray/recast/clone" {
  let a = Ray::new(origin=g_one3.clone(), direction=g_v3(0.0, 0.0, 1.0))
  assert_true(a.recast(0.0).equals(a))
  let b = a.clone()
  assert_true(
    b
    .recast(-1.0)
    .equals(Ray::new(origin=g_v3(1.0, 1.0, 0.0), direction=g_v3(0.0, 0.0, 1.0))),
  )
  let c = a.clone()
  assert_true(
    c
    .recast(1.0)
    .equals(Ray::new(origin=g_v3(1.0, 1.0, 2.0), direction=g_v3(0.0, 0.0, 1.0))),
  )
  let d = a.clone()
  let e = d.clone().recast(1.0)
  assert_true(d.equals(a))
  assert_true(!e.equals(d))
  assert_true(e.equals(c))
}

///|
test "Ray/copy/equals" {
  let a = Ray::new(origin=g_zero3.clone(), direction=g_one3.clone())
  let b = Ray::new().copy(a)
  assert_true(b.origin.equals(g_zero3))
  assert_true(b.direction.equals(g_one3))
  // ensure that it is a true copy
  a.origin = g_zero3
  a.direction = g_one3
  assert_true(b.origin.equals(g_zero3))
  assert_true(b.direction.equals(g_one3))
}

///|
test "Ray/at" {
  let a = Ray::new(origin=g_one3.clone(), direction=g_v3(0.0, 0.0, 1.0))
  let point = g_v3(0.0, 0.0, 0.0)
  a.at(0.0, point) |> ignore
  assert_true(point.equals(g_one3))
  a.at(-1.0, point) |> ignore
  assert_true(point.equals(g_v3(1.0, 1.0, 0.0)))
  a.at(1.0, point) |> ignore
  assert_true(point.equals(g_v3(1.0, 1.0, 2.0)))
}

///|
test "Ray/lookAt" {
  let a = Ray::new(origin=g_two3.clone(), direction=g_one3.clone())
  let target = g_one3.clone()
  let expected = target.sub(g_two3).normalize()
  a.look_at(target) |> ignore
  assert_true(a.direction.equals(expected))
}

///|
test "Ray/closestPointToPoint" {
  let a = Ray::new(origin=g_one3.clone(), direction=g_v3(0.0, 0.0, 1.0))
  let point = g_v3(0.0, 0.0, 0.0)
  // behind the ray
  a.closest_point_to_point(g_zero3, point) |> ignore
  assert_true(point.equals(g_one3))
  // front of the ray
  a.closest_point_to_point(g_v3(0.0, 0.0, 50.0), point) |> ignore
  assert_true(point.equals(g_v3(1.0, 1.0, 50.0)))
  // exactly on the ray
  a.closest_point_to_point(g_one3, point) |> ignore
  assert_true(point.equals(g_one3))
}

///|
test "Ray/distanceToPoint" {
  let a = Ray::new(origin=g_one3.clone(), direction=g_v3(0.0, 0.0, 1.0))
  // behind the ray
  let b = a.distance_to_point(g_zero3)
  assert_true(b == 3.0.sqrt())
  // front of the ray
  let c = a.distance_to_point(g_v3(0.0, 0.0, 50.0))
  assert_true(c == 2.0.sqrt())
  // exactly on the ray
  let d = a.distance_to_point(g_one3)
  assert_true(d == 0.0)
}

///|
test "Ray/distanceSqToPoint" {
  let a = Ray::new(origin=g_one3.clone(), direction=g_v3(0.0, 0.0, 1.0))
  // behind the ray
  let b = a.distance_sq_to_point(g_zero3)
  assert_true(b == 3.0)
  // front of the ray
  let c = a.distance_sq_to_point(g_v3(0.0, 0.0, 50.0))
  assert_true(c == 2.0)
  // exactly on the ray
  let d = a.distance_sq_to_point(g_one3)
  assert_true(d == 0.0)
}

///|
test "Ray/distanceSqToSegment" {
  let a = Ray::new(origin=g_one3.clone(), direction=g_v3(0.0, 0.0, 1.0))
  let pt_on_line = g_v3(0.0, 0.0, 0.0)
  let pt_on_segment = g_v3(0.0, 0.0, 0.0)
  //segment in front of the ray
  let mut v0 = g_v3(3.0, 5.0, 50.0)
  let mut v1 = g_v3(50.0, 50.0, 50.0) // just a far away point
  let mut dist_sqr = a.distance_sq_to_segment(
    v0,
    v1,
    optional_point_on_ray=pt_on_line,
    optional_point_on_segment=pt_on_segment,
  )
  assert_true(pt_on_segment.distance_to(v0) < 0.0001)
  assert_true(pt_on_line.distance_to(g_v3(1.0, 1.0, 50.0)) < 0.0001)
  // ((3-1) * (3-1) + (5-1) * (5-1) = 4 + 16 = 20
  assert_true((dist_sqr - 20.0).abs() < 0.0001)
  //segment behind the ray
  v0 = g_v3(-50.0, -50.0, -50.0) // just a far away point
  v1 = g_v3(-3.0, -5.0, -4.0)
  dist_sqr = a.distance_sq_to_segment(
    v0,
    v1,
    optional_point_on_ray=pt_on_line,
    optional_point_on_segment=pt_on_segment,
  )
  assert_true(pt_on_segment.distance_to(v1) < 0.0001)
  assert_true(pt_on_line.distance_to(g_one3) < 0.0001)
  // ((-3-1) * (-3-1) + (-5-1) * (-5-1) + (-4-1) + (-4-1) = 16 + 36 + 25 = 77
  assert_true((dist_sqr - 77.0).abs() < 0.0001)
  //exact intersection between the ray and the segment
  v0 = g_v3(-50.0, -50.0, -50.0)
  v1 = g_v3(50.0, 50.0, 50.0)
  dist_sqr = a.distance_sq_to_segment(
    v0,
    v1,
    optional_point_on_ray=pt_on_line,
    optional_point_on_segment=pt_on_segment,
  )
  assert_true(pt_on_segment.distance_to(g_one3) < 0.0001)
  assert_true(pt_on_line.distance_to(g_one3) < 0.0001)
  assert_true(dist_sqr < 0.0001)
}

///|
test "Ray/intersectSphere" {
  let tol = 0.0001
  let point = g_v3(0.0, 0.0, 0.0)
  // ray a0 origin located at ( 0, 0, 0 ) and points outward in negative-z direction
  let a0 = Ray::new(origin=g_zero3.clone(), direction=g_v3(0.0, 0.0, -1.0))
  // ray a1 origin located at ( 1, 1, 1 ) and points left in negative-x direction
  let a1 = Ray::new(origin=g_one3.clone(), direction=g_v3(-1.0, 0.0, 0.0))
  // sphere (radius of 2) located behind ray a0, should result in null
  let mut b = Sphere::new(center=g_v3(0.0, 0.0, 3.0), radius=2.0)
  a0.intersect_sphere(b, point.copy(g_pos_inf3)) |> ignore
  assert_true(point.equals(g_pos_inf3))
  // sphere (radius of 2) located in front of, but too far right of ray a0, should result in null
  b = Sphere::new(center=g_v3(3.0, 0.0, -1.0), radius=2.0)
  a0.intersect_sphere(b, point.copy(g_pos_inf3)) |> ignore
  assert_true(point.equals(g_pos_inf3))
  // sphere (radius of 2) located below ray a1, should result in null
  b = Sphere::new(center=g_v3(1.0, -2.0, 1.0), radius=2.0)
  a1.intersect_sphere(b, point.copy(g_pos_inf3)) |> ignore
  assert_true(point.equals(g_pos_inf3))
  // sphere (radius of 1) located to the left of ray a1, should result in intersection at 0, 1, 1
  b = Sphere::new(center=g_v3(-1.0, 1.0, 1.0), radius=1.0)
  a1.intersect_sphere(b, point) |> ignore
  assert_true(point.distance_to(g_v3(0.0, 1.0, 1.0)) < tol)
  // sphere (radius of 1) located in front of ray a0, should result in intersection at 0, 0, -1
  b = Sphere::new(center=g_v3(0.0, 0.0, -2.0), radius=1.0)
  a0.intersect_sphere(b, point) |> ignore
  assert_true(point.distance_to(g_v3(0.0, 0.0, -1.0)) < tol)
  // sphere (radius of 2) located in front & right of ray a0, should result in intersection at 0, 0, -1, or left-most edge of sphere
  b = Sphere::new(center=g_v3(2.0, 0.0, -1.0), radius=2.0)
  a0.intersect_sphere(b, point) |> ignore
  assert_true(point.distance_to(g_v3(0.0, 0.0, -1.0)) < tol)
  // same situation as above, but move the sphere a fraction more to the right, and ray a0 should now just miss
  b = Sphere::new(center=g_v3(2.01, 0.0, -1.0), radius=2.0)
  a0.intersect_sphere(b, point.copy(g_pos_inf3)) |> ignore
  assert_true(point.equals(g_pos_inf3))
  // following QUnit.tests are for situations where the ray origin is inside the sphere
  // sphere (radius of 1) center located at ray a0 origin / sphere surrounds the ray origin, so the first intersect point 0, 0, 1,
  // is behind ray a0.  Therefore, second exit point on back of sphere will be returned: 0, 0, -1
  // thus keeping the intersection point always in front of the ray.
  b = Sphere::new(center=g_zero3.clone(), radius=1.0)
  a0.intersect_sphere(b, point) |> ignore
  assert_true(point.distance_to(g_v3(0.0, 0.0, -1.0)) < tol)
  // sphere (radius of 4) center located behind ray a0 origin / sphere surrounds the ray origin, so the first intersect point 0, 0, 5,
  // is behind ray a0.  Therefore, second exit point on back of sphere will be returned: 0, 0, -3
  // thus keeping the intersection point always in front of the ray.
  b = Sphere::new(center=g_v3(0.0, 0.0, 1.0), radius=4.0)
  a0.intersect_sphere(b, point) |> ignore
  assert_true(point.distance_to(g_v3(0.0, 0.0, -3.0)) < tol)
  // sphere (radius of 4) center located in front of ray a0 origin / sphere surrounds the ray origin, so the first intersect point 0, 0, 3,
  // is behind ray a0.  Therefore, second exit point on back of sphere will be returned: 0, 0, -5
  // thus keeping the intersection point always in front of the ray.
  b = Sphere::new(center=g_v3(0.0, 0.0, -1.0), radius=4.0)
  a0.intersect_sphere(b, point) |> ignore
  assert_true(point.distance_to(g_v3(0.0, 0.0, -5.0)) < tol)
  // empty sphere ( negative radius ) can never be intersected, so the
  // target must be left untouched and the return value must be null,
  // consistent with intersectsSphere()
  b = Sphere::new(center=g_v3(0.0, 0.0, -1.0), radius=-1.0)
  assert_true(a0.intersect_sphere(b, point.copy(g_pos_inf3)) is None)
  assert_true(point.equals(g_pos_inf3))
}

///|
test "Ray/intersectsSphere" {
  let a = Ray::new(origin=g_one3.clone(), direction=g_v3(0.0, 0.0, 1.0))
  let b = Sphere::new(center=g_zero3, radius=0.5)
  let c = Sphere::new(center=g_zero3, radius=1.5)
  let d = Sphere::new(center=g_one3, radius=0.1)
  let e = Sphere::new(center=g_two3, radius=0.1)
  let f = Sphere::new(center=g_two3, radius=1.0)
  assert_true(!a.intersects_sphere(b))
  assert_true(!a.intersects_sphere(c))
  assert_true(a.intersects_sphere(d))
  assert_true(!a.intersects_sphere(e))
  assert_true(!a.intersects_sphere(f))
}

///|
test "Ray/intersectPlane" {
  let a = Ray::new(origin=g_one3.clone(), direction=g_v3(0.0, 0.0, 1.0))
  let point = g_v3(0.0, 0.0, 0.0)
  // parallel plane behind
  let b = Plane::new().set_from_normal_and_coplanar_point(
    g_v3(0.0, 0.0, 1.0),
    g_v3(1.0, 1.0, -1.0),
  )
  a.intersect_plane(b, point.copy(g_pos_inf3)) |> ignore
  assert_true(point.equals(g_pos_inf3))
  // parallel plane coincident with origin
  let c = Plane::new().set_from_normal_and_coplanar_point(
    g_v3(0.0, 0.0, 1.0),
    g_v3(1.0, 1.0, 0.0),
  )
  a.intersect_plane(c, point.copy(g_pos_inf3)) |> ignore
  assert_true(point.equals(g_pos_inf3))
  // parallel plane in front
  let d = Plane::new().set_from_normal_and_coplanar_point(
    g_v3(0.0, 0.0, 1.0),
    g_v3(1.0, 1.0, 1.0),
  )
  a.intersect_plane(d, point.copy(g_pos_inf3)) |> ignore
  assert_true(point.equals(a.origin))
  // perpendicular ray that overlaps exactly
  let e = Plane::new().set_from_normal_and_coplanar_point(
    g_v3(1.0, 0.0, 0.0),
    g_one3,
  )
  a.intersect_plane(e, point.copy(g_pos_inf3)) |> ignore
  assert_true(point.equals(a.origin))
  // perpendicular ray that doesn't overlap
  let f = Plane::new().set_from_normal_and_coplanar_point(
    g_v3(1.0, 0.0, 0.0),
    g_zero3,
  )
  a.intersect_plane(f, point.copy(g_pos_inf3)) |> ignore
  assert_true(point.equals(g_pos_inf3))
}

///|
test "Ray/intersectsPlane" {
  let a = Ray::new(origin=g_one3.clone(), direction=g_v3(0.0, 0.0, 1.0))
  // parallel plane in front of the ray
  let b = Plane::new().set_from_normal_and_coplanar_point(
    g_v3(0.0, 0.0, 1.0),
    g_one3.clone().sub(g_v3(0.0, 0.0, -1.0)),
  )
  assert_true(a.intersects_plane(b))
  // parallel plane coincident with origin
  let c = Plane::new().set_from_normal_and_coplanar_point(
    g_v3(0.0, 0.0, 1.0),
    g_one3.clone().sub(g_v3(0.0, 0.0, 0.0)),
  )
  assert_true(a.intersects_plane(c))
  // parallel plane behind the ray
  let d = Plane::new().set_from_normal_and_coplanar_point(
    g_v3(0.0, 0.0, 1.0),
    g_one3.clone().sub(g_v3(0.0, 0.0, 1.0)),
  )
  assert_true(!a.intersects_plane(d))
  // perpendicular ray that overlaps exactly
  let e = Plane::new().set_from_normal_and_coplanar_point(
    g_v3(1.0, 0.0, 0.0),
    g_one3,
  )
  assert_true(a.intersects_plane(e))
  // perpendicular ray that doesn't overlap
  let f = Plane::new().set_from_normal_and_coplanar_point(
    g_v3(1.0, 0.0, 0.0),
    g_zero3,
  )
  assert_true(!a.intersects_plane(f))
}

///|
test "Ray/intersectBox" {
  let tol = 0.0001
  let box = Box3::new(min=g_v3(-1.0, -1.0, -1.0), max=g_v3(1.0, 1.0, 1.0))
  let point = g_v3(0.0, 0.0, 0.0)
  let a = Ray::new(origin=g_v3(-2.0, 0.0, 0.0), direction=g_v3(1.0, 0.0, 0.0))
  //ray should intersect box at -1,0,0
  assert_true(a.intersects_box(box) == true)
  a.intersect_box(box, point) |> ignore
  assert_true(point.distance_to(g_v3(-1.0, 0.0, 0.0)) < tol)
  let b = Ray::new(origin=g_v3(-2.0, 0.0, 0.0), direction=g_v3(-1.0, 0.0, 0.0))
  //ray is point away from box, it should not intersect
  assert_true(b.intersects_box(box) == false)
  b.intersect_box(box, point.copy(g_pos_inf3)) |> ignore
  assert_true(point.equals(g_pos_inf3))
  let c = Ray::new(origin=g_v3(0.0, 0.0, 0.0), direction=g_v3(1.0, 0.0, 0.0))
  // ray is inside box, should return exit point
  assert_true(c.intersects_box(box) == true)
  c.intersect_box(box, point) |> ignore
  assert_true(point.distance_to(g_v3(1.0, 0.0, 0.0)) < tol)
  let d = Ray::new(
    origin=g_v3(0.0, 2.0, 1.0),
    direction=g_v3(0.0, -1.0, -1.0).normalize(),
  )
  //tilted ray should intersect box at 0,1,0
  assert_true(d.intersects_box(box) == true)
  d.intersect_box(box, point) |> ignore
  assert_true(point.distance_to(g_v3(0.0, 1.0, 0.0)) < tol)
  let e = Ray::new(
    origin=g_v3(1.0, -2.0, 1.0),
    direction=g_v3(0.0, 1.0, 0.0).normalize(),
  )
  //handle case where ray is coplanar with one of the boxes side - box in front of ray
  assert_true(e.intersects_box(box) == true)
  e.intersect_box(box, point) |> ignore
  assert_true(point.distance_to(g_v3(1.0, -1.0, 1.0)) < tol)
  let f = Ray::new(
    origin=g_v3(1.0, -2.0, 0.0),
    direction=g_v3(0.0, -1.0, 0.0).normalize(),
  )
  //handle case where ray is coplanar with one of the boxes side - box behind ray
  assert_true(f.intersects_box(box) == false)
  f.intersect_box(box, point.copy(g_pos_inf3)) |> ignore
  assert_true(point.equals(g_pos_inf3))
}

///|
test "Ray/intersectTriangle" {
  let ray = Ray::new()
  let a = g_v3(1.0, 1.0, 0.0)
  let b = g_v3(0.0, 1.0, 1.0)
  let c = g_v3(1.0, 0.0, 1.0)
  let point = g_v3(0.0, 0.0, 0.0)
  // DdN == 0
  ray.set(ray.origin, g_zero3.clone()) |> ignore
  ray.intersect_triangle(a, b, c, false, point.copy(g_pos_inf3)) |> ignore
  assert_true(point.equals(g_pos_inf3))
  // DdN > 0, backfaceCulling = true
  ray.set(ray.origin, g_one3.clone()) |> ignore
  ray.intersect_triangle(a, b, c, true, point.copy(g_pos_inf3)) |> ignore
  assert_true(point.equals(g_pos_inf3))
  // DdN > 0
  ray.set(ray.origin, g_one3.clone()) |> ignore
  ray.intersect_triangle(a, b, c, false, point) |> ignore
  assert_true((point.x - 2.0 / 3.0).abs() <= g_eps)
  assert_true((point.y - 2.0 / 3.0).abs() <= g_eps)
  assert_true((point.z - 2.0 / 3.0).abs() <= g_eps)
  // DdN > 0, DdQxE2 < 0
  b.multiply_scalar(-1.0) |> ignore
  ray.intersect_triangle(a, b, c, false, point.copy(g_pos_inf3)) |> ignore
  assert_true(point.equals(g_pos_inf3))
  // DdN > 0, DdE1xQ < 0
  a.multiply_scalar(-1.0) |> ignore
  ray.intersect_triangle(a, b, c, false, point.copy(g_pos_inf3)) |> ignore
  assert_true(point.equals(g_pos_inf3))
  // DdN > 0, DdQxE2 + DdE1xQ > DdN
  b.multiply_scalar(-1.0) |> ignore
  ray.intersect_triangle(a, b, c, false, point.copy(g_pos_inf3)) |> ignore
  assert_true(point.equals(g_pos_inf3))
  // DdN < 0, QdN < 0
  a.multiply_scalar(-1.0) |> ignore
  b.multiply_scalar(-1.0) |> ignore
  ray.direction.multiply_scalar(-1.0) |> ignore
  ray.intersect_triangle(a, b, c, false, point.copy(g_pos_inf3)) |> ignore
  assert_true(point.equals(g_pos_inf3))
}

///|
test "Ray/intersectTriangle (watertight at shared edges)" {
  // Two triangles forming a quad and sharing the diagonal edge from
  // ( -2, -2, -2 ) to ( 2, -2, 2 ). A ray aimed exactly at the midpoint of
  // that shared edge must be detected: a non-watertight test can let the ray
  // slip through the seam between the triangles and miss both of them.
  let t1a = g_v3(-2.0, -2.0, 2.0)
  let t1b = g_v3(-2.0, -2.0, -2.0)
  let t1c = g_v3(2.0, -2.0, 2.0)
  let t2a = g_v3(-2.0, -2.0, -2.0)
  let t2b = g_v3(2.0, -2.0, -2.0)
  let t2c = g_v3(2.0, -2.0, 2.0)
  let seam = g_v3(0.0, -2.0, 0.0) // midpoint of the shared edge
  let origin = g_v3(-4.0, -9.0, 0.4)
  let direction = g_v3(0.0, 0.0, 0.0).sub_vectors(seam, origin).normalize()
  let ray = Ray::new(origin~, direction~)
  let p1 = g_v3(0.0, 0.0, 0.0)
  let p2 = g_v3(0.0, 0.0, 0.0)
  let hit1 = ray.intersect_triangle(t1a, t1b, t1c, false, p1)
  let hit2 = ray.intersect_triangle(t2a, t2b, t2c, false, p2)
  assert_true(hit1 is Some(_) || hit2 is Some(_))
  let hit = if hit1 is Some(_) { p1 } else { p2 }
  assert_true(hit.distance_to(seam) <= g_eps)
}

///|
test "Ray/applyMatrix4" {
  let mut a = Ray::new(origin=g_one3.clone(), direction=g_v3(0.0, 0.0, 1.0))
  let m = g_m4()
  assert_true(a.clone().apply_matrix4(m).equals(a))
  a = Ray::new(origin=g_zero3.clone(), direction=g_v3(0.0, 0.0, 1.0))
  m.make_rotation_z(@cmath.PI) |> ignore
  assert_true(a.clone().apply_matrix4(m).equals(a))
  m.make_rotation_x(@cmath.PI) |> ignore
  let b = a.clone()
  b.direction.negate() |> ignore
  let mut a2 = a.clone().apply_matrix4(m)
  assert_true(a2.origin.distance_to(b.origin) < 0.0001)
  assert_true(a2.direction.distance_to(b.direction) < 0.0001)
  a.origin = g_v3(0.0, 0.0, 1.0)
  b.origin = g_v3(0.0, 0.0, -1.0)
  a2 = a.clone().apply_matrix4(m)
  assert_true(a2.origin.distance_to(b.origin) < 0.0001)
  assert_true(a2.direction.distance_to(b.direction) < 0.0001)
}
