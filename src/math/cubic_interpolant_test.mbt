///|
test "CubicInterpolant: Extending" {
  // parameterPositions, sampleValues, sampleSize, resultBuffer
  let object : @math.Interpolant = @math.CubicInterpolant::new(
    [],
    [1.0, 11.0, 2.0, 22.0, 3.0, 33.0],
    2,
    result_buffer=[],
  )
  assert_eq(object.value_size, 2)
}

///|
test "CubicInterpolant: Instancing" {
  // parameterPositions, sampleValues, sampleSize, resultBuffer
  let object = @math.CubicInterpolant::new(
    [],
    [1.0, 11.0, 2.0, 22.0, 3.0, 33.0],
    2,
    result_buffer=[],
  )
  assert_eq(object.sample_values.length(), 6)
}

// Not in upstream's test file: expected values are upstream's output.

///|
fn cubic_test_interpolant(ending : Int32) -> @math.Interpolant {
  let interpolant = @math.CubicInterpolant::new(
    [0.0, 1.0, 2.0, 4.0],
    [0.0, 2.0, 1.0, 5.0],
    1,
  )
  interpolant.settings = Some(
    @math.InterpolantSettings::new(ending_start=ending, ending_end=ending),
  )
  interpolant
}

///|
test "CubicInterpolant: evaluate with default settings" {
  let interpolant = @math.CubicInterpolant::new(
    [0.0, 1.0, 2.0, 4.0],
    [0.0, 2.0, 1.0, 5.0],
    1,
  )
  assert_eq(interpolant.evaluate(0.5), [1.1875])
  assert_eq(interpolant.evaluate(1.5), [1.5])
  assert_eq(interpolant.evaluate(3.0), [2.625])
}

///|
test "CubicInterpolant: evaluate with ZeroCurvatureEnding" {
  let interpolant = cubic_test_interpolant(@math.ZeroCurvatureEnding)
  assert_eq(interpolant.evaluate(0.5), [1.1875])
  assert_eq(interpolant.evaluate(1.5), [1.5])
  assert_eq(interpolant.evaluate(3.0), [2.625])
}

///|
test "CubicInterpolant: evaluate with ZeroSlopeEnding" {
  let interpolant = cubic_test_interpolant(@math.ZeroSlopeEnding)
  assert_eq(interpolant.evaluate(0.5), [0.9375])
  assert_eq(interpolant.evaluate(1.5), [1.5])
  assert_eq(interpolant.evaluate(3.0), [2.875])
}

///|
test "CubicInterpolant: evaluate with WrapAroundEnding" {
  let interpolant = cubic_test_interpolant(@math.WrapAroundEnding)
  assert_eq(interpolant.evaluate(0.5), [1.03125])
  assert_eq(interpolant.evaluate(1.5), [1.5])
  assert_eq(interpolant.evaluate(3.0), [3.25])
}
