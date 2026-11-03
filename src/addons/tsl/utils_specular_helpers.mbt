// examples/jsm/tsl/utils/SpecularHelpers.js

///|
/// Ray length used for rays that miss the scene (environment hits).
pub const ENV_RAY_LENGTH : Double = 10000.0

///|
/// Ray lengths above this are treated as environment hits.
pub const ENV_RAY_LENGTH_THRESHOLD : Double = 1000.0

///|
priv struct SpecularHelpersModule {
  sample_ggx_vndf : @nodes.Node
  d_gtr : @nodes.Node
  smith_g : @nodes.Node
  geometry_term : @nodes.Node
  ggx_vndf_pdf : @nodes.Node
  f_schlick : @nodes.Node
  get_specular_dominant_factor : @nodes.Node
  ggx_reflection_struct : @nodes.StructFn
  ggx_reflection_sample_with_reflectance : @nodes.Node
  equirect_uv_to_dir : @nodes.Node
  equirect_dir_pdf : @nodes.Node
  mis_power_heuristic : @nodes.Node
}

///|
let utils_specular_helpers_module : AddonModule[SpecularHelpersModule] = AddonModule::new(fn() {
    // Bounded-VNDF sampler (Eto & Tokuyoshi 2023; spherical-cap form, Dupuy & Benyoub 2023)
    let sample_ggx_vndf = @nodes.fn_(
      fn(inputs, _) {
        let v = addon_arg(inputs, 0)
        let ax = addon_arg(inputs, 1)
        let ay = addon_arg(inputs, 2)
        let r1 = addon_arg(inputs, 3)
        let r2 = addon_arg(inputs, 4)
        // Warp the view direction to the hemisphere ("standard") configuration.
        let wi_std = @nodes.normalize(
          @nodes.vec3_of([ax.mul(v.x()), ay.mul(v.y()), v.z()]),
        ).to_var()
        // Isotropic bound on the spherical cap (Eto & Tokuyoshi eq. 5).
        let a = ax.min(ay).to_var()
        let s = @nodes.float(1.0).add(v.xy().length()).to_var()
        let a2 = a.mul(a).to_var()
        let s2 = s.mul(s).to_var()
        let k = a2
          .one_minus()
          .mul(s2)
          .div(s2.add(a2.mul(v.z()).mul(v.z())))
          .to_var()
        // Tighten the cap with the bound (upper hemisphere; N·V ≥ 0 in our usage).
        let b = wi_std.z().mul(k).to_var()
        // Sample the (bounded) spherical cap.
        let phi = @nodes.float(6.283185307179586).mul(r1).to_var() // 2*pi
        let z = r2.one_minus().mul(@nodes.float(1.0).add(b)).sub(b).to_var()
        let sin_theta = @nodes.sqrt(
          @nodes.max(@nodes.float(0.0), @nodes.float(1.0).sub(z.mul(z))),
        ).to_var()
        let c = @nodes.vec3_of([
          sin_theta.mul(@nodes.cos(phi)),
          sin_theta.mul(@nodes.sin(phi)),
          z,
        ]).to_var()
        // Microfacet normal in the standard config, then warp back to the ellipsoid.
        let wm_std = c.add(wi_std).to_var()
        let ne = @nodes.normalize(
          @nodes.vec3_of([
            ax.mul(wm_std.x()),
            ay.mul(wm_std.y()),
            @nodes.max(@nodes.float(0.0), wm_std.z()),
          ]),
        ).to_var()
        Some(ne)
      },
      layout=addon_short_layout(
        [
          ("V", "vec3"),
          ("ax", "float"),
          ("ay", "float"),
          ("r1", "float"),
          ("r2", "float"),
        ],
        "vec3",
      ),
    )
    // Generalized Trowbridge-Reitz (GTR). For GGX set k=2.
    let d_gtr = @nodes.fn_(
      fn(inputs, _) {
        let roughness = addon_arg(inputs, 0)
        let no_h = addon_arg(inputs, 1)
        let k = addon_arg(inputs, 2)
        let a2 = roughness.mul(roughness).to_var() // α²
        let no_h2 = no_h.mul(no_h).to_var()
        let base = no_h2
          .mul(a2.sub(@nodes.float(1.0)))
          .add(@nodes.float(1.0))
          .to_var()
        // a² / (π * base^k)
        Some(a2.div(@nodes.pi.mul(@nodes.pow(base, k))).to_var())
      },
      layout=addon_short_layout(
        [("roughness", "float"), ("NoH", "float"), ("k", "float")],
        "float",
      ),
    )
    // Smith G1 (Heitz): expects alpha (not squared); it squares internally
    let smith_g = @nodes.fn_(
      fn(inputs, _) {
        let n_dot_x = addon_arg(inputs, 0)
        let alpha = addon_arg(inputs, 1)
        let a2 = alpha.mul(alpha).to_var() // α²
        let n_dot_x2 = n_dot_x.mul(n_dot_x).to_var() // (N·X)²
        Some(
          @nodes.float(2.0)
          .mul(n_dot_x)
          .div(n_dot_x.add(@nodes.sqrt(a2.add(a2.one_minus().mul(n_dot_x2))))),
        )
      },
      layout=addon_short_layout(
        [("NDotX", "float"), ("alpha", "float")],
        "float",
      ),
    )
    // Geometry term G = G1(N·L, α_G) * G1(N·V, α_G)  (α_G is NOT squared here)
    let geometry_term = @nodes.fn_(
      fn(inputs, _) {
        let no_l = addon_arg(inputs, 0)
        let no_v = addon_arg(inputs, 1)
        let alpha_g = addon_arg(inputs, 2)
        let g1v = smith_g.call([no_v, alpha_g]).to_var()
        let g1l = smith_g.call([no_l, alpha_g]).to_var()
        Some(g1v.mul(g1l).to_var())
      },
      layout=addon_short_layout(
        [("NoL", "float"), ("NoV", "float"), ("alphaG", "float")],
        "float",
      ),
    )
    // Bounded VNDF direction PDF (reflection mapping), matching SampleGGXVNDF above.
    let ggx_vndf_pdf = @nodes.fn_(
      fn(inputs, _) {
        let no_h = addon_arg(inputs, 0)
        let no_v = addon_arg(inputs, 1)
        let roughness = addon_arg(inputs, 2)
        let d = d_gtr.call([roughness, no_h, @nodes.float(2.0)]).to_var()
        let a2 = roughness.mul(roughness).to_var()
        let sin_v2 = @nodes.max(
          @nodes.float(0.0),
          @nodes.float(1.0).sub(no_v.mul(no_v)),
        ).to_var() // ‖V.xy‖²
        let s = @nodes.float(1.0).add(@nodes.sqrt(sin_v2)).to_var()
        let s2 = s.mul(s).to_var()
        let k = @nodes.float(1.0)
          .sub(a2)
          .mul(s2)
          .div(s2.add(a2.mul(no_v).mul(no_v)))
          .to_var()
        let t = @nodes.sqrt(a2.mul(sin_v2).add(no_v.mul(no_v))).to_var()
        Some(
          d
          .div(
            @nodes.max(
              @nodes.float(@nodes.epsilon),
              @nodes.float(2.0).mul(k.mul(no_v).add(t)),
            ),
          )
          .to_var(),
        )
      },
      layout=addon_short_layout(
        [("NoH", "float"), ("NoV", "float"), ("roughness", "float")],
        "float",
      ),
    )
    let f_schlick = @nodes.fn_(
      fn(inputs, _) {
        let f0 = addon_arg(inputs, 0)
        let theta = addon_arg(inputs, 1)
        let f90 = inputs.get(2).or_else(fn() { @nodes.float(1) })
        let one_minus = @nodes.float(1.0).sub(theta).to_var()
        let one_minus2 = one_minus.mul(one_minus).to_var()
        let one_minus5 = one_minus2.mul(one_minus2).mul(one_minus).to_var()
        Some(f0.add(@nodes.vec3(f90).sub(f0).mul(one_minus5)).to_var()) // vec3
      },
      layout=addon_short_layout(
        [("f0", "vec3"), ("theta", "float"), ("f90", "float")],
        "vec3",
      ),
    )
    let get_specular_dominant_factor = @nodes.fn_(
      fn(inputs, _) {
        let no_v = addon_arg(inputs, 0)
        let roughness = addon_arg(inputs, 1)
        let a = @nodes.float(0.298475).mul(
          @nodes.log(
            @nodes.float(39.4115).sub(@nodes.float(39.0029).mul(roughness)),
          ),
        )
        let f = @nodes.float(1.0)
          .sub(no_v)
          .pow(10.8649)
          .mul(@nodes.float(1.0).sub(a))
          .add(a)
        Some(@nodes.clamp(f))
      },
      layout=addon_short_layout(
        [("NoV", "float"), ("roughness", "float")],
        "float",
      ),
    )
    let ggx_reflection_struct = @nodes.struct_([
      @nodes.StructMember::new("reflectDir", "vec3"), // view-space reflected ray direction
      @nodes.StructMember::new("sampleWeight", "vec3"), // chromatic weight (incl. Fresnel tint)
      @nodes.StructMember::new("pdf", "float"), // VNDF direction pdf (for MIS against the env CDF)
      @nodes.StructMember::new("NdotV", "float"),
      @nodes.StructMember::new("alpha", "float"), // GGX alpha (roughness²), clamped
      @nodes.StructMember::new("f90", "float"),
      @nodes.StructMember::new("f0", "vec3"), // Fresnel reflectance at normal incidence
    ])
    // Core of `ggxReflectionSample()` with explicit F0/F90.
    let ggx_reflection_sample_with_reflectance = @nodes.fn_(fn(inputs, _) {
      let n = addon_arg(inputs, 0)
      let v = addon_arg(inputs, 1)
      let roughness = addon_arg(inputs, 2)
      let f0 = addon_arg(inputs, 3)
      let f90 = addon_arg(inputs, 4)
      let xi = addon_arg(inputs, 5)
      // GGX alpha (use r^2, clamp to avoid degenerate)
      let a = roughness.mul(roughness).max(0.001).to_var()
      let ax = a.to_var()
      let ay = a.to_var()
      // TBN from view-space normal
      let up = n
        .z()
        .abs()
        .less_than(0.999)
        .select(@nodes.vec3_of([0, 0, 1]), else_node=@nodes.vec3_of([1, 0, 0]))
      let t = @nodes.cross(up, n).normalize().to_var()
      let b = @nodes.cross(n, t).normalize().to_var()
      // transform V to LOCAL frame (N = +Z)
      let v_local = @nodes.vec3_of([
        @nodes.dot(t, v),
        @nodes.dot(b, v),
        @nodes.dot(n, v),
      ]).to_var()
      // VNDF sample **in local frame**
      let h_local = sample_ggx_vndf
        .call([v_local, ax, ay, xi.x(), xi.y()])
        .to_var()
      @nodes.if_(h_local.z().less_than(0), fn() {
        h_local.assign(h_local.negate())
      })
      |> ignore
      // transform H back to VIEW space
      let h = @nodes.normalize(
        t.mul(h_local.x()).add(b.mul(h_local.y())).add(n.mul(h_local.z())),
      ).to_var()
      // reflect with V (surface->camera) and H
      let view_reflect_dir = @nodes.reflect(v.negate(), h).normalize().to_var()
      // BRDF/PDF evaluation for the sampled direction
      let l = view_reflect_dir.to_var()
      let h2 = @nodes.normalize(v.add(l)).to_var() // ~h; recomputed for robustness
      let n_dot_v = @nodes.max(@nodes.float(0.0), @nodes.dot(n, v)).to_var()
      let n_dot_l = @nodes.max(@nodes.float(0.0), @nodes.dot(n, l)).to_var()
      let n_dot_h = @nodes.max(@nodes.float(0.0), @nodes.dot(n, h2)).to_var()
      let v_dot_h = @nodes.max(@nodes.float(0.0), @nodes.dot(v, h2)).to_var()
      // Chromatic Fresnel reflectance
      let fresnel_weight = f_schlick.call([f0, v_dot_h, f90]).to_var() // vec3
      // Bounded-VNDF direction pdf — still needed for the env-miss MIS path.
      let pdf = ggx_vndf_pdf.call([n_dot_h, n_dot_v, ax]).to_var()
      // Numerically stable importance weight (cancels the GGX D analytically).
      let a2 = ax.mul(ax).to_var()
      let sin_v2 = n_dot_v.mul(n_dot_v).one_minus().max(0.0).to_var() // ‖V.xy‖²
      let s_b = @nodes.float(1.0).add(@nodes.sqrt(sin_v2)).to_var()
      let s2_b = s_b.mul(s_b).to_var()
      let k_b = a2
        .one_minus()
        .mul(s2_b)
        .div(s2_b.add(a2.mul(n_dot_v).mul(n_dot_v)))
        .to_var()
      let t_b = @nodes.sqrt(a2.mul(sin_v2).add(n_dot_v.mul(n_dot_v))).to_var()
      let glossy_weight = fresnel_weight
        .mul(geometry_term.call([n_dot_l, n_dot_v, ax]))
        .mul(k_b.mul(n_dot_v).add(t_b))
        .div(@nodes.float(2.0).mul(n_dot_v).max(1.0e-4))
        .to_var()
      Some(
        ggx_reflection_struct.call([
          view_reflect_dir, glossy_weight, pdf, n_dot_v, ax, f90, f0,
        ]),
      )
    })
    // uv -> direction (equirectangular)
    let equirect_uv_to_dir = @nodes.fn_(
      fn(inputs, _) {
        let uv_in = addon_arg(inputs, 0)
        let phi = uv_in.x().mul(ADDON_PI * 2.0).sub(ADDON_PI)
        let lat = uv_in.y().sub(0.5).mul(ADDON_PI)
        let cos_lat = @nodes.cos(lat)
        Some(
          @nodes.normalize(
            @nodes.vec3_of([
              cos_lat.mul(@nodes.cos(phi)),
              @nodes.sin(lat),
              cos_lat.mul(@nodes.sin(phi)),
            ]),
          ),
        )
      },
      layout=addon_short_layout([("uv", "vec2")], "vec3"),
    )
    // Solid-angle PDF of a direction under equirectangular parameterization.
    let equirect_dir_pdf = @nodes.fn_(
      fn(inputs, _) {
        let direction = addon_arg(inputs, 0)
        let uv_dir = @nodes.equirect_uv.call([direction])
        let sin_theta = @nodes.sin(uv_dir.y().mul(ADDON_PI))
        Some(
          sin_theta
          .abs()
          .less_than(@nodes.float(@nodes.epsilon))
          .select(
            @nodes.float(0),
            else_node=@nodes.float(1).div(
              @nodes.float(2.0 * ADDON_PI * ADDON_PI).mul(sin_theta),
            ),
          ),
        )
      },
      layout=addon_short_layout([("direction", "vec3")], "float"),
    )
    let mis_power_heuristic = @nodes.fn_(
      fn(inputs, _) {
        let pdf_a = addon_arg(inputs, 0)
        let pdf_b = addon_arg(inputs, 1)
        let pdf_a_sq = pdf_a.mul(pdf_a)
        let pdf_b_sq = pdf_b.mul(pdf_b)
        Some(pdf_a_sq.div(pdf_a_sq.add(pdf_b_sq)))
      },
      layout=addon_short_layout([("pdfA", "float"), ("pdfB", "float")], "float"),
    )
    {
      sample_ggx_vndf,
      d_gtr,
      smith_g,
      geometry_term,
      ggx_vndf_pdf,
      f_schlick,
      get_specular_dominant_factor,
      ggx_reflection_struct,
      ggx_reflection_sample_with_reflectance,
      equirect_uv_to_dir,
      equirect_dir_pdf,
      mis_power_heuristic,
    }
  },
)

///|
/// Evaluates SpecularHelpers.js (its module-level `Fn`s), as `import` does.
pub fn load_utils_specular_helpers() -> Unit {
  utils_specular_helpers_module.get() |> ignore
}

///|
/// `D_GTR( roughness, NoH, k )`: generalized Trowbridge-Reitz (GGX for k = 2).
pub fn d_gtr() -> @nodes.Node {
  utils_specular_helpers_module.get().d_gtr
}

///|
/// `SmithG( NDotX, alpha )`: Smith G1 (Heitz).
pub fn smith_g() -> @nodes.Node {
  utils_specular_helpers_module.get().smith_g
}

///|
/// `GeometryTerm( NoL, NoV, alphaG )`.
pub fn geometry_term() -> @nodes.Node {
  utils_specular_helpers_module.get().geometry_term
}

///|
/// `F_Schlick( f0, theta, f90 = 1 )`.
pub fn f_schlick() -> @nodes.Node {
  utils_specular_helpers_module.get().f_schlick
}

///|
/// `getSpecularDominantFactor( NoV, roughness )`.
pub fn get_specular_dominant_factor() -> @nodes.Node {
  utils_specular_helpers_module.get().get_specular_dominant_factor
}

///|
/// `ggxReflectionSample( N, V, roughness, metalness, albedo, Xi, f0 = null, f90 = 1 )`:
/// a GGX reflection sample struct (`reflectDir`, `sampleWeight`, `pdf`, `NdotV`, `alpha`,
/// `f90`, `f0`).
pub fn ggx_reflection_sample(
  n : &@nodes.IntoTsl,
  v : &@nodes.IntoTsl,
  roughness : &@nodes.IntoTsl,
  metalness : &@nodes.IntoTsl,
  albedo : &@nodes.IntoTsl,
  xi : &@nodes.IntoTsl,
  f0? : &@nodes.IntoTsl,
  f90? : &@nodes.IntoTsl,
) -> @nodes.Node {
  let m = utils_specular_helpers_module.get()
  let f0 : &@nodes.IntoTsl = match f0 {
    Some(f) if !f.to_tsl().is_nullish() => f
    _ => @nodes.mix(@nodes.vec3(0.04), albedo, metalness)
  }
  let f90 : &@nodes.IntoTsl = match f90 {
    Some(f) => f
    None => 1
  }
  m.ggx_reflection_sample_with_reflectance.call([
    n,
    v,
    roughness,
    f0,
    @nodes.float(f90),
    xi,
  ])
}

///|
/// `equirectUvToDir( uv )`.
pub fn equirect_uv_to_dir() -> @nodes.Node {
  utils_specular_helpers_module.get().equirect_uv_to_dir
}

///|
/// `equirectDirPdf( direction )`.
pub fn equirect_dir_pdf() -> @nodes.Node {
  utils_specular_helpers_module.get().equirect_dir_pdf
}

///|
/// `misPowerHeuristic( pdfA, pdfB )`.
pub fn mis_power_heuristic() -> @nodes.Node {
  utils_specular_helpers_module.get().mis_power_heuristic
}
