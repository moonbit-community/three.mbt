// Upstream src/materials/MeshPhongMaterial.js.

///|
#external
pub type MeshPhongMaterial

///|
pub fn MeshPhongMaterial::new() -> Material {
  let material = Material::new()
  material.type_ = "MeshPhongMaterial"
  material.material_type = MeshPhongMaterial
  material.color = Some(@math.Color::from_hex(0xffffff))
  material.specular = Some(@math.Color::from_hex(0x111111))
  material.shininess = Some(30.0)
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
  material.combine = Some(MultiplyOperation)
  material.reflectivity = Some(1.0)
  material.env_map_intensity = Some(1.0)
  material.refraction_ratio = Some(0.98)
  material.wireframe = Some(false)
  material.wireframe_linewidth = Some(1.0)
  material.wireframe_linecap = Some("round")
  material.wireframe_linejoin = Some("round")
  material.flat_shading = Some(false)
  material.fog = Some(true)
  material
}

///|
/// `isMeshPhongMaterial`.
pub fn Material::is_mesh_phong_material(self : Material) -> Bool {
  self.material_type is MeshPhongMaterial ||
  // a node material with this class's defaults (upstream copies the flag)
  self.has_extension_flag("isMeshPhongMaterial")
}

///|
fn Material::copy_mesh_phong(self : Material, source : Material) -> Unit {
  self.copy_base(source)
  ignore(self.color.unwrap().copy(source.color.unwrap()))
  ignore(self.specular.unwrap().copy(source.specular.unwrap()))
  self.shininess = source.shininess
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
  self.specular_map = source.specular_map
  self.alpha_map = source.alpha_map
  self.env_map = source.env_map
  ignore(self.env_map_rotation.unwrap().copy(source.env_map_rotation.unwrap()))
  self.combine = source.combine
  self.reflectivity = source.reflectivity()
  self.env_map_intensity = source.env_map_intensity
  self.refraction_ratio = source.refraction_ratio
  self.wireframe = source.wireframe
  self.wireframe_linewidth = source.wireframe_linewidth
  self.wireframe_linecap = source.wireframe_linecap
  self.wireframe_linejoin = source.wireframe_linejoin
  self.flat_shading = source.flat_shading
  self.fog = source.fog
}
