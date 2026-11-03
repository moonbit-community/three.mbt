// Upstream examples/jsm/objects/SkyMesh.js: the Preetham sky of Sky.js with procedural
// clouds, as TSL on a `NodeMaterial` (WebGPURenderer).

///|
/// The uniforms upstream exposes on the instance.
pub(all) struct SkyMesh {
  turbidity : @nodes.Node
  rayleigh : @nodes.Node
  mie_coefficient : @nodes.Node
  mie_directional_g : @nodes.Node
  sun_position : @nodes.Node
  cloud_scale : @nodes.Node
  cloud_speed : @nodes.Node
  cloud_coverage : @nodes.Node
  cloud_density : @nodes.Node
  cloud_elevation : @nodes.Node
  show_sun_disc : @nodes.Node
}

///|
pub impl @core.Object3DExtension for SkyMesh with fn type_name(_) {
  "Mesh"
}

///|
pub impl @core.Object3DExtension for SkyMesh with fn construct(_) {
  SkyMesh::new()
}

///|
pub impl @core.Object3DExtension for SkyMesh with fn has_flag(_, flag) {
  flag == "isSkyMesh" || flag == "class:SkyMesh"
}

///|
#deprecated
pub extend SkyMesh with @core.Object3DExtension::{
  type_name,
  construct,
  payload,
  has_flag,
  raycast,
  copy_from,
  to_json,
  update_matrix_world,
  update_world_matrix,
  intersects_frustum,
  get_world_direction,
  dispose,
}

///|
/// The payload of a `SkyMesh`, or `None` for other objects.
pub fn SkyMesh::of(object : @core.Object3D) -> SkyMesh? {
  objects_payload(object, "class:SkyMesh")
}

///|
/// `new SkyMesh()`: a unit box; scale it up and set the uniforms (`SkyMesh::of`).
pub fn SkyMesh::new() -> @core.Object3D {
  let material = @nodes.NodeMaterial::new()
  let object = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(width=1.0, height=1.0, depth=1.0),
    material=Single(material),
  )
  let sky : SkyMesh = {
    turbidity: @nodes.uniform(2),
    rayleigh: @nodes.uniform(1),
    mie_coefficient: @nodes.uniform(0.005),
    mie_directional_g: @nodes.uniform(0.8),
    sun_position: @nodes.uniform(@math.Vector3::new(0.0, 0.0, 0.0)),
    cloud_scale: @nodes.uniform(0.0002),
    cloud_speed: @nodes.uniform(0.00002),
    cloud_coverage: @nodes.uniform(0.4),
    cloud_density: @nodes.uniform(0.4),
    cloud_elevation: @nodes.uniform(0.5),
    show_sun_disc: @nodes.uniform(1),
  }
  object.set_extension(sky) |> ignore
  // Varyings
  let v_sun_direction = @nodes.varying_property("vec3")
  let v_sun_e = @nodes.varying_property("float")
  let v_beta_r = @nodes.varying_property("vec3")
  let v_beta_m = @nodes.varying_property("vec3")
  let vertex_node = @nodes.fn_(fn(_, _) {
    // constants for atmospheric scattering
    let e = @nodes.float(2.718281828459045)
    // const pi = float( 3.141592653589793 );

    // wavelength of used primaries, according to preetham
    // const lambda = vec3( 680E-9, 550E-9, 450E-9 );
    // this pre-calculation replaces older TotalRayleigh(vec3 lambda) function:
    // (8.0 * pow(pi, 3.0) * pow(pow(n, 2.0) - 1.0, 2.0) * (6.0 + 3.0 * pn)) / (3.0 * N * pow(lambda, vec3(4.0)) * (6.0 - 7.0 * pn))
    let total_rayleigh = @nodes.vec3_of([
      5.804542996261093E-6, 1.3562911419845635E-5, 3.0265902468824876E-5,
    ])
    // mie stuff
    // K coefficient for the primaries
    // const v = float( 4.0 );
    // const K = vec3( 0.686, 0.678, 0.666 );
    // MieConst = pi * pow( ( 2.0 * pi ) / lambda, vec3( v - 2.0 ) ) * K
    let mie_const = @nodes.vec3_of([
      1.8399918514433978E14, 2.7798023919660528E14, 4.0790479543861094E14,
    ])
    // earth shadow hack
    // cutoffAngle = pi / 1.95;
    let cutoff_angle = @nodes.float(1.6110731556870734)
    let steepness = @nodes.float(1.5)
    let ee = @nodes.float(1000.0)
    // varying sun position
    let sun_direction = @nodes.normalize(sky.sun_position)
    v_sun_direction.assign(sun_direction)
    // varying sun intensity
    let angle = sun_direction.y()
    let zenith_angle_cos = @nodes.clamp(angle, low=-1, high=1)
    let sun_intensity = ee.mul(
      @nodes.max(
        0.0,
        @nodes.float(1.0).sub(
          @nodes.pow(
            e,
            cutoff_angle
            .sub(@nodes.acos(zenith_angle_cos))
            .div(steepness)
            .negate(),
          ),
        ),
      ),
    )
    v_sun_e.assign(sun_intensity)
    // sun fade
    let sunfade = @nodes.float(1.0).sub(
      @nodes.clamp(
        @nodes.float(1.0).sub(@nodes.exp(sky.sun_position.y().div(450000.0))),
        low=0,
        high=1,
      ),
    )
    // varying vBetaR
    let rayleigh_coefficient = sky.rayleigh.sub(
      @nodes.float(1.0).mul(@nodes.float(1.0).sub(sunfade)),
    )
    // extinction (absorption + out scattering)
    // rayleigh coefficients
    v_beta_r.assign(total_rayleigh.mul(rayleigh_coefficient))
    // varying vBetaM
    let c = @nodes.float(0.2).mul(sky.turbidity).mul(10.0E-18)
    let total_mie = @nodes.float(0.434).mul(c).mul(mie_const)
    v_beta_m.assign(total_mie.mul(sky.mie_coefficient))
    // position
    let position = @nodes.model_view_projection
    position.z().assign(position.w()) // set z to camera.far
    Some(position)
  }).call([])
  let color_node = @nodes.fn_(fn(_, _) {
    // constants for atmospheric scattering
    let pi = @nodes.float(3.141592653589793)
    // optical length at zenith for molecules
    let rayleigh_zenith_length = @nodes.float(8.4E3)
    let mie_zenith_length = @nodes.float(1.25E3)
    // 66 arc seconds -> degrees, and the cosine of that
    let sun_angular_diameter_cos = @nodes.float(0.9999566769464484)
    // 3.0 / ( 16.0 * pi )
    let three_over_sixteenpi = @nodes.float(0.05968310365946075)
    // 1.0 / ( 4.0 * pi )
    let one_over_fourpi = @nodes.float(0.07957747154594767)
    //
    let direction = @nodes.normalize(
      @nodes.position_world.sub(@nodes.camera_position),
    )
    // optical length
    // cutoff angle at 90 to avoid singularity in next formula.
    let zenith_angle = @nodes.acos(@nodes.max(0.0, direction.y()))
    let inverse = @nodes.float(1.0).div(
      @nodes.cos(zenith_angle).add(
        @nodes.float(0.15).mul(
          @nodes.pow(
            @nodes.float(93.885).sub(zenith_angle.mul(180.0).div(pi)),
            -1.253,
          ),
        ),
      ),
    )
    let s_r = rayleigh_zenith_length.mul(inverse)
    let s_m = mie_zenith_length.mul(inverse)
    // combined extinction factor
    let fex = @nodes.exp(
      @nodes.mul(v_beta_r, s_r).add(@nodes.mul(v_beta_m, s_m)).negate(),
    )
    // in scattering
    let cos_theta = @nodes.dot(direction, v_sun_direction)
    // betaRTheta
    let c = cos_theta.mul(0.5).add(0.5)
    let r_phase = three_over_sixteenpi.mul(
      @nodes.float(1.0).add(@nodes.pow(c, 2.0)),
    )
    let beta_r_theta = v_beta_r.mul(r_phase)
    // betaMTheta
    let g2 = @nodes.pow(sky.mie_directional_g, 2.0)
    let inv = @nodes.float(1.0).div(
      @nodes.pow(
        @nodes.float(1.0)
        .sub(@nodes.float(2.0).mul(sky.mie_directional_g).mul(cos_theta))
        .add(g2),
        1.5,
      ),
    )
    let m_phase = one_over_fourpi.mul(@nodes.float(1.0).sub(g2)).mul(inv)
    let beta_m_theta = v_beta_m.mul(m_phase)
    let lin = @nodes.pow(
      v_sun_e
      .mul(
        @nodes.add(beta_r_theta, beta_m_theta).div(
          @nodes.add(v_beta_r, v_beta_m),
        ),
      )
      .mul(@nodes.sub(1.0, fex)),
      @nodes.vec3(1.5),
    )
    lin.mul_assign(
      @nodes.mix(
        @nodes.vec3(1.0),
        @nodes.pow(
          v_sun_e
          .mul(
            @nodes.add(beta_r_theta, beta_m_theta).div(
              @nodes.add(v_beta_r, v_beta_m),
            ),
          )
          .mul(fex),
          @nodes.vec3(1.0 / 2.0),
        ),
        @nodes.clamp(
          @nodes.pow(@nodes.sub(1.0, v_sun_direction.y()), 5.0),
          low=0.0,
          high=1.0,
        ),
      ),
    )
    // nightsky
    let l0 = @nodes.vec3(0.1).mul(fex)
    // composition + solar disc
    let sundisc = @nodes.clamp(
      cos_theta.sub(sun_angular_diameter_cos).mul(50000.0),
      low=0.0,
      high=1.0,
    ).mul(sky.show_sun_disc)
    let sundisc_color = @nodes.min(v_sun_e.mul(fex), 80.0)
      .mul(760.0)
      .mul(sundisc)
    let tex_color = @nodes.add(lin, l0)
      .mul(0.04)
      .add(sundisc_color)
      .add(@nodes.vec3_of([0.0, 0.0003, 0.00075]))
      .to_var()
    // gradient at a lattice corner; sinless hash so every GPU produces the same clouds
    let gradient = @nodes.fn_(
      fn(inputs, _) {
        let i = inputs.get(0).unwrap()
        let p = @nodes.fract(
          i.xyx().mul(@nodes.vec3_of([0.1031, 0.1030, 0.0973])),
        ).to_var()
        p.add_assign(@nodes.dot(p, p.yzx().add(33.33)))
        Some(@nodes.fract(p.xx().add(p.yz()).mul(p.zy())).mul(2.0).sub(1.0))
      },
      layout=@nodes.FnLayout::short([("i", "vec2")], return_="vec2"),
    )
    // 2D gradient noise: isotropic lobes like Perlin at value-noise cost
    let noise = @nodes.fn_(
      fn(inputs, _) {
        let p = inputs.get(0).unwrap()
        let i = @nodes.floor(p)
        let f = @nodes.fract(p)
        let u = f.mul(f).mul(f).mul(f.mul(f.mul(6.0).sub(15.0)).add(10.0)) // quintic fade
        let a = @nodes.dot(gradient.call([i]), f)
        let b = @nodes.dot(
          gradient.call([i.add(@nodes.vec2_of([1.0, 0.0]))]),
          f.sub(@nodes.vec2_of([1.0, 0.0])),
        )
        let c = @nodes.dot(
          gradient.call([i.add(@nodes.vec2_of([0.0, 1.0]))]),
          f.sub(@nodes.vec2_of([0.0, 1.0])),
        )
        let d = @nodes.dot(
          gradient.call([i.add(@nodes.vec2_of([1.0, 1.0]))]),
          f.sub(@nodes.vec2_of([1.0, 1.0])),
        )
        Some(
          @nodes.mix(@nodes.mix(a, b, u.x()), @nodes.mix(c, d, u.x()), u.y()).mul(
            1.6,
          ), // ~[-1,1]
        )
      },
      layout=@nodes.FnLayout::short([("p", "vec2")], return_="float"),
    )
    // fbm; per-octave drift makes clouds billow instead of scrolling as a rigid stamp
    let fbm = @nodes.fn_(
      fn(inputs, _) {
        let position = inputs.get(0).unwrap()
        let drift = inputs.get(1).unwrap()
        let p = @nodes.vec2(position).to_var()
        let result = @nodes.float(0.0).to_var()
        let amplitude = @nodes.float(1.0).to_var()
        @nodes.loop_([4], fn(_) {
          result.add_assign(amplitude.mul(noise.call([p])))
          amplitude.mul_assign(0.5)
          p.mul_assign(2.0)
          p.add_assign(drift)
        })
        Some(result)
      },
      layout=@nodes.FnLayout::short(
        [("position", "vec2"), ("drift", "vec2")],
        return_="float",
      ),
    )
    // Clouds
    @nodes.if_(
      direction.y().greater_than(0.0).and_(sky.cloud_coverage.greater_than(0.0)),
      fn() {
        // Project to cloud plane (higher elevation = clouds appear lower/closer)
        let elevation = @nodes.mix(1.0, 0.1, sky.cloud_elevation)
        let cloud_uv = direction.xz().div(direction.y().mul(elevation)).to_var()
        cloud_uv.mul_assign(sky.cloud_scale)
        cloud_uv.add_assign(@nodes.time.mul(sky.cloud_speed))
        // Cloud density field
        let evolve = @nodes.time.mul(sky.cloud_speed).mul(300.0)
        let cloud_noise = fbm
          .call([cloud_uv.mul(1000.0), evolve])
          .mul(0.7)
          .add(0.5)
          .clamp(low=0.0, high=1.0)
          .to_var()
        // Large-scale coverage variation: clear gaps next to dense banks
        let region = noise.call([cloud_uv.mul(300.0)]).mul(0.37).add(0.5)
        let cov = @nodes.clamp(
          sky.cloud_coverage.add(region.sub(0.5).mul(0.6)),
          low=0.0,
          high=1.0,
        )
        // Carve clouds where noise rises above the coverage level
        let threshold = @nodes.sub(1.0, cov).to_var()
        let cloud_mask = @nodes.smoothstep(
          threshold,
          threshold.add(0.3),
          cloud_noise,
        ).to_var()
        // Fade clouds near horizon (adjusted by elevation)
        let horizon_fade = @nodes.smoothstep(
          0.0,
          @nodes.add(0.03, @nodes.mul(0.06, sky.cloud_elevation)),
          direction.y(),
        )
        cloud_mask.mul_assign(horizon_fade)
        // Cloud lighting from the sky's own radiance
        let day_factor = @nodes.smoothstep(-0.08, 0.3, v_sun_direction.y())
        // 0.22 ~ albedo/pi, 0.04 = exposure; the aerial composite adds the eye-leg extinction
        let sun_color = v_sun_e.mul(fex).mul(0.22).mul(0.04).to_var()
        let sky_ambient = lin
          .mul(0.04)
          .add(@nodes.vec3_of([0.0, 0.0003, 0.00075]))
        // Beer-powder self-shadow from the sampled density
        let depth = @nodes.max(0.0, cloud_noise.sub(threshold)).to_var()
        let beer = @nodes.exp(depth.mul(-4.0)).to_var()
        let powder = @nodes.sub(1.0, beer.mul(beer)) // beer*beer == exp(-8*depth)
        // 2.6 = 1/0.385, normalizes beer*powder peak to 1
        let shade = @nodes.mix(
          0.45,
          1.0,
          beer.mul(powder).mul(2.6).clamp(low=0.0, high=1.0),
        )
        // Henyey-Greenstein forward lobe ( g = 0.7 ): silver lining on rims toward the sun
        // 0.51=1-g^2, 1.49=1+g^2, 1.4=2g
        let silver = @nodes.float(0.51)
          .div(@nodes.pow(@nodes.sub(1.49, cos_theta.mul(1.4)), 1.5))
          .clamp(low=0.0, high=3.0)
        let edge = cloud_mask.mul(@nodes.sub(1.0, cloud_mask)).mul(4.0)
        let cloud_color = sky_ambient.add(sun_color.mul(shade)).to_var()
        cloud_color.add_assign(sun_color.mul(silver).mul(edge).mul(0.6))
        cloud_color.mul_assign(day_factor.max(0.03))
        // Cloud opacity via Beer's law: density sets how solid the clouds get
        let alpha = @nodes.sub(
            1.0,
            @nodes.exp(depth.mul(sky.cloud_density).mul(-12.0)),
          )
          .mul(horizon_fade)
          .to_var()
        // Occlude the sun disc/glow behind opaque cloud
        tex_color.sub_assign(l0.mul(0.04).add(sundisc_color).mul(alpha))
        // Composite through the atmosphere so distant clouds dissolve into haze
        let cloud_aerial = @nodes.mix(tex_color, cloud_color, fex)
        tex_color.assign(@nodes.mix(tex_color, cloud_aerial, alpha))
      },
    )
    |> ignore
    Some(@nodes.vec4_of([tex_color, 1.0]))
  }).call([])
  material.side = @core.BackSide
  material.depth_write = false
  material.fog = Some(false)
  let node_material = @nodes.NodeMaterial::of(material).unwrap()
  node_material.vertex_node = Some(vertex_node)
  node_material.color_node = Some(color_node)
  object
}
