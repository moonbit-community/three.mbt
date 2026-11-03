// Group 2 differential scenarios for WebGLUniforms, WebGLUniformsGroups, WebGLProgram and
// WebGLPrograms, mirroring harness/scenarios/programs_*.mjs in the diff/core/webgl
// harness step by step.

///|
/// The active uniforms of programs_uniforms.mjs (`UNIFORMS` there), as mock JSON.
let programs_uniform_spec : String =
  #|[
  #| {"name":"f","type":5126},{"name":"v2","type":35664},{"name":"v3","type":35665},{"name":"c3","type":35665},
  #| {"name":"a3","type":35665},{"name":"v4","type":35666},{"name":"q4","type":35666},{"name":"m2","type":35674},
  #| {"name":"m3","type":35675},{"name":"m4","type":35676},{"name":"m4a","type":35676},{"name":"i","type":5124},
  #| {"name":"b","type":35670},{"name":"iv2","type":35667},{"name":"iv3","type":35668},{"name":"iv4","type":35669},
  #| {"name":"bv2","type":35671},{"name":"u","type":5125},{"name":"uv2","type":36294},{"name":"uv3","type":36295},
  #| {"name":"uv4","type":36296},
  #| {"name":"s2d","type":35678},{"name":"scube","type":35680},{"name":"s3d","type":35679},{"name":"s2da","type":36289},
  #| {"name":"sshadow","type":35682},{"name":"scubeshadow","type":36293},{"name":"s2dashadow","type":36292},
  #| {"name":"is2d","type":36298},
  #| {"name":"fa[0]","type":5126,"size":3},{"name":"v2a[0]","type":35664,"size":2},{"name":"v3a[0]","type":35665,"size":2},
  #| {"name":"v4a[0]","type":35666,"size":2},{"name":"m2a[0]","type":35674,"size":2},{"name":"m3a[0]","type":35675,"size":2},
  #| {"name":"m4a2[0]","type":35676,"size":2},{"name":"ia[0]","type":5124,"size":2},{"name":"iv2a[0]","type":35667,"size":2},
  #| {"name":"iv3a[0]","type":35668,"size":1},{"name":"iv4a[0]","type":35669,"size":1},{"name":"ua[0]","type":5125,"size":2},
  #| {"name":"uv2a[0]","type":36294,"size":1},{"name":"uv3a[0]","type":36295,"size":1},{"name":"uv4a[0]","type":36296,"size":1},
  #| {"name":"texa[0]","type":35678,"size":3},{"name":"shadowa[0]","type":35682,"size":2},{"name":"cubea[0]","type":35680,"size":2},
  #| {"name":"s3da[0]","type":35679,"size":1},{"name":"s2daa[0]","type":36289,"size":2},{"name":"cubesha[0]","type":36293,"size":1},
  #| {"name":"light.position","type":35665},{"name":"light.color","type":35665},{"name":"light.intensity","type":5126},
  #| {"name":"lights[0].dir","type":35665},{"name":"lights[0].col","type":35665},{"name":"lights[1].dir","type":35665},
  #| {"name":"lights[1].col","type":35665},{"name":"s.inner.x","type":5126},{"name":"s.arr[0]","type":5126,"size":2},
  #| {"name":"ps[0].bias","type":5126},{"name":"ps[0].map","type":35682},{"name":"ps[1].bias","type":5126},{"name":"ps[1].map","type":35682},
  #| {"name":"bindMatrix","type":35676},{"name":"bindMatrixInverse","type":35676}
  #|]

///|
/// The modules `WebGLTextures` needs, built as the scenarios build them upstream.
struct ProgramsModules {
  capabilities : @webgl.WebGLCapabilities
  state : @webgl.WebGLState
  info : @webgl.WebGLInfo
  textures : @webgl.WebGLTextures
}

///|
fn programs_modules(gl : @webgl.WebGL2RenderingContext) -> ProgramsModules {
  let extensions = @webgl.WebGLExtensions::new(gl)
  let utils = @webgl.WebGLUtils::new(gl, extensions)
  let capabilities = @webgl.WebGLCapabilities::new(
    gl,
    extensions,
    {
      precision: None,
      logarithmic_depth_buffer: false,
      reversed_depth_buffer: false,
    },
    utils,
  )
  let state = @webgl.WebGLState::new(gl, extensions)
  let properties = @webgl.WebGLProperties::new()
  let info = @webgl.WebGLInfo::new(gl)
  let textures = @webgl.WebGLTextures::new(
    gl, extensions, state, properties, capabilities, utils, info,
  )
  { capabilities, state, info, textures, }
}

///|
/// `describe( seq )` of programs_uniforms.mjs.
fn programs_describe(seq : Array[@webgl.WebGLUniformSetter]) -> String {
  seq
  .map(fn(u) {
    match u {
      Structured(s) => s.id.key() + "{" + programs_describe(s.seq) + "}"
      Single(s) => s.id.key() + ":" + s.type_.to_string()
      PureArray(s) => s.id.key() + ":" + s.type_.to_string() + "[\{s.size}]"
    }
  })
  .join(" ")
}

///|
fn programs_uniform(value : @core.UniformValue) -> @core.Uniform {
  @core.Uniform::new(value)
}

///|
fn programs_struct(
  entries : Array[(String, @core.UniformValue)],
) -> @core.UniformValue {
  Struct(Map::from_array(entries))
}

///|
fn programs_float32_filled(n : Int32, value : Double) -> @core.TypedArray {
  let t = @core.TypedArray::float32(n)
  t.fill(value)
  t
}

///|
fn programs_v3(x : Double, y : Double, z : Double) -> @core.UniformValue {
  Vector3(@math.Vector3::new(x, y, z))
}

///|
fn programs_color(r : Double, g : Double, b : Double) -> @core.UniformValue {
  Color(@math.Color::new(r, g, b))
}

///|
fn programs_m3_123() -> @math.Matrix3 {
  @math.Matrix3::new().set(1.0, 2, 3, 4, 5, 6, 7, 8, 9)
}

///|
test "diff programs_uniforms" {
  let gl = mock_gl(
    options="{\"programs\":[{\"attributes\":[],\"uniforms\":" +
      programs_uniform_spec +
      "}],\"canvas\":{\"width\":64,\"height\":32}}",
  )
  let modules = programs_modules(gl)
  let textures = modules.textures
  mock_clear(gl)
  let program = gl.create_program()
  let uniforms = @webgl.WebGLUniforms::new(gl, program)
  note_str(gl, "seq", programs_describe(uniforms.seq))
  note_str(gl, "map", uniforms.map.keys().collect().join(" "))
  guard uniforms.map["lights"] is Structured(lights) else { fail("lights") }
  note_str(gl, "lights.map", lights.map.keys().collect().join(" "))
  let tex = @core.Texture::new()
  let cube = @core.CubeTexture::new()
  let t3d = @core.Data3DTexture::new()
  let t2da = @core.DataArrayTexture::new()
  let v2 = @math.Vector2::new(1.0, 2.0)
  let v3 = @math.Vector3::new(1.0, 2.0, 3.0)
  let c3 = @math.Color::new(0.25, 0.5, 0.75)
  let m3 = programs_m3_123()
  let m4 = @math.Matrix4::new().make_translation(1.0, 2.0, 3.0)
  let light_color = @math.Color::new(0.0, 1.0, 0.0)
  let values : Map[String, @core.Uniform] = Map::from_array([
    ("f", programs_uniform(Number(0.5))),
    ("v2", programs_uniform(Vector2(v2))),
    ("v3", programs_uniform(Vector3(v3))),
    ("c3", programs_uniform(Color(c3))),
    ("a3", programs_uniform(Numbers([4.0, 5, 6]))),
    ("v4", programs_uniform(Vector4(@math.Vector4::new(1.0, 2.0, 3.0, 4.0)))),
    (
      "q4",
      programs_uniform(Quaternion(@math.Quaternion::new(0.0, 0.0, 0.0, 1.0))),
    ),
    ("m2", programs_uniform(Numbers([1.0, 0, 0, 1]))),
    ("m3", programs_uniform(Matrix3(m3))),
    ("m4", programs_uniform(Matrix4(m4))),
    ("m4a", programs_uniform(TypedArray(programs_float32_filled(16, 0.1)))),
    ("i", programs_uniform(Int(3))),
    ("b", programs_uniform(Bool(true))),
    ("iv2", programs_uniform(Vector2(@math.Vector2::new(1.0, 2.0)))),
    ("iv3", programs_uniform(Numbers([1.0, 2, 3]))),
    ("iv4", programs_uniform(Vector4(@math.Vector4::new(1.0, 2.0, 3.0, 4.0)))),
    ("bv2", programs_uniform(Numbers([1.0, 0]))),
    ("u", programs_uniform(Number(7.0))),
    ("uv2", programs_uniform(Numbers([1.0, 2]))),
    ("uv3", programs_uniform(Vector3(@math.Vector3::new(1.0, 2.0, 3.0)))),
    (
      "uv4",
      programs_uniform(TypedArray(@core.TypedArray::int32([1.0, 2, 3, 4]))),
    ),
    ("s2d", programs_uniform(Texture(tex))),
    ("scube", programs_uniform(Null)),
    ("s3d", programs_uniform(Texture(t3d))),
    ("s2da", programs_uniform(Null)),
    ("sshadow", programs_uniform(Null)),
    ("scubeshadow", programs_uniform(Null)),
    ("s2dashadow", programs_uniform(Texture(t2da))),
    ("is2d", programs_uniform(Texture(tex))),
    ("fa", programs_uniform(Numbers([1.0, 2, 3]))),
    (
      "v2a",
      programs_uniform(
        Array([
          Vector2(@math.Vector2::new(1.0, 2.0)),
          Vector2(@math.Vector2::new(3.0, 4.0)),
        ]),
      ),
    ),
    (
      "v3a",
      programs_uniform(
        Array([programs_v3(1.0, 2.0, 3.0), programs_color(0.5, 0.25, 1.0)]),
      ),
    ),
    ("v4a", programs_uniform(TypedArray(programs_float32_filled(8, 2.0)))),
    ("m2a", programs_uniform(Numbers([1.0, 0, 0, 1, 2, 0, 0, 2]))),
    (
      "m3a",
      programs_uniform(
        Array([Matrix3(@math.Matrix3::new()), Matrix3(programs_m3_123())]),
      ),
    ),
    (
      "m4a2",
      programs_uniform(
        Array([
          Matrix4(@math.Matrix4::new()),
          Matrix4(@math.Matrix4::new().make_scale(2.0, 3.0, 4.0)),
        ]),
      ),
    ),
    ("ia", programs_uniform(Numbers([1.0, 2]))),
    (
      "iv2a",
      programs_uniform(TypedArray(@core.TypedArray::int32([1.0, 2, 3, 4]))),
    ),
    ("iv3a", programs_uniform(Numbers([1.0, 2, 3]))),
    ("iv4a", programs_uniform(Numbers([1.0, 2, 3, 4]))),
    ("ua", programs_uniform(Numbers([5.0, 6]))),
    ("uv2a", programs_uniform(Numbers([1.0, 2]))),
    (
      "uv3a",
      programs_uniform(TypedArray(@core.TypedArray::uint32([1.0, 2, 3]))),
    ),
    ("uv4a", programs_uniform(Numbers([1.0, 2, 3, 4]))),
    ("texa", programs_uniform(Array([Texture(tex), Null, Texture(tex)]))),
    ("shadowa", programs_uniform(Array([Null, Null]))),
    ("cubea", programs_uniform(Array([Texture(cube), Null]))),
    ("s3da", programs_uniform(Array([Texture(t3d)]))),
    ("s2daa", programs_uniform(Array([Null, Texture(t2da)]))),
    ("cubesha", programs_uniform(Array([Null]))),
    (
      "light",
      programs_uniform(
        programs_struct([
          ("position", programs_v3(1.0, 1.0, 1.0)),
          ("color", programs_color(1.0, 0.0, 0.0)),
          ("intensity", Number(2.0)),
        ]),
      ),
    ),
    (
      "lights",
      programs_uniform(
        Array([
          programs_struct([
            ("dir", programs_v3(0.0, 1.0, 0.0)),
            ("col", programs_color(1.0, 1.0, 1.0)),
          ]),
          programs_struct([
            ("dir", programs_v3(1.0, 0.0, 0.0)),
            ("col", Color(light_color)),
          ]),
        ]),
      ),
    ),
    (
      "s",
      programs_uniform(
        programs_struct([
          ("inner", programs_struct([("x", Number(4.0))])),
          ("arr", Numbers([7.0, 8])),
        ]),
      ),
    ),
    (
      "ps",
      programs_uniform(
        Array([
          programs_struct([("bias", Number(0.1)), ("map", Null)]),
          programs_struct([("bias", Number(0.2)), ("map", Texture(tex))]),
        ]),
      ),
    ),
    ("bindMatrix", programs_uniform(Matrix4(@math.Matrix4::new()))),
    ("bindMatrixInverse", programs_uniform(Matrix4(@math.Matrix4::new()))),
  ])
  textures.reset_texture_units()
  @webgl.WebGLUniforms::upload(gl, uniforms.seq, values, textures)
  note_int(gl, "frame", 2)
  textures.reset_texture_units()
  @webgl.WebGLUniforms::upload(gl, uniforms.seq, values, textures)
  note_int(gl, "frame", 3)
  values["f"].value = Number(0.75)
  ignore(v2.set(2.0, 2.0))
  ignore(c3.set_rgb(1.0, 1.0, 1.0))
  values["a3"].value = Numbers([4.0, 5, 7])
  ignore(m3.set(9.0, 8, 7, 6, 5, 4, 3, 2, 1))
  ignore(m4.make_rotation_x(0.5))
  values["m2"].value = Numbers([2.0, 0, 0, 2])
  values["b"].value = Bool(false)
  values["iv3"].value = Numbers([1.0, 2, 4])
  values["u"].value = Number(8.0)
  guard values["light"].value is Struct(light) else { fail("light") }
  light["intensity"] = Number(3.0)
  ignore(light_color.set_rgb(0.0, 0.0, 1.0))
  @webgl.set_uniform_needs_update(values["v3"], false)
  ignore(v3.set(9.0, 9.0, 9.0))
  textures.reset_texture_units()
  ignore(textures.allocate_texture_unit())
  @webgl.WebGLUniforms::upload(gl, uniforms.seq, values, textures)
  note_int(gl, "frame", 4)
  uniforms.set_value(gl, "f", Number(0.75))
  uniforms.set_value(gl, "f", Number(1.0))
  uniforms.set_value(gl, "i", Int(4))
  uniforms.set_value(gl, "b", Bool(true))
  uniforms.set_value(gl, "missing", Number(1.0))
  uniforms.set_value(gl, "v3", programs_v3(9.0, 9.0, 9.0))
  uniforms.set_value(gl, "v4", Numbers([5.0, 6, 7, 8]))
  uniforms.set_value(gl, "v4", Numbers([5.0, 6, 7, 8]))
  uniforms.set_value(
    gl,
    "m4",
    Matrix4(@math.Matrix4::new().make_scale(1.0, 2.0, 3.0)),
  )
  uniforms.set_value(gl, "m4", TypedArray(programs_float32_filled(16, 0.5)))
  textures.reset_texture_units()
  uniforms.set_value(gl, "s2d", Texture(tex), textures~)
  uniforms.set_value(gl, "s2d", Null, textures~)
  uniforms.set_value(
    gl,
    "texa",
    Array([Texture(tex), Texture(tex), Texture(tex)]),
    textures~,
  )
  let skinned = @core.SkinnedMesh::new(
    geometry=@core.BufferGeometry::new(),
    material=Single(@core.MeshBasicMaterial::new()),
  )
  guard skinned.kind is Mesh({ kind: SkinnedMesh(skin), .. }) else {
    fail("skinned")
  }
  ignore(skin.bind_matrix.make_translation(1.0, 0.0, 0.0))
  ignore(skin.bind_matrix_inverse.make_translation(-1.0, 0.0, 0.0))
  uniforms.set_optional(gl, skinned, "bindMatrix")
  uniforms.set_optional(gl, skinned, "bindMatrixInverse")
  uniforms.set_optional(gl, @core.Mesh::new(), "bindMatrix")
  let subset = @webgl.WebGLUniforms::seq_with_value(
    uniforms.seq,
    Map::from_array([
      ("f", programs_uniform(Number(1.0))),
      ("light", programs_uniform(programs_struct([]))),
      ("nothere", programs_uniform(Number(0.0))),
    ]),
  )
  note_str(gl, "seqWithValue", subset.map(fn(u) { u.id().key() }).join(" "))
  let log = emit_log("programs_uniforms", gl)
  assert_true(log.length() > 100)
}

///|
/// A `WebGLProgram` stand-in holding just a GL program, as `{ program }` upstream.
fn programs_fake_program(
  gl : @webgl.WebGL2RenderingContext,
  program : @webgl.GLProgram,
) -> @webgl.WebGLProgram {
  {
    type_: "",
    name: "",
    id: 0,
    cache_key: "",
    used_times: 1,
    program: Some(program),
    vertex_shader: @webgl.uninitialized(),
    fragment_shader: @webgl.uninitialized(),
    diagnostics: None,
    renderer: @webgl.uninitialized(),
    gl,
    binding_states: @webgl.uninitialized(),
    prefix_vertex: "",
    prefix_fragment: "",
    cached_uniforms: None,
    cached_attributes: None,
    program_ready: true,
  }
}

///|
test "diff programs_uniforms_groups" {
  let gl = mock_gl()
  let modules = programs_modules(gl)
  let groups = @webgl.WebGLUniformsGroups::new(
    gl,
    modules.info,
    modules.capabilities,
    modules.state,
  )
  mock_clear(gl)
  let program = programs_fake_program(gl, gl.create_program())
  let program2 = programs_fake_program(gl, gl.create_program())
  let f = programs_uniform(Number(0.5))
  let v2 = programs_uniform(Vector2(@math.Vector2::new(1.0, 2.0)))
  let v3_value = @math.Vector3::new(1.0, 2.0, 3.0)
  let v3 = programs_uniform(Vector3(v3_value))
  let f2 = programs_uniform(Number(2.0))
  let c_value = @math.Color::new(1.0, 0.5, 0.25)
  let c = programs_uniform(Color(c_value))
  let v4 = programs_uniform(Vector4(@math.Vector4::new(1.0, 2.0, 3.0, 4.0)))
  let m3_value = programs_m3_123()
  let m3 = programs_uniform(Matrix3(m3_value))
  let m4 = programs_uniform(
    Matrix4(@math.Matrix4::new().make_translation(1.0, 2.0, 3.0)),
  )
  let b = programs_uniform(Bool(true))
  let i = programs_uniform(Number(3.0))
  @webgl.set_uniform_type(i, "int")
  let u = programs_uniform(Number(4.0))
  @webgl.set_uniform_type(u, "uint")
  let arr1_value = @math.Vector3::new(1.0, 1.0, 1.0)
  let arr = [
    programs_uniform(Number(1.0)),
    programs_uniform(Vector3(arr1_value)),
  ]
  let va2_value = @math.Vector3::new(5.0, 6.0, 7.0)
  let value_array = programs_uniform(
    Array([
      Vector2(@math.Vector2::new(1.0, 2.0)),
      Vector2(@math.Vector2::new(3.0, 4.0)),
      Vector3(va2_value),
    ]),
  )
  let numbers_value = [1.0, 2, 3]
  let numbers = programs_uniform(Numbers(numbers_value))
  let typed = programs_uniform(
    TypedArray(@core.TypedArray::float32([1.0, 2, 3, 4, 5, 6, 7, 8])),
  )
  let group = @core.UniformsGroup::new().set_name("Settings")
  ignore(
    group
    .add(f)
    .add(v2)
    .add(v3)
    .add(f2)
    .add(c)
    .add(v4)
    .add(m3)
    .add(m4)
    .add(b)
    .add(i)
    .add(u),
  )
  ignore(group.add_array(arr))
  ignore(group.add(value_array).add(numbers).add(typed))
  let small = @core.UniformsGroup::new().set_name("Small")
  ignore(small.set_usage(@core.DynamicDrawUsage))
  ignore(small.add(programs_uniform(Number(1.0))))
  groups.update(group, program)
  groups.bind(group, program)
  groups.update(group, program)
  groups.bind(group, program)
  note_int(gl, "frame", 1)
  modules.info.render.frame = 1
  groups.update(group, program)
  modules.info.render.frame = 2
  f.value = Number(0.75)
  ignore(v3_value.set(3.0, 2.0, 1.0))
  ignore(c_value.set_rgb(0.0, 0.0, 1.0))
  ignore(m3_value.set(9.0, 8, 7, 6, 5, 4, 3, 2, 1))
  b.value = Bool(false)
  ignore(arr1_value.set(2.0, 2.0, 2.0))
  ignore(va2_value.set(7.0, 6.0, 5.0))
  numbers_value[1] = 9.0
  groups.update(group, program)
  groups.update(group, program2)
  groups.bind(group, program2)
  groups.update(small, program)
  groups.bind(small, program)
  modules.info.render.frame = 3
  groups.update(small, program)
  small.dispose()
  groups.update(small, program2)
  groups.dispose()
  group.dispose()
  let log = emit_log("programs_uniforms_groups", gl)
  assert_true(log.contains("bufferData(35345, 352, 35044)"))
}
