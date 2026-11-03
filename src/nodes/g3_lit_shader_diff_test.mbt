// The lit G3 shader scenarios (lights and lighting models): `lightingContext(
// lightsNode, lightingModel, materialLightings )` as NodeMaterial.setupLights builds
// it, for a mesh with every attribute, a perspective camera, a material and the context
// callbacks a node material sets. Upstream side: the `lit` list of upstream_g3.mjs.

///|
fn g3_lit_attribute(n : Int32, item_size : Int32) -> @core.GeometryAttribute {
  Buffer(
    @core.BufferAttribute::new(
      @core.TypedArray::float32(n * item_size),
      item_size,
    ),
  )
}

///|
let g3_lit_geometry : @core.BufferGeometry = {
  let g = @core.BufferGeometry::new()
  g.set_attribute("position", g3_lit_attribute(24, 3)) |> ignore
  g.set_attribute("normal", g3_lit_attribute(24, 3)) |> ignore
  g.set_attribute("uv", g3_lit_attribute(24, 2)) |> ignore
  g.set_attribute("uv1", g3_lit_attribute(24, 2)) |> ignore
  g.set_attribute("tangent", g3_lit_attribute(24, 4)) |> ignore
  g.set_attribute("color", g3_lit_attribute(24, 4)) |> ignore
  g
}

///|
fn g3_lit_setup(f : () -> @nodes.Node) -> @core.JsValue {
  @core.JsValue::of(@nodes.ContextSetup::{ f, })
}

///|
/// `materialContext( builder )` of upstream_g3.mjs (the same as G2's).
fn g3_lit_material_context(b : @nodes.NodeBuilder) -> Unit {
  b.context.set(
    "setupPositionView",
    Other(
      g3_lit_setup(fn() {
        @nodes.model_view_matrix.mul(@nodes.position_local).xyz()
      }),
    ),
  )
  b.context.set(
    "setupModelViewProjection",
    Other(
      g3_lit_setup(fn() {
        @nodes.camera_projection_matrix.mul(@nodes.position_view)
      }),
    ),
  )
  b.context.set(
    "setupNormal",
    Other(
      g3_lit_setup(fn() {
        @nodes.sub_build(@nodes.normal_view_geometry, "NORMAL", type_="vec3")
      }),
    ),
  )
  b.context.set(
    "setupClearcoatNormal",
    Other(
      g3_lit_setup(fn() {
        @nodes.sub_build(@nodes.normal_view_geometry, "NORMAL", type_="vec3")
      }),
    ),
  )
  b.context.set("clipSpace", Node(@nodes.vec4_of([1, 2, 3, 1])))
}

///|
fn g3_lit_tex(name : String) -> @core.Texture {
  let t = @core.Texture::new()
  t.name = name
  t
}

///|
/// What `StandardNodeLibrary` registers for each light class.
fn g3_lit_register_light_nodes() -> Unit {
  @core.Light::register_node("PointLight", @nodes.PointLightNode::node_class())
  @core.Light::register_node(
    "DirectionalLight",
    @nodes.DirectionalLightNode::node_class(),
  )
  @core.Light::register_node(
    "RectAreaLight",
    @nodes.RectAreaLightNode::node_class(),
  )
  @core.Light::register_node("SpotLight", @nodes.SpotLightNode::node_class())
  @core.Light::register_node(
    "AmbientLight",
    @nodes.AmbientLightNode::node_class(),
  )
  @core.Light::register_node(
    "HemisphereLight",
    @nodes.HemisphereLightNode::node_class(),
  )
  @core.Light::register_node("LightProbe", @nodes.LightProbeNode::node_class())
  @core.Light::register_node(
    "IESSpotLight",
    @nodes.IESSpotLightNode::node_class(),
  )
  @core.Light::register_node(
    "ProjectorLight",
    @nodes.ProjectorLightNode::node_class(),
  )
}

///|
priv struct G3Lit {
  name : String
  material : () -> @core.Material
  lights : () -> Array[@core.Object3D]
  model : () -> @nodes.LightingModel
  lightings : () -> Array[@nodes.Node]
  /// The renderer's `shadowMap.type` and `transmitted`; `None` keeps shadow maps off.
  shadow : (Int32, Bool)?
}

///|
fn g3_lit_point() -> @core.Object3D {
  @core.PointLight::new(
    color=@math.Color::from_hex(0xff0000),
    intensity=2,
    distance=10,
    decay=2,
  )
}

///|
fn g3_lit_directional() -> @core.Object3D {
  @core.DirectionalLight::new(
    color=@math.Color::from_hex(0x00ff00),
    intensity=3,
  )
}

///|
fn g3_lit_spot() -> @core.Object3D {
  @core.SpotLight::new(
    color=@math.Color::from_hex(0x0000ff),
    intensity=4,
    distance=20,
    angle=3.141592653589793 / 4.0,
    penumbra=0.5,
    decay=2,
  )
}

///|
fn g3_lit_hemisphere() -> @core.Object3D {
  @core.HemisphereLight::new(
    sky_color=@math.Color::from_hex(0xffffff),
    ground_color=@math.Color::from_hex(0x444444),
    intensity=1,
  )
}

///|
fn g3_lit_rect_area() -> @core.Object3D {
  @core.RectAreaLight::new(
    color=@math.Color::from_hex(0xffffff),
    intensity=5,
    width=4,
    height=2,
  )
}

///|
fn g3_lit_scenarios() -> Array[G3Lit] {
  let lit : Array[G3Lit] = []
  let add = fn(
    name : String,
    material : () -> @core.Material,
    lights : () -> Array[@core.Object3D],
    model : () -> @nodes.LightingModel,
  ) {
    lit.push({
      name: "g3_" + name,
      material,
      lights,
      model,
      lightings: fn() { [] },
      shadow: None,
    })
  }
  let phong = @core.MeshPhongMaterial::new
  let standard = @core.MeshStandardMaterial::new
  add("lit_phong_point", phong, fn() { [g3_lit_point()] }, fn() {
    @nodes.PhongLightingModel::new()
  })
  add(
    "lit_phong_directional_spot",
    phong,
    fn() { [g3_lit_directional(), g3_lit_spot()] },
    fn() { @nodes.PhongLightingModel::new() },
  )
  add(
    "lit_lambert_directional",
    @core.MeshLambertMaterial::new,
    fn() { [g3_lit_directional()] },
    fn() { @nodes.PhongLightingModel::new(specular=false) },
  )
  add(
    "lit_basic_ambient",
    @core.MeshBasicMaterial::new,
    fn() {
      [
        @core.AmbientLight::new(
          color=@math.Color::from_hex(0x404040),
          intensity=2,
        ),
      ]
    },
    fn() { @nodes.BasicLightingModel::new() },
  )
  add("lit_basic_none", @core.MeshBasicMaterial::new, fn() { [] }, fn() {
    @nodes.BasicLightingModel::new()
  })
  add(
    "lit_toon_point",
    @core.MeshToonMaterial::new,
    fn() { [g3_lit_point()] },
    fn() { @nodes.ToonLightingModel::new() },
  )
  add(
    "lit_toon_gradient",
    fn() {
      let m = @core.MeshToonMaterial::new()
      m.gradient_map = Some(g3_lit_tex("gradient"))
      m
    },
    fn() { [g3_lit_directional()] },
    fn() { @nodes.ToonLightingModel::new() },
  )
  add("lit_physical_point", standard, fn() { [g3_lit_point()] }, fn() {
    @nodes.PhysicalLightingModel::new()
  })
  add(
    "lit_physical_all_lights",
    standard,
    fn() {
      [
        g3_lit_point(),
        g3_lit_directional(),
        g3_lit_spot(),
        g3_lit_hemisphere(),
        @core.AmbientLight::new(
          color=@math.Color::from_hex(0x404040),
          intensity=1,
        ),
        @core.LightProbe::new(),
      ]
    },
    fn() { @nodes.PhysicalLightingModel::new() },
  )
  add(
    "lit_physical_counts",
    standard,
    fn() {
      [
        g3_lit_point(),
        g3_lit_point(),
        g3_lit_point(),
        g3_lit_directional(),
        g3_lit_directional(),
      ]
    },
    fn() { @nodes.PhysicalLightingModel::new() },
  )
  add(
    "lit_physical_features",
    @core.MeshPhysicalMaterial::new,
    fn() { [g3_lit_directional()] },
    fn() {
      @nodes.PhysicalLightingModel::new(
        clearcoat=true,
        sheen=true,
        iridescence=true,
        anisotropy=true,
      )
    },
  )
  add(
    "lit_physical_retro_eon",
    @core.MeshPhysicalMaterial::new,
    fn() { [g3_lit_point()] },
    fn() {
      @nodes.PhysicalLightingModel::new(
        retroreflection=true,
        diffuse_roughness=true,
      )
    },
  )
  add("lit_physical_rect_area", standard, fn() { [g3_lit_rect_area()] }, fn() {
    @nodes.PhysicalLightingModel::new()
  })
  add(
    "lit_physical_rect_area_clearcoat",
    @core.MeshPhysicalMaterial::new,
    fn() { [g3_lit_rect_area()] },
    fn() { @nodes.PhysicalLightingModel::new(clearcoat=true) },
  )
  add("lit_hemisphere", phong, fn() { [g3_lit_hemisphere()] }, fn() {
    @nodes.PhongLightingModel::new()
  })
  add("lit_light_probe", standard, fn() { [@core.LightProbe::new()] }, fn() {
    @nodes.PhysicalLightingModel::new()
  })
  add(
    "lit_spot_map",
    standard,
    fn() {
      let s = g3_lit_spot()
      guard s.as_light().kind is SpotLight(spot) else { abort("spot") }
      spot.map = Some(g3_lit_tex("spot_map"))
      [s]
    },
    fn() { @nodes.PhysicalLightingModel::new() },
  )
  add(
    "lit_ies_spot",
    standard,
    fn() {
      let s = @core.IESSpotLight::new(
        color=@math.Color::from_hex(0xffffff),
        intensity=2,
        distance=10,
        angle=0.5,
      )
      guard s.as_light().kind is SpotLight(spot) else { abort("spot") }
      spot.ies_map = Some(g3_lit_tex("ies"))
      [s]
    },
    fn() { @nodes.PhysicalLightingModel::new() },
  )
  add(
    "lit_projector",
    standard,
    fn() {
      [
        @core.ProjectorLight::new(
          color=@math.Color::from_hex(0xffffff),
          intensity=2,
          distance=10,
          angle=0.5,
        ),
      ]
    },
    fn() { @nodes.PhysicalLightingModel::new() },
  )
  add(
    "lit_shadow_mask",
    standard,
    fn() { [g3_lit_point(), g3_lit_directional()] },
    fn() { @nodes.ShadowMaskModel::new() },
  )
  lit.push({
    name: "g3_lit_material_lightings",
    material: phong,
    lights: fn() { [g3_lit_point()] },
    model: fn() { @nodes.PhongLightingModel::new() },
    lightings: fn() {
      [
        @nodes.AONode::new(ao_node=@nodes.float(0.5).to_var()),
        @nodes.IrradianceNode::new(@nodes.vec3_of([0.1, 0.2, 0.3]).to_var()),
      ]
    },
    shadow: None,
  })
  lit.push({
    name: "g3_lit_basic_light_map",
    material: @core.MeshBasicMaterial::new,
    lights: fn() { [] },
    model: fn() { @nodes.BasicLightingModel::new() },
    lightings: fn() {
      [
        @nodes.BasicLightMapNode::new(
          light_map_node=@nodes.vec3_of([0.5, 0.5, 0.5]).to_var(),
        ),
      ]
    },
    shadow: None,
  })
  g3_shadow_scenarios(lit)
  g3_more_lit_scenarios(lit)
  lit
}

///|
/// The lights `make` returns, casting shadows.
fn g3_casting(
  make : () -> Array[@core.Object3D],
) -> () -> Array[@core.Object3D] {
  fn() {
    let lights = make()
    for l in lights {
      l.cast_shadow = true
    }
    lights
  }
}

///|
/// Shadows: the renderer has shadow maps enabled with the given type (and
/// `transmitted`), the lights cast shadows and the mesh receives them.
fn g3_shadow_scenarios(lit : Array[G3Lit]) -> Unit {
  let add = fn(
    name : String,
    material : () -> @core.Material,
    lights : () -> Array[@core.Object3D],
    model : () -> @nodes.LightingModel,
    shadow : (Int32, Bool)?,
  ) {
    lit.push({
      name: "g3_" + name,
      material,
      lights: g3_casting(lights),
      model,
      lightings: fn() { [] },
      shadow,
    })
  }
  let basic = 0
  let pcf = 1
  let vsm = 3
  let phong = @core.MeshPhongMaterial::new
  let standard = @core.MeshStandardMaterial::new
  let phong_model = fn() { @nodes.PhongLightingModel::new() }
  let physical_model = fn() { @nodes.PhysicalLightingModel::new() }
  add(
    "shadow_directional_basic",
    phong,
    fn() { [g3_lit_directional()] },
    phong_model,
    Some((basic, false)),
  )
  add(
    "shadow_directional_pcf",
    phong,
    fn() { [g3_lit_directional()] },
    phong_model,
    Some((pcf, false)),
  )
  add(
    "shadow_directional_vsm",
    phong,
    fn() { [g3_lit_directional()] },
    phong_model,
    Some((vsm, false)),
  )
  add(
    "shadow_spot_pcf",
    standard,
    fn() { [g3_lit_spot()] },
    physical_model,
    Some((pcf, false)),
  )
  add(
    "shadow_point_basic",
    phong,
    fn() { [g3_lit_point()] },
    phong_model,
    Some((basic, false)),
  )
  add(
    "shadow_point_pcf",
    standard,
    fn() { [g3_lit_point()] },
    physical_model,
    Some((pcf, false)),
  )
  add(
    "shadow_point_vsm",
    phong,
    fn() { [g3_lit_point()] },
    phong_model,
    Some((vsm, false)),
  )
  add(
    "shadow_transmitted",
    phong,
    fn() { [g3_lit_directional()] },
    phong_model,
    Some((pcf, true)),
  )
  add(
    "shadow_point_transmitted",
    phong,
    fn() { [g3_lit_point()] },
    phong_model,
    Some((pcf, true)),
  )
  add(
    "shadow_bias_node",
    phong,
    fn() {
      let l = g3_lit_directional()
      l.as_light().shadow.unwrap().bias_node = Some(
        @core.JsValue::of(@nodes.float(0.001).to_var(name="customBias")),
      )
      [l]
    },
    phong_model,
    Some((pcf, false)),
  )
  add(
    "shadow_filter_node",
    phong,
    fn() {
      let l = g3_lit_spot()
      l.as_light().shadow.unwrap().filter_node = Some(
        @core.JsValue::of(@nodes.basic_shadow_filter),
      )
      [l]
    },
    phong_model,
    Some((pcf, false)),
  )
  add(
    "shadow_custom_node",
    phong,
    fn() {
      let l = g3_lit_directional()
      l.as_light().shadow.unwrap().shadow_node = Some(
        @core.JsValue::of(@nodes.float(0.5).to_var(name="customShadow")),
      )
      [l]
    },
    phong_model,
    Some((pcf, false)),
  )
  add(
    "shadow_two_lights",
    standard,
    fn() { [g3_lit_directional(), g3_lit_point()] },
    physical_model,
    Some((pcf, false)),
  )
  add(
    "shadow_mask_shadowed",
    standard,
    fn() { [g3_lit_directional(), g3_lit_spot()] },
    fn() { @nodes.ShadowMaskModel::new() },
    Some((pcf, false)),
  )
  add(
    "shadow_disabled",
    phong,
    fn() { [g3_lit_directional()] },
    phong_model,
    None,
  )
}

///|
test "g3 lit shader scenarios run (compared with upstream by run.mjs)" {
  g3_lit_register_light_nodes()
  @nodes.RectAreaLightNode::set_ltc({
    ltc_float_1: g3_lit_tex("ltc_float_1"),
    ltc_float_2: g3_lit_tex("ltc_float_2"),
    ltc_half_1: g3_lit_tex("ltc_half_1"),
    ltc_half_2: g3_lit_tex("ltc_half_2"),
  })
  for scenario in g3_lit_scenarios() {
    let material = (scenario.material)()
    let mesh = @core.Mesh::new(
      geometry=g3_lit_geometry,
      material=Single(material),
    )
    // a renderer per scenario: layout functions are cached per backend
    let renderer = @nodes.Renderer::foundation_stub()
    if scenario.shadow is Some((type_, transmitted)) {
      renderer.shadow_map.enabled = true
      renderer.shadow_map.type_ = type_
      renderer.shadow_map.transmitted = transmitted
      renderer._initialized = true // hasCompatibility() needs it (as upstream_g3.mjs)
      mesh.receive_shadow = true
    }
    let b = @nodes.NodeBuilder::new(
      Object3D(mesh),
      renderer,
      Some(g3_parser()),
      class_=G3Builder::{ },
    )
    b.camera = Some(@core.PerspectiveCamera::new())
    g3_lit_material_context(b)
    b.set_shader_stage(Some("fragment"))
    let lights_node = @nodes.LightsNode::set_lights(
      @nodes.LightsNode::new(),
      (scenario.lights)(),
    )
    // as NodeMaterial.build does (VolumetricLightingModel starts the lights in a loop
    // body, built after LightsNode.setup has restored the builder's lights node)
    b.lights_node = Some(lights_node)
    let flow = b.flow_stages_node(
      @nodes.lighting_context(
        lights_node,
        lighting_model=(scenario.model)(),
        material_lightings=(scenario.lightings)(),
      ),
    )
    let uniforms = []
    for stage in ["vertex", "fragment", "compute"] {
      for u in b.uniforms.stage(stage) {
        uniforms.push("\{stage}:\{u.name}:\{u.type_}")
      }
    }
    let record = g3_shader_json(
      flow.code,
      flow.result_snippet(),
      flow.vars.unwrap_or(""),
      uniforms,
      b.get_codes("fragment"),
    )
    if g3_shader_diff_enabled() {
      println("@@SHADER \{scenario.name} \{record}")
    }
  }
}

///|
fn g3_cube(name : String, pmrem : Bool) -> @core.Texture {
  let t = @core.CubeTexture::new()
  t.name = name
  if pmrem {
    t.is_pmrem_texture = true
    t.mipmaps = [
      @core.TextureImage::DataImage(@core.DataImage::new(width=64, height=64)),
    ]
  }
  t
}

///|
/// The members of `VolumeNodeMaterial` (steps 25, no offset or scattering nodes).
fn g3_volume_material() -> @core.Material {
  let m = @nodes.NodeMaterial::new()
  @nodes.register_volume_material(m, {
    steps: fn() { 25.0 },
    offset_node: fn() { None },
    scattering_node: fn() { None },
    scattering_emissive_node: fn() { None },
  })
  m
}

///|
/// Volumetric, transmission and environment lighting.
fn g3_more_lit_scenarios(lit : Array[G3Lit]) -> Unit {
  let add = fn(
    name : String,
    material : () -> @core.Material,
    lights : () -> Array[@core.Object3D],
    model : () -> @nodes.LightingModel,
    lightings : () -> Array[@nodes.Node],
  ) {
    lit.push({
      name: "g3_" + name,
      material,
      lights,
      model,
      lightings,
      shadow: None,
    })
  }
  let none = fn() -> Array[@nodes.Node] { [] }
  let no_lights = fn() -> Array[@core.Object3D] { [] }
  let physical = @core.MeshPhysicalMaterial::new
  let standard = @core.MeshStandardMaterial::new
  add(
    "lit_volumetric",
    g3_volume_material,
    fn() {
      [g3_lit_point(), g3_lit_spot(), g3_lit_directional(), g3_lit_rect_area()]
    },
    fn() { @nodes.VolumetricLightingModel::new() },
    none,
  )
  add(
    "lit_physical_transmission",
    physical,
    fn() { [g3_lit_point()] },
    fn() { @nodes.PhysicalLightingModel::new(transmission=true) },
    none,
  )
  add(
    "lit_physical_dispersion",
    physical,
    fn() { [g3_lit_point()] },
    fn() {
      @nodes.PhysicalLightingModel::new(transmission=true, dispersion=true)
    },
    none,
  )
  add(
    "lit_environment_pmrem",
    standard,
    fn() { [g3_lit_point()] },
    fn() { @nodes.PhysicalLightingModel::new() },
    fn() {
      [
        @nodes.EnvironmentNode::new(
          env_node=@nodes.cube_texture(g3_cube("env", true)),
        ),
      ]
    },
  )
  add(
    "lit_environment_clearcoat",
    physical,
    no_lights,
    fn() { @nodes.PhysicalLightingModel::new(clearcoat=true, sheen=true) },
    fn() {
      [
        @nodes.EnvironmentNode::new(
          env_node=@nodes.cube_texture(g3_cube("env", true)),
        ),
      ]
    },
  )
  add(
    "lit_environment_node",
    standard,
    no_lights,
    fn() { @nodes.PhysicalLightingModel::new() },
    fn() {
      [
        @nodes.EnvironmentNode::new(
          env_node=@nodes.vec3_of([0.1, 0.2, 0.3]).to_var(),
        ),
      ]
    },
  )
  for
    pair in [
      ("multiply", @core.MultiplyOperation),
      ("mix", @core.MixOperation),
      ("add", @core.AddOperation),
    ] {
    let (suffix, combine) = pair
    add(
      "lit_basic_environment_" + suffix,
      fn() {
        let m = @core.MeshBasicMaterial::new()
        m.combine = Some(combine)
        m
      },
      no_lights,
      fn() { @nodes.BasicLightingModel::new() },
      fn() {
        [
          @nodes.BasicEnvironmentNode::new(
            env_node=@nodes.cube_texture(g3_cube("env", false)),
          ),
        ]
      },
    )
  }
}

///|
/// Functions that read accessors, built like the lit scenarios without lights.
fn g3_geo_scenarios() -> Array[(String, () -> @nodes.Node)] {
  let geo : Array[(String, () -> @nodes.Node)] = []
  let add = fn(name : String, make : () -> @nodes.Node) {
    geo.push(("g3_" + name, make))
  }
  add("brdf_ggx", fn() {
    @nodes.brdf_ggx.call_named({
      "lightDirection": g3_v3(0, 0, 1),
      "f0": @nodes.vec3(0.04),
      "f90": 1,
      "roughness": g3_fv(0.5),
    })
  })
  add("brdf_ggx_iridescence_anisotropy", fn() {
    @nodes.brdf_ggx.call_named({
      "lightDirection": g3_v3(0, 0, 1),
      "f0": @nodes.vec3(0.04),
      "f90": 1,
      "roughness": g3_fv(0.5),
      "f": g3_v3(0.1, 0.2, 0.3),
      "USE_IRIDESCENCE": true,
      "USE_ANISOTROPY": true,
    })
  })
  add("brdf_ggx_view_direction", fn() {
    @nodes.brdf_ggx.call_named({
      "lightDirection": g3_v3(0, 0, 1),
      "viewDirection": g3_v3(0, 1, 0),
      "normalView": g3_v3(1, 0, 0),
      "f0": @nodes.vec3(0.04),
      "f90": 1,
      "roughness": g3_fv(0.5),
      "USE_IRIDESCENCE": false,
    })
  })
  add("brdf_sheen", fn() {
    @nodes.brdf_sheen.call_named({ "lightDirection": g3_v3(0, 0, 1) })
  })
  add("brdf_eon", fn() {
    @nodes.brdf_eon.call_named({
      "lightDirection": g3_v3(0, 0, 1),
      "diffuseColor": g3_v3(1, 0.5, 0.25),
      "roughness": g3_fv(0.5),
    })
  })
  add("eon_directional_albedo", fn() {
    @nodes.eon_directional_albedo.call_named({
      "diffuseColor": g3_v3(1, 0.5, 0.25),
      "roughness": g3_fv(0.5),
      "dotNV": g3_fv(0.7),
    })
  })
  add("environment_brdf", fn() {
    @nodes.environment_brdf.call_named({
      "dotNV": g3_fv(0.7),
      "specularColor": g3_v3(0.04, 0.04, 0.04),
      "specularF90": g3_fv(1),
      "roughness": g3_fv(0.5),
    })
  })
  add("dfglut", fn() {
    @nodes.dfglut.call_named({ "roughness": g3_fv(0.5), "dotNV": g3_fv(0.7) })
  })
  add("get_roughness", fn() {
    @nodes.get_roughness.call_named({ "roughness": g3_fv(0.3) })
  })
  add("get_geometry_roughness", fn() { @nodes.get_geometry_roughness.call([]) })
  add("get_parallax_correct_normal", fn() {
    @nodes.get_parallax_correct_normal.call([
      g3_v3(0, 1, 0),
      g3_v3(10, 10, 10),
      g3_v3(0, 0, 0),
    ])
  })
  add("pmrem_roughness_to_mip", fn() {
    @nodes.roughness_to_mip(g3_fv(0.5), g3_fv(8))
  })
  add("pmrem_spherical_gaussian_blur", fn() {
    @nodes.spherical_gaussian_blur.call_named({
      "SAMPLES": @nodes.int(20),
      "sigma": g3_fv(0.2),
      "direction": g3_v3(0, 0, 1),
      "envMap": @nodes.cube_texture(g3_cube("src", false)),
    })
  })
  add("pmrem_ggx_convolution", fn() {
    @nodes.ggx_convolution.call_named({
      "roughness": g3_fv(0.5),
      "lodBias": g3_fv(1),
      "envMap": @nodes.cube_texture(g3_cube("src", false)),
      "direction": g3_v3(0, 0, 1),
      "GGX_SAMPLES": @nodes.uint(64),
    })
  })
  add("pmrem_ggx_integration", fn() {
    @nodes.ggx_integration.call_named({
      "roughness": g3_fv(0.5),
      "sourceLod": g3_fv(2),
      "sourceSize": @nodes.int(8),
      "envMap": @nodes.cube_texture(g3_cube("src", false)),
      "direction": g3_v3(0, 0, 1),
    })
  })
  add("pmrem_texture", fn() {
    @nodes.pmrem_texture(
      g3_cube("env", true),
      uv_node=g3_v3(0, 0, 1),
      level_node=g3_fv(0.5),
    )
  })
  add("mx_noise_float", fn() { @nodes.mx_noise_float() })
  add("mx_noise_vec3", fn() {
    @nodes.mx_noise_vec3(texcoord=g3_v2(0.5, 0.25), amplitude=2, pivot=0.5)
  })
  add("mx_noise_vec4", fn() { @nodes.mx_noise_vec4() })
  add("mx_cell_noise_float", fn() { @nodes.mx_cell_noise_float() })
  add("mx_worley_noise_vec2", fn() { @nodes.mx_worley_noise_vec2() })
  add("mx_worley_noise_vec3_style", fn() {
    @nodes.mx_worley_noise_vec3_style(
      texcoord=g3_v3(0.5, 0.25, 0.125),
      jitter=1,
      style=1,
      metric=0,
    )
  })
  add("mx_fractal_noise_vec2", fn() { @nodes.mx_fractal_noise_vec2() })
  add("mx_unifiednoise2d_defaults", fn() {
    @nodes.mx_unifiednoise2d(@nodes.int(2))
  })
  add("mx_ramp4", fn() {
    @nodes.mx_ramp4(
      g3_v3(1, 0, 0),
      g3_v3(0, 1, 0),
      g3_v3(0, 0, 1),
      g3_v3(1, 1, 1),
    )
  })
  add("mx_splitlr", fn() { @nodes.mx_splitlr(g3_fv(0), g3_fv(1), g3_fv(0.5)) })
  add("mx_aastep", fn() { @nodes.mx_aastep(0.5, g3_fv(0.25)) })
  add("mx_contrast_safepower", fn() {
    @nodes.mx_contrast(g3_fv(0.25), amount=2).add(
      @nodes.mx_safepower(g3_fv(-2), in2=3),
    )
  })
  add("mx_place2d", fn() {
    @nodes.mx_place2d(
      @nodes.uv(),
      pivot=@nodes.vec2_of([0.5, 0.5]),
      scale=@nodes.vec2_of([2, 2]),
      rotate=@nodes.float(45),
      offset=@nodes.vec2_of([0.1, 0.2]),
    )
  })
  add("mx_heighttonormal", fn() { @nodes.mx_heighttonormal(g3_fv(0.5)) })
  add("mx_math", fn() {
    @nodes.mx_modulo(g3_fv(5), in2=g3_fv(2))
    .add(@nodes.mx_atan2(in1=g3_fv(1), in2=g3_fv(2)))
    .add(@nodes.mx_ifgreater(g3_fv(1), g3_fv(2), g3_fv(3), g3_fv(4)))
    .add(@nodes.mx_invert(g3_fv(0.25)))
  })
  add("mx_transform_uv_smoothstep", fn() {
    @nodes.mx_transform_uv(uv_scale=2, uv_offset=0.5)
    .x()
    .add(@nodes.mx_smoothstep(g3_fv(0.25), low=0, high=1))
  })
  add("mx_separate", fn() {
    @nodes.mx_separate(g3_v3(1, 2, 3), channel_or_out=String("outy")).add(
      @nodes.mx_separate(g3_v3(1, 2, 3), channel_or_out=Number(2)),
    )
  })
  add("mx_timer_frame", fn() { @nodes.mx_timer().add(@nodes.mx_frame()) })
  geo
}

///|
test "g3 geo shader scenarios run (compared with upstream by run.mjs)" {
  for scenario in g3_geo_scenarios() {
    let (name, make) = scenario
    let mesh = @core.Mesh::new(
      geometry=g3_lit_geometry,
      material=Single(@core.MeshStandardMaterial::new()),
    )
    let b = @nodes.NodeBuilder::new(
      Object3D(mesh),
      @nodes.Renderer::foundation_stub(),
      Some(g3_parser()),
      class_=G3Builder::{ },
    )
    b.camera = Some(@core.PerspectiveCamera::new())
    g3_lit_material_context(b)
    b.set_shader_stage(Some("fragment"))
    let flow = b.flow_stages_node(make())
    let uniforms = []
    for stage in ["vertex", "fragment", "compute"] {
      for u in b.uniforms.stage(stage) {
        uniforms.push("\{stage}:\{u.name}:\{u.type_}")
      }
    }
    let record = g3_shader_json(
      flow.code,
      flow.result_snippet(),
      flow.vars.unwrap_or(""),
      uniforms,
      b.get_codes("fragment"),
    )
    if g3_shader_diff_enabled() {
      println("@@SHADER \{name} \{record}")
    }
  }
}
