// MoonBit side of the G4 shader scenarios (nodes/display, nodes/gpgpu, nodes/parsers);
// the upstream side is diff/core/webgpu/shader_diff/upstream_g4.mjs, with the same scenario names (`g4_`) in the same order. Both build with
// `G4Builder`: a NodeBuilder with a GLSLNodeParser, GLSLNodeBuilder's
// `buildFunctionCode` (layout functions, and their `fn<id>` names, show up in `codes`)
// and fixed snippets for the backend methods the nodes call. One renderer serves every
// scenario, as layout functions are cached per backend.

///|
priv struct G4Builder {
  flip_y : Bool
}

///|
fn g4_fmt(s : String?) -> String {
  match s {
    Some(s) => s
    None => "-"
  }
}

///|
impl @nodes.NodeBuilderClass for G4Builder with fn is_flip_y(self, _) {
  self.flip_y
}

///|
impl @nodes.NodeBuilderClass for G4Builder with fn generate_texture(
  _,
  _,
  _,
  p,
  uv,
  depth,
  offset,
  _,
) {
  "tex(\{p}, \{uv}, \{g4_fmt(depth)}, \{g4_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G4Builder with fn generate_texture_level(
  _,
  _,
  _,
  p,
  uv,
  level,
  depth,
  offset,
) {
  "texLevel(\{p}, \{uv}, \{level}, \{g4_fmt(depth)}, \{g4_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G4Builder with fn generate_texture_size(
  _,
  _,
  _,
  p,
  level,
) {
  "size(\{p}, \{level})"
}

///|
fn g4_attribute(n : Int32, item_size : Int32) -> @core.GeometryAttribute {
  Buffer(
    @core.BufferAttribute::new(
      @core.TypedArray::float32(n * item_size),
      item_size,
    ),
  )
}

///|
/// A mesh geometry with the attributes the display scenarios read.
let g4_geometry : @core.BufferGeometry = {
  let g = @core.BufferGeometry::new()
  g.set_attribute("position", g4_attribute(24, 3)) |> ignore
  g.set_attribute("normal", g4_attribute(24, 3)) |> ignore
  g.set_attribute("uv", g4_attribute(24, 2)) |> ignore
  g.set_attribute("tangent", g4_attribute(24, 4)) |> ignore
  g
}

///|
fn g4_setup(f : () -> @nodes.Node) -> @core.JsValue {
  @core.JsValue::of(@nodes.ContextSetup::{ f, })
}

///|
/// The callbacks a node material puts in the context (`materialContext` of
/// upstream_g4.mjs, as upstream_g2.mjs).
fn g4_material_context(b : @nodes.NodeBuilder) -> Unit {
  b.context.set(
    "setupPositionView",
    Other(
      g4_setup(fn() {
        @nodes.model_view_matrix.mul(@nodes.position_local).xyz()
      }),
    ),
  )
  b.context.set(
    "setupNormal",
    Other(
      g4_setup(fn() {
        @nodes.sub_build(@nodes.normal_view_geometry, "NORMAL", type_="vec3")
      }),
    ),
  )
}

///|
fn g4_f1(v : Double, name : String) -> @nodes.Node {
  @nodes.float(v).to_var(name~)
}

///|
fn g4_no_mesh(_ : @core.Material) -> Unit {
  ()
}

///|
extern "js" fn g4_js_string(values : @core.JsValue) -> String = "(v) => v.map( String ).join( ',' )"

///|
fn g4_vec4(v : @math.Vector4) -> String {
  g4_js_string(@core.JsValue::of([v.x, v.y, v.z, v.w]))
}

///|
fn g4_pass_node_state() -> String {
  let p = @nodes.pass(@core.Scene::new(), @core.PerspectiveCamera::new(), options={
    ..@nodes.PassNodeOptions::default(),
    samples: Some(2),
  })
  let output = p.get_texture("output")
  p.get_texture("normal") |> ignore
  p.get_texture_node(name="normal") |> ignore
  p.get_previous_texture_node(name="output") |> ignore
  p.set_resolution_scale(0.5) |> ignore
  p.set_scissor(Some(@math.Vector4::new(1.0, 2.0, 3.0, 5.0)))
  p.set_viewport(Some(@math.Vector4::new(2.0, 4.0, 7.0, 9.0)))
  p.set_size(101.0, 51.0)
  p.toggle_texture("output")
  let rt = @nodes.PassNode::of(p).unwrap().render_target
  let depth = rt.depth_texture().unwrap()
  [
    rt.width.to_string(),
    rt.height.to_string(),
    g4_vec4(rt.scissor),
    rt.scissor_test.to_string(),
    g4_vec4(rt.viewport),
    rt.textures.map(fn(t) { t.name }).join(","),
    physical_equal(rt.textures[0], output).to_string(),
    physical_equal(p.get_texture("output"), output).to_string(),
    physical_equal(p.get_previous_texture("output"), output).to_string(),
    depth.name,
    depth.format.to_string(),
    depth.type_.to_string(),
    rt.texture().type_.to_string(),
    rt.samples.to_string(),
    g4_js_string(@core.JsValue::of([p.get_resolution_scale()])),
    physical_equal(
      p.get_texture_node(name="normal"),
      p.get_texture_node(name="normal"),
    ).to_string(),
    physical_equal(
      @nodes.TextureNode::get_value(p.get_texture_node()),
      p.get_texture("output"),
    ).to_string(),
    physical_equal(
      @nodes.TextureNode::get_value(p.get_previous_texture_node()),
      output,
    ).to_string(),
    p.update_before_type,
    p.global.to_string(),
  ].join(" ")
}

///|
fn g4_depth_pass_state() -> String {
  let p = @nodes.depth_pass(
    @core.Scene::new(),
    @core.PerspectiveCamera::new(),
    options={
      ..@nodes.PassNodeOptions::default(),
      stencil_buffer: Some(true),
      depth_buffer: Some(false),
      type_: Some(@core.FloatType),
    },
  )
  let q = @nodes.pass(@core.Scene::new(), @core.PerspectiveCamera::new(), options={
    ..@nodes.PassNodeOptions::default(),
    depth_buffer: Some(false),
  })
  let pp = @nodes.PassNode::of(p).unwrap()
  let rt = pp.render_target
  let depth = rt.depth_texture().unwrap()
  let qp = @nodes.PassNode::of(q).unwrap()
  [
    pp.scope,
    depth.format.to_string(),
    depth.type_.to_string(),
    depth.is_render_target_texture.to_string(),
    rt.texture().type_.to_string(),
    rt.texture().name,
    if qp.render_target.depth_texture() is Some(_) {
      "texture"
    } else {
      ""
    },
    qp._textures.keys().collect().join(","),
    pp.auto_clear.to_string(),
    pp.auto_clear_depth.to_string(),
  ].join(" ")
}

///|
fn g4_toon_outline_material(
  color? : &@nodes.IntoTsl,
  thickness? : &@nodes.IntoTsl,
  alpha? : &@nodes.IntoTsl,
) -> (@nodes.Node, @nodes.NodeMaterial) {
  let p = @nodes.toon_outline_pass(
    @core.Scene::new(),
    @core.PerspectiveCamera::new(),
    color?,
    thickness?,
    alpha?,
  )
  let m = @nodes.ToonOutlinePassNode::of(p).unwrap()._outline_material
  (p, @nodes.NodeMaterial::of(m).unwrap())
}

///|
fn g4_tex() -> @core.Texture {
  let t = @core.Texture::new()
  t.name = "tex"
  t
}

///|
impl @nodes.NodeBuilderClass for G4Builder with fn class_name(_) {
  "G4Builder"
}

///|
impl @nodes.NodeBuilderClass for G4Builder with fn build_function_code(
  _,
  builder,
  shader_node,
) {
  let layout = @nodes.ShaderNodeInternal::get_layout(shader_node).unwrap()
  let flow_data = builder.flow_shader_node(shader_node)
  let parameters = layout.inputs.map(fn(input) {
    builder.get_type(input.type_) + " " + input.name
  })
  let type_ = builder.get_type(layout.type_.unwrap_or("undefined"))
  let vars = flow_data.vars.unwrap_or("undefined")
  "\{type_} \{layout.name}( \{parameters.join(", ")} ) {\n\n\t\{vars}\n\n\{flow_data.code}\n\treturn \{flow_data.result_snippet()};\n\n}"
}

///|
impl @nodes.NodeBuilderClass for G4Builder with fn get_scoped_array(
  _,
  _,
  name,
  scope,
  buffer_type,
  buffer_count,
  is_atomic,
) {
  "\{name}/*\{scope} \{buffer_type} \{buffer_count} \{is_atomic}*/"
}

///|
impl @nodes.NodeBuilderClass for G4Builder with fn has_builtin(_, _, _, _) {
  false
}

///|
impl @nodes.NodeBuilderClass for G4Builder with fn enable_sub_groups(_, _) {
  ()
}

///|
impl @nodes.NodeBuilderClass for G4Builder with fn get_instance_index(_, _) {
  "instanceIndex"
}

///|
impl @nodes.NodeBuilderClass for G4Builder with fn get_front_facing(_, _) {
  "gl_FrontFacing"
}

///|
impl @nodes.NodeBuilderClass for G4Builder with fn get_frag_coord(_, _) {
  "gl_FragCoord"
}

///|
impl @nodes.NodeBuilderClass for G4Builder with fn get_frag_depth(_, _) {
  "gl_FragDepth"
}

///|
extern "js" fn g4_json(
  code : String,
  result : String,
  vars : String,
  uniforms : Array[String],
  codes : Array[String],
  extra : String,
) -> String = "(code, result, vars, uniforms, codes, extra) => JSON.stringify({ code, result, vars, uniforms, codes, extra })"

///|
/// `json.replaceAll( '_' + id, '_#' )`.
extern "js" fn g4_replace_id(json : String, id : Int32) -> String = "(json, id) => json.replaceAll( `_${ id }`, '_#' )"

///|
/// `relativeUserNames( json )` of upstream_g4.mjs.
extern "js" fn g4_relative_user_names(json : String) -> String =
  #|(json) => {
  #|  const ids = [ ...json.matchAll( /\bfn(\d+)\b/g ) ].map( ( m ) => + m[ 1 ] ).filter( ( n ) => n >= 130 );
  #|  if ( ids.length === 0 ) return json;
  #|  const base = Math.min( ...ids );
  #|  return json.replace( /\bfn(\d+)\b/g, ( m, n ) => + n >= 130 ? `fnUser${ + n - base }` : m );
  #|}

///|
priv struct G4Scenario {
  name : String
  stage : String
  make : () -> @nodes.Node
  extra : ((@nodes.NodeBuilder, @nodes.Node) -> String)?
  setup : ((@nodes.NodeBuilder) -> Unit)?
  teardown : (() -> Unit)?
  ids : ((@nodes.Node) -> Array[Int32])?
  user : Bool
  /// Build for a mesh with a MeshBasicMaterial this configures, and a camera.
  mesh : ((@core.Material) -> Unit)?
  orthographic : Bool
  flip_y : Bool
  /// Bind a render target on the renderer (the viewport textures' reference).
  render_target : Bool
}

///|
fn g4(
  name : String,
  stage : String,
  make : () -> @nodes.Node,
  extra? : (@nodes.NodeBuilder, @nodes.Node) -> String,
  setup? : (@nodes.NodeBuilder) -> Unit,
  teardown? : () -> Unit,
  ids? : (@nodes.Node) -> Array[Int32],
  user~ : Bool = false,
  mesh? : (@core.Material) -> Unit,
  orthographic~ : Bool = false,
  flip_y~ : Bool = false,
  render_target~ : Bool = false,
) -> G4Scenario {
  {
    name,
    stage,
    make,
    extra,
    setup,
    teardown,
    ids,
    user,
    mesh,
    orthographic,
    flip_y,
    render_target,
  }
}

///|
fn g4_c3() -> @nodes.Node {
  @nodes.vec3_of([0.5, 0.25, 1]).to_var(name="c")
}

///|
fn g4_c4() -> @nodes.Node {
  @nodes.vec4_of([0.5, 0.25, 1, 0.5]).to_var(name="c")
}

///|
fn g4_context_color(builder : @nodes.NodeBuilder) -> Unit {
  builder.context.set(
    "color",
    Node(@nodes.vec4_of([0.1, 0.2, 0.3, 0.4]).to_var(name="ctx")),
  )
}

///|
fn g4_glsl(code : String) -> @nodes.Node {
  @nodes.FunctionNode::new(code~)
}

///|
fn g4_parsed(node : @nodes.Node) -> (@nodes.NodeBuilder, @nodes.Node) -> String {
  fn(builder, _) {
    let f = @nodes.FunctionNode::get_node_function(node, builder)
    let lines = ["\{f.type_}|\{f.name}|\{f.precision}"]
    for i in f.inputs {
      let count = match i.count {
        Some(c) => c.to_string()
        None => "null"
      }
      lines.push("\{i.type_} \{i.name} \{count} \{i.qualifier} \{i.is_const}")
    }
    lines.join("\n")
  }
}

///|
/// Display P3, as examples/jsm/math/ColorSpaces.js defines it.
fn g4_define_display_p3() -> Unit {
  let p3_primaries = [0.680, 0.320, 0.265, 0.690, 0.150, 0.060]
  let p3_to_xyz = @math.Matrix3::new().set(
    0.4865709, 0.2656677, 0.1982173, 0.2289746, 0.6917385, 0.0792869, 0.0000000,
    0.0451134, 1.0439444,
  )
  let xyz_to_p3 = @math.Matrix3::new().set(
    2.4934969, -0.9313836, -0.4027108, -0.8294890, 1.7626641, 0.0236247, 0.0358458,
    -0.0761724, 0.9568845,
  )
  @math.color_management.define(
    Map::from_array([
      (
        "display-p3",
        {
          primaries: p3_primaries,
          white_point: [0.3127, 0.3290],
          transfer: @math.SRGBTransfer,
          to_xyz: p3_to_xyz,
          from_xyz: xyz_to_p3,
          luminance_coefficients: [0.2289, 0.6917, 0.0793],
          working_color_space_config: None,
          output_color_space_config: Some({
            drawing_buffer_color_space: "display-p3",
            tone_mapping_mode: None,
          }),
        },
      ),
      (
        "display-p3-linear",
        {
          primaries: p3_primaries,
          white_point: [0.3127, 0.3290],
          transfer: @math.LinearTransfer,
          to_xyz: p3_to_xyz,
          from_xyz: xyz_to_p3,
          luminance_coefficients: [0.2289, 0.6917, 0.0793],
          working_color_space_config: Some({ unpack_color_space: "display-p3", }),
          output_color_space_config: Some({
            drawing_buffer_color_space: "display-p3",
            tone_mapping_mode: None,
          }),
        },
      ),
    ]),
  )
}

///|
fn g4_scenarios() -> Array[G4Scenario] {
  let basic = g4_glsl("float myFn( vec3 a, float b ) { return a.x + b; }")
  let qualifiers = g4_glsl(
    "#define FOO 1\n// header\n#pragma main\n/* lead */\n// line\nhighp vec4 shade( const in vec3 a, out float b[ 4 ], inout int c, sampler2D t ) {\n\tb[ 0 ] = 1.0;\n\treturn vec4( a, 1.0 );\n}",
  )
  let iface = g4_glsl("  vec3 noBody( vec2 uv )  ")
  let semicolon = g4_glsl("vec3 decl( vec2 uv );")
  let unnamed = g4_glsl("mediump float ( float a ) { return a; }")
  let inout = g4_glsl(
    "void update( inout vec3 a, in float b, out int c, const float d, mat3 m, float e ) { c = 1; }",
  )
  let called = @nodes.glsl_fn(
    "float called( vec3 a, int b, float c ) { return a.x * float( b ) + c; }",
  )
  [
    // color space functions and node
    g4("g4_srgb_eotf", "fragment", fn() {
      @nodes.s_rgb_transfer_eotf.call([g4_c3()])
    }),
    g4("g4_srgb_oetf", "fragment", fn() {
      @nodes.s_rgb_transfer_oetf.call([g4_c3()])
    }),
    g4("g4_premultiply_alpha", "fragment", fn() {
      @nodes.premultiply_alpha.call([g4_c4()])
    }),
    g4("g4_unpremultiply_alpha", "fragment", fn() {
      @nodes.unpremultiply_alpha.call([g4_c4()])
    }),
    g4("g4_color_space_srgb_to_working", "fragment", fn() {
      @nodes.color_space_to_working(g4_c4(), @math.SRGBColorSpace)
    }),
    g4("g4_color_space_working_to_srgb", "fragment", fn() {
      g4_c4().working_to_color_space(@math.SRGBColorSpace)
    }),
    g4("g4_color_space_same", "fragment", fn() {
      @nodes.convert_color_space(
        g4_c4(),
        @math.LinearSRGBColorSpace,
        @math.LinearSRGBColorSpace,
      )
    }),
    g4("g4_color_space_output", "fragment", fn() {
      @nodes.working_to_color_space(g4_c4(), "OutputColorSpace")
    }),
    g4("g4_color_space_srgb_to_p3", "fragment", fn() {
      @nodes.convert_color_space(g4_c4(), @math.SRGBColorSpace, "display-p3")
    }),
    g4("g4_color_space_p3_linear_to_working", "fragment", fn() {
      g4_c4().color_space_to_working("display-p3-linear")
    }),
    g4(
      "g4_color_space_disabled",
      "fragment",
      fn() {
        @math.color_management.enabled = false
        @nodes.color_space_to_working(g4_c4(), @math.SRGBColorSpace)
      },
      teardown=fn() { @math.color_management.enabled = true },
    ),

    // tone mapping and render output nodes
    g4("g4_tone_mapping_linear", "fragment", fn() {
      @nodes.tone_mapping(
        @core.LinearToneMapping,
        exposure=@nodes.float(1.2),
        color=g4_c4(),
      )
    }),
    g4("g4_tone_mapping_reinhard", "fragment", fn() {
      @nodes.tone_mapping(
        @core.ReinhardToneMapping,
        exposure=@nodes.float(1.2),
        color=g4_c4(),
      )
    }),
    g4("g4_tone_mapping_cineon", "fragment", fn() {
      @nodes.tone_mapping(
        @core.CineonToneMapping,
        exposure=@nodes.float(1.2),
        color=g4_c4(),
      )
    }),
    g4("g4_tone_mapping_aces_default_exposure", "fragment", fn() {
      g4_c4().tone_mapping(@core.ACESFilmicToneMapping)
    }),
    g4("g4_tone_mapping_agx", "fragment", fn() {
      @nodes.tone_mapping(
        @core.AgXToneMapping,
        exposure=@nodes.float(1.2),
        color=g4_c4(),
      )
    }),
    g4(
      "g4_tone_mapping_neutral_context_color",
      "fragment",
      fn() {
        @nodes.tone_mapping(
          @core.NeutralToneMapping,
          exposure=@nodes.float(0.8),
        )
      },
      setup=g4_context_color,
    ),
    g4("g4_tone_mapping_none", "fragment", fn() {
      @nodes.tone_mapping(
        @core.NoToneMapping,
        exposure=@nodes.float(1),
        color=g4_c4(),
      )
    }),
    g4("g4_tone_mapping_unsupported", "fragment", fn() {
      @nodes.tone_mapping(
        @core.CustomToneMapping,
        exposure=@nodes.float(1),
        color=g4_c4(),
      )
    }),
    g4("g4_render_output_plain", "fragment", fn() {
      @nodes.render_output(g4_c4())
    }),
    g4("g4_render_output_explicit", "fragment", fn() {
      @nodes.render_output(
        g4_c4(),
        tone_mapping=@core.ACESFilmicToneMapping,
        output_color_space=@math.SRGBColorSpace,
      )
    }),
    g4(
      "g4_render_output_context",
      "fragment",
      fn() { g4_c4().render_output() },
      setup=fn(builder) {
        builder.context.set(
          "toneMapping",
          Number(@core.AgXToneMapping.to_double()),
        )
        builder.context.set("outputColorSpace", String(@math.SRGBColorSpace))
      },
    ),
    g4(
      "g4_render_output_context_color",
      "fragment",
      fn() {
        let n = @nodes.render_output(
          @nodes.TslValue::Null,
          tone_mapping=@core.NeutralToneMapping,
          output_color_space=@math.LinearSRGBColorSpace,
        )
        @nodes.RenderOutputNode::of(n).unwrap().premultiplied_alpha = false
        n
      },
      setup=g4_context_color,
    ),

    // front facing
    g4(
      "g4_front_facing",
      "fragment",
      fn() {
        @nodes.vec2_of([
          @nodes.float(@nodes.front_facing),
          @nodes.face_direction,
        ])
      },
      mesh=g4_no_mesh,
    ),
    g4(
      "g4_front_facing_back_side",
      "fragment",
      fn() { @nodes.float(@nodes.front_facing) },
      mesh=fn(m) { m.side = @core.BackSide },
    ),
    g4(
      "g4_front_facing_vertex",
      "vertex",
      fn() { @nodes.float(@nodes.front_facing) },
      mesh=g4_no_mesh,
    ),
    g4(
      "g4_negate_on_back_side_front",
      "fragment",
      fn() { @nodes.negate_on_back_side.call([g4_c3()]) },
      mesh=g4_no_mesh,
    ),
    g4(
      "g4_negate_on_back_side_back",
      "fragment",
      fn() { @nodes.negate_on_back_side.call([g4_c3()]) },
      mesh=fn(m) { m.side = @core.BackSide },
    ),
    g4(
      "g4_negate_on_back_side_double",
      "fragment",
      fn() { @nodes.negate_on_back_side.call([g4_c3()]) },
      mesh=fn(m) { m.side = @core.DoubleSide },
    ),

    // screen and viewport
    g4("g4_screen_uv", "fragment", fn() { @nodes.screen_uv }),
    g4("g4_screen_size_coordinate", "fragment", fn() {
      @nodes.vec4_of([@nodes.screen_size, @nodes.screen_coordinate])
    }),
    g4(
      "g4_screen_coordinate_flip_y",
      "fragment",
      fn() { @nodes.screen_coordinate },
      flip_y=true,
    ),
    g4(
      "g4_screen_uv_flip_y",
      "fragment",
      fn() { @nodes.screen_uv },
      flip_y=true,
    ),
    g4("g4_viewport", "fragment", fn() {
      @nodes.vec4_of([@nodes.viewport.xy(), @nodes.viewport_size])
    }),
    g4("g4_viewport_uv", "fragment", fn() {
      @nodes.vec4_of([@nodes.viewport_coordinate, @nodes.viewport_uv])
    }),
    g4("g4_screen_dpr", "fragment", fn() { @nodes.screen_dpr.mul(2) }),

    // normal and bump maps
    g4(
      "g4_normal_map",
      "fragment",
      fn() { @nodes.normal_map(@nodes.texture(g4_tex())) },
      mesh=g4_no_mesh,
    ),
    g4(
      "g4_normal_map_scale",
      "fragment",
      fn() {
        @nodes.normal_map(
          @nodes.texture(g4_tex()),
          scale_node=@nodes.vec2_of([0.5, 2]),
        )
      },
      mesh=g4_no_mesh,
    ),
    g4(
      "g4_normal_map_scale_flat",
      "fragment",
      fn() {
        @nodes.normal_map(
          @nodes.texture(g4_tex()),
          scale_node=@nodes.vec2_of([0.5, 2]),
        )
      },
      mesh=fn(m) {
        m.flat_shading = Some(true)
        m.side = @core.DoubleSide
      },
    ),
    g4(
      "g4_normal_map_object_space",
      "fragment",
      fn() {
        let n = @nodes.normal_map(@nodes.texture(g4_tex()))
        @nodes.NormalMapNode::of(n).unwrap().normal_map_type = @core.ObjectSpaceNormalMap
        n
      },
      mesh=g4_no_mesh,
    ),
    g4(
      "g4_normal_map_rg",
      "fragment",
      fn() {
        let n = @nodes.normal_map(
          @nodes.texture(g4_tex()),
          scale_node=@nodes.float(1.5),
        )
        @nodes.NormalMapNode::of(n).unwrap().unpack_normal_mode = @core.NormalRGPacking
        n
      },
      mesh=g4_no_mesh,
    ),
    g4(
      "g4_normal_map_ga",
      "fragment",
      fn() {
        let n = @nodes.normal_map(@nodes.texture(g4_tex()))
        @nodes.NormalMapNode::of(n).unwrap().unpack_normal_mode = @core.NormalGAPacking
        n
      },
      mesh=g4_no_mesh,
    ),
    g4(
      "g4_bump_map",
      "fragment",
      fn() { @nodes.bump_map(@nodes.texture(g4_tex())) },
      mesh=g4_no_mesh,
    ),
    g4(
      "g4_bump_map_scale",
      "fragment",
      fn() {
        @nodes.bump_map(
          @nodes.texture(g4_tex()).r(),
          scale_node=@nodes.float(0.5),
          normal_node=@nodes.vec3_of([0, 0, 1]).to_var(name="n"),
        )
      },
      mesh=g4_no_mesh,
    ),
    g4(
      "g4_bump_map_wireframe",
      "fragment",
      fn() {
        @nodes.bump_map(@nodes.texture(g4_tex()), scale_node=@nodes.float(0.5))
      },
      mesh=fn(m) { m.wireframe = Some(true) },
    ),

    // depth
    g4("g4_depth", "fragment", fn() { @nodes.depth }, mesh=g4_no_mesh),
    g4(
      "g4_depth_orthographic",
      "fragment",
      fn() { @nodes.depth },
      mesh=g4_no_mesh,
      orthographic=true,
    ),
    g4(
      "g4_linear_depth",
      "fragment",
      fn() { @nodes.linear_depth() },
      mesh=g4_no_mesh,
    ),
    g4(
      "g4_linear_depth_value",
      "fragment",
      fn() { @nodes.linear_depth(value_node=g4_f1(0.5, "d")) },
      mesh=g4_no_mesh,
    ),
    g4(
      "g4_linear_depth_value_orthographic",
      "fragment",
      fn() { @nodes.linear_depth(value_node=g4_f1(0.5, "d")) },
      mesh=g4_no_mesh,
      orthographic=true,
    ),
    g4(
      "g4_depth_assign",
      "fragment",
      fn() {
        @nodes.fn_(fn(_, _) {
          @nodes.depth.assign_node(@nodes.float(0.25)).to_stack() |> ignore
          None
        }).call([])
      },
      mesh=g4_no_mesh,
    ),
    g4("g4_depth_functions", "fragment", fn() {
      let z = g4_f1(-3.0, "z")
      let n = g4_f1(0.1, "n")
      let f = g4_f1(100.0, "f")
      let d = g4_f1(0.5, "d")
      @nodes.vec4_of([
        @nodes.view_z_to_orthographic_depth(z, n, f),
        @nodes.view_z_to_reversed_orthographic_depth(z, n, f),
        @nodes.view_z_to_perspective_depth(z, n, f),
        @nodes.view_z_to_reversed_perspective_depth(z, n, f),
      ]).add(
        @nodes.vec4_of([
          @nodes.orthographic_depth_to_view_z.call([d, n, f]),
          @nodes.perspective_depth_to_view_z.call([d, n, f]),
          @nodes.view_z_to_logarithmic_depth(z, n, f),
          @nodes.logarithmic_depth_to_view_z(d, n, f),
        ]),
      )
    }),

    // viewport textures (a render target is bound, so the reference is the target)
    g4(
      "g4_viewport_texture",
      "fragment",
      fn() { @nodes.viewport_texture() },
      render_target=true,
    ),
    g4(
      "g4_viewport_texture_uv_level",
      "fragment",
      fn() {
        @nodes.viewport_texture(
          uv_node=@nodes.vec2_of([0.25, 0.5]),
          level_node=@nodes.float(2),
        )
      },
      render_target=true,
    ),
    g4(
      "g4_viewport_mip_texture",
      "fragment",
      fn() { @nodes.viewport_mip_texture() },
      render_target=true,
    ),
    g4(
      "g4_viewport_shared_texture",
      "fragment",
      fn() { @nodes.viewport_shared_texture(uv_node=@nodes.screen_uv.mul(0.5)) },
      render_target=true,
    ),
    g4(
      "g4_viewport_depth_texture",
      "fragment",
      fn() { @nodes.viewport_depth_texture() },
      render_target=true,
    ),
    g4(
      "g4_viewport_opaque_mip_texture",
      "fragment",
      fn() { @nodes.viewport_opaque_mip_texture(uv=@nodes.vec2(0.5)) },
      render_target=true,
    ),
    g4(
      "g4_viewport_linear_depth",
      "fragment",
      fn() { @nodes.viewport_linear_depth },
      mesh=g4_no_mesh,
      render_target=true,
    ),

    // pass nodes (state only: building one needs renderer members not ported yet)
    g4("g4_pass_node_state", "fragment", fn() { @nodes.float(1) }, extra=fn(
      _,
      _,
    ) {
      g4_pass_node_state()
    }),
    g4("g4_depth_pass_state", "fragment", fn() { @nodes.float(1) }, extra=fn(
      _,
      _,
    ) {
      g4_depth_pass_state()
    }),
    g4(
      "g4_toon_outline_vertex",
      "vertex",
      fn() { g4_toon_outline_material().1.vertex_node.unwrap() },
      mesh=g4_no_mesh,
    ),
    g4(
      "g4_toon_outline_color",
      "fragment",
      fn() {
        g4_toon_outline_material(
          color=@math.Color::new(1.0, 0.5, 0.0),
          thickness=0.01,
          alpha=0.5,
        ).1.color_node.unwrap()
      },
      extra=fn(_, _) {
        let p = @nodes.toon_outline_pass(
          @core.Scene::new(),
          @core.PerspectiveCamera::new(),
        )
        let m = @nodes.ToonOutlinePassNode::of(p).unwrap()._outline_material
        let position = if @nodes.NodeMaterial::of(m).unwrap().position_node
          is Some(_) {
          "node"
        } else {
          ""
        }
        [
          p.name.unwrap_or(""),
          m.name,
          m.side.to_string(),
          position,
          @nodes.PassNode::of(p).unwrap().scope,
        ].join(" ")
      },
    ),

    // blend modes
    g4("g4_blend_burn", "fragment", fn() {
      @nodes.blend_burn.call([g4_c3(), @nodes.vec3_of([0.2, 0.4, 0.6])])
    }),
    g4("g4_blend_dodge", "fragment", fn() {
      @nodes.blend_dodge.call([g4_c3(), @nodes.vec3_of([0.2, 0.4, 0.6])])
    }),
    g4("g4_blend_screen", "fragment", fn() {
      @nodes.blend_screen.call([g4_c3(), @nodes.vec3_of([0.2, 0.4, 0.6])])
    }),
    g4("g4_blend_overlay", "fragment", fn() {
      @nodes.blend_overlay.call([g4_c3(), @nodes.vec3_of([0.2, 0.4, 0.6])])
    }),
    g4("g4_blend_color", "fragment", fn() {
      @nodes.blend_color.call([g4_c4(), @nodes.vec4_of([0.2, 0.4, 0.6, 0.8])])
    }),

    // color adjustment
    g4("g4_grayscale_default", "fragment", fn() {
      @nodes.grayscale.call([g4_c3()])
    }),
    g4("g4_grayscale_coefficients", "fragment", fn() {
      @nodes.grayscale.call([g4_c3(), @nodes.vec3_of([0.3, 0.59, 0.11])])
    }),
    g4("g4_saturation", "fragment", fn() {
      @nodes.saturation.call([g4_c3(), @nodes.float(0.5)])
    }),
    g4("g4_saturation_default", "fragment", fn() {
      @nodes.saturation.call([g4_c3()])
    }),
    g4("g4_vibrance", "fragment", fn() {
      @nodes.vibrance.call([g4_c3(), @nodes.float(0.3)])
    }),
    g4("g4_hue", "fragment", fn() {
      @nodes.hue.call([g4_c3(), @nodes.float(0.7)])
    }),
    g4("g4_luminance", "fragment", fn() { @nodes.luminance(g4_c3()) }),
    g4("g4_cdl_default", "fragment", fn() { @nodes.cdl.call([g4_c4()]) }),
    g4("g4_cdl_full", "fragment", fn() {
      @nodes.cdl.call([
        g4_c4(),
        @nodes.vec3(1.1),
        @nodes.vec3(0.01),
        @nodes.vec3(0.9),
        @nodes.float(1.2),
      ])
    }),
    g4("g4_posterize", "fragment", fn() {
      @nodes.posterize.call([g4_c3(), @nodes.float(4)])
    }),

    // tone mapping functions
    g4("g4_tone_linear", "fragment", fn() {
      @nodes.linear_tone_mapping.call([g4_c3(), @nodes.float(1.5)])
    }),
    g4("g4_tone_reinhard", "fragment", fn() {
      @nodes.reinhard_tone_mapping.call([g4_c3(), @nodes.float(1.5)])
    }),
    g4("g4_tone_cineon", "fragment", fn() {
      @nodes.cineon_tone_mapping.call([g4_c3(), @nodes.float(1.5)])
    }),
    g4("g4_tone_aces_filmic", "fragment", fn() {
      @nodes.aces_filmic_tone_mapping.call([g4_c3(), @nodes.float(1.5)])
    }),
    g4("g4_tone_agx", "fragment", fn() {
      @nodes.agx_tone_mapping.call([g4_c3(), @nodes.float(1.5)])
    }),
    g4("g4_tone_neutral", "fragment", fn() {
      @nodes.neutral_tone_mapping.call([g4_c3(), @nodes.float(1.5)])
    }),

    // compute built-ins
    g4("g4_compute_builtins", "compute", fn() {
      @nodes.uvec4_of([
        @nodes.num_workgroups.x(),
        @nodes.workgroup_id.y(),
        @nodes.local_id.z(),
        @nodes.global_id.x().add(@nodes.subgroup_size),
      ])
    }),
    g4("g4_compute_builtins_fragment", "fragment", fn() {
      @nodes.uvec4_of([
        @nodes.num_workgroups.x(),
        @nodes.workgroup_id.y(),
        @nodes.local_id.z(),
        @nodes.subgroup_size,
      ])
    }),

    // atomics
    g4("g4_atomic_value", "compute", fn() {
      @nodes.atomic_add(
        @nodes.workgroup_array("uint", count=4)
        .set_name("counts")
        .to_atomic()
        .element(@nodes.uint(1)),
        @nodes.uint(2),
      )
    }),
    g4("g4_atomic_statements", "compute", fn() {
      @nodes.fn_(fn(_, _) {
        let counts = @nodes.workgroup_array("int", count=8)
          .set_name("counts")
          .to_atomic()
        let e = counts.element(@nodes.uint(3))
        @nodes.atomic_add(e, @nodes.int(1)) |> ignore
        @nodes.atomic_sub(e, @nodes.int(2)) |> ignore
        @nodes.atomic_max(e, @nodes.int(3)) |> ignore
        @nodes.atomic_min(e, @nodes.int(4)) |> ignore
        @nodes.atomic_and(e, @nodes.int(5)) |> ignore
        @nodes.atomic_or(e, @nodes.int(6)) |> ignore
        @nodes.atomic_xor(e, @nodes.int(7)) |> ignore
        @nodes.atomic_store(e, @nodes.int(8)) |> ignore
        let v = @nodes.atomic_load(e).to_var(name="v")
        Some(v)
      }).call([])
    }),

    // barriers and workgroup arrays
    g4("g4_barriers", "compute", fn() {
      @nodes.fn_(fn(_, _) {
        @nodes.workgroup_barrier()
        @nodes.storage_barrier()
        @nodes.texture_barrier()
        None
      }).call([])
    }),
    g4("g4_workgroup_array_named", "compute", fn() {
      @nodes.workgroup_array("vec4", count=16)
      .set_name("tile")
      .element(@nodes.uint(2))
      .xy()
    }),
    g4("g4_workgroup_array_assign", "compute", fn() {
      @nodes.fn_(fn(_, _) {
        let tile = @nodes.workgroup_array("float", count=4).set_name("tile")
        tile.element(@nodes.uint(1)).assign(@nodes.float(3))
        Some(tile.element(@nodes.uint(1)).add(1))
      }).call([])
    }),
    g4(
      "g4_workgroup_array_unnamed",
      "compute",
      fn() { @nodes.workgroup_array("float").element(@nodes.uint(0)) },
      ids=fn(node) { [@nodes.ArrayElementNode::of(node).unwrap().node.id] },
    ),

    // subgroups
    g4("g4_subgroup_ops", "compute", fn() {
      let x = @nodes.float(1.5).to_var(name="x")
      let v = @nodes.vec3_of([1, 2, 3]).to_var(name="v")
      @nodes.vec4_of([
        @nodes.subgroup_add(x),
        @nodes.subgroup_inclusive_mul(v).y(),
        @nodes.subgroup_broadcast(v, @nodes.float(2)).z(),
        @nodes.subgroup_shuffle_xor(x, @nodes.uint(1)),
      ])
    }),
    g4("g4_subgroup_misc", "compute", fn() {
      let x = @nodes.float(1.5).to_var(name="x")
      @nodes.vec4_of([
        @nodes.float(@nodes.subgroup_elect()),
        @nodes.float(@nodes.subgroup_ballot(@nodes.bool(true)).x()),
        @nodes.float(@nodes.subgroup_all(@nodes.bool(false))),
        @nodes.quad_swap_x(x)
        .add(@nodes.quad_broadcast(x, @nodes.uint(1)))
        .add(@nodes.subgroup_shuffle_up(x, @nodes.uint(2))),
      ])
    }),

    // compute nodes
    g4(
      "g4_compute_count",
      "compute",
      fn() {
        @nodes.fn_(fn(_, _) {
          let counts = @nodes.workgroup_array("float", count=4).set_name(
            "counts",
          )
          counts.element(@nodes.uint(0)).assign(@nodes.float(1))
          None
        })
        .call([])
        .compute(64)
      },
      setup=fn(builder) { builder.allow_early_returns = true },
    ),
    g4("g4_compute_count_no_early_return", "compute", fn() {
      @nodes.compute(
        @nodes.fn_(fn(_, _) {
          let counts = @nodes.workgroup_array("float", count=4).set_name(
            "counts",
          )
          counts.element(@nodes.uint(0)).assign(@nodes.float(1))
          None
        }).call([]),
        32,
        workgroup_size=[8, 8],
      )
    }),
    g4("g4_compute_kernel_output", "fragment", fn() {
      @nodes.compute_kernel(
        @nodes.fn_(fn(_, _) { Some(@nodes.vec3_of([1, 2, 3]).to_var(name="r")) }).call([],
        ),
        workgroup_size=[4, 2],
      )
    }),
    g4(
      "g4_compute_barrier_flags",
      "compute",
      fn() {
        @nodes.fn_(fn(_, _) {
          @nodes.workgroup_barrier()
          None
        })
        .call([])
        .compute(16)
      },
      extra=fn(builder, _) {
        "\{builder.allow_early_returns} \{builder.allow_global_variables}"
      },
      setup=fn(builder) {
        builder.allow_early_returns = true
        builder.allow_global_variables = true
      },
    ),

    // GLSL parser
    g4("g4_glsl_basic", "fragment", fn() { basic }, extra=g4_parsed(basic)),
    g4(
      "g4_glsl_qualifiers",
      "fragment",
      fn() { qualifiers },
      extra=g4_parsed(qualifiers),
    ),
    g4("g4_glsl_interface", "fragment", fn() { iface }, extra=g4_parsed(iface)),
    g4(
      "g4_glsl_semicolon",
      "fragment",
      fn() { semicolon },
      extra=g4_parsed(semicolon),
    ),
    g4(
      "g4_glsl_unnamed",
      "fragment",
      fn() { unnamed },
      extra=g4_parsed(unnamed),
    ),
    g4("g4_glsl_inout", "fragment", fn() { inout }, extra=g4_parsed(inout)),
    g4("g4_glsl_call", "fragment", fn() {
      called.call([
        @nodes.vec3_of([1, 2, 3]).to_var(name="a"),
        2.5,
        @nodes.int(4),
      ])
    }),
    g4("g4_glsl_call_named", "fragment", fn() {
      called.call_named({
        "c": @nodes.float(1),
        "a": @nodes.vec3(4),
        "b": @nodes.int(2),
      })
    }),

    // fn<id> names of library functions from each group
    g4("g4_fn_names_g1", "fragment", fn() {
      @nodes.vec4_of([
        @nodes.rand.call([@nodes.vec2_of([0.25, 0.5]).to_var(name="p")]),
        @nodes.hash_tsl.call([@nodes.uint(7).to_var(name="s")]),
        @nodes.tri_noise3d.call([
          @nodes.vec3_of([1, 2, 3]).to_var(name="q"),
          @nodes.float(0.5),
          @nodes.float(0.25),
        ]),
        @nodes.float(1),
      ])
    }),
    g4("g4_fn_names_g4", "fragment", fn() {
      @nodes.vec4_of([
        @nodes.s_rgb_transfer_oetf.call([
          @nodes.blend_screen.call([g4_c3(), @nodes.vec3(0.1)]),
        ]),
        @nodes.grayscale.call([
          @nodes.neutral_tone_mapping.call([g4_c3(), @nodes.float(1)]),
        ]),
      ])
    }),
    g4(
      "g4_fn_names_user",
      "fragment",
      fn() {
        // short layouts created at run time count on from the library functions
        let a = @nodes.fn_(
          fn(inputs, _) { Some(inputs.get(0).unwrap().mul(2)) },
          layout=@nodes.FnLayout::short([("x", "float")], return_="float"),
        )
        let b = @nodes.fn_(
          fn(inputs, _) { Some(inputs.get(0).unwrap().add(1)) },
          layout=@nodes.FnLayout::short([("x", "float")], return_="float"),
        )
        a.call([b.call([@nodes.float(3).to_var(name="u")])])
      },
      user=true,
    ),
  ]
}

///|
test "g4 shader scenarios run (compared with upstream by run.mjs)" {
  g4_define_display_p3()
  let renderer = @nodes.Renderer::foundation_stub()
  // StandardNodeLibrary's tone mappings (upstream's WebGPURenderer has them)
  renderer.library.add_tone_mapping(
    @nodes.linear_tone_mapping,
    @core.LinearToneMapping,
  )
  renderer.library.add_tone_mapping(
    @nodes.reinhard_tone_mapping,
    @core.ReinhardToneMapping,
  )
  renderer.library.add_tone_mapping(
    @nodes.cineon_tone_mapping,
    @core.CineonToneMapping,
  )
  renderer.library.add_tone_mapping(
    @nodes.aces_filmic_tone_mapping,
    @core.ACESFilmicToneMapping,
  )
  renderer.library.add_tone_mapping(
    @nodes.agx_tone_mapping,
    @core.AgXToneMapping,
  )
  renderer.library.add_tone_mapping(
    @nodes.neutral_tone_mapping,
    @core.NeutralToneMapping,
  )
  let viewport_target = @core.RenderTarget::new(width=1, height=1)
  for scenario in g4_scenarios() {
    let object : @nodes.BuilderObject = match scenario.mesh {
      Some(configure) => {
        let material = @core.MeshBasicMaterial::new()
        configure(material)
        Object3D(
          @core.Mesh::new(geometry=g4_geometry, material=Single(material)),
        )
      }
      None => NoObject
    }
    let builder = @nodes.NodeBuilder::new(
      object,
      renderer,
      Some(@nodes.GLSLNodeParser::new()),
      class_=G4Builder::{ flip_y: scenario.flip_y, },
    )
    if scenario.mesh is Some(_) {
      builder.camera = Some(
        if scenario.orthographic {
          @core.OrthographicCamera::new()
        } else {
          @core.PerspectiveCamera::new()
        },
      )
      g4_material_context(builder)
    }
    renderer._render_target = if scenario.render_target {
      Some(viewport_target)
    } else {
      None
    }
    builder.set_shader_stage(Some(scenario.stage))
    if scenario.setup is Some(setup) {
      setup(builder)
    }
    let node = (scenario.make)()
    let flow = builder.flow_stages_node(node)
    let uniforms = []
    for stage in ["vertex", "fragment", "compute"] {
      for u in builder.uniforms.stage(stage) {
        uniforms.push("\{stage}:\{u.name}:\{u.type_}")
      }
    }
    let codes = []
    for stage in ["vertex", "fragment", "compute"] {
      if builder.codes.get(stage) is Some(list) {
        for c in list {
          codes.push("\{stage}:\{c.name}:\{c.code}")
        }
      }
    }
    let extra = match scenario.extra {
      Some(f) => f(builder, node)
      None => ""
    }
    if scenario.teardown is Some(teardown) {
      teardown()
    }
    renderer._render_target = None
    let mut json = g4_json(
      flow.code,
      flow.result_snippet(),
      flow.vars.unwrap_or(""),
      uniforms,
      codes,
      extra,
    )
    if scenario.ids is Some(ids) {
      for id in ids(node) {
        json = g4_replace_id(json, id)
      }
    }
    if scenario.user {
      json = g4_relative_user_names(json)
    }
    if shader_diff_enabled() {
      println("@@SHADER \{scenario.name} \{json}")
    }
  }
}
