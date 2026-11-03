// Differential harness, MoonBit side. Mirrors upstream.mjs statement by statement.

///|
extern "js" fn js_string(x : Double) -> String = "(x) => String(x)"

///|
extern "js" fn emit_raw(name : String, value : @core.JsValue) -> Unit =
  #|(name, value) => {
  #|  const replacer = ( k, v ) => ( typeof v === 'number' && ( Object.is( v, - 0 ) || ! Number.isFinite( v ) ) ) ? 'num:' + ( Object.is( v, - 0 ) ? '-0' : String( v ) ) : v;
  #|  console.log( JSON.stringify( [ name, value ], replacer ) );
  #|}

///|
extern "js" fn emit_json_raw(name : String, json : @core.JsValue) -> Unit =
  #|(name, json) => {
  #|  const replacer = ( k, v ) => ( typeof v === 'number' && ( Object.is( v, - 0 ) || ! Number.isFinite( v ) ) ) ? 'num:' + ( Object.is( v, - 0 ) ? '-0' : String( v ) ) : v;
  #|  const ids = new Map();
  #|  const text = JSON.stringify( json, ( k, v ) => {
  #|    if ( typeof v === 'string' && /^[0-9a-f-]{36}$/.test( v ) ) {
  #|      if ( ! ids.has( v ) ) ids.set( v, 'id' + ids.size );
  #|      return ids.get( v );
  #|    }
  #|    return replacer( k, v );
  #|  } );
  #|  console.log( JSON.stringify( [ name, text ] ) );
  #|}

///|
fn[T] emit(name : String, value : T) -> Unit {
  emit_raw(name, @core.JsValue::of(value))
}

///|
fn emit_json(name : String, json : Json) -> Unit {
  emit_json_raw(name, @core.JsValue::from_json(json))
}

///|
let seed : Ref[Double] = Ref(12345.0)

///|
fn rnd() -> Double {
  seed.val = seed.val * 16807.0
  seed.val = seed.val - (seed.val / 2147483647.0).floor() * 2147483647.0
  seed.val / 2147483647.0
}

///|
fn range(a : Double, b : Double) -> Double {
  a + rnd() * (b - a)
}

///|
fn vec3(x : Double, y : Double, z : Double) -> @math.Vector3 {
  @math.Vector3::new(x, y, z)
}

///|
fn matrices(name : String, camera : @core.Object3D) -> Unit {
  let data = camera.as_camera()
  emit(name + " projection", data.projection_matrix.elements)
  emit(name + " projectionInverse", data.projection_matrix_inverse.elements)
}

///|
fn transforms(name : String, object : @core.Object3D) -> Unit {
  emit(name + " position", object.position.to_array())
  emit(name + " quaternion", object.quaternion.to_array())
  emit(name + " rotation", [object.rotation.x, object.rotation.y, object.rotation.z])
  emit(name + " matrix", object.matrix.elements)
  emit(name + " matrixWorld", object.matrix_world.elements)
}

///|
fn view(name : String, camera : @core.Object3D) -> Unit {
  transforms(name, camera)
  emit(name + " matrixWorldInverse", camera.as_camera().matrix_world_inverse.elements)
}

///|
fn camera_details(name : String, camera : @core.Object3D) -> Unit {
  let min = @math.Vector2::new(0, 0)
  let max = @math.Vector2::new(0, 0)
  let size = @math.Vector2::new(0, 0)
  emit(name + " film", [
    camera.get_film_width(),
    camera.get_film_height(),
    camera.get_focal_length(),
    camera.get_effective_fov(),
  ])
  camera.get_view_bounds(1.0, min, max)
  emit(name + " bounds1", [min.x, min.y, max.x, max.y])
  camera.get_view_bounds(3.7, min, max)
  emit(name + " bounds2", [min.x, min.y, max.x, max.y])
  ignore(camera.get_view_size(7.5, size))
  emit(name + " size", [size.x, size.y])
}

///|
fn set_random_transform(object : @core.Object3D, scale_mode : Int) -> Unit {
  let x = range(-10, 10)
  let y = range(-10, 10)
  let z = range(-10, 10)
  ignore(object.position.set(x, y, z))
  let x = range(-3, 3)
  let y = range(-3, 3)
  let z = range(-3, 3)
  ignore(object.rotation.set(x, y, z))
  if scale_mode == 1 {
    let s = range(0.5, 3)
    ignore(object.scale.set(s, s, s))
  } else if scale_mode == 2 {
    let x = range(0.5, 3)
    let y = range(0.5, 3)
    let z = range(0.5, 3)
    ignore(object.scale.set(x, y, z))
  } else if scale_mode == 3 {
    let x = -range(0.5, 3)
    let y = range(0.5, 3)
    let z = range(0.5, 3)
    ignore(object.scale.set(x, y, z))
  }
}

///|
fn shadow_state(name : String, shadow : @core.LightShadow) -> Unit {
  emit(name + " matrix", shadow.matrix.elements)
  emit(name + " camera", shadow.camera.matrix_world.elements)
  emit(name + " cameraInverse", shadow.camera.as_camera().matrix_world_inverse.elements)
  emit(name + " cameraProjection", shadow.camera.as_camera().projection_matrix.elements)
  emit(name + " frustum", planes_of(shadow.get_frustum()))
}

///|
fn planes_of(frustum : @math.Frustum) -> Array[Double] {
  let planes = []
  for plane in frustum.planes {
    planes.push(plane.normal.x)
    planes.push(plane.normal.y)
    planes.push(plane.normal.z)
    planes.push(plane.constant)
  }
  planes
}

///|
fn json_of(name : String, object : @core.Object3D) -> Unit {
  emit_json(name, object.to_json())
  emit_json(name + " clone", object.clone().to_json())
}

///|
fn shadow_of(light : @core.Object3D) -> @core.LightShadow {
  guard light.as_light().shadow is Some(shadow) else { abort("no shadow") }
  shadow
}

///|
struct MockRenderer {
  coordinate_system : Int
  rev : Bool
  auto_clear : Bool
  mut xr : Bool
  mut target : @core.RenderTarget?
  mut face : Int
  mut level : Int
  log : Array[Double]
}

///|
impl @core.CubeCameraRenderer for MockRenderer with fn coordinate_system(self) {
  self.coordinate_system
}

///|
impl @core.CubeCameraRenderer for MockRenderer with fn get_render_target(self) {
  self.target
}

///|
impl @core.CubeCameraRenderer for MockRenderer with fn get_active_cube_face(self) {
  self.face
}

///|
impl @core.CubeCameraRenderer for MockRenderer with fn get_active_mipmap_level(self) {
  self.level
}

///|
impl @core.CubeCameraRenderer for MockRenderer with fn xr_enabled(self) {
  self.xr
}

///|
impl @core.CubeCameraRenderer for MockRenderer with fn set_xr_enabled(self, value) {
  self.xr = value
}

///|
impl @core.CubeCameraRenderer for MockRenderer with fn reversed_depth_buffer(self) {
  self.rev
}

///|
impl @core.CubeCameraRenderer for MockRenderer with fn auto_clear(self) {
  self.auto_clear
}

///|
impl @core.CubeCameraRenderer for MockRenderer with fn set_render_target(self, target, face, level) {
  self.log.push((1000 + face * 10 + level).to_double())
  self.target = target
  self.face = face
  self.level = level
}

///|
impl @core.CubeCameraRenderer for MockRenderer with fn clear_depth(self) {
  self.log.push(2000.0)
}

///|
impl @core.CubeCameraRenderer for MockRenderer with fn render(self, _scene, camera) {
  self.log.push(if self.xr { 3001.0 } else { 3000.0 })
  let data = camera.as_camera()
  for i in 0..<16 {
    self.log.push(camera.matrix_world.elements[i])
  }
  for i in 0..<16 {
    self.log.push(data.matrix_world_inverse.elements[i])
  }
  for i in 0..<16 {
    self.log.push(data.projection_matrix.elements[i])
  }
}

///|
fn main {
  let perspectives : Array[(Double, Double, Double, Double)] = [
    (50, 1, 0.1, 2000),
    (75, 16.0 / 9.0, 0.1, 300),
    (35, 0.5, 1, 100),
    (90, 2.5, 0.01, 100000.0),
    (1, 1, 0.001, 10000000.0),
    (-90, 1, 0.1, 2000),
    (179, 0.1, 0.7, 7.3),
  ]
  let orthographics : Array[(Double, Double, Double, Double, Double, Double)] = [
    (-1, 1, 1, -1, 0.1, 2000),
    (-5, 5, 5, -5, 0.5, 500),
    (-2, 3, 4, -1, 1, 10),
    (100, 300, 700, 50, -3, 17),
    (-0.25, 0.75, 0.125, -0.625, 0.1, 0.2),
  ]
  let views : Array[(Double, Double, Double, Double, Double, Double)?] = [
    None,
    Some((1920, 1080, 100, 50, 800, 600)),
    Some((100, 100, 0, 0, 100, 100)),
    Some((4000, 3000, 1000, 1500, 800, 600)),
    Some((300, 700, -20, 33.5, 12.25, 9.75)),
  ]
  let coordinate_systems = [2000, 2001]
  let reversed = [false, true]
  let zooms : Array[Double] = [1, 2, 0.37]

  // projection matrices and view offsets
  for pi, p in perspectives {
    for zoom in zooms {
      for coord in coordinate_systems {
        for rev in reversed {
          for vi, v in views {
            for offset in [0.0, 3.5] {
              let name = "persp \{pi} \{js_string(zoom)} \{coord} \{rev.to_string()} \{vi} \{js_string(offset)}"
              let camera = @core.PerspectiveCamera::new(fov=p.0, aspect=p.1, near=p.2, far=p.3)
              let data = camera.as_perspective_camera()
              data.zoom = zoom
              data.film_offset = offset
              camera.as_camera().coordinate_system = coord
              camera.as_camera()._reversed_depth = rev
              camera.update_projection_matrix()
              matrices(name + " base", camera)
              if v is Some(v) {
                camera.set_view_offset(v.0, v.1, v.2, v.3, v.4, v.5)
                matrices(name + " view", camera)
                emit(name + " aspect", [data.aspect])
              }
              camera_details(name, camera)
              let clone = camera.clone()
              matrices(name + " clone", clone)
              clone.update_projection_matrix()
              matrices(name + " cloneUpdated", clone)
              camera.clear_view_offset()
              matrices(name + " cleared", camera)
              camera.set_focal_length(42.0)
              matrices(name + " focal", camera)
              emit(name + " fov", [data.fov])
            }
          }
        }
      }
    }
  }
  for pi, p in orthographics {
    for zoom in zooms {
      for coord in coordinate_systems {
        for rev in reversed {
          for vi, v in views {
            let name = "ortho \{pi} \{js_string(zoom)} \{coord} \{rev.to_string()} \{vi}"
            let camera = @core.OrthographicCamera::new(
              left=p.0,
              right=p.1,
              top=p.2,
              bottom=p.3,
              near=p.4,
              far=p.5,
            )
            camera.as_orthographic_camera().zoom = zoom
            camera.as_camera().coordinate_system = coord
            camera.as_camera()._reversed_depth = rev
            camera.update_projection_matrix()
            matrices(name + " base", camera)
            if v is Some(v) {
              camera.set_view_offset(v.0, v.1, v.2, v.3, v.4, v.5)
              matrices(name + " view", camera)
            }
            let clone = camera.clone()
            matrices(name + " clone", clone)
            clone.update_projection_matrix()
            matrices(name + " cloneUpdated", clone)
            camera.clear_view_offset()
            matrices(name + " cleared", camera)
          }
        }
      }
    }
  }

  // lookAt and the scale-stripping hooks
  let makers : Array[(String, () -> @core.Object3D)] = [
    ("Camera", () => @core.Camera::new()),
    ("Perspective", () => @core.PerspectiveCamera::new()),
    ("Orthographic", () => @core.OrthographicCamera::new()),
    ("Array", () => @core.ArrayCamera::new()),
    ("Directional", () => @core.DirectionalLight::new()),
    ("Spot", () => @core.SpotLight::new()),
    ("Point", () => @core.PointLight::new()),
    ("Hemisphere", () => @core.HemisphereLight::new()),
  ]
  for i in 0..<400 {
    for maker in makers {
      let (kind, make) = maker
      let name = "look \{i} \{kind}"
      let scale_mode = i % 4
      let object = make()
      let parent = @core.Object3D::new()
      let grand = @core.Object3D::new()
      set_random_transform(grand, scale_mode)
      set_random_transform(parent, if scale_mode == 2 { 0 } else { scale_mode })
      set_random_transform(object, if i % 3 == 0 { 0 } else { scale_mode })
      if i % 5 == 0 {
        let x = range(-1, 1)
        let y = range(-1, 1)
        let z = range(-1, 1)
        ignore(object.up.set(x, y, z).normalize())
      }
      if i % 7 != 0 {
        ignore(grand.add(parent))
        ignore(parent.add(object))
      }
      let x = range(-10, 10)
      let y = range(-10, 10)
      let z = range(-10, 10)
      let target = vec3(x, y, z)
      if i % 2 == 0 {
        object.look_at(target)
      } else {
        object.look_at_xyz(target.x, target.y, target.z)
      }
      emit(name + " looked", object.quaternion.to_array())
      if i % 3 == 1 {
        object.update_world_matrix(true, true)
      } else {
        grand.update_matrix_world(force=true)
        object.update_matrix_world()
      }
      let dir = vec3(0, 0, 0)
      emit(name + " direction", object.get_world_direction(dir).to_array())
      if object.is_camera() {
        view(name, object)
      } else {
        transforms(name, object)
      }
    }
  }

  // shadow updateMatrices
  for i in 0..<300 {
    let coord = coordinate_systems[i % 2]
    let rev = i % 3 == 0
    let scale_mode = i % 4
    {
      let name = "dirShadow \{i}"
      let light = @core.DirectionalLight::new()
      set_random_transform(light, scale_mode)
      set_random_transform(light.light_target(), 0)
      let shadow = shadow_of(light)
      shadow.camera.as_camera().coordinate_system = coord
      shadow.camera.as_camera()._reversed_depth = rev
      shadow.camera.as_orthographic_camera().left = range(-20, -1)
      shadow.camera.as_orthographic_camera().right = range(1, 20)
      shadow.camera.update_projection_matrix()
      light.update_matrix_world()
      light.light_target().update_matrix_world()
      shadow.update_matrices(light)
      shadow_state(name, shadow)
    }
    {
      let name = "spotShadow \{i}"
      let distance = if i % 5 == 0 { 0.0 } else { range(1, 900) }
      let angle = range(0.1, 1.5)
      let light = @core.SpotLight::new(distance~, angle~, penumbra=0.2, decay=2.0)
      set_random_transform(light, scale_mode)
      set_random_transform(light.light_target(), 0)
      let shadow = shadow_of(light)
      shadow.camera.as_camera().coordinate_system = coord
      shadow.camera.as_camera()._reversed_depth = rev
      guard shadow.kind is SpotLightShadow(spot) else { abort("no spot shadow") }
      spot.focus = range(0.2, 1)
      spot.aspect = range(0.5, 2)
      ignore(shadow.map_size.set((256 + i).to_double(), (1024 - i).to_double()))
      light.update_matrix_world()
      light.light_target().update_matrix_world()
      shadow.update_matrices(light)
      shadow_state(name, shadow)
      let camera = shadow.camera.as_perspective_camera()
      emit(name + " cameraFields", [camera.fov, camera.aspect, camera.far])
      shadow.update_matrices(light)
      shadow_state(name + " again", shadow)
    }
    {
      let name = "viewportShadow \{i}"
      let camera = @core.OrthographicCamera::new(
        left=-3.0,
        right=3.0,
        top=2.0,
        bottom=-2.0,
        near=1.0,
        far=50.0,
      )
      camera.as_camera().coordinate_system = coord
      camera.as_camera()._reversed_depth = rev
      camera.update_projection_matrix()
      set_random_transform(camera, 0)
      camera.update_matrix_world()
      let shadow = @core.LightShadow::new(camera)
      let x = range(1, 8)
      let y = range(1, 8)
      ignore(shadow._frame_extents.set(x, y))
      let matrix = @math.Matrix4::new()
      let frustum = @math.Frustum::new()
      let x = range(0, 4)
      let y = range(0, 4)
      let z = range(1, 3)
      let w = range(1, 3)
      let viewport = @math.Vector4::new(x, y, z, w)
      shadow._update_matrix(camera, matrix, frustum, viewport~)
      emit(name + " matrix", matrix.elements)
      emit(name + " frustum", planes_of(frustum))
      emit(name + " viewport", shadow.get_viewport(0).to_array())
    }
  }

  // toJSON
  {
    let camera = @core.PerspectiveCamera::new(fov=60.0, aspect=1.5, near=0.2, far=90.0)
    json_of("json perspective", camera)
    camera.set_view_offset(10, 5, 1, 2, 3, 4)
    camera.name = "cam"
    ignore(camera.position.set(1, 2, 3))
    camera.update_matrix()
    camera.user_data = @core.JsValue::from_json({ "a": 1, "b": [1, 2] })
    ignore(camera.add(@core.Object3D::new()))
    camera.layers.set(3)
    camera.render_order = 2.5
    json_of("json perspective view", camera)
    camera.clear_view_offset()
    json_of("json perspective cleared", camera)
    let ortho = @core.OrthographicCamera::new(
      left=-2.0,
      right=3.0,
      top=4.0,
      bottom=-5.0,
      near=0.5,
      far=60.0,
    )
    json_of("json ortho", ortho)
    ortho.set_view_offset(10, 5, 1, 2, 3, 4)
    json_of("json ortho view", ortho)
    json_of("json camera", @core.Camera::new())
    json_of("json array", @core.ArrayCamera::new(array=[@core.PerspectiveCamera::new()]))
    json_of(
      "json cube",
      @core.CubeCamera::new(
        near=1.0,
        far=10.0,
        render_target=@core.RenderTarget::new(width=4, height=4),
      ),
    )
  }
  {
    let color = @math.Color::from_hex(0x123456)
    let ground = @math.Color::from_hex(0xabc012)
    json_of("json light", @core.Light::new(color~, intensity=0.5))
    json_of("json ambient", @core.AmbientLight::new(color~, intensity=0.25))
    json_of("json ambient default", @core.AmbientLight::new())
    let directional = @core.DirectionalLight::new(color~, intensity=2.0)
    let shadow = shadow_of(directional)
    shadow.bias = 0.25
    shadow.normal_bias = 0.75
    shadow.radius = 3.0
    shadow.blur_samples = 12
    shadow.intensity = 0.5
    ignore(shadow.map_size.set(1024, 2048))
    shadow.camera.as_orthographic_camera().left = -7.0
    json_of("json directional", directional)
    json_of(
      "json hemisphere",
      @core.HemisphereLight::new(sky_color=color, ground_color=ground, intensity=0.6),
    )
    let probe = @core.LightProbe::new(intensity=0.5)
    guard probe.as_light().kind is LightProbe(probe_data) else { abort("probe") }
    ignore(probe_data.sh.coefficients[2].set(1, 2, 3))
    json_of("json probe", probe)
    json_of("json point", @core.PointLight::new(color~, intensity=3.0, distance=10.0, decay=1.5))
    json_of("json rect", @core.RectAreaLight::new(color~, intensity=3.0, width=4.0, height=5.0))
    let spot = @core.SpotLight::new(
      color~,
      intensity=3.0,
      distance=10.0,
      angle=0.5,
      penumbra=0.25,
      decay=1.5,
    )
    guard shadow_of(spot).kind is SpotLightShadow(spot_shadow) else { abort("spot") }
    spot_shadow.focus = 0.5
    spot_shadow.aspect = 2.0
    json_of("json spot", spot)
    json_of("json spot default", @core.SpotLight::new())
    let mapped = @core.SpotLight::new()
    mapped.as_spot_light().map = Some(@core.Texture::new())
    json_of("json spot map", mapped)
    json_of("json ies", @core.IESSpotLight::new(color~, intensity=2.0))
    json_of("json projector", @core.ProjectorLight::new(color~, intensity=2.0))
    emit("power", [
      @core.PointLight::new(color~, intensity=3.0).power(),
      @core.SpotLight::new(color~, intensity=3.0).power(),
      @core.RectAreaLight::new(color~, intensity=3.0, width=4.0, height=5.0).power(),
    ])
    let powers = [
      @core.PointLight::new(),
      @core.SpotLight::new(),
      @core.RectAreaLight::new(color~, intensity=1.0, width=4.0, height=5.0),
    ]
    for light in powers {
      light.set_power(100.0)
    }
    emit("set power", powers.map(light => light.as_light().intensity))
  }
  {
    emit_json(
      "json fog",
      @core.Fog::new(color=@math.Color::from_hex(0xff0000), near=2.0, far=30.0).to_json(),
    )
    emit_json(
      "json fogexp2",
      @core.FogExp2::new(color=@math.Color::from_hex(0x00ff00), density=0.5).to_json(),
    )
    let named = @core.Fog::new()
    named.name = "n"
    emit_json("json fog named", named.to_json())
    emit_json("json fog named clone", named.clone().to_json())
    let scene = @core.Scene::new()
    json_of("json scene", scene)
    let data = scene.as_scene()
    data.background = Some(@core.SceneBackground::Color(@math.Color::from_hex(0x336699)))
    data.fog = Some(
      @core.SceneFog::Fog(
        @core.Fog::new(color=@math.Color::from_hex(0xff0000), near=2.0, far=30.0),
      ),
    )
    data.background_blurriness = 0.25
    data.background_intensity = 2.0
    ignore(data.background_rotation.set(1, 2, 3, order="ZYX"))
    data.environment_intensity = 3.0
    ignore(data.environment_rotation.set(0.5, 0.25, 0.125, order="YXZ"))
    ignore(scene.add(@core.DirectionalLight::new()))
    ignore(scene.add(@core.PerspectiveCamera::new()))
    json_of("json scene full", scene)
    data.fog = Some(
      @core.SceneFog::FogExp2(
        @core.FogExp2::new(color=@math.Color::from_hex(0xff0000), density=0.125),
      ),
    )
    let background = @core.Texture::new()
    let material = @core.MeshBasicMaterial::new()
    data.background = Some(@core.SceneBackground::Texture(background))
    data.environment = Some(@core.Texture::new())
    data.override_material = Some(material)
    let mapped_scene = @core.Scene::new()
    let mapped_spot = @core.SpotLight::new()
    mapped_spot.as_spot_light().map = Some(@core.Texture::new())
    ignore(mapped_scene.add(mapped_spot))
    mapped_scene.as_scene().background = Some(
      @core.SceneBackground::Texture(@core.Texture::new()),
    )
    emit_json("json scene spot map", mapped_scene.to_json())
    let copy = @core.Scene::new().copy(scene)
    guard copy.as_scene() is
      {
        background: Some(Texture(copy_background)),
        override_material: Some(copy_material),
        fog: Some(FogExp2(copy_fog)),
        ..
      } else {
      abort("scene copy")
    }
    emit("scene copy", [
      copy.children.length().to_double(),
      if copy_background.uuid == background.uuid { 1.0 } else { 0.0 },
      if copy_material.uuid == material.uuid { 1.0 } else { 0.0 },
      copy_fog.density,
    ])
  }

  // stereo
  for i in 0..<100 {
    let stereo = @core.StereoCamera::new()
    let fov = range(10, 120)
    let aspect = range(0.5, 3)
    let near = range(0.01, 2)
    let far = range(10, 1000)
    let camera = @core.PerspectiveCamera::new(fov~, aspect~, near~, far~)
    let data = camera.as_perspective_camera()
    data.focus = range(1, 20)
    data.zoom = range(0.5, 2)
    stereo.aspect = if i % 2 == 0 { 1.0 } else { 0.5 }
    stereo.eye_sep = range(0.01, 0.2)
    set_random_transform(camera, i % 4)
    camera.update_projection_matrix()
    camera.update_matrix_world()
    for pass in 0..<2 {
      stereo.update(camera)
      emit("stereo \{i} \{pass} l", stereo.camera_l.as_camera().projection_matrix.elements)
      emit("stereo \{i} \{pass} r", stereo.camera_r.as_camera().projection_matrix.elements)
      emit("stereo \{i} \{pass} lm", stereo.camera_l.matrix.elements)
      emit("stereo \{i} \{pass} rm", stereo.camera_r.matrix.elements)
      data.focus = data.focus + pass.to_double()
    }
  }

  // cube camera
  for coord in coordinate_systems {
    for rev in reversed {
      for auto_clear in reversed {
        for i in 0..<4 {
          let name = "cube \{coord} \{rev.to_string()} \{auto_clear.to_string()} \{i}"
          let target = @core.RenderTarget::new(width=8, height=8)
          let cube = @core.CubeCamera::new(near=0.5, far=40.0, render_target=target)
          cube.as_cube_camera().active_mipmap_level = i
          set_random_transform(cube, i)
          let parent = @core.Object3D::new()
          if i > 1 {
            set_random_transform(parent, 0)
            ignore(parent.add(cube))
            parent.update_matrix_world()
          }
          let renderer : MockRenderer = {
            coordinate_system: coord,
            rev,
            auto_clear,
            xr: true,
            target: None,
            face: 3,
            level: 2,
            log: [],
          }
          let scene = @core.Scene::new()
          cube.update_cube_camera(renderer, scene)
          emit(name + " log", renderer.log)
          emit(name + " restored", [
            renderer.face.to_double(),
            renderer.level.to_double(),
            if renderer.xr { 1.0 } else { 0.0 },
            if renderer.target is None { 1.0 } else { 0.0 },
          ])
          let texture = target.textures[0]
          emit(name + " texture", [
            texture.pmrem_version.to_double(),
            if texture.mipmaps_auto_update { 1.0 } else { 0.0 },
          ])
          for c, camera in cube.children {
            emit(name + " up \{c}", camera.up.to_array())
            view(name + " face \{c}", camera)
          }
          renderer.log.clear()
          cube.update_cube_camera(renderer, scene)
          emit(name + " log2", renderer.log)
        }
      }
    }
  }
  for coord in coordinate_systems {
    let cube = @core.CubeCamera::new(near=1.0, far=10.0)
    let clone = cube.clone()
    emit("cube clone \{coord}", [
      clone.children.length().to_double(),
      clone.children[0].as_perspective_camera().far,
      clone.children[6].as_perspective_camera().far,
    ])
    clone.as_cube_camera().coordinate_system = Some(coord)
    clone.update_coordinate_system()
    let quaternions : Array[Double] = []
    for child in clone.children {
      quaternions.append(child.quaternion.to_array())
    }
    emit("cube clone updated \{coord}", quaternions)
  }

  // copy keeps recursive as upstream does
  {
    let results : Array[Double] = []
    let makers : Array[() -> @core.Object3D] = [
      () => @core.Light::new(),
      () => @core.AmbientLight::new(),
      () => @core.DirectionalLight::new(),
      () => @core.HemisphereLight::new(),
      () => @core.LightProbe::new(),
      () => @core.PointLight::new(),
      () => @core.RectAreaLight::new(),
      () => @core.SpotLight::new(),
      () => @core.IESSpotLight::new(),
      () => @core.ProjectorLight::new(),
      () => @core.Camera::new(),
      () => @core.PerspectiveCamera::new(),
      () => @core.OrthographicCamera::new(),
      () => @core.Scene::new(),
    ]
    for make in makers {
      let source = make()
      ignore(source.add(@core.Object3D::new()))
      results.push(make().copy(source, recursive=false).children.length().to_double())
      results.push(make().copy(source, recursive=true).children.length().to_double())
      results.push(make().copy(source).children.length().to_double())
      results.push(source.clone().children.length().to_double())
    }
    emit("recursive", results)
  }
}
