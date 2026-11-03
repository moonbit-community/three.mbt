// Upstream src/materials/MeshToonMaterial.js.

///|
#external
pub type MeshToonMaterial

///|
pub fn MeshToonMaterial::new() -> Material {
  let material = Material::new()
  material.type_ = "MeshToonMaterial"
  material.material_type = MeshToonMaterial
  material.defines = Some(Map([("TOON", Json::string(""))]))
  material.color = Some(@math.Color::from_hex(0xffffff))
  material.light_map_intensity = Some(1.0)
  material.ao_map_intensity = Some(1.0)
  material.emissive = Some(@math.Color::from_hex(0x000000))
  material.emissive_intensity = Some(1.0)
  material.bump_scale = Some(1.0)
  material.normal_map_type = Some(TangentSpaceNormalMap)
  material.normal_scale = Some(@math.Vector2::new(1.0, 1.0))
  material.displacement_scale = Some(1.0)
  material.displacement_bias = Some(0.0)
  material.wireframe = Some(false)
  material.wireframe_linewidth = Some(1.0)
  material.wireframe_linecap = Some("round")
  material.wireframe_linejoin = Some("round")
  material.fog = Some(true)
  material
}

///|
/// `isMeshToonMaterial`.
pub fn Material::is_mesh_toon_material(self : Material) -> Bool {
  self.material_type is MeshToonMaterial ||
  // a node material with this class's defaults (upstream copies the flag)
  self.has_extension_flag("isMeshToonMaterial")
}

///|
fn Material::copy_mesh_toon(self : Material, source : Material) -> Unit {
  self.copy_base(source)
  ignore(self.color.unwrap().copy(source.color.unwrap()))
  self.map = source.map
  self.gradient_map = source.gradient_map
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
  self.alpha_map = source.alpha_map
  self.wireframe = source.wireframe
  self.wireframe_linewidth = source.wireframe_linewidth
  self.wireframe_linecap = source.wireframe_linecap
  self.wireframe_linejoin = source.wireframe_linejoin
  self.fog = source.fog
}
