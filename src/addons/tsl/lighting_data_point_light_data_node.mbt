// examples/jsm/tsl/lighting/data/PointLightDataNode.js

///|
let _point_light_data_node_position : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
fn point_light_data_node_warn(message : String) -> Unit {
  println("THREE.PointLightDataNode: \{message}")
}

///|
/// Batched data node for point lights in dynamic lighting mode.
pub(all) struct PointLightDataNode {
  max_count : Int32
  mut _lights : Array[@core.Object3D]
  _colors : Array[@math.Color]
  _positions_and_cutoff : Array[@math.Vector4]
  _decays : Array[@math.Vector4]
  mut colors_node : @nodes.Node
  mut positions_and_cutoff_node : @nodes.Node
  mut decays_node : @nodes.Node
  mut count_node : @nodes.Node
}

///|
pub impl @nodes.NodeClass for PointLightDataNode with fn class_name(_) {
  "PointLightDataNode"
}

///|
pub impl @nodes.NodeClass for PointLightDataNode with fn children(self, _, out) {
  @nodes.push_child(out, "colorsNode", Some(self.colors_node))
  @nodes.push_child(
    out,
    "positionsAndCutoffNode",
    Some(self.positions_and_cutoff_node),
  )
  @nodes.push_child(out, "decaysNode", Some(self.decays_node))
  @nodes.push_child(out, "countNode", Some(self.count_node))
}

///|
pub impl @nodes.NodeClass for PointLightDataNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl @nodes.NodeClass for PointLightDataNode with fn update(self, _, frame) {
  let camera = frame.camera.unwrap()
  let count = if self._lights.length() < self.max_count {
    self._lights.length()
  } else {
    self.max_count
  }
  @nodes.InputNode::set_value(self.count_node, Number(count.to_double()))
  for i in 0..<count {
    let light = self._lights[i]
    let data = light.as_light()
    guard data.kind is PointLight(point) else {
      abort("PointLightDataNode: not a PointLight")
    }
    self._colors[i].copy(data.color).multiply_scalar(data.intensity) |> ignore
    _point_light_data_node_position.set_from_matrix_position(light.matrix_world)
    |> ignore
    _point_light_data_node_position.apply_matrix4(
      camera.as_camera().matrix_world_inverse,
    )
    |> ignore
    let position_and_cutoff = self._positions_and_cutoff[i]
    position_and_cutoff.x = _point_light_data_node_position.x
    position_and_cutoff.y = _point_light_data_node_position.y
    position_and_cutoff.z = _point_light_data_node_position.z
    position_and_cutoff.w = point.distance
    self._decays[i].x = point.decay
  }
  None
}

///|
pub impl @nodes.NodeClass for PointLightDataNode with fn setup(self, _, builder) {
  let surface_position = match builder.context.get_node("positionView") {
    Some(p) => p
    None => @nodes.position_view
  }
  let lighting_model = @nodes.NodeContext::lighting_model(builder.context).unwrap()
  let reflected_light = @nodes.NodeContext::reflected_light(builder.context).unwrap()
  let dyn_diffuse = @nodes.vec3(0).to_var(name="dynPointDiffuse")
  let dyn_specular = @nodes.vec3(0).to_var(name="dynPointSpecular")
  @nodes.loop_([self.count_node], fn(inputs) {
    let i = inputs.named("i").unwrap()
    let position_and_cutoff = self.positions_and_cutoff_node.element(i)
    let light_view_position = position_and_cutoff.xyz()
    let cutoff_distance = position_and_cutoff.w()
    let decay_exponent = self.decays_node.element(i).x()
    let light_vector = light_view_position.sub(surface_position).to_var()
    let light_direction = light_vector.normalize().to_var()
    let light_distance = light_vector.length()
    let attenuation = @nodes.get_distance_attenuation.call_named({
      "lightDistance": light_distance,
      "cutoffDistance": cutoff_distance,
      "decayExponent": decay_exponent,
    })
    let light_color = self.colors_node.element(i).mul(attenuation).to_var()
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
pub fn PointLightDataNode::construct(
  node : @nodes.Node,
  max_count : Int32,
) -> PointLightDataNode {
  let _colors = []
  let _positions_and_cutoff = []
  let _decays = []
  for _ in 0..<max_count {
    _colors.push(@math.Color::new(1.0, 1.0, 1.0))
    _positions_and_cutoff.push(@math.Vector4::new(0.0, 0.0, 0.0, 1.0))
    _decays.push(@math.Vector4::new(0.0, 0.0, 0.0, 1.0))
  }
  let colors_node = @nodes.uniform_array(_colors, element_type="color").set_group(
    @nodes.render_group,
  )
  let positions_and_cutoff_node = @nodes.uniform_array(
    _positions_and_cutoff,
    element_type="vec4",
  ).set_group(@nodes.render_group)
  let decays_node = @nodes.uniform_array(_decays, element_type="vec4").set_group(
    @nodes.render_group,
  )
  let count_node = @nodes.uniform(0, type_="int").set_group(@nodes.render_group)
  node.update_type = @nodes.NodeUpdateType::render()
  {
    max_count,
    _lights: [],
    _colors,
    _positions_and_cutoff,
    _decays,
    colors_node,
    positions_and_cutoff_node,
    decays_node,
    count_node,
  }
}

///|
/// `new PointLightDataNode( maxCount = 16 )`.
pub fn PointLightDataNode::new(max_count~ : Int32 = 16) -> @nodes.Node {
  let node = @nodes.Node::alloc()
  node.set_class(PointLightDataNode::construct(node, max_count))
}

///|
pub fn PointLightDataNode::of(node : @nodes.Node) -> PointLightDataNode? {
  addon_class_of(node, "PointLightDataNode")
}

///|
/// `setLights( lights )`.
pub fn PointLightDataNode::set_lights(
  node : @nodes.Node,
  lights : Array[@core.Object3D],
) -> @nodes.Node {
  let self = PointLightDataNode::of(node).unwrap()
  if lights.length() > self.max_count {
    point_light_data_node_warn(
      "\{lights.length()} lights exceed the configured max of \{self.max_count}. Excess lights are ignored.",
    )
  }
  self._lights = lights
  node
}
