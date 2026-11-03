// Port of upstream test/unit/src/extras/core/ShapePath.tests.js, plus what it leaves as todo.

///|
test "ShapePath instancing" {
  ignore(@extras.ShapePath::new())
}

///|
test "ShapePath type" {
  assert_eq(@extras.ShapePath::new().type_, "ShapePath")
}

///|
fn shape_path_square(
  path : @extras.ShapePath,
  x : Double,
  size : Double,
  clockwise : Bool,
) -> Unit {
  let corners = [
    vec2(x, x),
    vec2(x + size, x),
    vec2(x + size, x + size),
    vec2(x, x + size),
  ]
  if clockwise {
    corners.rev_in_place()
  }
  ignore(path.move_to(corners[0].x, corners[0].y))
  ignore(path.line_to(corners[1].x, corners[1].y))
  ignore(path.line_to(corners[2].x, corners[2].y))
  ignore(path.line_to(corners[3].x, corners[3].y))
}

///|
test "ShapePath to_shapes makes an opposite winding inner path a hole" {
  let path = @extras.ShapePath::new()
  shape_path_square(path, 0.0, 10.0, false)
  shape_path_square(path, 2.0, 2.0, true)
  let shapes = path.to_shapes()
  assert_eq(shapes.length(), 1)
  assert_eq(shapes[0].holes().length(), 1)
}

///|
test "ShapePath to_shapes excludes a same winding inner path under nonzero" {
  let path = @extras.ShapePath::new()
  shape_path_square(path, 0.0, 10.0, false)
  shape_path_square(path, 2.0, 2.0, false)
  let shapes = path.to_shapes()
  assert_eq(shapes.length(), 1)
  assert_eq(shapes[0].holes().length(), 0)
}

///|
test "ShapePath to_shapes honours evenodd" {
  let path = @extras.ShapePath::new()
  shape_path_square(path, 0.0, 10.0, false)
  shape_path_square(path, 2.0, 2.0, false)
  let style = @core.JsValue::object()
  style.set("fillRule", @core.JsValue::of("evenodd"))
  path.user_data.set("style", style)
  let shapes = path.to_shapes()
  assert_eq(shapes.length(), 1)
  assert_eq(shapes[0].holes().length(), 1)
}

///|
test "ShapePath to_shapes makes a solid inside a hole a new shape" {
  let path = @extras.ShapePath::new()
  shape_path_square(path, 0.0, 10.0, false)
  shape_path_square(path, 2.0, 6.0, true)
  shape_path_square(path, 3.0, 2.0, false)
  let shapes = path.to_shapes()
  assert_eq(shapes.length(), 2)
  assert_eq(shapes[0].holes().length(), 1)
  assert_eq(shapes[1].holes().length(), 0)
}

///|
test "ShapePath to_shapes shares the sub-path's curve array" {
  let path = @extras.ShapePath::new()
  shape_path_square(path, 0.0, 10.0, false)
  let shapes = path.to_shapes()
  assert_true(physical_equal(shapes[0].curves(), path.sub_paths[0].curves()))
}

///|
test "ShapePath skips degenerate sub-paths" {
  let path = @extras.ShapePath::new()
  ignore(path.move_to(0.0, 0.0).line_to(1.0, 0.0))
  ignore(path.move_to(0.0, 0.0).line_to(1.0, 0.0).line_to(2.0, 0.0))
  assert_eq(path.to_shapes().length(), 0)
}

///|
test "ShapePath to_shapes accumulates winding through an excluded container" {
  // The middle square repeats the outer winding, so nonzero excludes it. The inner,
  // opposite square then has cumulative winding 2 - 1 = 1, still inside, so it is
  // excluded too. Upstream gives the same: one shape, no holes.
  let path = @extras.ShapePath::new()
  shape_path_square(path, 0.0, 10.0, false)
  shape_path_square(path, 1.0, 8.0, false)
  shape_path_square(path, 2.0, 2.0, true)
  let shapes = path.to_shapes()
  assert_eq(shapes.length(), 1)
  assert_eq(shapes[0].holes().length(), 0)
}
