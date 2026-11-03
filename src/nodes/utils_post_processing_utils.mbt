// nodes/utils/PostProcessingUtils.js: depth and screen-space helpers for
// post-processing passes.

///|
/// `isBackgroundDepth( depth )`: whether a depth value is the cleared background.
pub let is_background_depth : Node = module_nodes(
  "nodes/utils/PostProcessingUtils.js:isBackgroundDepth",
  fn() {
    fn_(fn(inputs, builder) {
      let depth = operator_node_input(inputs, 0)
      Some(
        if builder.renderer.reversed_depth_buffer {
          depth.less_than_equal(0.0)
        } else {
          depth.greater_than_equal(1.0)
        },
      )
    })
  },
)

///|
/// `getViewPosition( screenPosition, depth, projectionMatrixInverse )`: the view-space
/// position of a screen position and its depth.
pub let get_view_position : Node = module_nodes(
  "nodes/utils/PostProcessingUtils.js:getViewPosition",
  fn() {
    fn_(fn(inputs, builder) {
      let mut screen_position = operator_node_input(inputs, 0)
      let depth = operator_node_input(inputs, 1)
      let projection_matrix_inverse = operator_node_input(inputs, 2)
      let clip_space_position = if builder.renderer.coordinate_system() ==
        @core.WebGPUCoordinateSystem ||
        builder.renderer.reversed_depth_buffer {
        screen_position = vec2_of([
            screen_position.x(),
            screen_position.y().one_minus(),
          ])
          .mul(2.0)
          .sub(1.0)
        vec4_of([vec3_of([screen_position, depth]), 1.0])
      } else {
        vec4_of([
          vec3_of([screen_position.x(), screen_position.y().one_minus(), depth])
          .mul(2.0)
          .sub(1.0),
          1.0,
        ])
      }
      let view_space_position = vec4(
        projection_matrix_inverse.mul(clip_space_position),
      )
      Some(view_space_position.xyz().div(view_space_position.w()))
    })
  },
)

///|
/// `getScreenPosition( viewPosition, projectionMatrix )`: the screen position (uv) of
/// a view-space position.
pub let get_screen_position : Node = module_nodes(
  "nodes/utils/PostProcessingUtils.js:getScreenPosition",
  fn() {
    fn_(
      fn(inputs, _) {
        let view_position = operator_node_input(inputs, 0)
        let projection_matrix = operator_node_input(inputs, 1)
        let sample_clip_pos = projection_matrix.mul(
          vec4_of([view_position, 1.0]),
        )
        let sample_uv = sample_clip_pos
          .xy()
          .div(sample_clip_pos.w())
          .mul(0.5)
          .add(0.5)
          .to_var()
        Some(vec2_of([sample_uv.x(), sample_uv.y().one_minus()]))
      },
      layout=FnLayout::short(
        [("viewPosition", "vec3"), ("projectionMatrix", "mat4")],
        return_="vec2",
        upstream="nodes/utils/PostProcessingUtils.js:getScreenPosition",
      ),
    )
  },
)

///|
/// `getScreenPositionFromClip( clipPosition )`.
pub let get_screen_position_from_clip : Node = module_nodes(
  "nodes/utils/PostProcessingUtils.js:getScreenPositionFromClip",
  fn() {
    fn_(
      fn(inputs, _) {
        let clip_position = operator_node_input(inputs, 0)
        let screen = clip_position
          .xy()
          .div(clip_position.w())
          .mul(0.5)
          .add(0.5)
          .to_var()
        Some(vec2_of([screen.x(), screen.y().one_minus()]))
      },
      layout=FnLayout::short(
        [("clipPosition", "vec4")],
        return_="vec2",
        upstream="nodes/utils/PostProcessingUtils.js:getScreenPositionFromClip",
      ),
    )
  },
)

///|
/// `interleavedGradientNoise( position )`: a noise value from a screen position.
pub let interleaved_gradient_noise : Node = module_nodes(
  "nodes/utils/PostProcessingUtils.js:interleavedGradientNoise",
  fn() {
    fn_(
      fn(inputs, _) {
        let position = operator_node_input(inputs, 0)
        Some(
          fract(
            float(52.9829189).mul(
              fract(dot(position, vec2_of([0.06711056, 0.00583715]))),
            ),
          ),
        )
      },
      layout=FnLayout::short(
        [("position", "vec2")],
        return_="float",
        upstream="nodes/utils/PostProcessingUtils.js:interleavedGradientNoise",
      ),
    )
  },
)

///|
/// `vogelDiskSample( sampleIndex, samplesCount, phi )`: a sample on a Vogel disk.
pub let vogel_disk_sample : Node = module_nodes(
  "nodes/utils/PostProcessingUtils.js:vogelDiskSample",
  fn() {
    fn_(
      fn(inputs, _) {
        let sample_index = operator_node_input(inputs, 0)
        let samples_count = operator_node_input(inputs, 1)
        let phi = operator_node_input(inputs, 2)
        let golden_angle = float(2.399963229728653) // 2π * (2 - φ) where φ is golden ratio
        let r = sqrt(float(sample_index).add(0.5).div(float(samples_count)))
        let theta = float(sample_index).mul(golden_angle).add(phi)
        Some(vec2_of([cos(theta), sin(theta)]).mul(r))
      },
      layout=FnLayout::short(
        [("sampleIndex", "int"), ("samplesCount", "int"), ("phi", "float")],
        return_="vec2",
        upstream="nodes/utils/PostProcessingUtils.js:vogelDiskSample",
      ),
    )
  },
)

///|
/// `getNormalFromDepth( uv, depthTexture, projectionMatrixInverse )`: the view-space
/// normal reconstructed from a depth texture.
pub let get_normal_from_depth : Node = module_nodes(
  "nodes/utils/PostProcessingUtils.js:getNormalFromDepth",
  fn() {
    fn_(fn(inputs, _) {
      let uv_node = operator_node_input(inputs, 0)
      // a texture node or the `Texture` itself (`this.depthNode.value`, as GTAONode and
      // SSGINode pass it): `textureLoad( depthTexture )` takes either
      let depth_texture = match inputs.value(1) {
        Undefined | Null => TslValue::Node(operator_node_input(inputs, 1))
        Texture(t) => Texture(t)
        _ => Node(operator_node_input(inputs, 1))
      }
      let projection_matrix_inverse = operator_node_input(inputs, 2)
      let size = texture_size(texture_load(depth_texture))
      let p = ivec2(uv_node.mul(size)).to_var()
      let c0 = texture_load(depth_texture, uv_node=p).to_var()
      let l2 = texture_load(depth_texture, uv_node=p.sub(ivec2_of([2, 0]))).to_var()
      let l1 = texture_load(depth_texture, uv_node=p.sub(ivec2_of([1, 0]))).to_var()
      let r1 = texture_load(depth_texture, uv_node=p.add(ivec2_of([1, 0]))).to_var()
      let r2 = texture_load(depth_texture, uv_node=p.add(ivec2_of([2, 0]))).to_var()
      let b2 = texture_load(depth_texture, uv_node=p.add(ivec2_of([0, 2]))).to_var()
      let b1 = texture_load(depth_texture, uv_node=p.add(ivec2_of([0, 1]))).to_var()
      let t1 = texture_load(depth_texture, uv_node=p.sub(ivec2_of([0, 1]))).to_var()
      let t2 = texture_load(depth_texture, uv_node=p.sub(ivec2_of([0, 2]))).to_var()
      let dl = abs(sub(float(2).mul(l1).sub(l2), c0)).to_var()
      let dr = abs(sub(float(2).mul(r1).sub(r2), c0)).to_var()
      let db = abs(sub(float(2).mul(b1).sub(b2), c0)).to_var()
      let dt = abs(sub(float(2).mul(t1).sub(t2), c0)).to_var()
      let view_position = fn(uv : Node, depth : Node) {
        get_view_position.call([uv, depth, projection_matrix_inverse])
      }
      let ce = view_position(uv_node, c0).to_var()
      let dpdx = dl
        .less_than(dr)
        .select(
          ce.sub(
            view_position(uv_node.sub(vec2_of([float(1).div(size.x()), 0])), l1),
          ),
          else_node=ce
            .negate()
            .add(
              view_position(
                uv_node.add(vec2_of([float(1).div(size.x()), 0])),
                r1,
              ),
            ),
        )
      let dpdy = db
        .less_than(dt)
        .select(
          ce.sub(
            view_position(uv_node.add(vec2_of([0, float(1).div(size.y())])), b1),
          ),
          else_node=ce
            .negate()
            .add(
              view_position(
                uv_node.sub(vec2_of([0, float(1).div(size.y())])),
                t1,
              ),
            ),
        )
      Some(normalize(cross(dpdx, dpdy)))
    })
  },
)
