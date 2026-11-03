// Upstream src/materials/RawShaderMaterial.js.

///|
#external
pub type RawShaderMaterial

///|
pub fn RawShaderMaterial::new() -> Material {
  let material = ShaderMaterial::new()
  material.type_ = "RawShaderMaterial"
  material.material_type = RawShaderMaterial
  material
}

///|
/// `isRawShaderMaterial`.
pub fn Material::is_raw_shader_material(self : Material) -> Bool {
  self.material_type is RawShaderMaterial
}
