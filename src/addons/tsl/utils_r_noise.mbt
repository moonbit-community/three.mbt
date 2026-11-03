// examples/jsm/tsl/utils/RNoise.js

///|
/// `bindAnalyticNoise( resolution, seed = 0 )`: a `Fn( [ uvCoord, sampleIndex ] )` giving
/// analytic R4 blue-ish noise (vec4) tiled every 32 pixels.
pub fn bind_analytic_noise(
  resolution : &@nodes.IntoTsl,
  seed? : &@nodes.IntoTsl,
) -> @nodes.Node {
  let seed : &@nodes.IntoTsl = match seed {
    Some(s) => s
    None => 0
  }
  let seed_offset = @nodes.int(seed)
  let r4 = fn(coords : @nodes.Node) -> @nodes.Node {
    let p = 1.32471795724474602596
    let t = coords
      .x()
      .mul(1.0 / p)
      .add(coords.y().mul(1.0 / addon_js_pow(p, 2)))
      .add(@nodes.float(seed))
    @nodes.vec4_of([
      @nodes.fract(t.mul(p).mul(1.0 / p)),
      @nodes.fract(t.mul(p * 2.0).mul(1.0 / addon_js_pow(p, 2))),
      @nodes.fract(t.mul(p * 3.0).mul(0.4198754210)), // this is not 1 / P ** 3, however this magic constant gives better noise
      @nodes.fract(t.mul(p * 4.0).mul(1.0 / addon_js_pow(p, 3))),
    ])
  }
  @nodes.fn_(fn(inputs, _) {
    let uv_coord = addon_arg(inputs, 0)
    let sample_index = addon_arg(inputs, 1)
    let index = @nodes.int(sample_index).add(seed_offset)
    let noise = @nodes.vec4_of([]).to_var()
    let tile_size = @nodes.float(32)
    let screen_pixel = uv_coord.mul(resolution).floor()
    let offset = @nodes.fract(
        @nodes.vec2_of([
          @nodes.float(index).mul(0.7548776662),
          @nodes.float(index).mul(0.5698402910),
        ]),
      )
      .mul(tile_size)
      .floor()
    let coords = screen_pixel.add(offset).mod(tile_size)
    noise.assign(r4(coords))
    Some(noise)
  })
}
