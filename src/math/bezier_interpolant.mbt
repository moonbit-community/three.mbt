///|
/// Namespace for the constructor; the value is a plain `Interpolant`.
/// Tangents are read from its `in_tangents` and `out_tangents` fields.
#external
pub type BezierInterpolant

///|
pub fn BezierInterpolant::new(
  parameter_positions : Array[Double],
  sample_values : Array[Double],
  sample_size : Int32,
  result_buffer? : Array[Double],
) -> Interpolant {
  Interpolant::new(
    parameter_positions,
    sample_values,
    sample_size,
    result_buffer?,
    interpolate=bezier_interpolate,
  )
}

///|
fn bezier_interpolate(
  interpolant : Interpolant,
  i1 : Int32,
  t0 : Double,
  t : Double,
  t1 : Double,
) -> Array[Double] {
  let result = interpolant.result_buffer
  let values = interpolant.sample_values
  let stride = interpolant.value_size
  let offset1 = i1 * stride
  let offset0 = offset1 - stride
  guard interpolant.in_tangents is Some(in_tangents) &&
    interpolant.out_tangents is Some(out_tangents) else {
    // If no tangent data, fall back to linear interpolation
    let weight1 = (t - t0) / (t1 - t0)
    let weight0 = 1.0 - weight1
    for i = 0; i != stride; i = i + 1 {
      result[i] = values[offset0 + i] * weight0 + values[offset1 + i] * weight1
    }
    return result
  }
  let tangent_stride = stride * 2
  let i0 = i1 - 1
  for i = 0; i != stride; i = i + 1 {
    let v0 = values[offset0 + i]
    let v1 = values[offset1 + i]

    // outTangent of previous keyframe (C0)
    let out_tangent_offset = i0 * tangent_stride + i * 2
    let c0x = out_tangents[out_tangent_offset]
    let c0y = out_tangents[out_tangent_offset + 1]

    // inTangent of current keyframe (C1)
    let in_tangent_offset = i1 * tangent_stride + i * 2
    let c1x = in_tangents[in_tangent_offset]
    let c1y = in_tangents[in_tangent_offset + 1]

    // Find the curve parameter s where the Bezier X(s) matches t, then evaluate Y(s)
    let s = solve_bezier_parameter(t, t0, c0x, c1x, t1)
    result[i] = cubic_bezier(s, v0, c0y, c1y, v1)
  }
  result
}

///|
fn cubic_bezier(
  s : Double,
  p0 : Double,
  p1 : Double,
  p2 : Double,
  p3 : Double,
) -> Double {
  let k = 1.0 - s
  k * k * k * p0 + 3.0 * k * k * s * p1 + 3.0 * k * s * s * p2 + s * s * s * p3
}

///|
fn cubic_bezier_slope(
  s : Double,
  p0 : Double,
  p1 : Double,
  p2 : Double,
  p3 : Double,
) -> Double {
  let k = 1.0 - s
  3.0 * k * k * (p1 - p0) + 6.0 * k * s * (p2 - p1) + 3.0 * s * s * (p3 - p2)
}

///|
/// Solves `cubic_bezier(s, x0, x1, x2, x3) = x` for s in [0,1] using Newton-Raphson.
fn solve_bezier_parameter(
  x : Double,
  x0 : Double,
  x1 : Double,
  x2 : Double,
  x3 : Double,
) -> Double {
  let mut s = (x - x0) / (x3 - x0)
  for i = 0; i < 8; i = i + 1 {
    let error = cubic_bezier(s, x0, x1, x2, x3) - x
    if error.abs() < 1.0e-10 {
      break
    }
    let slope = cubic_bezier_slope(s, x0, x1, x2, x3)
    if slope.abs() < 1.0e-10 {
      break
    }
    s = js_max(0.0, js_min(1.0, s - error / slope))
  }
  s
}
