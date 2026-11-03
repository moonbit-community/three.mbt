///|
/// Upstream's custom cubic spline interpolant mimicking `GLTFCubicSplineInterpolant`.
/// The layout is [ inTangent_1, splineVertex_1, outTangent_1, inTangent_2, ... ].
fn custom_test_cubic_spline_interpolant(
  parameter_positions : Array[Double],
  sample_values : Array[Double],
  sample_size : Int32,
  result_buffer : Array[Double],
) -> @math.Interpolant {
  @math.Interpolant::new(
    parameter_positions,
    sample_values,
    sample_size,
    result_buffer~,
    copy_sample_value=(interpolant, index) => {
      let result = interpolant.result_buffer
      let values = interpolant.sample_values
      let value_size = interpolant.value_size
      let offset = index * value_size * 3 + value_size
      for i = 0; i != value_size; i = i + 1 {
        result[i] = values[offset + i]
      }
      result
    },
    interpolate=(interpolant, i1, t0, t, t1) => {
      let result = interpolant.result_buffer
      let values = interpolant.sample_values
      let stride = interpolant.value_size
      let stride2 = stride * 2
      let stride3 = stride * 3
      let td = t1 - t0
      let p = (t - t0) / td
      let pp = p * p
      let ppp = pp * p
      let offset1 = i1 * stride3
      let offset0 = offset1 - stride3
      let s2 = -2.0 * ppp + 3.0 * pp
      let s3 = ppp - pp
      let s0 = 1.0 - s2
      let s1 = s3 - pp + p
      for i = 0; i != stride; i = i + 1 {
        let p0 = values[offset0 + i + stride]
        let m0 = values[offset0 + i + stride2] * td
        let p1 = values[offset1 + i + stride]
        let m1 = values[offset1 + i] * td
        result[i] = s0 * p0 + s1 * m0 + s2 * p1 + s3 * m1
      }
      result
    },
  )
}

///|
test "CustomInterpolant: Extending" {
  // parameterPositions, sampleValues, sampleSize, resultBuffer
  let object : @math.Interpolant = custom_test_cubic_spline_interpolant(
    [0.0, 1.0],
    [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    1,
    [],
  )
  assert_eq(object.value_size, 1)
}

///|
test "CustomInterpolant: evaluate" {
  // Two keyframes at t = 0 and t = 1, valueSize = 1.
  // Layout: [ in_0, v_0, out_0, in_1, v_1, out_1 ]
  // Vertex values 0 -> 1 with non-zero tangents to exercise all spline terms.
  let positions = [0.0, 1.0]
  let values = [0.0, 0.0, 1.0, -1.0, 1.0, 0.0]
  let interpolant = custom_test_cubic_spline_interpolant(positions, values, 1, [
    0.0,
  ])
  assert_eq(interpolant.evaluate(0.0), [0.0])
  assert_eq(interpolant.evaluate(1.0), [1.0])

  // At t = 0.5 with td = 1, p = 0.5 -> s0 = 0.5, s1 = 0.125, s2 = 0.5, s3 = -0.125
  // result = 0.5 * 0 + 0.125 * 1 + 0.5 * 1 + ( -0.125 ) * ( -1 ) = 0.75
  assert_eq(interpolant.evaluate(0.5), [0.75])

  // Out-of-range queries clamp to the boundary spline vertex.
  assert_eq(interpolant.evaluate(-1.0), [0.0])
  assert_eq(interpolant.evaluate(2.0), [1.0])
}
