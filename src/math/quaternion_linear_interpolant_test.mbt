///|
test "QuaternionLinearInterpolant: Extending" {
  // parameterPositions, sampleValues, sampleSize, resultBuffer
  let object : @math.Interpolant = @math.QuaternionLinearInterpolant::new(
    [],
    [1.0, 11.0, 2.0, 22.0, 3.0, 33.0],
    2,
    result_buffer=[],
  )
  assert_eq(object.value_size, 2)
}

///|
test "QuaternionLinearInterpolant: Instancing" {
  // parameterPositions, sampleValues, sampleSize, resultBuffer
  let object = @math.QuaternionLinearInterpolant::new(
    [],
    [1.0, 11.0, 2.0, 22.0, 3.0, 33.0],
    2,
    result_buffer=[],
  )
  assert_eq(object.sample_values.length(), 6)
}

// Not in upstream's test file: expected values are upstream's output.

///|
test "QuaternionLinearInterpolant: evaluate" {
  let s = 0.5.sqrt()
  let interpolant = @math.QuaternionLinearInterpolant::new(
    [0.0, 1.0],
    [0.0, 0.0, 0.0, 1.0, 0.0, 0.0, s, s],
    4,
  )
  assert_eq(interpolant.evaluate(0.0), [0.0, 0.0, 0.0, 1.0])
  assert_eq(interpolant.evaluate(0.5), [
    0.0, 0.0, 0.38268343236508984, 0.9238795325112868,
  ])
  assert_eq(interpolant.evaluate(1.0), [
    0.0, 0.0, 0.7071067811865476, 0.7071067811865476,
  ])
}
