// Upstream src/renderers/shaders/UniformsLib.js.

///|
fn uniform_null() -> @core.Uniform {
  @core.Uniform::new(Null)
}

///|
fn uniform_number(value : Double) -> @core.Uniform {
  @core.Uniform::new(Number(value))
}

///|
fn uniform_color(hex : Int32) -> @core.Uniform {
  @core.Uniform::new(Color(@math.Color::from_hex(hex)))
}

///|
fn uniform_vector2(x : Double, y : Double) -> @core.Uniform {
  @core.Uniform::new(Vector2(@math.Vector2::new(x, y)))
}

///|
fn uniform_matrix3() -> @core.Uniform {
  @core.Uniform::new(Matrix3(@math.Matrix3::new()))
}

///|
fn uniform_array() -> @core.Uniform {
  @core.Uniform::new(Array([]))
}

///|
let uniforms_lib_common : Map[String, @core.Uniform] = Map([
  ("diffuse", uniform_color(0xffffff)),
  ("opacity", uniform_number(1.0)),
  ("map", uniform_null()),
  ("mapTransform", uniform_matrix3()),
  ("alphaMap", uniform_null()),
  ("alphaMapTransform", uniform_matrix3()),
  ("alphaTest", uniform_number(0.0)),
])

///|
let uniforms_lib_specularmap : Map[String, @core.Uniform] = Map([
  ("specularMap", uniform_null()),
  ("specularMapTransform", uniform_matrix3()),
])

///|
let uniforms_lib_envmap : Map[String, @core.Uniform] = Map([
  ("envMap", uniform_null()),
  ("envMapRotation", uniform_matrix3()),
  ("reflectivity", uniform_number(1.0)),
  ("ior", uniform_number(1.5)),
  ("refractionRatio", uniform_number(0.98)),
  ("dfgLUT", uniform_null()),
])

///|
let uniforms_lib_aomap : Map[String, @core.Uniform] = Map([
  ("aoMap", uniform_null()),
  ("aoMapIntensity", uniform_number(1.0)),
  ("aoMapTransform", uniform_matrix3()),
])

///|
let uniforms_lib_lightmap : Map[String, @core.Uniform] = Map([
  ("lightMap", uniform_null()),
  ("lightMapIntensity", uniform_number(1.0)),
  ("lightMapTransform", uniform_matrix3()),
])

///|
let uniforms_lib_bumpmap : Map[String, @core.Uniform] = Map([
  ("bumpMap", uniform_null()),
  ("bumpMapTransform", uniform_matrix3()),
  ("bumpScale", uniform_number(1.0)),
])

///|
let uniforms_lib_normalmap : Map[String, @core.Uniform] = Map([
  ("normalMap", uniform_null()),
  ("normalMapTransform", uniform_matrix3()),
  ("normalScale", uniform_vector2(1.0, 1.0)),
])

///|
let uniforms_lib_displacementmap : Map[String, @core.Uniform] = Map([
  ("displacementMap", uniform_null()),
  ("displacementMapTransform", uniform_matrix3()),
  ("displacementScale", uniform_number(1.0)),
  ("displacementBias", uniform_number(0.0)),
])

///|
let uniforms_lib_emissivemap : Map[String, @core.Uniform] = Map([
  ("emissiveMap", uniform_null()),
  ("emissiveMapTransform", uniform_matrix3()),
])

///|
let uniforms_lib_metalnessmap : Map[String, @core.Uniform] = Map([
  ("metalnessMap", uniform_null()),
  ("metalnessMapTransform", uniform_matrix3()),
])

///|
let uniforms_lib_roughnessmap : Map[String, @core.Uniform] = Map([
  ("roughnessMap", uniform_null()),
  ("roughnessMapTransform", uniform_matrix3()),
])

///|
let uniforms_lib_gradientmap : Map[String, @core.Uniform] = Map([
  ("gradientMap", uniform_null()),
])

///|
let uniforms_lib_fog : Map[String, @core.Uniform] = Map([
  ("fogDensity", uniform_number(0.00025)),
  ("fogNear", uniform_number(1.0)),
  ("fogFar", uniform_number(2000.0)),
  ("fogColor", uniform_color(0xffffff)),
])

///|
let uniforms_lib_lights : Map[String, @core.Uniform] = Map([
  ("ambientLightColor", uniform_array()),
  ("lightProbe", uniform_array()),
  ("sunLights", uniform_array()),
  ("sunLightShadows", uniform_array()),
  ("sunShadowMatrix", uniform_array()),
  ("sunShadowCascade", uniform_array()),
  ("directionalLights", uniform_array()),
  ("directionalLightShadows", uniform_array()),
  ("directionalShadowMatrix", uniform_array()),
  ("spotLights", uniform_array()),
  ("spotLightShadows", uniform_array()),
  ("spotLightMap", uniform_array()),
  ("spotLightMatrix", uniform_array()),
  ("pointLights", uniform_array()),
  ("pointLightShadows", uniform_array()),
  ("pointShadowMatrix", uniform_array()),
  ("hemisphereLights", uniform_array()),
  ("rectAreaLights", uniform_array()),
  ("ltc_1", uniform_null()),
  ("ltc_2", uniform_null()),
  ("probesSH", uniform_array()),
  ("probesMin", uniform_array()),
  ("probesMax", uniform_array()),
  ("probesResolution", uniform_array()),
])

///|
let uniforms_lib_points : Map[String, @core.Uniform] = Map([
  ("diffuse", uniform_color(0xffffff)),
  ("opacity", uniform_number(1.0)),
  ("size", uniform_number(1.0)),
  ("scale", uniform_number(1.0)),
  ("map", uniform_null()),
  ("alphaMap", uniform_null()),
  ("alphaMapTransform", uniform_matrix3()),
  ("alphaTest", uniform_number(0.0)),
  ("uvTransform", uniform_matrix3()),
])

///|
let uniforms_lib_sprite : Map[String, @core.Uniform] = Map([
  ("diffuse", uniform_color(0xffffff)),
  ("opacity", uniform_number(1.0)),
  ("center", uniform_vector2(0.5, 0.5)),
  ("rotation", uniform_number(0.0)),
  ("map", uniform_null()),
  ("mapTransform", uniform_matrix3()),
  ("alphaMap", uniform_null()),
  ("alphaMapTransform", uniform_matrix3()),
  ("alphaTest", uniform_number(0.0)),
])

///|
/// Upstream `UniformsLib`, in upstream key order.
pub let uniforms_lib : Map[String, Map[String, @core.Uniform]] = Map([
  ("common", uniforms_lib_common),
  ("specularmap", uniforms_lib_specularmap),
  ("envmap", uniforms_lib_envmap),
  ("aomap", uniforms_lib_aomap),
  ("lightmap", uniforms_lib_lightmap),
  ("bumpmap", uniforms_lib_bumpmap),
  ("normalmap", uniforms_lib_normalmap),
  ("displacementmap", uniforms_lib_displacementmap),
  ("emissivemap", uniforms_lib_emissivemap),
  ("metalnessmap", uniforms_lib_metalnessmap),
  ("roughnessmap", uniforms_lib_roughnessmap),
  ("gradientmap", uniforms_lib_gradientmap),
  ("fog", uniforms_lib_fog),
  ("lights", uniforms_lib_lights),
  ("points", uniforms_lib_points),
  ("sprite", uniforms_lib_sprite),
])

///|
/// The `properties` of the `lights` uniforms, keyed by uniform name, in upstream
/// order. `@core.Uniform` has only `value`, so this sits beside it. `ShaderLib`
/// shares it too: upstream's `cloneUniforms` copies `properties` by reference.
pub let uniforms_lib_properties : Map[String, Json] = Map([
  ("sunLights", { "direction": {}, "color": {} }),
  (
    "sunLightShadows",
    {
      "shadowIntensity": 1,
      "shadowBias": {},
      "shadowNormalBias": {},
      "shadowRadius": {},
      "shadowMapSize": {},
    },
  ),
  ("directionalLights", { "direction": {}, "color": {} }),
  (
    "directionalLightShadows",
    {
      "shadowIntensity": 1,
      "shadowBias": {},
      "shadowNormalBias": {},
      "shadowRadius": {},
      "shadowMapSize": {},
    },
  ),
  (
    "spotLights",
    {
      "color": {},
      "position": {},
      "direction": {},
      "distance": {},
      "coneCos": {},
      "penumbraCos": {},
      "decay": {},
    },
  ),
  (
    "spotLightShadows",
    {
      "shadowIntensity": 1,
      "shadowBias": {},
      "shadowNormalBias": {},
      "shadowRadius": {},
      "shadowMapSize": {},
    },
  ),
  ("pointLights", { "color": {}, "position": {}, "decay": {}, "distance": {} }),
  (
    "pointLightShadows",
    {
      "shadowIntensity": 1,
      "shadowBias": {},
      "shadowNormalBias": {},
      "shadowRadius": {},
      "shadowMapSize": {},
      "shadowCameraNear": {},
      "shadowCameraFar": {},
    },
  ),
  ("hemisphereLights", { "direction": {}, "skyColor": {}, "groundColor": {} }),
  ("rectAreaLights", { "color": {}, "position": {}, "width": {}, "height": {} }),
])
