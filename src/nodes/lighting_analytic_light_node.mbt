// nodes/lighting/AnalyticLightNode.js: the base of the light nodes for analytic lights.
// `setupDirect`, `setupDirectRectArea`, `setupShadowNode`, `setupShadow` and
// `getLightVector` are virtual and dispatch through `AnalyticLightNodeClass`.

///|
/// What `setupDirect` / `setupDirectRectArea` return and `LightingModel.direct` /
/// `directRectArea` receive (`{ ...lightData, lightNode, reflectedLight }`). `None` is
/// `undefined`. Passed to the lighting model as `JsValue::of(data)`.
pub(all) struct LightData {
  mut light_direction : Node?
  mut light_color : Node?
  mut light_position : Node?
  mut half_width : Node?
  mut half_height : Node?
  mut ltc_1 : Node?
  mut ltc_2 : Node?
  mut light_node : Node?
  mut reflected_light : ReflectedLight?
}

///|
/// `{ lightDirection, lightColor }`.
pub fn LightData::direct(
  light_direction : Node,
  light_color : Node,
) -> LightData {
  {
    light_direction: Some(light_direction),
    light_color: Some(light_color),
    light_position: None,
    half_width: None,
    half_height: None,
    ltc_1: None,
    ltc_2: None,
    light_node: None,
    reflected_light: None,
  }
}

///|
/// The light data a lighting model method receives as a JS value.
pub fn LightData::from_js(value : @core.JsValue) -> LightData {
  value.cast()
}

///|
/// `{ ...lightData }`.
pub fn LightData::copy(self : LightData) -> LightData {
  { ..self, }
}

///|
/// The virtual methods of the `AnalyticLightNode` family; defaults walk to the parent.
pub(open) trait AnalyticLightNodeClass {
  /// The superclass payload in the family, `None` for `AnalyticLightNode`.
  fn analytic_parent(Self) -> &AnalyticLightNodeClass? = _
  /// `setupDirect( builder )`.
  fn setup_direct(Self, Node, NodeBuilder) -> LightData? = _
  /// `setupDirectRectArea( builder )`.
  fn setup_direct_rect_area(Self, Node, NodeBuilder) -> LightData? = _
  /// `setupShadowNode()`.
  fn setup_shadow_node(Self, Node) -> Node = _
  /// `setupShadow( builder )`.
  fn setup_shadow(Self, Node, NodeBuilder) -> Unit = _
  /// `getLightVector( builder )`.
  fn get_light_vector(Self, Node, NodeBuilder) -> Node = _
}

///|
impl AnalyticLightNodeClass with fn analytic_parent(_) {
  None
}

///|
impl AnalyticLightNodeClass with fn setup_direct(self, node, builder) {
  match self.analytic_parent() {
    Some(p) => p.setup_direct(node, builder)
    None => None
  }
}

///|
impl AnalyticLightNodeClass with fn setup_direct_rect_area(self, node, builder) {
  match self.analytic_parent() {
    Some(p) => p.setup_direct_rect_area(node, builder)
    None => None
  }
}

///|
impl AnalyticLightNodeClass with fn setup_shadow_node(self, node) {
  match self.analytic_parent() {
    Some(p) => p.setup_shadow_node(node)
    None => AnalyticLightNode::setup_shadow_node_base(node)
  }
}

///|
impl AnalyticLightNodeClass with fn setup_shadow(self, node, builder) {
  match self.analytic_parent() {
    Some(p) => p.setup_shadow(node, builder)
    None => AnalyticLightNode::setup_shadow_base(node, builder)
  }
}

///|
impl AnalyticLightNodeClass with fn get_light_vector(self, node, builder) {
  match self.analytic_parent() {
    Some(p) => p.get_light_vector(node, builder)
    None => AnalyticLightNode::get_light_vector_base(node, builder)
  }
}

///|
/// A placeholder until construction installs the most derived payload.
priv struct AnalyticLightNodeUnset {}

///|
impl AnalyticLightNodeClass for AnalyticLightNodeUnset

///|
pub(all) struct AnalyticLightNode {
  lighting : LightingNode
  mut light : @core.Object3D?
  /// `color`, the value of the default `colorNode` uniform.
  color : @math.Color
  mut color_node : Node?
  mut base_color_node : Node?
  mut shadow_node : Node?
  mut shadow_color_node : Node?
  mut _shadow_dispose_listener : ((@core.Event) -> Unit)?
  /// The most derived payload of the family, set at the end of construction.
  mut class_ : &AnalyticLightNodeClass
}

///|
pub impl AnalyticLightNodeClass for AnalyticLightNode

///|
pub impl NodeClass for AnalyticLightNode with fn class_name(_) {
  "AnalyticLightNode"
}

///|
pub impl NodeClass for AnalyticLightNode with fn parent(self) {
  Some(self.lighting)
}

///|
pub impl NodeClass for AnalyticLightNode with fn has_flag(self, flag) {
  flag == "isAnalyticLightNode" || NodeClass::has_flag(self.lighting, flag)
}

///|
pub impl NodeClass for AnalyticLightNode with fn children(self, node, out) {
  NodeClass::children(self.lighting, node, out)
  push_child(out, "colorNode", self.color_node)
  push_child(out, "baseColorNode", self.base_color_node)
  push_child(out, "shadowNode", self.shadow_node)
  push_child(out, "shadowColorNode", self.shadow_color_node)
}

///|
pub impl NodeClass for AnalyticLightNode with fn dispose(self, node) {
  if self._shadow_dispose_listener is Some(listener) {
    self.light.unwrap().remove_event_listener("dispose", listener)
  }
  NodeClass::dispose(self.lighting, node)
}

///|
pub impl NodeClass for AnalyticLightNode with fn get_hash(self, _, _) {
  self.light.unwrap().uuid
}

///|
pub impl NodeClass for AnalyticLightNode with fn setup(self, node, builder) {
  self.color_node = match self.base_color_node {
    Some(n) => Some(n)
    None => self.color_node
  }
  let light = self.light.unwrap()
  if light.cast_shadow {
    if builder.object is Object3D(object) && object.receive_shadow {
      self.class_.setup_shadow(node, builder)
    }
  } else if self.shadow_node is Some(_) {
    AnalyticLightNode::dispose_shadow(node)
  }
  let direct_light_data = self.class_.setup_direct(node, builder)
  let direct_rect_area_light_data = self.class_.setup_direct_rect_area(
    node, builder,
  )
  let lights_node = builder.lights_node.unwrap()
  if direct_light_data is Some(data) {
    LightsNode::setup_direct_light(lights_node, builder, node, data)
  }
  if direct_rect_area_light_data is Some(data) {
    LightsNode::setup_direct_rect_area_light(lights_node, builder, node, data)
  }
  None
}

///|
pub impl NodeClass for AnalyticLightNode with fn update(self, _, _) {
  let light = self.light.unwrap().as_light()
  self.color.copy(light.color).multiply_scalar(light.intensity) |> ignore
  None
}

///|
/// The constructor body: `super()` (LightingNode) has run in `Node::alloc`.
pub fn AnalyticLightNode::construct(
  node : Node,
  light : @core.Object3D?,
) -> AnalyticLightNode {
  let lighting = LightingNode::construct(node)
  let color = @math.Color::new(1.0, 1.0, 1.0)
  let light_color_node = match light {
    Some(l) =>
      match l.as_light().color_node {
        Some(v) => Some((v.cast() : Node))
        None => None
      }
    None => None
  }
  let color_node = match light_color_node {
    Some(n) => n
    None => uniform(color).set_group(render_group)
  }
  let payload : AnalyticLightNode = {
    lighting,
    light,
    color,
    color_node: Some(color_node),
    base_color_node: None,
    shadow_node: None,
    shadow_color_node: None,
    _shadow_dispose_listener: None,
    class_: AnalyticLightNodeUnset::{ },
  }
  node.update_type = NodeUpdateType::frame()
  if light is Some(l) && l.as_light().shadow is Some(_) {
    let listener = fn(_e : @core.Event) {
      AnalyticLightNode::dispose_shadow(node)
    }
    payload._shadow_dispose_listener = Some(listener)
    l.add_event_listener("dispose", listener)
  }
  payload
}

///|
/// Allocates a light node of a subclass (`super()` of LightingNode: `'vec3'`).
pub fn AnalyticLightNode::alloc() -> Node {
  Node::alloc(node_type="vec3")
}

///|
/// `new AnalyticLightNode( light = null )`.
pub fn AnalyticLightNode::new(light? : @core.Object3D) -> Node {
  let node = AnalyticLightNode::alloc()
  let payload = AnalyticLightNode::construct(node, light)
  payload.class_ = payload
  node.set_class(payload)
}

///|
pub fn AnalyticLightNode::of(node : Node) -> AnalyticLightNode? {
  match node.class_payload("AnalyticLightNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn AnalyticLightNode::payload_of(node : Node) -> AnalyticLightNode {
  match AnalyticLightNode::of(node) {
    Some(p) => p
    None => abort("TypeError: \{node.type_()} is not an AnalyticLightNode")
  }
}

///|
/// `disposeShadow()`: frees the shadow resources.
pub fn AnalyticLightNode::dispose_shadow(node : Node) -> Unit {
  let self = AnalyticLightNode::payload_of(node)
  guard self.shadow_node is Some(shadow_node) else { return }
  shadow_node.dispose()
  self.shadow_node = None
  self.shadow_color_node = None
  self.color_node = self.base_color_node
  self.base_color_node = None
  node.set_needs_update(true)
}

///|
/// `getLightVector( builder )`, dispatched.
pub fn AnalyticLightNode::get_light_vector(
  node : Node,
  builder : NodeBuilder,
) -> Node {
  AnalyticLightNode::payload_of(node).class_.get_light_vector(node, builder)
}

///|
/// `AnalyticLightNode.prototype.getLightVector`: from the position to the light, in
/// view space.
pub fn AnalyticLightNode::get_light_vector_base(
  node : Node,
  builder : NodeBuilder,
) -> Node {
  let self = AnalyticLightNode::payload_of(node)
  let position = match builder.context.get_node("positionView") {
    Some(p) => p
    None => position_view
  }
  light_view_position(self.light.unwrap()).sub(position)
}

///|
/// `AnalyticLightNode.prototype.setupShadowNode`.
pub fn AnalyticLightNode::setup_shadow_node_base(node : Node) -> Node {
  shadow(AnalyticLightNode::payload_of(node).light.unwrap())
}

///|
/// `AnalyticLightNode.prototype.setupShadow`: multiplies the light color by the
/// shadow, if shadow maps are enabled.
pub fn AnalyticLightNode::setup_shadow_base(
  node : Node,
  builder : NodeBuilder,
) -> Unit {
  let self = AnalyticLightNode::payload_of(node)
  let renderer = builder.renderer
  if renderer.shadow_map.enabled == false {
    return
  }
  let mut shadow_color_node = self.shadow_color_node
  if shadow_color_node is None {
    let custom_shadow_node = self.light.unwrap().as_light().shadow.unwrap().shadow_node
    let shadow_node = match custom_shadow_node {
      Some(v) => node_object(Node(v.cast()))
      None => self.class_.setup_shadow_node(node)
    }
    self.shadow_node = Some(shadow_node)
    let n = self.color_node.unwrap().mul(shadow_node)
    self.shadow_color_node = Some(n)
    shadow_color_node = Some(n)
    self.base_color_node = self.color_node
  }
  if builder.context.get_shadow() is Some(get_shadow) {
    shadow_color_node = Some((get_shadow.f)(node, builder))
  }
  self.color_node = shadow_color_node
}
