// nodes/lighting/IESSpotLightNode.js

///|
pub(all) struct IESSpotLightNode {
  spot : SpotLightNode
  mut _ies_texture_node : Node?
}

///|
pub impl NodeClass for IESSpotLightNode with fn class_name(_) {
  "IESSpotLightNode"
}

///|
pub impl NodeClass for IESSpotLightNode with fn parent(self) {
  Some(self.spot)
}

///|
pub impl NodeClass for IESSpotLightNode with fn update(self, node, frame) {
  NodeClass::update(self.spot, node, frame) |> ignore
  if self._ies_texture_node is Some(ies_texture_node) &&
    self.spot.analytic.light.unwrap().as_light().kind
    is SpotLight({ ies_map: Some(ies_map), .. }) {
    InputNode::set_value(ies_texture_node, Texture(ies_map))
  }
  None
}

///|
pub impl AnalyticLightNodeClass for IESSpotLightNode with fn analytic_parent(
  self,
) {
  Some(self.spot)
}

///|
pub impl SpotLightNodeClass for IESSpotLightNode with fn spot_parent(self) {
  Some(self.spot)
}

///|
pub impl SpotLightNodeClass for IESSpotLightNode with fn get_spot_attenuation(
  self,
  node,
  builder,
  angle_cosine,
) {
  match self.spot.analytic.light.unwrap().as_light().kind {
    SpotLight({ ies_map: Some(ies_map), .. }) => {
      let light_coord = SpotLightNode::get_light_coord(node, builder).sub(0.5)
      let ies_texture_node = texture(ies_map)
      self._ies_texture_node = Some(ies_texture_node)
      let texel_inset = float(0.5).div(vec2(texture_size(ies_texture_node)))
      let twist_angle = remap
        .call([
          atan(light_coord.y(), x=light_coord.x()),
          -spot_light_node_pi,
          spot_light_node_pi,
        ])
        .add(texel_inset.y())
      let tilt_angle = remap.call([
        angle_cosine.acos(),
        0,
        spot_light_node_pi,
        texel_inset.x(),
        float(1).sub(texel_inset.x()),
      ])
      ies_texture_node.sample(vec2_of([tilt_angle, twist_angle])).level(0).r()
    }
    _ =>
      SpotLightNodeClass::get_spot_attenuation(
        self.spot,
        node,
        builder,
        angle_cosine,
      )
  }
}

///|
let spot_light_node_pi : Double = 3.141592653589793

///|
/// `new IESSpotLightNode( light = null )`.
pub fn IESSpotLightNode::new(light? : @core.Object3D) -> Node {
  let node = AnalyticLightNode::alloc()
  let payload = IESSpotLightNode::{
    spot: SpotLightNode::construct(node, light),
    _ies_texture_node: None,
  }
  payload.spot.analytic.class_ = payload
  payload.spot.spot_class = payload
  node.set_class(payload)
}

///|
pub fn IESSpotLightNode::of(node : Node) -> IESSpotLightNode? {
  match node.class_payload("IESSpotLightNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// The value `IESSpotLight.registerNode( IESSpotLightNode )` stores.
pub fn IESSpotLightNode::node_class() -> @core.JsValue {
  @core.JsValue::of(LightNodeClass::{
    create: fn(light) { IESSpotLightNode::new(light~) },
  })
}
