// Upstream has no test file for ShapeUtils.

///|
test "ShapeUtils area and is_clock_wise" {
  let ccw = [vec2(0.0, 0.0), vec2(2.0, 0.0), vec2(2.0, 2.0), vec2(0.0, 2.0)]
  assert_eq(@extras.ShapeUtils::area(ccw), 4.0)
  assert_false(@extras.ShapeUtils::is_clock_wise(ccw))
  ccw.rev_in_place()
  assert_eq(@extras.ShapeUtils::area(ccw), -4.0)
  assert_true(@extras.ShapeUtils::is_clock_wise(ccw))
  assert_eq(@extras.ShapeUtils::area([]), 0.0)
}

///|
test "ShapeUtils triangulate_shape" {
  let contour = [vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(1.0, 1.0), vec2(0.0, 1.0)]
  assert_eq(@extras.ShapeUtils::triangulate_shape(contour, []), [
    [2, 3, 0],
    [0, 1, 2],
  ])
}

///|
test "ShapeUtils triangulate_shape removes duplicated end points in place" {
  let contour = [
    vec2(0.0, 0.0),
    vec2(4.0, 0.0),
    vec2(4.0, 4.0),
    vec2(0.0, 4.0),
    vec2(0.0, 0.0),
  ]
  let hole = [
    vec2(1.0, 1.0),
    vec2(1.0, 2.0),
    vec2(2.0, 2.0),
    vec2(2.0, 1.0),
    vec2(1.0, 1.0),
  ]
  let faces = @extras.ShapeUtils::triangulate_shape(contour, [hole])
  assert_eq(contour.length(), 4)
  assert_eq(hole.length(), 4)
  assert_eq(faces.length(), 8)
}
