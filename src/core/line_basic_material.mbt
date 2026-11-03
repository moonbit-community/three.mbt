// Upstream src/materials/LineBasicMaterial.js.

///|
#external
pub type LineBasicMaterial

///|
pub fn LineBasicMaterial::new() -> Material {
  let material = Material::new()
  material.type_ = "LineBasicMaterial"
  material.material_type = LineBasicMaterial
  material.color = Some(@math.Color::from_hex(0xffffff))
  material.linewidth = Some(1.0)
  material.linecap = Some("round")
  material.linejoin = Some("round")
  material.fog = Some(true)
  material
}

///|
/// `isLineBasicMaterial`; also true for `LineDashedMaterial`.
pub fn Material::is_line_basic_material(self : Material) -> Bool {
  self.material_type is (LineBasicMaterial | LineDashedMaterial) ||
  // a node material with this class's defaults (upstream copies the flag)
  self.has_extension_flag("isLineBasicMaterial")
}

///|
fn Material::copy_line_basic(self : Material, source : Material) -> Unit {
  self.copy_base(source)
  ignore(self.color.unwrap().copy(source.color.unwrap()))
  self.map = source.map
  self.linewidth = source.linewidth
  self.linecap = source.linecap
  self.linejoin = source.linejoin
  self.fog = source.fog
}
