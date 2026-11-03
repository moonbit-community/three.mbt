// Upstream src/materials/MeshNormalMaterial.js.

///|
#external
pub type MeshNormalMaterial

///|
pub fn MeshNormalMaterial::new() -> Material {
  let material = Material::new()
  material.type_ = "MeshNormalMaterial"
  material.material_type = MeshNormalMaterial
  material.bump_scale = Some(1.0)
  material.normal_map_type = Some(TangentSpaceNormalMap)
  material.normal_scale = Some(@math.Vector2::new(1.0, 1.0))
  material.displacement_scale = Some(1.0)
  material.displacement_bias = Some(0.0)
  material.wireframe = Some(false)
  material.wireframe_linewidth = Some(1.0)
  material.flat_shading = Some(false)
  material
}

///|
/// `isMeshNormalMaterial`.
pub fn Material::is_mesh_normal_material(self : Material) -> Bool {
  self.material_type is MeshNormalMaterial ||
  // a node material with this class's defaults (upstream copies the flag)
  self.has_extension_flag("isMeshNormalMaterial")
}

///|
fn Material::copy_mesh_normal(self : Material, source : Material) -> Unit {
  self.copy_base(source)
  self.bump_map = source.bump_map
  self.bump_scale = source.bump_scale
  self.normal_map = source.normal_map
  self.normal_map_type = source.normal_map_type
  ignore(self.normal_scale.unwrap().copy(source.normal_scale.unwrap()))
  self.displacement_map = source.displacement_map
  self.displacement_scale = source.displacement_scale
  self.displacement_bias = source.displacement_bias
  self.wireframe = source.wireframe
  self.wireframe_linewidth = source.wireframe_linewidth
  self.flat_shading = source.flat_shading
}
