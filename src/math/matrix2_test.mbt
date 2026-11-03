// Upstream has no Matrix2.tests.js; these exercise each member once.

///|
test "Matrix2: new" {
  assert_eq(@math.Matrix2::new().elements, [1.0, 0.0, 0.0, 1.0])
  let a = @math.Matrix2::new(n11=11.0, n12=12.0, n21=21.0, n22=22.0)
  assert_eq(a.elements, [11.0, 21.0, 12.0, 22.0])
}

///|
test "Matrix2: set is row-major" {
  let a = @math.Matrix2::new().set(11.0, 12.0, 21.0, 22.0)
  assert_eq(a.elements, [11.0, 21.0, 12.0, 22.0])
}

///|
test "Matrix2: identity" {
  let a = @math.Matrix2::new().set(11.0, 12.0, 21.0, 22.0).identity()
  assert_eq(a.elements, [1.0, 0.0, 0.0, 1.0])
}

///|
test "Matrix2: from_array" {
  let array = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]
  let a = @math.Matrix2::new().from_array(array)
  assert_eq(a.elements, [0.0, 1.0, 2.0, 3.0])
  a.from_array(array, offset=2) |> ignore
  assert_eq(a.elements, [2.0, 3.0, 4.0, 5.0])
}
