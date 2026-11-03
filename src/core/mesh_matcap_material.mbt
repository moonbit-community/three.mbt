// Upstream src/materials/MeshMatcapMaterial.js.

///|
#external
pub type MeshMatcapMaterial

///|
pub fn MeshMatcapMaterial::new() -> Material {
  let material = Material::new()
  material.type_ = "MeshMatcapMaterial"
  material.material_type = MeshMatcapMaterial
  material.defines = Some(Map([("MATCAP", Json::string(""))]))
  material.color = Some(@math.Color::from_hex(0xffffff))
  material.bump_scale = Some(1.0)
  material.normal_map_type = Some(TangentSpaceNormalMap)
  material.normal_scale = Some(@math.Vector2::new(1.0, 1.0))
  material.displacement_scale = Some(1.0)
  material.displacement_bias = Some(0.0)
  material.wireframe = Some(false)
  material.wireframe_linewidth = Some(1.0)
  material.flat_shading = Some(false)
  material.fog = Some(true)
  material
}

///|
/// `isMeshMatcapMaterial`.
pub fn Material::is_mesh_matcap_material(self : Material) -> Bool {
  self.material_type is MeshMatcapMaterial ||
  // a node material with this class's defaults (upstream copies the flag)
  self.has_extension_flag("isMeshMatcapMaterial")
}

///|
fn Material::copy_mesh_matcap(self : Material, source : Material) -> Unit {
  self.copy_base(source)
  self.defines = Some(Map([("MATCAP", Json::string(""))]))
  ignore(self.color.unwrap().copy(source.color.unwrap()))
  self.matcap = source.matcap
  self.map = source.map
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
  self.flat_shading = source.flat_shading
  self.fog = source.fog
}
