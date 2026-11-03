// nodes/lighting/LightsNode.js: the scene's lights, as light nodes, and how their
// contributions combine into `outgoingLight`.

///|
let lights_node_total_diffuse : Node = module_nodes(
  "nodes/lighting/LightsNode.js:totalDiffuse",
  fn() { property("vec3", name="totalDiffuse") },
)

///|
let lights_node_total_specular : Node = module_nodes(
  "nodes/lighting/LightsNode.js:totalSpecular",
  fn() { property("vec3", name="totalSpecular") },
)

///|
let lights_node_outgoing_light : Node = module_nodes(
  "nodes/lighting/LightsNode.js:outgoingLight",
  fn() { property("vec3", name="outgoingLight") },
)

///|
/// `light._lightNode`: what `Light.registerNode( lightNodeClass )` stores, as a JS value
/// (`@core.Light::register_node("PointLight", PointLightNode::node_class())`).
pub(all) struct LightNodeClass {
  /// `new lightNodeClass( light )`.
  create : (@core.Object3D) -> Node
}

///|
/// One entry of `[ ...materialLightings, ...builtinLights ]`: a node or a light.
priv enum LightsNodeEntry {
  LightNode(Node)
  Light(@core.Object3D)
}

///|
fn LightsNodeEntry::id(self : LightsNodeEntry) -> Int32 {
  match self {
    LightNode(n) => n.id
    Light(l) => l.id
  }
}

///|
/// `getLightNodeById( id, lightNodes )`.
fn lights_node_get_light_node_by_id(
  id : Int32,
  light_nodes : Array[Node],
) -> Node? {
  for light_node in light_nodes {
    if AnalyticLightNode::of(light_node) is Some(a) &&
      a.light is Some(light) &&
      light.id == id {
      return Some(light_node)
    }
  }
  None
}

///|
/// `_lightsNodeRef`: the light node of each light.
let lights_node_ref : @webgl.WeakMap[@core.Object3D, Node] = @webgl.WeakMap::new()

///|
/// `_hashData`.
let lights_node_hash_data : Array[Double] = []

///|
/// The virtual methods of the `LightsNode` family (add-on subclasses such as
/// `DynamicLightsNode` override them); defaults walk to the parent.
pub(open) trait LightsNodeClass {
  /// The superclass payload in the family, `None` for `LightsNode`.
  fn lights_parent(Self) -> &LightsNodeClass? = _
  /// `setupLightsNode( builder )`.
  fn setup_lights_node(Self, Node, NodeBuilder) -> Array[Node] = _
  /// `setupLights( builder, lightNodes )`.
  fn setup_lights(Self, Node, NodeBuilder, Array[Node]) -> Unit = _
  /// `setLights( lights )`.
  fn set_lights(Self, Node, Array[@core.Object3D]) -> Node = _
  /// `getBuiltinLights()`.
  fn get_builtin_lights(Self, Node) -> Array[@core.Object3D] = _
  /// `get hasLights()`.
  fn has_lights(Self, Node) -> Bool = _
}

///|
impl LightsNodeClass with fn lights_parent(_) {
  None
}

///|
impl LightsNodeClass with fn setup_lights_node(self, node, builder) {
  match self.lights_parent() {
    Some(p) => p.setup_lights_node(node, builder)
    None => LightsNode::setup_lights_node_base(node, builder)
  }
}

///|
impl LightsNodeClass with fn setup_lights(self, node, builder, light_nodes) {
  match self.lights_parent() {
    Some(p) => p.setup_lights(node, builder, light_nodes)
    None => LightsNode::setup_lights_base(node, builder, light_nodes)
  }
}

///|
impl LightsNodeClass with fn set_lights(self, node, lights) {
  match self.lights_parent() {
    Some(p) => p.set_lights(node, lights)
    None => LightsNode::set_lights_base(node, lights)
  }
}

///|
impl LightsNodeClass with fn get_builtin_lights(self, node) {
  match self.lights_parent() {
    Some(p) => p.get_builtin_lights(node)
    None => LightsNode::payload_of(node)._lights
  }
}

///|
impl LightsNodeClass with fn has_lights(self, node) {
  match self.lights_parent() {
    Some(p) => p.has_lights(node)
    None => LightsNode::payload_of(node)._lights.length() > 0
  }
}

///|
priv struct LightsNodeUnset {}

///|
impl LightsNodeClass for LightsNodeUnset

///|
pub(all) struct LightsNode {
  mut total_diffuse_node : Node
  mut total_specular_node : Node
  mut outgoing_light_node : Node
  mut _lights : Array[@core.Object3D]
  /// The most derived payload of the family, set at the end of construction.
  mut class_ : &LightsNodeClass
}

///|
pub impl LightsNodeClass for LightsNode

///|
pub impl NodeClass for LightsNode with fn class_name(_) {
  "LightsNode"
}

///|
pub impl NodeClass for LightsNode with fn children(self, _, out) {
  push_child(out, "totalDiffuseNode", Some(self.total_diffuse_node))
  push_child(out, "totalSpecularNode", Some(self.total_specular_node))
  push_child(out, "outgoingLightNode", Some(self.outgoing_light_node))
}

///|
pub impl NodeClass for LightsNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for LightsNode with fn custom_cache_key(self, node) {
  let builtin_lights = self.class_.get_builtin_lights(node)
  for light in builtin_lights {
    lights_node_hash_data.push(light.id.to_double())
    lights_node_hash_data.push(if light.cast_shadow { 1.0 } else { 0.0 })
    if light.cast_shadow {
      let light_version = match lights_node_ref.get(light) {
        Some(light_node) => light_node.version
        None => 0
      }
      lights_node_hash_data.push(light_version.to_double())
    }
    if light.as_light().kind is SpotLight(spot) {
      let hash_map = match spot.map {
        Some(map) => map.id.to_double()
        None => -1.0
      }
      let hash_color_node = match light.as_light().color_node {
        Some(v) => (v.cast() : Node).get_cache_key()
        None => -1.0
      }
      lights_node_hash_data.push(hash_map)
      lights_node_hash_data.push(hash_color_node)
    }
  }
  let cache_key = hash_array(lights_node_hash_data)
  lights_node_hash_data.clear()
  cache_key
}

///|
pub impl NodeClass for LightsNode with fn get_hash(_, node, builder) {
  let node_data = builder.get_data_from_node(node)
  match lights_node_data_hash(node_data) {
    Some(hash) => hash
    None => {
      let light_nodes = LightsNode::setup_lights_node(node, builder)
      lights_node_data_set_nodes(node_data, light_nodes)
      let hash = light_nodes.map(fn(n) { n.get_hash(builder) })
      let hash = "lights-" + hash.join(",")
      node_data.extra.set("lightNodesHash", @core.JsValue::of(hash))
      hash
    }
  }
}

///|
pub impl NodeClass for LightsNode with fn setup(self, node, builder) {
  let current_lights_node = builder.lights_node
  builder.lights_node = Some(node)
  let mut outgoing_light_node = self.outgoing_light_node
  let context = builder.context
  if NodeContext::lighting_model(context) is Some(lighting_model) {
    let total_diffuse_node = self.total_diffuse_node
    let total_specular_node = self.total_specular_node
    context.set("outgoingLight", Node(outgoing_light_node))
    builder.add_stack() |> ignore
    lighting_model.start(builder)
    let backdrop = context.get_node("backdrop")
    let backdrop_alpha = context.get_node("backdropAlpha")
    let reflected_light = NodeContext::reflected_light(context).unwrap()
    let mut total_diffuse = reflected_light.direct_diffuse.add(
      reflected_light.indirect_diffuse,
    )
    if backdrop is Some(backdrop) {
      total_diffuse = match backdrop_alpha {
        Some(backdrop_alpha) =>
          vec3(backdrop_alpha.mix(total_diffuse, backdrop))
        None => vec3(backdrop)
      }
    }
    total_diffuse_node.assign(total_diffuse)
    total_specular_node.assign(
      reflected_light.direct_specular.add(reflected_light.indirect_specular),
    )
    outgoing_light_node.assign(total_diffuse_node.add(total_specular_node))
    lighting_model.finish(builder)
    outgoing_light_node = outgoing_light_node.bypass(
      builder.remove_stack().node,
    )
  }
  builder.lights_node = current_lights_node
  Some(outgoing_light_node)
}

///|
fn lights_node_data_hash(data : NodeData) -> String? {
  match data.extra.get("lightNodesHash") {
    Some(v) => Some(v.cast())
    None => None
  }
}

///|
/// `nodeData.lightNodes`.
fn lights_node_data_nodes(data : NodeData) -> Array[Node]? {
  match data.extra.get("lightNodes") {
    Some(v) => Some(v.cast())
    None => None
  }
}

///|
fn lights_node_data_set_nodes(data : NodeData, nodes : Array[Node]) -> Unit {
  data.extra.set("lightNodes", @core.JsValue::of(nodes))
}

///|
pub fn LightsNode::construct(node : Node) -> LightsNode {
  node.global = true
  {
    total_diffuse_node: lights_node_total_diffuse,
    total_specular_node: lights_node_total_specular,
    outgoing_light_node: lights_node_outgoing_light,
    _lights: [],
    class_: LightsNodeUnset::{ },
  }
}

///|
/// `new LightsNode()`.
pub fn LightsNode::new() -> Node {
  let node = Node::alloc(node_type="vec3")
  let payload = LightsNode::construct(node)
  payload.class_ = payload
  node.set_class(payload)
}

///|
pub fn LightsNode::of(node : Node) -> LightsNode? {
  match node.class_payload("LightsNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn LightsNode::payload_of(node : Node) -> LightsNode {
  match LightsNode::of(node) {
    Some(p) => p
    None => abort("TypeError: \{node.type_()} is not a LightsNode")
  }
}

///|
/// `setupLightsNode( builder )`, dispatched.
pub fn LightsNode::setup_lights_node(
  node : Node,
  builder : NodeBuilder,
) -> Array[Node] {
  LightsNode::payload_of(node).class_.setup_lights_node(node, builder)
}

///|
/// `LightsNode.prototype.setupLightsNode`: a light node for each material lighting
/// and light, in id order, reusing the nodes of the previous build.
pub fn LightsNode::setup_lights_node_base(
  node : Node,
  builder : NodeBuilder,
) -> Array[Node] {
  let self = LightsNode::payload_of(node)
  let node_data = builder.get_data_from_node(node)
  let light_nodes = []
  let previous_light_nodes = lights_node_data_nodes(node_data)
  let material_lightings = match
    NodeContext::material_lightings(builder.context) {
    Some(m) => m
    None =>
      abort("TypeError: builder.context.materialLightings is not iterable")
  }
  let lights : Array[LightsNodeEntry] = []
  for n in material_lightings {
    lights.push(LightNode(n))
  }
  for l in self.class_.get_builtin_lights(node) {
    lights.push(Light(l))
  }
  @webgl.stable_sort_by(lights, fn(a, b) { (a.id() - b.id()).to_double() })
  for entry in lights {
    match entry {
      LightNode(n) => light_nodes.push(n)
      Light(light) => {
        let mut light_node = match previous_light_nodes {
          Some(previous) => lights_node_get_light_node_by_id(light.id, previous)
          None => None
        }
        if light_node is None {
          guard light.light_node() is Some(light_node_class) else {
            @core.warn(
              "LightsNode.setupNodeLights: Light node not found for \{light.type_}",
            )
            continue
          }
          if !lights_node_ref.has(light) {
            let light_node_class : LightNodeClass = light_node_class.cast()
            lights_node_ref.set(light, (light_node_class.create)(light))
          }
          light_node = lights_node_ref.get(light)
        }
        light_nodes.push(light_node.unwrap())
      }
    }
  }
  light_nodes
}

///|
/// `setupDirectLight( builder, lightNode, lightData )`.
pub fn LightsNode::setup_direct_light(
  _node : Node,
  builder : NodeBuilder,
  light_node : Node,
  light_data : LightData,
) -> Unit {
  let lighting_model = NodeContext::lighting_model(builder.context).unwrap()
  let data = light_data.copy()
  data.light_node = Some(light_node)
  data.reflected_light = NodeContext::reflected_light(builder.context)
  lighting_model.direct(@core.JsValue::of(data), builder)
}

///|
/// `setupDirectRectAreaLight( builder, lightNode, lightData )`.
pub fn LightsNode::setup_direct_rect_area_light(
  _node : Node,
  builder : NodeBuilder,
  light_node : Node,
  light_data : LightData,
) -> Unit {
  let lighting_model = NodeContext::lighting_model(builder.context).unwrap()
  let data = light_data.copy()
  data.light_node = Some(light_node)
  data.reflected_light = NodeContext::reflected_light(builder.context)
  lighting_model.direct_rect_area(@core.JsValue::of(data), builder)
}

///|
/// `lightsNode.setupLights( builder, lightNodes )`, dispatched.
pub fn LightsNode::setup_lights(
  node : Node,
  builder : NodeBuilder,
  light_nodes : Array[Node],
) -> Unit {
  LightsNode::payload_of(node).class_.setup_lights(node, builder, light_nodes)
}

///|
/// `LightsNode.prototype.setupLights`.
pub fn LightsNode::setup_lights_base(
  _node : Node,
  builder : NodeBuilder,
  light_nodes : Array[Node],
) -> Unit {
  for light_node in light_nodes {
    light_node.build_node(builder) |> ignore
  }
  if builder.context.get_node("lightProbeIrradiance") is Some(irradiance) {
    builder.context.get_node("irradiance").unwrap().add_assign(irradiance)
  }
}

///|
/// `lightsNode.getLightNodes( builder )`.
pub fn LightsNode::get_light_nodes(
  node : Node,
  builder : NodeBuilder,
) -> Array[Node] {
  let node_data = builder.get_data_from_node(node)
  match lights_node_data_nodes(node_data) {
    Some(nodes) => nodes
    None => {
      let nodes = LightsNode::setup_lights_node(node, builder)
      lights_node_data_set_nodes(node_data, nodes)
      nodes
    }
  }
}

///|
/// `setLights( lights )`, dispatched.
pub fn LightsNode::set_lights(
  node : Node,
  lights : Array[@core.Object3D],
) -> Node {
  LightsNode::payload_of(node).class_.set_lights(node, lights)
}

///|
/// `LightsNode.prototype.setLights`.
pub fn LightsNode::set_lights_base(
  node : Node,
  lights : Array[@core.Object3D],
) -> Node {
  LightsNode::payload_of(node)._lights = lights
  node
}

///|
/// `getLights()`.
pub fn LightsNode::get_lights(node : Node) -> Array[@core.Object3D] {
  LightsNode::payload_of(node)._lights
}

///|
/// `getBuiltinLights()`, dispatched.
pub fn LightsNode::get_builtin_lights(node : Node) -> Array[@core.Object3D] {
  LightsNode::payload_of(node).class_.get_builtin_lights(node)
}

///|
/// `get hasLights()`, dispatched.
pub fn LightsNode::has_lights(node : Node) -> Bool {
  LightsNode::payload_of(node).class_.has_lights(node)
}

///|
/// `lights( lights = [] )`.
pub fn lights(lights~ : Array[@core.Object3D] = []) -> Node {
  LightsNode::set_lights(LightsNode::new(), lights)
}
