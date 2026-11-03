// examples/jsm/tsl/display/depthAwareBlend.js

///|
priv struct DepthAwareBlendModule {
  depth_aware_blend : @nodes.Node
}

///|
let display_depth_aware_blend_module : AddonModule[DepthAwareBlendModule] = AddonModule::new(fn() {
    let depth_aware_blend = @nodes.fn_(fn(inputs, _) {
      let base_node = addon_arg(inputs, 0)
      let blend_node = addon_arg(inputs, 1)
      let depth_node = addon_arg(inputs, 2)
      let camera = addon_object3d_arg(inputs, 3)
      let options = inputs.value(4)
      let uv_node = match a4_texture_uv_node(base_node) {
        Some(n) => n
        None => @nodes.uv()
      }
      let camera_near = @nodes.reference(
        "near",
        "float",
        object=Object3D(camera),
      )
      let camera_far = @nodes.reference("far", "float", object=Object3D(camera))
      let blend_color = a4_option_node_or(options, "blendColor", fn() {
        @nodes.color(0xffffff)
      })
      let edge_radius = a4_option_node_or(options, "edgeRadius", fn() {
        @nodes.int(2)
      })
      let edge_strength = a4_option_node_or(options, "edgeStrength", fn() {
        @nodes.float(2)
      })
      let view_z = @nodes.perspective_depth_to_view_z.call([
        depth_node, camera_near, camera_far,
      ])
      let correct_depth = @nodes.view_z_to_orthographic_depth(
        view_z, camera_near, camera_far,
      )
      let push_dir = @nodes.vec2(0.0).to_var()
      let count = @nodes.float(0).to_var()
      let resolution = @nodes.ivec2(@nodes.texture_size(base_node)).to_const()
      let pixel_step = @nodes.vec2(1).div(resolution)
      let poisson_disk = @nodes.array([
        @nodes.vec2_of([0.493393, 0.394269]),
        @nodes.vec2_of([0.798547, 0.885922]),
        @nodes.vec2_of([0.259143, 0.650754]),
        @nodes.vec2_of([0.605322, 0.023588]),
        @nodes.vec2_of([-0.574681, 0.137452]),
        @nodes.vec2_of([-0.430397, -0.638423]),
        @nodes.vec2_of([-0.849487, -0.366258]),
        @nodes.vec2_of([0.170621, -0.569941]),
      ])
      @nodes.loop_([8], fn(inputs) {
        let i = inputs.named("i").unwrap()
        let offset = poisson_disk.element(i).mul(edge_radius)
        let sample_uv = uv_node.add(offset.mul(pixel_step))
        let sample_depth = depth_node.sample(sample_uv)
        let sample_view_z = @nodes.perspective_depth_to_view_z.call([
          sample_depth, camera_near, camera_far,
        ])
        let sample_linear_depth = @nodes.view_z_to_orthographic_depth(
          sample_view_z, camera_near, camera_far,
        )
        @nodes.if_(
          @nodes.abs(sample_linear_depth.sub(correct_depth)).less_than(
            @nodes.float(0.05).mul(correct_depth),
          ),
          fn() {
            push_dir.add_assign(offset)
            count.add_assign(1)
          },
        )
        |> ignore
      })
      count.assign(count.equal(0).select(1, else_node=count))
      // upstream's `pushDir.divAssign( count ).normalize()`: the normalize is not used
      push_dir.div_assign(count)
      push_dir.normalize() |> ignore
      let sample_uv = push_dir
        .length()
        .greater_than(0)
        .select(
          uv_node.add(edge_strength.mul(push_dir.div(resolution))),
          else_node=uv_node,
        )
      let best_choice = blend_node.sample(sample_uv).r()
      let base_color = base_node.sample(uv_node)
      Some(
        @nodes.vec4(
          @nodes.mix(base_color, @nodes.vec4_of([blend_color, 1]), best_choice),
        ),
      )
    })
    { depth_aware_blend, }
  },
)

///|
/// Evaluates depthAwareBlend.js, as `import` does.
pub fn load_display_depth_aware_blend() -> Unit {
  display_depth_aware_blend_module.get() |> ignore
}

///|
/// `depthAwareBlend( baseNode, blendNode, depthNode, camera, options = {} )`; options
/// `blendColor`, `edgeRadius`, `edgeStrength`.
pub fn depth_aware_blend() -> @nodes.Node {
  display_depth_aware_blend_module.get().depth_aware_blend
}
