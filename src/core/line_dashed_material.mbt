// Upstream src/materials/LineDashedMaterial.js.

///|
#external
pub type LineDashedMaterial

///|
pub fn LineDashedMaterial::new() -> Material {
  let material = LineBasicMaterial::new()
  material.type_ = "LineDashedMaterial"
  material.material_type = LineDashedMaterial
  material.scale = Some(1.0)
  material.dash_size = Some(3.0)
  material.gap_size = Some(1.0)
  material
}

///|
/// `isLineDashedMaterial`.
pub fn Material::is_line_dashed_material(self : Material) -> Bool {
  self.material_type is LineDashedMaterial ||
  // a node material with this class's defaults (upstream copies the flag)
  self.has_extension_flag("isLineDashedMaterial")
}

///|
fn Material::copy_line_dashed(self : Material, source : Material) -> Unit {
  self.copy_line_basic(source)
  self.scale = source.scale
  self.dash_size = source.dash_size
  self.gap_size = source.gap_size
}
