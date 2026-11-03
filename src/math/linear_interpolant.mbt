///|
/// Namespace for the constructor; the value is a plain `Interpolant`.
#external
pub type LinearInterpolant

///|
pub fn LinearInterpolant::new(
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
    interpolate=linear_interpolate,
  )
}

///|
fn linear_interpolate(
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
  let weight1 = (t - t0) / (t1 - t0)
  let weight0 = 1.0 - weight1
  for i = 0; i != stride; i = i + 1 {
    result[i] = values[offset0 + i] * weight0 + values[offset1 + i] * weight1
  }
  result
}
