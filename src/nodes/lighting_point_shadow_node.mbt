// nodes/lighting/PointShadowNode.js: cube shadow maps for point lights.

///|
let point_shadow_node_clear_color : @math.Color = @math.Color::new(
  1.0, 1.0, 1.0,
)

///|
let point_shadow_node_proj_screen_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
let point_shadow_node_light_position_world : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let point_shadow_node_look_target : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let point_shadow_node_cube_directions_webgpu : Array[@math.Vector3] = [
  @math.Vector3::new(-1.0, 0.0, 0.0),
  @math.Vector3::new(1.0, 0.0, 0.0),
  @math.Vector3::new(0.0, 1.0, 0.0),
  @math.Vector3::new(0.0, -1.0, 0.0),
  @math.Vector3::new(0.0, 0.0, 1.0),
  @math.Vector3::new(0.0, 0.0, -1.0),
]

///|
let point_shadow_node_cube_ups_webgpu : Array[@math.Vector3] = [
  @math.Vector3::new(0.0, 1.0, 0.0),
  @math.Vector3::new(0.0, 1.0, 0.0),
  @math.Vector3::new(0.0, 0.0, -1.0),
  @math.Vector3::new(0.0, 0.0, 1.0),
  @math.Vector3::new(0.0, 1.0, 0.0),
  @math.Vector3::new(0.0, 1.0, 0.0),
]

///|
let point_shadow_node_cube_directions_webgl : Array[@math.Vector3] = [
  @math.Vector3::new(1.0, 0.0, 0.0),
  @math.Vector3::new(-1.0, 0.0, 0.0),
  @math.Vector3::new(0.0, 1.0, 0.0),
  @math.Vector3::new(0.0, -1.0, 0.0),
  @math.Vector3::new(0.0, 0.0, 1.0),
  @math.Vector3::new(0.0, 0.0, -1.0),
]

///|
let point_shadow_node_cube_ups_webgl : Array[@math.Vector3] = [
  @math.Vector3::new(0.0, -1.0, 0.0),
  @math.Vector3::new(0.0, -1.0, 0.0),
  @math.Vector3::new(0.0, 0.0, 1.0),
  @math.Vector3::new(0.0, 0.0, -1.0),
  @math.Vector3::new(0.0, -1.0, 0.0),
  @math.Vector3::new(0.0, -1.0, 0.0),
]

///|
/// `getPointShadowDepthFn( distance, near, far, bias, renderer )`: the depth a cube
/// face stores for a point, as a function of its largest absolute coordinate.
fn point_shadow_node_get_depth_fn(
  distance : Node,
  near : Node,
  far : Node,
  bias : Node,
  renderer : Renderer,
) -> (Node) -> Node {
  if renderer.logarithmic_depth_buffer == true {
    return fn(max_abs) {
      view_z_to_logarithmic_depth(max_abs.mul(distance).negate(), near, far).add(
        bias,
      )
    }
  }
  let depth_range = far.sub(near)
  let near_far = near.mul(far).div(depth_range.mul(distance))
  let (depth_a, depth_b) = if renderer.reversed_depth_buffer == true {
    (near.div(depth_range).add(bias).negate().to_const(), near_far.to_const())
  } else {
    (far.div(depth_range).add(bias).to_const(), near_far.negate().to_const())
  }
  fn(max_abs) { depth_a.add(depth_b.div(max_abs)) }
}

///|
/// `BasicPointShadowFilter( { depthTexture, bd3D, dp } )`.
pub let basic_point_shadow_filter : Node = module_nodes(
  "nodes/lighting/PointShadowNode.js:BasicPointShadowFilter",
  fn() {
    fn_(fn(inputs, _) {
      let depth_texture = shadow_filter_texture(inputs, "depthTexture")
      let bd3d = inputs.named("bd3D").unwrap()
      let dp = inputs.named("dp").unwrap()
      Some(cube_texture(depth_texture, uv_node=bd3d).compare(dp))
    })
  },
)

///|
/// `PointShadowFilter( { depthTexture, bd3D, distance, shadow } )`: five Vogel disk
/// samples in the tangent plane of the light direction.
pub let point_shadow_filter : Node = module_nodes(
  "nodes/lighting/PointShadowNode.js:PointShadowFilter",
  fn() {
    fn_(fn(inputs, builder) {
      let depth_texture = shadow_filter_texture(inputs, "depthTexture")
      let bd3d = inputs.named("bd3D").unwrap()
      let distance = inputs.named("distance").unwrap()
      let shadow = shadow_filter_shadow(inputs)
      let radius = ReferenceNode::set_group(
        shadow_reference("radius", "float", shadow),
        render_group,
      )
      let map_size = ReferenceNode::set_group(
        shadow_reference("mapSize", "vec2", shadow),
        render_group,
      )
      let near = ReferenceNode::set_group(
        reference("near", "float", object=Object3D(shadow.camera)),
        render_group,
      )
      let far = ReferenceNode::set_group(
        reference("far", "float", object=Object3D(shadow.camera)),
        render_group,
      )
      let bias = ReferenceNode::set_group(
        shadow_reference("bias", "float", shadow),
        render_group,
      )
      let texel_size = radius.div(map_size.x()).to_const()
      let abs_dir = abs(bd3d)
      let tangent = normalize(
        cross(
          bd3d,
          abs_dir
          .x()
          .greater_than(abs_dir.z())
          .select(vec3_of([0, 1, 0]), else_node=vec3_of([1, 0, 0])),
        ),
      ).to_const()
      let bitangent = cross(bd3d, tangent).to_const()
      let phi = interleaved_gradient_noise
        .call([screen_coordinate.xy()])
        .mul(6.28318530718)
        .to_const()
      let get_depth = point_shadow_node_get_depth_fn(
        distance,
        near,
        far,
        bias,
        builder.renderer,
      )
      let result = float(0.0).to_var()
      loop_([5], fn(inputs) {
        let i = inputs.named("i").unwrap()
        let sample = vogel_disk_sample.call([i, 5, phi])
        let direction = bd3d
          .add(
            tangent
            .mul(sample.x())
            .add(bitangent.mul(sample.y()))
            .mul(texel_size),
          )
          .to_const()
        let abs_direction = abs(direction).to_const()
        let max_abs = max_of([
          abs_direction.x(),
          abs_direction.y(),
          abs_direction.z(),
        ]).to_const()
        result.add_assign(
          cube_texture(depth_texture, uv_node=direction).compare(
            get_depth(max_abs),
          ),
        )
      })
      Some(result.mul(1.0 / 5.0))
    })
  },
)

///|
/// `pointShadowFilter( { filterFn, depthTexture, shadowCoord, shadow } )`.
let point_shadow_node_filter : Node = module_nodes(
  "nodes/lighting/PointShadowNode.js:pointShadowFilter",
  fn() {
    fn_(fn(inputs, builder) {
      let filter_fn = inputs.named("filterFn").unwrap()
      let depth_texture = shadow_filter_texture(inputs, "depthTexture")
      let shadow_coord = inputs.named("shadowCoord").unwrap()
      let shadow = shadow_filter_shadow(inputs)
      let shadow_position = shadow_coord.xyz().to_const()
      let shadow_position_abs = shadow_position.abs().to_const()
      let view_z = shadow_position_abs
        .x()
        .max(shadow_position_abs.y())
        .max(shadow_position_abs.z())
      let shadow_camera_near = uniform("float")
        .set_group(render_group)
        .on_render_update(fn(n, _) {
          InputNode::set_value(
            n,
            Number(point_shadow_node_camera_near(shadow.camera)),
          )
          None
        })
      let shadow_camera_far = uniform("float")
        .set_group(render_group)
        .on_render_update(fn(n, _) {
          InputNode::set_value(
            n,
            Number(point_shadow_node_camera_far(shadow.camera)),
          )
          None
        })
      let bias = ReferenceNode::set_group(
        shadow_reference("bias", "float", shadow),
        render_group,
      )
      let result = float(1.0).to_var()
      if_(
        view_z
        .sub(shadow_camera_far)
        .less_than_equal(0.0)
        .and_(view_z.sub(shadow_camera_near).greater_than_equal(0.0)),
        fn() {
          let bd3d = shadow_position.normalize()
          let distance = shadow_position.length()
          let get_depth = point_shadow_node_get_depth_fn(
            distance,
            shadow_camera_near,
            shadow_camera_far,
            bias,
            builder.renderer,
          )
          let dp = get_depth(view_z.div(distance))
          result.assign(
            filter_fn.call([
              TslValue::Object({
                "depthTexture": Texture(depth_texture),
                "bd3D": Node(bd3d),
                "dp": Node(dp),
                "distance": Node(distance),
                "shadow": shadow_filter_shadow_value(shadow),
              }),
            ]),
          )
        },
      )
      |> ignore
      Some(result)
    })
  },
)

///|
pub(all) struct PointShadowNode {
  shadow_node : ShadowNode
}

///|
pub impl NodeClass for PointShadowNode with fn class_name(_) {
  "PointShadowNode"
}

///|
pub impl NodeClass for PointShadowNode with fn parent(self) {
  Some(self.shadow_node)
}

///|
pub impl ShadowNodeClass for PointShadowNode with fn shadow_parent(self) {
  Some(self.shadow_node)
}

///|
pub impl ShadowNodeClass for PointShadowNode with fn get_shadow_filter_fn(
  _,
  _,
  type_,
) {
  Some(
    if type_ == @core.BasicShadowMap {
      basic_point_shadow_filter
    } else {
      point_shadow_filter
    },
  )
}

///|
pub impl ShadowNodeClass for PointShadowNode with fn setup_shadow_coord(
  _,
  _,
  _,
  shadow_position,
) {
  shadow_position
}

///|
pub impl ShadowNodeClass for PointShadowNode with fn setup_shadow_filter(
  _,
  _,
  _,
  inputs,
) {
  point_shadow_node_filter.call([
    TslValue::Object({
      "filterFn": Node(inputs.filter_fn),
      "depthTexture": Texture(inputs.depth_texture),
      "shadowCoord": Node(inputs.shadow_coord),
      "shadow": shadow_filter_shadow_value(inputs.shadow),
    }),
  ])
}

///|
pub impl ShadowNodeClass for PointShadowNode with fn setup_render_target(
  _,
  _,
  shadow,
  builder,
) {
  let size = shadow.map_size.x.to_int()
  let depth_texture = @core.CubeDepthTexture::new(size~)
  depth_texture.name = "PointShadowDepthTexture"
  depth_texture.compare_function = Some(
    if builder.renderer.reversed_depth_buffer {
      @core.GreaterEqualCompare
    } else {
      @core.LessEqualCompare
    },
  )
  let shadow_map = builder.create_cube_render_target(size)
  shadow_map.texture().name = "PointShadowMap"
  shadow_map.set_depth_texture(Some(depth_texture))
  { shadow_map, depth_texture, }
}

///|
pub impl ShadowNodeClass for PointShadowNode with fn render_shadow(
  self,
  _,
  frame,
) {
  let shadow = self.shadow_node.shadow
  let shadow_map = self.shadow_node.shadow_map.unwrap()
  let light = self.shadow_node.base.light
  let renderer = frame.renderer.unwrap()
  let scene = frame.scene.unwrap()
  let camera = shadow.camera
  let shadow_matrix = shadow.matrix
  let is_webgpu = renderer.coordinate_system() == @core.WebGPUCoordinateSystem
  let cube_directions = if is_webgpu {
    point_shadow_node_cube_directions_webgpu
  } else {
    point_shadow_node_cube_directions_webgl
  }
  let cube_ups = if is_webgpu {
    point_shadow_node_cube_ups_webgpu
  } else {
    point_shadow_node_cube_ups_webgl
  }
  let size = shadow.map_size.x.to_int()
  shadow_map.set_size(size, size)
  let previous_auto_clear = renderer.auto_clear
  let previous_clear_color = renderer.get_clear_color(
    point_shadow_node_clear_color,
  )
  let previous_clear_alpha = renderer.get_clear_alpha()
  renderer.auto_clear = false
  // `setClearColor( shadow.clearColor, shadow.clearAlpha )`: both are undefined, so
  // the color is kept and the alpha defaults to 1.
  renderer.set_clear_color(previous_clear_color, alpha=1.0)
  for face in 0..<6 {
    renderer.set_render_target(Some(shadow_map), active_cube_face=face)
    renderer.clear()
    let distance = match light.as_light().kind {
      PointLight(point) => point.distance
      _ => 0.0
    }
    let far = if distance != 0.0 {
      distance
    } else {
      point_shadow_node_camera_far(camera)
    }
    if far != point_shadow_node_camera_far(camera) {
      point_shadow_node_set_camera_far(camera, far)
      camera.update_projection_matrix()
    }
    point_shadow_node_light_position_world.set_from_matrix_position(
      light.matrix_world,
    )
    |> ignore
    camera.position.copy(point_shadow_node_light_position_world) |> ignore
    point_shadow_node_look_target.copy(camera.position) |> ignore
    point_shadow_node_look_target.add(cube_directions[face]) |> ignore
    camera.up.copy(cube_ups[face]) |> ignore
    camera.look_at(point_shadow_node_look_target)
    camera.update_matrix_world()
    shadow_matrix.make_translation(
      -point_shadow_node_light_position_world.x,
      -point_shadow_node_light_position_world.y,
      -point_shadow_node_light_position_world.z,
    )
    |> ignore
    point_shadow_node_proj_screen_matrix.multiply_matrices(
      camera.as_camera().projection_matrix,
      camera.as_camera().matrix_world_inverse,
    )
    |> ignore
    shadow._frustum.set_from_projection_matrix(
      point_shadow_node_proj_screen_matrix,
      coordinate_system=camera.as_camera().coordinate_system,
      reversed_depth=camera.reversed_depth(),
    )
    |> ignore
    let current_scene_name = scene.name
    let light_label = if light.name != "" {
      light.name
    } else {
      "ID: " + light.id.to_string()
    }
    scene.name = "Point Light Shadow [ \{light_label} ] - Face \{face + 1}"
    renderer.render(scene, camera)
    scene.name = current_scene_name
  }
  renderer.auto_clear = previous_auto_clear
  renderer.set_clear_color(previous_clear_color, alpha=previous_clear_alpha)
}

///|
/// `new PointShadowNode( light, shadow = null )`.
pub fn PointShadowNode::new(
  light : @core.Object3D,
  shadow? : @core.LightShadow,
) -> Node {
  let node = Node::alloc()
  let payload = PointShadowNode::{
    shadow_node: ShadowNode::construct(node, light, shadow),
  }
  payload.shadow_node.class_ = payload
  node.set_class(payload)
}

///|
pub fn PointShadowNode::of(node : Node) -> PointShadowNode? {
  match node.class_payload("PointShadowNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `pointShadow( light, shadow )`.
pub fn point_shadow(
  light : @core.Object3D,
  shadow? : @core.LightShadow,
) -> Node {
  PointShadowNode::new(light, shadow?)
}

///|
/// `camera.near` of a perspective or orthographic camera.
fn point_shadow_node_camera_near(camera : @core.Object3D) -> Double {
  match camera.as_camera().kind {
    PerspectiveCamera(c) => c.near
    OrthographicCamera(c) => c.near
    BaseCamera => abort("PointShadowNode: the shadow camera has no near")
  }
}

///|
/// `camera.far` of a perspective or orthographic camera.
fn point_shadow_node_camera_far(camera : @core.Object3D) -> Double {
  match camera.as_camera().kind {
    PerspectiveCamera(c) => c.far
    OrthographicCamera(c) => c.far
    BaseCamera => abort("PointShadowNode: the shadow camera has no far")
  }
}

///|
/// `camera.far = far`.
fn point_shadow_node_set_camera_far(
  camera : @core.Object3D,
  far : Double,
) -> Unit {
  match camera.as_camera().kind {
    PerspectiveCamera(c) => c.far = far
    OrthographicCamera(c) => c.far = far
    BaseCamera => abort("PointShadowNode: the shadow camera has no far")
  }
}
