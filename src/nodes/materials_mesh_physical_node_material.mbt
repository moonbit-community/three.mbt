// materials/nodes/MeshPhysicalNodeMaterial.js

///|
let mesh_physical_node_material_defaults : @core.Material = @core.MeshPhysicalMaterial::new()

///|
pub(all) struct MeshPhysicalNodeMaterial {
  standard : MeshStandardNodeMaterial
  mut clearcoat_node : Node?
  mut clearcoat_roughness_node : Node?
  mut diffuse_roughness_node : Node?
  mut clearcoat_normal_node : Node?
  mut sheen_node : Node?
  mut sheen_roughness_node : Node?
  mut iridescence_node : Node?
  mut iridescence_ior_node : Node?
  mut iridescence_thickness_node : Node?
  mut specular_intensity_node : Node?
  mut specular_color_node : Node?
  mut ior_node : Node?
  mut transmission_node : Node?
  mut thickness_node : Node?
  mut attenuation_distance_node : Node?
  mut attenuation_color_node : Node?
  mut dispersion_node : Node?
  mut retroreflectivity_node : Node?
  mut anisotropy_node : Node?
  /// The material this payload belongs to, for the `use*` getters.
  mut _material : @core.Material?
}

///|
pub impl NodeMaterialClass for MeshPhysicalNodeMaterial with fn class_name(_) {
  "MeshPhysicalNodeMaterial"
}

///|
pub impl NodeMaterialClass for MeshPhysicalNodeMaterial with fn parent(self) {
  Some(self.standard)
}

///|
pub impl NodeMaterialClass for MeshPhysicalNodeMaterial with fn has_flag(
  self,
  flag,
) {
  match flag {
    "isMeshPhysicalNodeMaterial" | "isMeshPhysicalMaterial" => true
    "useClearcoat" => self.use_clearcoat()
    "useDiffuseRoughness" => self.use_diffuse_roughness()
    "useIridescence" => self.use_iridescence()
    "useSheen" => self.use_sheen()
    "useAnisotropy" => self.use_anisotropy()
    "useTransmission" => self.use_transmission()
    "useDispersion" => self.use_dispersion()
    "useRetroreflection" => self.use_retroreflection()
    _ => self.standard.has_flag(flag)
  }
}

///|
pub impl NodeMaterialClass for MeshPhysicalNodeMaterial with fn construct(_) {
  MeshPhysicalNodeMaterial::new()
}

///|
fn MeshPhysicalNodeMaterial::own_slots(
  self : MeshPhysicalNodeMaterial,
) -> Array[(String, Node?)] {
  [
    ("clearcoatNode", self.clearcoat_node),
    ("clearcoatRoughnessNode", self.clearcoat_roughness_node),
    ("diffuseRoughnessNode", self.diffuse_roughness_node),
    ("clearcoatNormalNode", self.clearcoat_normal_node),
    ("sheenNode", self.sheen_node),
    ("sheenRoughnessNode", self.sheen_roughness_node),
    ("iridescenceNode", self.iridescence_node),
    ("iridescenceIORNode", self.iridescence_ior_node),
    ("iridescenceThicknessNode", self.iridescence_thickness_node),
    ("specularIntensityNode", self.specular_intensity_node),
    ("specularColorNode", self.specular_color_node),
    ("iorNode", self.ior_node),
    ("transmissionNode", self.transmission_node),
    ("thicknessNode", self.thickness_node),
    ("attenuationDistanceNode", self.attenuation_distance_node),
    ("attenuationColorNode", self.attenuation_color_node),
    ("dispersionNode", self.dispersion_node),
    ("retroreflectivityNode", self.retroreflectivity_node),
    ("anisotropyNode", self.anisotropy_node),
  ]
}

///|
pub impl NodeMaterialClass for MeshPhysicalNodeMaterial with fn node_slot(
  self,
  name,
) {
  for slot in self.own_slots() {
    if slot.0 == name {
      return Some(slot.1)
    }
  }
  self.standard.node_slot(name)
}

///|
pub impl NodeMaterialClass for MeshPhysicalNodeMaterial with fn own_node_slots(
  self,
  out,
) {
  self.standard.own_node_slots(out)
  out.append(self.own_slots())
}

///|
pub impl NodeMaterialClass for MeshPhysicalNodeMaterial with fn set_node_slot(
  self,
  name,
  value,
) {
  match name {
    "clearcoatNode" => self.clearcoat_node = value
    "clearcoatRoughnessNode" => self.clearcoat_roughness_node = value
    "diffuseRoughnessNode" => self.diffuse_roughness_node = value
    "clearcoatNormalNode" => self.clearcoat_normal_node = value
    "sheenNode" => self.sheen_node = value
    "sheenRoughnessNode" => self.sheen_roughness_node = value
    "iridescenceNode" => self.iridescence_node = value
    "iridescenceIORNode" => self.iridescence_ior_node = value
    "iridescenceThicknessNode" => self.iridescence_thickness_node = value
    "specularIntensityNode" => self.specular_intensity_node = value
    "specularColorNode" => self.specular_color_node = value
    "iorNode" => self.ior_node = value
    "transmissionNode" => self.transmission_node = value
    "thicknessNode" => self.thickness_node = value
    "attenuationDistanceNode" => self.attenuation_distance_node = value
    "attenuationColorNode" => self.attenuation_color_node = value
    "dispersionNode" => self.dispersion_node = value
    "retroreflectivityNode" => self.retroreflectivity_node = value
    "anisotropyNode" => self.anisotropy_node = value
    _ => return self.standard.set_node_slot(name, value)
  }
  true
}

///|
pub impl NodeMaterialClass for MeshPhysicalNodeMaterial with fn get_property(
  self,
  material,
  name,
) {
  match name {
    "useClearcoat"
    | "useDiffuseRoughness"
    | "useIridescence"
    | "useSheen"
    | "useAnisotropy"
    | "useTransmission"
    | "useDispersion"
    | "useRetroreflection" => Some(Bool(self.has_flag(name)))
    _ =>
      for slot in self.own_slots() {
        if slot.0 == name {
          break Some(node_material_slot_value(slot.1))
        }
      } nobreak {
        self.standard.get_property(material, name)
      }
  }
}

///|
/// The physical accessors of `copy( source )` (`anisotropy`, `clearcoat`, ...), which
/// bump the version when a value crosses zero.
pub impl NodeMaterialClass for MeshPhysicalNodeMaterial with fn copy_members(
  self,
  material,
  source,
) {
  self.standard.copy_members(material, source)
  if source.anisotropy() is Some(v) {
    material.set_anisotropy(v)
  }
  if source.clearcoat() is Some(v) {
    material.set_clearcoat(v)
  }
  if source.diffuse_roughness() is Some(v) {
    material.set_diffuse_roughness(v)
  }
  if source.iridescence() is Some(v) {
    material.set_iridescence(v)
  }
  if source.dispersion() is Some(v) {
    material.set_dispersion(v)
  }
  if source.retroreflectivity() is Some(v) {
    material.set_retroreflectivity(v)
  }
  if source.sheen() is Some(v) {
    material.set_sheen(v)
  }
  if source.transmission() is Some(v) {
    material.set_transmission(v)
  }
}

///|
fn MeshPhysicalNodeMaterial::material(
  self : MeshPhysicalNodeMaterial,
) -> @core.Material {
  self._material.unwrap()
}

///|
fn node_material_positive(value : Double?) -> Bool {
  match value {
    Some(v) => v > 0.0
    None => false
  }
}

///|
/// `get useClearcoat()`.
pub fn MeshPhysicalNodeMaterial::use_clearcoat(
  self : MeshPhysicalNodeMaterial,
) -> Bool {
  node_material_positive(self.material().clearcoat()) ||
  self.clearcoat_node is Some(_)
}

///|
/// `get useDiffuseRoughness()`.
pub fn MeshPhysicalNodeMaterial::use_diffuse_roughness(
  self : MeshPhysicalNodeMaterial,
) -> Bool {
  node_material_positive(self.material().diffuse_roughness()) ||
  self.diffuse_roughness_node is Some(_)
}

///|
/// `get useIridescence()`.
pub fn MeshPhysicalNodeMaterial::use_iridescence(
  self : MeshPhysicalNodeMaterial,
) -> Bool {
  node_material_positive(self.material().iridescence()) ||
  self.iridescence_node is Some(_)
}

///|
/// `get useSheen()`.
pub fn MeshPhysicalNodeMaterial::use_sheen(
  self : MeshPhysicalNodeMaterial,
) -> Bool {
  node_material_positive(self.material().sheen()) || self.sheen_node is Some(_)
}

///|
/// `get useAnisotropy()`.
pub fn MeshPhysicalNodeMaterial::use_anisotropy(
  self : MeshPhysicalNodeMaterial,
) -> Bool {
  node_material_positive(self.material().anisotropy()) ||
  self.anisotropy_node is Some(_)
}

///|
/// `get useTransmission()`.
pub fn MeshPhysicalNodeMaterial::use_transmission(
  self : MeshPhysicalNodeMaterial,
) -> Bool {
  node_material_positive(self.material().transmission()) ||
  self.transmission_node is Some(_)
}

///|
/// `get useDispersion()`.
pub fn MeshPhysicalNodeMaterial::use_dispersion(
  self : MeshPhysicalNodeMaterial,
) -> Bool {
  node_material_positive(self.material().dispersion()) ||
  self.dispersion_node is Some(_)
}

///|
/// `get useRetroreflection()`.
pub fn MeshPhysicalNodeMaterial::use_retroreflection(
  self : MeshPhysicalNodeMaterial,
) -> Bool {
  node_material_positive(self.material().retroreflectivity()) ||
  self.retroreflectivity_node is Some(_)
}

///|
pub impl NodeMaterialClass for MeshPhysicalNodeMaterial with fn setup_specular(
  self,
  _,
) {
  let ior_node = match self.ior_node {
    Some(n) => float(n)
    None => material_ior
  }
  let specular_color_node = match self.specular_color_node {
    Some(n) => vec3(n)
    None => material_specular_color
  }
  let specular_intensity_node = match self.specular_intensity_node {
    Some(n) => float(n)
    None => material_specular_intensity
  }
  ior.assign(ior_node)
  specular_color.assign(
    min(
      pow2(ior.sub(1.0).div(ior.add(1.0))).mul(specular_color_node),
      vec3(1.0),
    ).mul(specular_intensity_node),
  )
  specular_color_blended.assign(
    mix(specular_color, diffuse_color.rgb(), metalness),
  )
  specular_f90.assign(mix(specular_intensity_node, 1.0, metalness))
}

///|
pub impl NodeMaterialClass for MeshPhysicalNodeMaterial with fn setup_lighting_model(
  self,
  _,
  _,
) {
  Some(
    PhysicalLightingModel::new(
      clearcoat=self.use_clearcoat(),
      sheen=self.use_sheen(),
      iridescence=self.use_iridescence(),
      anisotropy=self.use_anisotropy(),
      transmission=self.use_transmission(),
      dispersion=self.use_dispersion(),
      retroreflection=self.use_retroreflection(),
      diffuse_roughness=self.use_diffuse_roughness(),
    ),
  )
}

///|
pub impl NodeMaterialClass for MeshPhysicalNodeMaterial with fn setup_variants(
  self,
  material,
  _,
) {
  self.standard.setup_variants_base(material)

  // DIFFUSE ROUGHNESS
  if self.use_diffuse_roughness() {
    let diffuse_roughness_node = match self.diffuse_roughness_node {
      Some(n) => float(n)
      None => material_diffuse_roughness
    }
    diffuse_roughness.assign(diffuse_roughness_node.clamp())
  }

  // CLEARCOAT
  if self.use_clearcoat() {
    let clearcoat_node = match self.clearcoat_node {
      Some(n) => float(n)
      None => material_clearcoat
    }
    let clearcoat_roughness_node = match self.clearcoat_roughness_node {
      Some(n) => float(n)
      None => material_clearcoat_roughness
    }
    clearcoat.assign(clearcoat_node)
    clearcoat_roughness.assign(
      get_roughness.call_named({ "roughness": clearcoat_roughness_node }),
    )
  }

  // SHEEN
  if self.use_sheen() {
    let sheen_node = match self.sheen_node {
      Some(n) => vec3(n)
      None => material_sheen
    }
    let sheen_roughness_node = match self.sheen_roughness_node {
      Some(n) => float(n)
      None => material_sheen_roughness
    }
    sheen.assign(sheen_node)
    sheen_roughness.assign(sheen_roughness_node)
  }

  // RETROREFLECTION
  if self.use_retroreflection() {
    let retroreflectivity_node = match self.retroreflectivity_node {
      Some(n) => float(n)
      None => material_retroreflectivity
    }
    retroreflectivity.assign(retroreflectivity_node)
  }

  // IRIDESCENCE
  if self.use_iridescence() {
    let iridescence_node = match self.iridescence_node {
      Some(n) => float(n)
      None => material_iridescence
    }
    let iridescence_ior_node = match self.iridescence_ior_node {
      Some(n) => float(n)
      None => material_iridescence_ior
    }
    let iridescence_thickness_node = match self.iridescence_thickness_node {
      Some(n) => float(n)
      None => material_iridescence_thickness
    }
    iridescence.assign(iridescence_node)
    iridescence_ior.assign(iridescence_ior_node)
    iridescence_thickness.assign(iridescence_thickness_node)
  }

  // ANISOTROPY
  if self.use_anisotropy() {
    let anisotropy_v = (match self.anisotropy_node {
      Some(n) => vec2(n)
      None => material_anisotropy
    }).to_var()
    anisotropy.assign(anisotropy_v.length())
    if_(anisotropy.equal(0.0), fn() { anisotropy_v.assign(vec2_of([1.0, 0.0])) }).else_(fn() {
        anisotropy_v.div_assign(vec2(anisotropy))
        anisotropy.assign(anisotropy.saturate())
      },
    )
    // Roughness along the anisotropy bitangent is the material roughness, while the
    // tangent roughness increases with anisotropy.
    alpha_t.assign(anisotropy.pow2().mix(roughness.pow2(), 1.0))
    anisotropy_t.assign(
      tbn_view_matrix[0]
      .mul(anisotropy_v.x())
      .add(tbn_view_matrix[1].mul(anisotropy_v.y())),
    )
    anisotropy_b.assign(
      tbn_view_matrix[1]
      .mul(anisotropy_v.x())
      .sub(tbn_view_matrix[0].mul(anisotropy_v.y())),
    )
  }

  // TRANSMISSION
  if self.use_transmission() {
    let transmission_node = match self.transmission_node {
      Some(n) => float(n)
      None => material_transmission
    }
    let thickness_node = match self.thickness_node {
      Some(n) => float(n)
      None => material_thickness
    }
    let attenuation_distance_node = match self.attenuation_distance_node {
      Some(n) => float(n)
      None => material_attenuation_distance
    }
    let attenuation_color_node = match self.attenuation_color_node {
      Some(n) => vec3(n)
      None => material_attenuation_color
    }
    transmission.assign(transmission_node)
    thickness.assign(thickness_node)
    attenuation_distance.assign(attenuation_distance_node)
    attenuation_color.assign(attenuation_color_node)
    if self.use_dispersion() {
      let dispersion_node = match self.dispersion_node {
        Some(n) => float(n)
        None => material_dispersion
      }
      dispersion.assign(dispersion_node)
    }
  }
}

///|
/// `setupClearcoatNormal()`.
pub fn MeshPhysicalNodeMaterial::setup_clearcoat_normal(
  self : MeshPhysicalNodeMaterial,
) -> Node {
  match self.clearcoat_normal_node {
    Some(n) => vec3(n)
    None => material_clearcoat_normal
  }
}

///|
pub impl NodeMaterialClass for MeshPhysicalNodeMaterial with fn setup(
  self,
  material,
  builder,
) {
  builder.context.set(
    "setupClearcoatNormal",
    node_material_context_setup(fn() {
      sub_build(self.setup_clearcoat_normal(), "NORMAL", type_="vec3")
    }),
  )
  self.standard.setup(material, builder)
}

///|
/// The payload of a new `MeshPhysicalNodeMaterial`, for subclasses.
pub fn MeshPhysicalNodeMaterial::construct() -> MeshPhysicalNodeMaterial {
  {
    standard: MeshStandardNodeMaterial::construct(),
    clearcoat_node: None,
    clearcoat_roughness_node: None,
    diffuse_roughness_node: None,
    clearcoat_normal_node: None,
    sheen_node: None,
    sheen_roughness_node: None,
    iridescence_node: None,
    iridescence_ior_node: None,
    iridescence_thickness_node: None,
    specular_intensity_node: None,
    specular_color_node: None,
    ior_node: None,
    transmission_node: None,
    thickness_node: None,
    attenuation_distance_node: None,
    attenuation_color_node: None,
    dispersion_node: None,
    retroreflectivity_node: None,
    anisotropy_node: None,
    _material: None,
  }
}

///|
/// The constructor body: `super()`'s, then `setDefaultValues` of the physical
/// defaults.
pub fn MeshPhysicalNodeMaterial::init(
  material : @core.Material,
  payload : MeshPhysicalNodeMaterial,
) -> Unit {
  payload._material = Some(material)
  MeshStandardNodeMaterial::init(material)
  NodeMaterial::set_default_values(
    material, mesh_physical_node_material_defaults,
  )
}

///|
/// `new MeshPhysicalNodeMaterial()`.
pub fn MeshPhysicalNodeMaterial::new() -> @core.Material {
  let payload = MeshPhysicalNodeMaterial::construct()
  let material = NodeMaterial::create(payload)
  MeshPhysicalNodeMaterial::init(material, payload)
  material
}

///|
pub fn MeshPhysicalNodeMaterial::of(
  material : @core.Material,
) -> MeshPhysicalNodeMaterial? {
  match NodeMaterial::class_payload(material, "MeshPhysicalNodeMaterial") {
    Some(p) => Some(p.cast())
    None => None
  }
}
