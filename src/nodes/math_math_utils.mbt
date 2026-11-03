// nodes/math/MathUtils.js: `parabola`, `gain`, `pcurve`, `sinc`.

///|
/// `parabola( x, k )`: a parabola remapping [0, 1] to [0, 1].
pub fn parabola(x : Node, k : &IntoTsl) -> Node {
  pow(mul(4.0, x.mul(sub(1.0, x))), k)
}

///|
/// `gain( x, k )`: expands the sides and compresses the center of [0, 1].
pub fn gain(x : Node, k : &IntoTsl) -> Node {
  select(
    x.less_than(0.5),
    pow(mul(2.0, x), k).mul(0.5),
    else_node=sub(1.0, pow(mul(2.0, sub(1.0, x)), k).mul(0.5)),
  )
}

///|
/// `pcurve( x, a, b )`: a generalized parabola.
pub fn pcurve(x : &IntoTsl, a : &IntoTsl, b : &IntoTsl) -> Node {
  pow(div(pow(x, a), add(pow(x, a), pow(sub(1.0, x), b))), div(1.0, a))
}

///|
/// `sinc( x, k )`: a phase-shifted sinc curve.
pub fn sinc(x : &IntoTsl, k : Node) -> Node {
  let arg = abs(pi.mul(k.mul(x).sub(1.0))).max(epsilon).to_const()
  sin(arg).div(arg)
}
