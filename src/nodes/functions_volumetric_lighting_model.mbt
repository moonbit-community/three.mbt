// nodes/functions/VolumetricLightingModel.js: ray-marched scattering, for
// VolumeNodeMaterial.

///|
let volumetric_scattering_density : Node = module_nodes(
  "nodes/functions/VolumetricLightingModel.js:scatteringDensity",
  fn() { property("vec3") },
)

///|
let volumetric_linear_depth_ray : Node = module_nodes(
  "nodes/functions/VolumetricLightingModel.js:linearDepthRay",
  fn() { property("float") },
)

///|
let volumetric_outgoing_ray_light : Node = module_nodes(
  "nodes/functions/VolumetricLightingModel.js:outgoingRayLight",
  fn() { property("vec3") },
)

///|
/// The `VolumeNodeMaterial` members the model reads (`steps`, `offsetNode`,
/// `scatteringNode`, `scatteringEmissiveNode`), read when used. The materials group
/// registers them for each volume material with `register_volume_material`.
pub(all) struct VolumeMaterialProperties {
  steps : () -> Double
  offset_node : () -> Node?
  scattering_node : () -> Node?
  scattering_emissive_node : () -> Node?
}

///|
let volumetric_materials : @webgl.WeakMap[
  @core.Material,
  VolumeMaterialProperties,
] = @webgl.WeakMap::new()

///|
/// Makes the volume members of `material` visible to `VolumetricLightingModel`.
pub fn register_volume_material(
  material : @core.Material,
  properties : VolumeMaterialProperties,
) -> Unit {
  volumetric_materials.set(material, properties)
}

///|
/// The volume members of a material; `undefined` ones for other materials.
fn volumetric_material_properties(
  material : @core.Material,
) -> VolumeMaterialProperties {
  match volumetric_materials.get(material) {
    Some(p) => p
    None =>
      {
        steps: fn() { abort("unreachable: steps of a non-volume material") },
        offset_node: fn() { None },
        scattering_node: fn() { None },
        scattering_emissive_node: fn() { None },
      }
  }
}

///|
pub(all) struct VolumetricLightingModel {}

///|
pub impl LightingModelClass for VolumetricLightingModel with fn class_name(_) {
  "VolumetricLightingModel"
}

///|
pub impl LightingModelClass for VolumetricLightingModel with fn start(
  _,
  model,
  builder,
) {
  let material = builder.material.unwrap()
  let volume = volumetric_material_properties(material)
  let start_pos = property("vec3")
  let end_pos = property("vec3")
  let is_front_to_back = property("bool")
  if_(
    camera_position
    .sub(position_world)
    .length()
    .greater_than(model_radius.mul(2)),
    fn() {
      start_pos.assign(camera_position)
      end_pos.assign(position_world)
      is_front_to_back.assign(true)
    },
  ).else_(fn() {
    start_pos.assign(position_world)
    end_pos.assign(camera_position)
    is_front_to_back.assign(false)
  })
  let view_vector = end_pos.sub(start_pos)
  let steps = uniform("int").on_render_update(fn(n, frame) {
    match frame.material {
      Some(m) =>
        match volumetric_materials.get(m) {
          Some(p) => InputNode::set_value(n, Number((p.steps)()))
          None => InputNode::set_value(n, Undefined)
        }
      None =>
        abort("TypeError: Cannot read properties of null (reading 'steps')")
    }
    None
  })
  let step_size = view_vector.length().div(steps).to_var()
  let ray_dir = view_vector.normalize().to_var()
  let dist_travelled = float(0.0).to_var()
  let transmittance = vec3(1).to_var()
  if (volume.offset_node)() is Some(offset_node) {
    dist_travelled.add_assign(offset_node.mul(step_size))
  }
  loop_([steps], fn(_) {
    let position_ray = start_pos.add(ray_dir.mul(dist_travelled))
    let position_view_ray = camera_view_matrix
      .mul(vec4_of([position_ray, 1]))
      .xyz()
    if NodeMaterial::of(material).unwrap().depth_node is Some(depth_node) {
      volumetric_linear_depth_ray.assign(
        linear_depth(
          value_node=view_z_to_perspective_depth(
            position_view_ray.z(),
            camera_near,
            camera_far,
          ),
        ),
      )
      builder.context.set(
        "sceneDepthNode",
        Node(linear_depth(value_node=depth_node).to_var()),
      )
    }
    builder.context.set("positionWorld", Node(position_ray))
    builder.context.set("shadowPositionWorld", Node(position_ray))
    builder.context.set("positionView", Node(position_view_ray))
    volumetric_scattering_density.assign(0)
    let scattering_node = match (volume.scattering_node)() {
      Some(f) => Some(f.call_named({ "positionRay": position_ray }))
      None => None
    }
    let scattering_emissive_node = match (volume.scattering_emissive_node)() {
      Some(f) => Some(f.call_named({ "positionRay": position_ray }))
      None => None
    }
    model.start_base(builder)
    if scattering_node is Some(scattering_node) {
      volumetric_scattering_density.mul_assign(scattering_node)
    }
    let step_light = volumetric_scattering_density.mul(0.01).to_var()
    if scattering_emissive_node is Some(scattering_emissive_node) {
      step_light.add_assign(scattering_emissive_node.mul(0.01))
    }
    let falloff = volumetric_scattering_density
      .mul(0.01)
      .negate()
      .mul(step_size)
      .exp()
    if_(is_front_to_back, fn() {
      volumetric_outgoing_ray_light.add_assign(
        step_light.mul(transmittance).mul(step_size),
      )
    }).else_(fn() {
      volumetric_outgoing_ray_light.assign(
        volumetric_outgoing_ray_light
        .mul(falloff)
        .add(step_light.mul(step_size)),
      )
    })
    transmittance.mul_assign(falloff)
    dist_travelled.add_assign(step_size)
  })
}

///|
/// `scatteringLight( lightColor, builder )`.
fn VolumetricLightingModel::scattering_light(
  light_color : Node,
  builder : NodeBuilder,
) -> Unit {
  match builder.context.get_node("sceneDepthNode") {
    Some(scene_depth_node) =>
      if_(scene_depth_node.greater_than_equal(volumetric_linear_depth_ray), fn() {
        volumetric_scattering_density.add_assign(light_color)
      })
      |> ignore
    None => volumetric_scattering_density.add_assign(light_color)
  }
}

///|
pub impl LightingModelClass for VolumetricLightingModel with fn direct(
  _,
  _,
  light_data,
  builder,
) {
  let data = LightData::from_js(light_data)
  let light_node = data.light_node.unwrap()
  let light_color = data.light_color.unwrap()
  // non-analytic lights and lights without a distance (infinitely far) are ignored
  guard AnalyticLightNode::of(light_node) is Some(analytic) else { return }
  match analytic.light.unwrap().as_light().kind {
    PointLight(_) | SpotLight(_) => ()
    _ => return
  }
  let direct_light = light_color.xyz().to_var()
  if analytic.shadow_node is Some(shadow_node) {
    direct_light.mul_assign(shadow_node)
  }
  VolumetricLightingModel::scattering_light(direct_light, builder)
}

///|
pub impl LightingModelClass for VolumetricLightingModel with fn direct_rect_area(
  _,
  _,
  light_data,
  builder,
) {
  let data = LightData::from_js(light_data)
  let light_color = data.light_color.unwrap()
  let light_position = data.light_position.unwrap()
  let half_width = data.half_width.unwrap()
  let half_height = data.half_height.unwrap()
  let p0 = light_position.add(half_width).sub(half_height)
  let p1 = light_position.sub(half_width).sub(half_height)
  let p2 = light_position.sub(half_width).add(half_height)
  let p3 = light_position.add(half_width).add(half_height)
  let p = physical_optional(builder.context.get_node("positionView"))
  let direct_light = light_color
    .xyz()
    .mul(
      ltc_evaluate_volume.call_named({
        "P": p,
        "p0": p0,
        "p1": p1,
        "p2": p2,
        "p3": p3,
      }),
    )
    .pow(1.5)
  VolumetricLightingModel::scattering_light(direct_light, builder)
}

///|
pub impl LightingModelClass for VolumetricLightingModel with fn finish(
  _,
  _,
  builder,
) {
  builder.context
  .get_node("outgoingLight")
  .unwrap()
  .assign(volumetric_outgoing_ray_light)
}

///|
/// `new VolumetricLightingModel()`.
pub fn VolumetricLightingModel::new() -> LightingModel {
  LightingModel::new(class_=VolumetricLightingModel::{ })
}
