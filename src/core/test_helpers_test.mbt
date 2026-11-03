// Shared helpers for the core tests.

///|
let test_x : Double = 2.0

///|
let test_y : Double = 3.0

///|
let test_z : Double = 4.0

///|
let test_w : Double = 5.0

///|
let test_eps : Double = 0.0001

///|
fn approx(a : Double, b : Double, eps~ : Double = 0.0001) -> Bool {
  (a - b).abs() <= eps
}

///|
extern "js" fn test_pi() -> Double = "() => Math.PI"

///|
fn matrix_equals4(a : @math.Matrix4, b : @math.Matrix4) -> Bool {
  for i in 0..<16 {
    if (a.elements[i] - b.elements[i]).abs() >= test_eps {
      return false
    }
  }
  true
}

///|
fn euler_equals(a : @math.Euler, b : @math.Euler) -> Bool {
  a.order == b.order && approx(a.x, b.x) && approx(a.y, b.y) && approx(a.z, b.z)
}

///|
fn vec3(x : Double, y : Double, z : Double) -> @math.Vector3 {
  @math.Vector3::new(x, y, z)
}
