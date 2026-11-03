///|
let _matrix : Matrix4 = Matrix4::new()

///|
let _euler_quaternion : Quaternion = Quaternion::new(0.0, 0.0, 0.0, 1.0)

///|
/// The default Euler angle order (upstream `Euler.DEFAULT_ORDER`).
pub const EULER_DEFAULT_ORDER : String = "XYZ"

///|
/// Euler angles. Fields are read-only outside this package: write through
/// `set_x`, `set_y`, `set_z`, `set_order` so the change callback fires.
pub struct Euler {
  mut x : Double
  mut y : Double
  mut z : Double
  mut order : String
  mut on_change_callback : () -> Unit
}

///|
/// Constructs a new Euler instance; upstream's default is `(0, 0, 0)`.
pub fn Euler::new(
  x : Double,
  y : Double,
  z : Double,
  order~ : String = EULER_DEFAULT_ORDER,
) -> Euler {
  { x, y, z, order, on_change_callback: () => (), }
}

///|
/// Upstream's `x` setter: assigns and fires the change callback.
pub fn Euler::set_x(self : Euler, value : Double) -> Unit {
  self.x = value
  (self.on_change_callback)()
}

///|
/// Upstream's `y` setter: assigns and fires the change callback.
pub fn Euler::set_y(self : Euler, value : Double) -> Unit {
  self.y = value
  (self.on_change_callback)()
}

///|
/// Upstream's `z` setter: assigns and fires the change callback.
pub fn Euler::set_z(self : Euler, value : Double) -> Unit {
  self.z = value
  (self.on_change_callback)()
}

///|
/// Upstream's `order` setter: assigns and fires the change callback.
pub fn Euler::set_order(self : Euler, value : String) -> Unit {
  self.order = value
  (self.on_change_callback)()
}

///|
/// Sets the Euler components.
pub fn Euler::set(
  self : Euler,
  x : Double,
  y : Double,
  z : Double,
  order~ : String = self.order,
) -> Euler {
  self.x = x
  self.y = y
  self.z = z
  self.order = order
  (self.on_change_callback)()
  self
}

///|
/// Returns a new instance with the same values, without the callback.
pub fn Euler::clone(self : Euler) -> Euler {
  Euler::new(self.x, self.y, self.z, order=self.order)
}

///|
/// Copies the values of `euler` to this instance.
pub fn Euler::copy(self : Euler, euler : Euler) -> Euler {
  self.x = euler.x
  self.y = euler.y
  self.z = euler.z
  self.order = euler.order
  (self.on_change_callback)()
  self
}

///|
/// Sets the angles from a matrix whose upper 3x3 is a pure rotation.
pub fn Euler::set_from_rotation_matrix(
  self : Euler,
  m : Matrix4,
  order~ : String = self.order,
  update~ : Bool = true,
) -> Euler {
  let te = m.elements
  let m11 = te[0]
  let m12 = te[4]
  let m13 = te[8]
  let m21 = te[1]
  let m22 = te[5]
  let m23 = te[9]
  let m31 = te[2]
  let m32 = te[6]
  let m33 = te[10]
  match order {
    "XYZ" => {
      self.y = @cmath.asin(clamp(m13, -1.0, 1.0))
      if m13.abs() < 0.9999999 {
        self.x = @cmath.atan2(-m23, m33)
        self.z = @cmath.atan2(-m12, m11)
      } else {
        self.x = @cmath.atan2(m32, m22)
        self.z = 0.0
      }
    }
    "YXZ" => {
      self.x = @cmath.asin(-clamp(m23, -1.0, 1.0))
      if m23.abs() < 0.9999999 {
        self.y = @cmath.atan2(m13, m33)
        self.z = @cmath.atan2(m21, m22)
      } else {
        self.y = @cmath.atan2(-m31, m11)
        self.z = 0.0
      }
    }
    "ZXY" => {
      self.x = @cmath.asin(clamp(m32, -1.0, 1.0))
      if m32.abs() < 0.9999999 {
        self.y = @cmath.atan2(-m31, m33)
        self.z = @cmath.atan2(-m12, m22)
      } else {
        self.y = 0.0
        self.z = @cmath.atan2(m21, m11)
      }
    }
    "ZYX" => {
      self.y = @cmath.asin(-clamp(m31, -1.0, 1.0))
      if m31.abs() < 0.9999999 {
        self.x = @cmath.atan2(m32, m33)
        self.z = @cmath.atan2(m21, m11)
      } else {
        self.x = 0.0
        self.z = @cmath.atan2(-m12, m22)
      }
    }
    "YZX" => {
      self.z = @cmath.asin(clamp(m21, -1.0, 1.0))
      if m21.abs() < 0.9999999 {
        self.x = @cmath.atan2(-m23, m22)
        self.y = @cmath.atan2(-m31, m11)
      } else {
        self.x = 0.0
        self.y = @cmath.atan2(m13, m33)
      }
    }
    "XZY" => {
      self.z = @cmath.asin(-clamp(m12, -1.0, 1.0))
      if m12.abs() < 0.9999999 {
        self.x = @cmath.atan2(m32, m22)
        self.y = @cmath.atan2(m13, m11)
      } else {
        self.x = @cmath.atan2(-m23, m33)
        self.y = 0.0
      }
    }
    _ =>
      println(
        "Euler: .setFromRotationMatrix() encountered an unknown order: " + order,
      )
  }
  self.order = order
  if update {
    (self.on_change_callback)()
  }
  self
}

///|
/// Sets the angles from a normalized quaternion.
pub fn Euler::set_from_quaternion(
  self : Euler,
  q : Quaternion,
  order~ : String = self.order,
  update~ : Bool = true,
) -> Euler {
  ignore(_matrix.make_rotation_from_quaternion(q))
  self.set_from_rotation_matrix(_matrix, order~, update~)
}

///|
/// Sets the angles from the components of `v`.
pub fn Euler::set_from_vector3(
  self : Euler,
  v : Vector3,
  order~ : String = self.order,
) -> Euler {
  self.set(v.x, v.y, v.z, order~)
}

///|
/// Resets to `new_order` through a quaternion; discards revolution information.
pub fn Euler::reorder(self : Euler, new_order : String) -> Euler {
  ignore(_euler_quaternion.set_from_euler(self))
  self.set_from_quaternion(_euler_quaternion, order=new_order)
}

///|
/// Returns `true` if this instance equals `euler`.
pub fn Euler::equals(self : Euler, euler : Euler) -> Bool {
  euler.x == self.x &&
  euler.y == self.y &&
  euler.z == self.z &&
  euler.order == self.order
}

///|
/// Reads a numeric component of a mixed `[x, y, z, order]` array.
fn euler_component(value : Json) -> Double {
  guard json_to_number(value) is Some(n) else {
    abort("Euler: .fromArray() expects numeric components")
  }
  n
}

///|
/// Sets the angles, and the order if present, from `[x, y, z, order?]`.
pub fn Euler::from_array(self : Euler, array : Array[Json]) -> Euler {
  self.x = euler_component(array[0])
  self.y = euler_component(array[1])
  self.z = euler_component(array[2])
  if array.get(3) is Some(String(order)) {
    self.order = order
  }
  (self.on_change_callback)()
  self
}

///|
/// Writes `[x, y, z, order]` to `array` at `offset`, growing it as needed.
pub fn Euler::to_array(
  self : Euler,
  array~ : Array[Json] = [],
  offset~ : Int32 = 0,
) -> Array[Json] {
  while array.length() < offset + 4 {
    array.push(Json::null())
  }
  array[offset] = json_number(self.x)
  array[offset + 1] = json_number(self.y)
  array[offset + 2] = json_number(self.z)
  array[offset + 3] = Json::string(self.order)
  array
}

///|
/// Sets the callback fired when this instance changes.
pub fn Euler::on_change(self : Euler, callback : () -> Unit) -> Euler {
  self.on_change_callback = callback
  self
}
