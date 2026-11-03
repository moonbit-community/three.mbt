// materials/nodes/MeshStandardNodeMaterial.js

///|
let mesh_standard_node_material_defaults : @core.Material = @core.MeshStandardMaterial::new()

///|
pub(all) struct MeshStandardNodeMaterial {
  mut emissive_node : Node?
  mut metalness_node : Node?
  mut roughness_node : Node?
}

///|
pub impl NodeMaterialClass for MeshStandardNodeMaterial with fn class_name(_) {
  "MeshStandardNodeMaterial"
}

///|
pub impl NodeMaterialClass for MeshStandardNodeMaterial with fn parent(_) {
  Some(BaseNodeMaterial::{ })
}

///|
pub impl NodeMaterialClass for MeshStandardNodeMaterial with fn has_flag(
  _,
  flag,
) {
  flag == "isMeshStandardNodeMaterial" || flag == "isMeshStandardMaterial"
}

///|
pub impl NodeMaterialClass for MeshStandardNodeMaterial with fn construct(_) {
  MeshStandardNodeMaterial::new()
}

///|
pub impl NodeMaterialClass for MeshStandardNodeMaterial with fn node_slot(
  self,
  name,
) {
  match name {
    "emissiveNode" => Some(self.emissive_node)
    "metalnessNode" => Some(self.metalness_node)
    "roughnessNode" => Some(self.roughness_node)
    _ => None
  }
}

///|
pub impl NodeMaterialClass for MeshStandardNodeMaterial with fn own_node_slots(
  self,
  out,
) {
  out.push(("emissiveNode", self.emissive_node))
  out.push(("metalnessNode", self.metalness_node))
  out.push(("roughnessNode", self.roughness_node))
}

///|
pub impl NodeMaterialClass for MeshStandardNodeMaterial with fn set_node_slot(
  self,
  name,
  value,
) {
  match name {
    "emissiveNode" => self.emissive_node = value
    "metalnessNode" => self.metalness_node = value
    "roughnessNode" => self.roughness_node = value
    _ => return false
  }
  true
}

///|
pub impl NodeMaterialClass for MeshStandardNodeMaterial with fn get_property(
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
pub impl NodeMaterialClass for MeshStandardNodeMaterial with fn setup_environment(
  _,
  material,
  builder,
) {
  let mut env_node = NodeMaterial::setup_environment_base(material)
  if env_node is None && builder.environment_node is Some(e) {
    env_node = Some(e)
  }
  match env_node {
    Some(env_node) => Some(EnvironmentNode::new(env_node~))
    None => None
  }
}

///|
pub impl NodeMaterialClass for MeshStandardNodeMaterial with fn setup_lighting_model(
  _,
  _,
  _,
) {
  Some(PhysicalLightingModel::new())
}

///|
pub impl NodeMaterialClass for MeshStandardNodeMaterial with fn setup_specular(
  _,
  _,
) {
  let specular_color_node = mix(vec3(0.04), diffuse_color.rgb(), metalness)
  specular_color.assign(vec3(0.04))
  specular_color_blended.assign(specular_color_node)
  specular_f90.assign(1.0)
}

///|
pub impl NodeMaterialClass for MeshStandardNodeMaterial with fn setup_variants(
  self,
  material,
  _,
) {
  MeshStandardNodeMaterial::setup_variants_base(self, material)
}

///|
/// `MeshStandardNodeMaterial.prototype.setupVariants`.
pub fn MeshStandardNodeMaterial::setup_variants_base(
  self : MeshStandardNodeMaterial,
  material : @core.Material,
) -> Unit {
  // METALNESS
  let metalness_node = match self.metalness_node {
    Some(m) => float(m)
    None => material_metalness
  }
  metalness.assign(metalness_node)
  // ROUGHNESS
  let roughness_node = match self.roughness_node {
    Some(r) => float(r)
    None => material_roughness
  }
  let roughness_node = get_roughness.call_named({ "roughness": roughness_node })
  roughness.assign(roughness_node)
  // SPECULAR COLOR
  node_material_class(material).setup_specular(material)
  // DIFFUSE COLOR
  diffuse_contribution.assign(
    diffuse_color.rgb().mul(metalness_node.one_minus()),
  )
}

///|
/// `new MeshStandardNodeMaterial()`.
pub fn MeshStandardNodeMaterial::new() -> @core.Material {
  let material = NodeMaterial::create(MeshStandardNodeMaterial::construct())
  MeshStandardNodeMaterial::init(material)
  material
}

///|
/// The payload of a new `MeshStandardNodeMaterial`, for subclasses.
pub fn MeshStandardNodeMaterial::construct() -> MeshStandardNodeMaterial {
  { emissive_node: None, metalness_node: None, roughness_node: None, }
}

///|
/// The constructor body after `super()`.
pub fn MeshStandardNodeMaterial::init(material : @core.Material) -> Unit {
  material.lights = Some(true)
  NodeMaterial::set_default_values(
    material, mesh_standard_node_material_defaults,
  )
}

///|
pub fn MeshStandardNodeMaterial::of(
  material : @core.Material,
) -> MeshStandardNodeMaterial? {
  match NodeMaterial::class_payload(material, "MeshStandardNodeMaterial") {
    Some(p) => Some(p.cast())
    None => None
  }
}
