// The shadow_sunlight differential scenario: a port of the SunLight addon
// (examples/jsm/lights/SunLight.js, SunLightShadow.js) registered through
// `register_sun_light`, rendered by WebGLRenderer so WebGLShadowMap takes the cascade
// path (`getCamera` / `getFrustum` / `getViewport` per cascade and
// `updateMatrices( light, camera )`). Mirrors harness/scenarios/shadow_sunlight.mjs.

///|
/// renderer_common's options without the absent lights' uniforms, plus group 3's and
/// the sun light's (`SUN_DROP`, `SUN_UNIFORMS` of shadow_sunlight.mjs).
extern "js" fn sun_mock_options(
  common : @core.JsValue,
  g3_extra : String,
) -> String =
  #|(c, g3) => {
  #|  const drop = ['directionalLights', 'directionalShadow', 'directionalLightShadows', 'pointLights', 'pointShadow',
  #|    'spotLights', 'spotShadow', 'spotLightMatrix', 'hemisphereLights'];
  #|  const sun = [
  #|    { name: 'sunLights[0].direction', type: 0x8B51 }, { name: 'sunLights[0].color', type: 0x8B51 },
  #|    { name: 'sunShadowMap[0]', type: 0x8B62 }, { name: 'sunShadowMatrix[0]', type: 0x8B5C, size: 2 },
  #|    { name: 'sunShadowCascade[0]', type: 0x8B52, size: 2 },
  #|    { name: 'sunLightShadows[0].shadowBias', type: 0x1406 }, { name: 'sunLightShadows[0].shadowMapSize', type: 0x8B50 },
  #|  ];
  #|  const o = JSON.parse(c.mockOptions({}, drop));
  #|  const extra = JSON.parse(g3).filter((u) => !drop.some((d) => u.name.startsWith(d))).concat(sun);
  #|  o.programs = o.programs.map((p) => ({ attributes: p.attributes, uniforms: p.uniforms.concat(extra) }));
  #|  return JSON.stringify(o);
  #|}

///|
extern "js" fn sun_math_min(a : Double, b : Double) -> Double = "Math.min"

///|
extern "js" fn sun_math_max(a : Double, b : Double) -> Double = "Math.max"

///|
extern "js" fn sun_math_max3(a : Double, b : Double, c : Double) -> Double = "Math.max"

///|
extern "js" fn sun_math_ceil(x : Double) -> Double = "Math.ceil"

///|
extern "js" fn sun_math_pow(x : Double, y : Double) -> Double = "Math.pow"

///|
extern "js" fn sun_math_round(x : Double) -> Double = "Math.round"

///|
extern "js" fn sun_math_abs(x : Double) -> Double = "Math.abs"

///|
extern "js" fn sun_math_sqrt(x : Double) -> Double = "Math.sqrt"

///|
let sun_light_orientation_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
let sun_view_to_light_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
let sun_light_direction : @math.Vector3 = @math.Vector3::new(0, 0, 0)

///|
let sun_up : @math.Vector3 = @math.Vector3::new(0, 0, 0)

///|
let sun_center : @math.Vector3 = @math.Vector3::new(0, 0, 0)

///|
let sun_near_corners : Array[@math.Vector3] = Array::makei(4, _ => {
  @math.Vector3::new(0, 0, 0)
})

///|
let sun_far_corners : Array[@math.Vector3] = Array::makei(4, _ => {
  @math.Vector3::new(0, 0, 0)
})

///|
let sun_cascade_corners : Array[@math.Vector3] = Array::makei(8, _ => {
  @math.Vector3::new(0, 0, 0)
})

///|
/// `SunLightShadow`'s own state; the `LightShadow` part is the light's core shadow.
struct SunShadow {
  cameras : Array[@core.Object3D]
  matrices : Array[@math.Matrix4]
  frustums : Array[@math.Frustum]
  cascade_splits : Array[Double]
  cascade_data : Array[@math.Vector4]
}

///|
impl @webgl.SunLightShadowSource for SunShadow with fn get_matrix(self, j) {
  self.matrices[j]
}

///|
impl @webgl.SunLightShadowSource for SunShadow with fn cascade_data(self, j) {
  Vector4(self.cascade_data[j])
}

///|
impl @webgl.SunLightShadowSource for SunShadow with fn get_camera(self, _, j) {
  self.cameras[j]
}

///|
impl @webgl.SunLightShadowSource for SunShadow with fn get_frustum(self, _, j) {
  self.frustums[j]
}

///|
fn sun_camera_near(camera : @core.Object3D) -> Double {
  match camera.as_camera().kind {
    PerspectiveCamera(c) => c.near
    OrthographicCamera(c) => c.near
    BaseCamera => abort("no near")
  }
}

///|
fn sun_camera_far(camera : @core.Object3D) -> Double {
  match camera.as_camera().kind {
    PerspectiveCamera(c) => c.far
    OrthographicCamera(c) => c.far
    BaseCamera => abort("no far")
  }
}

///|
/// `SunLightShadow.updateMatrices( light, viewCamera )`.
impl @webgl.SunLightShadowSource for SunShadow with fn update_matrices(
  self,
  shadow,
  light,
  view_camera,
) {
  let cascade_count = 2
  // inset the cascade viewports so shadow filtering cannot read across atlas tiles
  let inset_x = sun_math_min(
    0.25,
    (sun_math_ceil(shadow.radius) + 1.0) / shadow.map_size.x,
  )
  let inset_y = sun_math_min(
    0.25,
    (sun_math_ceil(shadow.radius) + 1.0) / shadow.map_size.y,
  )
  for i in 0..<cascade_count {
    ignore(
      shadow._viewports[i].set(
        i.to_double() + inset_x,
        inset_y,
        1.0 - 2.0 * inset_x,
        1.0 - 2.0 * inset_y,
      ),
    )
  }
  let resolution_x = shadow.map_size.x * (1.0 - 2.0 * inset_x)
  let resolution_y = shadow.map_size.y * (1.0 - 2.0 * inset_y)
  let resolution = sun_math_min(resolution_x, resolution_y)
  let camera = shadow.camera
  let camera_near = sun_camera_near(view_camera)
  let camera_far = sun_math_max(
    camera_near + 1.0e-6,
    sun_math_min(sun_camera_far(camera), sun_camera_far(view_camera)),
  )

  // practical split scheme: the average of uniform and logarithmic splits
  let splits = self.cascade_splits
  splits[0] = camera_near
  for i in 1..<cascade_count {
    let amount = i.to_double() / cascade_count.to_double()
    let uniform = camera_near + (camera_far - camera_near) * amount
    let logarithmic = if camera_near > 0.0 {
      camera_near * sun_math_pow(camera_far / camera_near, amount)
    } else {
      uniform
    }
    splits[i] = (uniform + logarithmic) * 0.5
  }
  splits[cascade_count] = camera_far
  ignore(
    sun_light_direction
    .set_from_matrix_position(light.matrix_world)
    .negate()
    .normalize(),
  )
  ignore(sun_up.set(0, 1, 0))
  if sun_math_abs(sun_up.dot(sun_light_direction)) > 0.99 {
    ignore(sun_up.set(0, 0, 1))
  }
  ignore(
    sun_light_orientation_matrix.look_at(
      sun_center.set(0, 0, 0),
      sun_light_direction,
      sun_up,
    ),
  )
  ignore(
    sun_view_to_light_matrix
    .copy(sun_light_orientation_matrix)
    .transpose()
    .multiply(view_camera.matrix_world),
  )

  // view frustum corners in light space
  let view_data = view_camera.as_camera()
  let z_near = if view_data._reversed_depth {
    1.0
  } else if view_data.coordinate_system == @core.WebGPUCoordinateSystem {
    0.0
  } else {
    -1.0
  }
  let inverse_projection_matrix = view_data.projection_matrix_inverse
  let mut global_max_z = -1.0 / 0.0
  for i in 0..<4 {
    let x = if i == 0 || i == 1 { 1.0 } else { -1.0 }
    let y = if i == 0 || i == 3 { 1.0 } else { -1.0 }
    let near_corner = sun_near_corners[i]
      .set(x, y, z_near)
      .apply_matrix4(inverse_projection_matrix)
    let far_corner = sun_far_corners[i]
    if view_camera.is_perspective_camera() {
      ignore(
        far_corner.copy(near_corner).multiply_scalar(camera_far / camera_near),
      )
    } else {
      ignore(far_corner.set(near_corner.x, near_corner.y, -camera_far))
    }
    ignore(near_corner.apply_matrix4(sun_view_to_light_matrix))
    ignore(far_corner.apply_matrix4(sun_view_to_light_matrix))
    global_max_z = sun_math_max3(global_max_z, near_corner.z, far_corner.z)
  }

  // raise the ceiling one shadow range towards the light
  global_max_z += camera_far
  let shadow_near = sun_camera_near(camera)
  for i in 0..<cascade_count {
    let cascade_near = if i == 0 {
      splits[0]
    } else {
      self.cascade_data[i - 1].z
    }
    let cascade_far = splits[i + 1]
    let fade_start = cascade_far - 0.1 * (cascade_far - splits[i])
    ignore(
      self.cascade_data[i].set(
        if i == 0 {
          -1.0e10
        } else {
          cascade_near
        },
        cascade_far,
        fade_start,
        0,
      ),
    )
    let near_alpha = (cascade_near - camera_near) / (camera_far - camera_near)
    let far_alpha = (cascade_far - camera_near) / (camera_far - camera_near)
    ignore(sun_center.set(0, 0, 0))
    for j in 0..<4 {
      ignore(
        sun_cascade_corners[j * 2].lerp_vectors(
          sun_near_corners[j],
          sun_far_corners[j],
          near_alpha,
        ),
      )
      ignore(
        sun_cascade_corners[j * 2 + 1].lerp_vectors(
          sun_near_corners[j],
          sun_far_corners[j],
          far_alpha,
        ),
      )
      ignore(
        sun_center
        .add(sun_cascade_corners[j * 2])
        .add(sun_cascade_corners[j * 2 + 1]),
      )
    }
    ignore(sun_center.multiply_scalar(1.0 / 8.0))
    let mut radius_sq = 0.0
    let mut min_z = 1.0 / 0.0
    for j in 0..<8 {
      radius_sq = sun_math_max(
        radius_sq,
        sun_cascade_corners[j].distance_to_squared(sun_center),
      )
      min_z = sun_math_min(min_z, sun_cascade_corners[j].z)
    }
    let mut radius = sun_math_sqrt(radius_sq)

    // snap to the texel grid
    if resolution > 1.0 {
      radius /= 1.0 - 1.0 / resolution
      let texel_size_x = 2.0 * radius / resolution_x
      let texel_size_y = 2.0 * radius / resolution_y
      sun_center.x = sun_math_round(sun_center.x / texel_size_x) * texel_size_x
      sun_center.y = sun_math_round(sun_center.y / texel_size_y) * texel_size_y
    }

    // place the near plane at the caster ceiling
    sun_center.z = global_max_z + shadow_near
    ignore(sun_center.apply_matrix4(sun_light_orientation_matrix))
    let cascade_camera = self.cameras[i]
    ignore(cascade_camera.position.copy(sun_center))
    ignore(
      cascade_camera.quaternion.set_from_rotation_matrix(
        sun_light_orientation_matrix,
      ),
    )
    let cascade_data = cascade_camera.as_camera()
    guard cascade_data.kind is OrthographicCamera(ortho) else {
      abort("cascade camera")
    }
    ortho.left = -radius
    ortho.right = radius
    ortho.top = radius
    ortho.bottom = -radius
    ortho.near = shadow_near
    ortho.far = global_max_z - min_z + 2.0 * shadow_near
    cascade_data.coordinate_system = camera.as_camera().coordinate_system
    cascade_data._reversed_depth = camera.reversed_depth()
    cascade_camera.update_projection_matrix()
    cascade_camera.update_matrix_world()
    shadow._update_matrix(
      cascade_camera,
      self.matrices[i],
      self.frustums[i],
      viewport=shadow._viewports[i],
    )
  }
}

///|
struct SunExtension {}

///|
impl @core.Object3DExtension for SunExtension with fn type_name(_) {
  "SunLight"
}

///|
impl @core.Object3DExtension for SunExtension with fn construct(_) {
  @core.Light::new()
}

///|
impl @core.Object3DExtension for SunExtension with fn has_flag(_, flag) {
  flag == "isSunLight"
}

///|
/// `new SunLight( color, intensity )`, returning the light and its addon shadow.
fn sun_light_new(
  color : Int32,
  intensity : Double,
) -> (@core.Object3D, SunShadow) {
  let light = @core.Light::new(color=@math.Color::from_hex(color), intensity~)
  ignore(light.set_extension(SunExtension::{ }))
  ignore(light.position.copy(@core.object3d_default_up))
  light.update_matrix()
  let shadow = @core.LightShadow::new(
    @core.OrthographicCamera::new(
      left=-5,
      right=5,
      top=5,
      bottom=-5,
      near=0.5,
      far=500,
    ),
  )
  ignore(shadow.map_size.set(1024, 1024))
  let sun : SunShadow = {
    cameras: [],
    matrices: [],
    frustums: [],
    cascade_splits: [0, 0, 0],
    cascade_data: [],
  }
  shadow._viewport_count = 2
  ignore(shadow._frame_extents.set(2, 1))
  for _ in 0..<2 {
    sun.cameras.push(@core.OrthographicCamera::new())
    sun.matrices.push(@math.Matrix4::new())
    sun.frustums.push(@math.Frustum::new())
    sun.cascade_data.push(@math.Vector4::new(0, 0, 0, 1))
  }
  while shadow._viewports.length() < 2 {
    shadow._viewports.push(@math.Vector4::new(0, 0, 0, 1))
  }
  light.as_light().shadow = Some(shadow)
  @webgl.register_sun_light(light, sun)
  (light, sun)
}

///|
fn sun_v4(v : @math.Vector4) -> @core.JsValue {
  xj_nums([v.x, v.y, v.z, v.w])
}

///|
test "diff shadow_sunlight" {
  let gl = mock_gl(options=sun_mock_options(renderer_common, g3_extra_uniforms))
  let renderer = @webgl.WebGLRenderer::new(
    canvas=renderer_mock_canvas(gl, 64, 32),
    context=gl,
  )
  renderer.shadow_map.enabled = true
  let scene = @core.Scene::new()
  let camera = @core.PerspectiveCamera::new(fov=50, aspect=2, near=0.5, far=60)
  ignore(camera.position.set(2, 5, 12))
  camera.look_at_xyz(0, 0, 0)
  let (sun, sun_shadow) = sun_light_new(0xfff2e3, 3)
  sun.name = "sun"
  ignore(sun.position.set(3, 8, 2))
  sun.cast_shadow = true
  let shadow = sun.as_light().shadow.unwrap()
  ignore(shadow.map_size.set(256, 256))
  shadow.radius = 2
  guard shadow.camera.as_camera().kind is OrthographicCamera(shadow_ortho) else {
    abort("shadow camera")
  }
  shadow_ortho.far = 80
  ignore(scene.add(sun))
  let floor = renderer_mesh(
    @geometries.PlaneGeometry::new(width=80, height=80),
    @core.MeshPhongMaterial::new(),
  )
  floor.rotation.set_x(-3.141592653589793 / 2.0)
  floor.receive_shadow = true
  ignore(scene.add(floor))
  let boxes = [
    (1.0, 0.0, 0.5, 0.0),
    (2.0, 6.0, 1.0, -20.0),
    (3.0, -4.0, 1.5, -40.0),
    (1.0, 500.0, 0.0, 0.0),
  ]
  for box in boxes {
    let (size, x, y, z) = box
    let mesh = renderer_mesh(
      @geometries.BoxGeometry::new(width=size, height=size, depth=size),
      @core.MeshPhongMaterial::new(),
    )
    ignore(mesh.position.set(x, y, z))
    mesh.cast_shadow = true
    ignore(scene.add(mesh))
  }
  let note_sun = (label : String) => {
    for j in 0..<2 {
      let c = sun_shadow.cameras[j]
      let data = c.as_camera()
      guard data.kind is OrthographicCamera(o) else { abort("cascade camera") }
      let q = c.quaternion
      mock_note(
        gl,
        label + " cascade " + j.to_string(),
        xj_list([
          xj_nums(sun_shadow.matrices[j].elements),
          sun_v4(sun_shadow.cascade_data[j]),
          sun_v4(shadow._viewports[j]),
          xj_list([
            xj(o.left),
            xj(o.right),
            xj(o.top),
            xj(o.bottom),
            xj(o.near),
            xj(o.far),
            xj_int(data.coordinate_system),
            xj_bool(data._reversed_depth),
          ]),
          xj_nums([c.position.x, c.position.y, c.position.z]),
          xj_nums([q.x, q.y, q.z, q.w]),
        ]),
      )
    }
    let map = match shadow.map {
      Some(map) =>
        xj_list([
          xj_int(map.width),
          xj_int(map.height),
          match shadow.map_pass {
            Some(pass) => xj_list([xj_int(pass.width), xj_int(pass.height)])
            None => @core.JsValue::null()
          },
        ])
      None => @core.JsValue::null()
    }
    mock_note(gl, label + " map", map)
  }
  let frame = (label : String, view : @core.Object3D) => {
    mock_log_push(gl, "## " + label)
    renderer.render(scene, view)
    note_sun(label)
  }
  frame("first", camera)
  ignore(camera.position.set(-3, 4, 10))
  camera.look_at_xyz(0, 0, -5)
  frame("moved", camera)
  shadow.radius = 5
  ignore(sun.position.set(0, 10, 0.1)) // straight down: the up vector switches to +z
  frame("radius", camera)
  renderer.shadow_map.type_ = @core.VSMShadowMap
  frame("vsm", camera)
  renderer.shadow_map.type_ = @core.PCFShadowMap
  let ortho = @core.OrthographicCamera::new(
    left=-10,
    right=10,
    top=5,
    bottom=-5,
    near=1,
    far=50,
  )
  ignore(ortho.position.set(0, 6, 15))
  ortho.look_at_xyz(0, 0, 0)
  frame("ortho", ortho)
  renderer.dispose()
  let log = emit_log("shadow_sunlight", gl)
  assert_true(log.length() > 1000)
}
