// nodes/lighting/SpotLightNode.js. `getSpotAttenuation`, overridden by IES and projector
// lights, dispatches through `SpotLightNodeClass`.

///|
extern "js" fn spot_light_node_cos(x : Double) -> Double = "Math.cos"

///|
/// The virtual methods of the `SpotLightNode` family.
pub(open) trait SpotLightNodeClass {
  /// The superclass payload in the family, `None` for `SpotLightNode`.
  fn spot_parent(Self) -> &SpotLightNodeClass? = _
  /// `getSpotAttenuation( builder, angleCosine )`.
  fn get_spot_attenuation(Self, Node, NodeBuilder, Node) -> Node = _
}

///|
impl SpotLightNodeClass with fn spot_parent(_) {
  None
}

///|
impl SpotLightNodeClass with fn get_spot_attenuation(
  self,
  node,
  builder,
  angle_cosine,
) {
  match self.spot_parent() {
    Some(p) => p.get_spot_attenuation(node, builder, angle_cosine)
    None =>
      SpotLightNode::get_spot_attenuation_base(node, builder, angle_cosine)
  }
}

///|
priv struct SpotLightNodeUnset {}

///|
impl SpotLightNodeClass for SpotLightNodeUnset

///|
pub(all) struct SpotLightNode {
  analytic : AnalyticLightNode
  cone_cos_node : Node
  penumbra_cos_node : Node
  cutoff_distance_node : Node
  decay_exponent_node : Node
  /// The most derived payload of the family.
  mut spot_class : &SpotLightNodeClass
}

///|
pub impl SpotLightNodeClass for SpotLightNode

///|
pub impl NodeClass for SpotLightNode with fn class_name(_) {
  "SpotLightNode"
}

///|
pub impl NodeClass for SpotLightNode with fn parent(self) {
  Some(self.analytic)
}

///|
pub impl NodeClass for SpotLightNode with fn children(self, node, out) {
  NodeClass::children(self.analytic, node, out)
  push_child(out, "coneCosNode", Some(self.cone_cos_node))
  push_child(out, "penumbraCosNode", Some(self.penumbra_cos_node))
  push_child(out, "cutoffDistanceNode", Some(self.cutoff_distance_node))
  push_child(out, "decayExponentNode", Some(self.decay_exponent_node))
}

///|
pub impl NodeClass for SpotLightNode with fn update(self, node, frame) {
  NodeClass::update(self.analytic, node, frame) |> ignore
  let light = self.analytic.light.unwrap()
  guard light.as_light().kind is SpotLight(spot) else { return None }
  InputNode::set_value(
    self.cone_cos_node,
    Number(spot_light_node_cos(spot.angle)),
  )
  InputNode::set_value(
    self.penumbra_cos_node,
    Number(spot_light_node_cos(spot.angle * (1.0 - spot.penumbra))),
  )
  InputNode::set_value(self.cutoff_distance_node, Number(spot.distance))
  InputNode::set_value(self.decay_exponent_node, Number(spot.decay))
  None
}

///|
pub impl AnalyticLightNodeClass for SpotLightNode with fn analytic_parent(self) {
  Some(self.analytic)
}

///|
pub impl AnalyticLightNodeClass for SpotLightNode with fn setup_direct(
  self,
  node,
  builder,
) {
  let color_node = self.analytic.color_node.unwrap()
  let light = self.analytic.light.unwrap()
  let light_vector = AnalyticLightNode::get_light_vector(node, builder)
  let light_direction = light_vector.normalize()
  let angle_cos = light_direction.dot(light_target_direction(light))
  let spot_attenuation = self.spot_class.get_spot_attenuation(
    node, builder, angle_cos,
  )
  let light_distance = light_vector.length()
  let light_attenuation = get_distance_attenuation.call_named({
    "lightDistance": light_distance,
    "cutoffDistance": self.cutoff_distance_node,
    "decayExponent": self.decay_exponent_node,
  })
  let mut light_color = color_node.mul(spot_attenuation).mul(light_attenuation)
  let mut projected : Node? = None
  let mut light_coord : Node? = None
  guard light.as_light().kind is SpotLight(spot) else {
    abort("SpotLightNode: not a spot light")
  }
  if light.as_light().color_node is Some(color_fn) {
    let coord = SpotLightNode::get_light_coord(node, builder)
    light_coord = Some(coord)
    projected = Some((color_fn.cast() : Node).call([coord]))
  } else if spot.map is Some(map) {
    let coord = SpotLightNode::get_light_coord(node, builder)
    light_coord = Some(coord)
    projected = Some(
      texture(map, uv_node=coord.xy()).on_render_update(fn(n, _) {
        match spot.map {
          Some(m) => InputNode::set_value(n, Texture(m))
          None => InputNode::set_value(n, Null)
        }
        None
      }),
    )
  }
  if projected is Some(projected) {
    let in_spot_light_map = light_coord
      .unwrap()
      .mul(2.0)
      .sub(1.0)
      .abs()
      .less_than(1.0)
      .all()
    light_color = in_spot_light_map.select(
      light_color.mul(projected),
      else_node=light_color,
    )
  }
  Some(LightData::direct(light_direction, light_color))
}

///|
/// The constructor body.
pub fn SpotLightNode::construct(
  node : Node,
  light : @core.Object3D?,
) -> SpotLightNode {
  let analytic = AnalyticLightNode::construct(node, light)
  let payload = SpotLightNode::{
    analytic,
    cone_cos_node: uniform(0).set_group(render_group),
    penumbra_cos_node: uniform(0).set_group(render_group),
    cutoff_distance_node: uniform(0).set_group(render_group),
    decay_exponent_node: uniform(0).set_group(render_group),
    spot_class: SpotLightNodeUnset::{ },
  }
  analytic.color_node = Some(uniform(analytic.color).set_group(render_group))
  payload
}

///|
/// `new SpotLightNode( light = null )`.
pub fn SpotLightNode::new(light? : @core.Object3D) -> Node {
  let node = AnalyticLightNode::alloc()
  let payload = SpotLightNode::construct(node, light)
  payload.analytic.class_ = payload
  payload.spot_class = payload
  node.set_class(payload)
}

///|
pub fn SpotLightNode::of(node : Node) -> SpotLightNode? {
  match node.class_payload("SpotLightNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn SpotLightNode::payload_of(node : Node) -> SpotLightNode {
  match SpotLightNode::of(node) {
    Some(p) => p
    None => abort("TypeError: \{node.type_()} is not a SpotLightNode")
  }
}

///|
/// `SpotLightNode.prototype.getSpotAttenuation`: the smoothstep between the cone and
/// penumbra cosines.
pub fn SpotLightNode::get_spot_attenuation_base(
  node : Node,
  _builder : NodeBuilder,
  angle_cosine : Node,
) -> Node {
  let self = SpotLightNode::payload_of(node)
  smoothstep(self.cone_cos_node, self.penumbra_cos_node, angle_cosine)
}

///|
/// `getLightCoord( builder )`: the light's projection uv, cached in the properties.
pub fn SpotLightNode::get_light_coord(
  node : Node,
  builder : NodeBuilder,
) -> Node {
  let self = SpotLightNode::payload_of(node)
  let properties = builder.get_node_properties(node)
  match properties.get_node("projectionUV") {
    Some(projection_uv) => projection_uv
    None => {
      let projection_uv = light_projection_uv(
        self.analytic.light.unwrap(),
        position?=builder.context.get_node("positionWorld"),
      )
      properties.set_node("projectionUV", projection_uv)
      projection_uv
    }
  }
}

///|
/// The value `SpotLight.registerNode( SpotLightNode )` stores.
pub fn SpotLightNode::node_class() -> @core.JsValue {
  @core.JsValue::of(LightNodeClass::{
    create: fn(light) { SpotLightNode::new(light~) },
  })
}
