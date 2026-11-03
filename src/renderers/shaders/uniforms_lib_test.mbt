// Tests for upstream src/renderers/shaders/UniformsLib.js.

///|
test "UniformsLib Instancing" {
  assert_true(@shaders.uniforms_lib.length() > 0)
}

///|
test "UniformsLib group order follows upstream" {
  let keys = @shaders.uniforms_lib.keys().collect()
  assert_eq(keys, [
    "common", "specularmap", "envmap", "aomap", "lightmap", "bumpmap", "normalmap",
    "displacementmap", "emissivemap", "metalnessmap", "roughnessmap", "gradientmap",
    "fog", "lights", "points", "sprite",
  ])
}

///|
test "UniformsLib uniform values" {
  let common = @shaders.uniforms_lib["common"]
  assert_eq(common.keys().collect(), [
    "diffuse", "opacity", "map", "mapTransform", "alphaMap", "alphaMapTransform",
    "alphaTest",
  ])
  guard common["diffuse"].value is Color(color) else { fail("diffuse") }
  assert_true(color.equals(@math.Color::from_hex(0xffffff)))
  guard common["map"].value is Null else { fail("map") }
  guard common["alphaTest"].value is Number(0.0) else { fail("alphaTest") }
  guard common["mapTransform"].value is Matrix3(matrix) else {
    fail("mapTransform")
  }
  assert_true(matrix.equals(@math.Matrix3::new()))
  guard @shaders.uniforms_lib["normalmap"]["normalScale"].value
    is Vector2(scale) else {
    fail("normalScale")
  }
  assert_eq(scale.x, 1.0)
  guard @shaders.uniforms_lib["sprite"]["center"].value is Vector2(center) else {
    fail("center")
  }
  assert_eq(center.y, 0.5)
  guard @shaders.uniforms_lib["lights"]["spotLights"].value is Array([]) else {
    fail("spotLights")
  }
}

///|
test "UniformsLib lights properties" {
  let properties = @shaders.uniforms_lib_properties
  assert_eq(properties.length(), 10)
  for name, _ in properties {
    assert_true(@shaders.uniforms_lib["lights"].contains(name), msg=name)
  }
  guard properties["pointLightShadows"] is Object(shadow) else {
    fail("object")
  }
  assert_eq(shadow.keys().collect(), [
    "shadowIntensity", "shadowBias", "shadowNormalBias", "shadowRadius", "shadowMapSize",
    "shadowCameraNear", "shadowCameraFar",
  ])
  assert_eq(shadow["shadowIntensity"], Json::number(1.0))
}
