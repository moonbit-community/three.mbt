// nodes/lighting/ProjectorLightNode.js

///|
/// `sdBox( p, b )`.
let projector_light_node_sd_box : Node = module_nodes(
  "nodes/lighting/ProjectorLightNode.js:sdBox",
  fn() {
    fn_(
      fn(inputs, _) {
        let p = inputs.get(0).unwrap()
        let b = inputs.get(1).unwrap()
        let d = p.abs().sub(b)
        Some(length(max(d, 0.0)).add(min(max(d.x(), d.y()), 0.0)))
      },
      layout=FnLayout::short(
        [("p", "vec2"), ("b", "vec2")],
        return_="float",
        upstream="nodes/lighting/ProjectorLightNode.js:sdBox",
      ),
    )
  },
)

///|
extern "js" fn projector_light_node_math_min(a : Double, b : Double) -> Double = "Math.min"

///|
pub(all) struct ProjectorLightNode {
  spot : SpotLightNode
}

///|
pub impl NodeClass for ProjectorLightNode with fn class_name(_) {
  "ProjectorLightNode"
}

///|
pub impl NodeClass for ProjectorLightNode with fn parent(self) {
  Some(self.spot)
}

///|
pub impl NodeClass for ProjectorLightNode with fn update(self, node, frame) {
  NodeClass::update(self.spot, node, frame) |> ignore
  let light = self.spot.analytic.light.unwrap()
  guard light.as_light().kind is SpotLight(spot) else { return None }
  InputNode::set_value(
    self.spot.penumbra_cos_node,
    Number(
      projector_light_node_math_min(
        spot_light_node_cos(spot.angle * (1.0 - spot.penumbra)),
        0.99999,
      ),
    ),
  )
  guard light.as_light().shadow is Some({ kind: SpotLightShadow(shadow), .. }) else {
    return None
  }
  match spot.aspect {
    None => {
      let mut aspect = 1.0
      if spot.map is Some(map) {
        aspect = map.width() / map.height()
      }
      shadow.aspect = aspect
    }
    Some(aspect) => shadow.aspect = aspect
  }
  None
}

///|
pub impl AnalyticLightNodeClass for ProjectorLightNode with fn analytic_parent(
  self,
) {
  Some(self.spot)
}

///|
pub impl SpotLightNodeClass for ProjectorLightNode with fn spot_parent(self) {
  Some(self.spot)
}

///|
pub impl SpotLightNodeClass for ProjectorLightNode with fn get_spot_attenuation(
  self,
  _,
  builder,
  _,
) {
  let attenuation = float(0)
  let penumbra_cos = self.spot.penumbra_cos_node
  let position = match builder.context.get_node("positionWorld") {
    Some(p) => p
    None => position_world
  }
  let spot_light_coord = light_shadow_matrix(self.spot.analytic.light.unwrap()).mul(
    position,
  )
  if_(spot_light_coord.w().greater_than(0), fn() {
    let projection_uv = spot_light_coord.xyz().div(spot_light_coord.w())
    let box_dist = projector_light_node_sd_box.call([
      projection_uv.xy().sub(vec2(0.5)),
      vec2(0.5),
    ])
    let angle_factor = div(-1.0, sub(1.0, acos(penumbra_cos)).sub(1.0))
    attenuation.assign(saturate(box_dist.mul(-2.0).mul(angle_factor)))
  })
  |> ignore
  attenuation
}

///|
/// `new ProjectorLightNode( light = null )`.
pub fn ProjectorLightNode::new(light? : @core.Object3D) -> Node {
  let node = AnalyticLightNode::alloc()
  let payload = ProjectorLightNode::{
    spot: SpotLightNode::construct(node, light),
  }
  payload.spot.analytic.class_ = payload
  payload.spot.spot_class = payload
  node.set_class(payload)
}

///|
pub fn ProjectorLightNode::of(node : Node) -> ProjectorLightNode? {
  match node.class_payload("ProjectorLightNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// The value `ProjectorLight.registerNode( ProjectorLightNode )` stores.
pub fn ProjectorLightNode::node_class() -> @core.JsValue {
  @core.JsValue::of(LightNodeClass::{
    create: fn(light) { ProjectorLightNode::new(light~) },
  })
}
