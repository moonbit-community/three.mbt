// nodes/materialx/MaterialXCore.js

///|
/// `mx_rotate2d( input, amount = 0 )`: rotates a vec2 by `amount` degrees.
pub fn mx_rotate2d(input : &IntoTsl, amount? : &IntoTsl) -> Node {
  let amount : &IntoTsl = match amount {
    Some(v) => v
    None => 0
  }
  let input = vec2(input)
  let amount = float(amount)
  let rotation_radians = mul(amount, 3.141592653589793 / 180.0)
  let sa = sin(rotation_radians)
  let ca = cos(rotation_radians)
  let x = input.x()
  let y = input.y()
  vec2_of([add(mul(ca, x), mul(sa, y)), sub(mul(ca, y), mul(sa, x))])
}

///|
/// `mx_rotate3d( input, amount = 0, axis = vec3( 0, 1, 0 ) )`: rotates a vec3 by
/// `amount` degrees around `axis`.
pub fn mx_rotate3d(
  input : &IntoTsl,
  amount? : &IntoTsl,
  axis? : &IntoTsl,
) -> Node {
  let amount : &IntoTsl = match amount {
    Some(v) => v
    None => 0
  }
  let axis : &IntoTsl = match axis {
    Some(v) => v
    None => vec3_of([0, 1, 0])
  }
  let input = vec3(input)
  let amount = float(amount)
  let axis = vec3(axis)
  let normalized_axis = normalize(axis)
  let rotation_radians = mul(amount, 3.141592653589793 / 180.0)
  let s = sin(rotation_radians)
  let c = cos(rotation_radians)
  let oc = sub(1, c)
  input
  .mul(c)
  .add(input.cross(normalized_axis).mul(s))
  .add(normalized_axis.mul(normalized_axis.dot(input).mul(oc)))
}
