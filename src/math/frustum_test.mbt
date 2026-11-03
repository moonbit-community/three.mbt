///|
test "Frustum/Instancing" {
  let mut a = Frustum::new()
  assert_true(a.planes.length() == 6)
  let p_default = Plane::new()
  for i in 0..<6 {
    assert_true(a.planes[i].equals(p_default))
  }
  let p0 = Plane::new(normal=g_unit3, constant=-1.0)
  let p1 = Plane::new(normal=g_unit3, constant=1.0)
  let p2 = Plane::new(normal=g_unit3, constant=2.0)
  let p3 = Plane::new(normal=g_unit3, constant=3.0)
  let p4 = Plane::new(normal=g_unit3, constant=4.0)
  let p5 = Plane::new(normal=g_unit3, constant=5.0)
  a = Frustum::new(p0~, p1~, p2~, p3~, p4~, p5~)
  assert_true(a.planes[0].equals(p0))
  assert_true(a.planes[1].equals(p1))
  assert_true(a.planes[2].equals(p2))
  assert_true(a.planes[3].equals(p3))
  assert_true(a.planes[4].equals(p4))
  assert_true(a.planes[5].equals(p5))
}

///|
test "Frustum/set" {
  let a = Frustum::new()
  let p0 = Plane::new(normal=g_unit3, constant=-1.0)
  let p1 = Plane::new(normal=g_unit3, constant=1.0)
  let p2 = Plane::new(normal=g_unit3, constant=2.0)
  let p3 = Plane::new(normal=g_unit3, constant=3.0)
  let p4 = Plane::new(normal=g_unit3, constant=4.0)
  let p5 = Plane::new(normal=g_unit3, constant=5.0)
  a.set(p0, p1, p2, p3, p4, p5) |> ignore
  assert_true(a.planes[0].equals(p0))
  assert_true(a.planes[1].equals(p1))
  assert_true(a.planes[2].equals(p2))
  assert_true(a.planes[3].equals(p3))
  assert_true(a.planes[4].equals(p4))
  assert_true(a.planes[5].equals(p5))
}

///|
test "Frustum/clone" {
  let p0 = Plane::new(normal=g_unit3, constant=-1.0)
  let p1 = Plane::new(normal=g_unit3, constant=1.0)
  let p2 = Plane::new(normal=g_unit3, constant=2.0)
  let p3 = Plane::new(normal=g_unit3, constant=3.0)
  let p4 = Plane::new(normal=g_unit3, constant=4.0)
  let p5 = Plane::new(normal=g_unit3, constant=5.0)
  let b = Frustum::new(p0~, p1~, p2~, p3~, p4~, p5~)
  let a = b.clone()
  assert_true(a.planes[0].equals(p0))
  assert_true(a.planes[1].equals(p1))
  assert_true(a.planes[2].equals(p2))
  assert_true(a.planes[3].equals(p3))
  assert_true(a.planes[4].equals(p4))
  assert_true(a.planes[5].equals(p5))
  // ensure it is a true copy by modifying source
  a.planes[0].copy(p1) |> ignore
  assert_true(b.planes[0].equals(p0))
}

///|
test "Frustum/copy" {
  let p0 = Plane::new(normal=g_unit3, constant=-1.0)
  let p1 = Plane::new(normal=g_unit3, constant=1.0)
  let p2 = Plane::new(normal=g_unit3, constant=2.0)
  let p3 = Plane::new(normal=g_unit3, constant=3.0)
  let p4 = Plane::new(normal=g_unit3, constant=4.0)
  let p5 = Plane::new(normal=g_unit3, constant=5.0)
  let b = Frustum::new(p0~, p1~, p2~, p3~, p4~, p5~)
  let a = Frustum::new().copy(b)
  assert_true(a.planes[0].equals(p0))
  assert_true(a.planes[1].equals(p1))
  assert_true(a.planes[2].equals(p2))
  assert_true(a.planes[3].equals(p3))
  assert_true(a.planes[4].equals(p4))
  assert_true(a.planes[5].equals(p5))
  // ensure it is a true copy by modifying source
  b.planes[0] = p1
  assert_true(a.planes[0].equals(p0))
}

///|
test "Frustum/setFromProjectionMatrix/makeOrthographic/containsPoint" {
  let m = g_m4().make_orthographic(-1.0, 1.0, 1.0, -1.0, 1.0, 100.0)
  let a = Frustum::new().set_from_projection_matrix(m)
  assert_true(!a.contains_point(g_v3(0.0, 0.0, 0.0)))
  assert_true(a.contains_point(g_v3(0.0, 0.0, -50.0)))
  assert_true(a.contains_point(g_v3(0.0, 0.0, -1.001)))
  assert_true(a.contains_point(g_v3(-1.0, -1.0, -1.001)))
  assert_true(!a.contains_point(g_v3(-1.1, -1.1, -1.001)))
  assert_true(a.contains_point(g_v3(1.0, 1.0, -1.001)))
  assert_true(!a.contains_point(g_v3(1.1, 1.1, -1.001)))
  assert_true(a.contains_point(g_v3(0.0, 0.0, -99.999)))
  assert_true(a.contains_point(g_v3(-0.999, -0.999, -99.999)))
  assert_true(!a.contains_point(g_v3(-1.1, -1.1, -100.1)))
  assert_true(a.contains_point(g_v3(0.999, 0.999, -99.999)))
  assert_true(!a.contains_point(g_v3(1.1, 1.1, -100.1)))
  assert_true(!a.contains_point(g_v3(0.0, 0.0, -101.0)))
}

///|
test "Frustum/setFromProjectionMatrix/makePerspective/containsPoint" {
  let m = g_m4().make_perspective(-1.0, 1.0, 1.0, -1.0, 1.0, 100.0)
  let a = Frustum::new().set_from_projection_matrix(m)
  assert_true(!a.contains_point(g_v3(0.0, 0.0, 0.0)))
  assert_true(a.contains_point(g_v3(0.0, 0.0, -50.0)))
  assert_true(a.contains_point(g_v3(0.0, 0.0, -1.001)))
  assert_true(a.contains_point(g_v3(-1.0, -1.0, -1.001)))
  assert_true(!a.contains_point(g_v3(-1.1, -1.1, -1.001)))
  assert_true(a.contains_point(g_v3(1.0, 1.0, -1.001)))
  assert_true(!a.contains_point(g_v3(1.1, 1.1, -1.001)))
  assert_true(a.contains_point(g_v3(0.0, 0.0, -99.999)))
  assert_true(a.contains_point(g_v3(-99.999, -99.999, -99.999)))
  assert_true(!a.contains_point(g_v3(-100.1, -100.1, -100.1)))
  assert_true(a.contains_point(g_v3(99.999, 99.999, -99.999)))
  assert_true(!a.contains_point(g_v3(100.1, 100.1, -100.1)))
  assert_true(!a.contains_point(g_v3(0.0, 0.0, -101.0)))
}

///|
test "Frustum/setFromProjectionMatrix/makePerspective/intersectsSphere" {
  let m = g_m4().make_perspective(-1.0, 1.0, 1.0, -1.0, 1.0, 100.0)
  let a = Frustum::new().set_from_projection_matrix(m)
  assert_true(
    !a.intersects_sphere(Sphere::new(center=g_v3(0.0, 0.0, 0.0), radius=0.0)),
  )
  assert_true(
    !a.intersects_sphere(Sphere::new(center=g_v3(0.0, 0.0, 0.0), radius=0.9)),
  )
  assert_true(
    a.intersects_sphere(Sphere::new(center=g_v3(0.0, 0.0, 0.0), radius=1.1)),
  )
  assert_true(
    a.intersects_sphere(Sphere::new(center=g_v3(0.0, 0.0, -50.0), radius=0.0)),
  )
  assert_true(
    a.intersects_sphere(Sphere::new(center=g_v3(0.0, 0.0, -1.001), radius=0.0)),
  )
  assert_true(
    a.intersects_sphere(
      Sphere::new(center=g_v3(-1.0, -1.0, -1.001), radius=0.0),
    ),
  )
  assert_true(
    !a.intersects_sphere(
      Sphere::new(center=g_v3(-1.1, -1.1, -1.001), radius=0.0),
    ),
  )
  assert_true(
    a.intersects_sphere(
      Sphere::new(center=g_v3(-1.1, -1.1, -1.001), radius=0.5),
    ),
  )
  assert_true(
    a.intersects_sphere(Sphere::new(center=g_v3(1.0, 1.0, -1.001), radius=0.0)),
  )
  assert_true(
    !a.intersects_sphere(Sphere::new(center=g_v3(1.1, 1.1, -1.001), radius=0.0)),
  )
  assert_true(
    a.intersects_sphere(Sphere::new(center=g_v3(1.1, 1.1, -1.001), radius=0.5)),
  )
  assert_true(
    a.intersects_sphere(Sphere::new(center=g_v3(0.0, 0.0, -99.999), radius=0.0)),
  )
  assert_true(
    a.intersects_sphere(
      Sphere::new(center=g_v3(-99.999, -99.999, -99.999), radius=0.0),
    ),
  )
  assert_true(
    !a.intersects_sphere(
      Sphere::new(center=g_v3(-100.1, -100.1, -100.1), radius=0.0),
    ),
  )
  assert_true(
    a.intersects_sphere(
      Sphere::new(center=g_v3(-100.1, -100.1, -100.1), radius=0.5),
    ),
  )
  assert_true(
    a.intersects_sphere(
      Sphere::new(center=g_v3(99.999, 99.999, -99.999), radius=0.0),
    ),
  )
  assert_true(
    !a.intersects_sphere(
      Sphere::new(center=g_v3(100.1, 100.1, -100.1), radius=0.0),
    ),
  )
  assert_true(
    a.intersects_sphere(
      Sphere::new(center=g_v3(100.1, 100.1, -100.1), radius=0.2),
    ),
  )
  assert_true(
    !a.intersects_sphere(Sphere::new(center=g_v3(0.0, 0.0, -101.0), radius=0.0)),
  )
  assert_true(
    a.intersects_sphere(Sphere::new(center=g_v3(0.0, 0.0, -101.0), radius=1.1)),
  )
}

///|
test "Frustum/intersectsBox" {
  let m = g_m4().make_perspective(-1.0, 1.0, 1.0, -1.0, 1.0, 100.0)
  let a = Frustum::new().set_from_projection_matrix(m)
  let box = Box3::new(min=g_zero3.clone(), max=g_one3.clone())
  let mut intersects = false
  intersects = a.intersects_box(box)
  assert_false(intersects)
  // add eps so that we prevent box touching the frustum,
  // which might intersect depending on floating point numerics
  box.translate(g_v3(-1.0 - g_eps, -1.0 - g_eps, -1.0 - g_eps)) |> ignore
  intersects = a.intersects_box(box)
  assert_true(intersects)
}
