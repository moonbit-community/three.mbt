// Group 3 differential scenarios (lights_, materials_, shadow_, morph_, background_,
// env_, output_, pmrem_). Each test mirrors harness/scenarios/<name>.mjs in the
// diff/core/webgl harness; values are flattened to JS arrays as harness/group3_util.mjs
// does, so the mock keeps them in its notes.

///|
fn g3_arr(items : Array[@core.JsValue]) -> @core.JsValue {
  @core.JsValue::of(items)
}

///|
fn g3_num(value : Double) -> @core.JsValue {
  @core.JsValue::of(value)
}

///|
fn g3_str(value : String) -> @core.JsValue {
  @core.JsValue::of(value)
}

///|
fn g3_nums(values : Array[Double]) -> @core.JsValue {
  g3_arr(values.map(g3_num))
}

///|
fn g3_texture(texture : @core.Texture) -> @core.JsValue {
  g3_str("tex:" + texture.name)
}

///|
fn g3_opt_texture(texture : @core.Texture?) -> @core.JsValue {
  match texture {
    Some(texture) => g3_texture(texture)
    None => @core.JsValue::null()
  }
}

///|
/// `ser( value )` of group3_util.mjs.
fn g3_ser(value : @core.UniformValue) -> @core.JsValue {
  match value {
    Null => @core.JsValue::null()
    Bool(b) => @core.JsValue::of(b)
    Int(i) => g3_num(i.to_double())
    Number(n) => g3_num(n)
    Numbers(a) => g3_nums(a)
    Vector2(v) => g3_nums([v.x, v.y])
    Vector3(v) => g3_nums([v.x, v.y, v.z])
    Vector4(v) => g3_nums([v.x, v.y, v.z, v.w])
    Color(c) => g3_nums([c.r, c.g, c.b])
    Quaternion(q) => g3_nums([q.x, q.y, q.z, q.w])
    Matrix3(m) => g3_nums(m.elements.copy())
    Matrix4(m) => g3_nums(m.elements.copy())
    Plane(p) =>
      g3_arr([g3_nums([p.normal.x, p.normal.y, p.normal.z]), g3_num(p.constant)])
    Texture(t) => g3_texture(t)
    TypedArray(t) => g3_nums(Array::makei(t.length(), fn(i) { t.get(i) }))
    Array(a) => g3_arr(a.map(g3_ser))
    Struct(m) => {
      let entries = []
      for k, v in m {
        entries.push(g3_arr([g3_str(k), g3_ser(v)]))
      }
      g3_arr(entries)
    }
    Other(v) => if v.is_undefined() { g3_str("undefined") } else { v }
  }
}

///|
/// `noteLightState( gl, label, state, v0 )` of group3_util.mjs.
fn g3_note_light_state(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  state : @webgl.WebGLLightsState,
  v0 : Int32,
) -> Unit {
  let h = state.hash
  note_int(gl, label + " version", state.version - v0)
  mock_note(
    gl,
    label + " hash",
    g3_nums(
      [
        h.sun_length,
        h.directional_length,
        h.point_length,
        h.spot_length,
        h.rect_area_length,
        h.hemi_length,
        h.num_sun_shadows,
        h.num_directional_shadows,
        h.num_point_shadows,
        h.num_spot_shadows,
        h.num_spot_maps,
        h.num_light_probes,
      ].map(Int32::to_double),
    ),
  )
  let fields : Array[(String, @core.JsValue)] = [
    ("ambient", g3_nums(state.ambient)),
    ("probe", g3_ser(Array(state.probe))),
    ("sun", g3_ser(Array(state.sun))),
    ("sunShadow", g3_ser(Array(state.sun_shadow))),
    ("sunShadowMap", g3_ser(Array(state.sun_shadow_map))),
    ("sunShadowMatrix", g3_ser(Array(state.sun_shadow_matrix))),
    ("sunShadowCascade", g3_ser(Array(state.sun_shadow_cascade))),
    ("directional", g3_ser(Array(state.directional))),
    ("directionalShadow", g3_ser(Array(state.directional_shadow))),
    ("directionalShadowMap", g3_ser(Array(state.directional_shadow_map))),
    ("directionalShadowMatrix", g3_ser(Array(state.directional_shadow_matrix))),
    ("spot", g3_ser(Array(state.spot))),
    ("spotLightMap", g3_ser(Array(state.spot_light_map))),
    ("spotShadow", g3_ser(Array(state.spot_shadow))),
    ("spotShadowMap", g3_ser(Array(state.spot_shadow_map))),
    ("spotLightMatrix", g3_ser(Array(state.spot_light_matrix))),
    ("rectArea", g3_ser(Array(state.rect_area))),
    ("rectAreaLTC1", g3_opt_texture(state.rect_area_ltc1)),
    ("rectAreaLTC2", g3_opt_texture(state.rect_area_ltc2)),
    ("point", g3_ser(Array(state.point))),
    ("pointShadow", g3_ser(Array(state.point_shadow))),
    ("pointShadowMap", g3_ser(Array(state.point_shadow_map))),
    ("pointShadowMatrix", g3_ser(Array(state.point_shadow_matrix))),
    ("hemi", g3_ser(Array(state.hemi))),
    (
      "numSpotLightShadowsWithMaps",
      g3_num(state.num_spot_light_shadows_with_maps.to_double()),
    ),
    ("numLightProbes", g3_num(state.num_light_probes.to_double())),
  ]
  for field in fields {
    mock_note(gl, label + " " + field.0, field.1)
  }
}

///|
/// `noteUniforms( gl, label, uniforms )` of group3_util.mjs: sorted by name.
fn g3_note_uniforms(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  uniforms : Map[String, @core.Uniform],
) -> Unit {
  for name in g3_js_sort(FixedArray::from_array(uniforms.keys().collect())) {
    mock_note(gl, label + " " + name, g3_ser(uniforms.get(name).unwrap().value))
  }
}

///|
/// JS `array.slice().sort()` (UTF-16 order; MoonBit's `String` order differs).
extern "js" fn g3_js_sort(names : FixedArray[String]) -> FixedArray[String] = "(a) => a.slice().sort()"

///|
/// Appends `prefix + entry` for every call recorded on `from` to `into`'s log.
extern "js" fn g3_merge_log(
  into : @webgl.WebGL2RenderingContext,
  from : @webgl.WebGL2RenderingContext,
  prefix : String,
) -> Unit = "(a, b, p) => { for (const e of b.__log) a.__log.push(p + e); }"

///|
fn g3_named_texture(name : String) -> @core.Texture {
  let texture = @core.Texture::new()
  texture.name = name
  texture
}

///|
/// The fake addon `SunLight` of the lights scenario.
struct G3SunShadow {
  matrices : Array[@math.Matrix4]
  cascades : Array[@math.Vector4]
}

///|
impl @webgl.SunLightShadowSource for G3SunShadow with fn get_matrix(self, j) {
  self.matrices[j]
}

///|
impl @webgl.SunLightShadowSource for G3SunShadow with fn cascade_data(self, j) {
  Vector4(self.cascades[j])
}

///|
struct G3SunExtension {}

///|
impl @core.Object3DExtension for G3SunExtension with fn type_name(_) {
  "SunLight"
}

///|
impl @core.Object3DExtension for G3SunExtension with fn construct(_) {
  @core.DirectionalLight::new()
}

///|
impl @core.Object3DExtension for G3SunExtension with fn has_flag(_, flag) {
  flag == "isSunLight"
}

///|
fn g3_place(
  light : @core.Object3D,
  name : String,
  x : Double,
  y : Double,
  z : Double,
  target? : (Double, Double, Double),
) -> @core.Object3D {
  light.name = name
  ignore(light.position.set(x, y, z))
  light.update_matrix_world()
  if target is Some((tx, ty, tz)) {
    let t = light.light_target()
    ignore(t.position.set(tx, ty, tz))
    t.update_matrix_world()
  }
  light
}

///|
fn g3_light_names(lights : Array[@core.Object3D]) -> @core.JsValue {
  g3_arr(lights.map(fn(l) { g3_str(l.name) }))
}

///|
test "diff lights_all" {
  @webgl.uniforms_lib_ltc.ltc_float_1 = Some(g3_named_texture("ltc_float_1"))
  @webgl.uniforms_lib_ltc.ltc_float_2 = Some(g3_named_texture("ltc_float_2"))
  @webgl.uniforms_lib_ltc.ltc_half_1 = Some(g3_named_texture("ltc_half_1"))
  @webgl.uniforms_lib_ltc.ltc_half_2 = Some(g3_named_texture("ltc_half_2"))
  let gl = mock_gl()
  let lights = @webgl.WebGLLights::new(@webgl.WebGLExtensions::new(gl))
  let camera = @core.PerspectiveCamera::new(
    fov=60,
    aspect=1.5,
    near=0.5,
    far=50,
  )
  ignore(camera.position.set(3, 4, 5))
  camera.look_at_xyz(0, 1, 0)
  camera.update_matrix_world()
  let ambient1 = @core.AmbientLight::new(
    color=@math.Color::new(0.2, 0.3, 0.4),
    intensity=0.5,
  )
  ambient1.name = "ambient1"
  let ambient2 = @core.AmbientLight::new(
    color=@math.Color::new(1, 0.5, 0.25),
    intensity=2,
  )
  ambient2.name = "ambient2"
  let sh = @math.SphericalHarmonics3::new()
  for i in 0..<9 {
    let f = i.to_double()
    ignore(sh.coefficients[i].set(f * 0.1, -f * 0.05, 0.3 + f))
  }
  let probe = @core.LightProbe::new(sh~, intensity=0.7)
  probe.name = "probe"
  let hemi = g3_place(
    @core.HemisphereLight::new(
      sky_color=@math.Color::new(0.9, 0.8, 0.7),
      ground_color=@math.Color::new(0.1, 0.2, 0.3),
      intensity=1.3,
    ),
    "hemi",
    0,
    10,
    2,
  )
  let dir1 = g3_place(
    @core.DirectionalLight::new(
      color=@math.Color::new(1, 0.9, 0.8),
      intensity=1.5,
    ),
    "dir1",
    5,
    10,
    7,
    target=(1, 0, -1),
  )
  dir1.cast_shadow = true
  let dir1_shadow = dir1.as_light().shadow.unwrap()
  dir1_shadow.bias = -0.001
  dir1_shadow.normal_bias = 0.02
  dir1_shadow.radius = 3
  dir1_shadow.intensity = 0.8
  ignore(dir1_shadow.map_size.set(1024, 512))
  let dir1_map = @core.RenderTarget::new(width=16, height=16)
  dir1_map.texture().name = "dir1.color"
  dir1_map.set_depth_texture(Some(@core.DepthTexture::new(width=16, height=16)))
  dir1_map.depth_texture().unwrap().name = "dir1.depth"
  dir1_shadow.map = Some(dir1_map)
  let dir2 = g3_place(
    @core.DirectionalLight::new(
      color=@math.Color::from_hex(0xff8800),
      intensity=0.25,
    ),
    "dir2",
    -3,
    2,
    1,
    target=(0, 0, 0),
  )
  let point1 = g3_place(
    @core.PointLight::new(
      color=@math.Color::new(0.5, 1, 0.5),
      intensity=3,
      distance=20,
      decay=1.5,
    ),
    "point1",
    1,
    2,
    3,
  )
  point1.cast_shadow = true
  let point1_shadow = point1.as_light().shadow.unwrap()
  point1_shadow.camera.as_perspective_camera().near = 0.25
  point1_shadow.camera.as_perspective_camera().far = 30
  let point1_map = @core.RenderTarget::new(width=8, height=8)
  point1_map.texture().name = "point1.vsm"
  point1_map.texture().format = @core.RGFormat
  point1_shadow.map = Some(point1_map)
  let point2 = g3_place(
    @core.PointLight::new(color=@math.Color::from_hex(0x2244ff), intensity=1),
    "point2",
    -1,
    0.5,
    -2,
  )
  let spot_map = g3_named_texture("spotMap")
  let pi = 3.141592653589793
  let spot1 = g3_place(
    @core.SpotLight::new(
      color=@math.Color::from_hex(0xffffff),
      intensity=2,
      distance=15,
      angle=pi / 5,
      penumbra=0.3,
      decay=2,
    ),
    "spot1",
    0,
    6,
    0,
    target=(0, 0, 0.5),
  )
  spot1.as_spot_light().map = Some(spot_map)
  spot1.cast_shadow = true
  let spot1_map = @core.RenderTarget::new(width=4, height=4)
  spot1_map.texture().name = "spot1.color"
  spot1.as_light().shadow.unwrap().map = Some(spot1_map)
  let spot2 = g3_place(
    @core.SpotLight::new(
      color=@math.Color::from_hex(0xff0000),
      intensity=1,
      distance=0,
      angle=pi / 3,
      penumbra=0.5,
      decay=1,
    ),
    "spot2",
    2,
    3,
    -4,
    target=(1, 0, 0),
  )
  spot2.as_spot_light().map = Some(spot_map)
  let spot3 = g3_place(
    @core.SpotLight::new(
      color=@math.Color::from_hex(0x00ff00),
      intensity=1.2,
      distance=8,
      angle=0.4,
      penumbra=0,
      decay=2,
    ),
    "spot3",
    -2,
    5,
    1,
    target=(0, 1, 0),
  )
  spot3.cast_shadow = true
  let spot4 = g3_place(
    @core.SpotLight::new(color=@math.Color::from_hex(0x0000ff), intensity=0.6),
    "spot4",
    4,
    4,
    4,
    target=(-1, -1, -1),
  )
  let rect1 = g3_place(
    @core.RectAreaLight::new(
      color=@math.Color::from_hex(0xffeedd),
      intensity=4,
      width=3,
      height=2,
    ),
    "rect1",
    0,
    3,
    -5,
  )
  ignore(rect1.rotation.set(0.3, -0.4, 0.2))
  rect1.update_matrix_world()
  let rect2 = g3_place(
    @core.RectAreaLight::new(
      color=@math.Color::from_hex(0x88ccff),
      intensity=1,
      width=1,
      height=6,
    ),
    "rect2",
    2,
    1,
    0,
  )
  let sun = g3_place(
    @core.DirectionalLight::new(
      color=@math.Color::new(1, 1, 0.9),
      intensity=2.5,
    ),
    "sun",
    30,
    50,
    20,
    target=(0, 0, 0),
  )
  ignore(sun.set_extension(G3SunExtension::{ }))
  sun.cast_shadow = true
  let sun_shadow = sun.as_light().shadow.unwrap()
  sun_shadow._viewport_count = 2
  sun_shadow._frame_extents = @math.Vector2::new(2, 1)
  ignore(sun_shadow.map_size.set(256, 256))
  @webgl.register_sun_light(sun, G3SunShadow::{
    matrices: [
      @math.Matrix4::new().make_translation(1, 2, 3),
      @math.Matrix4::new().make_scale(2, 3, 4),
    ],
    cascades: [
      @math.Vector4::new(0, 10, 0, 0),
      @math.Vector4::new(10, 40, 0, 0),
    ],
  })
  let all = [
    ambient1, spot4, dir2, probe, hemi, point2, spot3, rect1, dir1, spot2, point1,
    spot1, rect2, ambient2, sun,
  ]
  lights.setup(all)
  let v0 = lights.state.version
  mock_note(gl, "sorted", g3_light_names(all))
  g3_note_light_state(gl, "setup", lights.state, v0)
  lights.setup_view(all, camera)
  g3_note_light_state(gl, "view", lights.state, v0)
  let directional_array = lights.state.directional
  guard lights.state.directional[0] is Struct(first_directional) else {
    fail("directional[0]")
  }

  // same lights again: no hash change
  dir1.as_light().intensity = 0.5
  ignore(hemi.as_light().color.set_rgb(0.1, 0.1, 0.1))
  spot1.as_spot_light().angle = 0.2
  match point1.as_light().kind {
    PointLight(p) => p.distance = 0
    _ => ()
  }
  ignore(dir1_shadow.map_size.set(64, 64))
  ignore(sun_shadow._frame_extents.set(1, 3))
  lights.setup(all)
  g3_note_light_state(gl, "again", lights.state, v0)
  let still_first = match lights.state.directional[0] {
    Struct(m) => physical_equal(m, first_directional)
    _ => false
  }
  mock_note(
    gl,
    "shared",
    g3_arr([
      @core.JsValue::of(
        physical_equal(lights.state.directional, directional_array),
      ),
      @core.JsValue::of(still_first),
    ]),
  )

  // fewer lights: the hash changes and the arrays shrink in place
  let fewer = [spot2, rect1, dir2, point1, probe]
  point1.cast_shadow = false
  lights.setup(fewer)
  mock_note(gl, "sorted fewer", g3_light_names(fewer))
  g3_note_light_state(gl, "fewer", lights.state, v0)
  lights.setup_view(fewer, camera)
  g3_note_light_state(gl, "fewer view", lights.state, v0)
  mock_note(
    gl,
    "shared fewer",
    g3_arr([
      @core.JsValue::of(
        physical_equal(lights.state.directional, directional_array),
      ),
    ]),
  )
  lights.setup(fewer)
  note_int(gl, "version same", lights.state.version - v0)

  // no lights
  lights.setup([])
  g3_note_light_state(gl, "none", lights.state, v0)

  // half-float LTC without OES_texture_float_linear
  let gl2 = mock_gl(options="{\"extensions\":[\"EXT_color_buffer_float\"]}")
  let lights2 = @webgl.WebGLLights::new(@webgl.WebGLExtensions::new(gl2))
  lights2.setup([rect2, ambient1])
  g3_note_light_state(gl, "half", lights2.state, v0)
  g3_merge_log(gl, gl2, "gl2 ")
  mock_note(gl, "ser check", g3_ser(Array(lights2.state.hemi)))
  let log = emit_log("lights_all", gl)
  // Restore the shared LTC textures so tests do not depend on run order.
  @webgl.uniforms_lib_ltc.ltc_float_1 = None
  @webgl.uniforms_lib_ltc.ltc_float_2 = None
  @webgl.uniforms_lib_ltc.ltc_half_1 = None
  @webgl.uniforms_lib_ltc.ltc_half_2 = None
  assert_true(log.length() > 100)
}

///|
/// A stand-in renderer for `WebGLMaterials`/`WebGLBackground` tests that only read
/// `getRenderTarget()` and `outputColorSpace` (the real one needs every group's work).
extern "js" fn g3_fake_renderer(color_space : String) -> @webgl.WebGLRenderer = "(c) => ({ _output_color_space: c, _current_render_target: undefined })"

///|
extern "js" fn g3_set_fake_color_space(
  renderer : @webgl.WebGLRenderer,
  color_space : String,
) -> Unit = "(r, c) => { r._output_color_space = c; }"

///|
fn g3_lib(key : String) -> Map[String, @core.Uniform] {
  @core.clone_uniforms(@shaders.shader_lib.get(key).unwrap().uniforms)
}

///|
fn g3_color_of(
  uniforms : Map[String, @core.Uniform],
  name : String,
) -> @core.JsValue {
  g3_ser(uniforms.get(name).unwrap().value)
}

///|
test "diff materials_all" {
  let gl = mock_gl()
  let properties = @webgl.WebGLProperties::new()
  let renderer = g3_fake_renderer(@core.SRGBColorSpace)
  let materials = @webgl.WebGLMaterials::new(renderer, properties)
  let n = Ref(0)
  fn tex(name : String) -> @core.Texture {
    let t = g3_named_texture(name)
    n.val += 1
    let k = n.val.to_double()
    ignore(t.offset.set(0.1 * k, 0.05 * k))
    ignore(t.repeat.set(1.0 + k, 2.0 - 0.1 * k))
    t.rotation = 0.2 * k
    ignore(t.center.set(0.5, 0.25))
    if n.val % 3 == 0 {
      t.matrix_auto_update = false
    }
    t
  }

  fn cube(name : String, rtt : Bool) -> @core.Texture {
    let t = @core.CubeTexture::new()
    t.name = name
    t.is_render_target_texture = rtt
    t
  }

  fn run(
    label : String,
    key : String,
    material : @core.Material,
    extra : @core.RenderTarget?,
  ) -> Unit {
    let uniforms = g3_lib(key)
    materials.refresh_material_uniforms(uniforms, material, 2, 600, extra)
    g3_note_uniforms(gl, label, uniforms)
  }

  fn env_props(
    material : @core.Material,
    env_map : @core.Texture,
    x : Double,
    y : Double,
    z : Double,
  ) -> Unit {
    let p = properties.get_material(material)
    p.env_map = Some(env_map)
    p.env_map_rotation = Some(@math.Euler::new(x, y, z))
  }

  let basic = @core.MeshBasicMaterial::new()
  ignore(basic.color.unwrap().set_rgb(0.2, 0.4, 0.6))
  basic.opacity = 0.5
  basic.map = Some(tex("basic.map"))
  basic.alpha_map = Some(tex("basic.alphaMap"))
  basic.specular_map = Some(tex("basic.specularMap"))
  basic.set_alpha_test(0.3)
  basic.light_map = Some(tex("basic.lightMap"))
  basic.light_map_intensity = Some(0.7)
  basic.ao_map = Some(tex("basic.aoMap"))
  basic.ao_map_intensity = Some(0.4)
  basic.set_reflectivity(0.6)
  basic.refraction_ratio = Some(0.9)
  env_props(basic, cube("basic.env", false), 0.1, 0.2, 0.3)
  run("basic", "basic", basic, None)
  let lambert = @core.MeshLambertMaterial::new()
  ignore(lambert.color.unwrap().set_rgb(0.7, 0.1, 0.2))
  ignore(lambert.emissive.unwrap().set_rgb(0.1, 0.2, 0.3))
  lambert.emissive_intensity = Some(2)
  lambert.bump_map = Some(tex("lambert.bumpMap"))
  lambert.bump_scale = Some(2)
  lambert.side = @core.BackSide
  lambert.normal_map = Some(tex("lambert.normalMap"))
  ignore(lambert.normal_scale.unwrap().set(0.5, 0.7))
  lambert.displacement_map = Some(tex("lambert.displacementMap"))
  lambert.displacement_scale = Some(3)
  lambert.displacement_bias = Some(-1)
  lambert.emissive_map = Some(tex("lambert.emissiveMap"))
  let lambert_env = tex("lambert.envMap")
  lambert.env_map = Some(lambert_env)
  lambert.env_map_intensity = Some(0.3)
  env_props(lambert, lambert_env, 0.5, 0, 0)
  run("lambert", "lambert", lambert, None)
  let toon = @core.MeshToonMaterial::new()
  toon.gradient_map = Some(tex("toon.gradientMap"))
  ignore(toon.color.unwrap().set_rgb(0.3, 0.3, 0.9))
  run("toon", "toon", toon, None)
  let phong = @core.MeshPhongMaterial::new()
  ignore(phong.specular.unwrap().set_rgb(0.3, 0.2, 0.1))
  phong.shininess = Some(0)
  let phong_env = cube("phong.env", false)
  phong.env_map = Some(phong_env)
  phong.env_map_intensity = Some(2)
  env_props(phong, phong_env, 0, 0.7, 0)
  run("phong", "phong", phong, None)
  let standard = @core.MeshStandardMaterial::new()
  standard.metalness = Some(0.8)
  standard.metalness_map = Some(tex("standard.metalnessMap"))
  standard.roughness = Some(0.3)
  standard.roughness_map = Some(tex("standard.roughnessMap"))
  let standard_env = cube("standard.env", true)
  standard.env_map = Some(standard_env)
  standard.env_map_intensity = Some(1.5)
  env_props(standard, standard_env, 0.2, 0.4, 0.6)
  run("standard", "standard", standard, None)
  let physical = @core.MeshPhysicalMaterial::new()
  physical.ior = Some(1.8)
  physical.side = @core.BackSide
  physical.set_diffuse_roughness(0.5)
  physical.diffuse_roughness_map = Some(tex("physical.diffuseRoughnessMap"))
  physical.set_sheen(0.6)
  ignore(physical.sheen_color.unwrap().set_rgb(1, 0.5, 0))
  physical.sheen_roughness = Some(0.2)
  physical.sheen_color_map = Some(tex("physical.sheenColorMap"))
  physical.sheen_roughness_map = Some(tex("physical.sheenRoughnessMap"))
  physical.set_clearcoat(0.7)
  physical.clearcoat_roughness = Some(0.1)
  physical.clearcoat_map = Some(tex("physical.clearcoatMap"))
  physical.clearcoat_roughness_map = Some(tex("physical.clearcoatRoughnessMap"))
  physical.clearcoat_normal_map = Some(tex("physical.clearcoatNormalMap"))
  ignore(physical.clearcoat_normal_scale.unwrap().set(2, 3))
  physical.set_dispersion(0.2)
  physical.set_retroreflectivity(0.3)
  physical.set_iridescence(0.4)
  physical.iridescence_ior = Some(1.5)
  physical.iridescence_thickness_minimum = Some(200)
  physical.iridescence_thickness_maximum = Some(500)
  physical.iridescence_map = Some(tex("physical.iridescenceMap"))
  physical.iridescence_thickness_map = Some(
    tex("physical.iridescenceThicknessMap"),
  )
  physical.set_transmission(0.9)
  physical.transmission_map = Some(tex("physical.transmissionMap"))
  physical.thickness = Some(0.5)
  physical.thickness_map = Some(tex("physical.thicknessMap"))
  physical.attenuation_distance = Some(10)
  ignore(physical.attenuation_color.unwrap().set_rgb(0.9, 0.8, 0.7))
  physical.set_anisotropy(0.6)
  physical.anisotropy_rotation = Some(0.7)
  physical.anisotropy_map = Some(tex("physical.anisotropyMap"))
  physical.specular_intensity = Some(0.8)
  ignore(physical.specular_color.unwrap().set_rgb(0.5, 0.6, 0.7))
  physical.specular_color_map = Some(tex("physical.specularColorMap"))
  physical.specular_intensity_map = Some(tex("physical.specularIntensityMap"))
  let physical_env = cube("physical.env", false)
  physical.env_map = Some(physical_env)
  env_props(physical, physical_env, 0.3, 0.2, 0.1)
  let transmission_rt = @core.RenderTarget::new(width=128, height=64)
  transmission_rt.texture().name = "transmissionRT"
  run("physical", "physical", physical, Some(transmission_rt))
  let physical2 = @core.MeshPhysicalMaterial::new()
  run("physical2", "physical", physical2, None)
  let matcap = @core.MeshMatcapMaterial::new()
  matcap.matcap = Some(tex("matcap.matcap"))
  matcap.normal_map = Some(tex("matcap.normalMap"))
  matcap.side = @core.BackSide
  run("matcap", "matcap", matcap, None)
  let depth = @core.MeshDepthMaterial::new()
  depth.map = Some(tex("depth.map"))
  depth.set_alpha_test(0.5)
  depth.displacement_map = Some(tex("depth.displacementMap"))
  run("depth", "depth", depth, None)
  let distance = @core.MeshDistanceMaterial::new()
  let point = @core.PointLight::new()
  ignore(point.position.set(1, 2, 3))
  point.update_matrix_world()
  let point_camera = point.as_light().shadow.unwrap().camera.as_perspective_camera()
  point_camera.near = 0.5
  point_camera.far = 40
  properties.get_material(distance).light = Some(point)
  run("distance", "distance", distance, None)
  let normal = @core.MeshNormalMaterial::new()
  normal.bump_map = Some(tex("normal.bumpMap"))
  normal.normal_map = Some(tex("normal.normalMap"))
  normal.displacement_map = Some(tex("normal.displacementMap"))
  normal.displacement_scale = Some(0.25)
  run("normal", "normal", normal, None)
  let line = @core.LineBasicMaterial::new()
  ignore(line.color.unwrap().set_rgb(0.1, 0.9, 0.1))
  line.opacity = 0.6
  line.map = Some(tex("line.map"))
  run("line", "basic", line, None)
  let dashed = @core.LineDashedMaterial::new()
  dashed.dash_size = Some(2)
  dashed.gap_size = Some(0.5)
  dashed.scale = Some(3)
  dashed.map = Some(tex("dashed.map"))
  run("dashed", "dashed", dashed, None)
  let points = @core.PointsMaterial::new()
  points.size = Some(4)
  ignore(points.color.unwrap().set_rgb(0.4, 0.5, 0.6))
  points.map = Some(tex("points.map"))
  points.alpha_map = Some(tex("points.alphaMap"))
  points.set_alpha_test(0.2)
  run("points", "points", points, None)
  let sprite = @core.SpriteMaterial::new()
  sprite.rotation = Some(0.4)
  sprite.map = Some(tex("sprite.map"))
  sprite.alpha_map = Some(tex("sprite.alphaMap"))
  sprite.set_alpha_test(0.1)
  run("sprite", "sprite", sprite, None)
  let shadow = @core.ShadowMaterial::new()
  ignore(shadow.color.unwrap().set_rgb(0.1, 0.2, 0.3))
  shadow.opacity = 0.4
  run("shadow", "shadow", shadow, None)
  let shader = @core.ShaderMaterial::new()
  shader.uniforms_need_update = Some(true)
  materials.refresh_material_uniforms(Map([]), shader, 1, 1, None)
  note_bool(
    gl,
    "shader uniformsNeedUpdate",
    shader.uniforms_need_update.unwrap(),
  )
  let raw = @core.RawShaderMaterial::new()
  raw.uniforms_need_update = Some(true)
  materials.refresh_material_uniforms(Map([]), raw, 1, 1, None)
  note_bool(gl, "raw uniformsNeedUpdate", raw.uniforms_need_update.unwrap())
  let fog_uniforms = g3_lib("basic")
  let fog_state = fn() {
    g3_arr([
      g3_color_of(fog_uniforms, "fogColor"),
      g3_color_of(fog_uniforms, "fogNear"),
      g3_color_of(fog_uniforms, "fogFar"),
      g3_color_of(fog_uniforms, "fogDensity"),
    ])
  }
  materials.refresh_fog_uniforms(
    fog_uniforms,
    Fog(@core.Fog::new(color=@math.Color::from_hex(0x808080), near=2, far=30)),
  )
  mock_note(gl, "fog", fog_state())
  materials.refresh_fog_uniforms(
    fog_uniforms,
    FogExp2(
      @core.FogExp2::new(color=@math.Color::from_hex(0x112233), density=0.05),
    ),
  )
  mock_note(gl, "fogExp2", fog_state())
  g3_set_fake_color_space(renderer, @core.LinearSRGBColorSpace)
  materials.refresh_fog_uniforms(
    fog_uniforms,
    FogExp2(
      @core.FogExp2::new(color=@math.Color::from_hex(0x112233), density=0.05),
    ),
  )
  mock_note(gl, "fogExp2 linear", g3_color_of(fog_uniforms, "fogColor"))
  let log = emit_log("materials_all", gl)
  assert_true(log.length() > 600)
}

///|
/// `MORPH_OPTIONS` of harness/scenarios/morph_all.mjs.
let g3_morph_options : String =
  #|{"parameters":{"MAX_TEXTURE_SIZE":8},"programs":[{"attributes":[],"uniforms":[{"name":"morphTargetBaseInfluence","type":5126},{"name":"morphTargetInfluences[0]","type":5126,"size":4},{"name":"morphTargetsTexture","type":36289},{"name":"morphTargetsTextureSize","type":35667},{"name":"morphTexture","type":35678}]}]}

///|
/// A `WebGLProgram` stand-in whose `getUniforms()` returns `uniforms`.
fn g3_fake_program(
  gl : @webgl.WebGL2RenderingContext,
  uniforms : @webgl.WebGLUniforms,
) -> @webgl.WebGLProgram {
  {
    type_: "",
    name: "",
    id: 0,
    cache_key: "",
    used_times: 1,
    program: None,
    vertex_shader: @webgl.uninitialized(),
    fragment_shader: @webgl.uninitialized(),
    diagnostics: None,
    renderer: @webgl.uninitialized(),
    gl,
    binding_states: @webgl.uninitialized(),
    prefix_vertex: "",
    prefix_fragment: "",
    cached_uniforms: Some(uniforms),
    cached_attributes: Some(Map([])),
    program_ready: true,
  }
}

///|
fn g3_attr(
  n : Int32,
  size : Int32,
  f : (Double) -> Double,
) -> @core.GeometryAttribute {
  let a = @core.TypedArray::float32(n * size)
  for i in 0..<(n * size) {
    a.set(i, f(i.to_double()))
  }
  Buffer(@core.BufferAttribute::new(a, size))
}

///|
fn g3_set_influences(
  object : @core.Object3D,
  influences : Array[Double],
) -> Unit {
  match object.kind {
    Mesh(mesh) => mesh.morph_target_influences = Some(influences)
    _ => abort("not a mesh")
  }
}

///|
test "diff morph_all" {
  let gl = mock_gl(options=g3_morph_options)
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
  let uniforms = @webgl.WebGLUniforms::new(gl, gl.create_program())
  let program = g3_fake_program(gl, uniforms)
  let morph = @webgl.WebGLMorphtargets::new(gl, capabilities, textures)
  mock_clear(gl)
  let geometry = @core.BufferGeometry::new()
  ignore(geometry.set_attribute("position", g3_attr(2, 3, fn(i) { i })))
  geometry.morph_attributes.set("position", [
    g3_attr(2, 3, fn(i) { i * 0.5 }),
    g3_attr(2, 3, fn(i) { -i }),
  ])
  geometry.morph_attributes.set("normal", [
    g3_attr(2, 3, fn(i) { i * 0.25 }),
    g3_attr(2, 3, fn(i) { 1.0 - i }),
  ])
  geometry.morph_attributes.set("color", [
    g3_attr(2, 4, fn(i) { i * 0.125 }),
    g3_attr(2, 3, fn(_) { 0.5 }),
  ])
  let mesh = @core.Mesh::new(
    geometry~,
    material=Single(@core.MeshBasicMaterial::new()),
  )
  let influences = [0.25, 0.5]
  g3_set_influences(mesh, influences)
  morph.update(mesh, geometry, program)
  note_int(gl, "info", info.memory.textures)
  influences[1] = 0.125
  morph.update(mesh, geometry, program)
  geometry.morph_targets_relative = true
  morph.update(mesh, geometry, program)

  // more targets: the texture is rebuilt
  geometry.morph_attributes
  .get("position")
  .unwrap()
  .push(g3_attr(2, 3, fn(i) { 2.0 * i }))
  geometry.morph_attributes
  .get("normal")
  .unwrap()
  .push(g3_attr(2, 3, fn(_) { 3 }))
  geometry.morph_attributes
  .get("color")
  .unwrap()
  .push(g3_attr(2, 3, fn(_) { 0.75 }))
  influences.push(1)
  morph.update(mesh, geometry, program)
  note_int(gl, "info", info.memory.textures)

  // wider than MAX_TEXTURE_SIZE, position only
  let wide = @core.BufferGeometry::new()
  ignore(wide.set_attribute("position", g3_attr(5, 3, fn(i) { i })))
  wide.morph_attributes.set("position", [g3_attr(5, 3, fn(i) { i + 0.5 })])
  let wide_mesh = @core.Mesh::new(
    geometry=wide,
    material=Single(@core.MeshBasicMaterial::new()),
  )
  g3_set_influences(wide_mesh, [0.75])
  morph.update(wide_mesh, wide, program)

  // instanced mesh with a morph texture
  let instanced = @core.InstancedMesh::new(
    geometry=wide,
    material=Single(@core.MeshBasicMaterial::new()),
    2,
  )
  g3_set_influences(instanced, [0.5])
  let morph_texture = @core.DataTexture::new(
    data=@core.TypedArray::float32(8),
    width=2,
    height=1,
    format=@core.RedFormat,
    type_=@core.FloatType,
  )
  morph_texture.set_needs_update(true)
  match instanced.kind {
    Mesh({ kind: InstancedMesh(data), .. }) =>
      data.morph_texture = Some(morph_texture)
    _ => fail("not instanced")
  }
  morph.update(instanced, wide, program)
  note_int(gl, "info", info.memory.textures)
  geometry.dispose()
  note_int(gl, "info", info.memory.textures)
  morph.update(mesh, geometry, program)
  note_int(gl, "info", info.memory.textures)
  let log = emit_log("morph_all", gl)
  assert_true(log.length() > 50)
}

///|
/// `G3_EXTRA_UNIFORMS` of harness/group3_util.mjs.
let g3_extra_uniforms : String =
  #|[{"name":"envMap","type":35680},{"name":"flipEnvMap","type":5126},{"name":"backgroundBlurriness","type":5126},{"name":"backgroundIntensity","type":5126},{"name":"backgroundRotation","type":35675},{"name":"t2D","type":35678},{"name":"uvTransform","type":35675},{"name":"lodBias","type":5126},{"name":"sourceLod","type":5126},{"name":"sourceSize","type":5124},{"name":"sigma","type":5126},{"name":"tDiffuse","type":35678},{"name":"shadow_pass","type":35678},{"name":"resolution","type":35664},{"name":"radius","type":5126},{"name":"referencePosition","type":35665},{"name":"nearDistance","type":5126},{"name":"farDistance","type":5126},{"name":"spotShadowMap[0]","type":35682},{"name":"pointShadowMap[0]","type":36293},{"name":"spotLightMatrix[0]","type":35676},{"name":"pointShadowMatrix[0]","type":35676},{"name":"alphaTest","type":5126},{"name":"envMapIntensity","type":5126}]

///|
extern "js" fn g3_add_uniforms(
  options : String,
  extra : String,
  unlit : Bool,
) -> String =
  #|(o, e, unlit) => {
  #|  o = JSON.parse(o); e = JSON.parse(e);
  #|  const keep = (u) => !unlit || !/Light|Shadow/.test(u.name);
  #|  o.programs = o.programs.map((p) => ({ attributes: p.attributes, uniforms: p.uniforms.concat(e).filter(keep) }));
  #|  return JSON.stringify(o);
  #|}

///|
/// `g3Options( mockOptions, extra, unlit )` of harness/group3_util.mjs.
fn g3_options(extra~ : String = "{}", unlit~ : Bool = false) -> String {
  g3_add_uniforms(renderer_mock_options(extra), g3_extra_uniforms, unlit)
}

///|
/// `gl.__log.push( line )`.
extern "js" fn g3_log_push(
  gl : @webgl.WebGL2RenderingContext,
  line : String,
) -> Unit = "(gl, l) => { gl.__log.push(l); }"

///|
fn g3_dom(width : Int32, height : Int32) -> @core.TextureImage {
  DomImage(@core.JsValue::from_json({ "width": width, "height": height }))
}

///|
fn g3_renderer(
  gl : @webgl.WebGL2RenderingContext,
  output_buffer_type~ : Int32 = @core.UnsignedByteType,
) -> @webgl.WebGLRenderer {
  @webgl.WebGLRenderer::new(
    canvas=renderer_mock_canvas(gl, 64, 32),
    context=gl,
    output_buffer_type~,
  )
}

///|
test "diff background_all" {
  let gl = mock_gl(options=g3_options())
  let renderer = g3_renderer(gl)
  let scene = @core.Scene::new()
  let scene_data = scene.as_scene()
  let camera = @core.PerspectiveCamera::new(fov=50, aspect=2, near=0.1, far=100)
  ignore(camera.position.set(0, 0, 5))
  let material = @core.MeshBasicMaterial::new()
  ignore(material.color.unwrap().set_hex(0x00ff00))
  ignore(
    scene.add(
      @core.Mesh::new(
        geometry=@geometries.BoxGeometry::new(),
        material=Single(material),
      ),
    ),
  )
  fn frame(label : String) {
    g3_log_push(gl, "## " + label)
    renderer.render(scene, camera)
  }

  renderer.set_clear_color_hex(0x336699, alpha=0.5)
  frame("clear color")
  renderer.set_clear_alpha(0.25)
  frame("clear alpha")
  scene_data.background = Some(Color(@math.Color::new(0.2, 0.4, 0.8)))
  frame("color")
  renderer.auto_clear = false
  frame("color without autoClear")
  scene_data.background = None
  frame("no background without autoClear")
  renderer.auto_clear = true
  let tex = @core.DataTexture::new(
    data=@core.TypedArray::uint8(16),
    width=2,
    height=2,
  )
  tex.set_needs_update(true)
  tex.color_space = @core.SRGBColorSpace
  ignore(tex.offset.set(0.1, 0.2))
  tex.name = "bg2d"
  scene_data.background = Some(Texture(tex))
  scene_data.background_intensity = 0.7
  frame("texture")
  frame("texture again")
  renderer.tone_mapping = @core.ACESFilmicToneMapping
  frame("texture tone mapped")
  tex.color_space = @core.LinearSRGBColorSpace
  tex.set_needs_update(true)
  frame("texture version")
  let cube = @core.CubeTexture::new(
    images=Array::makei(6, fn(_) { g3_dom(4, 4) }),
  )
  cube.set_needs_update(true)
  scene_data.background = Some(Texture(cube))
  ignore(scene_data.background_rotation.set(0.1, 0.2, 0.3))
  scene_data.background_intensity = 1.5
  frame("cube")
  frame("cube again")
  let equirect = @core.Texture::new(image=g3_dom(8, 4))
  equirect.mapping = @core.EquirectangularReflectionMapping
  equirect.set_needs_update(true)
  scene_data.background = Some(Texture(equirect))
  frame("equirect")
  frame("equirect again")
  note_int(gl, "equirect mapping", equirect.mapping)
  let pending = @core.Texture::new()
  pending.mapping = @core.EquirectangularReflectionMapping
  scene_data.background = Some(Texture(pending))
  frame("equirect pending")
  equirect.dispose()
  g3_log_push(gl, "## dispose")
  renderer.dispose()
  let log = emit_log("background_all", gl)
  assert_true(log.length() > 1000)
}

///|
fn g3_opt_int(value : Int32?) -> @core.JsValue {
  match value {
    Some(v) => g3_num(v.to_double())
    None => @core.JsValue::null()
  }
}

///|
fn g3_mesh(
  geometry : @core.BufferGeometry,
  material : @core.Material,
) -> @core.Object3D {
  @core.Mesh::new(geometry~, material=Single(material))
}

///|
test "diff shadow_all" {
  let gl = mock_gl(
    options=g3_options(extra="{\"parameters\":{\"MAX_TEXTURE_SIZE\":2048}}"),
  )
  let renderer = g3_renderer(gl)
  renderer.shadow_map.enabled = true
  renderer.local_clipping_enabled = true
  let scene = @core.Scene::new()
  let camera = @core.PerspectiveCamera::new(fov=50, aspect=2, near=0.1, far=100)
  ignore(camera.position.set(0, 3, 8))
  camera.look_at_xyz(0, 0, 0)
  let dir = @core.DirectionalLight::new(
    color=@math.Color::from_hex(0xffffff),
    intensity=1,
  )
  dir.name = "dir"
  ignore(dir.position.set(3, 6, 2))
  dir.cast_shadow = true
  let dir_shadow = dir.as_light().shadow.unwrap()
  ignore(dir_shadow.map_size.set(4096, 256))
  ignore(scene.add(dir))
  let spot = @core.SpotLight::new(
    color=@math.Color::from_hex(0xffeedd),
    intensity=2,
    distance=20,
    angle=0.6,
    penumbra=0.2,
  )
  spot.name = "spot"
  ignore(spot.position.set(-2, 5, 1))
  spot.cast_shadow = true
  let spot_shadow = spot.as_light().shadow.unwrap()
  ignore(spot_shadow.map_size.set(64, 64))
  spot_shadow.blur_samples = 4
  spot_shadow.radius = 2
  ignore(scene.add(spot))
  let point = @core.PointLight::new(
    color=@math.Color::from_hex(0x88aaff),
    intensity=3,
    distance=0,
  )
  point.name = "point"
  ignore(point.position.set(1, 2, -1))
  point.cast_shadow = true
  ignore(point.as_light().shadow.unwrap().map_size.set(32, 32))
  ignore(scene.add(point))
  ignore(
    scene.add(
      @core.HemisphereLight::new(
        sky_color=@math.Color::from_hex(0xffffff),
        ground_color=@math.Color::from_hex(0x444444),
        intensity=0.5,
      ),
    ),
  )
  let floor = g3_mesh(
    @geometries.PlaneGeometry::new(width=10, height=10),
    @core.MeshPhongMaterial::new(),
  )
  floor.rotation.set_x(-3.141592653589793 / 2.0)
  floor.receive_shadow = true
  ignore(scene.add(floor))
  let red = @core.MeshBasicMaterial::new()
  ignore(red.color.unwrap().set_hex(0xff0000))
  let box = g3_mesh(
    @geometries.BoxGeometry::new(width=1, height=1, depth=1),
    red,
  )
  box.cast_shadow = true
  ignore(box.position.set(0, 0.5, 0))
  ignore(scene.add(box))
  let cutout_material = @core.MeshBasicMaterial::new()
  cutout_material.map = Some(@core.Texture::new())
  cutout_material.set_alpha_test(0.5)
  cutout_material.side = @core.DoubleSide
  let cutout = g3_mesh(
    @geometries.PlaneGeometry::new(width=1, height=1),
    cutout_material,
  )
  cutout.cast_shadow = true
  ignore(cutout.position.set(1.5, 0.5, 0))
  ignore(scene.add(cutout))
  let clipped_material = @core.MeshBasicMaterial::new()
  clipped_material.clipping_planes = Some([
    @math.Plane::new(normal=@math.Vector3::new(0, -1, 0), constant=0.8),
  ])
  clipped_material.clip_shadows = true
  clipped_material.shadow_side = Some(@core.FrontSide)
  let clipped = g3_mesh(
    @geometries.BoxGeometry::new(width=0.5, height=0.5, depth=0.5),
    clipped_material,
  )
  clipped.cast_shadow = true
  ignore(clipped.position.set(-1.5, 0.5, 0))
  ignore(scene.add(clipped))
  let custom = g3_mesh(
    @geometries.BoxGeometry::new(width=0.3, height=0.3, depth=0.3),
    @core.MeshBasicMaterial::new(),
  )
  custom.cast_shadow = true
  let custom_depth = @core.MeshDepthMaterial::new()
  custom_depth.depth_packing = Some(@core.RGBADepthPacking)
  custom.custom_depth_material = Some(custom_depth)
  custom.custom_distance_material = Some(@core.MeshDistanceMaterial::new())
  ignore(custom.position.set(0, 2, 0))
  ignore(scene.add(custom))
  let plain = @core.MeshBasicMaterial::new()
  let hidden = @core.MeshBasicMaterial::new()
  hidden.visible = false
  let coverage = @core.MeshBasicMaterial::new()
  coverage.alpha_to_coverage = true
  let multi = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(width=0.4, height=0.4, depth=0.4),
    material=Multiple([plain, hidden, coverage]),
  )
  multi.cast_shadow = true
  ignore(multi.position.set(0.5, 1.5, 1))
  ignore(scene.add(multi))
  let line = @core.Line::new(
    geometry=@core.BufferGeometry::new().set_from_points([
      @math.Vector3::new(0, 0, 0),
      @math.Vector3::new(1, 1, 1),
    ]),
    material=Single(@core.LineBasicMaterial::new()),
  )
  line.cast_shadow = true
  ignore(scene.add(line))
  let far = g3_mesh(
    @geometries.BoxGeometry::new(),
    @core.MeshBasicMaterial::new(),
  )
  far.cast_shadow = true
  ignore(far.position.set(500, 0, 0))
  ignore(scene.add(far))
  fn maps() {
    g3_arr(
      [dir, spot, point].map(fn(l) {
        let shadow = l.as_light().shadow.unwrap()
        let map = match shadow.map {
          None => @core.JsValue::null()
          Some(map) =>
            g3_arr([
              g3_num(map.width.to_double()),
              g3_num(map.height.to_double()),
              @core.JsValue::of(
                map.has_extension_flag("isWebGLCubeRenderTarget"),
              ),
              g3_num(map.texture().format.to_double()),
              match map.depth_texture() {
                None => @core.JsValue::null()
                Some(d) =>
                  g3_arr([
                    g3_str(d.name),
                    g3_opt_int(d.compare_function),
                    g3_num(d.min_filter.to_double()),
                    g3_num(d.type_.to_double()),
                  ])
              },
            ])
        }
        let map_pass = match shadow.map_pass {
          None => @core.JsValue::null()
          Some(p) => g3_nums([p.width.to_double(), p.height.to_double()])
        }
        g3_arr([
          g3_str(l.name),
          map,
          map_pass,
          g3_nums([shadow.map_size.x, shadow.map_size.y]),
          @core.JsValue::of(shadow.needs_update),
        ])
      }),
    )
  }

  fn frame(label : String) {
    g3_log_push(gl, "## " + label)
    renderer.render(scene, camera)
    mock_note(gl, label + " maps", maps())
    mock_note(
      gl,
      label + " state",
      g3_arr([
        g3_num(renderer.shadow_map.type_.to_double()),
        @core.JsValue::of(renderer.shadow_map.needs_update),
      ]),
    )
  }

  frame("pcf")
  frame("pcf again")
  renderer.shadow_map.auto_update = false
  frame("no auto update")
  renderer.shadow_map.needs_update = true
  dir_shadow.auto_update = false
  frame("needs update")
  dir_shadow.auto_update = true
  renderer.shadow_map.auto_update = true
  renderer.shadow_map.type_ = @core.BasicShadowMap
  frame("basic")
  renderer.shadow_map.type_ = @core.VSMShadowMap
  frame("vsm")
  spot_shadow.blur_samples = 8
  frame("vsm blur samples")
  renderer.shadow_map.type_ = @core.PCFSoftShadowMap
  frame("pcf soft")
  cutout_material.dispose()
  frame("after dispose")
  renderer.shadow_map.enabled = false
  frame("disabled")
  let log = emit_log("shadow_all", gl)
  assert_true(log.length() > 1000)
}

///|
fn g3_equirect(size? : (Int32, Int32)) -> @core.Texture {
  let t = match size {
    Some((w, h)) => @core.Texture::new(image=g3_dom(w, h))
    None => @core.Texture::new()
  }
  t.mapping = @core.EquirectangularReflectionMapping
  if size is Some(_) {
    t.set_needs_update(true)
  }
  t
}

///|
fn g3_cube(n : Int32, size~ : Int32 = 4) -> @core.Texture {
  let t = @core.CubeTexture::new(
    images=Array::makei(n, fn(_) { g3_dom(size, size) }),
  )
  t.set_needs_update(true)
  t
}

///|
fn g3_material_of(mesh : @core.Object3D) -> @core.Material {
  guard mesh.get_material() is Some(Single(material)) else { abort("material") }
  material
}

///|
test "diff env_all" {
  let gl = mock_gl(options=g3_options(unlit=true))
  let renderer = g3_renderer(gl)
  let scene = @core.Scene::new()
  let camera = @core.PerspectiveCamera::new(fov=50, aspect=2, near=0.1, far=100)
  ignore(camera.position.set(0, 0, 5))
  fn frame(label : String) {
    g3_log_push(gl, "## " + label)
    renderer.render(scene, camera)
  }

  fn mesh(material : @core.Material) -> @core.Object3D {
    let m = g3_mesh(@geometries.BoxGeometry::new(), material)
    ignore(scene.add(m))
    m
  }

  let e1 = g3_equirect(size=(16, 8))
  let basic_material = @core.MeshBasicMaterial::new()
  basic_material.env_map = Some(e1)
  let basic = mesh(basic_material)
  frame("basic equirect")
  note_int(gl, "e1 mapping", e1.mapping)
  frame("basic equirect again")
  let e3 = g3_equirect(size=(8, 4))
  e3.mapping = @core.EquirectangularRefractionMapping
  let refract_material = @core.MeshBasicMaterial::new()
  refract_material.env_map = Some(e3)
  ignore(mesh(refract_material))
  frame("basic equirect refraction")
  note_int(gl, "e3 mapping", e3.mapping)
  let e2 = g3_equirect(size=(1024, 512))
  e2.mapping = @core.EquirectangularRefractionMapping
  let standard_material = @core.MeshStandardMaterial::new()
  standard_material.env_map = Some(e2)
  let standard = mesh(standard_material)
  frame("standard equirect")
  let c1 = g3_cube(6)
  scene.as_scene().environment = Some(c1)
  let standard2 = mesh(@core.MeshStandardMaterial::new())
  frame("environment cube")
  g3_material_of(basic).env_map = Some(g3_equirect())
  g3_material_of(standard).env_map = Some(g3_cube(5))
  frame("not ready")
  let rt = @webgl.WebGLCubeRenderTarget::new(size=8)
  rt.texture().name = "rtCube"
  g3_material_of(standard).env_map = Some(rt.texture())
  frame("render target texture")
  rt.texture().set_needs_pmrem_update(true)
  frame("render target texture updated")
  frame("render target texture again")
  let pm = @webgl.WebGLCubeRenderTarget::new(size=4)
  pm.texture().is_pmrem_texture = true
  pm.texture().mipmaps.push(DataImage(@core.DataImage::new(width=4, height=4)))
  pm.texture().mipmaps.push(DataImage(@core.DataImage::new(width=2, height=2)))
  g3_material_of(standard2).env_map = Some(pm.texture())
  frame("pmrem texture")
  g3_log_push(gl, "## dispose e2")
  e2.dispose()
  g3_log_push(gl, "## dispose e1")
  e1.dispose()
  g3_log_push(gl, "## dispose c1")
  c1.dispose()
  scene.as_scene().environment = None
  g3_material_of(standard).env_map = Some(e2)
  frame("after dispose")
  g3_log_push(gl, "## renderer dispose")
  renderer.dispose()
  let log = emit_log("env_all", gl)
  assert_true(log.length() > 1000)
}

///|
fn g3_describe_target(t : @core.RenderTarget) -> @core.JsValue {
  let texture = t.texture()
  g3_arr([
    g3_num(t.width.to_double()),
    g3_num(t.height.to_double()),
    g3_str(texture.name),
    @core.JsValue::of(texture.is_pmrem_texture),
    g3_nums(
      texture.mipmaps.map(fn(m) {
        match m {
          DataImage(d) => d.width.to_double()
          _ => -1.0
        }
      }),
    ),
    g3_num(texture.type_.to_double()),
    g3_str(texture.color_space),
    g3_num(texture.min_filter.to_double()),
    @core.JsValue::of(texture.generate_mipmaps),
    @core.JsValue::of(t.depth_buffer),
  ])
}

///|
test "diff pmrem_all" {
  let gl = mock_gl(options=g3_options(unlit=true))
  let renderer = g3_renderer(gl)
  mock_note(
    gl,
    "lodToRoughness",
    g3_nums([
      @webgl.PMREMGenerator::lod_to_roughness(0, 5),
      @webgl.PMREMGenerator::lod_to_roughness(2, 5),
      @webgl.PMREMGenerator::lod_to_roughness(5, 5),
      @webgl.PMREMGenerator::lod_to_roughness(1, 0),
    ]),
  )
  let pmrem = @webgl.PMREMGenerator::new(renderer)
  g3_log_push(gl, "## compile")
  pmrem.compile_equirectangular_shader()
  pmrem.compile_cubemap_shader()
  pmrem.compile_cubemap_shader()
  let equirect = g3_equirect(size=(2048, 1024))
  g3_log_push(gl, "## equirect")
  let t1 = pmrem.from_equirectangular(equirect)
  mock_note(gl, "t1", g3_describe_target(t1))
  let cube = g3_cube(6, size=64)
  g3_log_push(gl, "## cube")
  let t2 = pmrem.from_cubemap(cube)
  mock_note(gl, "t2", g3_describe_target(t2))
  g3_log_push(gl, "## cube reuse")
  let t3 = pmrem.from_cubemap(cube, render_target=t2)
  note_bool(gl, "t3 same", physical_equal(t3, t2))
  let scene = @core.Scene::new()
  let material = @core.MeshBasicMaterial::new()
  ignore(material.color.unwrap().set_hex(0x804020))
  ignore(scene.add(g3_mesh(@geometries.BoxGeometry::new(), material)))
  renderer.set_clear_color_hex(0x102030)
  g3_log_push(gl, "## scene blur")
  let t4 = pmrem.from_scene(
    scene,
    sigma=0.04,
    near=0.1,
    far=100,
    size=128,
    position=@math.Vector3::new(1, 2, 3),
  )
  mock_note(gl, "t4", g3_describe_target(t4))
  mock_note(
    gl,
    "scene background",
    match scene.as_scene().background {
      None => @core.JsValue::null()
      Some(_) => g3_str("set")
    },
  )
  scene.as_scene().background = Some(Color(@math.Color::new(0.5, 0.25, 0.125)))
  g3_log_push(gl, "## scene sharp")
  let t5 = pmrem.from_scene(scene, sigma=0, near=0.5, far=50, size=300)
  mock_note(gl, "t5", g3_describe_target(t5))
  mock_note(
    gl,
    "autoClear",
    g3_arr(
      [
        renderer.auto_clear,
        renderer.auto_clear_color,
        renderer.auto_clear_depth,
        renderer.auto_clear_stencil,
      ].map(fn(b) { @core.JsValue::of(b) }),
    ),
  )
  g3_log_push(gl, "## dispose")
  pmrem.dispose()
  let log = emit_log("pmrem_all", gl)
  assert_true(log.length() > 1000)
}

///|
/// The fake post-processing passes of output_all.mjs.
struct G3Effect {
  name : String
  gl : @webgl.WebGL2RenderingContext
  ids : Array[@core.RenderTarget]
  enabled : Bool
  needs_swap : Bool
  render_pass : (@core.Object3D, @core.Object3D)?
  needs_depth_texture : Bool
  has_set_size : Bool
}

///|
fn G3Effect::tid(self : G3Effect, t : @core.RenderTarget?) -> @core.JsValue {
  guard t is Some(t) else { return @core.JsValue::null() }
  let mut i = -1
  for j, seen in self.ids {
    if physical_equal(seen, t) {
      i = j
      break
    }
  }
  if i == -1 {
    self.ids.push(t)
    i = self.ids.length() - 1
  }
  g3_arr([
    g3_num(i.to_double()),
    g3_num(t.width.to_double()),
    g3_num(t.height.to_double()),
    g3_num(t.texture().type_.to_double()),
    @core.JsValue::of(t.depth_texture() is Some(_)),
    g3_num(t.samples.to_double()),
  ])
}

///|
impl @webgl.WebGLOutputEffect for G3Effect with fn render(
  self,
  r,
  write,
  read,
  dt,
) {
  match self.render_pass {
    Some((scene, camera)) => {
      mock_note(
        self.gl,
        "renderPass",
        g3_arr([self.tid(write), self.tid(Some(read))]),
      )
      r.set_render_target(write)
      r.render(scene, camera)
    }
    None =>
      mock_note(
        self.gl,
        self.name + " render",
        g3_arr([
          self.tid(write),
          self.tid(Some(read)),
          match dt {
            Some(dt) => g3_num(dt)
            None => g3_str("undefined")
          },
          g3_num(r.tone_mapping.to_double()),
        ]),
      )
  }
}

///|
impl @webgl.WebGLOutputEffect for G3Effect with fn enabled(self) {
  self.enabled
}

///|
impl @webgl.WebGLOutputEffect for G3Effect with fn needs_swap(self) {
  self.needs_swap
}

///|
impl @webgl.WebGLOutputEffect for G3Effect with fn is_render_pass(self) {
  self.render_pass is Some(_)
}

///|
impl @webgl.WebGLOutputEffect for G3Effect with fn needs_depth_texture(self) {
  self.needs_depth_texture
}

///|
impl @webgl.WebGLOutputEffect for G3Effect with fn set_size(self, w, h) {
  if self.has_set_size {
    mock_note(
      self.gl,
      self.name + " setSize",
      g3_nums([w.to_double(), h.to_double()]),
    )
  }
}

///|
impl @webgl.WebGLOutputEffect for G3Effect with fn set_depth_texture(self, t) {
  let (w, h) = match t.image() {
    DataImage(d) => (d.width.to_double(), d.height.to_double())
    _ => (-1.0, -1.0)
  }
  mock_note(
    self.gl,
    self.name + " setDepthTexture",
    g3_nums([t.format.to_double(), t.type_.to_double(), w, h]),
  )
}

///|
test "diff output_all" {
  let gl = mock_gl(options=g3_options(unlit=true))
  let renderer = g3_renderer(gl, output_buffer_type=@core.HalfFloatType)
  let scene = @core.Scene::new()
  let camera = @core.PerspectiveCamera::new(fov=50, aspect=2, near=0.1, far=100)
  ignore(camera.position.set(0, 0, 5))
  let material = @core.MeshBasicMaterial::new()
  ignore(material.color.unwrap().set_hex(0x408020))
  ignore(scene.add(g3_mesh(@geometries.BoxGeometry::new(), material)))
  fn frame(label : String) {
    g3_log_push(gl, "## " + label)
    renderer.render(scene, camera)
  }

  let ids = []
  fn effect(
    name : String,
    enabled : Bool,
    needs_swap : Bool,
    needs_depth_texture : Bool,
  ) -> &@webgl.WebGLOutputEffect {
    G3Effect::{
      name,
      gl,
      ids,
      enabled,
      needs_swap,
      render_pass: None,
      needs_depth_texture,
      has_set_size: true,
    }
  }

  renderer.tone_mapping = @core.ACESFilmicToneMapping
  frame("aces")
  frame("aces again")
  renderer.tone_mapping = @core.NeutralToneMapping
  frame("neutral")
  renderer.set_output_color_space(@core.LinearSRGBColorSpace)
  frame("linear")
  renderer.set_output_color_space(@core.SRGBColorSpace)
  let depth_effect = effect("depth", true, true, true)
  let disabled = effect("disabled", false, true, false)
  let no_swap = effect("noSwap", true, false, false)
  let plain = effect("plain", true, true, false)
  g3_log_push(gl, "## setEffects")
  renderer.set_effects(
    Some([
      depth_effect,
      disabled,
      no_swap,
      plain,
      effect("last", true, true, false),
    ]),
  )
  frame("effects")
  g3_log_push(gl, "## setSize")
  renderer.set_size(80, 40)
  frame("effects resized")
  let render_pass : &@webgl.WebGLOutputEffect = G3Effect::{
    name: "renderPass",
    gl,
    ids,
    enabled: true,
    needs_swap: true,
    render_pass: Some((scene, camera)),
    needs_depth_texture: false,
    has_set_size: false,
  }
  g3_log_push(gl, "## render pass")
  renderer.set_effects(Some([render_pass, plain]))
  frame("render pass")
  g3_log_push(gl, "## no effects")
  renderer.set_effects(None)
  frame("no effects")
  renderer.tone_mapping = @core.NoToneMapping
  frame("no tone mapping")
  renderer.tone_mapping = @core.ReinhardToneMapping
  let rt = @webgl.WebGLRenderTarget::new(width=16, height=8)
  renderer.set_render_target(Some(rt))
  frame("render target")
  renderer.set_render_target(None)
  frame("back to canvas")
  g3_log_push(gl, "## dispose")
  renderer.dispose()
  let log = emit_log("output_all", gl)
  assert_true(log.length() > 500)
}
