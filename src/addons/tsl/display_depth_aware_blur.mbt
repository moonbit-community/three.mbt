// examples/jsm/tsl/display/depthAwareBlur.js

///|
priv struct DepthAwareBlurModule {
  depth_aware_blur : @nodes.Node
}

///|
let display_depth_aware_blur_module : AddonModule[DepthAwareBlurModule] = AddonModule::new(fn() {
    let depth_aware_blur = @nodes.fn_(fn(inputs, builder) {
      let input_node = addon_arg(inputs, 0)
      let depth_node = addon_arg(inputs, 1)
      let direction_node = addon_arg(inputs, 2)
      let camera = addon_object3d_arg(inputs, 3)
      let sharpness = a4_arg_or(inputs, 4, Number(2.0))
      let radius = a4_arg_or(inputs, 5, Number(1.0))
      let camera_near = @nodes.reference(
        "near",
        "float",
        object=Object3D(camera),
      )
      let camera_far = @nodes.reference("far", "float", object=Object3D(camera))
      let view_z = fn(uv_node : @nodes.Node) {
        let depth = depth_node.sample(uv_node).r()
        if builder.renderer.logarithmic_depth_buffer == true {
          return @nodes.logarithmic_depth_to_view_z(
            depth, camera_near, camera_far,
          )
        }
        @nodes.perspective_depth_to_view_z.call([depth, camera_near, camera_far])
      }
      let uv_node = @nodes.uv()
      let center_view_z = view_z(uv_node).to_var()
      let sum = @nodes.float(0).to_var()
      let weight_sum = @nodes.float(0).to_var()
      @nodes.loop_(
        [
          @nodes.loop_range(
            start=@nodes.int(-2),
            end=@nodes.int(3),
            type_="int",
            condition="<",
          ),
        ],
        fn(inputs) {
          let i = inputs.named("i").unwrap()
          let fi = @nodes.float(i)
          let sample_uv = uv_node.add(direction_node.mul(fi))
          let spatial_weight = @nodes.exp(fi.mul(fi).mul(-0.5))
          let depth_weight = @nodes.exp(
            @nodes.abs(view_z(sample_uv).sub(center_view_z))
            .div(radius)
            .mul(sharpness)
            .negate(),
          )
          let weight = spatial_weight.mul(depth_weight)
          sum.add_assign(input_node.sample(sample_uv).r().mul(weight))
          weight_sum.add_assign(weight)
        },
      )
      Some(sum.div(@nodes.max(weight_sum, @nodes.float(0.0001))))
    })
    { depth_aware_blur, }
  },
)

///|
/// Evaluates depthAwareBlur.js, as `import` does.
pub fn load_display_depth_aware_blur() -> Unit {
  display_depth_aware_blur_module.get() |> ignore
}

///|
/// `depthAwareBlur( inputNode, depthNode, directionNode, camera, sharpness = 2,
/// radius = 1 )`: a 5-tap blur weighted by view-space depth differences.
pub fn depth_aware_blur() -> @nodes.Node {
  display_depth_aware_blur_module.get().depth_aware_blur
}
