// examples/jsm/tsl/lighting/data/HemisphereLightDataNode.js

///|
fn hemisphere_light_data_node_warn(message : String) -> Unit {
  println("THREE.HemisphereLightDataNode: \{message}")
}

///|
/// Batched data node for hemisphere lights in dynamic lighting mode.
pub(all) struct HemisphereLightDataNode {
  max_count : Int32
  mut _lights : Array[@core.Object3D]
  _sky_colors : Array[@math.Color]
  _ground_colors : Array[@math.Color]
  _directions : Array[@math.Vector3]
  mut sky_colors_node : @nodes.Node
  mut ground_colors_node : @nodes.Node
  mut directions_node : @nodes.Node
  mut count_node : @nodes.Node
}

///|
pub impl @nodes.NodeClass for HemisphereLightDataNode with fn class_name(_) {
  "HemisphereLightDataNode"
}

///|
pub impl @nodes.NodeClass for HemisphereLightDataNode with fn children(
  self,
  _,
  out,
) {
  @nodes.push_child(out, "skyColorsNode", Some(self.sky_colors_node))
  @nodes.push_child(out, "groundColorsNode", Some(self.ground_colors_node))
  @nodes.push_child(out, "directionsNode", Some(self.directions_node))
  @nodes.push_child(out, "countNode", Some(self.count_node))
}

///|
pub impl @nodes.NodeClass for HemisphereLightDataNode with fn is_cacheable(
  _,
  _,
  _,
) {
  false
}

///|
pub impl @nodes.NodeClass for HemisphereLightDataNode with fn update(self, _, _) {
  let count = if self._lights.length() < self.max_count {
    self._lights.length()
  } else {
    self.max_count
  }
  @nodes.InputNode::set_value(self.count_node, Number(count.to_double()))
  for i in 0..<count {
    let light = self._lights[i]
    let data = light.as_light()
    self._sky_colors[i].copy(data.color).multiply_scalar(data.intensity)
    |> ignore
    guard data.kind is HemisphereLight(hemisphere) else {
      abort("HemisphereLightDataNode: not a HemisphereLight")
    }
    self._ground_colors[i]
    .copy(hemisphere.ground_color)
    .multiply_scalar(data.intensity)
    |> ignore
    self._directions[i].set_from_matrix_position(light.matrix_world).normalize()
    |> ignore
  }
  None
}

///|
pub impl @nodes.NodeClass for HemisphereLightDataNode with fn setup(
  self,
  _,
  builder,
) {
  @nodes.loop_([self.count_node], fn(inputs) {
    let i = inputs.named("i").unwrap()
    let sky_color = self.sky_colors_node.element(i)
    let ground_color = self.ground_colors_node.element(i)
    let light_direction = self.directions_node.element(i)
    let hemi_diffuse_weight = @nodes.normal_world
      .dot(light_direction)
      .mul(0.5)
      .add(0.5)
    let irradiance = @nodes.mix(ground_color, sky_color, hemi_diffuse_weight)
    builder.context.get_node("irradiance").unwrap().add_assign(irradiance)
  })
  None
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn HemisphereLightDataNode::construct(
  node : @nodes.Node,
  max_count : Int32,
) -> HemisphereLightDataNode {
  let _sky_colors = []
  let _ground_colors = []
  let _directions = []
  for _ in 0..<max_count {
    _sky_colors.push(@math.Color::new(1.0, 1.0, 1.0))
    _ground_colors.push(@math.Color::new(1.0, 1.0, 1.0))
    _directions.push(@math.Vector3::new(0.0, 0.0, 0.0))
  }
  let sky_colors_node = @nodes.uniform_array(_sky_colors, element_type="color").set_group(
    @nodes.render_group,
  )
  let ground_colors_node = @nodes.uniform_array(
    _ground_colors,
    element_type="color",
  ).set_group(@nodes.render_group)
  let directions_node = @nodes.uniform_array(_directions, element_type="vec3").set_group(
    @nodes.render_group,
  )
  let count_node = @nodes.uniform(0, type_="int").set_group(@nodes.render_group)
  node.update_type = @nodes.NodeUpdateType::render()
  {
    max_count,
    _lights: [],
    _sky_colors,
    _ground_colors,
    _directions,
    sky_colors_node,
    ground_colors_node,
    directions_node,
    count_node,
  }
}

///|
/// `new HemisphereLightDataNode( maxCount = 4 )`.
pub fn HemisphereLightDataNode::new(max_count~ : Int32 = 4) -> @nodes.Node {
  let node = @nodes.Node::alloc()
  node.set_class(HemisphereLightDataNode::construct(node, max_count))
}

///|
pub fn HemisphereLightDataNode::of(
  node : @nodes.Node,
) -> HemisphereLightDataNode? {
  addon_class_of(node, "HemisphereLightDataNode")
}

///|
/// `setLights( lights )`.
pub fn HemisphereLightDataNode::set_lights(
  node : @nodes.Node,
  lights : Array[@core.Object3D],
) -> @nodes.Node {
  let self = HemisphereLightDataNode::of(node).unwrap()
  if lights.length() > self.max_count {
    hemisphere_light_data_node_warn(
      "\{lights.length()} lights exceed the configured max of \{self.max_count}. Excess lights are ignored.",
    )
  }
  self._lights = lights
  node
}
