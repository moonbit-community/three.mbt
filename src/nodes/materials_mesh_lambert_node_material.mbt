// materials/nodes/MeshLambertNodeMaterial.js

///|
let mesh_lambert_node_material_defaults : @core.Material = @core.MeshLambertMaterial::new()

///|
pub(all) struct MeshLambertNodeMaterial {
  mut emissive_node : Node?
}

///|
pub impl NodeMaterialClass for MeshLambertNodeMaterial with fn class_name(_) {
  "MeshLambertNodeMaterial"
}

///|
pub impl NodeMaterialClass for MeshLambertNodeMaterial with fn parent(_) {
  Some(BaseNodeMaterial::{ })
}

///|
pub impl NodeMaterialClass for MeshLambertNodeMaterial with fn has_flag(_, flag) {
  flag == "isMeshLambertNodeMaterial" || flag == "isMeshLambertMaterial"
}

///|
pub impl NodeMaterialClass for MeshLambertNodeMaterial with fn construct(_) {
  MeshLambertNodeMaterial::new()
}

///|
pub impl NodeMaterialClass for MeshLambertNodeMaterial with fn node_slot(
  self,
  name,
) {
  match name {
    "emissiveNode" => Some(self.emissive_node)
    _ => None
  }
}

///|
pub impl NodeMaterialClass for MeshLambertNodeMaterial with fn own_node_slots(
  self,
  out,
) {
  out.push(("emissiveNode", self.emissive_node))
}

///|
pub impl NodeMaterialClass for MeshLambertNodeMaterial with fn set_node_slot(
  self,
  name,
  value,
) {
  match name {
    "emissiveNode" => self.emissive_node = value
    _ => return false
  }
  true
}

///|
pub impl NodeMaterialClass for MeshLambertNodeMaterial with fn get_property(
  self,
  material,
  name,
) {
  match name {
    "emissiveNode" => Some(node_material_slot_value(self.emissive_node))
    _ => BaseNodeMaterial::{ }.get_property(material, name)
  }
}

///|
pub impl NodeMaterialClass for MeshLambertNodeMaterial with fn setup_environment(
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
/// `new PhongLightingModel( false )`: forces lambert.
pub impl NodeMaterialClass for MeshLambertNodeMaterial with fn setup_lighting_model(
  _,
  _,
  _,
) {
  Some(PhongLightingModel::new(specular=false))
}

///|
/// `new MeshLambertNodeMaterial()`.
pub fn MeshLambertNodeMaterial::new() -> @core.Material {
  let material = NodeMaterial::create(MeshLambertNodeMaterial::{
    emissive_node: None,
  })
  material.lights = Some(true)
  NodeMaterial::set_default_values(
    material, mesh_lambert_node_material_defaults,
  )
  material
}

///|
pub fn MeshLambertNodeMaterial::of(
  material : @core.Material,
) -> MeshLambertNodeMaterial? {
  match NodeMaterial::class_payload(material, "MeshLambertNodeMaterial") {
    Some(p) => Some(p.cast())
    None => None
  }
}
