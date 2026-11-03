// Upstream src/materials/SpriteMaterial.js.

///|
#external
pub type SpriteMaterial

///|
pub fn SpriteMaterial::new() -> Material {
  let material = Material::new()
  material.type_ = "SpriteMaterial"
  material.material_type = SpriteMaterial
  material.color = Some(@math.Color::from_hex(0xffffff))
  material.rotation = Some(0.0)
  material.size_attenuation = Some(true)
  material.transparent = true
  material.fog = Some(true)
  material
}

///|
/// `isSpriteMaterial`.
pub fn Material::is_sprite_material(self : Material) -> Bool {
  self.material_type is SpriteMaterial ||
  // a node material with this class's defaults (upstream copies the flag)
  self.has_extension_flag("isSpriteMaterial")
}

///|
fn Material::copy_sprite(self : Material, source : Material) -> Unit {
  self.copy_base(source)
  ignore(self.color.unwrap().copy(source.color.unwrap()))
  self.map = source.map
  self.alpha_map = source.alpha_map
  self.rotation = source.rotation
  self.size_attenuation = source.size_attenuation
  self.fog = source.fog
}
