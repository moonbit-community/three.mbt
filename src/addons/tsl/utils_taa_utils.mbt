// examples/jsm/tsl/utils/TAAUtils.js

///|
priv struct TAAUtilsModule {
  clip_aabb : @nodes.Node
  flicker_reduction : @nodes.Node
  sample_current_depth : @nodes.Node
  sample_previous_depth : @nodes.Node
}

///|
/// `currentDepthStruct`, created after the four `Fn`s (upstream statement order).
let _taa_utils_current_depth_struct : Ref[@nodes.StructFn?] = Ref(None)

///|
let utils_taa_utils_module : AddonModule[TAAUtilsModule] = AddonModule::new(fn() {
  let clip_aabb = @nodes.fn_(
    fn(inputs, _) {
      let current_color = addon_arg(inputs, 0)
      let history_color = addon_arg(inputs, 1)
      let min_color = addon_arg(inputs, 2)
      let max_color = addon_arg(inputs, 3)
      let p_clip = max_color.rgb().add(min_color.rgb()).mul(0.5).to_const()
      let e_clip = max_color
        .rgb()
        .sub(min_color.rgb())
        .mul(0.5)
        .add(1.0e-7)
        .to_const()
      let v_clip = history_color
        .sub(@nodes.vec4_of([p_clip, current_color.a()]))
        .to_const()
      let v_unit = v_clip.xyz().div(e_clip).to_const()
      let abs_unit = v_unit.abs().to_const()
      let max_unit = @nodes.max_of([abs_unit.x(), abs_unit.y(), abs_unit.z()]).to_const()
      Some(
        max_unit
        .greater_than(1)
        .select(
          @nodes.vec4_of([p_clip, current_color.a()]).add(v_clip.div(max_unit)),
          else_node=history_color,
        ),
      )
    },
    layout=addon_short_layout(
      [
        ("currentColor", "vec4"),
        ("historyColor", "vec4"),
        ("minColor", "vec4"),
        ("maxColor", "vec4"),
      ],
      "vec4",
    ),
  )
  let flicker_reduction = @nodes.fn_(fn(inputs, _) {
    let current_color = addon_arg(inputs, 0)
    let history_color = addon_arg(inputs, 1)
    let current_weight = addon_arg(inputs, 2)
    let compressed_current = current_color
      .mul(
        @nodes.float(1).div(
          @nodes.max_of([
            current_color.r(),
            current_color.g(),
            current_color.b(),
          ]).add(1),
        ),
      )
      .to_const()
    let compressed_history = history_color
      .mul(
        @nodes.float(1).div(
          @nodes.max_of([
            history_color.r(),
            history_color.g(),
            history_color.b(),
          ]).add(1),
        ),
      )
      .to_const()
    let luminance_current = @nodes.luminance(compressed_current.rgb()).to_const()
    let luminance_history = @nodes.luminance(compressed_history.rgb()).to_const()
    let weight_current = current_weight.div(luminance_current.add(1)).to_const()
    let weight_history = current_weight
      .one_minus()
      .div(luminance_history.add(1))
      .to_const()
    Some(
      @nodes.add(
        current_color.mul(weight_current),
        history_color.mul(weight_history),
      ).div(@nodes.max(weight_current.add(weight_history), 0.00001)),
    )
  })
  let sample_current_depth = @nodes.fn_(fn(inputs, builder) {
    let depth_node = addon_arg(inputs, 0)
    let position_texel = addon_arg(inputs, 1)
    let camera_near_far = addon_arg(inputs, 2)
    let closest_depth = @nodes.float(2).to_var()
    let closest_position_texel = @nodes.vec2(0).to_var()
    let farthest_depth = @nodes.float(-1).to_var()
    for x in -1..<=1 {
      for y in -1..<=1 {
        let neighbor = position_texel.add(@nodes.vec2_of([x, y])).to_var()
        let mut depth = depth_node.load(neighbor).r()
        if builder.renderer.reversed_depth_buffer {
          depth = depth.one_minus()
        }
        if builder.renderer.logarithmic_depth_buffer {
          depth = taa_utils_logarithmic_to_perspective_depth(
            depth, camera_near_far,
          )
        }
        let depth = depth.to_var()
        @nodes.if_(depth.less_than(closest_depth), fn() {
          closest_depth.assign(depth)
          closest_position_texel.assign(neighbor)
        })
        |> ignore
        @nodes.if_(depth.greater_than(farthest_depth), fn() {
          farthest_depth.assign(depth)
        })
        |> ignore
      }
    }
    Some(
      _taa_utils_current_depth_struct.val
      .unwrap()
      .call([closest_depth, closest_position_texel, farthest_depth]),
    )
  })
  let sample_previous_depth = @nodes.fn_(fn(inputs, builder) {
    let previous_depth_node = addon_arg(inputs, 0)
    let uv = addon_arg(inputs, 1)
    let previous_camera_projection_matrix_inverse = addon_arg(inputs, 2)
    let previous_camera_world_matrix = addon_arg(inputs, 3)
    let camera_world_matrix_inverse = addon_arg(inputs, 4)
    let camera_near_far = addon_arg(inputs, 5)
    let camera = addon_object3d_arg(inputs, 6)
    let mut depth = previous_depth_node.sample(uv).r()
    if builder.renderer.logarithmic_depth_buffer {
      depth = taa_utils_logarithmic_to_perspective_depth(depth, camera_near_far)
    }
    let position_view = @nodes.get_view_position.call([
      uv, depth, previous_camera_projection_matrix_inverse,
    ])
    let position_world = previous_camera_world_matrix
      .mul(@nodes.vec4_of([position_view, 1]))
      .xyz()
    let view_z = camera_world_matrix_inverse
      .mul(@nodes.vec4_of([position_world, 1]))
      .z()
    Some(
      if camera.is_orthographic_camera() {
        @nodes.view_z_to_orthographic_depth(
          view_z,
          camera_near_far.x(),
          camera_near_far.y(),
        )
      } else {
        @nodes.view_z_to_perspective_depth(
          view_z,
          camera_near_far.x(),
          camera_near_far.y(),
        )
      },
    )
  })
  _taa_utils_current_depth_struct.val = Some(
    @nodes.struct_([
      @nodes.StructMember::new("closestDepth", "float"),
      @nodes.StructMember::new("closestPositionTexel", "vec2"),
      @nodes.StructMember::new("farthestDepth", "float"),
    ]),
  )
  { clip_aabb, flicker_reduction, sample_current_depth, sample_previous_depth, }
})

///|
/// Evaluates TAAUtils.js (its module-level `Fn`s and struct), as `import` does.
pub fn load_utils_taa_utils() -> Unit {
  utils_taa_utils_module.get() |> ignore
}

///|
/// `clipAABB( currentColor, historyColor, minColor, maxColor )`: clips the history color
/// to the neighborhood's AABB.
pub fn clip_aabb() -> @nodes.Node {
  utils_taa_utils_module.get().clip_aabb
}

///|
/// `flickerReduction( currentColor, historyColor, currentWeight )`.
pub fn flicker_reduction() -> @nodes.Node {
  utils_taa_utils_module.get().flicker_reduction
}

///|
/// `sampleCurrentDepth( depthNode, positionTexel, cameraNearFar )`: the closest and
/// farthest depth of the 3x3 neighborhood (struct `closestDepth`, `closestPositionTexel`,
/// `farthestDepth`).
pub fn sample_current_depth() -> @nodes.Node {
  utils_taa_utils_module.get().sample_current_depth
}

///|
/// `samplePreviousDepth( previousDepthNode, uv, previousCameraProjectionMatrixInverse,
/// previousCameraWorldMatrix, cameraWorldMatrixInverse, cameraNearFar, camera )`.
pub fn sample_previous_depth() -> @nodes.Node {
  utils_taa_utils_module.get().sample_previous_depth
}

///|
/// `computeHaltonOffsets( length )`: `[ halton( i + 1, 2 ), halton( i + 1, 3 ) ]` pairs.
pub fn compute_halton_offsets(length : Int32) -> Array[(Double, Double)] {
  Array::makei(length, fn(index) {
    (taa_utils_halton(index + 1, 2), taa_utils_halton(index + 1, 3))
  })
}

///|
fn taa_utils_logarithmic_to_perspective_depth(
  depth : @nodes.Node,
  camera_near_far : @nodes.Node,
) -> @nodes.Node {
  let near = camera_near_far.x()
  let far = camera_near_far.y()
  let view_z = @nodes.logarithmic_depth_to_view_z(depth, near, far)
  @nodes.view_z_to_perspective_depth(view_z, near, far)
}

///|
fn taa_utils_halton(index : Int32, base : Int32) -> Double {
  let mut index = index
  let mut fraction = 1.0
  let mut result = 0.0
  while index > 0 {
    fraction /= base.to_double()
    result += fraction * (index % base).to_double()
    index = index / base
  }
  result
}
