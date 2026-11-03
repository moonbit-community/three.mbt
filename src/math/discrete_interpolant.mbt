///|
/// Namespace for the constructor; the value is a plain `Interpolant`.
#external
pub type DiscreteInterpolant

///|
pub fn DiscreteInterpolant::new(
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
    interpolate=discrete_interpolate,
  )
}

///|
fn discrete_interpolate(
  interpolant : Interpolant,
  i1 : Int32,
  _t0 : Double,
  _t : Double,
  _t1 : Double,
) -> Array[Double] {
  interpolant.copy_sample_value_(i1 - 1)
}
