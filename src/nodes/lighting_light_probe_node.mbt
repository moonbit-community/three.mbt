// nodes/lighting/LightProbeNode.js

///|
pub(all) struct LightProbeNode {
  analytic : AnalyticLightNode
  light_probe : Node
  /// `lightProbe.array`: the nine spherical harmonics coefficients.
  light_probe_array : Array[@math.Vector3]
}

///|
pub impl NodeClass for LightProbeNode with fn class_name(_) {
  "LightProbeNode"
}

///|
pub impl NodeClass for LightProbeNode with fn parent(self) {
  Some(self.analytic)
}

///|
pub impl NodeClass for LightProbeNode with fn children(self, node, out) {
  NodeClass::children(self.analytic, node, out)
  push_child(out, "lightProbe", Some(self.light_probe))
}

///|
pub impl NodeClass for LightProbeNode with fn update(self, node, frame) {
  let light = self.analytic.light.unwrap()
  NodeClass::update(self.analytic, node, frame) |> ignore
  guard light.as_light().kind is LightProbe(probe) else { return None }
  for i in 0..<9 {
    self.light_probe_array[i]
    .copy(probe.sh.coefficients[i])
    .multiply_scalar(light.as_light().intensity)
    |> ignore
  }
  None
}

///|
pub impl NodeClass for LightProbeNode with fn setup(self, _, builder) {
  let irradiance = get_sh_irradiance_at.call([normal_world, self.light_probe])
  builder.context.get_node("irradiance").unwrap().add_assign(irradiance)
  None
}

///|
pub impl AnalyticLightNodeClass for LightProbeNode with fn analytic_parent(self) {
  Some(self.analytic)
}

///|
/// `new LightProbeNode( light = null )`.
pub fn LightProbeNode::new(light? : @core.Object3D) -> Node {
  let node = AnalyticLightNode::alloc()
  let analytic = AnalyticLightNode::construct(node, light)
  let array = []
  for _ in 0..<9 {
    array.push(@math.Vector3::new(0.0, 0.0, 0.0))
  }
  let payload = LightProbeNode::{
    analytic,
    light_probe: uniform_array(array.map(fn(v) { TslValue::Vector3(v) })).set_group(
      render_group,
    ),
    light_probe_array: array,
  }
  payload.analytic.class_ = payload
  node.set_class(payload)
}

///|
pub fn LightProbeNode::of(node : Node) -> LightProbeNode? {
  match node.class_payload("LightProbeNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// The value `LightProbe.registerNode( LightProbeNode )` stores.
pub fn LightProbeNode::node_class() -> @core.JsValue {
  @core.JsValue::of(LightNodeClass::{
    create: fn(light) { LightProbeNode::new(light~) },
  })
}
