// Upstream src/materials/MeshDepthMaterial.js.

///|
#external
pub type MeshDepthMaterial

///|
pub fn MeshDepthMaterial::new() -> Material {
  let material = Material::new()
  material.type_ = "MeshDepthMaterial"
  material.material_type = MeshDepthMaterial
  material.depth_packing = Some(BasicDepthPacking)
  material.displacement_scale = Some(1.0)
  material.displacement_bias = Some(0.0)
  material.wireframe = Some(false)
  material.wireframe_linewidth = Some(1.0)
  material
}

///|
/// `isMeshDepthMaterial`.
pub fn Material::is_mesh_depth_material(self : Material) -> Bool {
  self.material_type is MeshDepthMaterial ||
  // a node material with this class's defaults (upstream copies the flag)
  self.has_extension_flag("isMeshDepthMaterial")
}

///|
fn Material::copy_mesh_depth(self : Material, source : Material) -> Unit {
  self.copy_base(source)
  self.depth_packing = source.depth_packing
  self.map = source.map
  self.alpha_map = source.alpha_map
  self.displacement_map = source.displacement_map
  self.displacement_scale = source.displacement_scale
  self.displacement_bias = source.displacement_bias
  self.wireframe = source.wireframe
  self.wireframe_linewidth = source.wireframe_linewidth
}
