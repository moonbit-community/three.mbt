// examples/jsm/tsl/lighting/DynamicLightsNode.js

///|
extern "js" fn dynamic_lights_node_js_compare(a : String, b : String) -> Int32 = "(a, b) => a < b ? -1 : a > b ? 1 : 0"

///|
let _dynamic_lights_node_hash_data : Array[Double] = []

///|
/// `_lightClassToType.get( light.constructor )`: the type name of the plain light
/// classes that can be batched (subclasses such as `IESSpotLight`, `ProjectorLight` or
/// add-on lights with an `Object3DExtension` have another constructor).
fn dynamic_lights_node_light_class_to_type(light : @core.Object3D) -> String? {
  if light.extension is Some(_) {
    return None
  }
  match light.kind {
    Light({ kind: AmbientLight, .. }) => Some("AmbientLight")
    Light({ kind: DirectionalLight(_), .. }) => Some("DirectionalLight")
    Light({ kind: PointLight(_), .. }) => Some("PointLight")
    Light({ kind: SpotLight({ variant: PlainSpotLight, .. }), .. }) =>
      Some("SpotLight")
    Light({ kind: HemisphereLight(_), .. }) => Some("HemisphereLight")
    _ => None
  }
}

///|
/// `new _lightTypeToDataNode[ typeName ]( maxCount )`, `maxCount` from
/// `_lightTypeToMaxProp` (none for ambient lights).
fn dynamic_lights_node_create_data_node(
  lights_node : DynamicLightsNode,
  type_name : String,
) -> @nodes.Node {
  match type_name {
    "AmbientLight" => AmbientLightDataNode::new()
    "DirectionalLight" =>
      DirectionalLightDataNode::new(
        max_count=lights_node.max_directional_lights,
      )
    "PointLight" =>
      PointLightDataNode::new(max_count=lights_node.max_point_lights)
    "SpotLight" => SpotLightDataNode::new(max_count=lights_node.max_spot_lights)
    "HemisphereLight" =>
      HemisphereLightDataNode::new(max_count=lights_node.max_hemisphere_lights)
    _ => abort("DynamicLightsNode: unknown light type \{type_name}")
  }
}

///|
/// `dataNode.setLights( lights )`.
fn dynamic_lights_node_data_set_lights(
  data_node : @nodes.Node,
  lights : Array[@core.Object3D],
) -> Unit {
  if AmbientLightDataNode::of(data_node) is Some(_) {
    AmbientLightDataNode::set_lights(data_node, lights) |> ignore
  } else if DirectionalLightDataNode::of(data_node) is Some(_) {
    DirectionalLightDataNode::set_lights(data_node, lights) |> ignore
  } else if PointLightDataNode::of(data_node) is Some(_) {
    PointLightDataNode::set_lights(data_node, lights) |> ignore
  } else if SpotLightDataNode::of(data_node) is Some(_) {
    SpotLightDataNode::set_lights(data_node, lights) |> ignore
  } else if HemisphereLightDataNode::of(data_node) is Some(_) {
    HemisphereLightDataNode::set_lights(data_node, lights) |> ignore
  }
}

///|
/// `isSpecialSpotLight( light )`.
fn dynamic_lights_node_is_special_spot_light(light : @core.Object3D) -> Bool {
  match light.kind {
    Light({ kind: SpotLight(spot), color_node, .. }) =>
      spot.map is Some(_) || color_node is Some(_)
    _ => false
  }
}

///|
/// `canBatchLight( light )` (lights are never nodes here).
fn dynamic_lights_node_can_batch_light(light : @core.Object3D) -> Bool {
  light.cast_shadow != true &&
  dynamic_lights_node_is_special_spot_light(light) == false &&
  dynamic_lights_node_light_class_to_type(light) is Some(_)
}

///|
/// A custom version of `LightsNode` that batches supported analytic lights into
/// uniform arrays and loops.
pub(all) struct DynamicLightsNode {
  lights : @nodes.LightsNode
  mut max_directional_lights : Int32
  mut max_point_lights : Int32
  mut max_spot_lights : Int32
  mut max_hemisphere_lights : Int32
  _builtin_lights : Array[@core.Object3D]
  _data_nodes : Map[String, @nodes.Node]
}

///|
pub impl @nodes.NodeClass for DynamicLightsNode with fn class_name(_) {
  "DynamicLightsNode"
}

///|
pub impl @nodes.NodeClass for DynamicLightsNode with fn parent(self) {
  Some(self.lights)
}

///|
pub impl @nodes.NodeClass for DynamicLightsNode with fn custom_cache_key(
  self,
  node,
) {
  _dynamic_lights_node_hash_data.push(
    @nodes.NodeClass::custom_cache_key(self.lights, node),
  )
  let type_names = self._data_nodes.keys().collect()
  // `Array.prototype.sort()`: UTF-16 code unit order
  type_names.sort_by(dynamic_lights_node_js_compare)
  for type_name in type_names {
    _dynamic_lights_node_hash_data.push(@nodes.hash_string(type_name))
  }
  let cache_key = @nodes.hash_array(_dynamic_lights_node_hash_data)
  _dynamic_lights_node_hash_data.clear()
  cache_key
}

///|
pub impl @nodes.LightsNodeClass for DynamicLightsNode with fn lights_parent(
  self,
) {
  Some(self.lights)
}

///|
pub impl @nodes.LightsNodeClass for DynamicLightsNode with fn setup_lights_node(
  self,
  node,
  builder,
) {
  let light_nodes = @nodes.LightsNodeClass::setup_lights_node(
    self.lights,
    node,
    builder,
  )
  for data_node in self._data_nodes.values() {
    light_nodes.push(data_node)
  }
  light_nodes
}

///|
pub impl @nodes.LightsNodeClass for DynamicLightsNode with fn set_lights(
  self,
  node,
  lights,
) {
  let builtin_lights = self._builtin_lights
  let lights_by_type : Map[String, Array[@core.Object3D]] = Map([])
  builtin_lights.clear()
  for light in lights {
    if dynamic_lights_node_can_batch_light(light) == false {
      builtin_lights.push(light)
      continue
    }
    let type_name = dynamic_lights_node_light_class_to_type(light).unwrap()
    match lights_by_type.get(type_name) {
      None => lights_by_type.set(type_name, [light])
      Some(type_lights) => type_lights.push(light)
    }
  }
  for type_name in lights_by_type.keys() {
    if self._data_nodes.contains(type_name) == false {
      self._data_nodes.set(
        type_name,
        dynamic_lights_node_create_data_node(self, type_name),
      )
    }
  }
  for type_name, data_node in self._data_nodes {
    dynamic_lights_node_data_set_lights(
      data_node,
      lights_by_type.get(type_name).unwrap_or([]),
    )
  }
  @nodes.LightsNodeClass::set_lights(self.lights, node, lights)
}

///|
pub impl @nodes.LightsNodeClass for DynamicLightsNode with fn get_builtin_lights(
  self,
  _,
) {
  self._builtin_lights
}

///|
pub impl @nodes.LightsNodeClass for DynamicLightsNode with fn has_lights(
  self,
  node,
) {
  @nodes.LightsNodeClass::has_lights(self.lights, node) ||
  self._data_nodes.length() > 0
}

///|
/// The constructor body: `super()` (LightsNode) runs first.
pub fn DynamicLightsNode::construct(
  node : @nodes.Node,
  max_directional_lights : Int32,
  max_point_lights : Int32,
  max_spot_lights : Int32,
  max_hemisphere_lights : Int32,
) -> DynamicLightsNode {
  let lights = @nodes.LightsNode::construct(node)
  {
    lights,
    max_directional_lights,
    max_point_lights,
    max_spot_lights,
    max_hemisphere_lights,
    _builtin_lights: [],
    _data_nodes: Map([]),
  }
}

///|
/// `new DynamicLightsNode( options )`, with the options as labelled arguments.
pub fn DynamicLightsNode::new(
  max_directional_lights~ : Int32 = 8,
  max_point_lights~ : Int32 = 16,
  max_spot_lights~ : Int32 = 16,
  max_hemisphere_lights~ : Int32 = 4,
) -> @nodes.Node {
  let node = @nodes.Node::alloc(node_type="vec3")
  let payload = DynamicLightsNode::construct(
    node, max_directional_lights, max_point_lights, max_spot_lights, max_hemisphere_lights,
  )
  payload.lights.class_ = payload
  node.set_class(payload)
}

///|
pub fn DynamicLightsNode::of(node : @nodes.Node) -> DynamicLightsNode? {
  addon_class_of(node, "DynamicLightsNode")
}

///|
/// The batched data node of a light type (`_dataNodes.get( typeName )`).
pub fn DynamicLightsNode::data_node(
  node : @nodes.Node,
  type_name : String,
) -> @nodes.Node? {
  DynamicLightsNode::of(node).unwrap()._data_nodes.get(type_name)
}

///|
/// `dynamicLights( options = {} )`.
pub fn dynamic_lights(
  max_directional_lights~ : Int32 = 8,
  max_point_lights~ : Int32 = 16,
  max_spot_lights~ : Int32 = 16,
  max_hemisphere_lights~ : Int32 = 4,
) -> @nodes.Node {
  DynamicLightsNode::new(
    max_directional_lights~,
    max_point_lights~,
    max_spot_lights~,
    max_hemisphere_lights~,
  )
}
