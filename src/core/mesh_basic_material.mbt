// Upstream src/materials/MeshBasicMaterial.js.

///|
#external
pub type MeshBasicMaterial

///|
pub fn MeshBasicMaterial::new() -> Material {
  let material = Material::new()
  material.type_ = "MeshBasicMaterial"
  material.material_type = MeshBasicMaterial
  material.color = Some(@math.Color::from_hex(0xffffff))
  material.light_map_intensity = Some(1.0)
  material.ao_map_intensity = Some(1.0)
  material.env_map_rotation = Some(@math.Euler::new(0.0, 0.0, 0.0))
  material.combine = Some(MultiplyOperation)
  material.reflectivity = Some(1.0)
  material.refraction_ratio = Some(0.98)
  material.wireframe = Some(false)
  material.wireframe_linewidth = Some(1.0)
  material.wireframe_linecap = Some("round")
  material.wireframe_linejoin = Some("round")
  material.fog = Some(true)
  material
}

///|
/// `isMeshBasicMaterial`.
pub fn Material::is_mesh_basic_material(self : Material) -> Bool {
  self.material_type is MeshBasicMaterial ||
  // a node material with this class's defaults (upstream copies the flag)
  self.has_extension_flag("isMeshBasicMaterial")
}

///|
fn Material::copy_mesh_basic(self : Material, source : Material) -> Unit {
  self.copy_base(source)
  ignore(self.color.unwrap().copy(source.color.unwrap()))
  self.map = source.map
  self.light_map = source.light_map
  self.light_map_intensity = source.light_map_intensity
  self.ao_map = source.ao_map
  self.ao_map_intensity = source.ao_map_intensity
  self.specular_map = source.specular_map
  self.alpha_map = source.alpha_map
  self.env_map = source.env_map
  ignore(self.env_map_rotation.unwrap().copy(source.env_map_rotation.unwrap()))
  self.combine = source.combine
  self.reflectivity = source.reflectivity()
  self.refraction_ratio = source.refraction_ratio
  self.wireframe = source.wireframe
  self.wireframe_linewidth = source.wireframe_linewidth
  self.wireframe_linecap = source.wireframe_linecap
  self.wireframe_linejoin = source.wireframe_linejoin
  self.fog = source.fog
}
