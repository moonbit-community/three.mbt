// Upstream has no test file: expected values are upstream's output.

///|
test "BezierInterpolant: evaluate without tangents is linear" {
  let interpolant : @math.Interpolant = @math.BezierInterpolant::new(
    [0.0, 1.0],
    [0.0, 1.0],
    1,
  )
  assert_eq(interpolant.evaluate(0.25), [0.25])
}

///|
test "BezierInterpolant: evaluate with tangents" {
  let interpolant = @math.BezierInterpolant::new([0.0, 1.0], [0.0, 1.0], 1)
  interpolant.in_tangents = Some([0.0, 0.0, 0.75, 1.0])
  interpolant.out_tangents = Some([0.25, 0.0, 1.0, 1.0])
  assert_eq(interpolant.evaluate(0.25), [0.18235613683528523])
  assert_eq(interpolant.evaluate(0.5), [0.5])
  assert_eq(interpolant.evaluate(0.75), [0.8176438631647147])
}
