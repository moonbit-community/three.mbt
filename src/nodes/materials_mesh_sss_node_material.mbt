// materials/nodes/MeshSSSNodeMaterial.js: MeshPhysicalNodeMaterial with a fast
// approximation of subsurface scattering.

///|
/// `SSSLightingModel`: the physical model plus scattering in `direct`.
pub(all) struct SSSLightingModel {
  physical : PhysicalLightingModel
  /// Whether the lighting model should use subsurface scattering.
  use_sss : Bool
}

///|
pub impl LightingModelClass for SSSLightingModel with fn class_name(_) {
  "SSSLightingModel"
}

///|
pub impl LightingModelClass for SSSLightingModel with fn parent(self) {
  Some(self.physical)
}

///|
/// `direct( { lightDirection, lightColor, reflectedLight }, builder )`.
pub impl LightingModelClass for SSSLightingModel with fn direct(
  self,
  model,
  light_data,
  builder,
) {
  let data = LightData::from_js(light_data)
  let light_direction = data.light_direction.unwrap()
  let light_color = data.light_color.unwrap()
  let reflected_light = data.reflected_light.unwrap()
  if self.use_sss == true {
    let material = node_material_builder_material(builder)
    let sss = match MeshSSSNodeMaterial::of(material) {
      Some(s) => s
      None => abort("TypeError: builder.material is not a MeshSSSNodeMaterial")
    }
    let thickness_color_node = sss.thickness_color_node
    let thickness_distortion_node = sss.thickness_distortion_node
    let thickness_ambient_node = sss.thickness_ambient_node
    let thickness_attenuation_node = sss.thickness_attenuation_node
    let thickness_power_node = sss.thickness_power_node
    let thickness_scale_node = sss.thickness_scale_node
    let scattering_half = light_direction
      .add(
        normal_view.mul(
          node_material_tsl_or_undefined(thickness_distortion_node),
        ),
      )
      .normalize()
    let scattering_dot = float(
      position_view_direction
      .dot(scattering_half.negate())
      .saturate()
      .pow(node_material_tsl_or_undefined(thickness_power_node))
      .mul(node_material_tsl_or_undefined(thickness_scale_node)),
    )
    let scattering_illu = vec3(
      scattering_dot
      .add(node_material_tsl_or_undefined(thickness_ambient_node))
      .mul(node_material_tsl_or_undefined(thickness_color_node)),
    )
    reflected_light.direct_diffuse.add_assign(
      scattering_illu.mul(
        node_material_required(thickness_attenuation_node).mul(light_color),
      ),
    )
  }
  self.physical.direct(model, light_data, builder)
}

///|
/// A node property of the material, `undefined` when unset.
fn node_material_tsl_or_undefined(node : Node?) -> TslValue {
  match node {
    Some(n) => Node(n)
    None => Null
  }
}

///|
fn node_material_required(node : Node?) -> Node {
  match node {
    Some(n) => n
    None => abort("TypeError: Cannot read properties of null (reading 'mul')")
  }
}

///|
/// `new SSSLightingModel( clearcoat, sheen, iridescence, anisotropy, transmission,
/// dispersion, sss )`.
pub fn SSSLightingModel::new(
  clearcoat~ : Bool = false,
  sheen~ : Bool = false,
  iridescence~ : Bool = false,
  anisotropy~ : Bool = false,
  transmission~ : Bool = false,
  dispersion~ : Bool = false,
  sss~ : Bool = false,
) -> LightingModel {
  LightingModel::new(class_=SSSLightingModel::{
    physical: PhysicalLightingModel::construct(
      clearcoat~,
      sheen~,
      iridescence~,
      anisotropy~,
      transmission~,
      dispersion~,
    ),
    use_sss: sss,
  })
}

///|
pub(all) struct MeshSSSNodeMaterial {
  physical : MeshPhysicalNodeMaterial
  /// The thickness color (`null` disables scattering).
  mut thickness_color_node : Node?
  mut thickness_distortion_node : Node?
  mut thickness_ambient_node : Node?
  mut thickness_attenuation_node : Node?
  mut thickness_power_node : Node?
  mut thickness_scale_node : Node?
}

///|
pub impl NodeMaterialClass for MeshSSSNodeMaterial with fn class_name(_) {
  "MeshSSSNodeMaterial"
}

///|
pub impl NodeMaterialClass for MeshSSSNodeMaterial with fn parent(self) {
  Some(self.physical)
}

///|
pub impl NodeMaterialClass for MeshSSSNodeMaterial with fn has_flag(self, flag) {
  match flag {
    "useSSS" => self.use_sss()
    _ => self.physical.has_flag(flag)
  }
}

///|
pub impl NodeMaterialClass for MeshSSSNodeMaterial with fn construct(_) {
  MeshSSSNodeMaterial::new()
}

///|
fn MeshSSSNodeMaterial::own_slots(
  self : MeshSSSNodeMaterial,
) -> Array[(String, Node?)] {
  [
    ("thicknessColorNode", self.thickness_color_node),
    ("thicknessDistortionNode", self.thickness_distortion_node),
    ("thicknessAmbientNode", self.thickness_ambient_node),
    ("thicknessAttenuationNode", self.thickness_attenuation_node),
    ("thicknessPowerNode", self.thickness_power_node),
    ("thicknessScaleNode", self.thickness_scale_node),
  ]
}

///|
pub impl NodeMaterialClass for MeshSSSNodeMaterial with fn node_slot(self, name) {
  for slot in self.own_slots() {
    if slot.0 == name {
      return Some(slot.1)
    }
  }
  self.physical.node_slot(name)
}

///|
pub impl NodeMaterialClass for MeshSSSNodeMaterial with fn own_node_slots(
  self,
  out,
) {
  self.physical.own_node_slots(out)
  out.append(self.own_slots())
}

///|
pub impl NodeMaterialClass for MeshSSSNodeMaterial with fn set_node_slot(
  self,
  name,
  value,
) {
  match name {
    "thicknessColorNode" => self.thickness_color_node = value
    "thicknessDistortionNode" => self.thickness_distortion_node = value
    "thicknessAmbientNode" => self.thickness_ambient_node = value
    "thicknessAttenuationNode" => self.thickness_attenuation_node = value
    "thicknessPowerNode" => self.thickness_power_node = value
    "thicknessScaleNode" => self.thickness_scale_node = value
    _ => return self.physical.set_node_slot(name, value)
  }
  true
}

///|
pub impl NodeMaterialClass for MeshSSSNodeMaterial with fn get_property(
  self,
  material,
  name,
) {
  match name {
    "useSSS" => Some(Bool(self.use_sss()))
    _ =>
      for slot in self.own_slots() {
        if slot.0 == name {
          break Some(node_material_slot_value(slot.1))
        }
      } nobreak {
        self.physical.get_property(material, name)
      }
  }
}

///|
/// `get useSSS()`.
pub fn MeshSSSNodeMaterial::use_sss(self : MeshSSSNodeMaterial) -> Bool {
  self.thickness_color_node is Some(_)
}

///|
pub impl NodeMaterialClass for MeshSSSNodeMaterial with fn setup_lighting_model(
  self,
  _,
  _,
) {
  let p = self.physical
  Some(
    SSSLightingModel::new(
      clearcoat=p.use_clearcoat(),
      sheen=p.use_sheen(),
      iridescence=p.use_iridescence(),
      anisotropy=p.use_anisotropy(),
      transmission=p.use_transmission(),
      dispersion=p.use_dispersion(),
      sss=self.use_sss(),
    ),
  )
}

///|
/// `new MeshSSSNodeMaterial()`.
pub fn MeshSSSNodeMaterial::new() -> @core.Material {
  let physical = MeshPhysicalNodeMaterial::construct()
  let payload = MeshSSSNodeMaterial::{
    physical,
    thickness_color_node: None,
    thickness_distortion_node: None,
    thickness_ambient_node: None,
    thickness_attenuation_node: None,
    thickness_power_node: None,
    thickness_scale_node: None,
  }
  let material = NodeMaterial::create(payload)
  MeshPhysicalNodeMaterial::init(material, physical)
  payload.thickness_distortion_node = Some(float(0.1))
  payload.thickness_ambient_node = Some(float(0.0))
  payload.thickness_attenuation_node = Some(float(0.1))
  payload.thickness_power_node = Some(float(2.0))
  payload.thickness_scale_node = Some(float(10.0))
  material
}

///|
pub fn MeshSSSNodeMaterial::of(
  material : @core.Material,
) -> MeshSSSNodeMaterial? {
  match NodeMaterial::class_payload(material, "MeshSSSNodeMaterial") {
    Some(p) => Some(p.cast())
    None => None
  }
}
