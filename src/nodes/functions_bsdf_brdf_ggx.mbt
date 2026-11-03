// nodes/functions/BSDF/BRDF_GGX.js

///|
/// `defined( v )` of an optional Fn input (`undefined` is not defined).
fn bsdf_defined(value : Node?) -> Bool {
  match value {
    Some(n) => defined(Node(n))
    None => false
  }
}

///|
/// `BRDF_GGX( { lightDirection, f0, f90, roughness, f, normalView, viewDirection,
/// USE_IRIDESCENCE, USE_ANISOTROPY } )`: GGX distribution, Schlick Fresnel and
/// GGX_SmithCorrelated visibility.
pub let brdf_ggx : Node = module_nodes(
  "nodes/functions/BSDF/BRDF_GGX.js:BRDF_GGX",
  fn() {
    fn_(fn(inputs, _) {
      let light_direction = inputs.named("lightDirection").unwrap()
      let f0 = inputs.named("f0").unwrap()
      let f90 = inputs.named("f90").unwrap()
      let roughness = inputs.named("roughness").unwrap()
      let f = inputs.named("f")
      let normal_view = inputs.named("normalView").or_else(fn() { normal_view })
      let view_direction = inputs
        .named("viewDirection")
        .or_else(fn() { position_view_direction })
      let use_iridescence = inputs.named("USE_IRIDESCENCE")
      let use_anisotropy = inputs.named("USE_ANISOTROPY")
      let alpha = roughness.max(0.045).pow2()
      let half_dir = light_direction.add(view_direction).normalize()
      let dot_nl = normal_view.dot(light_direction).clamp()
      let dot_nv = normal_view.dot(view_direction).clamp()
      let dot_nh = normal_view.dot(half_dir).clamp()
      let dot_vh = view_direction.dot(half_dir).clamp()
      let mut f_ = f_schlick.call_named({
        "f0": f0,
        "f90": f90,
        "dotVH": dot_vh,
      })
      if bsdf_defined(use_iridescence) {
        f_ = iridescence.mix(f_, f.unwrap())
      }
      let (v, d) = if bsdf_defined(use_anisotropy) {
        let dot_tl = anisotropy_t.dot(light_direction)
        let dot_tv = anisotropy_t.dot(view_direction)
        let dot_th = anisotropy_t.dot(half_dir)
        let dot_bl = anisotropy_b.dot(light_direction)
        let dot_bv = anisotropy_b.dot(view_direction)
        let dot_bh = anisotropy_b.dot(half_dir)
        let clamped_alpha_t = alpha_t.max(alpha)
        let v = v_ggx_smith_correlated_anisotropic.call_named({
          "alphaT": clamped_alpha_t,
          "alphaB": alpha,
          "dotTV": dot_tv,
          "dotBV": dot_bv,
          "dotTL": dot_tl,
          "dotBL": dot_bl,
          "dotNV": dot_nv,
          "dotNL": dot_nl,
        })
        let d = d_ggx_anisotropic.call_named({
          "alphaT": clamped_alpha_t,
          "alphaB": alpha,
          "dotNH": dot_nh,
          "dotTH": dot_th,
          "dotBH": dot_bh,
        })
        (v, d)
      } else {
        let v = v_ggx_smith_correlated.call_named({
          "alpha": alpha,
          "dotNL": dot_nl,
          "dotNV": dot_nv,
        })
        let d = d_ggx.call_named({ "alpha": alpha, "dotNH": dot_nh })
        (v, d)
      }
      Some(f_.mul(v).mul(d))
    })
  },
)
