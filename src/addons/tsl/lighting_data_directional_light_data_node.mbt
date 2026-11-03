// examples/jsm/tsl/lighting/data/DirectionalLightDataNode.js

///|
let _directional_light_data_node_light_position : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _directional_light_data_node_target_position : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
fn directional_light_data_node_warn(message : String) -> Unit {
  println("THREE.DirectionalLightDataNode: \{message}")
}

///|
/// Batched data node for directional lights in dynamic lighting mode.
pub(all) struct DirectionalLightDataNode {
  max_count : Int32
  mut _lights : Array[@core.Object3D]
  _colors : Array[@math.Color]
  _directions : Array[@math.Vector3]
  mut colors_node : @nodes.Node
  mut directions_node : @nodes.Node
  mut count_node : @nodes.Node
}

///|
pub impl @nodes.NodeClass for DirectionalLightDataNode with fn class_name(_) {
  "DirectionalLightDataNode"
}

///|
pub impl @nodes.NodeClass for DirectionalLightDataNode with fn children(
  self,
  _,
  out,
) {
  @nodes.push_child(out, "colorsNode", Some(self.colors_node))
  @nodes.push_child(out, "directionsNode", Some(self.directions_node))
  @nodes.push_child(out, "countNode", Some(self.count_node))
}

///|
pub impl @nodes.NodeClass for DirectionalLightDataNode with fn is_cacheable(
  _,
  _,
  _,
) {
  false
}

///|
pub impl @nodes.NodeClass for DirectionalLightDataNode with fn update(
  self,
  _,
  frame,
) {
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
    self._colors[i].copy(data.color).multiply_scalar(data.intensity) |> ignore
    _directional_light_data_node_light_position.set_from_matrix_position(
      light.matrix_world,
    )
    |> ignore
    _directional_light_data_node_target_position.set_from_matrix_position(
      light.light_target().matrix_world,
    )
    |> ignore
    self._directions[i]
    .sub_vectors(
      _directional_light_data_node_light_position, _directional_light_data_node_target_position,
    )
    .transform_direction(camera.as_camera().matrix_world_inverse)
    |> ignore
  }
  None
}

///|
pub impl @nodes.NodeClass for DirectionalLightDataNode with fn setup(
  self,
  _,
  builder,
) {
  let lighting_model = @nodes.NodeContext::lighting_model(builder.context).unwrap()
  let reflected_light = @nodes.NodeContext::reflected_light(builder.context).unwrap()
  let dyn_diffuse = @nodes.vec3(0).to_var(name="dynDirectionalDiffuse")
  let dyn_specular = @nodes.vec3(0).to_var(name="dynDirectionalSpecular")
  @nodes.loop_([self.count_node], fn(inputs) {
    let i = inputs.named("i").unwrap()
    let light_color = self.colors_node.element(i).to_var()
    let light_direction = self.directions_node.element(i).normalize().to_var()
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
/// The light data the batched data nodes pass to `lightingModel.direct()`:
/// `{ lightDirection, lightColor, lightNode: { light: {}, shadowNode: null },
/// reflectedLight: { directDiffuse, directSpecular } }`. The stand-in light node is
/// `None` (the lighting models of the standard materials do not read it), and the
/// indirect slots of the reflected light are the context's (only `direct*` are read).
fn lighting_data_light_data(
  light_direction : @nodes.Node,
  light_color : @nodes.Node,
  context_reflected_light : @nodes.ReflectedLight,
  direct_diffuse : @nodes.Node,
  direct_specular : @nodes.Node,
) -> @core.JsValue {
  let data = @nodes.LightData::direct(light_direction, light_color)
  data.reflected_light = Some({
    direct_diffuse,
    direct_specular,
    indirect_diffuse: context_reflected_light.indirect_diffuse,
    indirect_specular: context_reflected_light.indirect_specular,
  })
  @core.JsValue::of(data)
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn DirectionalLightDataNode::construct(
  node : @nodes.Node,
  max_count : Int32,
) -> DirectionalLightDataNode {
  let _colors = []
  let _directions = []
  for _ in 0..<max_count {
    _colors.push(@math.Color::new(1.0, 1.0, 1.0))
    _directions.push(@math.Vector3::new(0.0, 0.0, 0.0))
  }
  let colors_node = @nodes.uniform_array(_colors, element_type="color").set_group(
    @nodes.render_group,
  )
  let directions_node = @nodes.uniform_array(_directions, element_type="vec3").set_group(
    @nodes.render_group,
  )
  let count_node = @nodes.uniform(0, type_="int").set_group(@nodes.render_group)
  node.update_type = @nodes.NodeUpdateType::render()
  {
    max_count,
    _lights: [],
    _colors,
    _directions,
    colors_node,
    directions_node,
    count_node,
  }
}

///|
/// `new DirectionalLightDataNode( maxCount = 8 )`.
pub fn DirectionalLightDataNode::new(max_count~ : Int32 = 8) -> @nodes.Node {
  let node = @nodes.Node::alloc()
  node.set_class(DirectionalLightDataNode::construct(node, max_count))
}

///|
pub fn DirectionalLightDataNode::of(
  node : @nodes.Node,
) -> DirectionalLightDataNode? {
  addon_class_of(node, "DirectionalLightDataNode")
}

///|
/// `setLights( lights )`.
pub fn DirectionalLightDataNode::set_lights(
  node : @nodes.Node,
  lights : Array[@core.Object3D],
) -> @nodes.Node {
  let self = DirectionalLightDataNode::of(node).unwrap()
  if lights.length() > self.max_count {
    directional_light_data_node_warn(
      "\{lights.length()} lights exceed the configured max of \{self.max_count}. Excess lights are ignored.",
    )
  }
  self._lights = lights
  node
}
