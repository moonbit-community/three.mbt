// Upstream src/renderers/webgl/WebGLLights.js. GROUP 3.
//
// `state` arrays are assigned straight to material uniforms by `WebGLRenderer.getProgram`
// (`uniforms.directionalLights.value = lights.state.directional`), and upstream mutates
// them in place afterwards (`state.directional[ i ] = uniforms`, `length = n`). To keep
// that sharing, every array that becomes a uniform value is an `Array[UniformValue]`
// (struct entries are `UniformValue::Struct`, shadow maps `Texture`, matrices `Matrix4`),
// and the renderer wraps it as `UniformValue::Array(state.directional)` without copying.
// `ambient` is uploaded as `UniformValue::Numbers(state.ambient)`.

///|
/// `state.hash`.
pub(all) struct WebGLLightsHash {
  mut sun_length : Int32
  mut directional_length : Int32
  mut point_length : Int32
  mut spot_length : Int32
  mut rect_area_length : Int32
  mut hemi_length : Int32
  mut num_sun_shadows : Int32
  mut num_directional_shadows : Int32
  mut num_point_shadows : Int32
  mut num_spot_shadows : Int32
  mut num_spot_maps : Int32
  mut num_light_probes : Int32
}

///|
/// `lights.state`.
pub(all) struct WebGLLightsState {
  mut version : Int32
  hash : WebGLLightsHash
  /// `[ r, g, b ]`
  ambient : Array[Double]
  /// 9 `Vector3` spherical-harmonics coefficients
  probe : Array[@core.UniformValue]
  sun : Array[@core.UniformValue]
  sun_shadow : Array[@core.UniformValue]
  sun_shadow_map : Array[@core.UniformValue]
  sun_shadow_matrix : Array[@core.UniformValue]
  sun_shadow_cascade : Array[@core.UniformValue]
  directional : Array[@core.UniformValue]
  directional_shadow : Array[@core.UniformValue]
  directional_shadow_map : Array[@core.UniformValue]
  directional_shadow_matrix : Array[@core.UniformValue]
  spot : Array[@core.UniformValue]
  spot_light_map : Array[@core.UniformValue]
  spot_shadow : Array[@core.UniformValue]
  spot_shadow_map : Array[@core.UniformValue]
  spot_light_matrix : Array[@core.UniformValue]
  rect_area : Array[@core.UniformValue]
  mut rect_area_ltc1 : @core.Texture?
  mut rect_area_ltc2 : @core.Texture?
  point : Array[@core.UniformValue]
  point_shadow : Array[@core.UniformValue]
  point_shadow_map : Array[@core.UniformValue]
  point_shadow_matrix : Array[@core.UniformValue]
  hemi : Array[@core.UniformValue]
  mut num_spot_light_shadows_with_maps : Int32
  mut num_light_probes : Int32
}

///|
/// `new WebGLLights( extensions )`.
pub(all) struct WebGLLights {
  extensions : WebGLExtensions
  /// `UniformsCache`: light id -> uniform struct
  cache : Map[Int32, Map[String, @core.UniformValue]]
  /// `ShadowUniformsCache`: light id -> shadow uniform struct
  shadow_cache : Map[Int32, Map[String, @core.UniformValue]]
  state : WebGLLightsState
  vector3 : @math.Vector3
  matrix4 : @math.Matrix4
  matrix42 : @math.Matrix4
}

///|
/// Module-level `nextVersion`.
let webgl_lights_next_version : Ref[Int32] = { val: 0, }

///|
/// `UniformsCache.get( light )`: the uniform struct of `light`, by `light.type`.
fn webgl_lights_cache_get(
  cache : Map[Int32, Map[String, @core.UniformValue]],
  light : @core.Object3D,
) -> Map[String, @core.UniformValue] {
  match cache.get(light.id) {
    Some(uniforms) => return uniforms
    None => ()
  }
  let uniforms : Map[String, @core.UniformValue] = match light.type_ {
    "SunLight" | "DirectionalLight" =>
      Map([
        ("direction", Vector3(@math.Vector3::new(0, 0, 0))),
        ("color", Color(@math.Color::new(0, 0, 0))),
      ])
    "SpotLight" =>
      Map([
        ("position", Vector3(@math.Vector3::new(0, 0, 0))),
        ("direction", Vector3(@math.Vector3::new(0, 0, 0))),
        ("color", Color(@math.Color::new(0, 0, 0))),
        ("distance", Number(0)),
        ("coneCos", Number(0)),
        ("penumbraCos", Number(0)),
        ("decay", Number(0)),
      ])
    "PointLight" =>
      Map([
        ("position", Vector3(@math.Vector3::new(0, 0, 0))),
        ("color", Color(@math.Color::new(0, 0, 0))),
        ("distance", Number(0)),
        ("decay", Number(0)),
      ])
    "HemisphereLight" =>
      Map([
        ("direction", Vector3(@math.Vector3::new(0, 0, 0))),
        ("skyColor", Color(@math.Color::new(0, 0, 0))),
        ("groundColor", Color(@math.Color::new(0, 0, 0))),
      ])
    "RectAreaLight" =>
      Map([
        ("color", Color(@math.Color::new(0, 0, 0))),
        ("position", Vector3(@math.Vector3::new(0, 0, 0))),
        ("halfWidth", Vector3(@math.Vector3::new(0, 0, 0))),
        ("halfHeight", Vector3(@math.Vector3::new(0, 0, 0))),
      ])
    // upstream stores `undefined` and throws on its first use
    type_ => abort("WebGLLights: no uniforms for light type " + type_)
  }
  cache.set(light.id, uniforms)
  uniforms
}

///|
/// `ShadowUniformsCache.get( light )`.
fn webgl_lights_shadow_cache_get(
  cache : Map[Int32, Map[String, @core.UniformValue]],
  light : @core.Object3D,
) -> Map[String, @core.UniformValue] {
  match cache.get(light.id) {
    Some(uniforms) => return uniforms
    None => ()
  }
  let uniforms : Map[String, @core.UniformValue] = match light.type_ {
    "SunLight" | "DirectionalLight" | "SpotLight" =>
      Map([
        ("shadowIntensity", Number(1)),
        ("shadowBias", Number(0)),
        ("shadowNormalBias", Number(0)),
        ("shadowRadius", Number(1)),
        ("shadowMapSize", Vector2(@math.Vector2::new(0, 0))),
      ])
    "PointLight" =>
      Map([
        ("shadowIntensity", Number(1)),
        ("shadowBias", Number(0)),
        ("shadowNormalBias", Number(0)),
        ("shadowRadius", Number(1)),
        ("shadowMapSize", Vector2(@math.Vector2::new(0, 0))),
        ("shadowCameraNear", Number(1)),
        ("shadowCameraFar", Number(1000)),
      ])
    type_ => abort("WebGLLights: no shadow uniforms for light type " + type_)
  }
  cache.set(light.id, uniforms)
  uniforms
}

///|
fn webgl_lights_vector3(
  uniforms : Map[String, @core.UniformValue],
  key : String,
) -> @math.Vector3 {
  guard uniforms.get(key) is Some(Vector3(v)) else {
    abort("WebGLLights: missing uniform " + key)
  }
  v
}

///|
fn webgl_lights_color(
  uniforms : Map[String, @core.UniformValue],
  key : String,
) -> @math.Color {
  guard uniforms.get(key) is Some(Color(c)) else {
    abort("WebGLLights: missing uniform " + key)
  }
  c
}

///|
fn webgl_lights_vector2(
  uniforms : Map[String, @core.UniformValue],
  key : String,
) -> @math.Vector2 {
  guard uniforms.get(key) is Some(Vector2(v)) else {
    abort("WebGLLights: missing uniform " + key)
  }
  v
}

///|
/// The struct stored at `array[ index ]`.
fn webgl_lights_struct_at(
  array : Array[@core.UniformValue],
  index : Int32,
) -> Map[String, @core.UniformValue] {
  guard index < array.length() && array[index] is Struct(uniforms) else {
    abort("WebGLLights: no light uniforms at " + index.to_string())
  }
  uniforms
}

///|
/// `array[ index ] = value`; indices past the end leave JS holes (`undefined`), here `Null`.
fn webgl_lights_assign(
  array : Array[@core.UniformValue],
  index : Int32,
  value : @core.UniformValue,
) -> Unit {
  if index < array.length() {
    array[index] = value
  } else {
    while array.length() < index {
      array.push(Null)
    }
    array.push(value)
  }
}

///|
/// `array.length = n`.
fn webgl_lights_set_length(
  array : Array[@core.UniformValue],
  n : Int32,
) -> Unit {
  truncate_array(array, n)
  while array.length() < n {
    array.push(Null)
  }
}

///|
/// `shadowCastingAndTexturingLightsFirst( lightA, lightB )`.
fn webgl_lights_shadow_casting_and_texturing_lights_first(
  light_a : @core.Object3D,
  light_b : @core.Object3D,
) -> Double {
  fn has_map(light : @core.Object3D) -> Bool {
    match light.kind {
      Light({ kind: SpotLight(spot), .. }) => spot.map is Some(_)
      _ => false
    }
  }

  let cast_b = if light_b.cast_shadow { 2 } else { 0 }
  let cast_a = if light_a.cast_shadow { 2 } else { 0 }
  let map_b = if has_map(light_b) { 1 } else { 0 }
  let map_a = if has_map(light_a) { 1 } else { 0 }
  (cast_b - cast_a + map_b - map_a).to_double()
}

///|
/// `new WebGLLights( extensions )`.
pub fn WebGLLights::new(extensions : WebGLExtensions) -> WebGLLights {
  let state : WebGLLightsState = {
    version: 0,
    hash: {
      sun_length: -1,
      directional_length: -1,
      point_length: -1,
      spot_length: -1,
      rect_area_length: -1,
      hemi_length: -1,
      num_sun_shadows: -1,
      num_directional_shadows: -1,
      num_point_shadows: -1,
      num_spot_shadows: -1,
      num_spot_maps: -1,
      num_light_probes: -1,
    },
    ambient: [0, 0, 0],
    probe: [],
    sun: [],
    sun_shadow: [],
    sun_shadow_map: [],
    sun_shadow_matrix: [],
    sun_shadow_cascade: [],
    directional: [],
    directional_shadow: [],
    directional_shadow_map: [],
    directional_shadow_matrix: [],
    spot: [],
    spot_light_map: [],
    spot_shadow: [],
    spot_shadow_map: [],
    spot_light_matrix: [],
    rect_area: [],
    rect_area_ltc1: None,
    rect_area_ltc2: None,
    point: [],
    point_shadow: [],
    point_shadow_map: [],
    point_shadow_matrix: [],
    hemi: [],
    num_spot_light_shadows_with_maps: 0,
    num_light_probes: 0,
  }
  for _ in 0..<9 {
    state.probe.push(Vector3(@math.Vector3::new(0, 0, 0)))
  }
  {
    extensions,
    cache: Map([]),
    shadow_cache: Map([]),
    state,
    vector3: @math.Vector3::new(0, 0, 0),
    matrix4: @math.Matrix4::new(),
    matrix42: @math.Matrix4::new(),
  }
}

///|
/// `light.shadow.map` as the texture the shader samples.
fn webgl_lights_shadow_map(light : @core.Light) -> @core.UniformValue {
  match light.shadow {
    Some({ map: Some(map), .. }) =>
      if map.texture().format == @core.RGFormat {
        // VSM uses color texture with blurred mean/std_dev
        Texture(map.texture())
      } else {
        // Other types use depth texture
        match map.depth_texture() {
          Some(depth_texture) => Texture(depth_texture)
          None => Texture(map.texture())
        }
      }
    _ => Null
  }
}

///|
/// `lights.setup( lights )`; sorts `lights` in place as upstream does.
pub fn WebGLLights::setup(
  self : WebGLLights,
  lights : Array[@core.Object3D],
) -> Unit {
  let state = self.state
  let cache = self.cache
  let shadow_cache = self.shadow_cache
  let mut r = 0.0
  let mut g = 0.0
  let mut b = 0.0
  for i in 0..<9 {
    guard state.probe[i] is Vector3(probe) else { abort("WebGLLights: probe") }
    ignore(probe.set(0, 0, 0))
  }
  let mut sun_length = 0
  let mut num_sun_shadows = 0
  let mut num_sun_shadow_cascades = 0
  let mut directional_length = 0
  let mut point_length = 0
  let mut spot_length = 0
  let mut rect_area_length = 0
  let mut hemi_length = 0
  let mut num_directional_shadows = 0
  let mut num_point_shadows = 0
  let mut num_spot_shadows = 0
  let mut num_spot_maps = 0
  let mut num_spot_shadows_with_maps = 0
  let mut num_light_probes = 0

  // ordering : [shadow casting + map texturing, map texturing, shadow casting, none ]
  stable_sort_by(lights, webgl_lights_shadow_casting_and_texturing_lights_first)
  for object in lights {
    guard object.kind is Light(light) else { continue }
    let color = light.color
    let intensity = light.intensity
    let shadow_map = webgl_lights_shadow_map(light)
    match light.kind {
      AmbientLight => {
        r += color.r * intensity
        g += color.g * intensity
        b += color.b * intensity
      }
      LightProbe(probe) => {
        for j in 0..<9 {
          guard state.probe[j] is Vector3(v) else {
            abort("WebGLLights: probe")
          }
          ignore(v.add_scaled_vector(probe.sh.coefficients[j], intensity))
        }
        num_light_probes += 1
      }
      _ if is_sun_light(object) => {
        let uniforms = webgl_lights_cache_get(cache, object)
        ignore(
          webgl_lights_color(uniforms, "color")
          .copy(light.color)
          .multiply_scalar(light.intensity),
        )
        if object.cast_shadow {
          guard light.shadow is Some(shadow) else {
            abort("WebGLLights: SunLight without shadow")
          }
          guard sun_light_shadow_of(object) is Some(sun_shadow) else {
            abort("WebGLLights: SunLight not registered")
          }
          let shadow_uniforms = webgl_lights_shadow_cache_get(
            shadow_cache, object,
          )
          shadow_uniforms.set("shadowIntensity", Number(shadow.intensity))
          shadow_uniforms.set("shadowBias", Number(shadow.bias))
          shadow_uniforms.set("shadowNormalBias", Number(shadow.normal_bias))
          shadow_uniforms.set("shadowRadius", Number(shadow.radius))
          ignore(
            webgl_lights_vector2(shadow_uniforms, "shadowMapSize")
            .copy(shadow.map_size)
            .multiply(shadow.get_frame_extents()),
          )
          webgl_lights_assign(
            state.sun_shadow,
            num_sun_shadows,
            Struct(shadow_uniforms),
          )
          webgl_lights_assign(state.sun_shadow_map, num_sun_shadows, shadow_map)
          let cascade_count = shadow.get_viewport_count()
          for j in 0..<cascade_count {
            webgl_lights_assign(
              state.sun_shadow_matrix,
              num_sun_shadow_cascades + j,
              Matrix4(sun_shadow.get_matrix(j)),
            )
            webgl_lights_assign(
              state.sun_shadow_cascade,
              num_sun_shadow_cascades + j,
              sun_shadow.cascade_data(j),
            )
          }
          num_sun_shadow_cascades += cascade_count
          num_sun_shadows += 1
        }
        webgl_lights_assign(state.sun, sun_length, Struct(uniforms))
        sun_length += 1
      }
      DirectionalLight(_) => {
        let uniforms = webgl_lights_cache_get(cache, object)
        ignore(
          webgl_lights_color(uniforms, "color")
          .copy(light.color)
          .multiply_scalar(light.intensity),
        )
        if object.cast_shadow {
          guard light.shadow is Some(shadow) else {
            abort("WebGLLights: light without shadow")
          }
          let shadow_uniforms = webgl_lights_shadow_cache_get(
            shadow_cache, object,
          )
          shadow_uniforms.set("shadowIntensity", Number(shadow.intensity))
          shadow_uniforms.set("shadowBias", Number(shadow.bias))
          shadow_uniforms.set("shadowNormalBias", Number(shadow.normal_bias))
          shadow_uniforms.set("shadowRadius", Number(shadow.radius))
          shadow_uniforms.set("shadowMapSize", Vector2(shadow.map_size))
          webgl_lights_assign(
            state.directional_shadow,
            directional_length,
            Struct(shadow_uniforms),
          )
          webgl_lights_assign(
            state.directional_shadow_map,
            directional_length,
            shadow_map,
          )
          webgl_lights_assign(
            state.directional_shadow_matrix,
            directional_length,
            Matrix4(shadow.matrix),
          )
          num_directional_shadows += 1
        }
        webgl_lights_assign(
          state.directional,
          directional_length,
          Struct(uniforms),
        )
        directional_length += 1
      }
      SpotLight(spot) => {
        let uniforms = webgl_lights_cache_get(cache, object)
        ignore(
          webgl_lights_vector3(uniforms, "position").set_from_matrix_position(
            object.matrix_world,
          ),
        )
        ignore(
          webgl_lights_color(uniforms, "color")
          .copy(color)
          .multiply_scalar(intensity),
        )
        uniforms.set("distance", Number(spot.distance))
        uniforms.set("coneCos", Number(@cmath.cos(spot.angle)))
        uniforms.set(
          "penumbraCos",
          Number(@cmath.cos(spot.angle * (1.0 - spot.penumbra))),
        )
        uniforms.set("decay", Number(spot.decay))
        webgl_lights_assign(state.spot, spot_length, Struct(uniforms))
        guard light.shadow is Some(shadow) else {
          abort("WebGLLights: SpotLight without shadow")
        }
        if spot.map is Some(map) {
          webgl_lights_assign(state.spot_light_map, num_spot_maps, Texture(map))
          num_spot_maps += 1

          // make sure the lightMatrix is up to date
          // TODO : do it if required only
          shadow.update_matrices(object)
          if object.cast_shadow {
            num_spot_shadows_with_maps += 1
          }
        }
        webgl_lights_assign(
          state.spot_light_matrix,
          spot_length,
          Matrix4(shadow.matrix),
        )
        if object.cast_shadow {
          let shadow_uniforms = webgl_lights_shadow_cache_get(
            shadow_cache, object,
          )
          shadow_uniforms.set("shadowIntensity", Number(shadow.intensity))
          shadow_uniforms.set("shadowBias", Number(shadow.bias))
          shadow_uniforms.set("shadowNormalBias", Number(shadow.normal_bias))
          shadow_uniforms.set("shadowRadius", Number(shadow.radius))
          shadow_uniforms.set("shadowMapSize", Vector2(shadow.map_size))
          webgl_lights_assign(
            state.spot_shadow,
            spot_length,
            Struct(shadow_uniforms),
          )
          webgl_lights_assign(state.spot_shadow_map, spot_length, shadow_map)
          num_spot_shadows += 1
        }
        spot_length += 1
      }
      RectAreaLight(rect) => {
        let uniforms = webgl_lights_cache_get(cache, object)
        ignore(
          webgl_lights_color(uniforms, "color")
          .copy(color)
          .multiply_scalar(intensity),
        )
        ignore(
          webgl_lights_vector3(uniforms, "halfWidth").set(
            rect.width * 0.5,
            0.0,
            0.0,
          ),
        )
        ignore(
          webgl_lights_vector3(uniforms, "halfHeight").set(
            0.0,
            rect.height * 0.5,
            0.0,
          ),
        )
        webgl_lights_assign(state.rect_area, rect_area_length, Struct(uniforms))
        rect_area_length += 1
      }
      PointLight(point) => {
        let uniforms = webgl_lights_cache_get(cache, object)
        ignore(
          webgl_lights_color(uniforms, "color")
          .copy(light.color)
          .multiply_scalar(light.intensity),
        )
        uniforms.set("distance", Number(point.distance))
        uniforms.set("decay", Number(point.decay))
        if object.cast_shadow {
          guard light.shadow is Some(shadow) else {
            abort("WebGLLights: light without shadow")
          }
          let shadow_uniforms = webgl_lights_shadow_cache_get(
            shadow_cache, object,
          )
          shadow_uniforms.set("shadowIntensity", Number(shadow.intensity))
          shadow_uniforms.set("shadowBias", Number(shadow.bias))
          shadow_uniforms.set("shadowNormalBias", Number(shadow.normal_bias))
          shadow_uniforms.set("shadowRadius", Number(shadow.radius))
          shadow_uniforms.set("shadowMapSize", Vector2(shadow.map_size))
          let shadow_camera = shadow.camera.as_perspective_camera()
          shadow_uniforms.set("shadowCameraNear", Number(shadow_camera.near))
          shadow_uniforms.set("shadowCameraFar", Number(shadow_camera.far))
          webgl_lights_assign(
            state.point_shadow,
            point_length,
            Struct(shadow_uniforms),
          )
          webgl_lights_assign(state.point_shadow_map, point_length, shadow_map)
          webgl_lights_assign(
            state.point_shadow_matrix,
            point_length,
            Matrix4(shadow.matrix),
          )
          num_point_shadows += 1
        }
        webgl_lights_assign(state.point, point_length, Struct(uniforms))
        point_length += 1
      }
      HemisphereLight(hemi) => {
        let uniforms = webgl_lights_cache_get(cache, object)
        ignore(
          webgl_lights_color(uniforms, "skyColor")
          .copy(light.color)
          .multiply_scalar(intensity),
        )
        ignore(
          webgl_lights_color(uniforms, "groundColor")
          .copy(hemi.ground_color)
          .multiply_scalar(intensity),
        )
        webgl_lights_assign(state.hemi, hemi_length, Struct(uniforms))
        hemi_length += 1
      }
      BaseLight => ()
    }
  }
  if rect_area_length > 0 {
    if self.extensions.has("OES_texture_float_linear") {
      state.rect_area_ltc1 = uniforms_lib_ltc.ltc_float_1
      state.rect_area_ltc2 = uniforms_lib_ltc.ltc_float_2
    } else {
      state.rect_area_ltc1 = uniforms_lib_ltc.ltc_half_1
      state.rect_area_ltc2 = uniforms_lib_ltc.ltc_half_2
    }
  }
  state.ambient[0] = r
  state.ambient[1] = g
  state.ambient[2] = b
  let hash = state.hash
  if hash.sun_length != sun_length ||
    hash.directional_length != directional_length ||
    hash.point_length != point_length ||
    hash.spot_length != spot_length ||
    hash.rect_area_length != rect_area_length ||
    hash.hemi_length != hemi_length ||
    hash.num_sun_shadows != num_sun_shadows ||
    hash.num_directional_shadows != num_directional_shadows ||
    hash.num_point_shadows != num_point_shadows ||
    hash.num_spot_shadows != num_spot_shadows ||
    hash.num_spot_maps != num_spot_maps ||
    hash.num_light_probes != num_light_probes {
    webgl_lights_set_length(state.sun, sun_length)
    webgl_lights_set_length(state.directional, directional_length)
    webgl_lights_set_length(state.spot, spot_length)
    webgl_lights_set_length(state.rect_area, rect_area_length)
    webgl_lights_set_length(state.point, point_length)
    webgl_lights_set_length(state.hemi, hemi_length)
    webgl_lights_set_length(state.sun_shadow, num_sun_shadows)
    webgl_lights_set_length(state.sun_shadow_map, num_sun_shadows)
    webgl_lights_set_length(state.sun_shadow_matrix, num_sun_shadow_cascades)
    webgl_lights_set_length(state.sun_shadow_cascade, num_sun_shadow_cascades)
    webgl_lights_set_length(state.directional_shadow, num_directional_shadows)
    webgl_lights_set_length(
      state.directional_shadow_map,
      num_directional_shadows,
    )
    webgl_lights_set_length(
      state.directional_shadow_matrix,
      num_directional_shadows,
    )
    webgl_lights_set_length(state.point_shadow, num_point_shadows)
    webgl_lights_set_length(state.point_shadow_map, num_point_shadows)
    webgl_lights_set_length(state.point_shadow_matrix, num_point_shadows)
    webgl_lights_set_length(state.spot_shadow, num_spot_shadows)
    webgl_lights_set_length(state.spot_shadow_map, num_spot_shadows)
    webgl_lights_set_length(
      state.spot_light_matrix,
      num_spot_shadows + num_spot_maps - num_spot_shadows_with_maps,
    )
    webgl_lights_set_length(state.spot_light_map, num_spot_maps)
    state.num_spot_light_shadows_with_maps = num_spot_shadows_with_maps
    state.num_light_probes = num_light_probes
    hash.sun_length = sun_length
    hash.directional_length = directional_length
    hash.point_length = point_length
    hash.spot_length = spot_length
    hash.rect_area_length = rect_area_length
    hash.hemi_length = hemi_length
    hash.num_sun_shadows = num_sun_shadows
    hash.num_directional_shadows = num_directional_shadows
    hash.num_point_shadows = num_point_shadows
    hash.num_spot_shadows = num_spot_shadows
    hash.num_spot_maps = num_spot_maps
    hash.num_light_probes = num_light_probes
    state.version = webgl_lights_next_version.val
    webgl_lights_next_version.val += 1
  }
}

///|
/// `lights.setupView( lights, camera )`.
pub fn WebGLLights::setup_view(
  self : WebGLLights,
  lights : Array[@core.Object3D],
  camera : @core.Object3D,
) -> Unit {
  let state = self.state
  let vector3 = self.vector3
  let matrix4 = self.matrix4
  let matrix42 = self.matrix42
  let mut sun_length = 0
  let mut directional_length = 0
  let mut point_length = 0
  let mut spot_length = 0
  let mut rect_area_length = 0
  let mut hemi_length = 0
  let view_matrix = camera.matrix_world_inverse()
  for object in lights {
    guard object.kind is Light(light) else { continue }
    match light.kind {
      _ if is_sun_light(object) => {
        let uniforms = webgl_lights_struct_at(state.sun, sun_length)
        let direction = webgl_lights_vector3(uniforms, "direction")
        ignore(direction.set_from_matrix_position(object.matrix_world))
        ignore(direction.transform_direction(view_matrix))
        sun_length += 1
      }
      DirectionalLight(directional) => {
        let uniforms = webgl_lights_struct_at(
          state.directional,
          directional_length,
        )
        let direction = webgl_lights_vector3(uniforms, "direction")
        ignore(direction.set_from_matrix_position(object.matrix_world))
        ignore(
          vector3.set_from_matrix_position(directional.target.matrix_world),
        )
        ignore(direction.sub(vector3))
        ignore(direction.transform_direction(view_matrix))
        directional_length += 1
      }
      SpotLight(spot) => {
        let uniforms = webgl_lights_struct_at(state.spot, spot_length)
        let position = webgl_lights_vector3(uniforms, "position")
        ignore(position.set_from_matrix_position(object.matrix_world))
        ignore(position.apply_matrix4(view_matrix))
        let direction = webgl_lights_vector3(uniforms, "direction")
        ignore(direction.set_from_matrix_position(object.matrix_world))
        ignore(vector3.set_from_matrix_position(spot.target.matrix_world))
        ignore(direction.sub(vector3))
        ignore(direction.transform_direction(view_matrix))
        spot_length += 1
      }
      RectAreaLight(rect) => {
        let uniforms = webgl_lights_struct_at(state.rect_area, rect_area_length)
        let position = webgl_lights_vector3(uniforms, "position")
        ignore(position.set_from_matrix_position(object.matrix_world))
        ignore(position.apply_matrix4(view_matrix))

        // extract local rotation of light to derive width/height half vectors
        ignore(matrix42.identity())
        ignore(matrix4.copy(object.matrix_world))
        ignore(matrix4.premultiply(view_matrix))
        ignore(matrix42.extract_rotation(matrix4))
        let half_width = webgl_lights_vector3(uniforms, "halfWidth")
        let half_height = webgl_lights_vector3(uniforms, "halfHeight")
        ignore(half_width.set(rect.width * 0.5, 0.0, 0.0))
        ignore(half_height.set(0.0, rect.height * 0.5, 0.0))
        ignore(half_width.apply_matrix4(matrix42))
        ignore(half_height.apply_matrix4(matrix42))
        rect_area_length += 1
      }
      PointLight(_) => {
        let uniforms = webgl_lights_struct_at(state.point, point_length)
        let position = webgl_lights_vector3(uniforms, "position")
        ignore(position.set_from_matrix_position(object.matrix_world))
        ignore(position.apply_matrix4(view_matrix))
        point_length += 1
      }
      HemisphereLight(_) => {
        let uniforms = webgl_lights_struct_at(state.hemi, hemi_length)
        let direction = webgl_lights_vector3(uniforms, "direction")
        ignore(direction.set_from_matrix_position(object.matrix_world))
        ignore(direction.transform_direction(view_matrix))
        hemi_length += 1
      }
      _ => ()
    }
  }
}
