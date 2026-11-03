// materials/nodes/ShadowNodeMaterial.js

///|
let shadow_node_material_defaults : @core.Material = @core.ShadowMaterial::new()

///|
pub(all) struct ShadowNodeMaterial {}

///|
pub impl NodeMaterialClass for ShadowNodeMaterial with fn class_name(_) {
  "ShadowNodeMaterial"
}

///|
pub impl NodeMaterialClass for ShadowNodeMaterial with fn parent(_) {
  Some(BaseNodeMaterial::{ })
}

///|
pub impl NodeMaterialClass for ShadowNodeMaterial with fn has_flag(_, flag) {
  flag == "isShadowNodeMaterial" || flag == "isShadowMaterial"
}

///|
pub impl NodeMaterialClass for ShadowNodeMaterial with fn construct(_) {
  ShadowNodeMaterial::new()
}

///|
pub impl NodeMaterialClass for ShadowNodeMaterial with fn setup_lighting_model(
  _,
  _,
  _,
) {
  Some(ShadowMaskModel::new())
}

///|
/// `new ShadowNodeMaterial()`.
pub fn ShadowNodeMaterial::new() -> @core.Material {
  let material = NodeMaterial::create(ShadowNodeMaterial::{ })
  material.lights = Some(true)
  material.transparent = true
  NodeMaterial::set_default_values(material, shadow_node_material_defaults)
  material
}
