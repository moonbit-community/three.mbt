///|
/// Upstream has no FrustumArray tests. These cover the ported surface.
fn g_frustum_array() -> FrustumArray {
  let m = g_m4().make_perspective(-1.0, 1.0, 1.0, -1.0, 1.0, 100.0)
  let near = Frustum::new().set_from_projection_matrix(m)
  let far = Frustum::new().set_from_projection_matrix(
    g_m4().make_translation(0.0, 0.0, -1000.0).premultiply(m),
  )
  let a = FrustumArray::new()
  a.frustums.push(near)
  a.frustums.push(far)
  a.frustums.push(Frustum::new())
  a.count = 2
  a
}

///|
test "FrustumArray/Instancing" {
  let a = FrustumArray::new()
  assert_true(a.coordinate_system == @math.WebGLCoordinateSystem)
  assert_true(a.frustums.length() == 0)
  assert_true(a.count == 0)
  assert_true(a.get_frustum(0) is None)
  assert_false(a.contains_point(g_zero3))
  assert_false(a.intersects_sphere(Sphere::new(radius=1000.0)))
  assert_false(a.intersects_box(Box3::new(min=g_zero3, max=g_one3)))
}

///|
test "FrustumArray/getFrustum" {
  let a = g_frustum_array()
  assert_true(a.get_frustum(0) is Some(f) && physical_equal(f, a.frustums[0]))
  assert_true(a.get_frustum(1) is Some(f) && physical_equal(f, a.frustums[1]))
  assert_true(a.get_frustum(2) is Some(_))
  assert_true(a.get_frustum(3) is None)
}

///|
test "FrustumArray/containsPoint" {
  let a = g_frustum_array()
  assert_true(a.contains_point(g_v3(0.0, 0.0, -50.0)))
  assert_true(a.contains_point(g_v3(0.0, 0.0, 950.0)))
  assert_false(a.contains_point(g_v3(0.0, 0.0, 500.0)))
  // entries past count are pooled, not consulted
  a.count = 1
  assert_false(a.contains_point(g_v3(0.0, 0.0, 950.0)))
}

///|
test "FrustumArray/intersectsSphere" {
  let a = g_frustum_array()
  assert_true(
    a.intersects_sphere(Sphere::new(center=g_v3(0.0, 0.0, -50.0), radius=0.0)),
  )
  assert_true(
    a.intersects_sphere(Sphere::new(center=g_v3(0.0, 0.0, 950.0), radius=0.0)),
  )
  assert_false(
    a.intersects_sphere(Sphere::new(center=g_v3(0.0, 0.0, 500.0), radius=0.0)),
  )
}

///|
test "FrustumArray/intersectsBox" {
  let a = g_frustum_array()
  let box = Box3::new(min=g_v3(-1.0, -1.0, -51.0), max=g_v3(1.0, 1.0, -49.0))
  assert_true(a.intersects_box(box))
  box.translate(g_v3(0.0, 0.0, 1000.0)) |> ignore
  assert_true(a.intersects_box(box))
  box.translate(g_v3(0.0, 0.0, -500.0)) |> ignore
  assert_false(a.intersects_box(box))
}

///|
test "FrustumArray/copy/clone" {
  let a = g_frustum_array()
  a.coordinate_system = @math.WebGPUCoordinateSystem
  let b = a.clone()
  assert_true(b.coordinate_system == @math.WebGPUCoordinateSystem)
  assert_true(b.count == 2)
  assert_true(b.frustums.length() == 2)
  assert_true(b.contains_point(g_v3(0.0, 0.0, 950.0)))
  // ensure that it is a true copy
  assert_false(physical_equal(b.frustums[0], a.frustums[0]))
  a.frustums[0].planes[0].constant = 12345.0
  assert_true(b.frustums[0].planes[0].constant != 12345.0)
  // an existing frustum in the pool is reused
  let kept = b.frustums[0]
  b.copy(a) |> ignore
  assert_true(physical_equal(b.frustums[0], kept))
  assert_true(b.frustums[0].planes[0].constant == 12345.0)
}
