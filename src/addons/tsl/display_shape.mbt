// examples/jsm/tsl/display/Shape.js

///|
priv struct ShapeModule {
  circle : @nodes.Node
}

///|
let display_shape_module : AddonModule[ShapeModule] = AddonModule::new(fn() {
  let circle = @nodes.fn_(fn(inputs, _) {
    let scale = inputs.get(0).or_else(fn() { @nodes.float(1.0) })
    let softness = inputs.get(1).or_else(fn() { @nodes.float(0.5) })
    let coord = inputs.get(2).or_else(fn() { @nodes.uv() })
    // Center UV coordinates (-0.5 to 0.5)
    let centered = coord.sub(0.5)
    // Calculate distance from center (0 at center, ~0.707 at corners)
    let dist = @nodes.length(centered).mul(2.0)
    // Calculate inner and outer edges based on scale and softness
    let outer = scale
    let inner = scale.sub(softness.mul(scale))
    // Smoothstep for soft/hard transition
    Some(@nodes.smoothstep(outer, inner, dist))
  })
  { circle, }
})

///|
/// Evaluates Shape.js, as `import` does.
pub fn load_display_shape() -> Unit {
  display_shape_module.get() |> ignore
}

///|
/// `circle( scale = 1, softness = 0.5, coord = uv() )`: a soft-edged disc mask.
pub fn circle() -> @nodes.Node {
  display_shape_module.get().circle
}
