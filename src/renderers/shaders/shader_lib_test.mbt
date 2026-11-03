// Tests for upstream src/renderers/shaders/ShaderLib.js.

///|
test "ShaderLib Instancing" {
  assert_true(@shaders.shader_lib.length() > 0)
}

///|
test "ShaderLib key order, with physical last" {
  assert_eq(@shaders.shader_lib.keys().collect(), [
    "basic", "lambert", "phong", "standard", "toon", "matcap", "points", "dashed",
    "depth", "normal", "sprite", "background", "backgroundCube", "cube", "equirect",
    "distance", "shadow", "physical",
  ])
}

///|
test "ShaderLib shaders come from ShaderChunk" {
  let lib = @shaders.shader_lib
  let chunk = @shaders.shader_chunk
  assert_eq(lib["basic"].vertex_shader, chunk["meshbasic_vert"])
  assert_eq(lib["basic"].fragment_shader, chunk["meshbasic_frag"])
  assert_eq(lib["dashed"].vertex_shader, chunk["linedashed_vert"])
  assert_eq(lib["backgroundCube"].fragment_shader, chunk["backgroundCube_frag"])
  assert_eq(lib["standard"].vertex_shader, chunk["meshphysical_vert"])
  assert_eq(lib["physical"].vertex_shader, chunk["meshphysical_vert"])
  assert_eq(lib["physical"].fragment_shader, chunk["meshphysical_frag"])
}

///|
test "physical extends standard" {
  let standard = @shaders.shader_lib["standard"].uniforms.keys().collect()
  let physical = @shaders.shader_lib["physical"].uniforms.keys().collect()
  assert_eq(physical[:standard.length()].to_owned(), standard)
  assert_eq(physical[standard.length()], "clearcoat")
  assert_eq(physical[physical.length() - 1], "anisotropyMapTransform")
}

///|
test "ShaderLib uniforms are clones of UniformsLib" {
  guard @shaders.shader_lib["basic"].uniforms["diffuse"].value is Color(cloned) else {
    fail("basic.diffuse")
  }
  guard @shaders.uniforms_lib["common"]["diffuse"].value is Color(shared) else {
    fail("common.diffuse")
  }
  assert_true(!physical_equal(cloned, shared))
  assert_true(cloned.equals(shared))
}

///|
test "merge keeps the first position of a repeated uniform" {
  let keys = @shaders.shader_lib["normal"].uniforms.keys().collect()
  assert_eq(keys[1], "opacity")
  assert_eq(keys.filter(key => key == "opacity").length(), 1)
}
