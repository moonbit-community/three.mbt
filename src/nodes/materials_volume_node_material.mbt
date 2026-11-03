// materials/nodes/VolumeNodeMaterial.js

///|
pub(all) struct VolumeNodeMaterial {
  /// Number of steps used for raymarching.
  mut steps : Double
  /// Offsets the distance a ray has been traveled through a volume.
  mut offset_node : Node?
  /// The scattering density of the volume.
  mut scattering_node : Node?
}

///|
pub impl NodeMaterialClass for VolumeNodeMaterial with fn class_name(_) {
  "VolumeNodeMaterial"
}

///|
pub impl NodeMaterialClass for VolumeNodeMaterial with fn parent(_) {
  Some(BaseNodeMaterial::{ })
}

///|
pub impl NodeMaterialClass for VolumeNodeMaterial with fn has_flag(_, flag) {
  flag == "isVolumeNodeMaterial"
}

///|
pub impl NodeMaterialClass for VolumeNodeMaterial with fn construct(_) {
  VolumeNodeMaterial::new()
}

///|
pub impl NodeMaterialClass for VolumeNodeMaterial with fn node_slot(self, name) {
  match name {
    "offsetNode" => Some(self.offset_node)
    "scatteringNode" => Some(self.scattering_node)
    _ => None
  }
}

///|
pub impl NodeMaterialClass for VolumeNodeMaterial with fn own_node_slots(
  self,
  out,
) {
  out.push(("offsetNode", self.offset_node))
  out.push(("scatteringNode", self.scattering_node))
}

///|
pub impl NodeMaterialClass for VolumeNodeMaterial with fn set_node_slot(
  self,
  name,
  value,
) {
  match name {
    "offsetNode" => self.offset_node = value
    "scatteringNode" => self.scattering_node = value
    _ => return false
  }
  true
}

///|
pub impl NodeMaterialClass for VolumeNodeMaterial with fn get_property(
  self,
  material,
  name,
) {
  match name {
    "steps" => Some(Number(self.steps))
    _ =>
      match self.node_slot(name) {
        Some(slot) => Some(node_material_slot_value(slot))
        None => BaseNodeMaterial::{ }.get_property(material, name)
      }
  }
}

///|
pub impl NodeMaterialClass for VolumeNodeMaterial with fn reference_value(
  self,
  _,
  key,
) {
  match key {
    "steps" => Some(Number(self.steps))
    _ => None
  }
}

///|
pub impl NodeMaterialClass for VolumeNodeMaterial with fn copy_members(
  self,
  _,
  source,
) {
  if VolumeNodeMaterial::of(source) is Some(s) {
    self.steps = s.steps
  }
}

///|
pub impl NodeMaterialClass for VolumeNodeMaterial with fn setup_lighting_model(
  _,
  _,
  _,
) {
  Some(VolumetricLightingModel::new())
}

///|
/// `new VolumeNodeMaterial()`.
pub fn VolumeNodeMaterial::new() -> @core.Material {
  let payload = VolumeNodeMaterial::{
    steps: 25,
    offset_node: None,
    scattering_node: None,
  }
  let material = NodeMaterial::create(payload)
  material.lights = Some(true)
  material.transparent = true
  material.side = @core.BackSide
  material.depth_test = false
  material.depth_write = false
  // the members VolumetricLightingModel reads (`scatteringEmissiveNode` is not a
  // member in r187, so it reads `undefined`)
  register_volume_material(material, {
    steps: fn() { payload.steps },
    offset_node: fn() { payload.offset_node },
    scattering_node: fn() { payload.scattering_node },
    scattering_emissive_node: fn() { None },
  })
  material
}

///|
pub fn VolumeNodeMaterial::of(material : @core.Material) -> VolumeNodeMaterial? {
  match NodeMaterial::class_payload(material, "VolumeNodeMaterial") {
    Some(p) => Some(p.cast())
    None => None
  }
}
