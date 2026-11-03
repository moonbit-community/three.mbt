///|
/// Namespace for the constructor; the value is a plain `Interpolant`.
#external
pub type QuaternionLinearInterpolant

///|
pub fn QuaternionLinearInterpolant::new(
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
    interpolate=quaternion_linear_interpolate,
  )
}

///|
fn quaternion_linear_interpolate(
  interpolant : Interpolant,
  i1 : Int32,
  t0 : Double,
  t : Double,
  t1 : Double,
) -> Array[Double] {
  let result = interpolant.result_buffer
  let values = interpolant.sample_values
  let stride = interpolant.value_size
  let alpha = (t - t0) / (t1 - t0)
  let mut offset = i1 * stride
  let end = offset + stride
  while offset != end {
    Quaternion::slerp_flat(
      result,
      0,
      values,
      offset - stride,
      values,
      offset,
      alpha,
    )
    offset += 4
  }
  result
}
