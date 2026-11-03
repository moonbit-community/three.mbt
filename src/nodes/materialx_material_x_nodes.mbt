// nodes/materialx/MaterialXNodes.js: the MaterialX node functions. The wrappers take
// upstream's defaults as labelled optional arguments; parameters used as method
// receivers are `Node`, as only nodes have the methods upstream calls on them.

///|
/// A labelled optional argument with its JS default.
fn materialx_or(value : &IntoTsl?, default : () -> &IntoTsl) -> &IntoTsl {
  match value {
    Some(v) => v
    None => default()
  }
}

///|
/// A labelled optional node argument with its JS default.
fn materialx_or_node(value : Node?, default : () -> Node) -> Node {
  match value {
    Some(v) => v
    None => default()
  }
}

///|
/// `mx_aastep( threshold, value )`: an antialiased step.
pub fn mx_aastep(threshold : &IntoTsl, value : &IntoTsl) -> Node {
  let threshold = float(threshold)
  let value = float(value)
  let afwidth = vec2_of([value.d_fdx(), value.d_fdy()])
    .length()
    .mul(0.70710678118654757)
  smoothstep(threshold.sub(afwidth), threshold.add(afwidth), value)
}

///|
/// `_ramp( a, b, uv, p )`.
fn materialx_ramp(a : &IntoTsl, b : &IntoTsl, uv : Node, p : String) -> Node {
  mix(a, b, uv.swizzle(p).clamp())
}

///|
/// `mx_ramplr( valuel, valuer, texcoord = uv() )`.
pub fn mx_ramplr(
  valuel : &IntoTsl,
  valuer : &IntoTsl,
  texcoord? : Node,
) -> Node {
  let texcoord = materialx_or_node(texcoord, fn() { uv() })
  materialx_ramp(valuel, valuer, texcoord, "x")
}

///|
/// `mx_ramptb( valueb, valuet, texcoord = uv() )`.
pub fn mx_ramptb(
  valueb : &IntoTsl,
  valuet : &IntoTsl,
  texcoord? : Node,
) -> Node {
  let texcoord = materialx_or_node(texcoord, fn() { uv() })
  materialx_ramp(valueb, valuet, texcoord, "y")
}

///|
/// `mx_ramp4( valuetl, valuetr, valuebl, valuebr, texcoord = uv() )`: a bilinear ramp.
pub fn mx_ramp4(
  valuetl : &IntoTsl,
  valuetr : &IntoTsl,
  valuebl : &IntoTsl,
  valuebr : &IntoTsl,
  texcoord? : Node,
) -> Node {
  let texcoord = materialx_or_node(texcoord, fn() { uv() })
  let u = texcoord.x().clamp()
  let v = texcoord.y().clamp()
  let top = mix(valuetl, valuetr, u)
  let bottom = mix(valuebl, valuebr, u)
  mix(bottom, top, v)
}

///|
/// `_split( a, b, center, uv, p )`.
fn materialx_split(
  a : &IntoTsl,
  b : &IntoTsl,
  center : &IntoTsl,
  uv : Node,
  p : String,
) -> Node {
  mix(a, b, mx_aastep(center, uv.swizzle(p)))
}

///|
/// `mx_splitlr( valuel, valuer, center, texcoord = uv() )`.
pub fn mx_splitlr(
  valuel : &IntoTsl,
  valuer : &IntoTsl,
  center : &IntoTsl,
  texcoord? : Node,
) -> Node {
  let texcoord = materialx_or_node(texcoord, fn() { uv() })
  materialx_split(valuel, valuer, center, texcoord, "x")
}

///|
/// `mx_splittb( valueb, valuet, center, texcoord = uv() )`.
pub fn mx_splittb(
  valueb : &IntoTsl,
  valuet : &IntoTsl,
  center : &IntoTsl,
  texcoord? : Node,
) -> Node {
  let texcoord = materialx_or_node(texcoord, fn() { uv() })
  materialx_split(valueb, valuet, center, texcoord, "y")
}

///|
/// `mx_transform_uv( uv_scale = 1, uv_offset = 0, uv_geo = uv() )`.
pub fn mx_transform_uv(
  uv_scale? : &IntoTsl,
  uv_offset? : &IntoTsl,
  uv_geo? : Node,
) -> Node {
  let uv_scale = materialx_or(uv_scale, fn() { 1 })
  let uv_offset = materialx_or(uv_offset, fn() { 0 })
  let uv_geo = materialx_or_node(uv_geo, fn() { uv() })
  uv_geo.mul(uv_scale).add(uv_offset)
}

///|
/// `mx_safepower( in1, in2 = 1 )`.
pub fn mx_safepower(in1 : &IntoTsl, in2? : &IntoTsl) -> Node {
  let in2 = materialx_or(in2, fn() { 1 })
  let in1 = float(in1)
  in1.abs().pow(in2).mul(in1.sign())
}

///|
/// `mx_contrast( input, amount = 1, pivot = .5 )`.
pub fn mx_contrast(
  input : &IntoTsl,
  amount? : &IntoTsl,
  pivot? : &IntoTsl,
) -> Node {
  let amount = materialx_or(amount, fn() { 1 })
  let pivot = materialx_or(pivot, fn() { 0.5 })
  float(input).sub(pivot).mul(amount).add(pivot)
}

///|
/// `mx_noise_float( texcoord = uv(), amplitude = 1, pivot = 0 )`.
pub fn mx_noise_float(
  texcoord? : Node,
  amplitude? : &IntoTsl,
  pivot? : &IntoTsl,
) -> Node {
  let texcoord = materialx_or_node(texcoord, fn() { uv() })
  let amplitude = materialx_or(amplitude, fn() { 1 })
  let pivot = materialx_or(pivot, fn() { 0 })
  mx_perlin_noise_float([texcoord.convert("vec2|vec3")])
  .mul(amplitude)
  .add(pivot)
}

///|
/// `mx_noise_vec3( texcoord = uv(), amplitude = 1, pivot = 0 )`.
pub fn mx_noise_vec3(
  texcoord? : Node,
  amplitude? : &IntoTsl,
  pivot? : &IntoTsl,
) -> Node {
  let texcoord = materialx_or_node(texcoord, fn() { uv() })
  let amplitude = materialx_or(amplitude, fn() { 1 })
  let pivot = materialx_or(pivot, fn() { 0 })
  mx_perlin_noise_vec3([texcoord.convert("vec2|vec3")])
  .mul(amplitude)
  .add(pivot)
}

///|
let mx_perlin_noise_vec4_0 : Node = module_nodes(
  "nodes/materialx/MaterialXNodes.js:mx_perlin_noise_vec4_0",
  fn() {
    fn_(
      fn(inputs, _) {
        let p = inputs.get(0).unwrap()
        Some(
          vec4_of([
            mx_perlin_noise_vec3([p]),
            mx_perlin_noise_float([p.add(vec2_of([19, 73]))]),
          ]),
        )
      },
      layout=FnLayout::short(
        [("p", "vec2")],
        return_="vec4",
        upstream="nodes/materialx/MaterialXNodes.js:mx_perlin_noise_vec4_0",
      ),
    )
  },
)

///|
let mx_perlin_noise_vec4_1 : Node = module_nodes(
  "nodes/materialx/MaterialXNodes.js:mx_perlin_noise_vec4_1",
  fn() {
    fn_(
      fn(inputs, _) {
        let p = inputs.get(0).unwrap()
        Some(
          vec4_of([
            mx_perlin_noise_vec3([p]),
            mx_perlin_noise_float([p.add(vec3_of([19, 73, 29]))]),
          ]),
        )
      },
      layout=FnLayout::short(
        [("p", "vec3")],
        return_="vec4",
        upstream="nodes/materialx/MaterialXNodes.js:mx_perlin_noise_vec4_1",
      ),
    )
  },
)

///|
let mx_perlin_noise_vec4 : (Array[&IntoTsl]) -> Node = overloading_fn([
  mx_perlin_noise_vec4_0, mx_perlin_noise_vec4_1,
])

///|
/// `mx_noise_vec4( texcoord = uv(), amplitude = 1, pivot = 0 )`.
pub fn mx_noise_vec4(
  texcoord? : Node,
  amplitude? : &IntoTsl,
  pivot? : &IntoTsl,
) -> Node {
  let texcoord = materialx_or_node(texcoord, fn() { uv() })
  let amplitude = materialx_or(amplitude, fn() { 1 })
  let pivot = materialx_or(pivot, fn() { 0 })
  mx_perlin_noise_vec4([texcoord.convert("vec2|vec3")])
  .mul(amplitude)
  .add(pivot)
}

///|
/// `mx_smoothstep( inNode, low = 0, high = 1 )`: a smoothstep that falls back to a
/// step for an empty range.
pub fn mx_smoothstep(
  in_node : &IntoTsl,
  low? : &IntoTsl,
  high? : &IntoTsl,
) -> Node {
  let low = materialx_or(low, fn() { 0 })
  let high = materialx_or(high, fn() { 1 })
  let range = sub(high, low)
  let safe_range = max(abs(range), float(epsilon))
  let t = clamp(div(sub(in_node, low), safe_range), low=float(0), high=float(1))
  let hermite = mul(mul(t, t), sub(float(3), mul(float(2), t)))
  let fallback = step(high, in_node)
  let use_fallback = step(high, low)
  mix(hermite, fallback, use_fallback)
}

///|
/// `mx_cell_noise_vec3( texcoord = uv() )`.
pub fn mx_cell_noise_vec3(texcoord? : Node) -> Node {
  let texcoord = materialx_or_node(texcoord, fn() { uv() })
  mx_cell_noise_vec3_impl([texcoord.convert("vec2|vec3")])
}

///|
/// `mx_worley_noise_float_2d( texcoord = uv(), jitter = 1, style = 0 )`.
pub fn mx_worley_noise_float_2d(
  texcoord? : &IntoTsl,
  jitter? : &IntoTsl,
  style? : &IntoTsl,
) -> Node {
  let texcoord = materialx_or(texcoord, fn() { uv() })
  let jitter = materialx_or(jitter, fn() { 1 })
  let style = materialx_or(style, fn() { 0 })
  mx_worley_noise_float_2d_impl.call([texcoord, jitter, style])
}

///|
/// `mx_worley_noise_float_3d( texcoord = uv(), jitter = 1, style = 0 )`.
pub fn mx_worley_noise_float_3d(
  texcoord? : &IntoTsl,
  jitter? : &IntoTsl,
  style? : &IntoTsl,
) -> Node {
  let texcoord = materialx_or(texcoord, fn() { uv() })
  let jitter = materialx_or(jitter, fn() { 1 })
  let style = materialx_or(style, fn() { 0 })
  mx_worley_noise_float_3d_impl.call([texcoord, jitter, style])
}

///|
/// `mx_unifiednoise2d( noiseType, texcoord = uv(), freq = vec2( 1, 1 ), offset = vec2( 0, 0 ),
/// jitter = 1, outmin = 0, outmax = 1, clampoutput = false, octaves = 1, lacunarity = 2,
/// diminish = .5, style = 0 )`.
pub fn mx_unifiednoise2d(
  noise_type : &IntoTsl,
  texcoord? : &IntoTsl,
  freq? : &IntoTsl,
  offset? : &IntoTsl,
  jitter? : &IntoTsl,
  outmin? : &IntoTsl,
  outmax? : &IntoTsl,
  clampoutput? : &IntoTsl,
  octaves? : &IntoTsl,
  lacunarity? : &IntoTsl,
  diminish? : &IntoTsl,
  style? : &IntoTsl,
) -> Node {
  let texcoord = materialx_or(texcoord, fn() { uv() })
  let freq = materialx_or(freq, fn() { vec2_of([1, 1]) })
  let offset = materialx_or(offset, fn() { vec2_of([0, 0]) })
  let jitter = materialx_or(jitter, fn() { 1 })
  let outmin = materialx_or(outmin, fn() { 0 })
  let outmax = materialx_or(outmax, fn() { 1 })
  let clampoutput = materialx_or(clampoutput, fn() { false })
  let octaves = materialx_or(octaves, fn() { 1 })
  let lacunarity = materialx_or(lacunarity, fn() { 2 })
  let diminish = materialx_or(diminish, fn() { 0.5 })
  let style = materialx_or(style, fn() { 0 })
  mx_unifiednoise2d_impl.call([
    noise_type, texcoord, freq, offset, jitter, outmin, outmax, clampoutput, octaves,
    lacunarity, diminish, style,
  ])
}

///|
/// `mx_unifiednoise3d( noiseType, texcoord = uv(), freq = vec3( 1, 1, 1 ), offset = vec3( 0,
/// 0, 0 ), jitter = 1, outmin = 0, outmax = 1, clampoutput = false, octaves = 1,
/// lacunarity = 2, diminish = .5, style = 0 )`.
pub fn mx_unifiednoise3d(
  noise_type : &IntoTsl,
  texcoord? : &IntoTsl,
  freq? : &IntoTsl,
  offset? : &IntoTsl,
  jitter? : &IntoTsl,
  outmin? : &IntoTsl,
  outmax? : &IntoTsl,
  clampoutput? : &IntoTsl,
  octaves? : &IntoTsl,
  lacunarity? : &IntoTsl,
  diminish? : &IntoTsl,
  style? : &IntoTsl,
) -> Node {
  let texcoord = materialx_or(texcoord, fn() { uv() })
  let freq = materialx_or(freq, fn() { vec3_of([1, 1, 1]) })
  let offset = materialx_or(offset, fn() { vec3_of([0, 0, 0]) })
  let jitter = materialx_or(jitter, fn() { 1 })
  let outmin = materialx_or(outmin, fn() { 0 })
  let outmax = materialx_or(outmax, fn() { 1 })
  let clampoutput = materialx_or(clampoutput, fn() { false })
  let octaves = materialx_or(octaves, fn() { 1 })
  let lacunarity = materialx_or(lacunarity, fn() { 2 })
  let diminish = materialx_or(diminish, fn() { 0.5 })
  let style = materialx_or(style, fn() { 0 })
  mx_unifiednoise3d_impl.call([
    noise_type, texcoord, freq, offset, jitter, outmin, outmax, clampoutput, octaves,
    lacunarity, diminish, style,
  ])
}

///|
/// `mx_worley_noise_float( texcoord = uv(), jitter = 1, style = 0 )`.
pub fn mx_worley_noise_float(
  texcoord? : Node,
  jitter? : &IntoTsl,
  style? : &IntoTsl,
) -> Node {
  let texcoord = materialx_or_node(texcoord, fn() { uv() })
  let jitter = materialx_or(jitter, fn() { 1 })
  let style = materialx_or(style, fn() { 0 })
  mx_worley_noise_float_3d(
    texcoord=texcoord.convert("vec2|vec3"),
    jitter~,
    style~,
  )
}

///|
/// `mx_worley_noise_vec2( texcoord = uv(), jitter = 1 )`.
pub fn mx_worley_noise_vec2(texcoord? : Node, jitter? : &IntoTsl) -> Node {
  let texcoord = materialx_or_node(texcoord, fn() { uv() })
  let jitter = materialx_or(jitter, fn() { 1 })
  mx_worley_noise_vec2_impl([texcoord.convert("vec2|vec3"), jitter, int(1)])
}

///|
/// `mx_worley_noise_vec3( texcoord = uv(), jitter = 1, metric = 1 )`.
pub fn mx_worley_noise_vec3(
  texcoord? : Node,
  jitter? : &IntoTsl,
  metric? : &IntoTsl,
) -> Node {
  let texcoord = materialx_or_node(texcoord, fn() { uv() })
  let jitter = materialx_or(jitter, fn() { 1 })
  let metric = materialx_or(metric, fn() { 1 })
  mx_worley_noise_vec3_impl([texcoord.convert("vec2|vec3"), jitter, int(metric)])
}

///|
/// `mx_worley_noise_vec3_style( texcoord = uv(), jitter = 1, style = 0, metric = 0 )`.
pub fn mx_worley_noise_vec3_style(
  texcoord? : Node,
  jitter? : &IntoTsl,
  style? : &IntoTsl,
  metric? : &IntoTsl,
) -> Node {
  let texcoord = materialx_or_node(texcoord, fn() { uv() })
  let jitter = materialx_or(jitter, fn() { 1 })
  let style = materialx_or(style, fn() { 0 })
  let metric = materialx_or(metric, fn() { 0 })
  mx_worley_noise_vec3_style_impl([
    texcoord.convert("vec2|vec3"),
    jitter,
    int(style),
    int(metric),
  ])
}

///|
/// `mx_cell_noise_float( texcoord = uv() )`.
pub fn mx_cell_noise_float(texcoord? : Node) -> Node {
  let texcoord = materialx_or_node(texcoord, fn() { uv() })
  mx_cell_noise_float_impl([texcoord.convert("vec2|vec3")])
}

///|
/// `mx_fractal_noise_float_2d( texcoord = uv(), octaves = 3, lacunarity = 2, diminish = .5,
/// amplitude = 1 )`.
pub fn mx_fractal_noise_float_2d(
  texcoord? : &IntoTsl,
  octaves? : &IntoTsl,
  lacunarity? : &IntoTsl,
  diminish? : &IntoTsl,
  amplitude? : &IntoTsl,
) -> Node {
  let texcoord = materialx_or(texcoord, fn() { uv() })
  let octaves = materialx_or(octaves, fn() { 3 })
  let lacunarity = materialx_or(lacunarity, fn() { 2 })
  let diminish = materialx_or(diminish, fn() { 0.5 })
  let amplitude = materialx_or(amplitude, fn() { 1 })
  mx_fractal_noise_float_2d_impl
  .call([texcoord, int(octaves), lacunarity, diminish])
  .mul(amplitude)
}

///|
/// `mx_fractal_noise_float( position = uv(), octaves = 3, lacunarity = 2, diminish = .5,
/// amplitude = 1 )`.
pub fn mx_fractal_noise_float(
  position? : &IntoTsl,
  octaves? : &IntoTsl,
  lacunarity? : &IntoTsl,
  diminish? : &IntoTsl,
  amplitude? : &IntoTsl,
) -> Node {
  let position = materialx_or(position, fn() { uv() })
  let octaves = materialx_or(octaves, fn() { 3 })
  let lacunarity = materialx_or(lacunarity, fn() { 2 })
  let diminish = materialx_or(diminish, fn() { 0.5 })
  let amplitude = materialx_or(amplitude, fn() { 1 })
  mx_fractal_noise_float_impl
  .call([position, int(octaves), lacunarity, diminish])
  .mul(amplitude)
}

///|
/// `mx_fractal_noise_vec2( position = uv(), octaves = 3, lacunarity = 2, diminish = .5,
/// amplitude = 1 )`.
pub fn mx_fractal_noise_vec2(
  position? : &IntoTsl,
  octaves? : &IntoTsl,
  lacunarity? : &IntoTsl,
  diminish? : &IntoTsl,
  amplitude? : &IntoTsl,
) -> Node {
  let position = materialx_or(position, fn() { uv() })
  let octaves = materialx_or(octaves, fn() { 3 })
  let lacunarity = materialx_or(lacunarity, fn() { 2 })
  let diminish = materialx_or(diminish, fn() { 0.5 })
  let amplitude = materialx_or(amplitude, fn() { 1 })
  mx_fractal_noise_vec2_impl
  .call([position, int(octaves), lacunarity, diminish])
  .mul(amplitude)
}

///|
/// `mx_fractal_noise_vec3( position = uv(), octaves = 3, lacunarity = 2, diminish = .5,
/// amplitude = 1 )`.
pub fn mx_fractal_noise_vec3(
  position? : &IntoTsl,
  octaves? : &IntoTsl,
  lacunarity? : &IntoTsl,
  diminish? : &IntoTsl,
  amplitude? : &IntoTsl,
) -> Node {
  let position = materialx_or(position, fn() { uv() })
  let octaves = materialx_or(octaves, fn() { 3 })
  let lacunarity = materialx_or(lacunarity, fn() { 2 })
  let diminish = materialx_or(diminish, fn() { 0.5 })
  let amplitude = materialx_or(amplitude, fn() { 1 })
  mx_fractal_noise_vec3_impl
  .call([position, int(octaves), lacunarity, diminish])
  .mul(amplitude)
}

///|
/// `mx_fractal_noise_vec4( position = uv(), octaves = 3, lacunarity = 2, diminish = .5,
/// amplitude = 1 )`.
pub fn mx_fractal_noise_vec4(
  position? : &IntoTsl,
  octaves? : &IntoTsl,
  lacunarity? : &IntoTsl,
  diminish? : &IntoTsl,
  amplitude? : &IntoTsl,
) -> Node {
  let position = materialx_or(position, fn() { uv() })
  let octaves = materialx_or(octaves, fn() { 3 })
  let lacunarity = materialx_or(lacunarity, fn() { 2 })
  let diminish = materialx_or(diminish, fn() { 0.5 })
  let amplitude = materialx_or(amplitude, fn() { 1 })
  mx_fractal_noise_vec4_impl
  .call([position, int(octaves), lacunarity, diminish])
  .mul(amplitude)
}

///|
/// `mx_add( in1, in2 = float( 0 ) )`.
pub fn mx_add(in1 : &IntoTsl, in2? : &IntoTsl) -> Node {
  let in2 = materialx_or(in2, fn() { float(0) })
  add(in1, in2)
}

///|
/// `mx_subtract( in1, in2 = float( 0 ) )`.
pub fn mx_subtract(in1 : &IntoTsl, in2? : &IntoTsl) -> Node {
  let in2 = materialx_or(in2, fn() { float(0) })
  sub(in1, in2)
}

///|
/// `mx_multiply( in1, in2 = float( 1 ) )`.
pub fn mx_multiply(in1 : &IntoTsl, in2? : &IntoTsl) -> Node {
  let in2 = materialx_or(in2, fn() { float(1) })
  mul(in1, in2)
}

///|
/// `mx_divide( in1, in2 = float( 1 ) )`.
pub fn mx_divide(in1 : &IntoTsl, in2? : &IntoTsl) -> Node {
  let in2 = materialx_or(in2, fn() { float(1) })
  div(in1, in2)
}

///|
/// `mx_modulo( in1, in2 = float( 1 ) )`.
pub fn mx_modulo(in1 : &IntoTsl, in2? : &IntoTsl) -> Node {
  let in2 = materialx_or(in2, fn() { float(1) })
  sub(in1, mul(in2, floor(div(in1, in2))))
}

///|
/// `mx_power( in1, in2 = float( 1 ) )`.
pub fn mx_power(in1 : &IntoTsl, in2? : &IntoTsl) -> Node {
  let in2 = materialx_or(in2, fn() { float(1) })
  pow(in1, in2)
}

///|
/// `mx_atan2( in1 = float( 0 ), in2 = float( 1 ) )`.
pub fn mx_atan2(in1? : &IntoTsl, in2? : &IntoTsl) -> Node {
  let in1 = materialx_or(in1, fn() { float(0) })
  let in2 = materialx_or(in2, fn() { float(1) })
  atan(in1, x=in2)
}

///|
/// `mx_timer()`.
pub fn mx_timer() -> Node {
  time
}

///|
/// `mx_frame()`.
pub fn mx_frame() -> Node {
  frame_id
}

///|
/// `mx_invert( in1, amount = float( 1 ) )`.
pub fn mx_invert(in1 : &IntoTsl, amount? : &IntoTsl) -> Node {
  let amount = materialx_or(amount, fn() { float(1) })
  sub(amount, in1)
}

///|
/// `mx_ifgreater( value1, value2, in1, in2 )`.
pub fn mx_ifgreater(
  value1 : Node,
  value2 : &IntoTsl,
  in1 : &IntoTsl,
  in2 : &IntoTsl,
) -> Node {
  value1.greater_than(value2).mix(in2, in1)
}

///|
/// `mx_ifgreatereq( value1, value2, in1, in2 )`.
pub fn mx_ifgreatereq(
  value1 : Node,
  value2 : &IntoTsl,
  in1 : &IntoTsl,
  in2 : &IntoTsl,
) -> Node {
  value1.greater_than_equal(value2).mix(in2, in1)
}

///|
/// `mx_ifequal( value1, value2, in1, in2 )`.
pub fn mx_ifequal(
  value1 : Node,
  value2 : &IntoTsl,
  in1 : &IntoTsl,
  in2 : &IntoTsl,
) -> Node {
  value1.equal(value2).mix(in2, in1)
}

///|
/// The channel index of `x`/`r`, `y`/`g`, `z`/`b`, `w`/`a`.
fn materialx_channel_index(c : String) -> Int32? {
  match c {
    "x" | "r" => Some(0)
    "y" | "g" => Some(1)
    "z" | "b" => Some(2)
    "w" | "a" => Some(3)
    _ => None
  }
}

///|
extern "js" fn materialx_separate_channel(s : String) -> String = "(s) => s.replace( /^out/, '' ).toLowerCase()"

///|
/// `mx_separate( in1, channelOrOut = null )`: one channel by name (`'outx'`, `'r'`) or
/// index.
pub fn mx_separate(in1 : Node, channel_or_out~ : TslValue = Null) -> Node {
  if channel_or_out is String(s) {
    let c = materialx_separate_channel(s)
    if materialx_channel_index(c) is Some(i) {
      return in1.element(i)
    }
  }
  if channel_or_out is Number(n) {
    return in1.element(n)
  }
  if channel_or_out is String(s) && s.length() == 1 {
    if materialx_channel_index(s) is Some(i) {
      return in1.element(i)
    }
  }
  in1
}

///|
/// `Number.EPSILON`.
let materialx_number_epsilon : Double = 2.220446049250313e-16

///|
/// `mx_place2d( texcoord, pivot = vec2( 0, 0 ), scale = vec2( 1, 1 ), rotate = float( 0 ),
/// offset = vec2( 0, 0 ), operationorder = int( 0 ) )`.
pub fn mx_place2d(
  texcoord : &IntoTsl,
  pivot? : &IntoTsl,
  scale? : &IntoTsl,
  rotate? : &IntoTsl,
  offset? : &IntoTsl,
  operationorder? : &IntoTsl,
) -> Node {
  let pivot = materialx_or(pivot, fn() { vec2_of([0, 0]) })
  let scale = materialx_or(scale, fn() { vec2_of([1, 1]) })
  let rotate = materialx_or(rotate, fn() { float(0) })
  let offset = materialx_or(offset, fn() { vec2_of([0, 0]) })
  let operationorder = materialx_or(operationorder, fn() { int(0) })
  let centered = sub(texcoord, pivot)
  let srt = add(
    sub(mx_rotate2d(div(centered, scale), amount=rotate), offset),
    pivot,
  )
  let trs = add(
    div(mx_rotate2d(sub(centered, offset), amount=rotate), scale),
    pivot,
  )
  if operationorder.to_tsl() is Number(order) {
    return if order.abs() > materialx_number_epsilon { trs } else { srt }
  }
  mix(srt, trs, step(0.5, float(operationorder)))
}

///|
/// `mx_heighttonormal( input, scale = 1, texcoord = uv() )`: a normal from a height map
/// by screen-space derivatives.
pub fn mx_heighttonormal(
  input : &IntoTsl,
  scale? : &IntoTsl,
  texcoord? : &IntoTsl,
) -> Node {
  let scale = materialx_or(scale, fn() { 1 })
  let texcoord = materialx_or(texcoord, fn() { uv() })
  let sobel_scale = float(1.0 / 16.0)
  let height = float(input)
  let uv_node = vec2(texcoord)
  let d_hd_s = vec2_of([height.d_fdx(), height.d_fdy()])
    .mul(float(scale))
    .mul(sobel_scale)
  let d_ud_s = vec2_of([uv_node.x().d_fdx(), uv_node.x().d_fdy()])
  let d_vd_s = vec2_of([uv_node.y().d_fdx(), uv_node.y().d_fdy()])
  let tangent = vec3_of([d_ud_s.x(), d_vd_s.x(), d_hd_s.x()])
  let bitangent = vec3_of([d_ud_s.y(), d_vd_s.y(), d_hd_s.y()])
  let mut n = cross(tangent, bitangent)
  let invalid = dot(n, n).less_than(float(1.0e-12))
  n = invalid.mix(n, vec3_of([0, 0, 1]))
  let mirrored = n.z().less_than(float(0))
  n = mirrored.mix(n, n.mul(-1))
  normalize(n).mul(0.5).add(0.5)
}
