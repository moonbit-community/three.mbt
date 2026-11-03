// nodes/functions/BasicLightingModel.js: baked indirect light and environment
// mapping, for MeshBasicNodeMaterial.

///|
pub(all) struct BasicLightingModel {}

///|
pub impl LightingModelClass for BasicLightingModel with fn class_name(_) {
  "BasicLightingModel"
}

///|
pub impl LightingModelClass for BasicLightingModel with fn indirect(
  _,
  _,
  builder,
) {
  let context = builder.context
  let ambient_occlusion = context.get_node("ambientOcclusion").unwrap()
  let reflected_light = NodeContext::reflected_light(context).unwrap()
  let irradiance_light_map = context.get_node("irradianceLightMap")
  reflected_light.indirect_diffuse.assign(vec4(0.0))
  match irradiance_light_map {
    Some(map) => reflected_light.indirect_diffuse.add_assign(map)
    None =>
      reflected_light.indirect_diffuse.add_assign(vec4_of([1.0, 1.0, 1.0, 0.0]))
  }
  reflected_light.indirect_diffuse.mul_assign(ambient_occlusion)
  reflected_light.indirect_diffuse.mul_assign(diffuse_color.rgb())
}

///|
pub impl LightingModelClass for BasicLightingModel with fn finish(_, _, builder) {
  let material = builder.material.unwrap()
  let context = builder.context
  let outgoing_light = context.get_node("outgoingLight").unwrap()
  guard context.get_node("environment") is Some(env_node) else { return }
  match material.combine {
    Some(c) if c == @core.MultiplyOperation =>
      outgoing_light
      .rgb()
      .assign(
        mix(
          outgoing_light.rgb(),
          outgoing_light.rgb().mul(env_node.rgb()),
          material_specular_strength.mul(material_reflectivity),
        ),
      )
    Some(c) if c == @core.MixOperation =>
      outgoing_light
      .rgb()
      .assign(
        mix(
          outgoing_light.rgb(),
          env_node.rgb(),
          material_specular_strength.mul(material_reflectivity),
        ),
      )
    Some(c) if c == @core.AddOperation =>
      outgoing_light
      .rgb()
      .add_assign(
        env_node
        .rgb()
        .mul(material_specular_strength.mul(material_reflectivity)),
      )
    combine => {
      let value = match combine {
        Some(c) => c.to_string()
        None => "undefined"
      }
      @core.warn("BasicLightingModel: Unsupported .combine value: \{value}")
    }
  }
}

///|
/// `new BasicLightingModel()`.
pub fn BasicLightingModel::new() -> LightingModel {
  LightingModel::new(class_=BasicLightingModel::{ })
}

///|
pub fn BasicLightingModel::of(model : LightingModel) -> BasicLightingModel? {
  match model.class_payload("BasicLightingModel") {
    Some(p) => Some(p.cast())
    None => None
  }
}
