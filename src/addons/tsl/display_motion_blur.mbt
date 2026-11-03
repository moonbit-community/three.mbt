// examples/jsm/tsl/display/MotionBlur.js

///|
priv struct MotionBlurModule {
  motion_blur : @nodes.Node
}

///|
let display_motion_blur_module : AddonModule[MotionBlurModule] = AddonModule::new(fn() {
    let motion_blur = @nodes.fn_(fn(inputs, _) {
      let input_node = addon_arg(inputs, 0)
      let velocity = addon_arg(inputs, 1)
      let num_samples = inputs.get(2).unwrap_or_else(fn() { @nodes.int(16) })
      let sample_color = fn(uv : @nodes.Node) { input_node.sample(uv) }
      let uvs = @nodes.uv()
      let color_result = @nodes.vec4(0).to_var()
      let f_samples = @nodes.float(num_samples)
      // taps span [ -0.5, 0.5 ] * velocity, a single tap sits at the center
      let center = f_samples.sub(1).mul(0.5)
      let spacing = f_samples.sub(1).max(1)
      let start = @nodes.int(0)
      @nodes.loop_(
        [@nodes.loop_range(start~, end=num_samples, type_="int", condition="<")],
        fn(inputs) {
          let i = inputs.named("i").unwrap()
          let offset = velocity.mul(@nodes.float(i).sub(center).div(spacing))
          color_result.add_assign(sample_color(uvs.add(offset)))
        },
      )
      color_result.div_assign(f_samples)
      Some(color_result)
    })
    { motion_blur, }
  },
)

///|
/// Evaluates MotionBlur.js, as `import` does.
pub fn load_display_motion_blur() -> Unit {
  display_motion_blur_module.get() |> ignore
}

///|
/// `motionBlur( inputNode, velocity, numSamples = int( 16 ) )` (the module-level `Fn`;
/// `.call([input, velocity, num_samples?])`).
pub fn motion_blur() -> @nodes.Node {
  display_motion_blur_module.get().motion_blur
}
