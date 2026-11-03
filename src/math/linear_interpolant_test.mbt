///|
test "LinearInterpolant: Extending" {
  // parameterPositions, sampleValues, sampleSize, resultBuffer
  let object : @math.Interpolant = @math.LinearInterpolant::new(
    [],
    [1.0, 11.0, 2.0, 22.0, 3.0, 33.0],
    2,
    result_buffer=[],
  )
  assert_eq(object.value_size, 2)
}

///|
test "LinearInterpolant: Instancing" {
  // parameterPositions, sampleValues, sampleSize, resultBuffer
  let object = @math.LinearInterpolant::new(
    [],
    [1.0, 11.0, 2.0, 22.0, 3.0, 33.0],
    2,
    result_buffer=[],
  )
  assert_eq(object.sample_values.length(), 6)
}

// Not in upstream's test file: expected values are upstream's output.

///|
test "LinearInterpolant: evaluate" {
  let interpolant = @math.LinearInterpolant::new(
    [0.0, 1.0, 3.0],
    [0.0, 10.0, 10.0, 0.0, 30.0, 5.0],
    2,
  )
  assert_eq(interpolant.evaluate(0.5), [5.0, 5.0])
  assert_eq(interpolant.evaluate(2.0), [20.0, 2.5])
  assert_eq(interpolant.evaluate(3.0), [30.0, 5.0])
  assert_eq(interpolant.evaluate(-1.0), [0.0, 10.0])
  assert_eq(interpolant.evaluate(5.0), [30.0, 5.0])
}
