// nodes/functions/PhysicalLightingModel.js: the PBR lighting model of
// MeshStandardNodeMaterial and MeshPhysicalNodeMaterial.

///|
/// `getVolumeTransmissionRay( n, v, thickness, ior, modelMatrix )`.
let physical_get_volume_transmission_ray : Node = module_nodes(
  "nodes/functions/PhysicalLightingModel.js:getVolumeTransmissionRay",
  fn() {
    fn_(
      fn(inputs, _) {
        let n = inputs.get(0).unwrap()
        let v = inputs.get(1).unwrap()
        let thickness = inputs.get(2).unwrap()
        let ior = inputs.get(3).unwrap()
        let model_matrix = inputs.get(4).unwrap()
        let refraction_vector = vec3(
          refract(v.negate(), normalize(n), div(1.0, ior)),
        )
        let model_scale = vec3_of([
          length(model_matrix[0].xyz()),
          length(model_matrix[1].xyz()),
          length(model_matrix[2].xyz()),
        ])
        Some(normalize(refraction_vector).mul(thickness.mul(model_scale)))
      },
      layout=FnLayout::short(
        [
          ("n", "vec3"),
          ("v", "vec3"),
          ("thickness", "float"),
          ("ior", "float"),
          ("modelMatrix", "mat4"),
        ],
        return_="vec3",
        upstream="nodes/functions/PhysicalLightingModel.js:getVolumeTransmissionRay",
      ),
    )
  },
)

///|
/// `applyIorToRoughness( roughness, ior )`.
let physical_apply_ior_to_roughness : Node = module_nodes(
  "nodes/functions/PhysicalLightingModel.js:applyIorToRoughness",
  fn() {
    fn_(
      fn(inputs, _) {
        let roughness = inputs.get(0).unwrap()
        let ior = inputs.get(1).unwrap()
        Some(roughness.mul(clamp(ior.mul(2.0).sub(2.0), low=0.0, high=1.0)))
      },
      layout=FnLayout::short(
        [("roughness", "float"), ("ior", "float")],
        return_="float",
        upstream="nodes/functions/PhysicalLightingModel.js:applyIorToRoughness",
      ),
    )
  },
)

///|
let physical_viewport_back_side_texture : Node = module_nodes(
  "nodes/functions/PhysicalLightingModel.js:viewportBackSideTexture",
  fn() { viewport_mip_texture() },
)

///|
let physical_viewport_front_side_texture : Node = module_nodes(
  "nodes/functions/PhysicalLightingModel.js:viewportFrontSideTexture",
  fn() { viewport_opaque_mip_texture() },
)

///|
/// `getTransmissionSample( fragCoord, roughness, ior )`.
let physical_get_transmission_sample : Node = module_nodes(
  "nodes/functions/PhysicalLightingModel.js:getTransmissionSample",
  fn() {
    fn_(fn(inputs, builder) {
      let frag_coord = inputs.get(0).unwrap()
      let roughness = inputs.get(1).unwrap()
      let ior = inputs.get(2).unwrap()
      let v_texture = if builder.material.unwrap().side == @core.BackSide {
        physical_viewport_back_side_texture
      } else {
        physical_viewport_front_side_texture
      }
      let transmission_sample = v_texture.sample(
        frag_coord
        .mul(camera_viewport.zw())
        .add(camera_viewport.xy())
        .div(screen_size),
      )
      let lod = log2(camera_viewport.z()).mul(
        physical_apply_ior_to_roughness.call([roughness, ior]),
      )
      Some(texture_bicubic_level.call([transmission_sample, lod]))
    })
  },
)

///|
/// `volumeAttenuation( transmissionDistance, attenuationColor, attenuationDistance )`
/// (Beer's law).
let physical_volume_attenuation : Node = module_nodes(
  "nodes/functions/PhysicalLightingModel.js:volumeAttenuation",
  fn() {
    fn_(
      fn(inputs, _) {
        let transmission_distance = inputs.get(0).unwrap()
        let attenuation_color = inputs.get(1).unwrap()
        let attenuation_distance = inputs.get(2).unwrap()
        if_value(attenuation_distance.not_equal(0), fn() {
          let attenuation_coefficient = log(attenuation_color)
            .negate()
            .div(attenuation_distance)
          let transmittance = exp(
            attenuation_coefficient.negate().mul(transmission_distance),
          )
          transmittance
        })
        |> ignore
        Some(vec3(1.0))
      },
      layout=FnLayout::short(
        [
          ("transmissionDistance", "float"),
          ("attenuationColor", "vec3"),
          ("attenuationDistance", "float"),
        ],
        return_="vec3",
        upstream="nodes/functions/PhysicalLightingModel.js:volumeAttenuation",
      ),
    )
  },
)

///|
/// The refracted ray's projected screen coordinates.
fn physical_refraction_coords(
  position : Node,
  transmission_ray : Node,
  view_matrix : Node,
  proj_matrix : Node,
) -> Node {
  let refracted_ray_exit = position.add(transmission_ray)
  let ndc_pos = proj_matrix.mul(
    view_matrix.mul(vec4_of([refracted_ray_exit, 1.0])),
  )
  let refraction_coords = vec2(ndc_pos.xy().div(ndc_pos.w())).to_var()
  refraction_coords.add_assign(1.0)
  refraction_coords.div_assign(2.0)
  refraction_coords.assign(
    vec2_of([refraction_coords.x(), refraction_coords.y().one_minus()]),
  )
  refraction_coords
}

///|
/// `getIBLVolumeRefraction( n, v, roughness, diffuseColor, specularColor, specularF90,
/// position, modelMatrix, viewMatrix, projMatrix, ior, thickness, attenuationColor,
/// attenuationDistance, dispersion )`.
let physical_get_ibl_volume_refraction : Node = module_nodes(
  "nodes/functions/PhysicalLightingModel.js:getIBLVolumeRefraction",
  fn() {
    fn_(fn(inputs, _) {
      let n = inputs.get(0).unwrap()
      let v = inputs.get(1).unwrap()
      let roughness = inputs.get(2).unwrap()
      let diffuse_color = inputs.get(3).unwrap()
      let specular_color = inputs.get(4).unwrap()
      let specular_f90 = inputs.get(5).unwrap()
      let position = inputs.get(6).unwrap()
      let model_matrix = inputs.get(7).unwrap()
      let view_matrix = inputs.get(8).unwrap()
      let proj_matrix = inputs.get(9).unwrap()
      let ior = inputs.get(10).unwrap()
      let thickness = inputs.get(11).unwrap()
      let attenuation_color = inputs.get(12).unwrap()
      let attenuation_distance = inputs.get(13).unwrap()
      let dispersion = inputs.get(14)
      let (transmitted_light, transmittance) = match dispersion {
        Some(dispersion) => {
          let transmitted_light = vec4_of([]).to_var()
          let transmittance = vec3_of([]).to_var()
          let half_spread = ior.sub(1.0).mul(dispersion.mul(0.025))
          let iors = vec3_of([ior.sub(half_spread), ior, ior.add(half_spread)])
          loop_([loop_range(start=0, end=3)], fn(inputs) {
            let i = inputs.named("i").unwrap()
            let ior = iors.element(i)
            let transmission_ray = physical_get_volume_transmission_ray.call([
              n, v, thickness, ior, model_matrix,
            ])
            let refraction_coords = physical_refraction_coords(
              position, transmission_ray, view_matrix, proj_matrix,
            )
            let transmission_sample = physical_get_transmission_sample.call([
              refraction_coords, roughness, ior,
            ])
            transmitted_light.element(i).assign(transmission_sample.element(i))
            transmitted_light.a().add_assign(transmission_sample.a())
            transmittance
            .element(i)
            .assign(
              diffuse_color
              .element(i)
              .mul(
                physical_volume_attenuation
                .call([
                  length(transmission_ray),
                  attenuation_color,
                  attenuation_distance,
                ])
                .element(i),
              ),
            )
          })
          transmitted_light.a().div_assign(3.0)
          (transmitted_light, transmittance)
        }
        None => {
          let transmission_ray = physical_get_volume_transmission_ray.call([
            n, v, thickness, ior, model_matrix,
          ])
          let refraction_coords = physical_refraction_coords(
            position, transmission_ray, view_matrix, proj_matrix,
          )
          let transmitted_light = physical_get_transmission_sample.call([
            refraction_coords, roughness, ior,
          ])
          let transmittance = diffuse_color.mul(
            physical_volume_attenuation.call([
              length(transmission_ray),
              attenuation_color,
              attenuation_distance,
            ]),
          )
          (transmitted_light, transmittance)
        }
      }
      let attenuated_color = transmittance.rgb().mul(transmitted_light.rgb())
      let dot_nv = n.dot(v).clamp()
      let f = vec3(
        environment_brdf.call_named({
          "dotNV": dot_nv,
          "specularColor": specular_color,
          "specularF90": specular_f90,
          "roughness": roughness,
        }),
      )
      let transmittance_factor = transmittance
        .r()
        .add_of([transmittance.g(), transmittance.b()])
        .div(3.0)
      Some(
        vec4_of([
          f.one_minus().mul(attenuated_color),
          transmitted_light
          .a()
          .one_minus()
          .mul(transmittance_factor)
          .one_minus(),
        ]),
      )
    })
  },
)

///|
let physical_xyz_to_rec709 : Node = module_nodes(
  "nodes/functions/PhysicalLightingModel.js:XYZ_TO_REC709",
  fn() {
    mat3_of([
      3.2404542, -1.5371385, -0.4985314, -0.9692660, 1.8760108, 0.0415560, 0.0556434,
      -0.2040259, 1.0572252,
    ])
  },
)

///|
/// `Fresnel0ToIor( fresnel0 )`.
fn physical_fresnel0_to_ior(fresnel0 : Node) -> Node {
  let sqrt_f0 = fresnel0.sqrt()
  vec3(1.0).add(sqrt_f0).div(vec3(1.0).sub(sqrt_f0))
}

///|
/// `IorToFresnel0( transmittedIor, incidentIor )`.
fn physical_ior_to_fresnel0(
  transmitted_ior : Node,
  incident_ior : Node,
) -> Node {
  transmitted_ior
  .sub(incident_ior)
  .div(transmitted_ior.add(incident_ior))
  .pow2()
}

///|
/// `evalSensitivity( OPD, shift )`: Fourier transform of the color matching functions.
fn physical_eval_sensitivity(opd : Node, shift : Node) -> Node {
  let phase = opd.mul(2.0 * bsdf_pi * 1.0e-9)
  let val = vec3_of([5.4856e-13, 4.4201e-13, 5.2481e-13])
  let pos = vec3_of([1.6810e+06, 1.7953e+06, 2.2084e+06])
  let var_ = vec3_of([4.3278e+09, 9.3046e+09, 6.6121e+09])
  let x = float(9.7470e-14 * (2.0 * bsdf_pi * 4.5282e+09).sqrt())
    .mul(phase.mul(2.2399e+06).add(shift.x()).cos())
    .mul(phase.pow2().mul(-4.5282e+09).exp())
  let mut xyz = val
    .mul(var_.mul(2.0 * bsdf_pi).sqrt())
    .mul(pos.mul(phase).add(shift).cos())
    .mul(phase.pow2().negate().mul(var_).exp())
  xyz = vec3_of([xyz.x().add(x), xyz.y(), xyz.z()]).div(1.0685e-7)
  let rgb = physical_xyz_to_rec709.mul(xyz)
  rgb
}

///|
/// `evalIridescence( { outsideIOR, eta2, cosTheta1, thinFilmThickness, baseF0 } )`.
let physical_eval_iridescence : Node = module_nodes(
  "nodes/functions/PhysicalLightingModel.js:evalIridescence",
  fn() {
    fn_(
      fn(inputs, _) {
        let outside_ior = inputs.named("outsideIOR").unwrap()
        let eta2 = inputs.named("eta2").unwrap()
        let cos_theta1 = inputs.named("cosTheta1").unwrap()
        let thin_film_thickness = inputs.named("thinFilmThickness").unwrap()
        let base_f0 = inputs.named("baseF0").unwrap()
        let iridescence_ior = mix(
          outside_ior,
          eta2,
          smoothstep(0.0, 0.03, thin_film_thickness),
        )
        let sin_theta2_sq = outside_ior
          .div(iridescence_ior)
          .pow2()
          .mul(cos_theta1.pow2().one_minus())
        let cos_theta2_sq = sin_theta2_sq.one_minus()
        if_value(cos_theta2_sq.less_than(0), fn() { vec3(1.0) }) |> ignore
        let cos_theta2 = cos_theta2_sq.sqrt()
        let r0 = physical_ior_to_fresnel0(iridescence_ior, outside_ior)
        let r12 = f_schlick.call_named({
          "f0": r0,
          "f90": 1.0,
          "dotVH": cos_theta1,
        })
        let t121 = r12.one_minus()
        let phi12 = iridescence_ior
          .less_than(outside_ior)
          .select(bsdf_pi, else_node=0.0)
        let phi21 = float(bsdf_pi).sub(phi12)
        let base_ior = physical_fresnel0_to_ior(
          base_f0.clamp(low=0.0, high=0.9999),
        )
        let r1 = physical_ior_to_fresnel0(base_ior, iridescence_ior.to_vec3())
        let r23 = f_schlick.call_named({
          "f0": r1,
          "f90": 1.0,
          "dotVH": cos_theta2,
        })
        let phi23 = vec3_of([
          base_ior.x().less_than(iridescence_ior).select(bsdf_pi, else_node=0.0),
          base_ior.y().less_than(iridescence_ior).select(bsdf_pi, else_node=0.0),
          base_ior.z().less_than(iridescence_ior).select(bsdf_pi, else_node=0.0),
        ])
        let opd = iridescence_ior.mul_of([thin_film_thickness, cos_theta2, 2.0])
        let phi = vec3(phi21).add(phi23)
        let r123 = r12.mul(r23).clamp(low=1.0e-5, high=0.9999)
        let r123_sqrt = r123.sqrt()
        let rs = t121.pow2().mul(r23).div(vec3(1.0).sub(r123))
        let c0 = r12.add(rs)
        let i_ = c0.to_var()
        let cm = rs.sub(t121).to_var()
        loop_([loop_range(start=1, end=2, condition="<=", name="m")], fn(
          inputs,
        ) {
          let m = inputs.named("m").unwrap()
          cm.mul_assign(r123_sqrt)
          let sm = physical_eval_sensitivity(
            float(m).mul(opd),
            float(m).mul(phi),
          ).mul(2.0)
          i_.add_assign(cm.mul(sm))
        })
        Some(i_.max(vec3(0.0)))
      },
      layout=FnLayout::short(
        [
          ("outsideIOR", "float"),
          ("eta2", "float"),
          ("cosTheta1", "float"),
          ("thinFilmThickness", "float"),
          ("baseF0", "vec3"),
        ],
        return_="vec3",
        upstream="nodes/functions/PhysicalLightingModel.js:evalIridescence",
      ),
    )
  },
)

///|
/// `IBLSheenBRDF( { normal, viewDir, roughness } )`.
let physical_ibl_sheen_brdf : Node = module_nodes(
  "nodes/functions/PhysicalLightingModel.js:IBLSheenBRDF",
  fn() {
    fn_(
      fn(inputs, _) {
        let normal = inputs.named("normal").unwrap()
        let view_dir = inputs.named("viewDir").unwrap()
        let roughness = inputs.named("roughness").unwrap()
        let dot_nv = normal.dot(view_dir).saturate()
        let r2 = roughness.mul(roughness)
        let r_inv = roughness.add(0.1).reciprocal()
        let a = float(-1.9362)
          .add(roughness.mul(1.0678))
          .add(r2.mul(0.4573))
          .sub(r_inv.mul(0.8469))
        let b = float(-0.6014)
          .add(roughness.mul(0.5538))
          .sub(r2.mul(0.4670))
          .sub(r_inv.mul(0.1255))
        let dg = a.mul(dot_nv).add(b).exp()
        Some(dg.saturate())
      },
      layout=FnLayout::short(
        [("normal", "vec3"), ("viewDir", "vec3"), ("roughness", "float")],
        return_="float",
        upstream="nodes/functions/PhysicalLightingModel.js:IBLSheenBRDF",
      ),
    )
  },
)

///|
let physical_clearcoat_f0 : Node = module_nodes(
  "nodes/functions/PhysicalLightingModel.js:clearcoatF0",
  fn() { vec3(0.04) },
)

///|
let physical_clearcoat_f90 : Node = module_nodes(
  "nodes/functions/PhysicalLightingModel.js:clearcoatF90",
  fn() { float(1) },
)

///|
pub(all) struct PhysicalLightingModel {
  mut clearcoat : Bool
  mut sheen : Bool
  mut iridescence : Bool
  mut anisotropy : Bool
  mut transmission : Bool
  mut dispersion : Bool
  mut retroreflection : Bool
  mut diffuse_roughness : Bool
  mut clearcoat_radiance : Node?
  mut clearcoat_specular_direct : Node?
  mut clearcoat_specular_indirect : Node?
  mut sheen_specular_direct : Node?
  mut sheen_specular_indirect : Node?
  mut iridescence_fresnel : Node?
  mut iridescence_f0_dielectric : Node?
  mut iridescence_f0_metallic : Node?
  mut dfg : Node?
  mut eon_directional_albedo : Node?
  mut multi_scattering_compensation : Node?
  mut single_scattering_dielectric : Node?
  mut multi_scattering_dielectric : Node?
}

///|
pub impl LightingModelClass for PhysicalLightingModel with fn class_name(_) {
  "PhysicalLightingModel"
}

///|
pub impl LightingModelClass for PhysicalLightingModel with fn start(
  self,
  model,
  builder,
) {
  if self.clearcoat == true {
    self.clearcoat_radiance = Some(vec3_of([]).to_var(name="clearcoatRadiance"))
    self.clearcoat_specular_direct = Some(
      vec3_of([]).to_var(name="clearcoatSpecularDirect"),
    )
    self.clearcoat_specular_indirect = Some(
      vec3_of([]).to_var(name="clearcoatSpecularIndirect"),
    )
  }
  if self.sheen == true {
    self.sheen_specular_direct = Some(
      vec3_of([]).to_var(name="sheenSpecularDirect"),
    )
    self.sheen_specular_indirect = Some(
      vec3_of([]).to_var(name="sheenSpecularIndirect"),
    )
  }
  if self.iridescence == true {
    let dot_nvi = normal_view.dot(position_view_direction).clamp()
    let iridescence_fresnel_dielectric = physical_eval_iridescence.call_named({
      "outsideIOR": float(1.0),
      "eta2": iridescence_ior,
      "cosTheta1": dot_nvi,
      "thinFilmThickness": iridescence_thickness,
      "baseF0": specular_color,
    })
    let iridescence_fresnel_metallic = physical_eval_iridescence.call_named({
      "outsideIOR": float(1.0),
      "eta2": iridescence_ior,
      "cosTheta1": dot_nvi,
      "thinFilmThickness": iridescence_thickness,
      "baseF0": diffuse_color.rgb(),
    })
    self.iridescence_fresnel = Some(
      mix(
        iridescence_fresnel_dielectric, iridescence_fresnel_metallic, metalness,
      ),
    )
    self.iridescence_f0_dielectric = Some(
      schlick_to_f0.call_named({
        "f": iridescence_fresnel_dielectric,
        "f90": 1.0,
        "dotVH": dot_nvi,
      }),
    )
    self.iridescence_f0_metallic = Some(
      schlick_to_f0.call_named({
        "f": iridescence_fresnel_metallic,
        "f90": 1.0,
        "dotVH": dot_nvi,
      }),
    )
  }
  if self.transmission == true {
    let position = position_world
    let v = camera_position.sub(position_world).normalize()
    let n = normal_world
    let context = builder.context
    let backdrop = physical_get_ibl_volume_refraction.call([
      n,
      v,
      roughness,
      diffuse_contribution,
      specular_color_blended,
      specular_f90,
      position,
      model_world_matrix,
      camera_view_matrix,
      camera_projection_matrix,
      ior,
      thickness,
      attenuation_color,
      attenuation_distance,
      if self.dispersion {
        TslValue::Node(dispersion)
      } else {
        TslValue::Null
      },
    ])
    context.set("backdrop", Node(backdrop))
    context.set("backdropAlpha", Node(transmission))
    diffuse_color.a().mul_assign(mix(1, backdrop.a(), transmission))
  }
  let dot_nv = normal_view.dot(position_view_direction).clamp()
  let dfg = dfglut
    .call_named({ "roughness": roughness, "dotNV": dot_nv })
    .to_const(name="dfg")
  self.dfg = Some(dfg)
  let ess = dfg.x().add(dfg.y())
  self.multi_scattering_compensation = Some(
    specular_color_blended
    .mul(ess.reciprocal().sub(1.0))
    .add(1.0)
    .to_const(name="multiScatteringCompensation"),
  )
  let single_scattering_dielectric = vec3_of([]).to_var(
    name="singleScatteringDielectric",
  )
  let multi_scattering_dielectric = vec3_of([]).to_var(
    name="multiScatteringDielectric",
  )
  self.single_scattering_dielectric = Some(single_scattering_dielectric)
  self.multi_scattering_dielectric = Some(multi_scattering_dielectric)
  self.compute_multiscattering(
    single_scattering_dielectric,
    multi_scattering_dielectric,
    specular_f90,
    specular_color,
    iridescence_f0=self.iridescence_f0_dielectric,
  )
  if self.diffuse_roughness == true {
    self.eon_directional_albedo = Some(
      eon_directional_albedo.call_named({
        "diffuseColor": diffuse_color.rgb(),
        "roughness": diffuse_roughness,
        "dotNV": dot_nv,
      }),
    )
  }
  model.start_base(builder)
}

///|
/// `computeMultiscattering( singleScatter, multiScatter, specularF90, f0,
/// iridescenceF0 = null )` (Fdez-Agüera's multiple-scattering approximation).
pub fn PhysicalLightingModel::compute_multiscattering(
  self : PhysicalLightingModel,
  single_scatter : Node,
  multi_scatter : Node,
  specular_f90 : Node,
  f0 : Node,
  iridescence_f0~ : Node? = None,
) -> Unit {
  let fab = self.dfg.unwrap()
  let fr = match iridescence_f0 {
    Some(iridescence_f0) => iridescence.mix(f0, iridescence_f0)
    None => f0
  }
  let fss_ess = fr.mul(fab.x()).add(specular_f90.mul(fab.y()))
  let ess = fab.x().add(fab.y())
  let ems = ess.one_minus()
  let favg = fr.add(fr.one_minus().mul(0.047619))
  let fms = fss_ess.mul(favg).div(ems.mul(favg).one_minus())
  single_scatter.add_assign(fss_ess)
  multi_scatter.add_assign(fms.mul(ems))
}

///|
pub impl LightingModelClass for PhysicalLightingModel with fn direct(
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
  let irradiance = dot_nl.mul(light_color).to_var()
  if self.sheen == true {
    self.sheen_specular_direct
    .unwrap()
    .add_assign(
      irradiance.mul(
        brdf_sheen.call_named({ "lightDirection": light_direction }),
      ),
    )
    let sheen_albedo_v = physical_ibl_sheen_brdf.call_named({
      "normal": normal_view,
      "viewDir": position_view_direction,
      "roughness": sheen_roughness,
    })
    let sheen_albedo_l = physical_ibl_sheen_brdf.call_named({
      "normal": normal_view,
      "viewDir": light_direction,
      "roughness": sheen_roughness,
    })
    let sheen_energy_comp = sheen
      .r()
      .max(sheen.g())
      .max(sheen.b())
      .mul(sheen_albedo_v.max(sheen_albedo_l))
      .one_minus()
    irradiance.mul_assign(sheen_energy_comp)
  }
  if self.clearcoat == true {
    let dot_n_lcc = clearcoat_normal_view.dot(light_direction).clamp()
    let cc_irradiance = dot_n_lcc.mul(light_color)
    self.clearcoat_specular_direct
    .unwrap()
    .add_assign(
      cc_irradiance.mul(
        brdf_ggx.call_named({
          "lightDirection": light_direction,
          "f0": physical_clearcoat_f0,
          "f90": physical_clearcoat_f90,
          "roughness": clearcoat_roughness,
          "normalView": clearcoat_normal_view,
        }),
      ),
    )
  }
  let half_dir = light_direction.add(position_view_direction).normalize()
  let dot_vh = position_view_direction.dot(half_dir).clamp()
  let mut f = f_schlick.call_named({
    "f0": specular_color,
    "f90": specular_f90,
    "dotVH": dot_vh,
  })
  let mut specular_brdf = brdf_ggx.call_named({
    "lightDirection": light_direction,
    "f0": specular_color_blended,
    "f90": specular_f90,
    "roughness": roughness,
    "f": physical_optional(self.iridescence_fresnel),
    "USE_IRIDESCENCE": self.iridescence,
    "USE_ANISOTROPY": self.anisotropy,
  })
  if self.retroreflection == true {
    let retro_view_direction = position_view_direction
      .negate()
      .reflect(normal_view)
    let retro_half_dir = light_direction.add(retro_view_direction).normalize()
    let dot_retro_vh = retro_view_direction.dot(retro_half_dir).clamp()
    let retro_f = f_schlick.call_named({
      "f0": specular_color,
      "f90": specular_f90,
      "dotVH": dot_retro_vh,
    })
    let retro_specular_brdf = brdf_ggx.call_named({
      "lightDirection": light_direction,
      "viewDirection": retro_view_direction,
      "f0": specular_color_blended,
      "f90": specular_f90,
      "roughness": roughness,
      "f": physical_optional(self.iridescence_fresnel),
      "USE_IRIDESCENCE": self.iridescence,
      "USE_ANISOTROPY": self.anisotropy,
    })
    f = mix(f, retro_f, retroreflectivity.clamp())
    specular_brdf = mix(
      specular_brdf,
      retro_specular_brdf,
      retroreflectivity.clamp(),
    )
  }
  let diffuse_brdf = if self.diffuse_roughness {
    brdf_eon
    .call_named({
      "lightDirection": light_direction,
      "diffuseColor": diffuse_color.rgb(),
      "roughness": diffuse_roughness,
    })
    .mul(metalness.one_minus())
  } else {
    brdf_lambert.call_named({ "diffuseColor": diffuse_contribution })
  }
  reflected_light.direct_diffuse.add_assign(
    irradiance.mul(diffuse_brdf).mul(f.one_minus()),
  )
  reflected_light.direct_specular.add_assign(
    irradiance
    .mul(specular_brdf)
    .mul(self.multi_scattering_compensation.unwrap()),
  )
}

///|
/// A JS value that may be `null`.
fn physical_optional(node : Node?) -> TslValue {
  match node {
    Some(n) => Node(n)
    None => Null
  }
}

///|
pub impl LightingModelClass for PhysicalLightingModel with fn direct_rect_area(
  self,
  _,
  light_data,
  _,
) {
  let data = LightData::from_js(light_data)
  let light_color = data.light_color.unwrap()
  let light_position = data.light_position.unwrap()
  let half_width = data.half_width.unwrap()
  let half_height = data.half_height.unwrap()
  let reflected_light = data.reflected_light.unwrap()
  let ltc_1 = data.ltc_1.unwrap()
  let ltc_2 = data.ltc_2.unwrap()
  let p0 = light_position.add(half_width).sub(half_height)
  let p1 = light_position.sub(half_width).sub(half_height)
  let p2 = light_position.sub(half_width).add(half_height)
  let p3 = light_position.add(half_width).add(half_height)
  let n = normal_view
  let v = position_view_direction
  let p = position_view.to_var()
  let uv = ltc_uv.call_named({ "N": n, "V": v, "roughness": roughness })
  let t1 = ltc_1.sample(uv).to_var()
  let t2 = ltc_2.sample(uv).to_var()
  let m_inv = mat3_of([
    vec3_of([t1.x(), 0, t1.y()]),
    vec3_of([0, 1, 0]),
    vec3_of([t1.z(), 0, t1.w()]),
  ]).to_var()
  let fresnel = specular_color_blended
    .mul(t2.x())
    .add(specular_f90.sub(specular_color_blended).mul(t2.y()))
    .to_var()
  reflected_light.direct_specular.add_assign(
    light_color
    .mul(fresnel)
    .mul(
      ltc_evaluate.call_named({
        "N": n,
        "V": v,
        "P": p,
        "mInv": m_inv,
        "p0": p0,
        "p1": p1,
        "p2": p2,
        "p3": p3,
      }),
    ),
  )
  reflected_light.direct_diffuse.add_assign(
    light_color
    .mul(diffuse_contribution)
    .mul(
      ltc_evaluate.call_named({
        "N": n,
        "V": v,
        "P": p,
        "mInv": mat3_of([1, 0, 0, 0, 1, 0, 0, 0, 1]),
        "p0": p0,
        "p1": p1,
        "p2": p2,
        "p3": p3,
      }),
    ),
  )
  if self.clearcoat == true {
    let ncc = clearcoat_normal_view
    let uv_clearcoat = ltc_uv.call_named({
      "N": ncc,
      "V": v,
      "roughness": clearcoat_roughness,
    })
    let t1_clearcoat = ltc_1.sample(uv_clearcoat)
    let t2_clearcoat = ltc_2.sample(uv_clearcoat)
    let m_inv_clearcoat = mat3_of([
      vec3_of([t1_clearcoat.x(), 0, t1_clearcoat.y()]),
      vec3_of([0, 1, 0]),
      vec3_of([t1_clearcoat.z(), 0, t1_clearcoat.w()]),
    ])
    let fresnel_clearcoat = physical_clearcoat_f0
      .mul(t2_clearcoat.x())
      .add(
        physical_clearcoat_f90.sub(physical_clearcoat_f0).mul(t2_clearcoat.y()),
      )
    self.clearcoat_specular_direct
    .unwrap()
    .add_assign(
      light_color
      .mul(fresnel_clearcoat)
      .mul(
        ltc_evaluate.call_named({
          "N": ncc,
          "V": v,
          "P": p,
          "mInv": m_inv_clearcoat,
          "p0": p0,
          "p1": p1,
          "p2": p2,
          "p3": p3,
        }),
      ),
    )
  }
}

///|
pub impl LightingModelClass for PhysicalLightingModel with fn indirect(
  self,
  model,
  builder,
) {
  self.indirect_diffuse(builder)
  self.indirect_specular(builder)
  model.ambient_occlusion(builder)
}

///|
/// `indirectDiffuse( builder )`.
pub fn PhysicalLightingModel::indirect_diffuse(
  self : PhysicalLightingModel,
  builder : NodeBuilder,
) -> Unit {
  let context = builder.context
  let irradiance = context.get_node("irradiance").unwrap()
  let reflected_light = NodeContext::reflected_light(context).unwrap()
  let single_scattering = self.single_scattering_dielectric.unwrap()
  let multi_scattering = self.multi_scattering_dielectric.unwrap()
  let diffuse_brdf = if self.diffuse_roughness {
    self.eon_directional_albedo
    .unwrap()
    .mul_of([metalness.one_minus(), 1.0 / bsdf_pi])
  } else {
    brdf_lambert.call_named({ "diffuseColor": diffuse_contribution })
  }
  let diffuse = irradiance
    .mul(diffuse_brdf)
    .mul(single_scattering.add(multi_scattering).one_minus())
    .to_var()
  if self.sheen == true {
    let sheen_albedo = physical_ibl_sheen_brdf.call_named({
      "normal": normal_view,
      "viewDir": position_view_direction,
      "roughness": sheen_roughness,
    })
    self.sheen_specular_indirect
    .unwrap()
    .add_assign(irradiance.mul_of([sheen, sheen_albedo, 1.0 / bsdf_pi]))
    let sheen_energy_comp = sheen
      .r()
      .max(sheen.g())
      .max(sheen.b())
      .mul(sheen_albedo)
      .one_minus()
    diffuse.mul_assign(sheen_energy_comp)
  }
  reflected_light.indirect_diffuse.add_assign(diffuse)
}

///|
/// `indirectSpecular( builder )`.
pub fn PhysicalLightingModel::indirect_specular(
  self : PhysicalLightingModel,
  builder : NodeBuilder,
) -> Unit {
  let context = builder.context
  let radiance = context.get_node("radiance").unwrap()
  let ibl_irradiance = context.get_node("iblIrradiance").unwrap()
  let reflected_light = NodeContext::reflected_light(context).unwrap()
  if self.sheen == true {
    self.sheen_specular_indirect
    .unwrap()
    .add_assign(
      ibl_irradiance.mul_of([
        sheen,
        physical_ibl_sheen_brdf.call_named({
          "normal": normal_view,
          "viewDir": position_view_direction,
          "roughness": sheen_roughness,
        }),
        1.0 / bsdf_pi,
      ]),
    )
  }
  if self.clearcoat == true {
    let dot_n_vcc = clearcoat_normal_view.dot(position_view_direction).clamp()
    let clearcoat_env = environment_brdf.call_named({
      "dotNV": dot_n_vcc,
      "specularColor": physical_clearcoat_f0,
      "specularF90": physical_clearcoat_f90,
      "roughness": clearcoat_roughness,
    })
    self.clearcoat_specular_indirect
    .unwrap()
    .add_assign(self.clearcoat_radiance.unwrap().mul(clearcoat_env))
  }
  let single_scattering_dielectric = self.single_scattering_dielectric.unwrap()
  let multi_scattering_dielectric = self.multi_scattering_dielectric.unwrap()
  let single_scattering_metallic = vec3_of([]).to_var(
    name="singleScatteringMetallic",
  )
  let multi_scattering_metallic = vec3_of([]).to_var(
    name="multiScatteringMetallic",
  )
  self.compute_multiscattering(
    single_scattering_metallic,
    multi_scattering_metallic,
    specular_f90,
    diffuse_color.rgb(),
    iridescence_f0=self.iridescence_f0_metallic,
  )
  let single_scattering = mix(
    single_scattering_dielectric, single_scattering_metallic, metalness,
  )
  let multi_scattering = mix(
    multi_scattering_dielectric, multi_scattering_metallic, metalness,
  )
  let total_scattering_dielectric = single_scattering_dielectric.add(
    multi_scattering_dielectric,
  )
  let diffuse_albedo = if self.diffuse_roughness {
    self.eon_directional_albedo.unwrap().mul(metalness.one_minus())
  } else {
    diffuse_contribution
  }
  let diffuse = diffuse_albedo.mul(total_scattering_dielectric.one_minus())
  let cosine_weighted_irradiance = ibl_irradiance.mul(1.0 / bsdf_pi)
  let indirect_specular = radiance
    .mul(single_scattering)
    .add(multi_scattering.mul(cosine_weighted_irradiance))
    .to_var()
  let indirect_diffuse = diffuse.mul(cosine_weighted_irradiance).to_var()
  if self.sheen == true {
    let sheen_albedo = physical_ibl_sheen_brdf.call_named({
      "normal": normal_view,
      "viewDir": position_view_direction,
      "roughness": sheen_roughness,
    })
    let sheen_energy_comp = sheen
      .r()
      .max(sheen.g())
      .max(sheen.b())
      .mul(sheen_albedo)
      .one_minus()
    indirect_specular.mul_assign(sheen_energy_comp)
    indirect_diffuse.mul_assign(sheen_energy_comp)
  }
  reflected_light.indirect_specular.add_assign(indirect_specular)
  reflected_light.indirect_diffuse.add_assign(indirect_diffuse)
}

///|
pub impl LightingModelClass for PhysicalLightingModel with fn ambient_occlusion(
  self,
  _,
  builder,
) {
  let context = builder.context
  let ambient_occlusion = context.get_node("ambientOcclusion").unwrap()
  let reflected_light = NodeContext::reflected_light(context).unwrap()
  let dot_nv = normal_view.dot(position_view_direction).clamp()
  let ao_nv = dot_nv.add(ambient_occlusion)
  let ao_exp = roughness.mul(-16.0).one_minus().negate().exp2()
  let ao_node = ambient_occlusion.sub(ao_nv.pow(ao_exp).one_minus()).clamp()
  if self.clearcoat == true {
    self.clearcoat_specular_indirect.unwrap().mul_assign(ambient_occlusion)
  }
  if self.sheen == true {
    self.sheen_specular_indirect.unwrap().mul_assign(ambient_occlusion)
  }
  reflected_light.indirect_diffuse.mul_assign(ambient_occlusion)
  reflected_light.indirect_specular.mul_assign(ao_node)
}

///|
pub impl LightingModelClass for PhysicalLightingModel with fn finish(
  self,
  _,
  builder,
) {
  let outgoing_light = builder.context.get_node("outgoingLight").unwrap()
  if self.clearcoat == true {
    let dot_n_vcc = clearcoat_normal_view.dot(position_view_direction).clamp()
    let fcc = f_schlick.call_named({
      "dotVH": dot_n_vcc,
      "f0": physical_clearcoat_f0,
      "f90": physical_clearcoat_f90,
    })
    let clearcoat_light = outgoing_light
      .mul(clearcoat.mul(fcc).one_minus())
      .add(
        self.clearcoat_specular_direct
        .unwrap()
        .add(self.clearcoat_specular_indirect.unwrap())
        .mul(clearcoat),
      )
    outgoing_light.assign(clearcoat_light)
  }
  if self.sheen == true {
    let sheen_light = outgoing_light.add_of([
      self.sheen_specular_direct.unwrap(),
      self.sheen_specular_indirect.unwrap(),
    ])
    outgoing_light.assign(sheen_light)
  }
}

///|
/// The payload of `new PhysicalLightingModel( ... )`, for subclasses.
pub fn PhysicalLightingModel::construct(
  clearcoat~ : Bool = false,
  sheen~ : Bool = false,
  iridescence~ : Bool = false,
  anisotropy~ : Bool = false,
  transmission~ : Bool = false,
  dispersion~ : Bool = false,
  retroreflection~ : Bool = false,
  diffuse_roughness~ : Bool = false,
) -> PhysicalLightingModel {
  {
    clearcoat,
    sheen,
    iridescence,
    anisotropy,
    transmission,
    dispersion,
    retroreflection,
    diffuse_roughness,
    clearcoat_radiance: None,
    clearcoat_specular_direct: None,
    clearcoat_specular_indirect: None,
    sheen_specular_direct: None,
    sheen_specular_indirect: None,
    iridescence_fresnel: None,
    iridescence_f0_dielectric: None,
    iridescence_f0_metallic: None,
    dfg: None,
    eon_directional_albedo: None,
    multi_scattering_compensation: None,
    single_scattering_dielectric: None,
    multi_scattering_dielectric: None,
  }
}

///|
/// `new PhysicalLightingModel( clearcoat = false, sheen = false, iridescence = false,
/// anisotropy = false, transmission = false, dispersion = false,
/// retroreflection = false, diffuseRoughness = false )`.
pub fn PhysicalLightingModel::new(
  clearcoat~ : Bool = false,
  sheen~ : Bool = false,
  iridescence~ : Bool = false,
  anisotropy~ : Bool = false,
  transmission~ : Bool = false,
  dispersion~ : Bool = false,
  retroreflection~ : Bool = false,
  diffuse_roughness~ : Bool = false,
) -> LightingModel {
  LightingModel::new(
    class_=PhysicalLightingModel::construct(
      clearcoat~,
      sheen~,
      iridescence~,
      anisotropy~,
      transmission~,
      dispersion~,
      retroreflection~,
      diffuse_roughness~,
    ),
  )
}

///|
pub fn PhysicalLightingModel::of(
  model : LightingModel,
) -> PhysicalLightingModel? {
  match model.class_payload("PhysicalLightingModel") {
    Some(p) => Some(p.cast())
    None => None
  }
}
