// Upstream src/materials/MeshPhysicalMaterial.js.

///|
#external
pub type MeshPhysicalMaterial

///|
pub fn MeshPhysicalMaterial::new() -> Material {
  let material = MeshStandardMaterial::new()
  material.type_ = "MeshPhysicalMaterial"
  material.material_type = MeshPhysicalMaterial
  material.defines = Some(
    Map([("STANDARD", Json::string("")), ("PHYSICAL", Json::string(""))]),
  )
  material.anisotropy_rotation = Some(0.0)
  material.clearcoat_roughness = Some(0.0)
  material.clearcoat_normal_scale = Some(@math.Vector2::new(1.0, 1.0))
  material.ior = Some(1.5)
  material.iridescence_ior = Some(1.3)
  material.iridescence_thickness_minimum = Some(100.0)
  material.iridescence_thickness_maximum = Some(400.0)
  material.sheen_color = Some(@math.Color::from_hex(0x000000))
  material.sheen_roughness = Some(1.0)
  material.thickness = Some(0.0)
  material.attenuation_distance = Some(material_infinity())
  material.attenuation_color = Some(@math.Color::new(1.0, 1.0, 1.0))
  material.specular_intensity = Some(1.0)
  material.specular_color = Some(@math.Color::new(1.0, 1.0, 1.0))
  material._anisotropy = Some(0.0)
  material._clearcoat = Some(0.0)
  material._diffuse_roughness = Some(0.0)
  material._dispersion = Some(0.0)
  material._iridescence = Some(0.0)
  material._retroreflectivity = Some(0.0)
  material._sheen = Some(0.0)
  material._transmission = Some(0.0)
  material
}

///|
/// `isMeshPhysicalMaterial`.
pub fn Material::is_mesh_physical_material(self : Material) -> Bool {
  self.material_type is MeshPhysicalMaterial ||
  // a node material with this class's defaults (upstream copies the flag)
  self.has_extension_flag("isMeshPhysicalMaterial")
}

///|
fn Material::copy_mesh_physical(self : Material, source : Material) -> Unit {
  self.copy_mesh_standard(source)
  self.defines = Some(
    Map([("STANDARD", Json::string("")), ("PHYSICAL", Json::string(""))]),
  )
  self.set_anisotropy(source._anisotropy.unwrap())
  self.anisotropy_rotation = source.anisotropy_rotation
  self.anisotropy_map = source.anisotropy_map
  self.set_clearcoat(source._clearcoat.unwrap())
  self.clearcoat_map = source.clearcoat_map
  self.clearcoat_roughness = source.clearcoat_roughness
  self.clearcoat_roughness_map = source.clearcoat_roughness_map
  self.clearcoat_normal_map = source.clearcoat_normal_map
  ignore(
    self.clearcoat_normal_scale
    .unwrap()
    .copy(source.clearcoat_normal_scale.unwrap()),
  )
  self.set_diffuse_roughness(source._diffuse_roughness.unwrap())
  self.diffuse_roughness_map = source.diffuse_roughness_map
  self.set_dispersion(source._dispersion.unwrap())
  self.ior = source.ior
  self.set_iridescence(source._iridescence.unwrap())
  self.iridescence_map = source.iridescence_map
  self.iridescence_ior = source.iridescence_ior
  self.iridescence_thickness_minimum = source.iridescence_thickness_minimum
  self.iridescence_thickness_maximum = source.iridescence_thickness_maximum
  self.iridescence_thickness_map = source.iridescence_thickness_map
  self.set_retroreflectivity(source._retroreflectivity.unwrap())
  self.set_sheen(source._sheen.unwrap())
  ignore(self.sheen_color.unwrap().copy(source.sheen_color.unwrap()))
  self.sheen_color_map = source.sheen_color_map
  self.sheen_roughness = source.sheen_roughness
  self.sheen_roughness_map = source.sheen_roughness_map
  self.set_transmission(source._transmission.unwrap())
  self.transmission_map = source.transmission_map
  self.thickness = source.thickness
  self.thickness_map = source.thickness_map
  self.attenuation_distance = source.attenuation_distance
  ignore(
    self.attenuation_color.unwrap().copy(source.attenuation_color.unwrap()),
  )
  self.specular_intensity = source.specular_intensity
  self.specular_intensity_map = source.specular_intensity_map
  ignore(self.specular_color.unwrap().copy(source.specular_color.unwrap()))
  self.specular_color_map = source.specular_color_map
}

///|
/// Upstream's `reflectivity`: use this, as `MeshPhysicalMaterial` derives it from `ior`.
pub fn Material::reflectivity(self : Material) -> Double? {
  match self.material_type {
    MeshPhysicalMaterial => {
      let ior = self.ior.unwrap()
      Some(@math.clamp(2.5 * (ior - 1.0) / (ior + 1.0), 0.0, 1.0))
    }
    _ => self.reflectivity
  }
}

///|
/// The other classes have a plain `reflectivity` property.
pub fn Material::set_reflectivity(
  self : Material,
  reflectivity : Double,
) -> Unit {
  match self.material_type {
    MeshPhysicalMaterial =>
      self.ior = Some((1.0 + 0.4 * reflectivity) / (1.0 - 0.4 * reflectivity))
    _ => self.reflectivity = Some(reflectivity)
  }
}

///|
/// The check of the accessors below. The other classes have plain properties.
fn Material::physical_version_check(
  self : Material,
  current : Double?,
  value : Double,
) -> Unit {
  // node materials made with MeshPhysicalMaterial's defaults (MeshPhysicalNodeMaterial)
  // have its accessors too
  if (
      self.material_type is MeshPhysicalMaterial ||
      self.has_extension_flag("isMeshPhysicalMaterial")
    ) &&
    (current is Some(current) && current > 0.0) != (value > 0.0) {
    self.version += 1
  }
}

///|
pub fn Material::anisotropy(self : Material) -> Double? {
  self._anisotropy
}

///|
pub fn Material::set_anisotropy(self : Material, value : Double) -> Unit {
  self.physical_version_check(self._anisotropy, value)
  self._anisotropy = Some(value)
}

///|
pub fn Material::clearcoat(self : Material) -> Double? {
  self._clearcoat
}

///|
pub fn Material::set_clearcoat(self : Material, value : Double) -> Unit {
  self.physical_version_check(self._clearcoat, value)
  self._clearcoat = Some(value)
}

///|
pub fn Material::diffuse_roughness(self : Material) -> Double? {
  self._diffuse_roughness
}

///|
pub fn Material::set_diffuse_roughness(self : Material, value : Double) -> Unit {
  self.physical_version_check(self._diffuse_roughness, value)
  self._diffuse_roughness = Some(value)
}

///|
pub fn Material::dispersion(self : Material) -> Double? {
  self._dispersion
}

///|
pub fn Material::set_dispersion(self : Material, value : Double) -> Unit {
  self.physical_version_check(self._dispersion, value)
  self._dispersion = Some(value)
}

///|
pub fn Material::iridescence(self : Material) -> Double? {
  self._iridescence
}

///|
pub fn Material::set_iridescence(self : Material, value : Double) -> Unit {
  self.physical_version_check(self._iridescence, value)
  self._iridescence = Some(value)
}

///|
pub fn Material::retroreflectivity(self : Material) -> Double? {
  self._retroreflectivity
}

///|
pub fn Material::set_retroreflectivity(self : Material, value : Double) -> Unit {
  self.physical_version_check(self._retroreflectivity, value)
  self._retroreflectivity = Some(value)
}

///|
pub fn Material::sheen(self : Material) -> Double? {
  self._sheen
}

///|
pub fn Material::set_sheen(self : Material, value : Double) -> Unit {
  self.physical_version_check(self._sheen, value)
  self._sheen = Some(value)
}

///|
pub fn Material::transmission(self : Material) -> Double? {
  self._transmission
}

///|
pub fn Material::set_transmission(self : Material, value : Double) -> Unit {
  self.physical_version_check(self._transmission, value)
  self._transmission = Some(value)
}
