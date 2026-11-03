// materials/nodes/MeshToonNodeMaterial.js

///|
let mesh_toon_node_material_defaults : @core.Material = @core.MeshToonMaterial::new()

///|
pub(all) struct MeshToonNodeMaterial {
  mut emissive_node : Node?
}

///|
pub impl NodeMaterialClass for MeshToonNodeMaterial with fn class_name(_) {
  "MeshToonNodeMaterial"
}

///|
pub impl NodeMaterialClass for MeshToonNodeMaterial with fn parent(_) {
  Some(BaseNodeMaterial::{ })
}

///|
pub impl NodeMaterialClass for MeshToonNodeMaterial with fn has_flag(_, flag) {
  flag == "isMeshToonNodeMaterial" || flag == "isMeshToonMaterial"
}

///|
pub impl NodeMaterialClass for MeshToonNodeMaterial with fn construct(_) {
  MeshToonNodeMaterial::new()
}

///|
pub impl NodeMaterialClass for MeshToonNodeMaterial with fn node_slot(
  self,
  name,
) {
  match name {
    "emissiveNode" => Some(self.emissive_node)
    _ => None
  }
}

///|
pub impl NodeMaterialClass for MeshToonNodeMaterial with fn own_node_slots(
  self,
  out,
) {
  out.push(("emissiveNode", self.emissive_node))
}

///|
pub impl NodeMaterialClass for MeshToonNodeMaterial with fn set_node_slot(
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
pub impl NodeMaterialClass for MeshToonNodeMaterial with fn get_property(
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
pub impl NodeMaterialClass for MeshToonNodeMaterial with fn setup_lighting_model(
  _,
  _,
  _,
) {
  Some(ToonLightingModel::new())
}

///|
/// `new MeshToonNodeMaterial()`.
pub fn MeshToonNodeMaterial::new() -> @core.Material {
  let material = NodeMaterial::create(MeshToonNodeMaterial::{
    emissive_node: None,
  })
  material.lights = Some(true)
  NodeMaterial::set_default_values(material, mesh_toon_node_material_defaults)
  material
}

///|
pub fn MeshToonNodeMaterial::of(
  material : @core.Material,
) -> MeshToonNodeMaterial? {
  match NodeMaterial::class_payload(material, "MeshToonNodeMaterial") {
    Some(p) => Some(p.cast())
    None => None
  }
}
