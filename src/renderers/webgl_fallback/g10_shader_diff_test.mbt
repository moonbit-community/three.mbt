// MoonBit side of the G10 (GLSLNodeBuilder) shader scenarios. The upstream side is
// diff/core/webgpu/shader_diff/upstream_g10.mjs; `node shader_diff/run.mjs
// g10_...` compares them byte for byte. The first part re-runs G8's scenarios
// (g8_shader_diff_test.mbt) through GLSL under `g10_` names; then the GLSL-only
// scenarios and every node material class through `build()` (`g10_mat_*`). Renderers:
// `a` (the mock's default extensions), `b` (no extensions), `c` (default +
// WEBGL_clip_cull_distance), `d` (default, keyword diagnostics).

///|
extern "js" fn g10_shader_diff_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.SHADER_DIFF === '1'"

///|
extern "js" fn g10_flow_json(
  code : String,
  result : String,
  vars : String,
  uniforms : FixedArray[String],
  codes : String,
  decl : String,
  bindings : String,
) -> String = "(code, result, vars, uniforms, codes, decl, bindings) => JSON.stringify({ code, result, vars, uniforms, codes, decl, bindings })"

///|
extern "js" fn g10_shader_json(shader : String, bindings : String) -> String = "(shader, bindings) => JSON.stringify({ shader, bindings })"

///|
extern "js" fn g10_compute_json(
  shader : String,
  transforms : String,
  bindings : String,
) -> String = "(shader, transforms, bindings) => JSON.stringify({ shader, transforms, bindings })"

///|
/// `bindingsOf( builder )`.
fn g10_bindings(b : @nodes.NodeBuilder) -> String {
  b
  .get_bindings()
  .map(fn(g) {
    g.name +
    "[" +
    g.bindings
    .map(fn(binding) { "\{binding.name}:\{binding.visibility}" })
    .join(",") +
    "]"
  })
  .join(" ")
}

///|
fn g10_fv(v : Double) -> @nodes.Node {
  @nodes.float(v).to_var()
}

///|
fn g10_iv(v : Int32) -> @nodes.Node {
  @nodes.int(v).to_var()
}

///|
fn g10_uv(v : Int32) -> @nodes.Node {
  @nodes.uint(v).to_var()
}

///|
fn g10_v2() -> @nodes.Node {
  @nodes.vec2_of([1, 2]).to_var()
}

///|
fn g10_v3() -> @nodes.Node {
  @nodes.vec3_of([1, 2, 3]).to_var()
}

///|
fn g10_v4() -> @nodes.Node {
  @nodes.vec4_of([1, 2, 3, 4]).to_var()
}

///|
fn g10_m2() -> @nodes.Node {
  @nodes.mat2_of([1, 2, 3, 4]).to_var()
}

///|
fn g10_m3() -> @nodes.Node {
  @nodes.mat3_of([1, 0, 0, 0, 1, 0, 0, 0, 1]).to_var()
}

///|
fn g10_m4() -> @nodes.Node {
  @nodes.mat4_of([]).to_var()
}

///|
fn g10_tex() -> @core.Texture {
  let t = @core.Texture::new()
  t.name = "tex"
  t
}

///|
fn g10_float_tex(nearest : Bool) -> @core.Texture {
  let t = g10_tex()
  t.type_ = @core.FloatType
  if nearest {
    t.min_filter = @core.NearestFilter
    t.mag_filter = @core.NearestFilter
  }
  t
}

///|
fn g10_attribute(n : Int32, item_size : Int32) -> @core.GeometryAttribute {
  Buffer(
    @core.BufferAttribute::new(
      @core.TypedArray::float32(n * item_size),
      item_size,
    ),
  )
}

///|
let g10_geometry : @core.BufferGeometry = {
  let g = @core.BufferGeometry::new()
  g.set_attribute("position", g10_attribute(24, 3)) |> ignore
  g.set_attribute("normal", g10_attribute(24, 3)) |> ignore
  g.set_attribute("uv", g10_attribute(24, 2)) |> ignore
  g
}

///|
fn g10_float_buffer(n : Int32, item_size : Int32) -> @core.BufferAttribute {
  @nodes.StorageBufferAttribute::new(n, item_size)
}

///|
fn g10_uint_buffer(n : Int32) -> @core.BufferAttribute {
  @nodes.StorageBufferAttribute::new(n, 1, type_class=Uint32Array)
}

///|
fn g10_setup(f : () -> @nodes.Node) -> @core.JsValue {
  @core.JsValue::of(@nodes.ContextSetup::{ f, })
}

///|
/// `materialContext( builder )` of upstream_g8.mjs.
fn g10_material_context(b : @nodes.NodeBuilder) -> Unit {
  b.context.set(
    "setupPositionView",
    Other(
      g10_setup(fn() {
        @nodes.model_view_matrix.mul(@nodes.position_local).xyz()
      }),
    ),
  )
  b.context.set(
    "setupModelViewProjection",
    Other(
      g10_setup(fn() {
        @nodes.camera_projection_matrix.mul(@nodes.position_view)
      }),
    ),
  )
  b.context.set(
    "setupNormal",
    Other(
      g10_setup(fn() {
        @nodes.sub_build(@nodes.normal_view_geometry, "NORMAL", type_="vec3")
      }),
    ),
  )
}

///|
priv enum G10Kind {
  Flow(() -> @nodes.Node)
  Compute(() -> @nodes.Node)
  Material(() -> @nodes.Node, () -> @nodes.Node)
}

///|
priv struct G10Scenario {
  name : String
  kind : G10Kind
  stage : String
  renderer : String
  mesh : Bool
  ctx : Bool
  pre : ((@nodes.NodeBuilder) -> Unit)?
}

///|
priv struct G10Opts {
  stage : String
  renderer : String
  mesh : Bool
  ctx : Bool
  pre : ((@nodes.NodeBuilder) -> Unit)?
}

///|
let g10_default : G10Opts = {
  stage: "fragment",
  renderer: "a",
  mesh: false,
  ctx: false,
  pre: None,
}

///|
fn g10_stage(stage : String) -> G10Opts {
  { ..g10_default, stage, }
}

///|
fn g10_fn(body : () -> @nodes.Node) -> @nodes.Node {
  @nodes.fn_(fn(_, _) { Some(body()) }).call([])
}

///|
fn g10_fn_unit(body : () -> Unit) -> @nodes.Node {
  @nodes.fn_(fn(_, _) {
    body()
    None
  }).call([])
}

///|
fn g10_scenarios() -> Array[G10Scenario] {
  let scenarios : Array[G10Scenario] = []
  let flow = fn(name : String, make : () -> @nodes.Node, opts : G10Opts) {
    scenarios.push({
      name: "g10_" + name,
      kind: Flow(make),
      stage: opts.stage,
      renderer: opts.renderer,
      mesh: opts.mesh,
      ctx: opts.ctx,
      pre: opts.pre,
    })
  }
  let f = fn(name : String, make : () -> @nodes.Node) {
    flow(name, make, g10_default)
  }
  let compute_build = fn(
    name : String,
    make : () -> @nodes.Node,
    renderer : String,
  ) {
    scenarios.push({
      ..g10_default_scenario(name),
      kind: Compute(make),
      renderer,
    })
  }
  let material_build = fn(
    name : String,
    vertex : () -> @nodes.Node,
    fragment : () -> @nodes.Node,
    pre : ((@nodes.NodeBuilder) -> Unit)?,
  ) {
    scenarios.push({
      ..g10_default_scenario(name),
      kind: Material(vertex, fragment),
      pre,
    })
  }

  // --- Types, conversions and methods
  f("vec_types", fn() {
    @nodes.vec4_of([
      @nodes.float(@nodes.ivec2_of([1, 2]).to_var().x()),
      @nodes.float(@nodes.uvec3_of([1, 2, 3]).to_var().y()),
      @nodes.float(@nodes.bvec2_of([true, false]).to_var().x()),
      1,
    ])
  })
  f("mat_types", fn() {
    g10_m2()
    .mul(@nodes.vec2_of([1, 2]))
    .add(g10_m3().mul(@nodes.vec3(1)).xy())
    .add(g10_m4().mul(@nodes.vec4(1)).xy())
  })
  f("color_type", fn() { @nodes.color(0xff0000).to_var() })
  f("convert_int_float", fn() {
    @nodes.int(g10_fv(2.5)).add(@nodes.int(g10_uv(3)))
  })
  f("convert_vec", fn() {
    @nodes.vec3(@nodes.ivec3_of([1, 2, 3]).to_var()).add(
      @nodes.vec3(@nodes.uvec3_of([4, 5, 6]).to_var()),
    )
  })
  f("bitcast", fn() { @nodes.bitcast(g10_fv(1), "uint") })
  f("bitcast_methods", fn() {
    @nodes.vec2_of([
      @nodes.float(@nodes.float_bits_to_int(g10_fv(1))),
      @nodes.uint_bits_to_float(g10_uv(3)),
    ])
  })
  f("packing", fn() {
    @nodes.vec3_of([
      @nodes.float(@nodes.pack_snorm2x16(g10_v2())),
      @nodes.unpack_half2x16(g10_uv(5)).x(),
      @nodes.float(@nodes.pack_unorm4x8(g10_v4())),
    ])
  })
  f("mod_float", fn() { g10_fv(5).mod(2) })
  f("mod_vec2", fn() { g10_v2().mod(@nodes.vec2(2)) })
  f("mod_vec3", fn() { g10_v3().mod(g10_fv(2)) })
  f("mod_vec4", fn() { g10_v4().mod(@nodes.vec4(3)) })
  f("mod_int", fn() { g10_iv(5).mod(g10_iv(2)) })
  f("equal_bool", fn() {
    @nodes.bool(true).to_var().equal(@nodes.bool(false).to_var())
  })
  f("equal_bvec2", fn() {
    @nodes.bvec2_of([true, false])
    .to_var()
    .equal(@nodes.bvec2_of([false, false]).to_var())
  })
  f("xor", fn() { @nodes.bool(true).to_var().xor(@nodes.bool(false).to_var()) })
  f("inverse_mat2", fn() { g10_m2().inverse() })
  f("inverse_mat3", fn() { g10_m3().inverse() })
  f("inverse_mat4", fn() { g10_m4().inverse() })
  f("derivatives", fn() {
    g10_fv(1).d_fdx().add(g10_fv(2).d_fdy()).add(@nodes.inverse_sqrt(g10_fv(4)))
  })
  f("faceforward", fn() { @nodes.faceforward(g10_v3(), g10_v3(), g10_v3()) })
  f("select", fn() {
    @nodes.select(g10_fv(1).greater_than(0), g10_v3(), else_node=@nodes.vec3(0))
  })
  f("reserved_names", fn() {
    @nodes.float(1)
    .to_var(name="fn")
    .add(@nodes.float(2).to_var(name="main"))
    .add(@nodes.float(3).to_var(name="let"))
  })
  flow(
    "reserved_names_checked",
    fn() {
      @nodes.float(1)
      .to_var(name="fn")
      .add(@nodes.float(2).to_var(name="main"))
      .add(@nodes.float(3).to_var(name="let"))
      .add(@nodes.float(4).to_var(name="color"))
    },
    { ..g10_default, renderer: "d", },
  )
  f("declaration_names", fn() {
    @nodes.uniform(1)
    .set_name("scale")
    .add(@nodes.uniform(2).set_name("scale"))
    .add(
      @nodes.storage(g10_float_buffer(4, 1), type_="float", count=4)
      .set_name("buf")
      .element(g10_iv(0)),
    )
    .add(
      @nodes.storage(g10_float_buffer(4, 1), type_="float", count=4)
      .set_name("buf")
      .element(g10_iv(1)),
    )
  })
  f("array_values", fn() {
    @nodes.array([@nodes.float(1), @nodes.float(2), @nodes.float(3)])
    .to_var()
    .element(g10_iv(1))
  })
  f("array_count", fn() {
    @nodes.array_of_type("vec3", 4).to_var().element(g10_iv(2))
  })
  f("const_let", fn() {
    @nodes.vec3_of([1, 2, 3]).to_const(name="k").add(g10_fv(1).to_const())
  })

  // --- Functions
  f("fn_layout", fn() {
    @nodes.fn_(fn(inputs, _) {
      let a = inputs.get(0).unwrap()
      let b = inputs.get(1).unwrap()
      Some(a.mul(b).add(1))
    })
    .set_layout(name="myFn", type_="float", inputs=[
      ("a", "float"),
      ("b", "float"),
    ])
    .call([g10_fv(1), g10_fv(2)])
  })
  f("fn_layout_early_return", fn() {
    @nodes.fn_(fn(inputs, _) {
      let p = inputs.get(0).unwrap()
      let r = @nodes.vec3(0).to_var()
      @nodes.if_(p.x().greater_than(1), fn() {
        r.assign(p)
        @nodes.return_()
      })
      |> ignore
      r.assign(p.mul(2))
      Some(r)
    })
    .set_layout(name="earlyFn", type_="vec3", inputs=[("p", "vec3")])
    .call([g10_v3()])
  })
  f("fn_layout_mod", fn() {
    @nodes.fn_(fn(inputs, _) {
      let x = inputs.get(0).unwrap()
      Some(x.mod(2).add(x.d_fdx()))
    })
    .set_layout(name="modFn", type_="float", inputs=[("x", "float")])
    .call([g10_fv(3)])
  })
  f("wgsl_fn", fn() {
    @nodes.wgsl_fn("fn scale( a : f32, b : vec3f ) -> vec3f { return b * a; }").call([
        g10_fv(2),
        g10_v3(),
      ],
    )
  })
  f("wgsl_fn_comment", fn() {
    @nodes.wgsl_fn(
      "// scales\n/* by a */\nfn scale2( a : f32, b : vec2<f32> ) -> vec2<f32> { return b * a; }",
    ).call([g10_fv(2), g10_v2()])
  })
  f("wgsl_fn_includes", fn() {
    let inner = @nodes.wgsl_fn("fn inner( x : f32 ) -> f32 { return x * 2.0; }")
    @nodes.wgsl_fn("fn outer( x : f32 ) -> f32 { return inner( x ) + 1.0; }", includes=[
      inner,
    ]).call([g10_fv(3)])
  })
  f("wgsl_fn_object_args", fn() {
    @nodes.wgsl_fn(
      "fn mixer( a : vec3<f32>, b : vec3<f32>, t : f32 ) -> vec3<f32> { return mix( a, b, t ); }",
    ).call_named({ "t": g10_fv(0.5), "a": g10_v3(), "b": @nodes.vec3(1) })
  })
  f("loop_break", fn() {
    g10_fn(fn() {
      let r = g10_fv(0)
      @nodes.loop_([4], fn(inputs) {
        let i = inputs.named("i").unwrap()
        @nodes.if_(r.greater_than(2), fn() { @nodes.break_() }) |> ignore
        r.add_assign(@nodes.float(i))
      })
      r
    })
  })
  f("early_return_main", fn() {
    g10_fn(fn() {
      let r = g10_fv(1)
      @nodes.if_(r.greater_than(1), fn() { @nodes.return_() }) |> ignore
      r
    })
  })
  f("discard", fn() {
    g10_fn(fn() {
      @nodes.discard(conditional=g10_fv(1).less_than(0))
      g10_fv(1)
    })
  })

  // --- Structs
  f("struct", fn() {
    let s = @nodes.struct_(
      [
        @nodes.StructMember::new("a", "float"),
        @nodes.StructMember::new("b", "vec3"),
      ],
      name="MyStruct",
    )
    s.call([g10_fv(1), g10_v3()]).to_var().get("b")
  })
  f("output_struct", fn() {
    @nodes.output_struct([@nodes.vec4(1), @nodes.vec4(0.5)])
  })
  f("frag_depth", fn() {
    g10_fn(fn() {
      @nodes.depth.assign(g10_fv(0.5))
      @nodes.vec4(1)
    })
  })

  // --- Builtins
  flow("front_facing", fn() { @nodes.float(@nodes.front_facing).to_var() }, {
    ..g10_default,
    mesh: true,
  })
  f("frag_coord", fn() { @nodes.screen_coordinate.to_var() })
  flow(
    "vertex_index",
    fn() {
      @nodes.float(@nodes.vertex_index).add(@nodes.float(@nodes.instance_index))
    },
    g10_stage("vertex"),
  )
  f("instance_index_fragment", fn() { @nodes.float(@nodes.instance_index) })
  flow(
    "compute_builtins",
    fn() {
      @nodes.vec3(@nodes.global_id)
      .add(@nodes.vec3(@nodes.local_id))
      .add(@nodes.vec3(@nodes.workgroup_id))
      .add(@nodes.vec3(@nodes.num_workgroups))
    },
    g10_stage("compute"),
  )
  flow(
    "invocation_local_index",
    fn() { @nodes.float(@nodes.invocation_local_index) },
    g10_stage("compute"),
  )
  flow(
    "subgroups",
    fn() {
      @nodes.subgroup_add(g10_fv(1))
      .add(@nodes.float(@nodes.subgroup_size))
      .add(@nodes.float(@nodes.invocation_subgroup_index))
      .add(@nodes.float(@nodes.subgroup_index))
    },
    { ..g10_stage("compute"), renderer: "b", },
  )
  flow(
    "subgroups_unsupported",
    fn() { @nodes.float(@nodes.subgroup_size) },
    g10_stage("compute"),
  )
  flow("hardware_clipping", fn() { g10_fv(1) }, {
    ..g10_stage("vertex"),
    pre: Some(fn(b) { b.enable_hardware_clipping(3) }),
  })
  flow("directives", fn() { g10_fv(1) }, {
    ..g10_default,
    pre: Some(fn(b) {
      b.enable_shader_f16()
      b.enable_dual_source_blending()
      b.enable_shader_f16()
    }),
  })
  flow("invariant", fn() { g10_fv(1) }, {
    ..g10_stage("vertex"),
    pre: Some(fn(b) { b.context.set("invariant", Bool(true)) }),
  })

  // --- Uniforms
  f("uniforms_object", fn() {
    @nodes.uniform(1.5)
    .add(@nodes.uniform(@math.Vector3::new(1, 2, 3)).x())
    .add(@nodes.uniform(@math.Color::new(1, 0, 0)).r())
    .add(@nodes.uniform(@math.Matrix4::new()).mul(@nodes.vec4(1)).x())
  })
  f("uniforms_groups", fn() {
    @nodes.uniform(1)
    .set_group(@nodes.render_group)
    .add(@nodes.uniform(2).set_group(@nodes.frame_group))
    .add(@nodes.uniform(3))
    .add(@nodes.uniform(4).set_group(@nodes.uniform_group("custom")))
  })
  flow(
    "uniforms_vertex",
    fn() {
      @nodes.uniform(@math.Vector2::new(1, 2)).add(
        @nodes.uniform(@nodes.int(3)),
      )
    },
    g10_stage("vertex"),
  )
  f("uniform_array", fn() {
    @nodes.uniform_array([1, 2, 3, 4]).element(g10_iv(1))
  })
  f("uniform_array_vec4", fn() {
    @nodes.uniform_array([
      @math.Vector4::new(1, 2, 3, 4),
      @math.Vector4::new(0, 0, 0, 1),
    ]).element(g10_iv(1))
  })

  // --- Textures
  f("texture_sample", fn() { @nodes.texture(g10_tex()) })
  f("texture_uv", fn() {
    @nodes.texture(g10_tex(), uv_node=@nodes.vec2_of([0.25, 0.75]))
  })
  f("texture_level", fn() {
    @nodes.texture(g10_tex(), uv_node=@nodes.vec2(0.5)).level(2)
  })
  f("texture_bias", fn() {
    @nodes.texture(g10_tex(), uv_node=@nodes.vec2(0.5)).bias(0.5)
  })
  f("texture_grad", fn() {
    @nodes.texture(g10_tex(), uv_node=@nodes.vec2(0.5)).grad(
      @nodes.vec2(0.1),
      @nodes.vec2(0.2),
    )
  })
  f("texture_offset", fn() {
    @nodes.texture(g10_tex(), uv_node=@nodes.vec2(0.5)).offset(
      @nodes.ivec2_of([1, 2]),
    )
  })
  f("texture_depth_offset", fn() {
    @nodes.texture(@core.DataArrayTexture::new(), uv_node=@nodes.vec2(0.5))
    .depth(1)
    .offset(@nodes.ivec2_of([1, 0]))
  })
  f("texture_gather", fn() {
    @nodes.texture(g10_tex(), uv_node=@nodes.vec2(0.5)).gather()
  })
  f("texture_gather_channel", fn() {
    @nodes.texture(g10_tex(), uv_node=@nodes.vec2(0.5)).gather(gather_node=2)
  })
  f("texture_load", fn() {
    @nodes.texture_load(g10_tex(), uv_node=@nodes.ivec2_of([1, 2]))
  })
  f("texture_load_level", fn() {
    @nodes.texture_load(
      g10_tex(),
      uv_node=@nodes.ivec2_of([1, 2]),
      level_node=1,
    )
  })
  f("texture_size", fn() { @nodes.texture_size(@nodes.texture(g10_tex())) })
  f("texture_size_level", fn() { @nodes.texture(g10_tex()).size(level_node=2) })
  f("texture_array", fn() {
    @nodes.texture(@core.DataArrayTexture::new(), uv_node=@nodes.vec2(0.5)).depth(
      2,
    )
  })
  f("texture_depth_texture", fn() {
    @nodes.texture(
      @core.DepthTexture::new(width=4, height=4),
      uv_node=@nodes.vec2(0.5),
    )
  })
  // the `compare()` scenarios (restored by G6 with `Renderer::has_compatibility`)
  f("texture_compare", fn() {
    @nodes.texture(
      @core.DepthTexture::new(width=4, height=4),
      uv_node=@nodes.vec2(0.5),
    ).compare(0.25)
  })
  f("texture_gather_compare", fn() {
    @nodes.texture(
      @core.DepthTexture::new(width=4, height=4),
      uv_node=@nodes.vec2(0.5),
    )
    .gather()
    .compare(0.25)
  })
  flow(
    "texture_depth_load_compat",
    fn() {
      @nodes.texture_load(
        @core.DepthTexture::new(width=4, height=4),
        uv_node=@nodes.ivec2_of([1, 2]),
      )
    },
    { ..g10_default, renderer: "c", },
  )
  flow(
    "texture_depth_compat",
    fn() {
      @nodes.texture(
        @core.DepthTexture::new(width=4, height=4),
        uv_node=@nodes.vec2(0.5),
      )
    },
    { ..g10_default, renderer: "c", },
  )
  f("texture_int", fn() {
    let t = g10_tex()
    t.type_ = @core.IntType
    @nodes.texture(t, uv_node=@nodes.vec2(0.5))
  })
  f("texture_uint_red", fn() {
    let t = g10_tex()
    t.type_ = @core.UnsignedIntType
    t.format = @core.RedIntegerFormat
    @nodes.texture(t, uv_node=@nodes.vec2(0.5))
  })
  f("texture_cube", fn() {
    @nodes.cube_texture(
      @core.CubeTexture::new(),
      uv_node=@nodes.vec3_of([0, 1, 0]),
    )
  })
  f("texture_cube_level", fn() {
    @nodes.cube_texture(
      @core.CubeTexture::new(),
      uv_node=@nodes.vec3_of([0, 1, 0]),
      level_node=2,
    )
  })
  f("texture_cube_float", fn() {
    let t = @core.CubeTexture::new()
    t.type_ = @core.FloatType
    @nodes.cube_texture(t, uv_node=@nodes.vec3_of([0, 1, 0])).offset(
      @nodes.ivec3_of([1, 0, 0]),
    )
  })
  f("texture_3d", fn() {
    @nodes.texture3d(
      @core.Data3DTexture::new(),
      uv_node=@nodes.vec3_of([0.1, 0.2, 0.3]),
    )
  })
  f("texture_3d_load", fn() {
    @nodes.texture3d_load(
      @core.Data3DTexture::new(),
      uv_node=@nodes.ivec3_of([1, 2, 3]),
    )
  })
  f("texture_3d_float_nearest", fn() {
    let t = @core.Data3DTexture::new()
    t.type_ = @core.FloatType
    t.min_filter = @core.NearestFilter
    t.mag_filter = @core.NearestFilter
    t.wrap_r = @core.MirroredRepeatWrapping
    @nodes.texture3d(t, uv_node=@nodes.vec3(0.5)).offset(
      @nodes.ivec3_of([1, 0, 1]),
    )
  })
  f("texture_float_filtered", fn() {
    @nodes.texture(g10_float_tex(false), uv_node=@nodes.vec2(0.5))
  })
  f("texture_float_filtered_offset_level", fn() {
    @nodes.texture(g10_float_tex(false), uv_node=@nodes.vec2(0.5))
    .offset(@nodes.ivec2_of([1, 1]))
    .level(1)
  })
  f("texture_float_filtered_array", fn() {
    let t = @core.DataArrayTexture::new()
    t.type_ = @core.FloatType
    t.min_filter = @core.LinearFilter
    @nodes.texture(t, uv_node=@nodes.vec2(0.5)).depth(1)
  })
  f("texture_float_nearest", fn() {
    @nodes.texture(g10_float_tex(true), uv_node=@nodes.vec2(0.5))
  })
  f("texture_float_nearest_wrap", fn() {
    let t = g10_float_tex(true)
    t.wrap_s = @core.RepeatWrapping
    t.wrap_t = @core.MirroredRepeatWrapping
    @nodes.texture(t, uv_node=@nodes.vec2(0.5)).offset(@nodes.ivec2_of([1, 2]))
  })
  f("texture_float_nearest_shared", fn() {
    let t = g10_float_tex(true)
    @nodes.texture(t, uv_node=@nodes.vec2(0.5)).add(
      @nodes.texture(t, uv_node=@nodes.vec2(0.25)).level(1),
    )
  })
  f("texture_float_grad", fn() {
    @nodes.texture(g10_float_tex(true), uv_node=@nodes.vec2(0.5)).grad(
      @nodes.vec2(0.1),
      @nodes.vec2(0.2),
    )
  })
  f("texture_normalized_short", fn() {
    let t = g10_tex()
    t.type_ = @core.ShortType
    t.normalized = true
    @nodes.texture(t, uv_node=@nodes.vec2(0.5))
  })
  flow(
    "texture_vertex",
    fn() { @nodes.texture(g10_tex(), uv_node=@nodes.vec2(0.5)) },
    g10_stage("vertex"),
  )
  flow(
    "texture_vertex_offset_array",
    fn() {
      @nodes.texture(@core.DataArrayTexture::new(), uv_node=@nodes.vec2(0.5))
      .depth(1)
      .offset(@nodes.ivec2_of([1, 1]))
    },
    g10_stage("vertex"),
  )
  flow(
    "texture_vertex_float",
    fn() { @nodes.texture(g10_float_tex(true), uv_node=@nodes.vec2(0.5)) },
    g10_stage("vertex"),
  )
  flow(
    "texture_vertex_bias",
    fn() { @nodes.texture(g10_tex(), uv_node=@nodes.vec2(0.5)).bias(1) },
    g10_stage("vertex"),
  )
  f("texture_msaa_depth", fn() {
    let rt = @core.RenderTarget::new(
      width=4,
      height=4,
      samples=4,
      depth_texture=@core.DepthTexture::new(width=4, height=4),
    )
    @nodes.texture(rt.depth_texture().unwrap(), uv_node=@nodes.vec2(0.5))
  })
  f("texture_msaa_depth_gather", fn() {
    let rt = @core.RenderTarget::new(
      width=4,
      height=4,
      samples=4,
      depth_texture=@core.DepthTexture::new(width=4, height=4),
    )
    @nodes.texture(rt.depth_texture().unwrap(), uv_node=@nodes.vec2(0.5))
    .gather()
    .offset(@nodes.ivec2_of([1, 0]))
  })
  f("texture_msaa_color", fn() {
    let rt = @core.RenderTarget::new(width=4, height=4, samples=4)
    @nodes.texture(rt.texture(), uv_node=@nodes.vec2(0.5)).add(
      @nodes.texture(rt.texture()).size(level_node=0).x(),
    )
  })
  flow(
    "storage_texture_load",
    fn() {
      @nodes.storage_texture(
        @nodes.StorageTexture::new(width=4, height=4),
        uv_node=@nodes.uvec2_of([1, 2]),
      )
    },
    g10_stage("compute"),
  )
  flow(
    "storage_texture_store",
    fn() {
      @nodes.texture_store(
        @nodes.StorageTexture::new(width=4, height=4),
        @nodes.uvec2_of([1, 2]),
        @nodes.vec4_of([1, 0, 0, 1]),
      )
    },
    g10_stage("compute"),
  )
  f("storage_texture_rw_fragment", fn() {
    @nodes.storage_texture(
      @nodes.StorageTexture::new(width=4, height=4),
      uv_node=@nodes.uvec2_of([1, 2]),
    ).to_read_write()
  })
  flow(
    "storage_texture_formats",
    fn() {
      let a = @nodes.StorageTexture::new(width=4, height=4)
      a.type_ = @core.UnsignedByteType
      let b = @nodes.StorageTexture::new(width=4, height=4)
      b.format = @core.RedFormat
      b.type_ = @core.HalfFloatType
      let c = @nodes.StorageTexture::new(width=4, height=4)
      c.format = @core.RGIntegerFormat
      c.type_ = @core.UnsignedIntType
      @nodes.storage_texture(a, uv_node=@nodes.uvec2_of([1, 2]))
      .add(@nodes.storage_texture(b, uv_node=@nodes.uvec2_of([1, 2])).x())
      .add(
        @nodes.vec4(@nodes.storage_texture(c, uv_node=@nodes.uvec2_of([1, 2]))),
      )
    },
    g10_stage("compute"),
  )
  flow(
    "storage_texture_3d",
    fn() {
      @nodes.storage_texture3d(
        @nodes.Storage3DTexture::new(width=2, height=2, depth=2),
        uv_node=@nodes.uvec3_of([1, 1, 1]),
      )
    },
    g10_stage("compute"),
  )
  flow(
    "storage_texture_array",
    fn() {
      @nodes.storage_texture(
        @nodes.StorageArrayTexture::new(width=2, height=2, depth=2),
        uv_node=@nodes.uvec2_of([1, 1]),
      ).depth(1)
    },
    g10_stage("compute"),
  )

  // --- Storage buffers, atomics, workgroup memory
  flow(
    "storage_read",
    fn() {
      @nodes.storage(g10_float_buffer(16, 4), type_="vec4", count=16).element(
        @nodes.instance_index,
      )
    },
    g10_stage("compute"),
  )
  flow(
    "storage_read_only",
    fn() {
      @nodes.storage(g10_float_buffer(16, 4), type_="vec4", count=16)
      .to_read_only()
      .element(@nodes.instance_index)
    },
    g10_stage("compute"),
  )
  flow(
    "storage_vertex",
    fn() {
      @nodes.storage(g10_float_buffer(16, 3), type_="vec3", count=16).element(
        @nodes.instance_index,
      )
    },
    g10_stage("vertex"),
  )
  f("storage_fragment", fn() {
    @nodes.storage(g10_float_buffer(16, 1), type_="float", count=16).element(
      g10_iv(2),
    )
  })
  flow(
    "storage_atomic",
    fn() {
      @nodes.atomic_add(
        @nodes.storage(g10_uint_buffer(4), type_="uint", count=4)
        .to_atomic()
        .element(0),
        1,
      )
    },
    g10_stage("compute"),
  )
  f("storage_atomic_fragment", fn() {
    @nodes.atomic_add(
      @nodes.storage(g10_uint_buffer(4), type_="uint", count=4)
      .to_atomic()
      .element(1),
      2,
    )
  })
  flow(
    "storage_atomic_vertex",
    fn() {
      @nodes.atomic_load(
        @nodes.storage(g10_uint_buffer(4), type_="uint", count=4)
        .to_atomic()
        .element(1),
      )
    },
    g10_stage("vertex"),
  )
  flow(
    "workgroup_array",
    fn() {
      @nodes.workgroup_array("float", count=64)
      .set_name("wgFloats")
      .element(@nodes.invocation_local_index)
    },
    g10_stage("compute"),
  )
  flow(
    "workgroup_atomic",
    fn() {
      @nodes.atomic_add(
        @nodes.workgroup_array("uint", count=8)
        .set_name("wgCounters")
        .to_atomic()
        .element(@nodes.uint(0)),
        1,
      )
    },
    g10_stage("compute"),
  )
  flow(
    "barrier",
    fn() {
      g10_fn(fn() {
        let r = g10_fv(1)
        @nodes.workgroup_barrier()
        r
      })
    },
    g10_stage("compute"),
  )

  // --- Varyings and attributes (mesh)
  let mesh = { ..g10_default, mesh: true, }
  flow(
    "varying",
    fn() { @nodes.varying(@nodes.position_local.mul(2)).x() },
    mesh,
  )
  flow(
    "varying_flat",
    fn() {
      @nodes.varying(@nodes.position_local.mul(3), name="vFlat").set_interpolation(
        "flat",
        sampling="first",
      )
    },
    mesh,
  )
  flow(
    "varying_sampling",
    fn() {
      @nodes.varying(@nodes.position_local, name="vPos")
      .set_interpolation("perspective", sampling="centroid")
      .add(@nodes.varying(@nodes.normal_local).set_interpolation("linear"))
    },
    mesh,
  )
  flow(
    "varying_uint",
    fn() { @nodes.float(@nodes.varying(@nodes.vertex_index)) },
    mesh,
  )
  flow(
    "attribute",
    fn() {
      @nodes.attribute("uv", node_type="vec2").add(
        @nodes.position_geometry.xy(),
      )
    },
    { ..mesh, stage: "vertex", },
  )
  flow("uv_fragment", fn() { @nodes.uv() }, mesh)

  // --- Representative g1/g2 graphs through WGSL
  f("g1_op_add_variadic", fn() { @nodes.add_of([g10_fv(1), 2, g10_fv(3), 4]) })
  f("g1_op_div_int_int", fn() { g10_iv(4).div(g10_iv(2)) })
  f("g1_op_mul_uint_negative", fn() { g10_uv(3).mul(-2) })
  f("g1_op_not_equal_vec3", fn() { g10_v3().not_equal(g10_v3()) })
  f("g1_op_and_bvec", fn() {
    @nodes.bvec2_of([true, false])
    .to_var()
    .and_(@nodes.bvec2_of([false, true]).to_var())
  })
  f("g1_op_bit_not", fn() { g10_iv(6).bit_not() })
  f("g1_op_shift_right_uvec", fn() {
    @nodes.uvec3_of([8, 16, 32]).to_var().shift_right(2)
  })
  f("g1_op_mat3_vec3", fn() { g10_m3().mul(g10_v3()) })
  f("g1_op_assign_ops", fn() {
    g10_fn(fn() {
      let v = g10_fv(1)
      v.add_assign(2)
      v.mul_assign(3)
      v.mod_assign(5)
      let i = g10_iv(3)
      i.bit_xor_assign(7)
      i.shift_left_assign(1)
      v.add(@nodes.float(i))
    })
  })
  f("g1_op_increment", fn() {
    g10_fn(fn() {
      let i = g10_iv(0)
      i.increment()
      i.decrement_before()
      i
    })
  })
  f("g1_math_one_vec3", fn() {
    g10_v3()
    .normalize()
    .add(g10_v3().fract())
    .add(g10_v3().saturate())
    .add(g10_v3().one_minus())
    .add(g10_v3().cbrt())
  })
  f("g1_math_atan2", fn() { @nodes.atan(g10_fv(1), x=g10_fv(2)) })
  f("g1_math_mix_vec3", fn() {
    @nodes.mix(g10_v3(), @nodes.vec3(0), g10_fv(0.5))
  })
  f("g1_math_clamp_int", fn() { g10_iv(3).clamp(low=g10_iv(0), high=2) })
  f("g1_math_transpose_det", fn() {
    g10_m3().transpose().mul(g10_m3().determinant())
  })
  f("g1_math_rand", fn() { @nodes.rand.call([g10_v2()]) })
  f("g1_math_constants", fn() {
    @nodes.vec4_of([@nodes.pi, @nodes.two_pi, @nodes.half_pi, @nodes.epsilon]).add(
      @nodes.infinity,
    )
  })
  f("g1_cond_select_vec", fn() {
    @nodes.select(g10_fv(1).greater_than(0), g10_v3(), else_node=@nodes.vec3(1)).add(
      g10_fv(1).greater_than(0).select(1, else_node=2),
    )
  })
  f("g1_hash", fn() { @nodes.hash_tsl.call([g10_uv(3)]) })
  f("g1_remap", fn() {
    @nodes.remap
    .call([g10_fv(0.5), 0, 1, 2, 4])
    .add(@nodes.remap_clamp(g10_fv(0.5), 0, 1, out_low_node=2, out_high_node=4))
  })
  f("g1_rotate", fn() { @nodes.rotate(g10_v2(), g10_fv(0.5)) })
  f("g1_checker", fn() { @nodes.checker.call([g10_v2()]) })
  f("g1_tri_noise", fn() { @nodes.tri_noise3d.call([g10_v3(), 1, g10_fv(0)]) })
  f("g1_oscillators", fn() {
    @nodes.osc_sine(t=g10_fv(0.5))
    .add(@nodes.osc_square(t=g10_fv(0.5)))
    .add(@nodes.osc_triangle(t=g10_fv(0.5)))
    .add(@nodes.osc_sawtooth(t=g10_fv(0.5)))
  })
  f("g1_packing_normals", fn() {
    @nodes.pack_normal_to_rgb(g10_v3()).add(
      @nodes.unpack_rgb_to_normal(g10_v3()),
    )
  })
  let mesh_ctx = { ..mesh, ctx: true, }
  flow("g2_position_view", fn() { @nodes.position_view }, mesh_ctx)
  flow("g2_normal_view", fn() { @nodes.normal_view }, mesh_ctx)
  flow(
    "g2_model_matrices",
    fn() {
      @nodes.model_world_matrix
      .mul(@nodes.vec4_of([@nodes.position_local, 1]))
      .add(@nodes.model_normal_matrix.mul(@nodes.normal_local).xyzz())
    },
    { ..mesh, stage: "vertex", },
  )
  flow(
    "g2_camera",
    fn() {
      @nodes.camera_projection_matrix
      .mul(@nodes.camera_view_matrix)
      .mul(@nodes.vec4_of([@nodes.camera_position, 1]))
    },
    mesh,
  )
  flow("g2_uv1", fn() { @nodes.uv(index=1) }, mesh)
  flow("g2_texture_uv_default", fn() { @nodes.texture(g10_tex()).rgb() }, mesh)

  // --- Whole compute shaders
  compute_build(
    "compute_basic",
    fn() {
      let buf = @nodes.storage(g10_float_buffer(64, 1), type_="float", count=64)
      @nodes.compute(
        g10_fn_unit(fn() {
          buf
          .element(@nodes.instance_index)
          .assign(@nodes.float(@nodes.instance_index).mul(2))
        }),
        64,
      )
    },
    "a",
  )
  compute_build(
    "compute_workgroup_2d",
    fn() {
      let buf = @nodes.storage(g10_float_buffer(64, 4), type_="vec4", count=64)
      let scale = @nodes.uniform(2)
      let shared = @nodes.workgroup_array("float", count=64).set_name("shared")
      @nodes.compute(
        g10_fn_unit(fn() {
          shared.element(@nodes.invocation_local_index).assign(scale)
          @nodes.workgroup_barrier()
          buf
          .element(@nodes.instance_index)
          .assign(@nodes.vec4(shared.element(@nodes.uint(0))))
        }),
        64,
        workgroup_size=[8, 8],
      )
    },
    "a",
  )
  compute_build(
    "compute_atomic",
    fn() {
      let counter = @nodes.storage(g10_uint_buffer(1), type_="uint", count=1).to_atomic()
      @nodes.compute(
        g10_fn_unit(fn() { @nodes.atomic_add(counter.element(0), 1) |> ignore }),
        16,
        workgroup_size=[16],
      )
    },
    "a",
  )
  compute_build(
    "compute_subgroups",
    fn() {
      let buf = @nodes.storage(g10_float_buffer(32, 1), type_="float", count=32)
      @nodes.compute(
        g10_fn_unit(fn() {
          buf
          .element(@nodes.instance_index)
          .assign(
            @nodes.subgroup_add(@nodes.float(@nodes.invocation_subgroup_index)),
          )
        }),
        32,
        workgroup_size=[32],
      )
    },
    "b",
  )
  compute_build(
    "compute_texture_store",
    fn() {
      let t = @nodes.StorageTexture::new(width=8, height=8)
      @nodes.compute(
        g10_fn_unit(fn() {
          @nodes.texture_store(
            t,
            @nodes.global_id.xy(),
            @nodes.vec4_of([1, 0, 0, 1]),
          ).to_write_only()
          |> ignore
        }),
        64,
        workgroup_size=[8, 8, 1],
      )
    },
    "a",
  )
  compute_build(
    "compute_uniforms_texture",
    fn() {
      let buf = @nodes.storage(g10_float_buffer(16, 4), type_="vec4", count=16)
      let a = @nodes.uniform(1)
      let b = @nodes.uniform(@math.Vector3::new(1, 2, 3)).set_group(
        @nodes.render_group,
      )
      @nodes.compute(
        g10_fn_unit(fn() {
          let c = @nodes.texture(g10_tex(), uv_node=@nodes.vec2(0.5))
            .mul(a)
            .add(@nodes.vec4_of([b, 1]))
          buf.element(@nodes.instance_index).assign(c)
        }),
        16,
      )
    },
    "a",
  )
  compute_build(
    "compute_layout_fn",
    fn() {
      let buf = @nodes.storage(g10_float_buffer(16, 1), type_="float", count=16)
      let sq = @nodes.fn_(fn(inputs, _) {
        let x = inputs.get(0).unwrap()
        Some(x.mul(x).mod(3))
      }).set_layout(name="sq", type_="float", inputs=[("x", "float")])
      @nodes.compute(
        g10_fn_unit(fn() {
          buf
          .element(@nodes.instance_index)
          .assign(sq.call([@nodes.float(@nodes.instance_index)]))
        }),
        16,
      )
    },
    "a",
  )
  compute_build(
    "compute_local_vars",
    fn() {
      let buf = @nodes.storage(g10_float_buffer(16, 1), type_="float", count=16)
      @nodes.compute(
        g10_fn_unit(fn() {
          let v = @nodes.float(1).to_var()
          @nodes.workgroup_barrier()
          v.add_assign(1)
          buf.element(@nodes.instance_index).assign(v)
        }),
        16,
      )
    },
    "a",
  )

  // --- Whole materials (NodeMaterial.build stand-in)
  let mvp = fn() {
    @nodes.camera_projection_matrix
    .mul(@nodes.model_view_matrix)
    .mul(@nodes.vec4_of([@nodes.position_local, 1]))
  }
  material_build(
    "material_basic",
    mvp,
    fn() { @nodes.vec4_of([@nodes.uv(), 0, 1]) },
    None,
  )
  material_build(
    "material_vec3_output",
    mvp,
    fn() { @nodes.vec3_of([1, 0, 0]) },
    None,
  )
  material_build(
    "material_uniform_texture",
    mvp,
    fn() {
      @nodes.texture(g10_tex(), uv_node=@nodes.uv())
      .mul(@nodes.uniform(@math.Color::new(0.5, 0.25, 1)))
      .add(@nodes.texture(g10_float_tex(true), uv_node=@nodes.uv()))
    },
    None,
  )
  material_build(
    "material_sampler_comparison",
    mvp,
    fn() {
      @nodes.vec4_of([
        @nodes.texture(
          @core.DepthTexture::new(width=4, height=4),
          uv_node=@nodes.uv(),
        ).compare(0.5),
        0,
        0,
        1,
      ])
    },
    None,
  )
  material_build(
    "material_output_struct",
    mvp,
    fn() {
      @nodes.output_struct([@nodes.vec4(1), @nodes.vec4_of([@nodes.uv(), 0, 1])])
    },
    None,
  )
  material_build(
    "material_frag_depth",
    mvp,
    fn() {
      g10_fn(fn() {
        @nodes.depth.assign(0.5)
        @nodes.vec4(1)
      })
    },
    None,
  )
  material_build(
    "material_varyings",
    mvp,
    fn() {
      @nodes.vec4_of([
        @nodes.varying(@nodes.position_local).add(
          @nodes.varying(@nodes.normal_local, name="vFlat").set_interpolation(
            "flat",
          ),
        ),
        @nodes.float(@nodes.front_facing),
      ]).add(@nodes.vec4_of([@nodes.screen_coordinate, 0, 0]))
    },
    None,
  )
  material_build(
    "material_invariant",
    mvp,
    fn() { @nodes.vec4(1) },
    Some(fn(b) { b.context.set("invariant", Bool(true)) }),
  )
  material_build(
    "material_storage_vertex",
    fn() {
      let buf = @nodes.storage(g10_float_buffer(16, 3), type_="vec3", count=16).to_read_only()
      @nodes.camera_projection_matrix
      .mul(@nodes.model_view_matrix)
      .mul(
        @nodes.vec4_of([
          @nodes.position_local.add(buf.element(@nodes.instance_index)),
          1,
        ]),
      )
    },
    fn() { @nodes.vec4(@nodes.float(@nodes.varying(@nodes.vertex_index))) },
    None,
  )
  material_build(
    "material_layout_fn",
    mvp,
    fn() {
      let tint = @nodes.fn_(fn(inputs, _) {
        let c = inputs.get(0).unwrap()
        Some(c.mul(2).mod(1))
      }).set_layout(name="tint", type_="vec3", inputs=[("c", "vec3")])
      @nodes.vec4_of([tint.call([@nodes.vec3_of([@nodes.uv(), 1])]), 1])
    },
    None,
  )
  scenarios
}

///|
fn g10_default_scenario(name : String) -> G10Scenario {
  {
    name: "g10_" + name,
    kind: Flow(fn() { @nodes.float(0) }),
    stage: "fragment",
    renderer: "a",
    mesh: false,
    ctx: false,
    pre: None,
  }
}

// ---------------------------------------------------------------------------
// G10 only.

///|
priv enum G10ExtraKind {
  ExtraFlow(() -> @nodes.Node)
  ExtraCompute(() -> @nodes.Node)
  ExtraMaterial(() -> @core.Object3D, () -> @nodes.Node, () -> @nodes.Node)
  Whole(() -> @core.Material, (@core.Material) -> @core.Object3D)
}

///|
priv struct G10Extra {
  name : String
  kind : G10ExtraKind
  stage : String
  renderer : String
  mesh : Bool
  pre : ((@nodes.NodeBuilder) -> Unit)?
  geometry : @core.BufferGeometry?
  decl_compute : Bool
  lights : () -> Array[@core.Object3D]
  fog : Bool
  logarithmic : Bool
  clipping : String
}

///|
let g10_extra_default : G10Extra = {
  name: "",
  kind: ExtraFlow(fn() { @nodes.float(0) }),
  stage: "fragment",
  renderer: "a",
  mesh: false,
  pre: None,
  geometry: None,
  decl_compute: false,
  lights: fn() { [] },
  fog: false,
  logarithmic: false,
  clipping: "",
}

///|
fn g10_int_geometry() -> @core.BufferGeometry {
  let g = @core.BufferGeometry::new()
  g.set_attribute("position", g10_attribute(24, 3)) |> ignore
  g.set_attribute(
    "ids",
    @core.GeometryAttribute::Buffer(
      @core.BufferAttribute::new(@core.TypedArray::int16(24 * 2), 2),
    ),
  )
  |> ignore
  g.set_attribute(
    "ids32",
    @core.GeometryAttribute::Buffer(
      @core.BufferAttribute::new(@core.TypedArray::int32(24), 1),
    ),
  )
  |> ignore
  let gpu_int = @core.BufferAttribute::new(@core.TypedArray::uint16(24), 1)
  gpu_int.gpu_type = @core.IntType
  g.set_attribute("idsGpu", @core.GeometryAttribute::Buffer(gpu_int)) |> ignore
  g
}

///|
fn g10_batched(material : @core.Material) -> @core.Object3D {
  @core.BatchedMesh::new(4, 64, max_index_count=64, material=Single(material))
}

///|
fn g10_mvp() -> @nodes.Node {
  @nodes.camera_projection_matrix
  .mul(@nodes.model_view_matrix)
  .mul(@nodes.vec4_of([@nodes.position_local, 1]))
}

///|
fn g10_extras() -> Array[G10Extra] {
  let s : Array[G10Extra] = []
  let d = g10_extra_default
  let flow = fn(name : String, make : () -> @nodes.Node, opts : G10Extra) {
    s.push({ ..opts, name: "g10_" + name, kind: ExtraFlow(make), })
  }
  let f = fn(name : String, make : () -> @nodes.Node) { flow(name, make, d) }
  let vertex = { ..d, stage: "vertex", }
  let mesh = { ..d, mesh: true, }
  let int_geometry = g10_int_geometry()
  flow("glsl_draw_index_multi_draw", fn() { @nodes.float(@nodes.draw_index) }, {
    ..vertex,
    mesh: true,
  })
  flow("glsl_draw_index_uniform", fn() { @nodes.float(@nodes.draw_index) }, {
    ..vertex,
    mesh: true,
    renderer: "b",
  })
  flow("glsl_multiview", fn() { g10_fv(1) }, {
    ..vertex,
    pre: Some(fn(b) { b.enable_multiview() }),
  })
  flow("glsl_multiview_fragment", fn() { g10_fv(1) }, {
    ..d,
    pre: Some(fn(b) { b.enable_multiview() }),
  })
  flow("glsl_hardware_clipping_two", fn() { g10_fv(1) }, {
    ..vertex,
    renderer: "c",
    pre: Some(fn(b) { b.enable_hardware_clipping(2) }),
  })
  f("glsl_vector_select_int", fn() {
    @nodes.select(
      @nodes.bvec2_of([true, false]).to_var(),
      @nodes.ivec2_of([1, 2]).to_var(),
      else_node=@nodes.ivec2_of([3, 4]).to_var(),
    )
  })
  f("glsl_vector_select_bool", fn() {
    @nodes.select(
      @nodes.bvec2_of([true, false]).to_var(),
      @nodes.bvec2_of([false, true]).to_var(),
      else_node=@nodes.bvec2_of([true, true]).to_var(),
    )
  })
  f("glsl_vector_select_float", fn() {
    @nodes.select(
      @nodes.bvec2_of([true, false]).to_var(),
      g10_v2(),
      else_node=@nodes.vec2_of([3, 4]).to_var(),
    )
  })
  let depth_tex = fn() { @core.DepthTexture::new(width=4, height=4) }
  let half = fn() { @nodes.vec2(0.5) }
  flow(
    "glsl_texture_compare_vertex",
    fn() { @nodes.texture(depth_tex(), uv_node=half()).compare(0.25) },
    vertex,
  )
  f("glsl_texture_compare_offset", fn() {
    @nodes.texture(depth_tex(), uv_node=half())
    .compare(0.25)
    .offset(@nodes.ivec2_of([1, 0]))
  })
  flow(
    "glsl_ternary_uniform_flow",
    fn() {
      @nodes.select(g10_fv(1).greater_than(0), g10_fv(2), else_node=g10_fv(3))
    },
    { ..d, pre: Some(fn(b) { b.context.set("uniformFlow", Bool(true)) }), },
  )
  f("glsl_texture_compare_array", fn() {
    let t = @core.DepthTexture::new(width=4, height=4, depth=2)
    t.compare_function = Some(@core.LessCompare)
    let s = @core.DepthTexture::new(width=4, height=4)
    s.compare_function = Some(@core.LessCompare)
    @nodes.texture(t, uv_node=half())
    .depth(1)
    .compare(0.25)
    .add(@nodes.texture(s, uv_node=half()).compare(0.5))
  })
  f("glsl_texture_gather_array", fn() {
    @nodes.texture(@core.DataArrayTexture::new(), uv_node=half())
    .depth(1)
    .gather()
  })
  f("glsl_texture_gather_offset", fn() {
    @nodes.texture(g10_tex(), uv_node=half())
    .gather(gather_node=1)
    .offset(@nodes.ivec2_of([1, 1]))
  })
  f("glsl_texture_gather_depth", fn() {
    @nodes.texture(depth_tex(), uv_node=half()).gather()
  })
  f("glsl_texture_load_offset", fn() {
    @nodes.texture_load(g10_tex(), uv_node=@nodes.ivec2_of([1, 2])).offset(
      @nodes.ivec2_of([1, 1]),
    )
  })
  f("glsl_texture_load_array", fn() {
    @nodes.texture_load(
      @core.DataArrayTexture::new(),
      uv_node=@nodes.ivec2_of([1, 2]),
    ).depth(1)
  })
  f("glsl_texture_load_array_offset", fn() {
    @nodes.texture_load(
      @core.DataArrayTexture::new(),
      uv_node=@nodes.ivec2_of([1, 2]),
    )
    .depth(1)
    .offset(@nodes.ivec2_of([1, 0]))
  })
  f("glsl_texture_load_depth", fn() {
    @nodes.texture_load(depth_tex(), uv_node=@nodes.ivec2_of([1, 2]))
  })
  f("glsl_texture_bias_offset", fn() {
    @nodes.texture(g10_tex(), uv_node=half())
    .bias(0.5)
    .offset(@nodes.ivec2_of([1, 1]))
  })
  f("glsl_texture_grad_offset", fn() {
    @nodes.texture(g10_tex(), uv_node=half())
    .grad(@nodes.vec2(0.1), @nodes.vec2(0.2))
    .offset(@nodes.ivec2_of([1, 1]))
  })
  f("glsl_texture_grad_array", fn() {
    @nodes.texture(@core.DataArrayTexture::new(), uv_node=half())
    .depth(1)
    .grad(@nodes.vec2(0.1), @nodes.vec2(0.2))
  })
  f("glsl_texture_level_depth", fn() {
    @nodes.texture(depth_tex(), uv_node=half()).level(1)
  })
  f("glsl_texture_level_depth_offset", fn() {
    @nodes.texture(depth_tex(), uv_node=half())
    .level(1)
    .offset(@nodes.ivec2_of([1, 1]))
  })
  f("glsl_texture_depth_offset", fn() {
    @nodes.texture(depth_tex(), uv_node=half()).offset(@nodes.ivec2_of([1, 1]))
  })
  f("glsl_texture_3d_level", fn() {
    @nodes.texture3d(@core.Data3DTexture::new(), uv_node=@nodes.vec3(0.5)).level(
      1,
    )
  })
  f("glsl_texture_uint_array", fn() {
    let t = @core.DataArrayTexture::new()
    t.type_ = @core.UnsignedIntType
    t.format = @core.RGBAIntegerFormat
    @nodes.texture(t, uv_node=half()).depth(1)
  })
  f("glsl_texture_int_3d", fn() {
    let t = @core.Data3DTexture::new()
    t.type_ = @core.IntType
    @nodes.texture3d(t, uv_node=@nodes.vec3(0.5))
  })
  f("glsl_texture_precision", fn() {
    @nodes.texture(g10_tex(), uv_node=half())
    .set_precision(Some("low"))
    .add(
      @nodes.cube_texture(
        @core.CubeTexture::new(),
        uv_node=@nodes.vec3_of([0, 1, 0]),
      ).set_precision(Some("medium")),
    )
  })
  f("glsl_uniform_precision", fn() {
    @nodes.uniform(1)
    .set_precision(Some("medium"))
    .add(
      @nodes.uniform(@math.Vector3::new(1, 2, 3))
      .set_precision(Some("high"))
      .x(),
    )
    .add(
      @nodes.uniform(2)
      .set_precision(Some("low"))
      .set_group(@nodes.render_group),
    )
  })
  flow(
    "glsl_uniforms_shared_stages",
    fn() {
      @nodes.uniform(1)
      .set_name("shared")
      .add(@nodes.varying(@nodes.uniform(2).set_name("vtx")))
    },
    mesh,
  )
  f("glsl_uniform_mat3_vec2", fn() {
    @nodes.uniform(@math.Matrix3::new())
    .mul(@nodes.vec3(1))
    .xy()
    .add(@nodes.uniform(@math.Vector2::new(1, 2)))
    .add(@nodes.uniform(@math.Vector4::new(1, 2, 3, 4)).xy())
  })
  f("glsl_bitcast_int_uint", fn() {
    @nodes.float(@nodes.bitcast(g10_iv(1), "uint")).add(
      @nodes.float(@nodes.bitcast(g10_uv(2), "int")),
    )
  })
  f("glsl_bitcast_vec", fn() {
    @nodes.bitcast(@nodes.ivec2_of([1, 2]).to_var(), "vec2").add(
      @nodes.vec2(@nodes.bitcast(g10_v2(), "uvec2")),
    )
  })
  f("glsl_unpacking_4x8", fn() {
    @nodes.unpack_snorm4x8(g10_uv(5))
    .add(@nodes.unpack_unorm4x8(g10_uv(6)))
    .add(@nodes.float(@nodes.pack_snorm4x8(g10_v4())))
  })
  f("glsl_unpacking_2x16", fn() {
    @nodes.vec4_of([
      @nodes.unpack_snorm2x16(g10_uv(5)),
      @nodes.unpack_unorm2x16(g10_uv(6)),
    ]).add(@nodes.float(@nodes.pack_half2x16(g10_v2())))
  })
  flow(
    "glsl_int_attribute",
    fn() {
      @nodes.vec2(@nodes.attribute("ids", node_type="ivec2"))
      .add(@nodes.float(@nodes.attribute("ids32", node_type="int")))
      .add(@nodes.float(@nodes.attribute("idsGpu", node_type="int")))
    },
    { ..vertex, mesh: true, geometry: Some(int_geometry), },
  )
  flow(
    "glsl_varying_int_flat",
    fn() {
      @nodes.float(@nodes.varying(@nodes.int(@nodes.vertex_index))).add(
        @nodes.vec2(@nodes.varying(@nodes.ivec2_of([1, 2]))).x(),
      )
    },
    mesh,
  )
  flow(
    "glsl_varying_sampling_compute",
    fn() {
      @nodes.varying(@nodes.position_local, name="vPosC").set_interpolation(
        "linear",
        sampling="centroid",
      )
    },
    { ..mesh, decl_compute: true, },
  )
  f("glsl_struct_array", fn() {
    let st = @nodes.struct_(
      [
        @nodes.StructMember::new("a", "float"),
        @nodes.StructMember::new("b", "vec2"),
        @nodes.StructMember::new("c", "ivec3"),
      ],
      name="GStruct",
    )
    st.call([g10_fv(1), g10_v2(), @nodes.ivec3_of([1, 2, 3])]).to_var().get("b")
  })
  f("glsl_mrt_output", fn() {
    @nodes.output_struct([@nodes.vec4(1), @nodes.vec4(0.5), @nodes.vec4(0.25)])
  })
  flow(
    "glsl_reserved_glsl",
    fn() {
      @nodes.float(1)
      .to_var(name="input")
      .add(@nodes.float(2).to_var(name="sample"))
      .add(@nodes.float(3).to_var(name="filter"))
    },
    { ..d, renderer: "d", },
  )
  f("glsl_storage_pbo_vec4", fn() {
    @nodes.storage(g10_float_buffer(16, 4), type_="vec4", count=16)
    .set_pbo(true)
    .element(g10_iv(3))
  })
  f("glsl_storage_pbo_uint", fn() {
    @nodes.storage(g10_uint_buffer(10), type_="uint", count=10)
    .set_pbo(true)
    .element(g10_iv(1))
    .add(
      @nodes.storage(g10_uint_buffer(10), type_="uint", count=10)
      .set_pbo(true)
      .element(g10_iv(2)),
    )
  })
  flow(
    "glsl_storage_pbo_vec3_vertex",
    fn() {
      @nodes.storage(g10_float_buffer(7, 3), type_="vec3", count=7)
      .set_pbo(true)
      .element(@nodes.instance_index)
    },
    vertex,
  )
  f("glsl_storage_pbo_int16", fn() {
    @nodes.storage(
      @nodes.StorageBufferAttribute::from_array(@core.TypedArray::int16(6), 2),
      type_="ivec2",
      count=3,
    )
    .set_pbo(true)
    .element(g10_iv(1))
  })
  let compute = fn(name : String, make : () -> @nodes.Node) {
    s.push({ ..d, name: "g10_" + name, kind: ExtraCompute(make), })
  }
  compute("glsl_compute_two_buffers", fn() {
    let a = @nodes.storage(g10_float_buffer(32, 1), type_="float", count=32)
    let b = @nodes.storage(g10_float_buffer(32, 4), type_="vec4", count=32)
    let k = @nodes.uniform(3)
    @nodes.compute(
      g10_fn_unit(fn() {
        a
        .element(@nodes.instance_index)
        .assign(@nodes.float(@nodes.instance_index).mul(k))
        b
        .element(@nodes.instance_index)
        .assign(@nodes.vec4(a.element(@nodes.instance_index)))
      }),
      32,
    )
  })
  compute("glsl_compute_local_index", fn() {
    let a = @nodes.storage(g10_float_buffer(64, 1), type_="float", count=64)
    @nodes.compute(
      g10_fn_unit(fn() {
        a
        .element(@nodes.instance_index)
        .assign(@nodes.float(@nodes.invocation_local_index))
      }),
      64,
      workgroup_size=[8, 2],
    )
  })
  compute("glsl_compute_pbo_read", fn() {
    let src = @nodes.storage(g10_float_buffer(16, 1), type_="float", count=16).set_pbo(
      true,
    )
    let dst = @nodes.storage(g10_float_buffer(16, 1), type_="float", count=16)
    @nodes.compute(
      g10_fn_unit(fn() {
        dst
        .element(@nodes.instance_index)
        .assign(src.element(@nodes.instance_index.add(1)))
      }),
      16,
    )
  })
  let material = fn(
    name : String,
    object : (() -> @core.Object3D)?,
    fragment : () -> @nodes.Node,
    opts : G10Extra,
  ) {
    let object = match object {
      Some(o) => o
      None =>
        fn() {
          @core.Mesh::new(
            geometry=g10_geometry,
            material=Single(@core.MeshBasicMaterial::new()),
          )
        }
    }
    s.push({
      ..opts,
      name: "g10_" + name,
      kind: ExtraMaterial(object, g10_mvp, fragment),
    })
  }
  let batched_object = fn() { g10_batched(@core.MeshBasicMaterial::new()) }
  material(
    "glsl_material_batched_multi_draw",
    Some(batched_object),
    fn() { @nodes.vec4(@nodes.float(@nodes.draw_index)) },
    d,
  )
  material(
    "glsl_material_batched_uniform",
    Some(batched_object),
    fn() { @nodes.vec4(@nodes.float(@nodes.draw_index)) },
    { ..d, renderer: "b", },
  )
  material(
    "glsl_material_mrt",
    None,
    fn() {
      @nodes.output_struct([@nodes.vec4(1), @nodes.vec4_of([@nodes.uv(), 0, 1])])
    },
    d,
  )
  material(
    "glsl_material_frag_depth_uniform",
    None,
    fn() {
      g10_fn(fn() {
        @nodes.depth.assign(@nodes.uniform(0.5))
        @nodes.texture(g10_tex(), uv_node=@nodes.uv())
      })
    },
    d,
  )
  material("glsl_material_multiview", None, fn() { @nodes.vec4(1) }, {
    ..d,
    pre: Some(fn(b) { b.enable_multiview() }),
  })
  material("glsl_material_hw_clipping", None, fn() { @nodes.vec4(1) }, {
    ..d,
    renderer: "c",
    pre: Some(fn(b) { b.enable_hardware_clipping(3) }),
  })
  g10_wholes(s)
  s
}

///|
fn g10_wattr(n : Int32, item_size : Int32) -> @core.GeometryAttribute {
  g10_attribute(n, item_size)
}

///|
fn g10_wgeometry(
  n : Int32,
  attributes : Array[(String, Int32)],
) -> @core.BufferGeometry {
  let g = @core.BufferGeometry::new()
  for a in attributes {
    g.set_attribute(a.0, g10_wattr(n, a.1)) |> ignore
  }
  g
}

///|
fn g10_point() -> @core.Object3D {
  @core.PointLight::new(
    color=@math.Color::from_hex(0xff0000),
    intensity=2,
    distance=10,
    decay=2,
  )
}

///|
fn g10_directional() -> @core.Object3D {
  @core.DirectionalLight::new(
    color=@math.Color::from_hex(0x00ff00),
    intensity=3,
  )
}

///|
fn g10_set(
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
/// The whole-material scenarios (`g10_mat_*`).
fn g10_wholes(s : Array[G10Extra]) -> Unit {
  let wgeometry = g10_wgeometry(24, [
    ("position", 3),
    ("normal", 3),
    ("uv", 2),
    ("color", 4),
  ])
  let line_geometry = g10_wgeometry(4, [("position", 3), ("lineDistance", 1)])
  let line2_geometry = g10_wgeometry(8, [
    ("position", 3),
    ("uv", 2),
    ("instanceStart", 3),
    ("instanceEnd", 3),
    ("instanceDistanceStart", 1),
    ("instanceDistanceEnd", 1),
  ])
  let mesh = fn(m : @core.Material) {
    @core.Mesh::new(geometry=wgeometry, material=Single(m))
  }
  let d = { ..g10_extra_default, lights: fn() { [] }, }
  let whole = fn(
    name : String,
    material : () -> @core.Material,
    opts : G10Extra,
    object : ((@core.Material) -> @core.Object3D)?,
  ) {
    s.push({
      ..opts,
      name: "g10_mat_" + name,
      kind: Whole(material, object.unwrap_or(mesh)),
    })
  }
  let wtex = fn(name : String) {
    let t = @core.Texture::new()
    t.name = name
    t
  }
  let lit = { ..d, lights: fn() { [g10_point()] }, }
  let basic = @nodes.MeshBasicNodeMaterial::new
  whole("node_material", @nodes.NodeMaterial::new, d, None)
  whole("basic", basic, d, None)
  whole(
    "basic_map_alpha_test",
    g10_set(basic, fn(m) {
      m.map = Some(wtex("map"))
      m.set_alpha_test(0.5)
    }),
    d,
    None,
  )
  whole(
    "basic_transparent_fog",
    g10_set(basic, fn(m) {
      m.transparent = true
      m.premultiplied_alpha = true
    }),
    { ..d, fog: true, },
    None,
  )
  whole(
    "basic_vertex_colors_nodes",
    g10_set(basic, fn(m) {
      m.vertex_colors = true
      let nm = @nodes.NodeMaterial::of(m).unwrap()
      nm.color_node = Some(@nodes.vec3_of([1, 0.5, 0]))
      nm.position_node = Some(@nodes.position_local.mul(2))
    }),
    d,
    None,
  )
  whole("basic_log_depth", basic, { ..d, logarithmic: true, }, None)
  whole("lambert", @nodes.MeshLambertNodeMaterial::new, lit, None)
  whole("phong", @nodes.MeshPhongNodeMaterial::new, lit, None)
  whole("standard", @nodes.MeshStandardNodeMaterial::new, lit, None)
  whole(
    "standard_maps",
    g10_set(@nodes.MeshStandardNodeMaterial::new, fn(m) {
      m.map = Some(wtex("map"))
      m.roughness_map = Some(wtex("rough"))
      m.normal_map = Some(wtex("normal"))
    }),
    { ..d, lights: fn() { [g10_point(), g10_directional()] }, },
    None,
  )
  whole("physical", @nodes.MeshPhysicalNodeMaterial::new, lit, None)
  whole(
    "physical_clearcoat_sheen",
    g10_set(@nodes.MeshPhysicalNodeMaterial::new, fn(m) {
      m.set_clearcoat(1)
      m.set_sheen(1)
      m.set_iridescence(1)
    }),
    lit,
    None,
  )
  whole(
    "sss",
    g10_set(@nodes.MeshSSSNodeMaterial::new, fn(m) {
      @nodes.MeshSSSNodeMaterial::of(m).unwrap().thickness_color_node = Some(
        @nodes.vec3_of([0.5, 0.1, 0.1]),
      )
    }),
    lit,
    None,
  )
  whole("toon", @nodes.MeshToonNodeMaterial::new, lit, None)
  whole("matcap", @nodes.MeshMatcapNodeMaterial::new, d, None)
  whole("normal", @nodes.MeshNormalNodeMaterial::new, d, None)
  whole(
    "shadow",
    @nodes.ShadowNodeMaterial::new,
    { ..d, lights: fn() { [g10_directional()] }, },
    None,
  )
  whole("volume", @nodes.VolumeNodeMaterial::new, lit, None)
  let line = fn(m : @core.Material) {
    @core.Line::new(geometry=line_geometry, material=Single(m))
  }
  let line2 = fn(m : @core.Material) {
    @core.Mesh::new(geometry=line2_geometry, material=Single(m))
  }
  whole("line_basic", @nodes.LineBasicNodeMaterial::new, d, Some(line))
  whole("line_dashed", @nodes.LineDashedNodeMaterial::new, d, Some(line))
  whole("line2", fn() { @nodes.Line2NodeMaterial::new() }, d, Some(line2))
  whole(
    "line2_dashed_world_units",
    g10_set(fn() { @nodes.Line2NodeMaterial::new(dashed=true) }, fn(m) {
      @nodes.Line2NodeMaterial::set_world_units(m, true)
    }),
    d,
    Some(line2),
  )
  whole(
    "points",
    @nodes.PointsNodeMaterial::new,
    d,
    Some(fn(m) { @core.Points::new(geometry=line_geometry, material=Single(m)) }),
  )
  whole("points_sprite", @nodes.PointsNodeMaterial::new, d, None)
  whole(
    "sprite",
    @nodes.SpriteNodeMaterial::new,
    d,
    Some(fn(m) { @core.Sprite::new(material=m) }),
  )
  whole("from_core_standard", @core.MeshStandardMaterial::new, lit, None)
  whole(
    "from_core_basic_map",
    g10_set(@core.MeshBasicMaterial::new, fn(m) { m.map = Some(wtex("map")) }),
    d,
    None,
  )
  whole(
    "standard_instanced",
    @nodes.MeshStandardNodeMaterial::new,
    lit,
    Some(fn(m) {
      @core.InstancedMesh::new(geometry=wgeometry, material=Single(m), 4)
    }),
  )
  whole("basic_batched", basic, d, Some(g10_batched))
  whole(
    "basic_batched_no_multi_draw",
    basic,
    { ..d, renderer: "b", },
    Some(g10_batched),
  )
  whole(
    "basic_batched_float32_unfiltered",
    basic,
    { ..d, renderer: "b", },
    Some(g10_batched),
  )
  whole(
    "phong_spot_hemi",
    @nodes.MeshPhongNodeMaterial::new,
    {
      ..d,
      lights: fn() {
        [
          @core.SpotLight::new(
            color=@math.Color::from_hex(0xffffff),
            intensity=2,
          ),
          @core.HemisphereLight::new(
            sky_color=@math.Color::from_hex(0x8888ff),
            ground_color=@math.Color::from_hex(0x442200),
            intensity=1,
          ),
        ]
      },
    },
    None,
  )
  whole(
    "standard_directional_shadow",
    @nodes.MeshStandardNodeMaterial::new,
    {
      ..d,
      lights: fn() {
        let l = g10_directional()
        l.cast_shadow = true
        [l]
      },
    },
    None,
  )
  whole(
    "standard_clipping",
    @nodes.MeshStandardNodeMaterial::new,
    { ..lit, clipping: "soft", },
    None,
  )
  whole(
    "basic_clipping_hardware",
    basic,
    { ..d, renderer: "c", clipping: "hardware", },
    None,
  )
  whole(
    "basic_clipping_intersection",
    basic,
    { ..d, clipping: "intersection", },
    None,
  )
}

///|
/// The scenarios upstream throws on (WGSL-only nodes); upstream_g10.mjs skips them too.
let g10_skipped : Array[String] = [
  "g10_wgsl_fn_comment", "g10_invocation_local_index", "g10_storage_texture_load",
  "g10_storage_texture_store", "g10_storage_texture_rw_fragment", "g10_storage_texture_formats",
  "g10_storage_texture_3d", "g10_storage_texture_array", "g10_workgroup_array", "g10_workgroup_atomic",
  "g10_compute_workgroup_2d", "g10_compute_texture_store",
]

///|
/// The extensions of a stage, `name:behavior` joined by `,`.
fn g10_extensions_of(b : @nodes.NodeBuilder, stage : String) -> String {
  let g = @webgl_fallback.GLSLNodeBuilder::of(b).unwrap()
  match g.extensions.get(stage) {
    Some(m) => {
      let out = []
      for _, e in m {
        out.push(e.name + ":" + e.behavior)
      }
      out.join(",")
    }
    None => ""
  }
}

///|
fn g10_run_flow(
  make : () -> @nodes.Node,
  stage : String,
  renderer : @nodes.Renderer,
  mesh : Bool,
  ctx : Bool,
  pre : ((@nodes.NodeBuilder) -> Unit)?,
  geometry : @core.BufferGeometry?,
  decl_compute : Bool,
) -> String {
  let object : @nodes.BuilderObject = if mesh {
    Object3D(
      @core.Mesh::new(
        geometry=geometry.unwrap_or(g10_geometry),
        material=Single(@core.MeshBasicMaterial::new()),
      ),
    )
  } else {
    NoObject
  }
  let b = @webgl_fallback.GLSLNodeBuilder::new(object, renderer)
  if mesh {
    b.camera = Some(@core.PerspectiveCamera::new())
  }
  if ctx {
    g10_material_context(b)
  }
  if pre is Some(pre) {
    pre(b)
  }
  b.set_shader_stage(Some(stage))
  let flow = b.flow_stages_node(make())
  let g = @webgl_fallback.GLSLNodeBuilder::of(b).unwrap()
  if !b.vars.contains("vertex") {
    b.vars.set("vertex", [])
  }
  let decl = [
    b.get_uniforms(stage),
    b.get_attributes(stage),
    b.get_varyings("vertex"),
    b.get_varyings("fragment"),
    if decl_compute {
      b.get_varyings("compute")
    } else {
      ""
    },
    g.get_structs(b, stage),
    g10_extensions_of(b, stage),
    g.get_transforms(b, stage),
    b.get_vars(stage, global=true),
    b.get_vars("vertex", global=true),
  ].join("\n@@\n")
  let uniforms = []
  for st in ["vertex", "fragment", "compute"] {
    for u in b.uniforms.stage(st) {
      uniforms.push("\{st}:\{u.name}:\{u.type_}")
    }
  }
  g10_flow_json(
    flow.code,
    flow.result_snippet(),
    flow.vars.unwrap_or(""),
    FixedArray::from_array(uniforms),
    b.get_codes(stage),
    decl,
    g10_bindings(b),
  )
}

///|
fn g10_run_compute(
  make : () -> @nodes.Node,
  renderer : @nodes.Renderer,
) -> String {
  let b = @webgl_fallback.GLSLNodeBuilder::new(NoObject, renderer)
  b.compute = Some(make())
  b.build() |> ignore
  g10_compute_json(
    b.compute_shader.unwrap_or("undefined"),
    b.transforms().map(fn(t) { t.varying_name }).join(","),
    g10_bindings(b),
  )
}

///|
fn g10_run_material(
  object : @core.Object3D,
  vertex : () -> @nodes.Node,
  fragment : () -> @nodes.Node,
  renderer : @nodes.Renderer,
  pre : ((@nodes.NodeBuilder) -> Unit)?,
) -> String {
  let b = @webgl_fallback.GLSLNodeBuilder::new(Object3D(object), renderer)
  b.scene = Some(@core.Scene::new())
  b.camera = Some(@core.PerspectiveCamera::new())
  if pre is Some(pre) {
    pre(b)
  }
  b.add_context(
    @nodes.ContextNode::get_flow_context_data(renderer.context_node),
  )
  |> ignore
  b.add_stack() |> ignore
  b.stack.output_node = Some(vertex())
  b.add_flow("vertex", b.remove_stack().node) |> ignore
  b.add_stack() |> ignore
  b.stack.output_node = Some(fragment())
  b.add_flow("fragment", b.remove_stack().node) |> ignore
  for build_stage in ["setup", "analyze", "generate"] {
    b.set_build_stage(Some(build_stage))
    for shader_stage in ["fragment", "vertex", "compute"] {
      b.set_shader_stage(Some(shader_stage))
      for node in b.flow_nodes.get(shader_stage).unwrap() {
        if build_stage == "generate" {
          b.flow_node(node) |> ignore
        } else {
          node.build(b) |> ignore
        }
      }
    }
  }
  b.set_build_stage(None)
  b.set_shader_stage(None)
  b.build_code()
  g10_shader_json(
    b.vertex_shader.unwrap_or("undefined") +
    "\n@@@@\n" +
    b.fragment_shader.unwrap_or("undefined"),
    g10_bindings(b),
  )
}

///|
fn g10_run_whole(
  scenario : G10Extra,
  make : () -> @core.Material,
  object : (@core.Material) -> @core.Object3D,
  renderer : @nodes.Renderer,
) -> String {
  let material = make()
  let object = object(material)
  renderer.logarithmic_depth_buffer = scenario.logarithmic
  let b = @webgl_fallback.GLSLNodeBuilder::new(Object3D(object), renderer)
  b.scene = Some(@core.Scene::new())
  b.camera = Some(@core.PerspectiveCamera::new())
  b.lights_node = Some(
    @nodes.LightsNode::set_lights(@nodes.LightsNode::new(), (scenario.lights)()),
  )
  if scenario.fog {
    b.fog_node = Some(
      @nodes.fog.call([
        @nodes.color(0x8899aa),
        @nodes.range_fog_factor.call([1, 10]),
      ]),
    )
  }
  if scenario.clipping != "" {
    let group = @core.ClippingGroup::new()
    match group.kind {
      ClippingGroup(cg) => {
        cg.clipping_planes = [
          @math.Plane::new(normal=@math.Vector3::new(1, 0, 0), constant=1),
          @math.Plane::new(normal=@math.Vector3::new(0, 1, 0), constant=2),
        ]
        cg.clip_intersection = scenario.clipping == "intersection"
      }
      _ => ()
    }
    let context = @nodes.ClippingContext::new()
    context.update(@nodes.ClippingContext::new(), group)
    b.clipping_context = Some(context)
    b.hardware_clipping = scenario.clipping == "hardware"
  }
  b.build() |> ignore
  renderer.logarithmic_depth_buffer = false
  g10_shader_json(
    b.vertex_shader.unwrap_or("undefined") +
    "\n@@@@\n" +
    b.fragment_shader.unwrap_or("undefined"),
    g10_bindings(b),
  )
}

///|
test "g10 GLSL shader scenarios run (compared with upstream by run.mjs)" {
  let renderers = {
    "a": g10_shader_renderer(g10_default_extensions),
    "b": g10_shader_renderer([]),
    "c": g10_shader_renderer(
      g10_default_extensions + ["WEBGL_clip_cull_distance"],
    ),
    "d": g10_shader_renderer(g10_default_extensions),
  }
  renderers.get("d").unwrap().debug.diagnostics.keywords = true
  let only = g10_only()
  let emit = fn(name : String, record : String) {
    if g10_shader_diff_enabled() {
      println("@@SHADER \{name} \{record}")
    }
  }
  for scenario in g10_scenarios() {
    if (only != "" && only != scenario.name) ||
      g10_skipped.contains(scenario.name) {
      continue
    }
    let renderer = renderers.get(scenario.renderer).unwrap()
    let record = match scenario.kind {
      Flow(make) =>
        g10_run_flow(
          make,
          scenario.stage,
          renderer,
          scenario.mesh,
          scenario.ctx,
          scenario.pre,
          None,
          false,
        )
      Compute(make) => g10_run_compute(make, renderer)
      Material(vertex, fragment) =>
        g10_run_material(
          @core.Mesh::new(
            geometry=g10_geometry,
            material=Single(@core.MeshBasicMaterial::new()),
          ),
          vertex,
          fragment,
          renderer,
          scenario.pre,
        )
    }
    emit(scenario.name, record)
  }
  for scenario in g10_extras() {
    if only != "" && only != scenario.name {
      continue
    }
    let renderer = renderers.get(scenario.renderer).unwrap()
    let record = match scenario.kind {
      ExtraFlow(make) =>
        g10_run_flow(
          make,
          scenario.stage,
          renderer,
          scenario.mesh,
          false,
          scenario.pre,
          scenario.geometry,
          scenario.decl_compute,
        )
      ExtraCompute(make) => g10_run_compute(make, renderer)
      ExtraMaterial(object, vertex, fragment) =>
        g10_run_material(object(), vertex, fragment, renderer, scenario.pre)
      Whole(make, object) => g10_run_whole(scenario, make, object, renderer)
    }
    emit(scenario.name, record)
  }
}

///|
/// `G10_ONLY=<name>` runs one scenario (debugging aid).
extern "js" fn g10_only() -> String = "() => (typeof process !== 'undefined' && process.env.G10_ONLY) || ''"
