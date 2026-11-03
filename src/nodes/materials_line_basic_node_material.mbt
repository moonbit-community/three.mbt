// materials/nodes/LineBasicNodeMaterial.js

///|
let line_basic_node_material_defaults : @core.Material = @core.LineBasicMaterial::new()

///|
pub(all) struct LineBasicNodeMaterial {}

///|
pub impl NodeMaterialClass for LineBasicNodeMaterial with fn class_name(_) {
  "LineBasicNodeMaterial"
}

///|
pub impl NodeMaterialClass for LineBasicNodeMaterial with fn parent(_) {
  Some(BaseNodeMaterial::{ })
}

///|
pub impl NodeMaterialClass for LineBasicNodeMaterial with fn has_flag(_, flag) {
  flag == "isLineBasicNodeMaterial" || flag == "isLineBasicMaterial"
}

///|
pub impl NodeMaterialClass for LineBasicNodeMaterial with fn construct(_) {
  LineBasicNodeMaterial::new()
}

///|
/// `new LineBasicNodeMaterial()`.
pub fn LineBasicNodeMaterial::new() -> @core.Material {
  let material = NodeMaterial::create(LineBasicNodeMaterial::{ })
  NodeMaterial::set_default_values(material, line_basic_node_material_defaults)
  material
}
