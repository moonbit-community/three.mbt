// Port of upstream test/unit/src/extras/core/Shape.tests.js, plus what it leaves as todo.

///|
fn square_shape() -> @extras.Shape {
  @extras.Shape::new(points=[
    vec2(0.0, 0.0),
    vec2(4.0, 0.0),
    vec2(4.0, 4.0),
    vec2(0.0, 4.0),
  ])
}

///|
fn square_hole() -> @extras.Path {
  @extras.Path::new(points=[
    vec2(1.0, 1.0),
    vec2(1.0, 2.0),
    vec2(2.0, 2.0),
    vec2(2.0, 1.0),
  ])
}

///|
test "Shape extends Path" {
  let object = @extras.Shape::new()
  assert_true(object.curve.kind is Shape(_, _, _))
  assert_true(object.to_path().curve.kind is Shape(_, _, _))
}

///|
test "Shape type" {
  assert_eq(@extras.Shape::new().curve.type_, "Shape")
}

///|
test "Shape uuid" {
  assert_true(@extras.Shape::new().uuid() != @extras.Shape::new().uuid())
}

///|
test "Shape extract_points" {
  let shape = square_shape()
  shape.holes().push(square_hole())
  let points = shape.extract_points(12)
  assert_eq(points.shape.length(), 4)
  assert_eq(points.holes.length(), 1)
  assert_eq(points.holes[0].length(), 4)
}

///|
test "Shape implements SerializableResource for GeometryParameters.shapes" {
  let shape = square_shape()
  let parameters : @core.GeometryParameters = {
    values: Map([]),
    shapes: [shape as &@core.SerializableResource],
  }
  assert_eq(parameters.shapes[0].uuid(), shape.uuid())
  assert_eq(
    parameters.shapes[0].to_json().stringify(),
    shape.to_json().stringify(),
  )
}

///|
test "Shape JSON keeps uuid and holes after the path keys" {
  let shape = square_shape()
  shape.holes().push(square_hole())
  guard shape.to_json() is Object(object) else { fail("not an object") }
  assert_eq(object.keys().collect(), [
    "metadata", "arcLengthDivisions", "type", "autoClose", "curves", "currentPoint",
    "uuid", "holes",
  ])
  let restored = @extras.Shape::new().from_json(shape.to_json())
  assert_eq(restored.uuid(), shape.uuid())
  assert_eq(restored.holes().length(), 1)
  assert_eq(restored.holes()[0].curve.type_, "Path")
}

///|
test "Shape clone is deep and gets its own uuid" {
  let shape = square_shape()
  shape.holes().push(square_hole())
  let clone = shape.clone()
  assert_true(clone.uuid() != shape.uuid())
  assert_true(!physical_equal(clone.holes()[0], shape.holes()[0]))
  assert_exact_points(clone.get_points(), shape.get_points())
}
