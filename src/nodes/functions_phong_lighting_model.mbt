// nodes/functions/PhongLightingModel.js: Blinn-Phong direct light, for
// MeshPhongNodeMaterial and (without specular) MeshLambertNodeMaterial.

///|
/// `G_BlinnPhong_Implicit()`.
fn phong_lighting_model_g_blinn_phong_implicit() -> Node {
  float(0.25)
}

///|
/// `D_BlinnPhong( { dotNH } )`.
let phong_lighting_model_d_blinn_phong : Node = module_nodes(
  "nodes/functions/PhongLightingModel.js:D_BlinnPhong",
  fn() {
    fn_(fn(inputs, _) {
      let dot_nh = inputs.named("dotNH").unwrap()
      Some(
        shininess
        .mul(float(0.5))
        .add(1.0)
        .mul(float(1.0 / bsdf_pi))
        .mul(dot_nh.pow(shininess)),
      )
    })
  },
)

///|
/// `BRDF_BlinnPhong( { lightDirection } )`.
let phong_lighting_model_brdf_blinn_phong : Node = module_nodes(
  "nodes/functions/PhongLightingModel.js:BRDF_BlinnPhong",
  fn() {
    fn_(fn(inputs, _) {
      let light_direction = inputs.named("lightDirection").unwrap()
      let half_dir = light_direction.add(position_view_direction).normalize()
      let dot_nh = normal_view.dot(half_dir).clamp()
      let dot_vh = position_view_direction.dot(half_dir).clamp()
      let f = f_schlick.call_named({
        "f0": specular_color,
        "f90": 1.0,
        "dotVH": dot_vh,
      })
      let g = phong_lighting_model_g_blinn_phong_implicit()
      let d = phong_lighting_model_d_blinn_phong.call_named({ "dotNH": dot_nh })
      Some(f.mul(g).mul(d))
    })
  },
)

///|
pub(all) struct PhongLightingModel {
  basic : BasicLightingModel
  mut specular : Bool
}

///|
pub impl LightingModelClass for PhongLightingModel with fn class_name(_) {
  "PhongLightingModel"
}

///|
pub impl LightingModelClass for PhongLightingModel with fn parent(self) {
  Some(self.basic)
}

///|
pub impl LightingModelClass for PhongLightingModel with fn direct(
  self,
  _,
  light_data,
  _,
) {
  let data = LightData::from_js(light_data)
  let light_direction = data.light_direction.unwrap()
  let light_color = data.light_color.unwrap()
  let reflected_light = data.reflected_light.unwrap()
  let dot_nl = normal_view.dot(light_direction).clamp()
  let irradiance = dot_nl.mul(light_color)
  reflected_light.direct_diffuse.add_assign(
    irradiance.mul(
      brdf_lambert.call_named({ "diffuseColor": diffuse_color.rgb() }),
    ),
  )
  if self.specular == true {
    reflected_light.direct_specular.add_assign(
      irradiance
      .mul(
        phong_lighting_model_brdf_blinn_phong.call_named({
          "lightDirection": light_direction,
        }),
      )
      .mul(material_specular_strength),
    )
  }
}

///|
pub impl LightingModelClass for PhongLightingModel with fn indirect(
  _,
  _,
  builder,
) {
  let context = builder.context
  let ambient_occlusion = context.get_node("ambientOcclusion").unwrap()
  let irradiance = context.get_node("irradiance").unwrap()
  let reflected_light = NodeContext::reflected_light(context).unwrap()
  reflected_light.indirect_diffuse.add_assign(
    irradiance.mul(brdf_lambert.call_named({ "diffuseColor": diffuse_color })),
  )
  reflected_light.indirect_diffuse.mul_assign(ambient_occlusion)
}

///|
/// `new PhongLightingModel( specular = true )`.
pub fn PhongLightingModel::new(specular~ : Bool = true) -> LightingModel {
  LightingModel::new(class_=PhongLightingModel::{
    basic: BasicLightingModel::{ },
    specular,
  })
}

///|
pub fn PhongLightingModel::of(model : LightingModel) -> PhongLightingModel? {
  match model.class_payload("PhongLightingModel") {
    Some(p) => Some(p.cast())
    None => None
  }
}
