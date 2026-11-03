// materials/nodes/MeshPhongNodeMaterial.js

///|
let mesh_phong_node_material_defaults : @core.Material = @core.MeshPhongMaterial::new()

///|
pub(all) struct MeshPhongNodeMaterial {
  mut emissive_node : Node?
  mut shininess_node : Node?
  mut specular_node : Node?
}

///|
pub impl NodeMaterialClass for MeshPhongNodeMaterial with fn class_name(_) {
  "MeshPhongNodeMaterial"
}

///|
pub impl NodeMaterialClass for MeshPhongNodeMaterial with fn parent(_) {
  Some(BaseNodeMaterial::{ })
}

///|
pub impl NodeMaterialClass for MeshPhongNodeMaterial with fn has_flag(_, flag) {
  flag == "isMeshPhongNodeMaterial" || flag == "isMeshPhongMaterial"
}

///|
pub impl NodeMaterialClass for MeshPhongNodeMaterial with fn construct(_) {
  MeshPhongNodeMaterial::new()
}

///|
pub impl NodeMaterialClass for MeshPhongNodeMaterial with fn node_slot(
  self,
  name,
) {
  match name {
    "emissiveNode" => Some(self.emissive_node)
    "shininessNode" => Some(self.shininess_node)
    "specularNode" => Some(self.specular_node)
    _ => None
  }
}

///|
pub impl NodeMaterialClass for MeshPhongNodeMaterial with fn own_node_slots(
  self,
  out,
) {
  out.push(("emissiveNode", self.emissive_node))
  out.push(("shininessNode", self.shininess_node))
  out.push(("specularNode", self.specular_node))
}

///|
pub impl NodeMaterialClass for MeshPhongNodeMaterial with fn set_node_slot(
  self,
  name,
  value,
) {
  match name {
    "emissiveNode" => self.emissive_node = value
    "shininessNode" => self.shininess_node = value
    "specularNode" => self.specular_node = value
    _ => return false
  }
  true
}

///|
pub impl NodeMaterialClass for MeshPhongNodeMaterial with fn get_property(
  self,
  material,
  name,
) {
  match self.node_slot(name) {
    Some(slot) => Some(node_material_slot_value(slot))
    None => BaseNodeMaterial::{ }.get_property(material, name)
  }
}

///|
pub impl NodeMaterialClass for MeshPhongNodeMaterial with fn setup_environment(
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
pub impl NodeMaterialClass for MeshPhongNodeMaterial with fn setup_lighting_model(
  _,
  _,
  _,
) {
  Some(PhongLightingModel::new())
}

///|
pub impl NodeMaterialClass for MeshPhongNodeMaterial with fn setup_variants(
  self,
  _,
  _,
) {
  // SHININESS
  let shininess_node = (match self.shininess_node {
    Some(s) => float(s)
    None => material_shininess
  }).max(1.0e-4) // to prevent pow( 0.0, 0.0 )
  shininess.assign(shininess_node)
  // SPECULAR COLOR
  let specular_node = match self.specular_node {
    Some(s) => s
    None => material_specular
  }
  specular_color.assign(specular_node)
}

///|
/// `new MeshPhongNodeMaterial()`.
pub fn MeshPhongNodeMaterial::new() -> @core.Material {
  let material = NodeMaterial::create(MeshPhongNodeMaterial::{
    emissive_node: None,
    shininess_node: None,
    specular_node: None,
  })
  material.lights = Some(true)
  NodeMaterial::set_default_values(material, mesh_phong_node_material_defaults)
  material
}

///|
pub fn MeshPhongNodeMaterial::of(
  material : @core.Material,
) -> MeshPhongNodeMaterial? {
  match NodeMaterial::class_payload(material, "MeshPhongNodeMaterial") {
    Some(p) => Some(p.cast())
    None => None
  }
}
