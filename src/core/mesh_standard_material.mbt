// Upstream src/materials/MeshStandardMaterial.js.

///|
#external
pub type MeshStandardMaterial

///|
pub fn MeshStandardMaterial::new() -> Material {
  let material = Material::new()
  material.type_ = "MeshStandardMaterial"
  material.material_type = MeshStandardMaterial
  material.defines = Some(Map([("STANDARD", Json::string(""))]))
  material.color = Some(@math.Color::from_hex(0xffffff))
  material.roughness = Some(1.0)
  material.metalness = Some(0.0)
  material.light_map_intensity = Some(1.0)
  material.ao_map_intensity = Some(1.0)
  material.emissive = Some(@math.Color::from_hex(0x000000))
  material.emissive_intensity = Some(1.0)
  material.bump_scale = Some(1.0)
  material.normal_map_type = Some(TangentSpaceNormalMap)
  material.normal_scale = Some(@math.Vector2::new(1.0, 1.0))
  material.displacement_scale = Some(1.0)
  material.displacement_bias = Some(0.0)
  material.env_map_rotation = Some(@math.Euler::new(0.0, 0.0, 0.0))
  material.env_map_intensity = Some(1.0)
  material.wireframe = Some(false)
  material.wireframe_linewidth = Some(1.0)
  material.wireframe_linecap = Some("round")
  material.wireframe_linejoin = Some("round")
  material.flat_shading = Some(false)
  material.fog = Some(true)
  material
}

///|
/// `isMeshStandardMaterial`; also true for `MeshPhysicalMaterial`.
pub fn Material::is_mesh_standard_material(self : Material) -> Bool {
  self.material_type is (MeshStandardMaterial | MeshPhysicalMaterial) ||
  // a node material with this class's defaults (upstream copies the flag)
  self.has_extension_flag("isMeshStandardMaterial")
}

///|
fn Material::copy_mesh_standard(self : Material, source : Material) -> Unit {
  self.copy_base(source)
  self.defines = Some(Map([("STANDARD", Json::string(""))]))
  ignore(self.color.unwrap().copy(source.color.unwrap()))
  self.roughness = source.roughness
  self.metalness = source.metalness
  self.map = source.map
  self.light_map = source.light_map
  self.light_map_intensity = source.light_map_intensity
  self.ao_map = source.ao_map
  self.ao_map_intensity = source.ao_map_intensity
  ignore(self.emissive.unwrap().copy(source.emissive.unwrap()))
  self.emissive_map = source.emissive_map
  self.emissive_intensity = source.emissive_intensity
  self.bump_map = source.bump_map
  self.bump_scale = source.bump_scale
  self.normal_map = source.normal_map
  self.normal_map_type = source.normal_map_type
  ignore(self.normal_scale.unwrap().copy(source.normal_scale.unwrap()))
  self.displacement_map = source.displacement_map
  self.displacement_scale = source.displacement_scale
  self.displacement_bias = source.displacement_bias
  self.roughness_map = source.roughness_map
  self.metalness_map = source.metalness_map
  self.alpha_map = source.alpha_map
  self.env_map = source.env_map
  ignore(self.env_map_rotation.unwrap().copy(source.env_map_rotation.unwrap()))
  self.env_map_intensity = source.env_map_intensity
  self.wireframe = source.wireframe
  self.wireframe_linewidth = source.wireframe_linewidth
  self.wireframe_linecap = source.wireframe_linecap
  self.wireframe_linejoin = source.wireframe_linejoin
  self.flat_shading = source.flat_shading
  self.fog = source.fog
}
