// Upstream src/materials/MeshDistanceMaterial.js.

///|
#external
pub type MeshDistanceMaterial

///|
pub fn MeshDistanceMaterial::new() -> Material {
  let material = Material::new()
  material.type_ = "MeshDistanceMaterial"
  material.material_type = MeshDistanceMaterial
  material.displacement_scale = Some(1.0)
  material.displacement_bias = Some(0.0)
  material
}

///|
/// `isMeshDistanceMaterial`.
pub fn Material::is_mesh_distance_material(self : Material) -> Bool {
  self.material_type is MeshDistanceMaterial ||
  // a node material with this class's defaults (upstream copies the flag)
  self.has_extension_flag("isMeshDistanceMaterial")
}

///|
fn Material::copy_mesh_distance(self : Material, source : Material) -> Unit {
  self.copy_base(source)
  self.map = source.map
  self.alpha_map = source.alpha_map
  self.displacement_map = source.displacement_map
  self.displacement_scale = source.displacement_scale
  self.displacement_bias = source.displacement_bias
}
