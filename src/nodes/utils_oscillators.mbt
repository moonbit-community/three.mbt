// nodes/utils/Oscillators.js: periodic functions of `time` (or of `t`).

///|
/// `oscSine( t = time )`.
pub fn osc_sine(t? : Node) -> Node {
  let t = t.unwrap_or(time)
  t.add(0.75).mul(3.141592653589793 * 2.0).sin().mul(0.5).add(0.5)
}

///|
/// `oscSquare( t = time )`.
pub fn osc_square(t? : Node) -> Node {
  let t = t.unwrap_or(time)
  t.fract().round()
}

///|
/// `oscTriangle( t = time )`.
pub fn osc_triangle(t? : Node) -> Node {
  let t = t.unwrap_or(time)
  t.add(0.5).fract().mul(2).sub(1).abs()
}

///|
/// `oscSawtooth( t = time )`.
pub fn osc_sawtooth(t? : Node) -> Node {
  let t = t.unwrap_or(time)
  t.fract()
}
