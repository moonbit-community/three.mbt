///|
/// The matrices `PerspectiveCamera( 75, 16 / 9, 0.1, 300.0 )` holds at rest.
struct VectorTestCamera {
  world : @math.Matrix4
  world_inverse : @math.Matrix4
  projection : @math.Matrix4
  projection_inverse : @math.Matrix4
}

///|
fn VectorTestCamera::perspective(
  fov : Double,
  aspect : Double,
  near : Double,
  far : Double,
) -> VectorTestCamera {
  let top = near * @cmath.tan(@cmath.PI / 180.0 * 0.5 * fov)
  let height = 2.0 * top
  let width = aspect * height
  let left = -0.5 * width
  let projection = @math.Matrix4::new().make_perspective(
    left,
    left + width,
    top,
    top - height,
    near,
    far,
  )
  {
    world: @math.Matrix4::new(),
    world_inverse: @math.Matrix4::new(),
    projection,
    projection_inverse: projection.clone().invert(),
  }
}

///|
impl @math.CameraMatrices for VectorTestCamera with fn matrix_world(self) {
  self.world
}

///|
impl @math.CameraMatrices for VectorTestCamera with fn matrix_world_inverse(
  self,
) {
  self.world_inverse
}

///|
impl @math.CameraMatrices for VectorTestCamera with fn projection_matrix(self) {
  self.projection
}

///|
impl @math.CameraMatrices for VectorTestCamera with fn projection_matrix_inverse(
  self,
) {
  self.projection_inverse
}

///|
test "Vector3: Instancing" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let mut a = @math.Vector3::new(0.0, 0.0, 0.0)
  assert_true(a.x == 0.0)
  assert_true(a.y == 0.0)
  assert_true(a.z == 0.0)
  a = @math.Vector3::new(x, y, z)
  assert_true(a.x == x)
  assert_true(a.y == y)
  assert_true(a.z == z)
}

///|
test "Vector3: set" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(0.0, 0.0, 0.0)
  assert_true(a.x == 0.0)
  assert_true(a.y == 0.0)
  assert_true(a.z == 0.0)
  a.set(x, y, z) |> ignore
  assert_true(a.x == x)
  assert_true(a.y == y)
  assert_true(a.z == z)
}

///|
test "Vector3: copy" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(x, y, z)
  let b = @math.Vector3::new(0.0, 0.0, 0.0).copy(a)
  assert_true(b.x == x)
  assert_true(b.y == y)
  assert_true(b.z == z)
  a.x = 0.0
  a.y = -1.0
  a.z = -2.0
  assert_true(b.x == x)
  assert_true(b.y == y)
  assert_true(b.z == z)
}

///|
test "Vector3: add" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(x, y, z)
  let b = @math.Vector3::new(-x, -y, -z)
  a.add(b) |> ignore
  assert_true(a.x == 0.0)
  assert_true(a.y == 0.0)
  assert_true(a.z == 0.0)
  let c = @math.Vector3::new(0.0, 0.0, 0.0).add_vectors(b, b)
  assert_true(c.x == -2.0 * x)
  assert_true(c.y == -2.0 * y)
  assert_true(c.z == -2.0 * z)
}

///|
test "Vector3: addScaledVector" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(x, y, z)
  let b = @math.Vector3::new(2.0, 3.0, 4.0)
  let s = 3.0
  a.add_scaled_vector(b, s) |> ignore
  assert_eq(a.x, x + b.x * s)
  assert_eq(a.y, y + b.y * s)
  assert_eq(a.z, z + b.z * s)
}

///|
test "Vector3: sub" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(x, y, z)
  let b = @math.Vector3::new(-x, -y, -z)
  a.sub(b) |> ignore
  assert_true(a.x == 2.0 * x)
  assert_true(a.y == 2.0 * y)
  assert_true(a.z == 2.0 * z)
  let c = @math.Vector3::new(0.0, 0.0, 0.0).sub_vectors(a, a)
  assert_true(c.x == 0.0)
  assert_true(c.y == 0.0)
  assert_true(c.z == 0.0)
}

///|
test "Vector3: multiplyVectors" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(x, y, z)
  let b = @math.Vector3::new(2.0, 3.0, -5.0)
  let c = @math.Vector3::new(0.0, 0.0, 0.0).multiply_vectors(a, b)
  assert_eq(c.x, x * 2.0)
  assert_eq(c.y, y * 3.0)
  assert_eq(c.z, z * -5.0)
}

///|
test "Vector3: applyEuler" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let eps = 0.0001
  let a = @math.Vector3::new(x, y, z)
  let euler = @math.Euler::new(90.0, -45.0, 0.0)
  let expected = @math.Vector3::new(
    -2.352970120501014, -4.7441750936226645, 0.9779234597246458,
  )
  a.apply_euler(euler) |> ignore
  assert_true((a.x - expected.x).abs() <= eps)
  assert_true((a.y - expected.y).abs() <= eps)
  assert_true((a.z - expected.z).abs() <= eps)
}

///|
test "Vector3: applyAxisAngle" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let eps = 0.0001
  let a = @math.Vector3::new(x, y, z)
  let axis = @math.Vector3::new(0.0, 1.0, 0.0)
  let angle = @cmath.PI / 4.0
  let expected = @math.Vector3::new(3.0 * 2.0.sqrt(), 3.0, 2.0.sqrt())
  a.apply_axis_angle(axis, angle) |> ignore
  assert_true((a.x - expected.x).abs() <= eps)
  assert_true((a.y - expected.y).abs() <= eps)
  assert_true((a.z - expected.z).abs() <= eps)
}

///|
test "Vector3: applyMatrix3" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(x, y, z)
  let m = @math.Matrix3::new().set(
    2.0, 3.0, 5.0, 7.0, 11.0, 13.0, 17.0, 19.0, 23.0,
  )
  a.apply_matrix3(m) |> ignore
  assert_eq(a.x, 33.0)
  assert_eq(a.y, 99.0)
  assert_eq(a.z, 183.0)
}

///|
test "Vector3: applyMatrix4" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(x, y, z)
  let b = @math.Vector4::new(x, y, z, 1.0)
  let mut m = @math.Matrix4::new().make_rotation_x(@cmath.PI)
  a.apply_matrix4(m) |> ignore
  b.apply_matrix4(m) |> ignore
  assert_true(a.x == b.x / b.w)
  assert_true(a.y == b.y / b.w)
  assert_true(a.z == b.z / b.w)
  m = @math.Matrix4::new().make_translation(3.0, 2.0, 1.0)
  a.apply_matrix4(m) |> ignore
  b.apply_matrix4(m) |> ignore
  assert_true(a.x == b.x / b.w)
  assert_true(a.y == b.y / b.w)
  assert_true(a.z == b.z / b.w)
  m = @math.Matrix4::new().set(
    1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0,
  )
  a.apply_matrix4(m) |> ignore
  b.apply_matrix4(m) |> ignore
  assert_true(a.x == b.x / b.w)
  assert_true(a.y == b.y / b.w)
  assert_true(a.z == b.z / b.w)
}

///|
test "Vector3: applyQuaternion" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(x, y, z)
  a.apply_quaternion(@math.Quaternion::new(0.0, 0.0, 0.0, 1.0)) |> ignore
  assert_eq(a.x, x)
  assert_eq(a.y, y)
  assert_eq(a.z, z)
}

///|
test "Vector3: transformDirection" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let eps = 0.0001
  let a = @math.Vector3::new(x, y, z)
  let m = @math.Matrix4::new()
  let transformed = @math.Vector3::new(
    0.3713906763541037, 0.5570860145311556, 0.7427813527082074,
  )
  a.transform_direction(m) |> ignore
  assert_true((a.x - transformed.x).abs() <= eps)
  assert_true((a.y - transformed.y).abs() <= eps)
  assert_true((a.z - transformed.z).abs() <= eps)
}

///|
test "Vector3: clampScalar" {
  let a = @math.Vector3::new(-0.01, 0.5, 1.5)
  let clamped = @math.Vector3::new(0.1, 0.5, 1.0)
  a.clamp_scalar(0.1, 1.0) |> ignore
  assert_true((a.x - clamped.x).abs() <= 0.001)
  assert_true((a.y - clamped.y).abs() <= 0.001)
  assert_true((a.z - clamped.z).abs() <= 0.001)
}

///|
test "Vector3: negate" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(x, y, z)
  a.negate() |> ignore
  assert_true(a.x == -x)
  assert_true(a.y == -y)
  assert_true(a.z == -z)
}

///|
test "Vector3: dot" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(x, y, z)
  let b = @math.Vector3::new(-x, -y, -z)
  let c = @math.Vector3::new(0.0, 0.0, 0.0)
  let mut result = a.dot(b)
  assert_true(result == -x * x - y * y - z * z)
  result = a.dot(c)
  assert_true(result == 0.0)
}

///|
test "Vector3: manhattanLength" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(x, 0.0, 0.0)
  let b = @math.Vector3::new(0.0, -y, 0.0)
  let c = @math.Vector3::new(0.0, 0.0, z)
  let d = @math.Vector3::new(0.0, 0.0, 0.0)
  assert_true(a.manhattan_length() == x)
  assert_true(b.manhattan_length() == y)
  assert_true(c.manhattan_length() == z)
  assert_true(d.manhattan_length() == 0.0)
  a.set(x, y, z) |> ignore
  assert_true(a.manhattan_length() == x.abs() + y.abs() + z.abs())
}

///|
test "Vector3: normalize" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(x, 0.0, 0.0)
  let b = @math.Vector3::new(0.0, -y, 0.0)
  let c = @math.Vector3::new(0.0, 0.0, z)
  a.normalize() |> ignore
  assert_true(a.length() == 1.0)
  assert_true(a.x == 1.0)
  b.normalize() |> ignore
  assert_true(b.length() == 1.0)
  assert_true(b.y == -1.0)
  c.normalize() |> ignore
  assert_true(c.length() == 1.0)
  assert_true(c.z == 1.0)
}

///|
test "Vector3: setLength" {
  let x = 2.0
  let y = 3.0
  let mut a = @math.Vector3::new(x, 0.0, 0.0)
  assert_true(a.length() == x)
  a.set_length(y) |> ignore
  assert_true(a.length() == y)
  a = @math.Vector3::new(0.0, 0.0, 0.0)
  assert_true(a.length() == 0.0)
  a.set_length(y) |> ignore
  assert_true(a.length() == 0.0)
  // upstream calls setLength() with no argument, which multiplies by undefined
  a.set_length(0.0 / 0.0) |> ignore
  assert_true(a.length().is_nan())
}

///|
test "Vector3: cross" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let eps = 0.0001
  let a = @math.Vector3::new(x, y, z)
  let b = @math.Vector3::new(2.0 * x, -y, 0.5 * z)
  let crossed = @math.Vector3::new(18.0, 12.0, -18.0)
  a.cross(b) |> ignore
  assert_true((a.x - crossed.x).abs() <= eps)
  assert_true((a.y - crossed.y).abs() <= eps)
  assert_true((a.z - crossed.z).abs() <= eps)
}

///|
test "Vector3: crossVectors" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let eps = 0.0001
  let a = @math.Vector3::new(x, y, z)
  let b = @math.Vector3::new(x, -y, z)
  let c = @math.Vector3::new(0.0, 0.0, 0.0)
  let crossed = @math.Vector3::new(24.0, 0.0, -12.0)
  c.cross_vectors(a, b) |> ignore
  assert_true((c.x - crossed.x).abs() <= eps)
  assert_true((c.y - crossed.y).abs() <= eps)
  assert_true((c.z - crossed.z).abs() <= eps)
}

///|
test "Vector3: projectOnVector" {
  let a = @math.Vector3::new(1.0, 0.0, 0.0)
  let b = @math.Vector3::new(0.0, 0.0, 0.0)
  let normal = @math.Vector3::new(10.0, 0.0, 0.0)
  assert_true(
    b
    .copy(a)
    .project_on_vector(normal)
    .equals(@math.Vector3::new(1.0, 0.0, 0.0)),
  )
  a.set(0.0, 1.0, 0.0) |> ignore
  assert_true(
    b
    .copy(a)
    .project_on_vector(normal)
    .equals(@math.Vector3::new(0.0, 0.0, 0.0)),
  )
  a.set(0.0, 0.0, -1.0) |> ignore
  assert_true(
    b
    .copy(a)
    .project_on_vector(normal)
    .equals(@math.Vector3::new(0.0, 0.0, 0.0)),
  )
  a.set(-1.0, 0.0, 0.0) |> ignore
  assert_true(
    b
    .copy(a)
    .project_on_vector(normal)
    .equals(@math.Vector3::new(-1.0, 0.0, 0.0)),
  )
}

///|
test "Vector3: projectOnPlane" {
  let a = @math.Vector3::new(1.0, 0.0, 0.0)
  let b = @math.Vector3::new(0.0, 0.0, 0.0)
  let normal = @math.Vector3::new(1.0, 0.0, 0.0)
  assert_true(
    b.copy(a).project_on_plane(normal).equals(@math.Vector3::new(0.0, 0.0, 0.0)),
  )
  a.set(0.0, 1.0, 0.0) |> ignore
  assert_true(
    b.copy(a).project_on_plane(normal).equals(@math.Vector3::new(0.0, 1.0, 0.0)),
  )
  a.set(0.0, 0.0, -1.0) |> ignore
  assert_true(
    b
    .copy(a)
    .project_on_plane(normal)
    .equals(@math.Vector3::new(0.0, 0.0, -1.0)),
  )
  a.set(-1.0, 0.0, 0.0) |> ignore
  assert_true(
    b.copy(a).project_on_plane(normal).equals(@math.Vector3::new(0.0, 0.0, 0.0)),
  )
}

///|
test "Vector3: reflect" {
  let a = @math.Vector3::new(0.0, 0.0, 0.0)
  let normal = @math.Vector3::new(0.0, 1.0, 0.0)
  let b = @math.Vector3::new(0.0, 0.0, 0.0)
  a.set(0.0, -1.0, 0.0) |> ignore
  assert_true(
    b.copy(a).reflect(normal).equals(@math.Vector3::new(0.0, 1.0, 0.0)),
  )
  a.set(1.0, -1.0, 0.0) |> ignore
  assert_true(
    b.copy(a).reflect(normal).equals(@math.Vector3::new(1.0, 1.0, 0.0)),
  )
  a.set(1.0, -1.0, 0.0) |> ignore
  normal.set(0.0, -1.0, 0.0) |> ignore
  assert_true(
    b.copy(a).reflect(normal).equals(@math.Vector3::new(1.0, 1.0, 0.0)),
  )
}

///|
test "Vector3: angleTo" {
  let a = @math.Vector3::new(0.0, -0.18851655680720186, 0.9820700116639124)
  let b = @math.Vector3::new(0.0, 0.18851655680720186, -0.9820700116639124)
  assert_eq(a.angle_to(a), 0.0)
  assert_eq(a.angle_to(b), @cmath.PI)
  let x = @math.Vector3::new(1.0, 0.0, 0.0)
  let y = @math.Vector3::new(0.0, 1.0, 0.0)
  let z = @math.Vector3::new(0.0, 0.0, 1.0)
  assert_eq(x.angle_to(y), @cmath.PI / 2.0)
  assert_eq(x.angle_to(z), @cmath.PI / 2.0)
  assert_eq(z.angle_to(x), @cmath.PI / 2.0)
  assert_true(
    (x.angle_to(@math.Vector3::new(1.0, 1.0, 0.0)) - @cmath.PI / 4.0).abs() <
    0.0000001,
  )
}

///|
test "Vector3: setFromSpherical" {
  let eps = 0.0001
  let a = @math.Vector3::new(0.0, 0.0, 0.0)
  let phi = @cmath.acos(-0.5)
  let theta = @cmath.PI.sqrt() * phi
  let sph = @math.Spherical::new(10.0, phi, theta)
  let expected = @math.Vector3::new(
    -4.677914006701843, -5.0, -7.288149322420796,
  )
  a.set_from_spherical(sph) |> ignore
  assert_true((a.x - expected.x).abs() <= eps)
  assert_true((a.y - expected.y).abs() <= eps)
  assert_true((a.z - expected.z).abs() <= eps)
}

///|
test "Vector3: setFromCylindrical" {
  let eps = 0.0001
  let a = @math.Vector3::new(0.0, 0.0, 0.0)
  let cyl = @math.Cylindrical::new(10.0, @cmath.PI * 0.125, 20.0)
  let expected = @math.Vector3::new(3.826834323650898, 20.0, 9.238795325112868)
  a.set_from_cylindrical(cyl) |> ignore
  assert_true((a.x - expected.x).abs() <= eps)
  assert_true((a.y - expected.y).abs() <= eps)
  assert_true((a.z - expected.z).abs() <= eps)
}

///|
test "Vector3: setFromMatrixPosition" {
  let a = @math.Vector3::new(0.0, 0.0, 0.0)
  let m = @math.Matrix4::new().set(
    2.0, 3.0, 5.0, 7.0, 11.0, 13.0, 17.0, 19.0, 23.0, 29.0, 31.0, 37.0, 41.0, 43.0,
    47.0, 53.0,
  )
  a.set_from_matrix_position(m) |> ignore
  assert_eq(a.x, 7.0)
  assert_eq(a.y, 19.0)
  assert_eq(a.z, 37.0)
}

///|
test "Vector3: setFromMatrixScale" {
  let eps = 0.0001
  let a = @math.Vector3::new(0.0, 0.0, 0.0)
  let m = @math.Matrix4::new().set(
    2.0, 3.0, 5.0, 7.0, 11.0, 13.0, 17.0, 19.0, 23.0, 29.0, 31.0, 37.0, 41.0, 43.0,
    47.0, 53.0,
  )
  let expected = @math.Vector3::new(
    25.573423705088842, 31.921779399024736, 35.70714214271425,
  )
  a.set_from_matrix_scale(m) |> ignore
  assert_true((a.x - expected.x).abs() <= eps)
  assert_true((a.y - expected.y).abs() <= eps)
  assert_true((a.z - expected.z).abs() <= eps)
}

///|
test "Vector3: setFromMatrixColumn" {
  let a = @math.Vector3::new(0.0, 0.0, 0.0)
  let m = @math.Matrix4::new().set(
    2.0, 3.0, 5.0, 7.0, 11.0, 13.0, 17.0, 19.0, 23.0, 29.0, 31.0, 37.0, 41.0, 43.0,
    47.0, 53.0,
  )
  a.set_from_matrix_column(m, 0) |> ignore
  assert_eq(a.x, 2.0)
  assert_eq(a.y, 11.0)
  assert_eq(a.z, 23.0)
  a.set_from_matrix_column(m, 2) |> ignore
  assert_eq(a.x, 5.0)
  assert_eq(a.y, 17.0)
  assert_eq(a.z, 31.0)
}

///|
test "Vector3: equals" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(x, 0.0, z)
  let b = @math.Vector3::new(0.0, -y, 0.0)
  assert_true(a.x != b.x)
  assert_true(a.y != b.y)
  assert_true(a.z != b.z)
  assert_true(!a.equals(b))
  assert_true(!b.equals(a))
  a.copy(b) |> ignore
  assert_true(a.x == b.x)
  assert_true(a.y == b.y)
  assert_true(a.z == b.z)
  assert_true(a.equals(b))
  assert_true(b.equals(a))
}

///|
test "Vector3: fromArray" {
  let a = @math.Vector3::new(0.0, 0.0, 0.0)
  let array = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
  a.from_array(array) |> ignore
  assert_eq(a.x, 1.0)
  assert_eq(a.y, 2.0)
  assert_eq(a.z, 3.0)
  a.from_array(array, offset=3) |> ignore
  assert_eq(a.x, 4.0)
  assert_eq(a.y, 5.0)
  assert_eq(a.z, 6.0)
}

///|
test "Vector3: toArray" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(x, y, z)
  let mut array = a.to_array()
  assert_eq(array[0], x)
  assert_eq(array[1], y)
  assert_eq(array[2], z)
  array = []
  a.to_array(array~) |> ignore
  assert_eq(array[0], x)
  assert_eq(array[1], y)
  assert_eq(array[2], z)
  array = []
  a.to_array(array~, offset=1) |> ignore
  assert_true(array[0].is_nan())
  assert_eq(array[1], x)
  assert_eq(array[2], y)
  assert_eq(array[3], z)
}

///|
test "Vector3: fromBufferAttribute" {
  let a = @math.Vector3::new(0.0, 0.0, 0.0)
  let attr = VectorTestAttribute::new([1.0, 2.0, 3.0, 4.0, 5.0, 6.0], 3)
  a.from_buffer_attribute(attr, 0) |> ignore
  assert_eq(a.x, 1.0)
  assert_eq(a.y, 2.0)
  assert_eq(a.z, 3.0)
  a.from_buffer_attribute(attr, 1) |> ignore
  assert_eq(a.x, 4.0)
  assert_eq(a.y, 5.0)
  assert_eq(a.z, 6.0)
}

///|
test "Vector3: randomDirection" {
  let vec = @math.Vector3::new(0.0, 0.0, 0.0)
  vec.random_direction() |> ignore
  let zero = @math.Vector3::new(0.0, 0.0, 0.0)
  assert_true(vec != zero)
  assert_true(1.0 - vec.length() <= 2.220446049250313e-16)
}

///|
test "Vector3: setX,setY,setZ" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(0.0, 0.0, 0.0)
  assert_true(a.x == 0.0)
  assert_true(a.y == 0.0)
  assert_true(a.z == 0.0)
  a.set_x(x) |> ignore
  a.set_y(y) |> ignore
  a.set_z(z) |> ignore
  assert_true(a.x == x)
  assert_true(a.y == y)
  assert_true(a.z == z)
}

///|
test "Vector3: setComponent,getComponent" {
  let a = @math.Vector3::new(0.0, 0.0, 0.0)
  assert_true(a.x == 0.0)
  assert_true(a.y == 0.0)
  assert_true(a.z == 0.0)
  a.set_component(0, 1.0) |> ignore
  a.set_component(1, 2.0) |> ignore
  a.set_component(2, 3.0) |> ignore
  assert_true(a.get_component(0) == 1.0)
  assert_true(a.get_component(1) == 2.0)
  assert_true(a.get_component(2) == 3.0)
}

///|
test "Vector3: min/max/clamp" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(x, y, z)
  let b = @math.Vector3::new(-x, -y, -z)
  let c = @math.Vector3::new(0.0, 0.0, 0.0)
  c.copy(a).min(b) |> ignore
  assert_true(c.x == -x)
  assert_true(c.y == -y)
  assert_true(c.z == -z)
  c.copy(a).max(b) |> ignore
  assert_true(c.x == x)
  assert_true(c.y == y)
  assert_true(c.z == z)
  c.set(-2.0 * x, 2.0 * y, -2.0 * z) |> ignore
  c.clamp(b, a) |> ignore
  assert_true(c.x == -x)
  assert_true(c.y == y)
  assert_true(c.z == -z)
}

///|
test "Vector3: distanceTo/distanceToSquared" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(x, 0.0, 0.0)
  let b = @math.Vector3::new(0.0, -y, 0.0)
  let c = @math.Vector3::new(0.0, 0.0, z)
  let d = @math.Vector3::new(0.0, 0.0, 0.0)
  assert_true(a.distance_to(d) == x)
  assert_true(a.distance_to_squared(d) == x * x)
  assert_true(b.distance_to(d) == y)
  assert_true(b.distance_to_squared(d) == y * y)
  assert_true(c.distance_to(d) == z)
  assert_true(c.distance_to_squared(d) == z * z)
}

///|
test "Vector3: setScalar/addScalar/subScalar" {
  let a = @math.Vector3::new(0.0, 0.0, 0.0)
  let s = 3.0
  a.set_scalar(s) |> ignore
  assert_eq(a.x, s)
  assert_eq(a.y, s)
  assert_eq(a.z, s)
  a.add_scalar(s) |> ignore
  assert_eq(a.x, 2.0 * s)
  assert_eq(a.y, 2.0 * s)
  assert_eq(a.z, 2.0 * s)
  a.sub_scalar(2.0 * s) |> ignore
  assert_eq(a.x, 0.0)
  assert_eq(a.y, 0.0)
  assert_eq(a.z, 0.0)
}

///|
test "Vector3: multiply/divide" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let eps = 0.0001
  let a = @math.Vector3::new(x, y, z)
  let b = @math.Vector3::new(2.0 * x, 2.0 * y, 2.0 * z)
  let c = @math.Vector3::new(4.0 * x, 4.0 * y, 4.0 * z)
  a.multiply(b) |> ignore
  assert_eq(a.x, x * b.x)
  assert_eq(a.y, y * b.y)
  assert_eq(a.z, z * b.z)
  b.divide(c) |> ignore
  assert_true((b.x - 0.5).abs() <= eps)
  assert_true((b.y - 0.5).abs() <= eps)
  assert_true((b.z - 0.5).abs() <= eps)
}

///|
test "Vector3: multiply/divide (2)" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(x, y, z)
  let b = @math.Vector3::new(-x, -y, -z)
  a.multiply_scalar(-2.0) |> ignore
  assert_true(a.x == x * -2.0)
  assert_true(a.y == y * -2.0)
  assert_true(a.z == z * -2.0)
  b.multiply_scalar(-2.0) |> ignore
  assert_true(b.x == 2.0 * x)
  assert_true(b.y == 2.0 * y)
  assert_true(b.z == 2.0 * z)
  a.divide_scalar(-2.0) |> ignore
  assert_true(a.x == x)
  assert_true(a.y == y)
  assert_true(a.z == z)
  b.divide_scalar(-2.0) |> ignore
  assert_true(b.x == -x)
  assert_true(b.y == -y)
  assert_true(b.z == -z)
}

///|
test "Vector3: project/unproject" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let eps = 0.0001
  let a = @math.Vector3::new(x, y, z)
  let camera = VectorTestCamera::perspective(75.0, 16.0 / 9.0, 0.1, 300.0)
  let projected = @math.Vector3::new(
    -0.36653213611158914, -0.9774190296309043, 1.0506835611870624,
  )
  a.project(camera) |> ignore
  assert_true((a.x - projected.x).abs() <= eps)
  assert_true((a.y - projected.y).abs() <= eps)
  assert_true((a.z - projected.z).abs() <= eps)
  a.unproject(camera) |> ignore
  assert_true((a.x - x).abs() <= eps)
  assert_true((a.y - y).abs() <= eps)
  assert_true((a.z - z).abs() <= eps)
}

///|
test "Vector3: length/lengthSq" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(x, 0.0, 0.0)
  let b = @math.Vector3::new(0.0, -y, 0.0)
  let c = @math.Vector3::new(0.0, 0.0, z)
  let d = @math.Vector3::new(0.0, 0.0, 0.0)
  assert_true(a.length() == x)
  assert_true(a.length_sq() == x * x)
  assert_true(b.length() == y)
  assert_true(b.length_sq() == y * y)
  assert_true(c.length() == z)
  assert_true(c.length_sq() == z * z)
  assert_true(d.length() == 0.0)
  assert_true(d.length_sq() == 0.0)
  a.set(x, y, z) |> ignore
  assert_true(a.length() == (x * x + y * y + z * z).sqrt())
  assert_true(a.length_sq() == x * x + y * y + z * z)
}

///|
test "Vector3: lerp/clone" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let a = @math.Vector3::new(x, 0.0, z)
  let b = @math.Vector3::new(0.0, -y, 0.0)
  assert_true(a.lerp(a, 0.0).equals(a.lerp(a, 0.5)))
  assert_true(a.lerp(a, 0.0).equals(a.lerp(a, 1.0)))
  assert_true(a.clone().lerp(b, 0.0).equals(a))
  assert_true(a.clone().lerp(b, 0.5).x == x * 0.5)
  assert_true(a.clone().lerp(b, 0.5).y == -y * 0.5)
  assert_true(a.clone().lerp(b, 0.5).z == z * 0.5)
  assert_true(a.clone().lerp(b, 1.0).equals(b))
}

///|
test "panic Vector3: set_component out of range" {
  @math.Vector3::new(0.0, 0.0, 0.0).set_component(3, 0.0) |> ignore
}

///|
test "panic Vector3: get_component out of range" {
  @math.Vector3::new(0.0, 0.0, 0.0).get_component(3) |> ignore
}

// The rest have no upstream test: they exercise ported overloads and members.

///|
test "Vector3: set_xy leaves z alone" {
  let a = @math.Vector3::new(1.0, 2.0, 3.0).set_xy(4.0, 5.0)
  assert_eq(a.x, 4.0)
  assert_eq(a.y, 5.0)
  assert_eq(a.z, 3.0)
}

///|
test "Vector3: add_scaled_vector4 ignores w" {
  let a = @math.Vector3::new(1.0, 2.0, 3.0)
  a.add_scaled_vector4(@math.Vector4::new(1.0, 1.0, 1.0, 100.0), 2.0) |> ignore
  assert_eq(a.x, 3.0)
  assert_eq(a.y, 4.0)
  assert_eq(a.z, 5.0)
}

///|
test "Vector3: set_from_euler and set_from_color" {
  let a = @math.Vector3::new(0.0, 0.0, 0.0)
  a.set_from_euler(@math.Euler::new(1.0, 2.0, 3.0)) |> ignore
  assert_eq(a.x, 1.0)
  assert_eq(a.y, 2.0)
  assert_eq(a.z, 3.0)
  a.set_from_color(@math.Color::new(0.25, 0.5, 0.75)) |> ignore
  assert_eq(a.x, 0.25)
  assert_eq(a.y, 0.5)
  assert_eq(a.z, 0.75)
}

///|
test "Vector3: extract_basis through set_from_matrix3_column" {
  let m = @math.Matrix3::new().set(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0)
  let x = @math.Vector3::new(0.0, 0.0, 0.0)
  let y = @math.Vector3::new(0.0, 0.0, 0.0)
  let z = @math.Vector3::new(0.0, 0.0, 0.0)
  m.extract_basis(x, y, z) |> ignore
  assert_true(x.equals(@math.Vector3::new(1.0, 4.0, 7.0)))
  assert_true(y.equals(@math.Vector3::new(2.0, 5.0, 8.0)))
  assert_true(z.equals(@math.Vector3::new(3.0, 6.0, 9.0)))
}
