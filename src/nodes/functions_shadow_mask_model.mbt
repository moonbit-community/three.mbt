// nodes/functions/ShadowMaskModel.js: renders only the shadow mask, for
// ShadowNodeMaterial.

///|
pub(all) struct ShadowMaskModel {
  shadow_node : Node
}

///|
pub impl LightingModelClass for ShadowMaskModel with fn class_name(_) {
  "ShadowMaskModel"
}

///|
pub impl LightingModelClass for ShadowMaskModel with fn direct(
  self,
  _,
  light_data,
  _,
) {
  let data = LightData::from_js(light_data)
  let light_node = data.light_node.unwrap()
  if AnalyticLightNode::of(light_node).unwrap().shadow_node is Some(shadow_node) {
    self.shadow_node.mul_assign(shadow_node)
  }
}

///|
pub impl LightingModelClass for ShadowMaskModel with fn finish(self, _, builder) {
  diffuse_color.a().mul_assign(self.shadow_node.one_minus())
  builder.context
  .get_node("outgoingLight")
  .unwrap()
  .rgb()
  .assign(diffuse_color.rgb())
}

///|
/// `new ShadowMaskModel()`.
pub fn ShadowMaskModel::new() -> LightingModel {
  LightingModel::new(class_=ShadowMaskModel::{
    shadow_node: float(1).to_var(name="shadowMask"),
  })
}

///|
pub fn ShadowMaskModel::of(model : LightingModel) -> ShadowMaskModel? {
  match model.class_payload("ShadowMaskModel") {
    Some(p) => Some(p.cast())
    None => None
  }
}
