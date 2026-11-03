///|
using @math {
  type Box2,
  type Box3,
  type Frustum,
  type FrustumArray,
  type Line3,
  type Plane,
  type Ray,
  type Sphere,
  type Triangle,
}

///|
/// Shared by the box, sphere, plane, ray, line, triangle and frustum tests.
/// Mirrors upstream `test/unit/utils/math-constants.js`.
let g_x : Double = 2.0

///|
let g_y : Double = 3.0

///|
let g_z : Double = 4.0

///|
let g_w : Double = 5.0

///|
let g_inf : Double = 1.0 / 0.0

///|
let g_neg_inf2 : @math.Vector2 = g_v2(-g_inf, -g_inf)

///|
let g_pos_inf2 : @math.Vector2 = g_v2(g_inf, g_inf)

///|
let g_neg_one2 : @math.Vector2 = g_v2(-1.0, -1.0)

///|
let g_zero2 : @math.Vector2 = g_v2(0.0, 0.0)

///|
let g_one2 : @math.Vector2 = g_v2(1.0, 1.0)

///|
let g_two2 : @math.Vector2 = g_v2(2.0, 2.0)

///|
let g_neg_inf3 : @math.Vector3 = g_v3(-g_inf, -g_inf, -g_inf)

///|
let g_pos_inf3 : @math.Vector3 = g_v3(g_inf, g_inf, g_inf)

///|
let g_zero3 : @math.Vector3 = g_v3(0.0, 0.0, 0.0)

///|
let g_one3 : @math.Vector3 = g_v3(1.0, 1.0, 1.0)

///|
let g_two3 : @math.Vector3 = g_v3(2.0, 2.0, 2.0)

///|
let g_unit3 : @math.Vector3 = g_v3(1.0, 0.0, 0.0)

///|
let g_eps : Double = 0.0001

///|
fn g_v2(x : Double, y : Double) -> @math.Vector2 {
  @math.Vector2::new(x, y)
}

///|
fn g_v3(x : Double, y : Double, z : Double) -> @math.Vector3 {
  @math.Vector3::new(x, y, z)
}

///|
fn g_v4(x : Double, y : Double, z : Double, w : Double) -> @math.Vector4 {
  @math.Vector4::new(x, y, z, w)
}

///|
fn g_m4() -> @math.Matrix4 {
  @math.Matrix4::new()
}

///|
/// Upstream `assert.numEqual`, which tolerates a difference below 0.1.
fn g_num_equal(actual : Double, expected : Double) -> Unit raise {
  assert_true((actual - expected).abs() < 0.1)
}

///|
fn g_compare_box(a : Box3, b : Box3) -> Bool {
  let threshold = 0.0001
  a.min.distance_to(b.min) < threshold && a.max.distance_to(b.max) < threshold
}

///|
fn g_compare_plane(a : Plane, b : Plane) -> Bool {
  let threshold = 0.0001
  a.normal.distance_to(b.normal) < threshold &&
  (a.constant - b.constant).abs() < threshold
}
