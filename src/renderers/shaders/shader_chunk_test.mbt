// Tests for upstream src/renderers/shaders/ShaderChunk.js. Upstream only checks that
// `ShaderChunk` exists; full byte comparison with upstream happens outside this repo.

///|
/// The `x` of each `#include <x>` line. Mirrors `includePattern` in WebGLProgram.js.
fn shader_chunk_includes(source : String) -> Array[String] {
  let result = []
  for line in source.split("\n") {
    let line = line.trim()
    if line.strip_prefix("#include <") is Some(rest) &&
      rest.strip_suffix(">") is Some(name) {
      result.push(name.to_owned())
    }
  }
  result
}

///|
test "ShaderChunk Instancing" {
  assert_true(@shaders.shader_chunk.length() > 0)
}

///|
test "ShaderChunk keys and order follow upstream" {
  let keys = @shaders.shader_chunk.keys().collect()
  assert_eq(keys.length(), 141)
  assert_eq(keys[0], "alphahash_fragment")
  assert_eq(keys[12], "bsdfs")
  assert_eq(keys[13], "iridescence_fragment")
  assert_eq(keys[keys.length() - 1], "sprite_frag")
  assert_true(keys.contains("backgroundCube_vert"))
  assert_true(!keys.contains("default_vertex"))
  assert_true(!keys.contains("vsm_vert"))
}

///|
test "ShaderChunk strings keep their leading and trailing newlines" {
  for key, chunk in @shaders.shader_chunk {
    assert_true(chunk.has_prefix("\n"), msg=key)
    assert_true(chunk.has_suffix("\n"), msg=key)
  }
}

///|
test "ShaderChunk keeps non-ASCII text and trailing whitespace" {
  assert_true(@shaders.shader_chunk["alphahash_pars_fragment"].contains("ατ"))
  assert_true(
    @shaders.shader_chunk["lights_physical_pars_fragment"].contains(
      "Disney’s",
    ),
  )
  assert_true(
    @shaders.shader_chunk["aomap_fragment"].contains(
      "#if defined( USE_CLEARCOAT ) \n",
    ),
  )
}

///|
test "every #include resolves through ShaderChunk" {
  let includes = []
  for _, chunk in @shaders.shader_chunk {
    includes.append(shader_chunk_includes(chunk))
  }
  assert_true(includes.length() > 0)
  for name in includes {
    assert_true(@shaders.shader_chunk.contains(name), msg=name)
  }
}

///|
test "ShaderChunk can be assigned into, and ShaderLib keeps its snapshot" {
  let key = "meshbasic_vert"
  let original = @shaders.shader_chunk[key]
  @shaders.shader_chunk[key] = "patched"
  assert_eq(@shaders.shader_chunk[key], "patched")
  assert_eq(@shaders.shader_lib["basic"].vertex_shader, original)
  @shaders.shader_chunk[key] = original
  @shaders.shader_chunk["my_chunk"] = "void f() {}"
  assert_eq(@shaders.shader_chunk.get("my_chunk"), Some("void f() {}"))
  @shaders.shader_chunk.remove("my_chunk")
}

///|
test "vsm shaders stay outside ShaderChunk" {
  assert_true(@shaders.vsm_vertex.has_prefix("\nvoid main() {"))
  assert_true(@shaders.vsm_fragment.contains("VSM_SAMPLES"))
}
