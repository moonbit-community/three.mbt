// nodes/functions/ToonLightingModel.js: banded direct light, for MeshToonNodeMaterial.

///|
/// `getGradientIrradiance( { normal, lightDirection, builder } )`.
let toon_lighting_model_get_gradient_irradiance : Node = module_nodes(
  "nodes/functions/ToonLightingModel.js:getGradientIrradiance",
  fn() {
    fn_(fn(inputs, builder) {
      let normal = inputs.named("normal").unwrap()
      let light_direction = inputs.named("lightDirection").unwrap()
      let dot_nl = normal.dot(light_direction)
      let coord = vec2_of([dot_nl.mul(0.5).add(0.5), 0.0])
      if builder.material.unwrap().gradient_map is Some(_) {
        let get_uv = ContextGetUV::{ f: fn(_, _) { coord }, }
        let gradient_map = material_reference("gradientMap", "texture").context(
          value=node_context([("getUV", Other(@core.JsValue::of(get_uv)))]),
        )
        Some(vec3(gradient_map.r()))
      } else {
        let fw = coord.fwidth().mul(0.5)
        Some(
          mix(
            vec3(0.7),
            vec3(1.0),
            smoothstep(
              float(0.7).sub(fw.x()),
              float(0.7).add(fw.x()),
              coord.x(),
            ),
          ),
        )
      }
    })
  },
)

///|
pub(all) struct ToonLightingModel {}

///|
pub impl LightingModelClass for ToonLightingModel with fn class_name(_) {
  "ToonLightingModel"
}

///|
pub impl LightingModelClass for ToonLightingModel with fn direct(
  _,
  _,
  light_data,
  _,
) {
  let data = LightData::from_js(light_data)
  let light_direction = data.light_direction.unwrap()
  let light_color = data.light_color.unwrap()
  let reflected_light = data.reflected_light.unwrap()
  // `builder` is passed in the call object, as upstream does.
  let irradiance = toon_lighting_model_get_gradient_irradiance
    .call_named({ "normal": normal_view, "lightDirection": light_direction })
    .mul(light_color)
  reflected_light.direct_diffuse.add_assign(
    irradiance.mul(
      brdf_lambert.call_named({ "diffuseColor": diffuse_color.rgb() }),
    ),
  )
}

///|
pub impl LightingModelClass for ToonLightingModel with fn indirect(
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
/// `new ToonLightingModel()`.
pub fn ToonLightingModel::new() -> LightingModel {
  LightingModel::new(class_=ToonLightingModel::{ })
}
