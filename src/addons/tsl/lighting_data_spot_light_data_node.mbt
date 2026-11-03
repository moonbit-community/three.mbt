// examples/jsm/tsl/lighting/data/SpotLightDataNode.js

///|
let _spot_light_data_node_light_position : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _spot_light_data_node_target_position : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
extern "js" fn spot_light_data_node_math_cos(x : Double) -> Double = "Math.cos"

///|
fn spot_light_data_node_warn(message : String) -> Unit {
  println("THREE.SpotLightDataNode: \{message}")
}

///|
/// Batched data node for simple spot lights in dynamic lighting mode.
pub(all) struct SpotLightDataNode {
  max_count : Int32
  mut _lights : Array[@core.Object3D]
  _colors : Array[@math.Color]
  _positions_and_cutoff : Array[@math.Vector4]
  _directions_and_decay : Array[@math.Vector4]
  _cones : Array[@math.Vector4]
  mut colors_node : @nodes.Node
  mut positions_and_cutoff_node : @nodes.Node
  mut directions_and_decay_node : @nodes.Node
  mut cones_node : @nodes.Node
  mut count_node : @nodes.Node
}

///|
pub impl @nodes.NodeClass for SpotLightDataNode with fn class_name(_) {
  "SpotLightDataNode"
}

///|
pub impl @nodes.NodeClass for SpotLightDataNode with fn children(self, _, out) {
  @nodes.push_child(out, "colorsNode", Some(self.colors_node))
  @nodes.push_child(
    out,
    "positionsAndCutoffNode",
    Some(self.positions_and_cutoff_node),
  )
  @nodes.push_child(
    out,
    "directionsAndDecayNode",
    Some(self.directions_and_decay_node),
  )
  @nodes.push_child(out, "conesNode", Some(self.cones_node))
  @nodes.push_child(out, "countNode", Some(self.count_node))
}

///|
pub impl @nodes.NodeClass for SpotLightDataNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl @nodes.NodeClass for SpotLightDataNode with fn update(self, _, frame) {
  let camera = frame.camera.unwrap()
  let view_matrix = camera.as_camera().matrix_world_inverse
  let count = if self._lights.length() < self.max_count {
    self._lights.length()
  } else {
    self.max_count
  }
  @nodes.InputNode::set_value(self.count_node, Number(count.to_double()))
  for i in 0..<count {
    let light = self._lights[i]
    let data = light.as_light()
    guard data.kind is SpotLight(spot) else {
      abort("SpotLightDataNode: not a SpotLight")
    }
    self._colors[i].copy(data.color).multiply_scalar(data.intensity) |> ignore
    _spot_light_data_node_light_position.set_from_matrix_position(
      light.matrix_world,
    )
    |> ignore
    _spot_light_data_node_light_position.apply_matrix4(view_matrix) |> ignore
    let position_and_cutoff = self._positions_and_cutoff[i]
    position_and_cutoff.x = _spot_light_data_node_light_position.x
    position_and_cutoff.y = _spot_light_data_node_light_position.y
    position_and_cutoff.z = _spot_light_data_node_light_position.z
    position_and_cutoff.w = spot.distance
    _spot_light_data_node_light_position.set_from_matrix_position(
      light.matrix_world,
    )
    |> ignore
    _spot_light_data_node_target_position.set_from_matrix_position(
      spot.target.matrix_world,
    )
    |> ignore
    _spot_light_data_node_light_position
    .sub(_spot_light_data_node_target_position)
    .transform_direction(view_matrix)
    |> ignore
    let direction_and_decay = self._directions_and_decay[i]
    direction_and_decay.x = _spot_light_data_node_light_position.x
    direction_and_decay.y = _spot_light_data_node_light_position.y
    direction_and_decay.z = _spot_light_data_node_light_position.z
    direction_and_decay.w = spot.decay
    let cone = self._cones[i]
    cone.x = spot_light_data_node_math_cos(spot.angle)
    cone.y = spot_light_data_node_math_cos(spot.angle * (1.0 - spot.penumbra))
  }
  None
}

///|
pub impl @nodes.NodeClass for SpotLightDataNode with fn setup(self, _, builder) {
  let surface_position = match builder.context.get_node("positionView") {
    Some(p) => p
    None => @nodes.position_view
  }
  let lighting_model = @nodes.NodeContext::lighting_model(builder.context).unwrap()
  let reflected_light = @nodes.NodeContext::reflected_light(builder.context).unwrap()
  let dyn_diffuse = @nodes.vec3(0).to_var(name="dynSpotDiffuse")
  let dyn_specular = @nodes.vec3(0).to_var(name="dynSpotSpecular")
  @nodes.loop_([self.count_node], fn(inputs) {
    let i = inputs.named("i").unwrap()
    let position_and_cutoff = self.positions_and_cutoff_node.element(i)
    let light_view_position = position_and_cutoff.xyz()
    let cutoff_distance = position_and_cutoff.w()
    let direction_and_decay = self.directions_and_decay_node.element(i)
    let spot_direction = direction_and_decay.xyz()
    let decay_exponent = direction_and_decay.w()
    let cone = self.cones_node.element(i)
    let cone_cos = cone.x()
    let penumbra_cos = cone.y()
    let light_vector = light_view_position.sub(surface_position).to_var()
    let light_direction = light_vector.normalize().to_var()
    let light_distance = light_vector.length()
    let angle_cos = light_direction.dot(spot_direction)
    let spot_attenuation = @nodes.smoothstep(cone_cos, penumbra_cos, angle_cos)
    let distance_attenuation = @nodes.get_distance_attenuation.call_named({
      "lightDistance": light_distance,
      "cutoffDistance": cutoff_distance,
      "decayExponent": decay_exponent,
    })
    let light_color = self.colors_node
      .element(i)
      .mul(spot_attenuation)
      .mul(distance_attenuation)
      .to_var()
    lighting_model.direct(
      lighting_data_light_data(
        light_direction, light_color, reflected_light, dyn_diffuse, dyn_specular,
      ),
      builder,
    )
  })
  reflected_light.direct_diffuse.add_assign(dyn_diffuse)
  reflected_light.direct_specular.add_assign(dyn_specular)
  None
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn SpotLightDataNode::construct(
  node : @nodes.Node,
  max_count : Int32,
) -> SpotLightDataNode {
  let _colors = []
  let _positions_and_cutoff = []
  let _directions_and_decay = []
  let _cones = []
  for _ in 0..<max_count {
    _colors.push(@math.Color::new(1.0, 1.0, 1.0))
    _positions_and_cutoff.push(@math.Vector4::new(0.0, 0.0, 0.0, 1.0))
    _directions_and_decay.push(@math.Vector4::new(0.0, 0.0, 0.0, 1.0))
    _cones.push(@math.Vector4::new(0.0, 0.0, 0.0, 1.0))
  }
  let colors_node = @nodes.uniform_array(_colors, element_type="color").set_group(
    @nodes.render_group,
  )
  let positions_and_cutoff_node = @nodes.uniform_array(
    _positions_and_cutoff,
    element_type="vec4",
  ).set_group(@nodes.render_group)
  let directions_and_decay_node = @nodes.uniform_array(
    _directions_and_decay,
    element_type="vec4",
  ).set_group(@nodes.render_group)
  let cones_node = @nodes.uniform_array(_cones, element_type="vec4").set_group(
    @nodes.render_group,
  )
  let count_node = @nodes.uniform(0, type_="int").set_group(@nodes.render_group)
  node.update_type = @nodes.NodeUpdateType::render()
  {
    max_count,
    _lights: [],
    _colors,
    _positions_and_cutoff,
    _directions_and_decay,
    _cones,
    colors_node,
    positions_and_cutoff_node,
    directions_and_decay_node,
    cones_node,
    count_node,
  }
}

///|
/// `new SpotLightDataNode( maxCount = 16 )`.
pub fn SpotLightDataNode::new(max_count~ : Int32 = 16) -> @nodes.Node {
  let node = @nodes.Node::alloc()
  node.set_class(SpotLightDataNode::construct(node, max_count))
}

///|
pub fn SpotLightDataNode::of(node : @nodes.Node) -> SpotLightDataNode? {
  addon_class_of(node, "SpotLightDataNode")
}

///|
/// `setLights( lights )`.
pub fn SpotLightDataNode::set_lights(
  node : @nodes.Node,
  lights : Array[@core.Object3D],
) -> @nodes.Node {
  let self = SpotLightDataNode::of(node).unwrap()
  if lights.length() > self.max_count {
    spot_light_data_node_warn(
      "\{lights.length()} lights exceed the configured max of \{self.max_count}. Excess lights are ignored.",
    )
  }
  self._lights = lights
  node
}
