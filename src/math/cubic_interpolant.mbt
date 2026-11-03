///|
/// Namespace for the constructor; the value is a plain `Interpolant`.
#external
pub type CubicInterpolant

///|
pub fn CubicInterpolant::new(
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
    interpolate=cubic_interpolate,
    interval_changed=cubic_interval_changed,
  )
}

///|
fn cubic_interval_changed(
  interpolant : Interpolant,
  i1 : Int32,
  t0 : Double,
  t1 : Double,
) -> Unit {
  let pp = interpolant.parameter_positions
  let mut i_prev = i1 - 2
  let mut i_next = i1 + 1
  let t_prev = match pp.get(i_prev) {
    Some(t_prev) => t_prev
    None =>
      match interpolant.get_settings_().ending_start {
        ZeroSlopeEnding => {
          // f'(t0) = 0
          i_prev = i1
          2.0 * t0 - t1
        }
        WrapAroundEnding => {
          // use the other end of the curve
          i_prev = pp.length() - 2
          t0 + pp[i_prev] - pp[i_prev + 1]
        }
        _ => {
          // ZeroCurvatureEnding
          // f''(t0) = 0 a.k.a. Natural Spline
          i_prev = i1
          t1
        }
      }
  }
  let t_next = match pp.get(i_next) {
    Some(t_next) => t_next
    None =>
      match interpolant.get_settings_().ending_end {
        ZeroSlopeEnding => {
          // f'(tN) = 0
          i_next = i1
          2.0 * t1 - t0
        }
        WrapAroundEnding => {
          // use the other end of the curve
          i_next = 1
          t1 + pp[1] - pp[0]
        }
        _ => {
          // ZeroCurvatureEnding
          // f''(tN) = 0, a.k.a. Natural Spline
          i_next = i1 - 1
          t0
        }
      }
  }
  let half_dt = (t1 - t0) * 0.5
  let stride = interpolant.value_size
  interpolant.weight_prev = half_dt / (t0 - t_prev)
  interpolant.weight_next = half_dt / (t_next - t1)
  interpolant.offset_prev = i_prev * stride
  interpolant.offset_next = i_next * stride
}

///|
fn cubic_interpolate(
  interpolant : Interpolant,
  i1 : Int32,
  t0 : Double,
  t : Double,
  t1 : Double,
) -> Array[Double] {
  let result = interpolant.result_buffer
  let values = interpolant.sample_values
  let stride = interpolant.value_size
  let o1 = i1 * stride
  let o0 = o1 - stride
  let o_p = interpolant.offset_prev
  let o_n = interpolant.offset_next
  let w_p = interpolant.weight_prev
  let w_n = interpolant.weight_next
  let p = (t - t0) / (t1 - t0)
  let pp = p * p
  let ppp = pp * p

  // evaluate polynomials
  let s_p = -w_p * ppp + 2.0 * w_p * pp - w_p * p
  let s0 = (1.0 + w_p) * ppp + (-1.5 - 2.0 * w_p) * pp + (-0.5 + w_p) * p + 1.0
  let s1 = (-1.0 - w_n) * ppp + (1.5 + w_n) * pp + 0.5 * p
  let s_n = w_n * ppp - w_n * pp

  // combine data linearly
  for i = 0; i != stride; i = i + 1 {
    result[i] = s_p * values[o_p + i] +
      s0 * values[o0 + i] +
      s1 * values[o1 + i] +
      s_n * values[o_n + i]
  }
  result
}
