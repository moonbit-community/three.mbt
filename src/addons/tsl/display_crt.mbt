// examples/jsm/tsl/display/CRT.js

///|
priv struct CRTModule {
  barrel_uv : @nodes.Node
  barrel_mask : @nodes.Node
  color_bleeding : @nodes.Node
  scanlines : @nodes.Node
  vignette : @nodes.Node
}

///|
let display_crt_module : AddonModule[CRTModule] = AddonModule::new(fn() {
  load_display_shape()
  let barrel_uv = @nodes.fn_(fn(inputs, _) {
    let curvature = inputs.get(0).or_else(fn() { @nodes.float(0.1) })
    let coord = inputs.get(1).or_else(fn() { @nodes.uv() })
    // Center UV coordinates (-1 to 1)
    let centered = coord.sub(0.5).mul(2.0)
    // Calculate squared distance from center
    let r2 = @nodes.dot(centered, centered)
    // Barrel distortion: push center outward (bulge effect)
    let distortion = @nodes.float(1.0).sub(r2.mul(curvature))
    // Calculate scale to compensate for edge expansion
    // At corners r² = 2, so we scale by the inverse of corner distortion
    let corner_distortion = @nodes.float(1.0).sub(curvature.mul(2.0))
    // Apply distortion and compensate scale to keep edges aligned
    let distorted = centered
      .div(distortion)
      .mul(corner_distortion)
      .mul(0.5)
      .add(0.5)
    Some(distorted)
  })
  let barrel_mask = @nodes.fn_(fn(inputs, _) {
    let coord = addon_arg(inputs, 0)
    let out_of_bounds = coord
      .x()
      .less_than(0.0)
      .or(coord.x().greater_than(1.0))
      .or(coord.y().less_than(0.0))
      .or(coord.y().greater_than(1.0))
    Some(
      @nodes.select(
        out_of_bounds,
        @nodes.float(0.0),
        else_node=@nodes.float(1.0),
      ),
    )
  })
  let color_bleeding = @nodes.fn_(fn(inputs, _) {
    let color = addon_arg(inputs, 0)
    let amount = inputs.get(1).or_else(fn() { @nodes.float(0.002) })
    let input_texture = @nodes.convert_to_texture(color)
    // Get the original color
    let original = input_texture.sample(@nodes.screen_uv).rgb()
    // Sample colors from the left (simulating signal trailing)
    let left1 = input_texture
      .sample(@nodes.screen_uv.sub(@nodes.vec2_of([amount, 0.0])))
      .rgb()
    let left2 = input_texture
      .sample(@nodes.screen_uv.sub(@nodes.vec2_of([amount.mul(2.0), 0.0])))
      .rgb()
    let left3 = input_texture
      .sample(@nodes.screen_uv.sub(@nodes.vec2_of([amount.mul(3.0), 0.0])))
      .rgb()
    // Red bleeds more (travels further in analog signal)
    let bleed_r = original
      .r()
      .add(left1.r().mul(0.4))
      .add(left2.r().mul(0.2))
      .add(left3.r().mul(0.1))
    // Green bleeds medium
    let bleed_g = original.g().add(left1.g().mul(0.25)).add(left2.g().mul(0.1))
    // Blue bleeds least
    let bleed_b = original.b().add(left1.b().mul(0.15))
    // Normalize and clamp
    let r = @nodes.clamp(bleed_r.div(1.7), low=0.0, high=1.0)
    let g = @nodes.clamp(bleed_g.div(1.35), low=0.0, high=1.0)
    let b = @nodes.clamp(bleed_b.div(1.15), low=0.0, high=1.0)
    Some(@nodes.vec3_of([r, g, b]))
  })
  let scanlines = @nodes.fn_(fn(inputs, _) {
    let color = addon_arg(inputs, 0)
    let intensity = inputs.get(1).or_else(fn() { @nodes.float(0.3) })
    let count = inputs.get(2).or_else(fn() { @nodes.float(240.0) })
    let speed = inputs.get(3).or_else(fn() { @nodes.float(0.0) })
    let coord = inputs.get(4).or_else(fn() { @nodes.uv() })
    // Animate scanlines scrolling down (like CRT vertical sync roll)
    let animated_y = coord.y().sub(@nodes.time.mul(speed))
    // Create scanline pattern
    let scanline = @nodes.sin(animated_y.mul(count))
    let scanline_intensity = scanline.mul(0.5).add(0.5).mul(intensity)
    // Darken alternate lines
    Some(color.mul(@nodes.float(1.0).sub(scanline_intensity)))
  })
  let vignette = @nodes.fn_(fn(inputs, _) {
    let color = addon_arg(inputs, 0)
    let intensity = inputs.get(1).or_else(fn() { @nodes.float(0.4) })
    let smoothness = inputs.get(2).or_else(fn() { @nodes.float(0.5) })
    let coord = inputs.get(3).or_else(fn() { @nodes.uv() })
    // Use circle for radial gradient (1.42 ≈ √2 covers full diagonal)
    let mask = circle().call([@nodes.float(1.42), smoothness, coord])
    // Apply vignette: center = 1, edges = (1 - intensity)
    let vignette_amount = @nodes.mix(
      @nodes.float(1.0).sub(intensity),
      @nodes.float(1.0),
      mask,
    )
    Some(color.mul(vignette_amount))
  })
  { barrel_uv, barrel_mask, color_bleeding, scanlines, vignette, }
})

///|
/// Evaluates CRT.js (and Shape.js, which it imports), as `import` does.
pub fn load_display_crt() -> Unit {
  display_crt_module.get() |> ignore
}

///|
/// `barrelUV( curvature = float( 0.1 ), coord = uv() )`: barrel-distorted UVs.
pub fn barrel_uv() -> @nodes.Node {
  display_crt_module.get().barrel_uv
}

///|
/// `barrelMask( coord )`: 0 outside the unit square, 1 inside.
pub fn barrel_mask() -> @nodes.Node {
  display_crt_module.get().barrel_mask
}

///|
/// `colorBleeding( color, amount = float( 0.002 ) )`: analog signal color bleeding.
pub fn color_bleeding() -> @nodes.Node {
  display_crt_module.get().color_bleeding
}

///|
/// `scanlines( color, intensity = float( 0.3 ), count = float( 240.0 ), speed =
/// float( 0.0 ), coord = uv() )`.
pub fn scanlines() -> @nodes.Node {
  display_crt_module.get().scanlines
}

///|
/// `vignette( color, intensity = float( 0.4 ), smoothness = float( 0.5 ), coord = uv() )`.
pub fn vignette() -> @nodes.Node {
  display_crt_module.get().vignette
}
