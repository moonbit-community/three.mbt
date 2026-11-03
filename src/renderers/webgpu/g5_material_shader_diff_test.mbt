// MoonBit side of the G5 whole-material WGSL scenarios (`g5_wgsl_*`): each node
// material class built by WGSLNodeBuilder (`build()`: prebuild -> NodeMaterial.build ->
// the three stages -> buildCode) on G8's renderer `a`. The upstream side is
// harness/shader_diff/upstream_g5_wgsl.mjs; run.mjs compares `shader` and `bindings`.

///|
fn g5w_geometry_of(
  n : Int32,
  attributes : Array[(String, Int32)],
) -> @core.BufferGeometry {
  let g = @core.BufferGeometry::new()
  for a in attributes {
    g.set_attribute(a.0, g8_attribute(n, a.1)) |> ignore
  }
  g
}

///|
let g5w_geometry : @core.BufferGeometry = g5w_geometry_of(24, [
  ("position", 3),
  ("normal", 3),
  ("uv", 2),
  ("color", 4),
])

///|
let g5w_line_geometry : @core.BufferGeometry = g5w_geometry_of(4, [
  ("position", 3),
  ("lineDistance", 1),
])

///|
let g5w_line2_geometry : @core.BufferGeometry = g5w_geometry_of(8, [
  ("position", 3),
  ("uv", 2),
  ("instanceStart", 3),
  ("instanceEnd", 3),
  ("instanceDistanceStart", 1),
  ("instanceDistanceEnd", 1),
])

///|
fn g5w_tex(name : String) -> @core.Texture {
  let t = @core.Texture::new()
  t.name = name
  t
}

///|
fn g5w_point() -> @core.Object3D {
  @core.PointLight::new(
    color=@math.Color::from_hex(0xff0000),
    intensity=2,
    distance=10,
    decay=2,
  )
}

///|
fn g5w_directional() -> @core.Object3D {
  @core.DirectionalLight::new(
    color=@math.Color::from_hex(0x00ff00),
    intensity=3,
  )
}

///|
priv struct G5WScenario {
  name : String
  material : () -> @core.Material
  lights : () -> Array[@core.Object3D]
  object : ((@core.Material) -> @core.Object3D)?
  fog : Bool
  logarithmic : Bool
}

///|
fn g5w_set(
  make : () -> @core.Material,
  f : (@core.Material) -> Unit,
) -> () -> @core.Material {
  fn() {
    let m = make()
    f(m)
    m
  }
}

///|
fn g5w_scenarios() -> Array[G5WScenario] {
  let s : Array[G5WScenario] = []
  let none = fn() -> Array[@core.Object3D] { [] }
  let lit = fn() -> Array[@core.Object3D] { [g5w_point()] }
  let add = fn(
    name : String,
    material : () -> @core.Material,
    lights : () -> Array[@core.Object3D],
  ) {
    s.push({
      name: "g5_wgsl_" + name,
      material,
      lights,
      object: None,
      fog: false,
      logarithmic: false,
    })
  }
  let add_object = fn(
    name : String,
    material : () -> @core.Material,
    object : (@core.Material) -> @core.Object3D,
  ) {
    s.push({
      name: "g5_wgsl_" + name,
      material,
      lights: none,
      object: Some(object),
      fog: false,
      logarithmic: false,
    })
  }
  let basic = @nodes.MeshBasicNodeMaterial::new
  add("node_material", @nodes.NodeMaterial::new, none)
  add("basic", basic, none)
  add(
    "basic_map_alpha_test",
    g5w_set(basic, fn(m) {
      m.map = Some(g5w_tex("map"))
      m.set_alpha_test(0.5)
    }),
    none,
  )
  s.push({
    name: "g5_wgsl_basic_transparent_fog",
    material: g5w_set(basic, fn(m) {
      m.transparent = true
      m.premultiplied_alpha = true
    }),
    lights: none,
    object: None,
    fog: true,
    logarithmic: false,
  })
  add(
    "basic_vertex_colors_nodes",
    g5w_set(basic, fn(m) {
      m.vertex_colors = true
      let nm = @nodes.NodeMaterial::of(m).unwrap()
      nm.color_node = Some(@nodes.vec3_of([1, 0.5, 0]))
      nm.position_node = Some(@nodes.position_local.mul(2))
    }),
    none,
  )
  s.push({
    name: "g5_wgsl_basic_log_depth",
    material: basic,
    lights: none,
    object: None,
    fog: false,
    logarithmic: true,
  })
  add("lambert", @nodes.MeshLambertNodeMaterial::new, lit)
  add("phong", @nodes.MeshPhongNodeMaterial::new, lit)
  add("standard", @nodes.MeshStandardNodeMaterial::new, lit)
  add(
    "standard_maps",
    g5w_set(@nodes.MeshStandardNodeMaterial::new, fn(m) {
      m.map = Some(g5w_tex("map"))
      m.roughness_map = Some(g5w_tex("rough"))
      m.normal_map = Some(g5w_tex("normal"))
    }),
    fn() { [g5w_point(), g5w_directional()] },
  )
  add("physical", @nodes.MeshPhysicalNodeMaterial::new, lit)
  add(
    "physical_clearcoat_sheen",
    g5w_set(@nodes.MeshPhysicalNodeMaterial::new, fn(m) {
      m.set_clearcoat(1)
      m.set_sheen(1)
      m.set_iridescence(1)
    }),
    lit,
  )
  add(
    "sss",
    g5w_set(@nodes.MeshSSSNodeMaterial::new, fn(m) {
      @nodes.MeshSSSNodeMaterial::of(m).unwrap().thickness_color_node = Some(
        @nodes.vec3_of([0.5, 0.1, 0.1]),
      )
    }),
    lit,
  )
  add("toon", @nodes.MeshToonNodeMaterial::new, lit)
  add("matcap", @nodes.MeshMatcapNodeMaterial::new, none)
  add("normal", @nodes.MeshNormalNodeMaterial::new, none)
  add("shadow", @nodes.ShadowNodeMaterial::new, fn() { [g5w_directional()] })
  add("volume", @nodes.VolumeNodeMaterial::new, lit)
  let line = fn(m : @core.Material) {
    @core.Line::new(geometry=g5w_line_geometry, material=Single(m))
  }
  let line2 = fn(m : @core.Material) {
    @core.Mesh::new(geometry=g5w_line2_geometry, material=Single(m))
  }
  add_object("line_basic", @nodes.LineBasicNodeMaterial::new, line)
  add_object("line_dashed", @nodes.LineDashedNodeMaterial::new, line)
  add_object("line2", fn() { @nodes.Line2NodeMaterial::new() }, line2)
  add_object(
    "line2_dashed_world_units",
    g5w_set(fn() { @nodes.Line2NodeMaterial::new(dashed=true) }, fn(m) {
      @nodes.Line2NodeMaterial::set_world_units(m, true)
    }),
    line2,
  )
  add_object("points", @nodes.PointsNodeMaterial::new, fn(m) {
    @core.Points::new(geometry=g5w_line_geometry, material=Single(m))
  })
  add_object("points_sprite", @nodes.PointsNodeMaterial::new, fn(m) {
    @core.Mesh::new(geometry=g5w_geometry, material=Single(m))
  })
  add_object("sprite", @nodes.SpriteNodeMaterial::new, fn(m) {
    @core.Sprite::new(material=m)
  })
  add("from_core_standard", @core.MeshStandardMaterial::new, lit)
  s
}

///|
test "g5 whole-material WGSL scenarios run (compared with upstream by run.mjs)" {
  for scenario in g5w_scenarios() {
    let material = (scenario.material)()
    let object = match scenario.object {
      Some(f) => f(material)
      None => @core.Mesh::new(geometry=g5w_geometry, material=Single(material))
    }
    let renderer = g8_renderer([], false)
    renderer.library = @webgpu.StandardNodeLibrary::new()
    renderer.logarithmic_depth_buffer = scenario.logarithmic
    let b = @webgpu.WGSLNodeBuilder::new(Object3D(object), renderer)
    b.scene = Some(@core.Scene::new())
    b.camera = Some(@core.PerspectiveCamera::new())
    b.lights_node = Some(
      @nodes.LightsNode::set_lights(
        @nodes.LightsNode::new(),
        (scenario.lights)(),
      ),
    )
    if scenario.fog {
      b.fog_node = Some(
        @nodes.fog.call([
          @nodes.color(0x8899aa),
          @nodes.range_fog_factor.call([1, 10]),
        ]),
      )
    }
    b.build() |> ignore
    let record = g8_shader_json(
      b.vertex_shader.unwrap_or("undefined") +
      "\n@@@@\n" +
      b.fragment_shader.unwrap_or("undefined"),
      g8_bindings(b),
    )
    if g8_shader_diff_enabled() {
      println("@@SHADER \{scenario.name} \{record}")
    }
  }
}
