///|
/// Stands in for `BufferAttribute` until `core` is ported.
struct VectorTestAttribute {
  array : Array[Double]
  item_size : Int32
}

///|
fn VectorTestAttribute::new(
  array : Array[Double],
  item_size : Int32,
) -> VectorTestAttribute {
  { array, item_size, }
}

///|
impl @math.BufferAttributeLike for VectorTestAttribute with fn get_x(
  self,
  index,
) {
  self.array[index * self.item_size]
}

///|
impl @math.BufferAttributeLike for VectorTestAttribute with fn get_y(
  self,
  index,
) {
  self.array[index * self.item_size + 1]
}

///|
impl @math.BufferAttributeLike for VectorTestAttribute with fn get_z(
  self,
  index,
) {
  self.array[index * self.item_size + 2]
}

///|
impl @math.BufferAttributeLike for VectorTestAttribute with fn get_w(
  self,
  index,
) {
  self.array[index * self.item_size + 3]
}

///|
test "Vector2: Instancing" {
  let x = 2.0
  let y = 3.0
  let mut a = @math.Vector2::new(0.0, 0.0)
  assert_true(a.x == 0.0)
  assert_true(a.y == 0.0)
  a = @math.Vector2::new(x, y)
  assert_true(a.x == x)
  assert_true(a.y == y)
}

///|
test "Vector2: properties" {
  let a = @math.Vector2::new(0.0, 0.0)
  let width = 100.0
  let height = 200.0
  a.set_width(width)
  a.set_height(height)
  assert_eq(a.x, width)
  assert_eq(a.y, height)
  a.set(width, height) |> ignore
  assert_eq(a.width(), width)
  assert_eq(a.height(), height)
}

///|
test "Vector2: set" {
  let x = 2.0
  let y = 3.0
  let a = @math.Vector2::new(0.0, 0.0)
  assert_true(a.x == 0.0)
  assert_true(a.y == 0.0)
  a.set(x, y) |> ignore
  assert_true(a.x == x)
  assert_true(a.y == y)
}

///|
test "Vector2: copy" {
  let x = 2.0
  let y = 3.0
  let a = @math.Vector2::new(x, y)
  let b = @math.Vector2::new(0.0, 0.0).copy(a)
  assert_true(b.x == x)
  assert_true(b.y == y)
  a.x = 0.0
  a.y = -1.0
  assert_true(b.x == x)
  assert_true(b.y == y)
}

///|
test "Vector2: add" {
  let x = 2.0
  let y = 3.0
  let a = @math.Vector2::new(x, y)
  let b = @math.Vector2::new(-x, -y)
  a.add(b) |> ignore
  assert_true(a.x == 0.0)
  assert_true(a.y == 0.0)
  let c = @math.Vector2::new(0.0, 0.0).add_vectors(b, b)
  assert_true(c.x == -2.0 * x)
  assert_true(c.y == -2.0 * y)
}

///|
test "Vector2: addScaledVector" {
  let x = 2.0
  let y = 3.0
  let a = @math.Vector2::new(x, y)
  let b = @math.Vector2::new(2.0, 3.0)
  let s = 3.0
  a.add_scaled_vector(b, s) |> ignore
  assert_eq(a.x, x + b.x * s)
  assert_eq(a.y, y + b.y * s)
}

///|
test "Vector2: sub" {
  let x = 2.0
  let y = 3.0
  let a = @math.Vector2::new(x, y)
  let b = @math.Vector2::new(-x, -y)
  a.sub(b) |> ignore
  assert_true(a.x == 2.0 * x)
  assert_true(a.y == 2.0 * y)
  let c = @math.Vector2::new(0.0, 0.0).sub_vectors(a, a)
  assert_true(c.x == 0.0)
  assert_true(c.y == 0.0)
}

///|
test "Vector2: applyMatrix3" {
  let x = 2.0
  let y = 3.0
  let a = @math.Vector2::new(x, y)
  let m = @math.Matrix3::new().set(
    2.0, 3.0, 5.0, 7.0, 11.0, 13.0, 17.0, 19.0, 23.0,
  )
  a.apply_matrix3(m) |> ignore
  assert_eq(a.x, 18.0)
  assert_eq(a.y, 60.0)
}

///|
test "Vector2: negate" {
  let x = 2.0
  let y = 3.0
  let a = @math.Vector2::new(x, y)
  a.negate() |> ignore
  assert_true(a.x == -x)
  assert_true(a.y == -y)
}

///|
test "Vector2: dot" {
  let x = 2.0
  let y = 3.0
  let a = @math.Vector2::new(x, y)
  let b = @math.Vector2::new(-x, -y)
  let c = @math.Vector2::new(0.0, 0.0)
  let mut result = a.dot(b)
  assert_true(result == -x * x - y * y)
  result = a.dot(c)
  assert_true(result == 0.0)
}

///|
test "Vector2: cross" {
  let x = 2.0
  let y = 3.0
  let eps = 0.0001
  let a = @math.Vector2::new(x, y)
  let b = @math.Vector2::new(2.0 * x, -y)
  let answer = -18.0
  let crossed = a.cross(b)
  assert_true((answer - crossed).abs() <= eps)
}

///|
test "Vector2: manhattanLength" {
  let x = 2.0
  let y = 3.0
  let a = @math.Vector2::new(x, 0.0)
  let b = @math.Vector2::new(0.0, -y)
  let c = @math.Vector2::new(0.0, 0.0)
  assert_eq(a.manhattan_length(), x)
  assert_eq(b.manhattan_length(), y)
  assert_eq(c.manhattan_length(), 0.0)
  a.set(x, y) |> ignore
  assert_eq(a.manhattan_length(), x.abs() + y.abs())
}

///|
test "Vector2: normalize" {
  let x = 2.0
  let y = 3.0
  let a = @math.Vector2::new(x, 0.0)
  let b = @math.Vector2::new(0.0, -y)
  a.normalize() |> ignore
  assert_true(a.length() == 1.0)
  assert_true(a.x == 1.0)
  b.normalize() |> ignore
  assert_true(b.length() == 1.0)
  assert_true(b.y == -1.0)
}

///|
test "Vector2: angleTo" {
  let a = @math.Vector2::new(-0.18851655680720186, 0.9820700116639124)
  let b = @math.Vector2::new(0.18851655680720186, -0.9820700116639124)
  assert_eq(a.angle_to(a), 0.0)
  assert_eq(a.angle_to(b), @cmath.PI)
  let x = @math.Vector2::new(1.0, 0.0)
  let y = @math.Vector2::new(0.0, 1.0)
  assert_eq(x.angle_to(y), @cmath.PI / 2.0)
  assert_eq(y.angle_to(x), @cmath.PI / 2.0)
  assert_true(
    (x.angle_to(@math.Vector2::new(1.0, 1.0)) - @cmath.PI / 4.0).abs() <
    0.0000001,
  )
}

///|
test "Vector2: setLength" {
  let x = 2.0
  let y = 3.0
  let mut a = @math.Vector2::new(x, 0.0)
  assert_true(a.length() == x)
  a.set_length(y) |> ignore
  assert_true(a.length() == y)
  a = @math.Vector2::new(0.0, 0.0)
  assert_true(a.length() == 0.0)
  a.set_length(y) |> ignore
  assert_true(a.length() == 0.0)
  // upstream calls setLength() with no argument, which multiplies by undefined
  a.set_length(0.0 / 0.0) |> ignore
  assert_true(a.length().is_nan())
}

///|
test "Vector2: equals" {
  let x = 2.0
  let y = 3.0
  let a = @math.Vector2::new(x, 0.0)
  let b = @math.Vector2::new(0.0, -y)
  assert_true(a.x != b.x)
  assert_true(a.y != b.y)
  assert_true(!a.equals(b))
  assert_true(!b.equals(a))
  a.copy(b) |> ignore
  assert_true(a.x == b.x)
  assert_true(a.y == b.y)
  assert_true(a.equals(b))
  assert_true(b.equals(a))
}

///|
test "Vector2: fromArray" {
  let a = @math.Vector2::new(0.0, 0.0)
  let array = [1.0, 2.0, 3.0, 4.0]
  a.from_array(array) |> ignore
  assert_eq(a.x, 1.0)
  assert_eq(a.y, 2.0)
  a.from_array(array, offset=2) |> ignore
  assert_eq(a.x, 3.0)
  assert_eq(a.y, 4.0)
}

///|
test "Vector2: toArray" {
  let x = 2.0
  let y = 3.0
  let a = @math.Vector2::new(x, y)
  let mut array = a.to_array()
  assert_eq(array[0], x)
  assert_eq(array[1], y)
  array = []
  a.to_array(array~) |> ignore
  assert_eq(array[0], x)
  assert_eq(array[1], y)
  array = []
  a.to_array(array~, offset=1) |> ignore
  assert_true(array[0].is_nan())
  assert_eq(array[1], x)
  assert_eq(array[2], y)
}

///|
test "Vector2: fromBufferAttribute" {
  let a = @math.Vector2::new(0.0, 0.0)
  let attr = VectorTestAttribute::new([1.0, 2.0, 3.0, 4.0], 2)
  a.from_buffer_attribute(attr, 0) |> ignore
  assert_eq(a.x, 1.0)
  assert_eq(a.y, 2.0)
  a.from_buffer_attribute(attr, 1) |> ignore
  assert_eq(a.x, 3.0)
  assert_eq(a.y, 4.0)
}

///|
test "Vector2: setX,setY" {
  let x = 2.0
  let y = 3.0
  let a = @math.Vector2::new(0.0, 0.0)
  assert_true(a.x == 0.0)
  assert_true(a.y == 0.0)
  a.set_x(x) |> ignore
  a.set_y(y) |> ignore
  assert_true(a.x == x)
  assert_true(a.y == y)
}

///|
test "Vector2: setComponent,getComponent" {
  let a = @math.Vector2::new(0.0, 0.0)
  assert_true(a.x == 0.0)
  assert_true(a.y == 0.0)
  a.set_component(0, 1.0) |> ignore
  a.set_component(1, 2.0) |> ignore
  assert_true(a.get_component(0) == 1.0)
  assert_true(a.get_component(1) == 2.0)
}

///|
test "Vector2: multiply/divide" {
  let x = 2.0
  let y = 3.0
  let a = @math.Vector2::new(x, y)
  let b = @math.Vector2::new(-x, -y)
  a.multiply_scalar(-2.0) |> ignore
  assert_true(a.x == x * -2.0)
  assert_true(a.y == y * -2.0)
  b.multiply_scalar(-2.0) |> ignore
  assert_true(b.x == 2.0 * x)
  assert_true(b.y == 2.0 * y)
  a.divide_scalar(-2.0) |> ignore
  assert_true(a.x == x)
  assert_true(a.y == y)
  b.divide_scalar(-2.0) |> ignore
  assert_true(b.x == -x)
  assert_true(b.y == -y)
}

///|
test "Vector2: min/max/clamp" {
  let x = 2.0
  let y = 3.0
  let a = @math.Vector2::new(x, y)
  let b = @math.Vector2::new(-x, -y)
  let c = @math.Vector2::new(0.0, 0.0)
  c.copy(a).min(b) |> ignore
  assert_true(c.x == -x)
  assert_true(c.y == -y)
  c.copy(a).max(b) |> ignore
  assert_true(c.x == x)
  assert_true(c.y == y)
  c.set(-2.0 * x, 2.0 * y) |> ignore
  c.clamp(b, a) |> ignore
  assert_true(c.x == -x)
  assert_true(c.y == y)
  c.set(-2.0 * x, 2.0 * x) |> ignore
  c.clamp_scalar(-x, x) |> ignore
  assert_eq(c.x, -x)
  assert_eq(c.y, x)
}

///|
test "Vector2: rounding" {
  assert_eq(
    @math.Vector2::new(-0.1, 0.1).floor(),
    @math.Vector2::new(-1.0, 0.0),
  )
  assert_eq(
    @math.Vector2::new(-0.5, 0.5).floor(),
    @math.Vector2::new(-1.0, 0.0),
  )
  assert_eq(
    @math.Vector2::new(-0.9, 0.9).floor(),
    @math.Vector2::new(-1.0, 0.0),
  )
  assert_eq(@math.Vector2::new(-0.1, 0.1).ceil(), @math.Vector2::new(0.0, 1.0))
  assert_eq(@math.Vector2::new(-0.5, 0.5).ceil(), @math.Vector2::new(0.0, 1.0))
  assert_eq(@math.Vector2::new(-0.9, 0.9).ceil(), @math.Vector2::new(0.0, 1.0))
  assert_eq(@math.Vector2::new(-0.1, 0.1).round(), @math.Vector2::new(0.0, 0.0))
  assert_eq(@math.Vector2::new(-0.5, 0.5).round(), @math.Vector2::new(0.0, 1.0))
  assert_eq(
    @math.Vector2::new(-0.9, 0.9).round(),
    @math.Vector2::new(-1.0, 1.0),
  )
  assert_eq(
    @math.Vector2::new(-0.1, 0.1).round_to_zero(),
    @math.Vector2::new(0.0, 0.0),
  )
  assert_eq(
    @math.Vector2::new(-0.5, 0.5).round_to_zero(),
    @math.Vector2::new(0.0, 0.0),
  )
  assert_eq(
    @math.Vector2::new(-0.9, 0.9).round_to_zero(),
    @math.Vector2::new(0.0, 0.0),
  )
  assert_eq(
    @math.Vector2::new(-1.1, 1.1).round_to_zero(),
    @math.Vector2::new(-1.0, 1.0),
  )
  assert_eq(
    @math.Vector2::new(-1.5, 1.5).round_to_zero(),
    @math.Vector2::new(-1.0, 1.0),
  )
  assert_eq(
    @math.Vector2::new(-1.9, 1.9).round_to_zero(),
    @math.Vector2::new(-1.0, 1.0),
  )
}

///|
test "Vector2: length/lengthSq" {
  let x = 2.0
  let y = 3.0
  let a = @math.Vector2::new(x, 0.0)
  let b = @math.Vector2::new(0.0, -y)
  let c = @math.Vector2::new(0.0, 0.0)
  assert_true(a.length() == x)
  assert_true(a.length_sq() == x * x)
  assert_true(b.length() == y)
  assert_true(b.length_sq() == y * y)
  assert_true(c.length() == 0.0)
  assert_true(c.length_sq() == 0.0)
  a.set(x, y) |> ignore
  assert_true(a.length() == (x * x + y * y).sqrt())
  assert_true(a.length_sq() == x * x + y * y)
}

///|
test "Vector2: distanceTo/distanceToSquared" {
  let x = 2.0
  let y = 3.0
  let a = @math.Vector2::new(x, 0.0)
  let b = @math.Vector2::new(0.0, -y)
  let c = @math.Vector2::new(0.0, 0.0)
  assert_true(a.distance_to(c) == x)
  assert_true(a.distance_to_squared(c) == x * x)
  assert_true(b.distance_to(c) == y)
  assert_true(b.distance_to_squared(c) == y * y)
}

///|
test "Vector2: lerp/clone" {
  let x = 2.0
  let y = 3.0
  let a = @math.Vector2::new(x, 0.0)
  let b = @math.Vector2::new(0.0, -y)
  assert_true(a.lerp(a, 0.0).equals(a.lerp(a, 0.5)))
  assert_true(a.lerp(a, 0.0).equals(a.lerp(a, 1.0)))
  assert_true(a.clone().lerp(b, 0.0).equals(a))
  assert_true(a.clone().lerp(b, 0.5).x == x * 0.5)
  assert_true(a.clone().lerp(b, 0.5).y == -y * 0.5)
  assert_true(a.clone().lerp(b, 1.0).equals(b))
}

///|
test "Vector2: setScalar/addScalar/subScalar" {
  let a = @math.Vector2::new(1.0, 1.0)
  let s = 3.0
  a.set_scalar(s) |> ignore
  assert_eq(a.x, s)
  assert_eq(a.y, s)
  a.add_scalar(s) |> ignore
  assert_eq(a.x, 2.0 * s)
  assert_eq(a.y, 2.0 * s)
  a.sub_scalar(2.0 * s) |> ignore
  assert_eq(a.x, 0.0)
  assert_eq(a.y, 0.0)
}

///|
test "Vector2: multiply/divide (2)" {
  let x = 2.0
  let y = 3.0
  let a = @math.Vector2::new(x, y)
  let b = @math.Vector2::new(2.0 * x, 2.0 * y)
  let c = @math.Vector2::new(4.0 * x, 4.0 * y)
  a.multiply(b) |> ignore
  assert_eq(a.x, x * b.x)
  assert_eq(a.y, y * b.y)
  b.divide(c) |> ignore
  assert_eq(b.x, 0.5)
  assert_eq(b.y, 0.5)
}

///|
test "panic Vector2: set_component out of range" {
  @math.Vector2::new(0.0, 0.0).set_component(2, 0.0) |> ignore
}

///|
test "panic Vector2: get_component out of range" {
  @math.Vector2::new(0.0, 0.0).get_component(2) |> ignore
}

// The rest have no upstream test: they pin JS semantics and ported overloads.

///|
test "Vector2: min and max follow Math.min and Math.max on NaN" {
  let nan = 0.0 / 0.0
  let a = @math.Vector2::new(1.0, nan)
  let b = @math.Vector2::new(nan, 1.0)
  let min = a.clone().min(b)
  assert_true(min.x.is_nan())
  assert_true(min.y.is_nan())
  let max = a.clone().max(b)
  assert_true(max.x.is_nan())
  assert_true(max.y.is_nan())
}

///|
test "Vector2: normalize divides by 1 when the length is NaN" {
  // upstream's `length || 1` treats NaN as falsy
  let a = @math.Vector2::new(0.0 / 0.0, 1.0).normalize()
  assert_true(a.x.is_nan())
  assert_eq(a.y, 1.0)
}

///|
test "Vector2: to_array grows into an existing array" {
  let array = [9.0, 9.0, 9.0]
  @math.Vector2::new(1.0, 2.0).to_array(array~, offset=2) |> ignore
  assert_eq(array, [9.0, 9.0, 1.0, 2.0])
}

///|
test "Vector2: random stays in [0, 1)" {
  let a = @math.Vector2::new(2.0, 2.0).random()
  assert_true(a.x >= 0.0 && a.x < 1.0)
  assert_true(a.y >= 0.0 && a.y < 1.0)
}
