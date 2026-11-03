// nodes/display/ToneMappingFunctions.js

///|
/// `linearToneMapping( color, exposure )`.
pub let linear_tone_mapping : Node = module_nodes(
  "nodes/display/ToneMappingFunctions.js:linearToneMapping",
  fn() {
    fn_(
      fn(inputs, _) {
        let color = inputs.get(0).unwrap()
        let exposure = inputs.get(1).unwrap()
        Some(color.mul(exposure).clamp())
      },
      layout=FnLayout::short(
        [("color", "vec3"), ("exposure", "float")],
        return_="vec3",
        upstream="nodes/display/ToneMappingFunctions.js:linearToneMapping",
      ),
    )
  },
)

///|
/// `reinhardToneMapping( color, exposure )`.
pub let reinhard_tone_mapping : Node = module_nodes(
  "nodes/display/ToneMappingFunctions.js:reinhardToneMapping",
  fn() {
    fn_(
      fn(inputs, _) {
        let mut color = inputs.get(0).unwrap()
        let exposure = inputs.get(1).unwrap()
        color = color.mul(exposure)
        Some(color.div(color.add(1.0)).clamp())
      },
      layout=FnLayout::short(
        [("color", "vec3"), ("exposure", "float")],
        return_="vec3",
        upstream="nodes/display/ToneMappingFunctions.js:reinhardToneMapping",
      ),
    )
  },
)

///|
/// `cineonToneMapping( color, exposure )`.
pub let cineon_tone_mapping : Node = module_nodes(
  "nodes/display/ToneMappingFunctions.js:cineonToneMapping",
  fn() {
    fn_(
      fn(inputs, _) {
        let mut color = inputs.get(0).unwrap()
        let exposure = inputs.get(1).unwrap()
        // filmic operator by Jim Hejl and Richard Burgess-Dawson
        color = color.mul(exposure)
        color = color.sub(0.004).max(0.0)
        let a = color.mul(color.mul(6.2).add(0.5))
        let b = color.mul(color.mul(6.2).add(1.7)).add(0.06)
        Some(a.div(b).pow(2.2))
      },
      layout=FnLayout::short(
        [("color", "vec3"), ("exposure", "float")],
        return_="vec3",
        upstream="nodes/display/ToneMappingFunctions.js:cineonToneMapping",
      ),
    )
  },
)

///|
// source: https://github.com/selfshadow/ltc_code/blob/master/webgl/shaders/ltc/ltc_blit.fs
let rrt_and_odt_fit : Node = module_nodes(
  "nodes/display/ToneMappingFunctions.js:RRTAndODTFit",
  fn() {
    fn_(
      fn(inputs, _) {
        let color = inputs.get(0).unwrap()
        let a = color.mul(color.add(0.0245786)).sub(0.000090537)
        let b = color.mul(color.mul(0.983729).add(0.4329510)).add(0.238081)
        Some(a.div(b))
      },
      layout=FnLayout::short(
        [("color", "vec3")],
        return_="vec3",
        upstream="nodes/display/ToneMappingFunctions.js:RRTAndODTFit",
      ),
    )
  },
)

///|
/// `acesFilmicToneMapping( color, exposure )`.
pub let aces_filmic_tone_mapping : Node = module_nodes(
  "nodes/display/ToneMappingFunctions.js:acesFilmicToneMapping",
  fn() {
    fn_(
      fn(inputs, _) {
        let mut color = inputs.get(0).unwrap()
        let exposure = inputs.get(1).unwrap()
        // sRGB => XYZ => D65_2_D60 => AP1 => RRT_SAT
        let aces_input_mat = mat3_of([
          0.59719, 0.35458, 0.04823, 0.07600, 0.90834, 0.01566, 0.02840, 0.13383,
          0.83777,
        ])
        // ODT_SAT => XYZ => D60_2_D65 => sRGB
        let aces_output_mat = mat3_of([
          1.60475, -0.53108, -0.07367, -0.10208, 1.10813, -0.00605, -0.00327, -0.07276,
          1.07602,
        ])
        color = color.mul(exposure).div(0.6)
        color = aces_input_mat.mul(color)
        // Apply RRT and ODT
        color = rrt_and_odt_fit.call([color])
        color = aces_output_mat.mul(color)
        // Clamp to [0, 1]
        Some(color.clamp())
      },
      layout=FnLayout::short(
        [("color", "vec3"), ("exposure", "float")],
        return_="vec3",
        upstream="nodes/display/ToneMappingFunctions.js:acesFilmicToneMapping",
      ),
    )
  },
)

///|
let _tone_mapping_functions_linear_rec2020_to_linear_srgb : Node = module_nodes(
  "nodes/display/ToneMappingFunctions.js:LINEAR_REC2020_TO_LINEAR_SRGB",
  fn() {
    mat3_of([
      vec3_of([1.6605, -0.1246, -0.0182]),
      vec3_of([-0.5876, 1.1329, -0.1006]),
      vec3_of([-0.0728, -0.0083, 1.1187]),
    ])
  },
)

///|
let _tone_mapping_functions_linear_srgb_to_linear_rec2020 : Node = module_nodes(
  "nodes/display/ToneMappingFunctions.js:LINEAR_SRGB_TO_LINEAR_REC2020",
  fn() {
    mat3_of([
      vec3_of([0.6274, 0.0691, 0.0164]),
      vec3_of([0.3293, 0.9195, 0.0880]),
      vec3_of([0.0433, 0.0113, 0.8956]),
    ])
  },
)

///|
let agx_default_contrast_approx : Node = module_nodes(
  "nodes/display/ToneMappingFunctions.js:agxDefaultContrastApprox",
  fn() {
    fn_(
      fn(inputs, _) {
        let x_immutable = inputs.get(0).unwrap()
        let x = vec3(x_immutable).to_var()
        let x2 = vec3(x.mul(x)).to_var()
        let x4 = vec3(x2.mul(x2)).to_var()
        Some(
          float(15.5)
          .mul(x4.mul(x2))
          .sub(mul(40.14, x4.mul(x)))
          .add(
            mul(31.96, x4)
            .sub(mul(6.868, x2.mul(x)))
            .add(mul(0.4298, x2).add(mul(0.1191, x).sub(0.00232))),
          ),
        )
      },
      layout=FnLayout::short(
        [("x", "vec3")],
        return_="vec3",
        upstream="nodes/display/ToneMappingFunctions.js:agxDefaultContrastApprox",
      ),
    )
  },
)

///|
/// `agxToneMapping( color, exposure )`: Blender's AgX.
pub let agx_tone_mapping : Node = module_nodes(
  "nodes/display/ToneMappingFunctions.js:agxToneMapping",
  fn() {
    fn_(
      fn(inputs, _) {
        let color = inputs.get(0).unwrap()
        let exposure = inputs.get(1).unwrap()
        let colortone = vec3(color).to_var()
        let agx_inset_matrix = mat3_of([
          vec3_of([0.856627153315983, 0.137318972929847, 0.11189821299995]),
          vec3_of([0.0951212405381588, 0.761241990602591, 0.0767994186031903]),
          vec3_of([0.0482516061458583, 0.101439036467562, 0.811302368396859]),
        ])
        let agx_outset_matrix = mat3_of([
          vec3_of([
            1.1271005818144368, -0.1413297634984383, -0.14132976349843826,
          ]),
          vec3_of([
            -0.11060664309660323, 1.157823702216272, -0.11060664309660294,
          ]),
          vec3_of([
            -0.016493938717834573, -0.016493938717834257, 1.2519364065950405,
          ]),
        ])
        let agx_min_ev = float(-12.47393)
        let agx_max_ev = float(4.026069)
        colortone.mul_assign(exposure)
        colortone.assign(
          _tone_mapping_functions_linear_srgb_to_linear_rec2020.mul(colortone),
        )
        colortone.assign(agx_inset_matrix.mul(colortone))
        colortone.assign(max(colortone, 1.0e-10))
        colortone.assign(log2(colortone))
        colortone.assign(
          colortone.sub(agx_min_ev).div(agx_max_ev.sub(agx_min_ev)),
        )
        colortone.assign(clamp(colortone, low=0.0, high=1.0))
        colortone.assign(agx_default_contrast_approx.call([colortone]))
        colortone.assign(agx_outset_matrix.mul(colortone))
        colortone.assign(pow(max(vec3(0.0), colortone), vec3(2.2)))
        colortone.assign(
          _tone_mapping_functions_linear_rec2020_to_linear_srgb.mul(colortone),
        )
        colortone.assign(clamp(colortone, low=0.0, high=1.0))
        Some(colortone)
      },
      layout=FnLayout::short(
        [("color", "vec3"), ("exposure", "float")],
        return_="vec3",
        upstream="nodes/display/ToneMappingFunctions.js:agxToneMapping",
      ),
    )
  },
)

///|
/// `neutralToneMapping( color, exposure )`: the Khronos PBR Neutral tone mapper.
pub let neutral_tone_mapping : Node = module_nodes(
  "nodes/display/ToneMappingFunctions.js:neutralToneMapping",
  fn() {
    fn_(
      fn(inputs, _) {
        let mut color = inputs.get(0).unwrap()
        let exposure = inputs.get(1).unwrap()
        let start_compression = float(0.8 - 0.04)
        let desaturation = float(0.15)
        color = color.mul(exposure)
        let x = min(color.r(), min(color.g(), color.b()))
        let offset = select(
          x.less_than(0.08),
          x.sub(mul(6.25, x.mul(x))),
          else_node=0.04,
        )
        color.sub_assign(offset)
        let peak = max(color.r(), max(color.g(), color.b()))
        let c = color
        if_value(peak.less_than(start_compression), fn() { c }) |> ignore
        let d = sub(1, start_compression)
        let new_peak = sub(1, d.mul(d).div(peak.add(d.sub(start_compression))))
        color.mul_assign(new_peak.div(peak))
        let g = sub(1, div(1, desaturation.mul(peak.sub(new_peak)).add(1)))
        Some(mix(color, vec3(new_peak), g))
      },
      layout=FnLayout::short(
        [("color", "vec3"), ("exposure", "float")],
        return_="vec3",
        upstream="nodes/display/ToneMappingFunctions.js:neutralToneMapping",
      ),
    )
  },
)
