// MoonBit side of the G8 (WGSLNodeBuilder) shader scenarios. The upstream side is
// diff/core/webgpu/shader_diff/upstream_g8.mjs; `node shader_diff/run.mjs
// g8_...` compares them byte for byte. See that file for the three kinds of scenario
// (flow with declarations, whole compute shaders, whole materials through a stand-in for
// `NodeMaterial.build`) and the three renderers (`a` no features, `b` subgroups, `c`
// compatibility mode).

///|
extern "js" fn g8_shader_diff_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.SHADER_DIFF === '1'"

///|
extern "js" fn g8_flow_json(
  code : String,
  result : String,
  vars : String,
  uniforms : FixedArray[String],
  codes : String,
  decl : String,
  bindings : String,
) -> String = "(code, result, vars, uniforms, codes, decl, bindings) => JSON.stringify({ code, result, vars, uniforms, codes, decl, bindings })"

///|
extern "js" fn g8_shader_json(shader : String, bindings : String) -> String = "(shader, bindings) => JSON.stringify({ shader, bindings })"

///|
/// `bindingsOf( builder )` of upstream_g8.mjs: each bind group's bindings with their
/// visibility.
fn g8_bindings(b : @nodes.NodeBuilder) -> String {
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
fn g8_fv(v : Double) -> @nodes.Node {
  @nodes.float(v).to_var()
}

///|
fn g8_iv(v : Int32) -> @nodes.Node {
  @nodes.int(v).to_var()
}

///|
fn g8_uv(v : Int32) -> @nodes.Node {
  @nodes.uint(v).to_var()
}

///|
fn g8_v2() -> @nodes.Node {
  @nodes.vec2_of([1, 2]).to_var()
}

///|
fn g8_v3() -> @nodes.Node {
  @nodes.vec3_of([1, 2, 3]).to_var()
}

///|
fn g8_v4() -> @nodes.Node {
  @nodes.vec4_of([1, 2, 3, 4]).to_var()
}

///|
fn g8_m2() -> @nodes.Node {
  @nodes.mat2_of([1, 2, 3, 4]).to_var()
}

///|
fn g8_m3() -> @nodes.Node {
  @nodes.mat3_of([1, 0, 0, 0, 1, 0, 0, 0, 1]).to_var()
}

///|
fn g8_m4() -> @nodes.Node {
  @nodes.mat4_of([]).to_var()
}

///|
fn g8_tex() -> @core.Texture {
  let t = @core.Texture::new()
  t.name = "tex"
  t
}

///|
fn g8_float_tex(nearest : Bool) -> @core.Texture {
  let t = g8_tex()
  t.type_ = @core.FloatType
  if nearest {
    t.min_filter = @core.NearestFilter
    t.mag_filter = @core.NearestFilter
  }
  t
}

///|
fn g8_attribute(n : Int32, item_size : Int32) -> @core.GeometryAttribute {
  Buffer(
    @core.BufferAttribute::new(
      @core.TypedArray::float32(n * item_size),
      item_size,
    ),
  )
}

///|
let g8_geometry : @core.BufferGeometry = {
  let g = @core.BufferGeometry::new()
  g.set_attribute("position", g8_attribute(24, 3)) |> ignore
  g.set_attribute("normal", g8_attribute(24, 3)) |> ignore
  g.set_attribute("uv", g8_attribute(24, 2)) |> ignore
  g
}

///|
fn g8_float_buffer(n : Int32, item_size : Int32) -> @core.BufferAttribute {
  @nodes.StorageBufferAttribute::new(n, item_size)
}

///|
fn g8_uint_buffer(n : Int32) -> @core.BufferAttribute {
  @nodes.StorageBufferAttribute::new(n, 1, type_class=Uint32Array)
}

///|
fn g8_setup(f : () -> @nodes.Node) -> @core.JsValue {
  @core.JsValue::of(@nodes.ContextSetup::{ f, })
}

///|
/// `materialContext( builder )` of upstream_g8.mjs.
fn g8_material_context(b : @nodes.NodeBuilder) -> Unit {
  b.context.set(
    "setupPositionView",
    Other(
      g8_setup(fn() {
        @nodes.model_view_matrix.mul(@nodes.position_local).xyz()
      }),
    ),
  )
  b.context.set(
    "setupModelViewProjection",
    Other(
      g8_setup(fn() {
        @nodes.camera_projection_matrix.mul(@nodes.position_view)
      }),
    ),
  )
  b.context.set(
    "setupNormal",
    Other(
      g8_setup(fn() {
        @nodes.sub_build(@nodes.normal_view_geometry, "NORMAL", type_="vec3")
      }),
    ),
  )
}

///|
priv enum G8Kind {
  Flow(() -> @nodes.Node)
  Compute(() -> @nodes.Node)
  Material(() -> @nodes.Node, () -> @nodes.Node)
}

///|
priv struct G8Scenario {
  name : String
  kind : G8Kind
  stage : String
  renderer : String
  mesh : Bool
  ctx : Bool
  pre : ((@nodes.NodeBuilder) -> Unit)?
}

///|
priv struct G8Opts {
  stage : String
  renderer : String
  mesh : Bool
  ctx : Bool
  pre : ((@nodes.NodeBuilder) -> Unit)?
}

///|
let g8_default : G8Opts = {
  stage: "fragment",
  renderer: "a",
  mesh: false,
  ctx: false,
  pre: None,
}

///|
fn g8_stage(stage : String) -> G8Opts {
  { ..g8_default, stage, }
}

///|
fn g8_fn(body : () -> @nodes.Node) -> @nodes.Node {
  @nodes.fn_(fn(_, _) { Some(body()) }).call([])
}

///|
fn g8_fn_unit(body : () -> Unit) -> @nodes.Node {
  @nodes.fn_(fn(_, _) {
    body()
    None
  }).call([])
}

///|
fn g8_scenarios() -> Array[G8Scenario] {
  let scenarios : Array[G8Scenario] = []
  let flow = fn(name : String, make : () -> @nodes.Node, opts : G8Opts) {
    scenarios.push({
      name: "g8_" + name,
      kind: Flow(make),
      stage: opts.stage,
      renderer: opts.renderer,
      mesh: opts.mesh,
      ctx: opts.ctx,
      pre: opts.pre,
    })
  }
  let f = fn(name : String, make : () -> @nodes.Node) {
    flow(name, make, g8_default)
  }
  let compute_build = fn(
    name : String,
    make : () -> @nodes.Node,
    renderer : String,
  ) {
    scenarios.push({
      ..g8_default_scenario(name),
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
      ..g8_default_scenario(name),
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
    g8_m2()
    .mul(@nodes.vec2_of([1, 2]))
    .add(g8_m3().mul(@nodes.vec3(1)).xy())
    .add(g8_m4().mul(@nodes.vec4(1)).xy())
  })
  f("color_type", fn() { @nodes.color(0xff0000).to_var() })
  f("convert_int_float", fn() {
    @nodes.int(g8_fv(2.5)).add(@nodes.int(g8_uv(3)))
  })
  f("convert_vec", fn() {
    @nodes.vec3(@nodes.ivec3_of([1, 2, 3]).to_var()).add(
      @nodes.vec3(@nodes.uvec3_of([4, 5, 6]).to_var()),
    )
  })
  f("bitcast", fn() { @nodes.bitcast(g8_fv(1), "uint") })
  f("bitcast_methods", fn() {
    @nodes.vec2_of([
      @nodes.float(@nodes.float_bits_to_int(g8_fv(1))),
      @nodes.uint_bits_to_float(g8_uv(3)),
    ])
  })
  f("packing", fn() {
    @nodes.vec3_of([
      @nodes.float(@nodes.pack_snorm2x16(g8_v2())),
      @nodes.unpack_half2x16(g8_uv(5)).x(),
      @nodes.float(@nodes.pack_unorm4x8(g8_v4())),
    ])
  })
  f("mod_float", fn() { g8_fv(5).mod(2) })
  f("mod_vec2", fn() { g8_v2().mod(@nodes.vec2(2)) })
  f("mod_vec3", fn() { g8_v3().mod(g8_fv(2)) })
  f("mod_vec4", fn() { g8_v4().mod(@nodes.vec4(3)) })
  f("mod_int", fn() { g8_iv(5).mod(g8_iv(2)) })
  f("equal_bool", fn() {
    @nodes.bool(true).to_var().equal(@nodes.bool(false).to_var())
  })
  f("equal_bvec2", fn() {
    @nodes.bvec2_of([true, false])
    .to_var()
    .equal(@nodes.bvec2_of([false, false]).to_var())
  })
  f("xor", fn() { @nodes.bool(true).to_var().xor(@nodes.bool(false).to_var()) })
  f("inverse_mat2", fn() { g8_m2().inverse() })
  f("inverse_mat3", fn() { g8_m3().inverse() })
  f("inverse_mat4", fn() { g8_m4().inverse() })
  f("derivatives", fn() {
    g8_fv(1).d_fdx().add(g8_fv(2).d_fdy()).add(@nodes.inverse_sqrt(g8_fv(4)))
  })
  f("faceforward", fn() { @nodes.faceforward(g8_v3(), g8_v3(), g8_v3()) })
  f("select", fn() {
    @nodes.select(g8_fv(1).greater_than(0), g8_v3(), else_node=@nodes.vec3(0))
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
    { ..g8_default, renderer: "d", },
  )
  f("declaration_names", fn() {
    @nodes.uniform(1)
    .set_name("scale")
    .add(@nodes.uniform(2).set_name("scale"))
    .add(
      @nodes.storage(g8_float_buffer(4, 1), type_="float", count=4)
      .set_name("buf")
      .element(g8_iv(0)),
    )
    .add(
      @nodes.storage(g8_float_buffer(4, 1), type_="float", count=4)
      .set_name("buf")
      .element(g8_iv(1)),
    )
  })
  f("array_values", fn() {
    @nodes.array([@nodes.float(1), @nodes.float(2), @nodes.float(3)])
    .to_var()
    .element(g8_iv(1))
  })
  f("array_count", fn() {
    @nodes.array_of_type("vec3", 4).to_var().element(g8_iv(2))
  })
  f("const_let", fn() {
    @nodes.vec3_of([1, 2, 3]).to_const(name="k").add(g8_fv(1).to_const())
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
    .call([g8_fv(1), g8_fv(2)])
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
    .call([g8_v3()])
  })
  f("fn_layout_mod", fn() {
    @nodes.fn_(fn(inputs, _) {
      let x = inputs.get(0).unwrap()
      Some(x.mod(2).add(x.d_fdx()))
    })
    .set_layout(name="modFn", type_="float", inputs=[("x", "float")])
    .call([g8_fv(3)])
  })
  f("wgsl_fn", fn() {
    @nodes.wgsl_fn("fn scale( a : f32, b : vec3f ) -> vec3f { return b * a; }").call([
        g8_fv(2),
        g8_v3(),
      ],
    )
  })
  f("wgsl_fn_comment", fn() {
    @nodes.wgsl_fn(
      "// scales\n/* by a */\nfn scale2( a : f32, b : vec2<f32> ) -> vec2<f32> { return b * a; }",
    ).call([g8_fv(2), g8_v2()])
  })
  f("wgsl_fn_includes", fn() {
    let inner = @nodes.wgsl_fn("fn inner( x : f32 ) -> f32 { return x * 2.0; }")
    @nodes.wgsl_fn("fn outer( x : f32 ) -> f32 { return inner( x ) + 1.0; }", includes=[
      inner,
    ]).call([g8_fv(3)])
  })
  f("wgsl_fn_object_args", fn() {
    @nodes.wgsl_fn(
      "fn mixer( a : vec3<f32>, b : vec3<f32>, t : f32 ) -> vec3<f32> { return mix( a, b, t ); }",
    ).call_named({ "t": g8_fv(0.5), "a": g8_v3(), "b": @nodes.vec3(1) })
  })
  f("loop_break", fn() {
    g8_fn(fn() {
      let r = g8_fv(0)
      @nodes.loop_([4], fn(inputs) {
        let i = inputs.named("i").unwrap()
        @nodes.if_(r.greater_than(2), fn() { @nodes.break_() }) |> ignore
        r.add_assign(@nodes.float(i))
      })
      r
    })
  })
  f("early_return_main", fn() {
    g8_fn(fn() {
      let r = g8_fv(1)
      @nodes.if_(r.greater_than(1), fn() { @nodes.return_() }) |> ignore
      r
    })
  })
  f("discard", fn() {
    g8_fn(fn() {
      @nodes.discard(conditional=g8_fv(1).less_than(0))
      g8_fv(1)
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
    s.call([g8_fv(1), g8_v3()]).to_var().get("b")
  })
  f("output_struct", fn() {
    @nodes.output_struct([@nodes.vec4(1), @nodes.vec4(0.5)])
  })
  f("frag_depth", fn() {
    g8_fn(fn() {
      @nodes.depth.assign(g8_fv(0.5))
      @nodes.vec4(1)
    })
  })

  // --- Builtins
  flow("front_facing", fn() { @nodes.float(@nodes.front_facing).to_var() }, {
    ..g8_default,
    mesh: true,
  })
  f("frag_coord", fn() { @nodes.screen_coordinate.to_var() })
  flow(
    "vertex_index",
    fn() {
      @nodes.float(@nodes.vertex_index).add(@nodes.float(@nodes.instance_index))
    },
    g8_stage("vertex"),
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
    g8_stage("compute"),
  )
  flow(
    "invocation_local_index",
    fn() { @nodes.float(@nodes.invocation_local_index) },
    g8_stage("compute"),
  )
  flow(
    "subgroups",
    fn() {
      @nodes.subgroup_add(g8_fv(1))
      .add(@nodes.float(@nodes.subgroup_size))
      .add(@nodes.float(@nodes.invocation_subgroup_index))
      .add(@nodes.float(@nodes.subgroup_index))
    },
    { ..g8_stage("compute"), renderer: "b", },
  )
  flow(
    "subgroups_unsupported",
    fn() { @nodes.float(@nodes.subgroup_size) },
    g8_stage("compute"),
  )
  flow("hardware_clipping", fn() { g8_fv(1) }, {
    ..g8_stage("vertex"),
    pre: Some(fn(b) { b.enable_hardware_clipping(3) }),
  })
  flow("directives", fn() { g8_fv(1) }, {
    ..g8_default,
    pre: Some(fn(b) {
      b.enable_shader_f16()
      b.enable_dual_source_blending()
      b.enable_shader_f16()
    }),
  })
  flow("invariant", fn() { g8_fv(1) }, {
    ..g8_stage("vertex"),
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
    g8_stage("vertex"),
  )
  f("uniform_array", fn() {
    @nodes.uniform_array([1, 2, 3, 4]).element(g8_iv(1))
  })
  f("uniform_array_vec4", fn() {
    @nodes.uniform_array([
      @math.Vector4::new(1, 2, 3, 4),
      @math.Vector4::new(0, 0, 0, 1),
    ]).element(g8_iv(1))
  })

  // --- Textures
  f("texture_sample", fn() { @nodes.texture(g8_tex()) })
  f("texture_uv", fn() {
    @nodes.texture(g8_tex(), uv_node=@nodes.vec2_of([0.25, 0.75]))
  })
  f("texture_level", fn() {
    @nodes.texture(g8_tex(), uv_node=@nodes.vec2(0.5)).level(2)
  })
  f("texture_bias", fn() {
    @nodes.texture(g8_tex(), uv_node=@nodes.vec2(0.5)).bias(0.5)
  })
  f("texture_grad", fn() {
    @nodes.texture(g8_tex(), uv_node=@nodes.vec2(0.5)).grad(
      @nodes.vec2(0.1),
      @nodes.vec2(0.2),
    )
  })
  f("texture_offset", fn() {
    @nodes.texture(g8_tex(), uv_node=@nodes.vec2(0.5)).offset(
      @nodes.ivec2_of([1, 2]),
    )
  })
  f("texture_depth_offset", fn() {
    @nodes.texture(@core.DataArrayTexture::new(), uv_node=@nodes.vec2(0.5))
    .depth(1)
    .offset(@nodes.ivec2_of([1, 0]))
  })
  f("texture_gather", fn() {
    @nodes.texture(g8_tex(), uv_node=@nodes.vec2(0.5)).gather()
  })
  f("texture_gather_channel", fn() {
    @nodes.texture(g8_tex(), uv_node=@nodes.vec2(0.5)).gather(gather_node=2)
  })
  f("texture_load", fn() {
    @nodes.texture_load(g8_tex(), uv_node=@nodes.ivec2_of([1, 2]))
  })
  f("texture_load_level", fn() {
    @nodes.texture_load(g8_tex(), uv_node=@nodes.ivec2_of([1, 2]), level_node=1)
  })
  f("texture_size", fn() { @nodes.texture_size(@nodes.texture(g8_tex())) })
  f("texture_size_level", fn() { @nodes.texture(g8_tex()).size(level_node=2) })
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
    { ..g8_default, renderer: "c", },
  )
  flow(
    "texture_depth_compat",
    fn() {
      @nodes.texture(
        @core.DepthTexture::new(width=4, height=4),
        uv_node=@nodes.vec2(0.5),
      )
    },
    { ..g8_default, renderer: "c", },
  )
  f("texture_int", fn() {
    let t = g8_tex()
    t.type_ = @core.IntType
    @nodes.texture(t, uv_node=@nodes.vec2(0.5))
  })
  f("texture_uint_red", fn() {
    let t = g8_tex()
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
    @nodes.texture(g8_float_tex(false), uv_node=@nodes.vec2(0.5))
  })
  f("texture_float_filtered_offset_level", fn() {
    @nodes.texture(g8_float_tex(false), uv_node=@nodes.vec2(0.5))
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
    @nodes.texture(g8_float_tex(true), uv_node=@nodes.vec2(0.5))
  })
  f("texture_float_nearest_wrap", fn() {
    let t = g8_float_tex(true)
    t.wrap_s = @core.RepeatWrapping
    t.wrap_t = @core.MirroredRepeatWrapping
    @nodes.texture(t, uv_node=@nodes.vec2(0.5)).offset(@nodes.ivec2_of([1, 2]))
  })
  f("texture_float_nearest_shared", fn() {
    let t = g8_float_tex(true)
    @nodes.texture(t, uv_node=@nodes.vec2(0.5)).add(
      @nodes.texture(t, uv_node=@nodes.vec2(0.25)).level(1),
    )
  })
  f("texture_float_grad", fn() {
    @nodes.texture(g8_float_tex(true), uv_node=@nodes.vec2(0.5)).grad(
      @nodes.vec2(0.1),
      @nodes.vec2(0.2),
    )
  })
  f("texture_normalized_short", fn() {
    let t = g8_tex()
    t.type_ = @core.ShortType
    t.normalized = true
    @nodes.texture(t, uv_node=@nodes.vec2(0.5))
  })
  flow(
    "texture_vertex",
    fn() { @nodes.texture(g8_tex(), uv_node=@nodes.vec2(0.5)) },
    g8_stage("vertex"),
  )
  flow(
    "texture_vertex_offset_array",
    fn() {
      @nodes.texture(@core.DataArrayTexture::new(), uv_node=@nodes.vec2(0.5))
      .depth(1)
      .offset(@nodes.ivec2_of([1, 1]))
    },
    g8_stage("vertex"),
  )
  flow(
    "texture_vertex_float",
    fn() { @nodes.texture(g8_float_tex(true), uv_node=@nodes.vec2(0.5)) },
    g8_stage("vertex"),
  )
  flow(
    "texture_vertex_bias",
    fn() { @nodes.texture(g8_tex(), uv_node=@nodes.vec2(0.5)).bias(1) },
    g8_stage("vertex"),
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
    g8_stage("compute"),
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
    g8_stage("compute"),
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
    g8_stage("compute"),
  )
  flow(
    "storage_texture_3d",
    fn() {
      @nodes.storage_texture3d(
        @nodes.Storage3DTexture::new(width=2, height=2, depth=2),
        uv_node=@nodes.uvec3_of([1, 1, 1]),
      )
    },
    g8_stage("compute"),
  )
  flow(
    "storage_texture_array",
    fn() {
      @nodes.storage_texture(
        @nodes.StorageArrayTexture::new(width=2, height=2, depth=2),
        uv_node=@nodes.uvec2_of([1, 1]),
      ).depth(1)
    },
    g8_stage("compute"),
  )

  // --- Storage buffers, atomics, workgroup memory
  flow(
    "storage_read",
    fn() {
      @nodes.storage(g8_float_buffer(16, 4), type_="vec4", count=16).element(
        @nodes.instance_index,
      )
    },
    g8_stage("compute"),
  )
  flow(
    "storage_read_only",
    fn() {
      @nodes.storage(g8_float_buffer(16, 4), type_="vec4", count=16)
      .to_read_only()
      .element(@nodes.instance_index)
    },
    g8_stage("compute"),
  )
  flow(
    "storage_vertex",
    fn() {
      @nodes.storage(g8_float_buffer(16, 3), type_="vec3", count=16).element(
        @nodes.instance_index,
      )
    },
    g8_stage("vertex"),
  )
  f("storage_fragment", fn() {
    @nodes.storage(g8_float_buffer(16, 1), type_="float", count=16).element(
      g8_iv(2),
    )
  })
  flow(
    "storage_atomic",
    fn() {
      @nodes.atomic_add(
        @nodes.storage(g8_uint_buffer(4), type_="uint", count=4)
        .to_atomic()
        .element(0),
        1,
      )
    },
    g8_stage("compute"),
  )
  f("storage_atomic_fragment", fn() {
    @nodes.atomic_add(
      @nodes.storage(g8_uint_buffer(4), type_="uint", count=4)
      .to_atomic()
      .element(1),
      2,
    )
  })
  flow(
    "storage_atomic_vertex",
    fn() {
      @nodes.atomic_load(
        @nodes.storage(g8_uint_buffer(4), type_="uint", count=4)
        .to_atomic()
        .element(1),
      )
    },
    g8_stage("vertex"),
  )
  flow(
    "workgroup_array",
    fn() {
      @nodes.workgroup_array("float", count=64)
      .set_name("wgFloats")
      .element(@nodes.invocation_local_index)
    },
    g8_stage("compute"),
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
    g8_stage("compute"),
  )
  flow(
    "barrier",
    fn() {
      g8_fn(fn() {
        let r = g8_fv(1)
        @nodes.workgroup_barrier()
        r
      })
    },
    g8_stage("compute"),
  )

  // --- Varyings and attributes (mesh)
  let mesh = { ..g8_default, mesh: true, }
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
  f("g1_op_add_variadic", fn() { @nodes.add_of([g8_fv(1), 2, g8_fv(3), 4]) })
  f("g1_op_div_int_int", fn() { g8_iv(4).div(g8_iv(2)) })
  f("g1_op_mul_uint_negative", fn() { g8_uv(3).mul(-2) })
  f("g1_op_not_equal_vec3", fn() { g8_v3().not_equal(g8_v3()) })
  f("g1_op_and_bvec", fn() {
    @nodes.bvec2_of([true, false])
    .to_var()
    .and_(@nodes.bvec2_of([false, true]).to_var())
  })
  f("g1_op_bit_not", fn() { g8_iv(6).bit_not() })
  f("g1_op_shift_right_uvec", fn() {
    @nodes.uvec3_of([8, 16, 32]).to_var().shift_right(2)
  })
  f("g1_op_mat3_vec3", fn() { g8_m3().mul(g8_v3()) })
  f("g1_op_assign_ops", fn() {
    g8_fn(fn() {
      let v = g8_fv(1)
      v.add_assign(2)
      v.mul_assign(3)
      v.mod_assign(5)
      let i = g8_iv(3)
      i.bit_xor_assign(7)
      i.shift_left_assign(1)
      v.add(@nodes.float(i))
    })
  })
  f("g1_op_increment", fn() {
    g8_fn(fn() {
      let i = g8_iv(0)
      i.increment()
      i.decrement_before()
      i
    })
  })
  f("g1_math_one_vec3", fn() {
    g8_v3()
    .normalize()
    .add(g8_v3().fract())
    .add(g8_v3().saturate())
    .add(g8_v3().one_minus())
    .add(g8_v3().cbrt())
  })
  f("g1_math_atan2", fn() { @nodes.atan(g8_fv(1), x=g8_fv(2)) })
  f("g1_math_mix_vec3", fn() { @nodes.mix(g8_v3(), @nodes.vec3(0), g8_fv(0.5)) })
  f("g1_math_clamp_int", fn() { g8_iv(3).clamp(low=g8_iv(0), high=2) })
  f("g1_math_transpose_det", fn() {
    g8_m3().transpose().mul(g8_m3().determinant())
  })
  f("g1_math_rand", fn() { @nodes.rand.call([g8_v2()]) })
  f("g1_math_constants", fn() {
    @nodes.vec4_of([@nodes.pi, @nodes.two_pi, @nodes.half_pi, @nodes.epsilon]).add(
      @nodes.infinity,
    )
  })
  f("g1_cond_select_vec", fn() {
    @nodes.select(g8_fv(1).greater_than(0), g8_v3(), else_node=@nodes.vec3(1)).add(
      g8_fv(1).greater_than(0).select(1, else_node=2),
    )
  })
  f("g1_hash", fn() { @nodes.hash_tsl.call([g8_uv(3)]) })
  f("g1_remap", fn() {
    @nodes.remap
    .call([g8_fv(0.5), 0, 1, 2, 4])
    .add(@nodes.remap_clamp(g8_fv(0.5), 0, 1, out_low_node=2, out_high_node=4))
  })
  f("g1_rotate", fn() { @nodes.rotate(g8_v2(), g8_fv(0.5)) })
  f("g1_checker", fn() { @nodes.checker.call([g8_v2()]) })
  f("g1_tri_noise", fn() { @nodes.tri_noise3d.call([g8_v3(), 1, g8_fv(0)]) })
  f("g1_oscillators", fn() {
    @nodes.osc_sine(t=g8_fv(0.5))
    .add(@nodes.osc_square(t=g8_fv(0.5)))
    .add(@nodes.osc_triangle(t=g8_fv(0.5)))
    .add(@nodes.osc_sawtooth(t=g8_fv(0.5)))
  })
  f("g1_packing_normals", fn() {
    @nodes.pack_normal_to_rgb(g8_v3()).add(@nodes.unpack_rgb_to_normal(g8_v3()))
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
  flow("g2_texture_uv_default", fn() { @nodes.texture(g8_tex()).rgb() }, mesh)

  // --- Whole compute shaders
  compute_build(
    "compute_basic",
    fn() {
      let buf = @nodes.storage(g8_float_buffer(64, 1), type_="float", count=64)
      @nodes.compute(
        g8_fn_unit(fn() {
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
      let buf = @nodes.storage(g8_float_buffer(64, 4), type_="vec4", count=64)
      let scale = @nodes.uniform(2)
      let shared = @nodes.workgroup_array("float", count=64).set_name("shared")
      @nodes.compute(
        g8_fn_unit(fn() {
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
      let counter = @nodes.storage(g8_uint_buffer(1), type_="uint", count=1).to_atomic()
      @nodes.compute(
        g8_fn_unit(fn() { @nodes.atomic_add(counter.element(0), 1) |> ignore }),
        16,
        workgroup_size=[16],
      )
    },
    "a",
  )
  compute_build(
    "compute_subgroups",
    fn() {
      let buf = @nodes.storage(g8_float_buffer(32, 1), type_="float", count=32)
      @nodes.compute(
        g8_fn_unit(fn() {
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
        g8_fn_unit(fn() {
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
      let buf = @nodes.storage(g8_float_buffer(16, 4), type_="vec4", count=16)
      let a = @nodes.uniform(1)
      let b = @nodes.uniform(@math.Vector3::new(1, 2, 3)).set_group(
        @nodes.render_group,
      )
      @nodes.compute(
        g8_fn_unit(fn() {
          let c = @nodes.texture(g8_tex(), uv_node=@nodes.vec2(0.5))
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
      let buf = @nodes.storage(g8_float_buffer(16, 1), type_="float", count=16)
      let sq = @nodes.fn_(fn(inputs, _) {
        let x = inputs.get(0).unwrap()
        Some(x.mul(x).mod(3))
      }).set_layout(name="sq", type_="float", inputs=[("x", "float")])
      @nodes.compute(
        g8_fn_unit(fn() {
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
      let buf = @nodes.storage(g8_float_buffer(16, 1), type_="float", count=16)
      @nodes.compute(
        g8_fn_unit(fn() {
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
      @nodes.texture(g8_tex(), uv_node=@nodes.uv())
      .mul(@nodes.uniform(@math.Color::new(0.5, 0.25, 1)))
      .add(@nodes.texture(g8_float_tex(true), uv_node=@nodes.uv()))
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
      g8_fn(fn() {
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
      let buf = @nodes.storage(g8_float_buffer(16, 3), type_="vec3", count=16).to_read_only()
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
fn g8_default_scenario(name : String) -> G8Scenario {
  {
    name: "g8_" + name,
    kind: Flow(fn() { @nodes.float(0) }),
    stage: "fragment",
    renderer: "a",
    mesh: false,
    ctx: false,
    pre: None,
  }
}

///|
/// The backend of the test renderers: an initialized WebGPUBackend as upstream_g8.mjs
/// fakes it (`hasFeature` reads the stand-in device features).
priv struct G8Backend {}

///|
impl @nodes.BackendClass for G8Backend with fn class_name(_) {
  "WebGPUBackend"
}

///|
impl @nodes.BackendClass for G8Backend with fn has_flag(_, flag) {
  flag == "isWebGPUBackend"
}

///|
impl @nodes.BackendClass for G8Backend with fn coordinate_system(_, _) {
  @core.WebGPUCoordinateSystem
}

///|
impl @nodes.BackendClass for G8Backend with fn has_compatibility(_, _, name) {
  name == @core.Compatibility_TEXTURE_COMPARE
}

///|
impl @nodes.BackendClass for G8Backend with fn has_feature(_, backend, name) {
  @webgpu.wgsl_backend_state(backend).features.contains(
    @webgpu.wgsl_gpu_feature_name(name),
  )
}

///|
/// The renderers of upstream_g8.mjs.
fn g8_renderer(
  features : Array[String],
  compatibility_mode : Bool,
) -> @nodes.Renderer {
  let r = @nodes.Renderer::foundation_stub()
  r.backend.class_ = G8Backend::{ }
  r._initialized = true
  r.backend.renderer = Some(r)
  let state = @webgpu.wgsl_backend_state(r.backend)
  for feature in features {
    state.features.push(feature)
  }
  state.compatibility_mode = compatibility_mode
  r
}

///|
fn g8_run(scenario : G8Scenario, renderer : @nodes.Renderer) -> String {
  match scenario.kind {
    Flow(make) => {
      let object : @nodes.BuilderObject = if scenario.mesh {
        Object3D(
          @core.Mesh::new(
            geometry=g8_geometry,
            material=Single(@core.MeshBasicMaterial::new()),
          ),
        )
      } else {
        NoObject
      }
      let b = @webgpu.WGSLNodeBuilder::new(object, renderer)
      if scenario.mesh {
        b.camera = Some(@core.PerspectiveCamera::new())
      }
      if scenario.ctx {
        g8_material_context(b)
      }
      if scenario.pre is Some(pre) {
        pre(b)
      }
      let stage = scenario.stage
      b.set_shader_stage(Some(stage))
      let flow = b.flow_stages_node(make())
      let w = @webgpu.WGSLNodeBuilder::of(b).unwrap()
      if !b.vars.contains("vertex") {
        b.vars.set("vertex", [])
      }
      let decl = [
        b.get_uniforms(stage),
        b.get_attributes(stage),
        b.get_varyings("vertex"),
        b.get_varyings("fragment"),
        w.get_structs(b, stage),
        w.get_directives(stage),
        w.get_scoped_arrays(b, stage).unwrap_or("undefined"),
        w.get_builtins(b, "output"),
        b.get_vars(stage, global=true),
        b.get_vars("vertex", global=true),
      ].join("\n@@\n")
      let uniforms = []
      for st in ["vertex", "fragment", "compute"] {
        for u in b.uniforms.stage(st) {
          uniforms.push("\{st}:\{u.name}:\{u.type_}")
        }
      }
      g8_flow_json(
        flow.code,
        flow.result_snippet(),
        flow.vars.unwrap_or(""),
        FixedArray::from_array(uniforms),
        b.get_codes(stage),
        decl,
        g8_bindings(b),
      )
    }
    Compute(make) => {
      let b = @webgpu.WGSLNodeBuilder::new(NoObject, renderer)
      b.compute = Some(make())
      b.build() |> ignore
      g8_shader_json(b.compute_shader.unwrap_or("undefined"), g8_bindings(b))
    }
    Material(vertex, fragment) => {
      let mesh = @core.Mesh::new(
        geometry=g8_geometry,
        material=Single(@core.MeshBasicMaterial::new()),
      )
      let b = @webgpu.WGSLNodeBuilder::new(Object3D(mesh), renderer)
      b.scene = Some(@core.Scene::new())
      b.camera = Some(@core.PerspectiveCamera::new())
      if scenario.pre is Some(pre) {
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
      g8_shader_json(
        b.vertex_shader.unwrap_or("undefined") +
        "\n@@@@\n" +
        b.fragment_shader.unwrap_or("undefined"),
        g8_bindings(b),
      )
    }
  }
}

///|
test "g8 shader scenarios run (compared with upstream by run.mjs)" {
  let renderers = {
    "a": g8_renderer([], false),
    "b": g8_renderer(["subgroups"], false),
    "c": g8_renderer([], true),
    "d": g8_renderer([], false),
  }
  renderers.get("d").unwrap().debug.diagnostics.keywords = true
  let only = g8_only()
  for scenario in g8_scenarios() {
    if only != "" && only != scenario.name {
      continue
    }
    let record = g8_run(scenario, renderers.get(scenario.renderer).unwrap())
    if g8_shader_diff_enabled() {
      println("@@SHADER \{scenario.name} \{record}")
    }
  }
}

///|
/// `G8_ONLY=<name>` runs one scenario (debugging aid).
extern "js" fn g8_only() -> String = "() => (typeof process !== 'undefined' && process.env.G8_ONLY) || ''"
