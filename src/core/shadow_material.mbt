// Upstream src/materials/ShadowMaterial.js.

///|
#external
pub type ShadowMaterial

///|
pub fn ShadowMaterial::new() -> Material {
  let material = Material::new()
  material.type_ = "ShadowMaterial"
  material.material_type = ShadowMaterial
  material.color = Some(@math.Color::from_hex(0x000000))
  material.transparent = true
  material.fog = Some(true)
  material
}

///|
/// `isShadowMaterial`.
pub fn Material::is_shadow_material(self : Material) -> Bool {
  self.material_type is ShadowMaterial ||
  // a node material with this class's defaults (upstream copies the flag)
  self.has_extension_flag("isShadowMaterial")
}

///|
fn Material::copy_shadow(self : Material, source : Material) -> Unit {
  self.copy_base(source)
  ignore(self.color.unwrap().copy(source.color.unwrap()))
  self.fog = source.fog
}
