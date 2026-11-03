// Upstream src/materials/PointsMaterial.js.

///|
#external
pub type PointsMaterial

///|
pub fn PointsMaterial::new() -> Material {
  let material = Material::new()
  material.type_ = "PointsMaterial"
  material.material_type = PointsMaterial
  material.color = Some(@math.Color::from_hex(0xffffff))
  material.size = Some(1.0)
  material.size_attenuation = Some(true)
  material.fog = Some(true)
  material
}

///|
/// `isPointsMaterial`.
pub fn Material::is_points_material(self : Material) -> Bool {
  self.material_type is PointsMaterial ||
  // a node material with this class's defaults (upstream copies the flag)
  self.has_extension_flag("isPointsMaterial")
}

///|
fn Material::copy_points(self : Material, source : Material) -> Unit {
  self.copy_base(source)
  ignore(self.color.unwrap().copy(source.color.unwrap()))
  self.map = source.map
  self.alpha_map = source.alpha_map
  self.size = source.size
  self.size_attenuation = source.size_attenuation
  self.fog = source.fog
}
