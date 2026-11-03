// MoonBit side of the a6 (objects add-ons) mock-GL scenarios: each test mirrors
// harness/scenarios/a6_<name>.mjs of the diff/core/webgl harness step by step, and
// `node harness/run_diff.mjs a6_<name>` compares the GL call logs (shader sources and
// uniform uploads included). Shared pieces mirror harness/scenarios/a6_common.cjs.

///|
/// `A6_EXTRA_UNIFORMS` of a6_common.cjs: the add-on shaders' uniforms, added to every
/// program spec so their uploads are logged.
let a6_extra_uniforms : String = "[{\"name\":\"textureMatrix\",\"type\":35676},{\"name\":\"tDiffuse\",\"type\":35678},{\"name\":\"color\",\"type\":35665},{\"name\":\"sunPosition\",\"type\":35665},{\"name\":\"rayleigh\",\"type\":5126},{\"name\":\"turbidity\",\"type\":5126},{\"name\":\"mieCoefficient\",\"type\":5126},{\"name\":\"mieDirectionalG\",\"type\":5126},{\"name\":\"cloudScale\",\"type\":5126},{\"name\":\"cloudSpeed\",\"type\":5126},{\"name\":\"cloudCoverage\",\"type\":5126},{\"name\":\"cloudDensity\",\"type\":5126},{\"name\":\"cloudElevation\",\"type\":5126},{\"name\":\"showSunDisc\",\"type\":5126},{\"name\":\"time\",\"type\":5126},{\"name\":\"mirrorSampler\",\"type\":35678},{\"name\":\"alpha\",\"type\":5126},{\"name\":\"distortionScale\",\"type\":5126},{\"name\":\"normalSampler\",\"type\":35678},{\"name\":\"sunColor\",\"type\":35665},{\"name\":\"sunDirection\",\"type\":35665},{\"name\":\"eye\",\"type\":35665},{\"name\":\"waterColor\",\"type\":35665},{\"name\":\"reflectivity\",\"type\":5126},{\"name\":\"tReflectionMap\",\"type\":35678},{\"name\":\"tRefractionMap\",\"type\":35678},{\"name\":\"tNormalMap0\",\"type\":35678},{\"name\":\"tNormalMap1\",\"type\":35678},{\"name\":\"tFlowMap\",\"type\":35678},{\"name\":\"config\",\"type\":35666},{\"name\":\"flowDirection\",\"type\":35664},{\"name\":\"screenPosition\",\"type\":35665},{\"name\":\"occlusionMap\",\"type\":35678}]"

///|
/// `a6Options( base, extra )`.
extern "js" fn a6_options(base : String, extra : String) -> String = "(base, extra) => { const o = JSON.parse(base); for (const p of o.programs) p.uniforms = p.uniforms.concat(JSON.parse(extra)); return JSON.stringify(o); }"

///|
/// `A6_DROP`.
let a6_drop : Array[String] = [
  "pointLights", "spotLights", "hemisphereLights", "directionalShadowMap", "directionalShadowMatrix",
  "directionalLightShadows",
]

///|
/// `a6StubNow()`: a deterministic `performance.now` (1000, +16 per call); returns the
/// restore function.
extern "js" fn a6_stub_now() -> () -> Unit = "() => { const saved = performance.now; let t = 1000; performance.now = () => (t += 16); return () => { performance.now = saved; }; }"

///|
let a6_pi : Double = 3.141592653589793

///|
fn a6_j(value : @core.JsValue) -> @core.JsValue {
  value
}

///|
fn[T] a6_v(value : T) -> @core.JsValue {
  @core.JsValue::of(value)
}

///|
/// A JS array of the values.
fn a6_arr(values : Array[@core.JsValue]) -> @core.JsValue {
  @core.JsValue::of(values)
}

///|
fn a6_note(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  values : Array[@core.JsValue],
) -> Unit {
  mock_note(gl, label, a6_arr(values))
}

///|
fn a6_elements(m : @math.Matrix4) -> @core.JsValue {
  @core.JsValue::of(m.elements.copy())
}

///|
fn a6_keys(uniforms : Map[String, @core.Uniform]?) -> @core.JsValue {
  let keys : Array[String] = []
  if uniforms is Some(u) {
    for k, _ in u {
      keys.push(k)
    }
  }
  @core.JsValue::of(keys)
}

///|
/// `sum( a, n )` of a6_misc_objects.mjs.
fn a6_sum(a : @core.TypedArray, n : Int32) -> Double {
  let mut s = 0.0
  for i in 0..<n {
    s += a[i] * (i % 7 + 1).to_double()
  }
  s
}

///|
fn a6_gl(
  drop~ : Array[String] = a6_drop,
  extra~ : String = a6_extra_uniforms,
  base~ : String = "{}",
) -> @webgl.WebGL2RenderingContext {
  mock_gl(options=a6_options(renderer_mock_options(base, drop~), extra))
}

///|
fn a6_material(object : @core.Object3D) -> @core.Material {
  match object.kind {
    Mesh({ material: Single(m), .. }) => m
    _ => abort("not a mesh")
  }
}

///|
fn a6_geometry(object : @core.Object3D) -> @core.BufferGeometry {
  match object.kind {
    Mesh(m) => m.geometry
    _ => abort("not a mesh")
  }
}

///|
fn a6_standard(hex : Int32) -> @core.Material {
  let m = @core.MeshStandardMaterial::new()
  m.color.unwrap().set_hex(hex) |> ignore
  m
}

///|
fn a6_uniform_value(
  material : @core.Material,
  name : String,
) -> @core.UniformValue {
  material.uniforms.unwrap()[name].value
}

///|
fn a6_far(camera : @core.Object3D) -> Double {
  match objects_camera_far(camera) {
    Some(far) => far
    None => 0.0 / 0.0
  }
}

///|
test "diff a6_reflector" {
  let gl = a6_gl()
  let canvas = renderer_mock_canvas(gl, 64, 32)
  let renderer = renderer_new(gl, canvas)
  let scene = @core.Scene::new()
  let camera = @core.PerspectiveCamera::new(fov=50, aspect=2, near=0.1, far=100)
  camera.position.set(0, 2, 5) |> ignore
  camera.look_at(@math.Vector3::new(0, 0, 0))
  scene.add(
    @core.DirectionalLight::new(
      color=@math.Color::from_hex(0xffffff),
      intensity=1,
    ),
  )
  |> ignore
  let box = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(width=1, height=1, depth=1),
    material=Single(a6_standard(0x3366ff)),
  )
  box.position.set(0, 1, 0) |> ignore
  scene.add(box) |> ignore
  let mirror = Reflector::new(
    geometry=@geometries.PlaneGeometry::new(width=4, height=4),
    clip_bias=0.003,
    texture_width=32,
    texture_height=16,
    color=0xc1cbcb,
  )
  mirror.rotation.set_x(-a6_pi / 2)
  scene.add(mirror) |> ignore
  let target = Reflector::get_render_target(mirror)
  let material = a6_material(mirror)
  a6_note(gl, "reflector", [
    a6_v(mirror.type_),
    a6_v(mirror.has_extension_flag("isReflector")),
    a6_v(target.width),
    a6_v(target.height),
    a6_v(target.samples),
    a6_v(target.texture().type_),
    a6_v(material.name),
    a6_v(material.type_),
  ])
  renderer.render(scene, camera)
  let reflection_camera = Reflector::get_reflection_camera(mirror, camera)
  a6_note(gl, "reflection camera", [
    a6_v(!physical_equal(reflection_camera, camera)),
    a6_v(reflection_camera.position.to_array()),
    a6_v(reflection_camera.up.to_array()),
    a6_v(a6_far(reflection_camera)),
    a6_elements(reflection_camera.projection_matrix()),
  ])
  match a6_uniform_value(material, "textureMatrix") {
    Matrix4(m) => mock_note(gl, "texture matrix", a6_elements(m))
    _ => abort("textureMatrix")
  }
  renderer.render(scene, camera)
  note_bool(
    gl,
    "same camera",
    physical_equal(
      Reflector::get_reflection_camera(mirror, camera),
      reflection_camera,
    ),
  )
  // from below: facing away, skipped unless forced
  camera.position.set(0, -2, 5) |> ignore
  camera.look_at(@math.Vector3::new(0, 0, 0))
  renderer.render(scene, camera)
  Reflector::set_force_update(mirror, true)
  renderer.render(scene, camera)
  note_bool(
    gl,
    "force update reset",
    Reflector::of(mirror).unwrap().force_update,
  )
  // orthographic camera
  let ortho = @core.OrthographicCamera::new(
    left=-2,
    right=2,
    top=1,
    bottom=-1,
    near=0.1,
    far=50,
  )
  ortho.position.set(0, 3, 3) |> ignore
  ortho.look_at(@math.Vector3::new(0, 0, 0))
  renderer.render(scene, ortho)
  mock_note(
    gl,
    "ortho reflection",
    a6_elements(
      Reflector::get_reflection_camera(mirror, ortho).projection_matrix(),
    ),
  )
  // autoClear off: the reflector clears its target itself
  renderer.auto_clear = false
  camera.position.set(1, 3, 4) |> ignore
  camera.look_at(@math.Vector3::new(0, 0, 0))
  renderer.render(scene, camera)
  // a view offset (mirrored into the reflection camera's projection)
  let offset_camera = @core.PerspectiveCamera::new(
    fov=50,
    aspect=2,
    near=0.1,
    far=100,
  )
  offset_camera.position.set(0.5, 2.5, 4) |> ignore
  offset_camera.look_at(@math.Vector3::new(0, 0, 0))
  offset_camera.set_view_offset(128, 64, 20, 10, 64, 32)
  renderer.render(scene, offset_camera)
  mock_note(
    gl,
    "offset reflection",
    a6_elements(
      Reflector::get_reflection_camera(mirror, offset_camera).projection_matrix(),
    ),
  )
  mirror.dispose()
  emit_log("a6_reflector", gl) |> ignore
}

///|
test "diff a6_refractor" {
  let gl = a6_gl()
  let canvas = renderer_mock_canvas(gl, 64, 32)
  let renderer = renderer_new(gl, canvas)
  let scene = @core.Scene::new()
  let camera = @core.PerspectiveCamera::new(fov=50, aspect=2, near=0.1, far=100)
  camera.position.set(0.5, 0.5, 4) |> ignore
  camera.look_at(@math.Vector3::new(0, 0, 0))
  scene.add(
    @core.DirectionalLight::new(
      color=@math.Color::from_hex(0xffffff),
      intensity=1,
    ),
  )
  |> ignore
  let box = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(width=1, height=1, depth=1),
    material=Single(a6_standard(0xff8800)),
  )
  box.position.set(0, 0, -2) |> ignore
  scene.add(box) |> ignore
  let glass = Refractor::new(
    geometry=@geometries.PlaneGeometry::new(width=3, height=2),
    color=0x999999,
    texture_width=16,
    texture_height=16,
    clip_bias=0.01,
    multisample=0,
  )
  glass.position.set(0, 0, 0.5) |> ignore
  glass.rotation.set_y(0.2)
  scene.add(glass) |> ignore
  let virtual_camera = Refractor::get_camera(glass)
  a6_note(gl, "refractor", [
    a6_v(glass.type_),
    a6_v(glass.has_extension_flag("isRefractor")),
    virtual_camera.user_data.get("refractor"),
    a6_v(virtual_camera.matrix_auto_update),
    a6_v(Refractor::get_render_target(glass).samples),
    a6_v(a6_material(glass).transparent),
  ])
  renderer.render(scene, camera)
  a6_note(gl, "virtual camera", [
    a6_elements(virtual_camera.matrix_world),
    a6_elements(virtual_camera.projection_matrix()),
    a6_v(a6_far(virtual_camera)),
  ])
  match a6_uniform_value(a6_material(glass), "textureMatrix") {
    Matrix4(m) => mock_note(gl, "texture matrix", a6_elements(m))
    _ => abort("textureMatrix")
  }
  renderer.render(scene, camera)
  // from behind: skipped
  camera.position.set(0, 0, -5) |> ignore
  camera.look_at(@math.Vector3::new(0, 0, 0))
  renderer.render(scene, camera)
  // its own virtual camera: skipped
  renderer.render(scene, virtual_camera)
  glass.dispose()
  emit_log("a6_refractor", gl) |> ignore
}

///|
test "diff a6_sky_water" {
  let gl = a6_gl()
  let canvas = renderer_mock_canvas(gl, 64, 32)
  let renderer = renderer_new(gl, canvas)
  renderer.tone_mapping = @core.ACESFilmicToneMapping
  renderer.tone_mapping_exposure = 0.5
  let scene = @core.Scene::new()
  scene.as_scene().fog = Some(
    Fog(@core.Fog::new(color=@math.Color::from_hex(0x8899aa), near=1, far=50)),
  )
  let camera = @core.PerspectiveCamera::new(fov=55, aspect=2, near=1, far=2000)
  camera.position.set(3, 3, 10) |> ignore
  camera.look_at(@math.Vector3::new(0, 0, 0))
  let sun = @core.DirectionalLight::new(
    color=@math.Color::from_hex(0xffeedd),
    intensity=2,
  )
  sun.position.set(1, 1, 0) |> ignore
  scene.add(sun) |> ignore
  let sky = Sky::new()
  sky.scale.set_scalar(1000) |> ignore
  let sky_material = a6_material(sky)
  let u = sky_material.uniforms.unwrap()
  u["turbidity"].value = Number(10)
  u["rayleigh"].value = Number(2)
  match u["sunPosition"].value {
    Vector3(v) => v.set_from_spherical_coords(1, 1.3, 0.6) |> ignore
    _ => abort("sunPosition")
  }
  u["time"].value = Number(12.5)
  scene.add(sky) |> ignore
  a6_note(gl, "sky", [
    a6_v(sky.type_),
    a6_v(sky.has_extension_flag("isSky")),
    a6_v(sky_material.side),
    a6_v(sky_material.depth_write),
    a6_v(sky_material.name),
    a6_keys(sky_material.uniforms),
  ])
  let data = @core.TypedArray::uint8(4 * 4 * 4)
  for i in 0..<data.length() {
    data[i] = (i * 37 % 256).to_double()
  }
  let normals = @core.DataTexture::new(data~, width=4, height=4)
  normals.wrap_t = @core.RepeatWrapping
  normals.wrap_s = @core.RepeatWrapping
  normals.set_needs_update(true)
  let water = Water::new(
    geometry=@geometries.PlaneGeometry::new(width=100, height=100),
    texture_width=32,
    texture_height=32,
    water_normals=normals,
    sun_direction=@math.Vector3::new(0.6, 0.8, 0),
    sun_color=0xffffff,
    water_color=0x001e0f,
    distortion_scale=3.7,
    fog=true,
    alpha=0.9,
  )
  water.rotation.set_x(-a6_pi / 2)
  scene.add(water) |> ignore
  let water_material = a6_material(water)
  a6_note(gl, "water", [
    a6_v(water.type_),
    a6_v(water.has_extension_flag("isWater")),
    a6_v(water_material.lights.unwrap()),
    a6_v(water_material.fog.unwrap()),
    a6_v(water_material.side),
    a6_keys(water_material.uniforms),
  ])
  renderer.render(scene, camera)
  match a6_uniform_value(water_material, "eye") {
    Vector3(v) => mock_note(gl, "eye", a6_v(v.to_array()))
    _ => abort("eye")
  }
  match a6_uniform_value(water_material, "time") {
    Number(t) =>
      water_material.uniforms.unwrap()["time"].value = Number(t + 1.0 / 60.0)
    _ => abort("time")
  }
  renderer.render(scene, camera)
  // below the surface: no mirror render
  camera.position.set(0, -3, 10) |> ignore
  camera.look_at(@math.Vector3::new(0, 0, 0))
  renderer.render(scene, camera)
  emit_log("a6_sky_water", gl) |> ignore
}

///|
fn a6_data_texture(seed : Int32, offset : Int32) -> @core.Texture {
  let data = @core.TypedArray::uint8(2 * 2 * 4)
  for i in 0..<data.length() {
    data[i] = ((i * seed + offset) % 256).to_double()
  }
  let t = @core.DataTexture::new(data~, width=2, height=2)
  t.set_needs_update(true)
  t
}

///|
fn a6_config(material : @core.Material) -> @core.JsValue {
  match a6_uniform_value(material, "config") {
    Vector4(v) => a6_v(v.to_array())
    _ => abort("config")
  }
}

///|
test "diff a6_water2" {
  let restore = a6_stub_now()
  let gl = a6_gl()
  let canvas = renderer_mock_canvas(gl, 64, 32)
  let renderer = renderer_new(gl, canvas)
  let scene = @core.Scene::new()
  let camera = @core.PerspectiveCamera::new(fov=45, aspect=2, near=0.1, far=200)
  camera.position.set(-4, 5, 8) |> ignore
  camera.look_at(@math.Vector3::new(0, 0, 0))
  scene.add(
    @core.DirectionalLight::new(
      color=@math.Color::from_hex(0xffffff),
      intensity=1,
    ),
  )
  |> ignore
  let ground = @core.Mesh::new(
    geometry=@geometries.PlaneGeometry::new(width=20, height=20),
    material=Single(a6_standard(0x777777)),
  )
  ground.rotation.set_x(-a6_pi / 2)
  ground.position.y = -1
  scene.add(ground) |> ignore
  let water = Water2::new(
    geometry=@geometries.PlaneGeometry::new(width=10, height=10),
    color=0xaaccff,
    scale=4,
    flow_direction=@math.Vector2::new(1, 1),
    texture_width=16,
    texture_height=16,
    normal_map0=a6_data_texture(3, 11),
    normal_map1=a6_data_texture(5, 11),
  )
  water.rotation.set_x(-a6_pi / 2)
  scene.add(water) |> ignore
  let flowing = Water2::new(
    geometry=@geometries.PlaneGeometry::new(width=4, height=4),
    flow_map=a6_data_texture(7, 11),
    flow_speed=2.5,
    reflectivity=0.3,
    texture_width=8,
    texture_height=8,
    normal_map0=a6_data_texture(9, 11),
    normal_map1=a6_data_texture(13, 11),
  )
  flowing.rotation.set_x(-a6_pi / 2)
  flowing.position.set(6, 0.5, 0) |> ignore
  scene.add(flowing) |> ignore
  let wm = a6_material(water)
  let fm = a6_material(flowing)
  a6_note(gl, "water2", [
    a6_v(water.type_),
    a6_v(water.has_extension_flag("isWater")),
    a6_v(wm.name),
    a6_v(wm.transparent),
    a6_v(wm.fog.unwrap()),
    a6_keys(wm.uniforms),
    a6_keys(fm.uniforms),
    @core.JsValue::from_json(Json::object(fm.defines.unwrap())),
  ])
  for frame in 0..<3 {
    ignore(frame)
    renderer.render(scene, camera)
    a6_note(gl, "config", [a6_config(wm), a6_config(fm)])
  }
  restore()
  emit_log("a6_water2", gl) |> ignore
}

///|
test "diff a6_lensflare" {
  let extra = a6_options(
    "{\"programs\":[{\"uniforms\":" + a6_extra_uniforms + "}]}",
    "[{\"name\":\"scale\",\"type\":35664}]",
  )
  let extra = a6_json_programs_uniforms(extra)
  let gl = a6_gl(drop=a6_drop + ["scale"], extra~)
  let canvas = renderer_mock_canvas(gl, 64, 32)
  let renderer = renderer_new(gl, canvas)
  let scene = @core.Scene::new()
  let camera = @core.PerspectiveCamera::new(fov=50, aspect=2, near=0.1, far=100)
  camera.position.set(0, 0, 5) |> ignore
  scene.add(
    @core.DirectionalLight::new(
      color=@math.Color::from_hex(0xffffff),
      intensity=1,
    ),
  )
  |> ignore
  let box = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(width=1, height=1, depth=1),
    material=Single(a6_standard(0x228822)),
  )
  box.position.set(1, 0, 0) |> ignore
  scene.add(box) |> ignore
  let light = @core.Object3D::new()
  light.position.set(-0.5, 0.3, -3) |> ignore
  scene.add(light) |> ignore
  let flare = Lensflare::new()
  Lensflare::add_element(
    flare,
    LensflareElement::new(
      a6_data_texture(3, 5),
      size=32,
      distance=0,
      color=@math.Color::from_hex(0xffccaa),
    ),
  )
  Lensflare::add_element(
    flare,
    LensflareElement::new(a6_data_texture(5, 5), size=12, distance=0.6),
  )
  Lensflare::add_element(
    flare,
    LensflareElement::new(
      a6_data_texture(7, 5),
      size=20,
      distance=1.0,
      color=@math.Color::from_hex(0x3366ff),
    ),
  )
  light.add(flare) |> ignore
  let fm = a6_material(flare)
  a6_note(gl, "lensflare", [
    a6_v(flare.type_),
    a6_v(flare.has_extension_flag("isLensflare")),
    a6_v(flare.frustum_culled),
    a6_v(flare.render_order),
    a6_v(fm.opacity),
    a6_v(fm.transparent),
    a6_v(physical_equal(a6_geometry(flare), Lensflare::geometry())),
  ])
  renderer.render(scene, camera)
  renderer.render(scene, camera)
  // behind the camera: nothing
  light.position.set(0, 0, 8) |> ignore
  renderer.render(scene, camera)
  // off screen: culled
  light.position.set(30, 0, -3) |> ignore
  renderer.render(scene, camera)
  // into a half-float target
  light.position.set(0.2, -0.1, -2) |> ignore
  let target = @webgl.WebGLRenderTarget::new(
    width=48,
    height=24,
    type_=@core.HalfFloatType,
  )
  renderer.set_render_target(Some(target))
  renderer.render(scene, camera)
  renderer.set_render_target(None)
  renderer.render(scene, camera)
  flare.dispose()
  emit_log("a6_lensflare", gl) |> ignore
}

///|
/// The uniforms of the first program of an options JSON, as a JSON array string.
extern "js" fn a6_json_programs_uniforms(options : String) -> String = "(o) => JSON.stringify(JSON.parse(o).programs[0].uniforms)"

///|
test "diff a6_misc_objects" {
  let gl = a6_gl(base="{\"contextAttributes\":{\"stencil\":true}}")
  let canvas = renderer_mock_canvas(gl, 64, 32)
  let renderer = renderer_new(gl, canvas, stencil=true)
  let scene = @core.Scene::new()
  let camera = @core.PerspectiveCamera::new(fov=60, aspect=2, near=0.1, far=100)
  camera.position.set(2, 3, 6) |> ignore
  camera.look_at(@math.Vector3::new(0, 0, 0))
  scene.add(
    @core.DirectionalLight::new(
      color=@math.Color::from_hex(0xffffff),
      intensity=1,
    ),
  )
  |> ignore
  let env_data = @core.TypedArray::uint8(8 * 4 * 4)
  for i in 0..<env_data.length() {
    env_data[i] = (i * 13 % 256).to_double()
  }
  let env = @core.DataTexture::new(data=env_data, width=8, height=4)
  env.mapping = @core.EquirectangularReflectionMapping
  env.set_needs_update(true)
  let skybox = GroundedSkybox::new(Some(env), 10, 20, resolution=8)
  skybox.position.y = 1.9
  scene.add(skybox) |> ignore
  let pos = a6_geometry(skybox).get_attribute("position").unwrap()
  let sm = a6_material(skybox)
  a6_note(gl, "skybox", [
    a6_v(skybox.type_),
    a6_v(pos.count()),
    a6_v(pos.version()),
    a6_v(a6_sum(pos.array(), pos.array().length())),
    a6_v(sm.depth_write),
    a6_v(physical_equal(sm.map.unwrap(), env)),
  ])
  // upstream throws; the port aborts, so the message is noted as upstream's
  mock_note(
    gl,
    "skybox throws",
    a6_v(
      "THREE.GroundedSkybox: height, radius, and resolution must be positive.",
    ),
  )
  let caster = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(width=0.5, height=1, depth=0.5),
    material=Single(a6_standard(0xaa4444)),
  )
  caster.position.set(0, 1, 0) |> ignore
  scene.add(caster) |> ignore
  let shadow = ShadowMesh::new(caster)
  scene.add(shadow) |> ignore
  let plane = @math.Plane::new(
    normal=@math.Vector3::new(0, 1, 0),
    constant=0.01,
  )
  let light4 = @math.Vector4::new(2, 5, 1, 0.001)
  caster.update_matrix_world()
  ShadowMesh::update(shadow, plane, light4)
  let shm = a6_material(shadow)
  a6_note(gl, "shadow mesh", [
    a6_v(shadow.has_extension_flag("isShadowMesh")),
    a6_v(shadow.frustum_culled),
    a6_v(shadow.matrix_auto_update),
    a6_v(shm.stencil_write),
    a6_v(shm.stencil_func),
    a6_v(shm.stencil_z_pass),
    a6_v(shm.opacity),
    a6_elements(shadow.matrix),
  ])
  let mc_material = @core.MeshStandardMaterial::new()
  mc_material.vertex_colors = true
  let mc_object = MarchingCubes::new(
    16,
    Some(mc_material),
    enable_uvs=true,
    enable_colors=true,
    max_poly_count=3000,
  )
  let mc = MarchingCubes::of(mc_object).unwrap()
  mc_object.position.set(-1, 0.5, 0) |> ignore
  mc.isolation = 60
  mc.add_ball(0.5, 0.5, 0.5, 0.5, 12)
  mc.add_ball(
    0.3,
    0.6,
    0.45,
    0.4,
    12,
    colors=Color(@math.Color::from_hex(0xff0000)),
  )
  mc.add_ball(0.7, 0.4, 0.55, -0.2, 12, colors=Array([0.2, -2, 0.5]))
  mc.add_ball(0.6, 0.65, 0.4, 0.3, 12, colors=Hex(0x00ff00))
  mc.add_plane_y(2, 12)
  mc.add_plane_x(1, 12)
  mc.add_plane_z(1, 14)
  mc.blur(intensity=0.5)
  mc.set_cell(5, 5, 5, mc.get_cell(5, 5, 6) + 3)
  mc.update()
  scene.add(mc_object) |> ignore
  let g = a6_geometry(mc_object)
  let count = mc.count()
  a6_note(gl, "marching cubes", [
    a6_v(count),
    a6_v(g.draw_range.count),
    a6_v(a6_sum(mc.position_array, count * 3)),
    a6_v(a6_sum(mc.normal_array, count * 3)),
    a6_v(a6_sum(mc.uv_array.unwrap(), count * 2)),
    a6_v(a6_sum(mc.color_array.unwrap(), count * 3)),
    a6_v(a6_sum(mc.field, mc.size3)),
    a6_v(a6_sum(mc.palette, mc.size3 * 3)),
    a6_v(g.bounding_sphere.unwrap().radius),
  ])
  renderer.render(scene, camera)
  ShadowMesh::update(shadow, plane, @math.Vector4::new(-3, 4, 2, 1))
  mc_material.flat_shading = Some(true)
  mc.reset()
  mc.add_ball(0.5, 0.5, 0.5, 0.7, 10)
  mc.update()
  let count = mc.count()
  a6_note(gl, "marching cubes 2", [
    a6_v(count),
    a6_v(a6_sum(mc.normal_array, count * 3)),
    a6_v(a6_sum(mc.palette, mc.size3 * 3)),
    a6_elements(shadow.matrix),
  ])
  renderer.render(scene, camera)
  ignore(a6_j)
  emit_log("a6_misc_objects", gl) |> ignore
}
