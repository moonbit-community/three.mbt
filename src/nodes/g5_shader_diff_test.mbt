// MoonBit side of the G5 scenarios (materials/nodes, loaders/nodes). The upstream side
// is diff/core/webgpu/shader_diff/upstream_g5.mjs;
// `node shader_diff/run.mjs g5_...` compares them byte for byte.
//
// Whole-material scenarios build a mesh (points, line, sprite) with a node material
// through `G5Builder` (G3Builder's parser, ternary and texture methods, builtin names
// for the backend-only methods, a `build_code` recording each stage) and
// `NodeBuilder::build`. The other records compare cache keys, properties, `copy`,
// `fromMaterial`, JSON round trips and NodeMaterialObserver sequences.

///|
extern "js" fn g5_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.SHADER_DIFF === '1'"

///|
extern "js" fn g5_json(
  code : String,
  result : String,
  vars : String,
  uniforms : Array[String],
  codes : Array[String],
  extra : String,
) -> String = "(code, result, vars, uniforms, codes, extra) => JSON.stringify({ code, result, vars, uniforms, codes, extra })"

///|
extern "js" fn g5_json3(
  code : String,
  result : String,
  vars : String,
) -> String = "(code, result, vars) => JSON.stringify({ code, result, vars })"

///|
extern "js" fn g5_json_code(code : String) -> String = "(code) => JSON.stringify({ code })"

///|
extern "js" fn g5_json_code_result(code : String, result : String) -> String = "(code, result) => JSON.stringify({ code, result })"

///|
extern "js" fn g5_js_string(x : Double) -> String = "(x) => String(x)"

///|
/// The normalization of upstream_g5.mjs: uuids replaced by their order of appearance.
extern "js" fn g5_normalize(text : String) -> String =
  #|(s) => {
  #|  const ids = new Map();
  #|  return s.replace( /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi, ( u ) => {
  #|    if ( ! ids.has( u ) ) ids.set( u, '#' + ids.size );
  #|    return ids.get( u );
  #|  } );
  #|}

///|
fn g5_emit(name : String, record : String) -> Unit {
  if g5_enabled() {
    println("@@SHADER \{name} \{record}")
  }
}

///|
struct G5Builder {
  clip_distance : Bool
  recorded : Ref[(String, String, Array[String])?]
}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn class_name(_) {
  "G5Builder"
}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn get_ternary(_, _, c, a, b) {
  Some("select( \{b}, \{a}, \{c} )")
}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn generate_texture(
  _,
  _,
  _,
  p,
  uv,
  depth,
  offset,
  _,
) {
  "tex(\{p}, \{uv}, \{g3_fmt(depth)}, \{g3_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn generate_texture_level(
  _,
  _,
  _,
  p,
  uv,
  level,
  depth,
  offset,
) {
  "texLevel(\{p}, \{uv}, \{level}, \{g3_fmt(depth)}, \{g3_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn generate_texture_bias(
  _,
  _,
  _,
  p,
  uv,
  bias,
  depth,
  offset,
  _,
) {
  "texBias(\{p}, \{uv}, \{bias}, \{g3_fmt(depth)}, \{g3_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn generate_texture_compare(
  _,
  _,
  _,
  p,
  uv,
  compare,
  depth,
  offset,
  _,
) {
  "texCompare(\{p}, \{uv}, \{compare}, \{g3_fmt(depth)}, \{g3_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn generate_texture_load(
  _,
  _,
  _,
  p,
  uv,
  level,
  depth,
  offset,
) {
  "texLoad(\{p}, \{uv}, \{g3_fmt(level)}, \{g3_fmt(depth)}, \{g3_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn generate_texture_size(
  _,
  _,
  _,
  p,
  level,
) {
  "size(\{p}, \{level})"
}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn get_output_struct_name(_, _) {
  "output"
}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn get_front_facing(_, _) {
  "frontFacing"
}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn get_frag_coord(_, _) {
  "fragCoord"
}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn get_frag_depth(_, _) {
  "fragDepth"
}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn get_instance_index(_, _) {
  "instanceIndex"
}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn get_vertex_index(_, _) {
  "vertexIndex"
}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn get_draw_index(_, _) {
  None
}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn get_clip_distance(_, _) {
  "clipDistances"
}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn enable_hardware_clipping(
  _,
  _,
  _,
) {

}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn is_available(self, _, name) {
  if name == "clipDistance" {
    self.clip_distance
  } else {
    false
  }
}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn build_function_code(
  _,
  b,
  shader_node,
) {
  let layout = @nodes.ShaderNodeInternal::get_layout(shader_node).unwrap()
  let flow_data = b.flow_shader_node(shader_node)
  let parameters = layout.inputs.map(fn(input) {
    input.name + " : " + b.get_type(input.type_)
  })
  let type_ = match layout.type_ {
    Some(t) => b.get_type(t)
    None => "null"
  }
  let mut code = "fn \{layout.name}( \{parameters.join(", ")} ) -> \{type_} {\n\{flow_data.vars.unwrap_or("undefined")}\n\{flow_data.code}\n"
  let result = flow_data.result_snippet()
  if result != "" {
    code += "\treturn \{result};\n"
  }
  code += "\n}\n"
  code
}

///|
impl @nodes.NodeBuilderClass for G5Builder with fn build_code(self, b) {
  let mut code = ""
  let vars = []
  let codes = []
  for stage in ["vertex", "fragment"] {
    code += "// \{stage}\n"
    for node in b.flow_nodes.get(stage).unwrap() {
      let flow = b.get_flow_data(node).unwrap()
      code += flow.code + "\n=> \{flow.result_snippet()}\n"
    }
    vars.push("\{stage}: \{b.get_vars(stage)}")
    codes.push(b.get_codes(stage))
  }
  self.recorded.val = Some((code, vars.join("\n"), codes))
}

///|
fn g5_attr(n : Int32, item_size : Int32) -> @core.GeometryAttribute {
  Buffer(
    @core.BufferAttribute::new(
      @core.TypedArray::float32(n * item_size),
      item_size,
    ),
  )
}

///|
fn g5_geometry_of(
  n : Int32,
  attributes : Array[(String, Int32)],
) -> @core.BufferGeometry {
  let g = @core.BufferGeometry::new()
  for a in attributes {
    g.set_attribute(a.0, g5_attr(n, a.1)) |> ignore
  }
  g
}

///|
let g5_geometry : @core.BufferGeometry = g5_geometry_of(24, [
  ("position", 3),
  ("normal", 3),
  ("uv", 2),
  ("uv1", 2),
  ("tangent", 4),
  ("color", 4),
])

///|
fn g5_line2_geometry() -> @core.BufferGeometry {
  g5_geometry_of(8, [
    ("position", 3),
    ("uv", 2),
    ("instanceStart", 3),
    ("instanceEnd", 3),
    ("instanceDistanceStart", 1),
    ("instanceDistanceEnd", 1),
    ("instanceColorStart", 3),
    ("instanceColorEnd", 3),
  ])
}

///|
fn g5_line_geometry() -> @core.BufferGeometry {
  g5_geometry_of(4, [("position", 3), ("color", 3), ("lineDistance", 1)])
}

///|
fn g5_tex(name : String) -> @core.Texture {
  let t = @core.Texture::new()
  t.name = name
  t
}

///|
fn g5_cube(name : String) -> @core.Texture {
  let t = @core.CubeTexture::new()
  t.name = name
  t
}

///|
fn g5_skinned_mesh(material : @core.Material) -> @core.Object3D {
  let g = g5_geometry_of(24, [
    ("position", 3),
    ("normal", 3),
    ("uv", 2),
    ("skinWeight", 4),
  ])
  g.set_attribute(
    "skinIndex",
    @core.BufferAttribute::new(@core.TypedArray::uint16(24 * 4), 4),
  )
  |> ignore
  let bones = [@core.Bone::new(), @core.Bone::new()]
  bones[0].add(bones[1]) |> ignore
  let mesh = @core.SkinnedMesh::new(geometry=g, material=Single(material))
  mesh.add(bones[0]) |> ignore
  mesh.bind(@core.Skeleton::new(bones~))
  mesh
}

///|
fn g5_morph_mesh(material : @core.Material) -> @core.Object3D {
  let g = g5_geometry_of(24, [
    ("position", 3),
    ("normal", 3),
    ("uv", 2),
    ("color", 4),
  ])
  g.morph_attributes.set("position", [g5_attr(24, 3), g5_attr(24, 3)])
  g.morph_attributes.set("normal", [g5_attr(24, 3), g5_attr(24, 3)])
  g.morph_attributes.set("color", [g5_attr(24, 4), g5_attr(24, 4)])
  @core.Mesh::new(geometry=g, material=Single(material))
}

///|
fn g5_instanced_mesh(material : @core.Material) -> @core.Object3D {
  let mesh = @core.InstancedMesh::new(
    geometry=g5_geometry,
    material=Single(material),
    3,
  )
  mesh.set_color_at(0, @math.Color::new(1.0, 0.0, 0.0)) |> ignore
  mesh
}

///|
fn g5_batched_mesh(material : @core.Material) -> @core.Object3D {
  let mesh = @core.BatchedMesh::new(
    2,
    48,
    max_index_count=72,
    material=Single(material),
  )
  let id = mesh.add_instance(mesh.add_geometry(g5_geometry))
  mesh.set_color_at(id, @math.Color::new(1.0, 0.0, 0.0)) |> ignore
  mesh
}

///|
priv struct G5Options {
  lights : (() -> Array[@core.Object3D])?
  fog : Bool
  clipping : Bool
  clip_distance : Bool
  samples : Int32
  object : ((@core.Material) -> @core.Object3D)?
  logarithmic : Bool
  reversed : Bool
  ortho : Bool
  mrt : (() -> @nodes.Node)?
  render_target : Bool
  ao_gi : Bool
}

///|
fn g5_options() -> G5Options {
  {
    lights: None,
    fog: false,
    clipping: false,
    clip_distance: false,
    samples: 0,
    object: None,
    logarithmic: false,
    reversed: false,
    ortho: false,
    mrt: None,
    render_target: false,
    ao_gi: false,
  }
}

///|
priv struct G5Scenario {
  name : String
  material : () -> @core.Material
  options : G5Options
}

///|
fn g5_set(
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
fn g5_nm(m : @core.Material) -> @nodes.NodeMaterial {
  @nodes.NodeMaterial::of(m).unwrap()
}

///|
fn g5_scenarios() -> Array[G5Scenario] {
  let s : Array[G5Scenario] = []
  let add = fn(
    name : String,
    material : () -> @core.Material,
    options : G5Options,
  ) {
    s.push({ name: "g5_" + name, material, options, })
  }
  let o = g5_options()
  let lit = { ..o, lights: Some(fn() { [g3_lit_point()] }), }
  let basic = @nodes.MeshBasicNodeMaterial::new

  // --- NodeMaterial and the variants of its setup
  add("node_material", @nodes.NodeMaterial::new, o)
  add("basic", basic, o)
  add(
    "basic_maps",
    g5_set(basic, fn(m) {
      m.map = Some(g5_tex("map"))
      m.alpha_map = Some(g5_tex("alpha"))
      m.ao_map = Some(g5_tex("ao"))
      m.light_map = Some(g5_tex("light"))
      m.env_map = Some(g5_cube("env"))
      m.specular_map = Some(g5_tex("spec"))
    }),
    o,
  )
  add("basic_vertex_colors", g5_set(basic, fn(m) { m.vertex_colors = true }), o)
  add("basic_alpha_test", g5_set(basic, fn(m) { m.set_alpha_test(0.5) }), o)
  add(
    "basic_alpha_to_coverage",
    g5_set(basic, fn(m) {
      m.set_alpha_test(0.5)
      m.alpha_to_coverage = true
    }),
    o,
  )
  add("basic_alpha_hash", g5_set(basic, fn(m) { m.alpha_hash = true }), o)
  add(
    "basic_transparent_premultiplied",
    g5_set(basic, fn(m) {
      m.transparent = true
      m.premultiplied_alpha = true
    }),
    o,
  )
  add("basic_fog", basic, { ..o, fog: true, })
  add("basic_fog_disabled", g5_set(basic, fn(m) { m.fog = Some(false) }), {
    ..o,
    fog: true,
  })
  add("basic_clipping", basic, { ..o, clipping: true, })
  add("basic_clipping_hardware", basic, {
    ..o,
    clipping: true,
    clip_distance: true,
  })
  add(
    "basic_clipping_alpha_to_coverage",
    g5_set(basic, fn(m) { m.alpha_to_coverage = true }),
    { ..o, clipping: true, samples: 4, },
  )
  add("basic_skinning", basic, { ..o, object: Some(g5_skinned_mesh), })
  add("basic_morph", g5_set(basic, fn(m) { m.vertex_colors = true }), {
    ..o,
    object: Some(g5_morph_mesh),
  })
  add("basic_instanced", basic, { ..o, object: Some(g5_instanced_mesh), })
  add("basic_batched", basic, { ..o, object: Some(g5_batched_mesh), })
  add("basic_log_depth", basic, { ..o, logarithmic: true, })
  add("basic_log_depth_ortho", basic, { ..o, logarithmic: true, ortho: true, })
  add("basic_reversed_depth", basic, { ..o, reversed: true, })
  add(
    "basic_no_depth",
    g5_set(basic, fn(m) {
      m.depth_test = false
      m.depth_write = false
      g5_nm(m).depth_node = Some(@nodes.float(0.5))
    }),
    { ..o, logarithmic: true, },
  )
  add("basic_mrt", basic, {
    ..o,
    mrt: Some(fn() {
      @nodes.mrt(
        Map([("output", @nodes.output), ("normal", @nodes.normal_view)]),
      )
    }),
  })
  add(
    "basic_mrt_material",
    g5_set(basic, fn(m) {
      g5_nm(m).mrt_node = Some(
        @nodes.mrt(Map([("emissive", @nodes.vec4_of([1, 0, 0, 1]))])),
      )
    }),
    { ..o, mrt: Some(fn() { @nodes.mrt(Map([("output", @nodes.output)])) }), },
  )
  add("basic_mrt_depth", basic, {
    ..o,
    mrt: Some(fn() {
      @nodes.mrt(
        Map([("output", @nodes.output), ("depth", @nodes.float(0.25))]),
      )
    }),
  })
  add(
    "basic_material_mrt_only",
    g5_set(basic, fn(m) {
      g5_nm(m).mrt_node = Some(@nodes.mrt(Map([("output", @nodes.vec4(1))])))
    }),
    { ..o, render_target: true, },
  )
  add(
    "basic_output_node_mrt",
    g5_set(basic, fn(m) {
      g5_nm(m).output_node = Some(@nodes.vec4_of([0, 1, 0, 1]))
    }),
    { ..o, mrt: Some(fn() { @nodes.mrt(Map([("output", @nodes.output)])) }), },
  )
  add(
    "basic_nodes",
    g5_set(basic, fn(m) {
      let nm = g5_nm(m)
      nm.color_node = Some(@nodes.vec3_of([1, 0.5, 0.25]))
      nm.opacity_node = Some(@nodes.float(0.5))
      nm.position_node = Some(@nodes.position_local.mul(2))
      nm.alpha_test_node = Some(@nodes.float(0.1))
      nm.mask_node = Some(@nodes.uv().x().greater_than(0.5))
      nm.depth_node = Some(@nodes.float(0.75))
    }),
    o,
  )
  add(
    "basic_output_node",
    g5_set(basic, fn(m) {
      g5_nm(m).output_node = Some(@nodes.vec4_of([0, 1, 0, 1]))
    }),
    o,
  )
  add(
    "basic_backdrop",
    g5_set(@nodes.NodeMaterial::new, fn(m) {
      g5_nm(m).backdrop_node = Some(@nodes.vec3(0.2))
      g5_nm(m).backdrop_alpha_node = Some(@nodes.float(0.5))
    }),
    o,
  )
  add(
    "basic_fragment_node",
    g5_set(basic, fn(m) {
      g5_nm(m).fragment_node = Some(@nodes.vec3_of([1, 0, 0]))
    }),
    o,
  )
  add(
    "basic_fragment_output_struct",
    g5_set(@nodes.NodeMaterial::new, fn(m) {
      g5_nm(m).fragment_node = Some(
        @nodes.output_struct([@nodes.vec4(1), @nodes.vec4(0.5)]),
      )
    }),
    o,
  )
  add(
    "basic_vertex_node",
    g5_set(basic, fn(m) {
      g5_nm(m).vertex_node = Some(@nodes.vec4_of([0, 0, 0, 1]))
    }),
    o,
  )
  add(
    "basic_lights_node",
    g5_set(@nodes.NodeMaterial::new, fn(m) {
      g5_nm(m).lights_node = Some(
        @nodes.LightsNode::set_lights(@nodes.LightsNode::new(), [g3_lit_point()]),
      )
    }),
    o,
  )
  add("basic_context_getters", basic, { ..o, ao_gi: true, })
  add(
    "basic_displacement",
    g5_set(basic, fn(m) { m.displacement_map = Some(g5_tex("disp")) }),
    o,
  )

  // --- lit materials
  let lambert = @nodes.MeshLambertNodeMaterial::new
  let phong = @nodes.MeshPhongNodeMaterial::new
  let standard = @nodes.MeshStandardNodeMaterial::new
  let physical = @nodes.MeshPhysicalNodeMaterial::new
  add("lambert", lambert, lit)
  add(
    "lambert_maps",
    g5_set(lambert, fn(m) {
      m.emissive_map = Some(g5_tex("emissive"))
      m.normal_map = Some(g5_tex("normal"))
      m.env_map = Some(g5_cube("env"))
    }),
    lit,
  )
  add(
    "lambert_emissive_node",
    g5_set(lambert, fn(m) {
      @nodes.MeshLambertNodeMaterial::of(m).unwrap().emissive_node = Some(
        @nodes.vec3(0.1),
      )
    }),
    lit,
  )
  add(
    "lambert_emissive_node_no_color",
    g5_set(lambert, fn(m) {
      m.emissive = None
      @nodes.MeshLambertNodeMaterial::of(m).unwrap().emissive_node = Some(
        @nodes.vec3(0.2),
      )
    }),
    lit,
  )
  add("phong", phong, lit)
  add(
    "phong_nodes",
    g5_set(phong, fn(m) {
      let p = @nodes.MeshPhongNodeMaterial::of(m).unwrap()
      p.shininess_node = Some(@nodes.float(50))
      p.specular_node = Some(@nodes.vec3(0.5))
      p.emissive_node = Some(@nodes.vec3(0.1))
    }),
    lit,
  )
  add(
    "phong_env_bump",
    g5_set(phong, fn(m) {
      m.env_map = Some(g5_tex("env2d"))
      m.bump_map = Some(g5_tex("bump"))
      m.specular_map = Some(g5_tex("spec"))
    }),
    lit,
  )
  add("standard", standard, lit)
  add("standard_no_lights", standard, o)
  add(
    "standard_maps",
    g5_set(standard, fn(m) {
      m.map = Some(g5_tex("map"))
      m.roughness_map = Some(g5_tex("rough"))
      m.metalness_map = Some(g5_tex("metal"))
      m.normal_map = Some(g5_tex("normal"))
      m.emissive_map = Some(g5_tex("emissive"))
      m.ao_map = Some(g5_tex("ao"))
      m.light_map = Some(g5_tex("light"))
    }),
    lit,
  )
  add(
    "standard_nodes",
    g5_set(standard, fn(m) {
      let p = @nodes.MeshStandardNodeMaterial::of(m).unwrap()
      p.metalness_node = Some(@nodes.float(0.5))
      p.roughness_node = Some(@nodes.float(0.25))
      g5_nm(m).normal_node = Some(@nodes.vec3_of([0, 0, 1]))
      p.emissive_node = Some(@nodes.color(0x112233))
    }),
    lit,
  )
  add(
    "standard_env",
    g5_set(standard, fn(m) {
      g5_nm(m).env_node = Some(@nodes.vec3_of([0.1, 0.2, 0.3]))
    }),
    lit,
  )
  add(
    "standard_flat",
    g5_set(standard, fn(m) { m.flat_shading = Some(true) }),
    lit,
  )
  add("standard_fog_clipping", standard, { ..lit, fog: true, clipping: true, })
  add("physical", physical, lit)
  add(
    "physical_clearcoat",
    g5_set(physical, fn(m) {
      m.set_clearcoat(1)
      m.clearcoat_normal_map = Some(g5_tex("ccn"))
    }),
    lit,
  )
  add(
    "physical_clearcoat_node",
    g5_set(physical, fn(m) {
      let p = @nodes.MeshPhysicalNodeMaterial::of(m).unwrap()
      p.clearcoat_node = Some(@nodes.float(0.5))
      p.clearcoat_roughness_node = Some(@nodes.float(0.2))
      p.clearcoat_normal_node = Some(@nodes.vec3_of([0, 0, 1]))
    }),
    lit,
  )
  add("physical_sheen", g5_set(physical, fn(m) { m.set_sheen(1) }), lit)
  add(
    "physical_iridescence",
    g5_set(physical, fn(m) { m.set_iridescence(1) }),
    lit,
  )
  add(
    "physical_anisotropy",
    g5_set(physical, fn(m) { m.set_anisotropy(0.5) }),
    lit,
  )
  add(
    "physical_anisotropy_node",
    g5_set(physical, fn(m) {
      @nodes.MeshPhysicalNodeMaterial::of(m).unwrap().anisotropy_node = Some(
        @nodes.vec2_of([0.5, 0.25]),
      )
    }),
    lit,
  )
  add(
    "physical_retroreflection",
    g5_set(physical, fn(m) { m.set_retroreflectivity(0.5) }),
    lit,
  )
  add(
    "physical_diffuse_roughness",
    g5_set(physical, fn(m) { m.set_diffuse_roughness(0.5) }),
    lit,
  )
  add(
    "physical_specular_nodes",
    g5_set(physical, fn(m) {
      let p = @nodes.MeshPhysicalNodeMaterial::of(m).unwrap()
      p.ior_node = Some(@nodes.float(1.8))
      p.specular_color_node = Some(@nodes.vec3_of([1, 0.5, 0.5]))
      p.specular_intensity_node = Some(@nodes.float(0.5))
    }),
    lit,
  )
  add(
    "sss",
    g5_set(@nodes.MeshSSSNodeMaterial::new, fn(m) {
      @nodes.MeshSSSNodeMaterial::of(m).unwrap().thickness_color_node = Some(
        @nodes.vec3_of([0.5, 0.1, 0.1]),
      )
    }),
    lit,
  )
  add("sss_default", @nodes.MeshSSSNodeMaterial::new, lit)
  add("toon", @nodes.MeshToonNodeMaterial::new, lit)
  add(
    "toon_gradient",
    g5_set(@nodes.MeshToonNodeMaterial::new, fn(m) {
      m.gradient_map = Some(g5_tex("gradient"))
    }),
    { ..o, lights: Some(fn() { [g3_lit_directional()] }), },
  )
  add("matcap", @nodes.MeshMatcapNodeMaterial::new, o)
  add(
    "matcap_texture",
    g5_set(@nodes.MeshMatcapNodeMaterial::new, fn(m) {
      m.matcap = Some(g5_tex("matcap"))
    }),
    o,
  )
  add("normal", @nodes.MeshNormalNodeMaterial::new, o)
  add(
    "normal_opacity",
    g5_set(@nodes.MeshNormalNodeMaterial::new, fn(m) {
      g5_nm(m).opacity_node = Some(@nodes.float(0.5))
      m.transparent = true
    }),
    o,
  )
  add("shadow", @nodes.ShadowNodeMaterial::new, {
    ..o,
    lights: Some(fn() { [g3_lit_directional()] }),
  })
  add("volume", @nodes.VolumeNodeMaterial::new, lit)
  add(
    "volume_scattering",
    g5_set(@nodes.VolumeNodeMaterial::new, fn(m) {
      let v = @nodes.VolumeNodeMaterial::of(m).unwrap()
      v.steps = 12
      v.scattering_node = Some(@nodes.fn_(fn(_, _) { Some(@nodes.vec3(0.5)) }))
      v.offset_node = Some(@nodes.float(0.1))
    }),
    lit,
  )

  // --- lines, points, sprites
  let line_object = fn(m : @core.Material) {
    @core.Line::new(geometry=g5_line_geometry(), material=Single(m))
  }
  let line2_object = fn(m : @core.Material) {
    @core.Mesh::new(geometry=g5_line2_geometry(), material=Single(m))
  }
  let points_object = fn(m : @core.Material) {
    @core.Points::new(geometry=g5_line_geometry(), material=Single(m))
  }
  let sprite_object = fn(m : @core.Material) { @core.Sprite::new(material=m) }
  let mesh_object = fn(m : @core.Material) {
    @core.Mesh::new(geometry=g5_geometry, material=Single(m))
  }
  let line2 = fn() { @nodes.Line2NodeMaterial::new() }
  let line2_dashed = fn() { @nodes.Line2NodeMaterial::new(dashed=true) }
  add("line_basic", @nodes.LineBasicNodeMaterial::new, {
    ..o,
    object: Some(line_object),
  })
  add(
    "line_basic_vertex_colors",
    g5_set(@nodes.LineBasicNodeMaterial::new, fn(m) { m.vertex_colors = true }),
    { ..o, object: Some(line_object), },
  )
  add("line_dashed", @nodes.LineDashedNodeMaterial::new, {
    ..o,
    object: Some(line_object),
  })
  add(
    "line_dashed_nodes",
    g5_set(@nodes.LineDashedNodeMaterial::new, fn(m) {
      let p = @nodes.LineDashedNodeMaterial::of(m).unwrap()
      p.dash_offset = 1
      p.offset_node = Some(@nodes.float(2))
      p.dash_scale_node = Some(@nodes.float(3))
      p.dash_size_node = Some(@nodes.float(4))
      p.gap_size_node = Some(@nodes.float(5))
    }),
    { ..o, object: Some(line_object), },
  )
  let l2 = { ..o, object: Some(line2_object), }
  add("line2", line2, l2)
  add(
    "line2_world_units",
    g5_set(line2, fn(m) { @nodes.Line2NodeMaterial::set_world_units(m, true) }),
    l2,
  )
  add("line2_dashed", line2_dashed, l2)
  add(
    "line2_dashed_world_units",
    g5_set(line2_dashed, fn(m) {
      @nodes.Line2NodeMaterial::set_world_units(m, true)
      @nodes.Line2NodeMaterial::of(m).unwrap().dash_offset = 0.5
    }),
    l2,
  )
  add(
    "line2_no_alpha_to_coverage",
    g5_set(line2, fn(m) {
      @nodes.Line2NodeMaterial::set_alpha_to_coverage(m, false)
    }),
    l2,
  )
  add("line2_alpha_to_coverage_samples", line2, { ..l2, samples: 4, })
  add(
    "line2_world_units_samples",
    g5_set(line2, fn(m) { @nodes.Line2NodeMaterial::set_world_units(m, true) }),
    { ..l2, samples: 4, },
  )
  add(
    "line2_vertex_colors_transparent",
    g5_set(fn() { @nodes.Line2NodeMaterial::new(vertex_colors=true) }, fn(m) {
      m.transparent = true
    }),
    l2,
  )
  add(
    "line2_dashed_nodes",
    g5_set(line2_dashed, fn(m) {
      let p = @nodes.Line2NodeMaterial::of(m).unwrap()
      p.offset_node = Some(@nodes.float(2))
      p.dash_scale_node = Some(@nodes.float(3))
      p.dash_size_node = Some(@nodes.float(4))
      p.gap_size_node = Some(@nodes.float(5))
    }),
    l2,
  )
  let points = @nodes.PointsNodeMaterial::new
  add("points", points, { ..o, object: Some(points_object), })
  add("points_sprite", points, { ..o, object: Some(mesh_object), })
  add(
    "points_sprite_nodes",
    g5_set(points, fn(m) {
      let p = @nodes.PointsNodeMaterial::of(m).unwrap()
      p.size_node = Some(@nodes.float(4))
      p.sprite.rotation_node = Some(@nodes.float(0.5))
      p.sprite.scale_node = Some(@nodes.vec2_of([2, 3]))
      g5_nm(m).position_node = Some(@nodes.vec3_of([1, 2, 3]))
    }),
    { ..o, object: Some(mesh_object), },
  )
  add(
    "points_sprite_no_attenuation_ortho",
    g5_set(points, fn(m) {
      @nodes.SpriteNodeMaterial::set_size_attenuation(m, false)
    }),
    { ..o, object: Some(mesh_object), ortho: true, },
  )
  let sprite = @nodes.SpriteNodeMaterial::new
  add("sprite", sprite, { ..o, object: Some(sprite_object), })
  add(
    "sprite_nodes",
    g5_set(sprite, fn(m) {
      let p = @nodes.SpriteNodeMaterial::of(m).unwrap()
      p.rotation_node = Some(@nodes.float(0.5))
      p.scale_node = Some(@nodes.vec2_of([2, 3]))
      g5_nm(m).position_node = Some(@nodes.vec3_of([1, 2, 3]))
      @nodes.SpriteNodeMaterial::set_size_attenuation(m, false)
    }),
    { ..o, object: Some(sprite_object), },
  )
  add(
    "sprite_map",
    g5_set(sprite, fn(m) {
      m.map = Some(g5_tex("sprite"))
      m.rotation = Some(1)
    }),
    { ..o, object: Some(sprite_object), ortho: true, },
  )

  // --- NodeMaterialInstance
  add(
    "instance",
    fn() {
      let base = standard()
      g5_nm(base).color_node = Some(@nodes.vec3_of([1, 0, 0]))
      let instance = @nodes.NodeMaterialInstance::new(base)
      instance.color = Some(@math.Color::new(0, 1, 0))
      instance.map = Some(g5_tex("instance_map"))
      instance
    },
    lit,
  )
  s
}

///|
test "g5 material scenarios run (compared with upstream by run.mjs)" {
  g3_lit_register_light_nodes()
  for scenario in g5_scenarios() {
    let material = (scenario.material)()
    let options = scenario.options
    let object = match options.object {
      Some(f) => f(material)
      None => @core.Mesh::new(geometry=g5_geometry, material=Single(material))
    }
    object.position.set(1, 2, 3) |> ignore
    object.update_matrix_world(force=true)
    let renderer = @nodes.Renderer::foundation_stub()
    renderer.backend.class_ = G2Backend::{ limit: 65536, }
    renderer.logarithmic_depth_buffer = options.logarithmic
    renderer.reversed_depth_buffer = options.reversed
    if options.samples > 0 {
      renderer._samples = options.samples
    }
    if options.mrt is Some(_) || options.render_target {
      renderer._render_target = Some(@core.RenderTarget::new(width=4, height=4))
    }
    if options.mrt is Some(mrt) {
      renderer._mrt = Some(mrt())
    }
    let recorded = Ref(None)
    let b = @nodes.NodeBuilder::new(
      Object3D(object),
      renderer,
      Some(g3_parser()),
      class_=G5Builder::{ clip_distance: options.clip_distance, recorded, },
    )
    b.scene = Some(@core.Scene::new())
    b.camera = Some(
      if options.ortho {
        @core.OrthographicCamera::new()
      } else {
        @core.PerspectiveCamera::new()
      },
    )
    let lights = match options.lights {
      Some(f) => f()
      None => []
    }
    b.lights_node = Some(
      @nodes.LightsNode::set_lights(@nodes.LightsNode::new(), lights),
    )
    if options.fog {
      b.fog_node = Some(
        @nodes.fog.call([
          @nodes.color(0x8899aa),
          @nodes.range_fog_factor.call([1, 10]),
        ]),
      )
    }
    if options.clipping {
      let c = @nodes.ClippingContext::new()
      c.union_planes = [
        @math.Vector4::new(0.0, 1.0, 0.0, 0.0),
        @math.Vector4::new(1.0, 0.0, 0.0, 2.0),
      ]
      c.intersection_planes = [@math.Vector4::new(0.0, 0.0, 1.0, 1.0)]
      b.clipping_context = Some(c)
    }
    if options.ao_gi {
      b.context.set(
        "getAO",
        Other(
          @core.JsValue::of(@nodes.ContextGetLayer::{
            f: fn(ao, _) {
              match ao {
                None => Some(@nodes.float(0.5))
                Some(ao) => Some(ao.mul(0.5))
              }
            },
          }),
        ),
      )
      b.context.set(
        "getGI",
        Other(
          @core.JsValue::of(@nodes.ContextGetLayer::{
            f: fn(_, _) { Some(@nodes.vec3_of([0.1, 0.2, 0.3])) },
          }),
        ),
      )
    }
    b.build() |> ignore
    let uniforms = []
    for stage in ["vertex", "fragment", "compute"] {
      for u in b.uniforms.stage(stage) {
        uniforms.push("\{stage}:\{u.name}:\{u.type_}")
      }
    }
    let varyings = b.varyings.map(fn(v) {
      "\{v.name}:\{v.type_}:\{v.needs_interpolation}"
    })
    let attributes = b.attributes.map(fn(a) { "\{a.name}:\{a.type_}" })
    let observer = b.observer.unwrap()
    let extra = [
      "varyings=" + varyings.join(","),
      "attributes=" + attributes.join(","),
      "hasNode=\{observer.has_node}",
      "hasAnimation=\{observer.has_animation}",
      "hardwareClipping=\{b.hardware_clipping}",
      "updates=\{b.update_nodes.length()}/\{b.update_before_nodes.length()}/\{b.update_after_nodes.length()}",
    ].join("\n")
    let (code, vars, codes) = recorded.val.unwrap()
    g5_emit(scenario.name, g5_json(code, "", vars, uniforms, codes, extra))
  }
}

// ---------------------------------------------------------------------------
// Cache keys, properties, copy, fromMaterial, JSON round trips

///|
let g5_classes : Array[String] = [
  "NodeMaterial", "LineBasicNodeMaterial", "LineDashedNodeMaterial", "Line2NodeMaterial",
  "MeshNormalNodeMaterial", "MeshBasicNodeMaterial", "MeshLambertNodeMaterial", "MeshPhongNodeMaterial",
  "MeshStandardNodeMaterial", "MeshPhysicalNodeMaterial", "MeshSSSNodeMaterial",
  "MeshToonNodeMaterial", "MeshMatcapNodeMaterial", "PointsNodeMaterial", "SpriteNodeMaterial",
  "ShadowNodeMaterial", "VolumeNodeMaterial",
]

///|
fn g5_new(class_ : String) -> @core.Material {
  @nodes.node_materials().get(class_).unwrap()()
}

///|
fn g5_bool(b : Bool) -> String {
  if b {
    "true"
  } else {
    "false"
  }
}

///|
/// `show( m[ p ] )` of upstream_g5.mjs.
fn g5_show(m : @core.Material, p : String) -> String {
  match p {
    "type" => m.type_
    "version" => m.version.to_string()
    "color" | "emissive" =>
      match (if p == "color" { m.color } else { m.emissive }) {
        Some(c) => "#" + c.get_hex_string()
        None => "undefined"
      }
    "userData" => "userData"
    _ if p.has_prefix("is") =>
      if m.has_extension_flag(p) {
        "true"
      } else {
        "undefined"
      }
    _ =>
      match @nodes.material_property(m, p) {
        Undefined => "undefined"
        Null => "null"
        Number(x) => g5_js_string(x)
        Bool(b) => g5_bool(b)
        String(s) => s
        Object => if p.has_suffix("Node") { "node" } else { "object" }
        Texture(_) => "object"
      }
  }
}

///|
let g5_props : Array[String] = [
  "type", "lights", "fog", "transparent", "side", "depthTest", "depthWrite", "blending",
  "vertexColors", "alphaToCoverage", "sizeAttenuation", "worldUnits", "dashed", "dashOffset",
  "steps", "useClearcoat", "useSheen", "useIridescence", "useAnisotropy", "useTransmission",
  "useDispersion", "useRetroreflection", "useDiffuseRoughness", "useSSS", "isMeshStandardMaterial",
  "isMeshPhysicalMaterial", "isLineBasicMaterial", "isSpriteNodeMaterial", "isNodeMaterial",
  "version",
]

///|
fn g5_show_props(m : @core.Material, props : Array[String]) -> String {
  props.map(fn(p) { p + "=" + g5_show(m, p) }).join(",")
}

///|
extern "js" fn g5_user_data_json(v : @core.JsValue) -> String = "(v) => JSON.stringify(v)"

///|
extern "js" fn g5_user_data() -> @core.JsValue = "() => ({ a: 1, b: [ 2 ] })"

///|
test "g5 key, property and copy records" {
  for c in g5_classes {
    let a = g5_new(c)
    let b = g5_new(c)
    let shared = @nodes.float(1)
    g5_nm(a).color_node = Some(shared)
    g5_nm(b).color_node = Some(shared)
    let d = g5_new(c)
    g5_nm(d).color_node = Some(@nodes.float(1))
    let e = g5_new(c)
    g5_nm(d).opacity_node = Some(@nodes.float(2))
    let key = fn(m : @core.Material) { m.custom_program_cache_key() }
    g5_emit(
      "g5_key_program_" + c,
      g5_json_code_result(
        // node cache keys include node ids: classes with default node slots
        // are not compared
        {
          let fresh = g5_new(c)
          if @nodes.NodeMaterial::get_node_children(fresh).length() > 0 {
            c + ":id-dependent"
          } else {
            key(fresh)
          }
        },
        g5_bool(key(a) == key(b)) +
        "," +
        g5_bool(key(a) == key(d)) +
        "," +
        g5_bool(key(e) == key(d)),
      ),
    )
  }
  for c in g5_classes {
    g5_emit("g5_props_" + c, g5_json_code(g5_show_props(g5_new(c), g5_props)))
  }
  let physical = @nodes.MeshPhysicalNodeMaterial::new()
  physical.set_clearcoat(1)
  let pp = @nodes.MeshPhysicalNodeMaterial::of(physical).unwrap()
  pp.sheen_node = Some(@nodes.vec3(1))
  physical.set_transmission(0.5)
  pp.anisotropy_node = Some(@nodes.vec2(1))
  g5_emit(
    "g5_props_physical_features",
    g5_json_code(g5_show_props(physical, g5_props)),
  )
  let copy_props = [
    "type", "name", "color", "opacity", "transparent", "roughness", "metalness",
    "clearcoat", "sheen", "transmission", "ior", "emissive", "emissiveIntensity",
    "alphaTest", "side", "dashOffset", "steps", "worldUnits", "dashed", "sizeAttenuation",
    "size", "rotation", "linewidth", "version", "colorNode", "emissiveNode", "clearcoatNode",
    "sizeNode", "offsetNode", "scatteringNode", "thicknessColorNode", "userData",
  ]
  for c in g5_classes {
    let source = g5_new(c)
    source.name = "src"
    if source.color is Some(color) {
      color.set_hex(0x336699) |> ignore
    }
    source.opacity = 0.5
    source.transparent = true
    source.set_alpha_test(0.25)
    source.user_data = g5_user_data()
    g5_nm(source).color_node = Some(@nodes.float(3))
    if source.roughness is Some(_) {
      source.roughness = Some(0.3)
    }
    if c == "MeshPhysicalNodeMaterial" || c == "MeshSSSNodeMaterial" {
      source.set_clearcoat(0.5)
      source.set_sheen(1)
      source.set_transmission(0.2)
      @nodes.MeshPhysicalNodeMaterial::of(source).unwrap().clearcoat_node = Some(
        @nodes.float(1),
      )
    }
    if @nodes.LineDashedNodeMaterial::of(source) is Some(p) {
      p.dash_offset = 2
    }
    if @nodes.Line2NodeMaterial::of(source) is Some(p) {
      p.dash_offset = 2
      @nodes.Line2NodeMaterial::set_world_units(source, true)
      @nodes.Line2NodeMaterial::set_dashed(source, true)
    }
    if @nodes.VolumeNodeMaterial::of(source) is Some(v) {
      v.steps = 7
      v.scattering_node = Some(@nodes.float(1))
    }
    if @nodes.PointsNodeMaterial::of(source) is Some(p) {
      p.size_node = Some(@nodes.float(2))
      source.size = Some(3)
    }
    if c == "SpriteNodeMaterial" || c == "PointsNodeMaterial" {
      @nodes.SpriteNodeMaterial::set_size_attenuation(source, false)
    }
    if @nodes.MeshSSSNodeMaterial::of(source) is Some(p) {
      p.thickness_color_node = Some(@nodes.vec3(1))
    }
    let clone = source.clone()
    let shown = copy_props
      .map(fn(p) {
        p +
        "=" +
        (match p {
          "userData" => g5_user_data_json(clone.user_data)
          "name" => clone.name
          "opacity" => g5_js_string(clone.opacity)
          _ => g5_show(clone, p)
        })
      })
      .join(",")
    let same_node = match (g5_nm(clone).color_node, g5_nm(source).color_node) {
      (Some(a), Some(b)) => physical_equal(a, b)
      _ => false
    }
    let same_color = match (clone.color, source.color) {
      (Some(a), Some(b)) => physical_equal(a, b)
      (None, None) => true
      _ => false
    }
    g5_emit(
      "g5_copy_" + c,
      g5_json_code_result(shown, g5_bool(same_node) + "," + g5_bool(same_color)),
    )
  }
}

///|
test "g5 fromMaterial records" {
  let library = @nodes.NodeLibrary::new()
  for entry in @nodes.standard_node_material_library() {
    library.add_material(entry.0, entry.1)
  }
  let core_materials : Array[(String, () -> @core.Material)] = [
    ("MeshPhongMaterial", @core.MeshPhongMaterial::new),
    ("MeshStandardMaterial", @core.MeshStandardMaterial::new),
    ("MeshPhysicalMaterial", @core.MeshPhysicalMaterial::new),
    ("MeshToonMaterial", @core.MeshToonMaterial::new),
    ("MeshBasicMaterial", @core.MeshBasicMaterial::new),
    ("MeshLambertMaterial", @core.MeshLambertMaterial::new),
    ("MeshNormalMaterial", @core.MeshNormalMaterial::new),
    ("MeshMatcapMaterial", @core.MeshMatcapMaterial::new),
    ("LineBasicMaterial", @core.LineBasicMaterial::new),
    ("LineDashedMaterial", @core.LineDashedMaterial::new),
    ("PointsMaterial", @core.PointsMaterial::new),
    ("SpriteMaterial", @core.SpriteMaterial::new),
    ("ShadowMaterial", @core.ShadowMaterial::new),
    ("MeshDepthMaterial", @core.MeshDepthMaterial::new),
  ]
  let props = [
    "type", "color", "opacity", "roughness", "shininess", "size", "sizeAttenuation",
    "rotation", "dashSize", "linewidth", "clearcoat", "transparent", "lights", "fog",
    "isNodeMaterial",
  ]
  for entry in core_materials {
    let m = (entry.1)()
    m.name = "core"
    m.opacity = 0.75
    if m.color is Some(c) {
      c.set_hex(0x445566) |> ignore
    }
    let code = match library.from_material(m) {
      None => "null"
      Some(nm) =>
        props
        .map(fn(p) {
          p +
          "=" +
          (match p {
            "opacity" => g5_js_string(nm.opacity)
            _ => g5_show(nm, p)
          })
        })
        .join(",") +
        ",name=" +
        nm.name
    }
    g5_emit("g5_from_" + entry.0, g5_json_code(code))
  }
}

// ---------------------------------------------------------------------------
// NodeMaterialObserver.needsRefresh sequences

///|
priv struct G5ObserverEnv {
  renderer : @nodes.Renderer
  material : @core.Material
  object : @core.Object3D
  scene : @core.Object3D
  lights_node : @nodes.Node
  context : @nodes.RenderContext
  frame : @nodes.NodeFrame
  extra : Array[@core.Object3D]
}

///|
fn g5_scene_of(o : @core.Object3D) -> @core.Scene {
  match o.kind {
    Scene(s) => s
    _ => abort("not a scene")
  }
}

///|
fn g5_box() -> @core.BufferGeometry {
  @geometries.BoxGeometry::new()
}

///|
fn g5_observer_run(
  name : String,
  make_material : () -> @core.Material,
  make_object : (@core.Material) -> @core.Object3D,
  steps : Array[((G5ObserverEnv) -> Unit)?],
) -> Unit {
  let renderer = @nodes.Renderer::foundation_stub()
  renderer._bindings = None
  renderer._output_render_target = Some(
    @core.RenderTarget::new(width=8, height=8),
  )
  let info = @nodes.Info::new()
  let nodes = @nodes.NodeManager::new(renderer, renderer.backend)
  let attributes = @nodes.Attributes::new(renderer.backend, info)
  let geometries = @nodes.Geometries::new(renderer.backend, attributes, info)
  let material = make_material()
  let object = make_object(material)
  let scene = @core.Scene::new()
  let camera = @core.PerspectiveCamera::new()
  let lights_node = @nodes.LightsNode::new()
  let context = @nodes.RenderContext::new()
  context.width = 8
  context.height = 8
  let ro = @nodes.RenderObject::new(
    nodes,
    geometries,
    renderer,
    object,
    material,
    scene,
    camera,
    lights_node,
    context,
    None,
  )
  let builder = @nodes.NodeBuilder::new(Object3D(object), renderer, None)
  let observer = @nodes.NodeMaterialObserver::new(builder)
  let frame = @nodes.NodeFrame::new()
  frame.renderer = Some(renderer)
  let log = ["hasNode=\{observer.has_node}"]
  let env = {
    renderer,
    material,
    object,
    scene,
    lights_node,
    context,
    frame,
    extra: [],
  }
  let mut render_id = 0
  for step in steps {
    if step is Some(f) {
      f(env)
    }
    frame.render_id = render_id
    render_id += 1
    log.push(observer.needs_refresh(ro, frame).to_string())
  }
  g5_emit("g5_observer_" + name, g5_json_code(log.join(",")))
}

///|
/// `renderObject.getMaterialCacheKey()` of a box mesh with `material`.
fn g5_material_key(material : @core.Material) -> String {
  let renderer = @nodes.Renderer::foundation_stub()
  renderer._bindings = None
  let info = @nodes.Info::new()
  let nodes = @nodes.NodeManager::new(renderer, renderer.backend)
  let geometries = @nodes.Geometries::new(
    renderer.backend,
    @nodes.Attributes::new(renderer.backend, info),
    info,
  )
  let object = @core.Mesh::new(geometry=g5_box(), material=Single(material))
  let ro = @nodes.RenderObject::new(
    nodes,
    geometries,
    renderer,
    object,
    material,
    @core.Scene::new(),
    @core.PerspectiveCamera::new(),
    @nodes.LightsNode::new(),
    @nodes.RenderContext::new(),
    None,
  )
  g5_js_string(ro.get_material_cache_key())
}

///|
test "g5 material cache keys" {
  for c in g5_classes {
    if c == "MeshSSSNodeMaterial" {
      continue
    }
    g5_emit("g5_key_material_" + c, g5_json_code(g5_material_key(g5_new(c))))
  }
  let variant = fn(name : String, make : () -> @core.Material) {
    g5_emit("g5_key_material_" + name, g5_json_code(g5_material_key(make())))
  }
  variant("physical_features", fn() {
    let m = @nodes.MeshPhysicalNodeMaterial::new()
    m.set_clearcoat(1)
    m.set_sheen(0.5)
    m.set_transmission(0.2)
    m.map = Some(@core.Texture::new())
    m
  })
  variant("line2_options", fn() {
    let m = @nodes.Line2NodeMaterial::new(dashed=true, vertex_colors=true)
    @nodes.Line2NodeMaterial::set_world_units(m, true)
    @nodes.Line2NodeMaterial::set_alpha_to_coverage(m, false)
    @nodes.Line2NodeMaterial::of(m).unwrap().dash_offset = 1
    m
  })
  variant("points_options", fn() {
    let m = @nodes.PointsNodeMaterial::new()
    @nodes.SpriteNodeMaterial::set_size_attenuation(m, false)
    @nodes.PointsNodeMaterial::set_alpha_to_coverage(m, true)
    m
  })
  variant("volume_steps", fn() {
    let m = @nodes.VolumeNodeMaterial::new()
    @nodes.VolumeNodeMaterial::of(m).unwrap().steps = 0
    m
  })
  variant("standard_maps", fn() {
    let m = @nodes.MeshStandardNodeMaterial::new()
    m.map = Some(@core.Texture::new())
    m.normal_map = Some(@core.Texture::new())
    m.flat_shading = Some(true)
    m
  })
}

///|
test "g5 observer sequences" {
  let same : ((G5ObserverEnv) -> Unit)? = None
  let step = fn(f : (G5ObserverEnv) -> Unit) -> ((G5ObserverEnv) -> Unit)? {
    Some(f)
  }
  let mesh = fn(m : @core.Material) {
    @core.Mesh::new(geometry=g5_box(), material=Single(m))
  }
  let standard = @nodes.MeshStandardNodeMaterial::new
  let basic = @nodes.MeshBasicNodeMaterial::new
  g5_observer_run("static_sequence", standard, mesh, [
    same,
    same,
    same,
    step(fn(e) { e.frame.render_id = 0 }),
    same,
  ])
  g5_observer_run("material_changes", standard, mesh, [
    same,
    same,
    step(fn(e) { e.material.roughness = Some(0.5) }),
    same,
    step(fn(e) { e.material.color.unwrap().set_hex(0xff0000) |> ignore }),
    same,
    step(fn(e) { e.material.map = Some(@core.Texture::new()) }),
    same,
    step(fn(e) { e.material.map.unwrap().version += 1 }),
    same,
    step(fn(e) { e.material.map.unwrap().offset.set(0.5, 0) |> ignore }),
    same,
    step(fn(e) { e.material.map = None }),
    same,
  ])
  g5_observer_run("world_matrix", basic, mesh, [
    same,
    same,
    step(fn(e) {
      e.object.position.x = 2
      e.object.update_matrix_world(force=true)
    }),
    same,
  ])
  g5_observer_run("geometry_changes", basic, mesh, [
    same,
    same,
    step(fn(e) {
      match e.object.get_geometry().unwrap().attributes.get("position") {
        Some(Buffer(a)) => a.set_needs_update(true)
        _ => ()
      }
    }),
    same,
    step(fn(e) { e.object.get_geometry().unwrap().set_draw_range(0, 6) }),
    same,
    step(fn(e) {
      e.object.get_geometry().unwrap().delete_attribute("uv") |> ignore
    }),
    same,
  ])
  g5_observer_run("output_target_resize", basic, mesh, [
    same,
    same,
    step(fn(e) { e.context.width = 16 }),
    same,
    step(fn(e) {
      e.renderer._render_target = Some(
        @core.RenderTarget::new(width=2, height=2),
      )
    }),
    same,
    same,
  ])
  g5_observer_run(
    "node_material_with_node",
    fn() {
      let m = basic()
      g5_nm(m).color_node = Some(@nodes.float(1))
      m
    },
    mesh,
    [same, same],
  )
  g5_observer_run(
    "skinned",
    basic,
    fn(m) {
      let bones = [@core.Bone::new()]
      let s = @core.SkinnedMesh::new(geometry=g5_box(), material=Single(m))
      s.add(bones[0]) |> ignore
      s.bind(@core.Skeleton::new(bones~))
      s
    },
    [same, same],
  )
  g5_observer_run(
    "instanced",
    basic,
    fn(m) { @core.InstancedMesh::new(geometry=g5_box(), material=Single(m), 2) },
    [
      same,
      same,
      step(fn(e) {
        match e.object.kind {
          Mesh({ kind: InstancedMesh(i), .. }) =>
            i.instance_matrix.set_needs_update(true)
          _ => ()
        }
      }),
      same,
      step(fn(e) {
        e.object.set_color_at(0, @math.Color::new(1, 0, 0)) |> ignore
      }),
      same,
    ],
  )
  g5_observer_run(
    "instanced_dynamic",
    basic,
    fn(m) {
      let i = @core.InstancedMesh::new(geometry=g5_box(), material=Single(m), 2)
      match i.kind {
        Mesh({ kind: InstancedMesh(p), .. }) =>
          p.instance_matrix.set_usage(@core.DynamicDrawUsage) |> ignore
        _ => ()
      }
      i
    },
    [same, same],
  )
  g5_observer_run(
    "morph",
    basic,
    fn(m) {
      let g = g5_box()
      match g.attributes.get("position") {
        Some(Buffer(a)) =>
          g.morph_attributes.set("position", [Buffer(a.clone())])
        _ => ()
      }
      let o = @core.Mesh::new(geometry=g, material=Single(m))
      o.update_morph_targets()
      o
    },
    [
      same,
      same,
      step(fn(e) {
        match e.object.kind {
          Mesh(m) => m.morph_target_influences.unwrap()[0] = 0.5
          _ => ()
        }
      }),
      same,
    ],
  )
  g5_observer_run(
    "sprite_center",
    @nodes.SpriteNodeMaterial::new,
    fn(m) { @core.Sprite::new(material=m) },
    [
      same,
      same,
      step(fn(e) {
        match e.object.kind {
          Sprite(s) => s.center.set(0, 0) |> ignore
          _ => ()
        }
      }),
      same,
    ],
  )
  g5_observer_run("static_object", basic, mesh, [
    same,
    step(fn(e) {
      e.object.static_ = true
      e.material.opacity = 0.5
    }),
    same,
    step(fn(e) {
      e.renderer._render_target = Some(
        @core.RenderTarget::new(width=2, height=2),
      )
    }),
    same,
  ])
  g5_observer_run("environment", standard, mesh, [
    step(fn(e) { g5_scene_of(e.scene).environment = Some(@core.Texture::new()) }),
    same,
    step(fn(e) { g5_scene_of(e.scene).environment_intensity = 2 }),
    same,
    step(fn(e) { g5_scene_of(e.scene).environment_rotation.set_y(1) }),
    same,
    step(fn(e) {
      g5_scene_of(e.scene).environment
      .unwrap()
      .dispatch_event(@core.Event::new("dispose"))
    }),
    same,
  ])
  g5_observer_run(
    "line_dashed",
    @nodes.LineDashedNodeMaterial::new,
    fn(m) {
      @core.Line::new(
        geometry=@core.BufferGeometry::new().set_from_points([
          @math.Vector3::new(0, 0, 0),
          @math.Vector3::new(1, 0, 0),
        ]),
        material=Single(m),
      )
    },
    [
      same,
      same,
      step(fn(e) {
        @nodes.LineDashedNodeMaterial::of(e.material).unwrap().dash_offset = 2
      }),
      same,
      step(fn(e) { e.material.linewidth = Some(3) }),
      same,
    ],
  )
  g5_observer_run("volume_steps", @nodes.VolumeNodeMaterial::new, mesh, [
    same,
    same,
    step(fn(e) { @nodes.VolumeNodeMaterial::of(e.material).unwrap().steps = 10 }),
    same,
  ])
  g5_observer_run("physical", @nodes.MeshPhysicalNodeMaterial::new, mesh, [
    same,
    same,
    step(fn(e) { e.material.set_clearcoat(1) }),
    same,
    step(fn(e) { e.material.sheen_color.unwrap().set_hex(0xff0000) |> ignore }),
    same,
    step(fn(e) { e.material.clearcoat_map = Some(@core.Texture::new()) }),
    same,
  ])
  g5_observer_run("lights", standard, mesh, [
    step(fn(e) {
      let s = @core.SpotLight::new()
      match s.kind {
        Light({ kind: SpotLight(sp), .. }) =>
          sp.map = Some(@core.Texture::new())
        _ => ()
      }
      let d = @core.DirectionalLight::new()
      d.cast_shadow = true
      @nodes.LightsNode::set_lights(e.lights_node, [s, d]) |> ignore
      e.extra.push(s)
      e.extra.push(d)
    }),
    same,
    step(fn(e) {
      match e.extra[0].kind {
        Light({ kind: SpotLight(sp), .. }) => sp.map.unwrap().version += 1
        _ => ()
      }
    }),
    same,
    step(fn(e) {
      match e.extra[1].kind {
        Light({ shadow: Some(sh), .. }) => sh.map_size.set(1024, 1024) |> ignore
        _ => ()
      }
    }),
    same,
    same,
  ])
}
