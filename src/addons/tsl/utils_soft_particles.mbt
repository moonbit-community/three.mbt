// examples/jsm/tsl/utils/SoftParticles.js

///|
priv struct SoftParticlesModule {
  contrast_curve : @nodes.Node
}

///|
let utils_soft_particles_module : AddonModule[SoftParticlesModule] = AddonModule::new(fn() {
    let contrast_curve = @nodes.fn_(
      fn(inputs, _) {
        let value = addon_arg(inputs, 0)
        let power = addon_arg(inputs, 1)
        let above_half = value.greater_than(0.5).to_const()
        let folded = above_half
          .select(value.one_minus(), else_node=value)
          .to_const()
        let output = folded.mul(2).saturate().pow(power).mul(0.5).to_const()
        Some(above_half.select(output.one_minus(), else_node=output))
      },
      layout=addon_short_layout(
        [("value", "float"), ("power", "float")],
        "float",
      ),
    )
    { contrast_curve, }
  },
)

///|
/// Evaluates SoftParticles.js, as `import` does.
pub fn load_utils_soft_particles() -> Unit {
  utils_soft_particles_module.get() |> ignore
}

///|
/// `softParticles( { opacity = float( 1 ), distance = 1, contrast = 2, viewportDepth =
/// viewportDepthTexture() } = {} )`: fades particles out where they approach the opaque
/// scene behind them.
pub fn soft_particles(
  opacity? : @nodes.Node,
  distance? : &@nodes.IntoTsl,
  contrast? : &@nodes.IntoTsl,
  viewport_depth? : @nodes.Node,
) -> @nodes.Node {
  let contrast_curve = utils_soft_particles_module.get().contrast_curve
  let opacity = match opacity {
    Some(o) => o
    None => @nodes.float(1)
  }
  let distance : &@nodes.IntoTsl = match distance {
    Some(d) => d
    None => 1
  }
  let contrast : &@nodes.IntoTsl = match contrast {
    Some(c) => c
    None => 2
  }
  let viewport_depth = match viewport_depth {
    Some(v) => v
    None => @nodes.viewport_depth_texture()
  }
  // Read the opaque scene depth captured before the particle pass and convert both
  // the scene depth and the particle's depth to view space.
  let scene_view_z = @nodes.perspective_depth_to_view_z
    .call([viewport_depth, @nodes.camera_near, @nodes.camera_far])
    .to_const()
  let depth_delta = @nodes.position_view
    .z()
    .sub(scene_view_z)
    .div(distance)
    .saturate()
  // Fade out as the particle approaches the scene; stay opaque when well in front of it.
  opacity.mul(contrast_curve.call([depth_delta, contrast]))
}
