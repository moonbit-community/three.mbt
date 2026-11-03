// materials/nodes/MeshBasicNodeMaterial.js

///|
let mesh_basic_node_material_defaults : @core.Material = @core.MeshBasicMaterial::new()

///|
pub(all) struct MeshBasicNodeMaterial {}

///|
pub impl NodeMaterialClass for MeshBasicNodeMaterial with fn class_name(_) {
  "MeshBasicNodeMaterial"
}

///|
pub impl NodeMaterialClass for MeshBasicNodeMaterial with fn parent(_) {
  Some(BaseNodeMaterial::{ })
}

///|
pub impl NodeMaterialClass for MeshBasicNodeMaterial with fn has_flag(_, flag) {
  flag == "isMeshBasicNodeMaterial" || flag == "isMeshBasicMaterial"
}

///|
pub impl NodeMaterialClass for MeshBasicNodeMaterial with fn construct(_) {
  MeshBasicNodeMaterial::new()
}

///|
/// `negateOnBackSide( normalViewGeometry )` (see #28839).
pub impl NodeMaterialClass for MeshBasicNodeMaterial with fn setup_normal(
  _,
  _,
  _,
) {
  negate_on_back_side.call([normal_view_geometry])
}

///|
pub impl NodeMaterialClass for MeshBasicNodeMaterial with fn setup_environment(
  _,
  material,
  _,
) {
  match NodeMaterial::setup_environment_base(material) {
    Some(env_node) => Some(BasicEnvironmentNode::new(env_node~))
    None => None
  }
}

///|
pub impl NodeMaterialClass for MeshBasicNodeMaterial with fn setup_light_map(
  _,
  _,
  builder,
) {
  if node_material_builder_material(builder).light_map is Some(_) {
    Some(BasicLightMapNode::new(light_map_node=material_light_map))
  } else {
    None
  }
}

///|
pub impl NodeMaterialClass for MeshBasicNodeMaterial with fn setup_outgoing_light(
  _,
  _,
  _,
) {
  diffuse_color.rgb()
}

///|
pub impl NodeMaterialClass for MeshBasicNodeMaterial with fn setup_lighting_model(
  _,
  _,
  _,
) {
  Some(BasicLightingModel::new())
}

///|
/// `new MeshBasicNodeMaterial()`.
pub fn MeshBasicNodeMaterial::new() -> @core.Material {
  let material = NodeMaterial::create(MeshBasicNodeMaterial::{ })
  material.lights = Some(true)
  NodeMaterial::set_default_values(material, mesh_basic_node_material_defaults)
  material
}
