// Unit tests for the foundation helpers and the modules without GL calls.

///|
test "stable_sort_by keeps equal elements in order" {
  let items = [(3, "a"), (1, "b"), (3, "c"), (2, "d"), (1, "e"), (3, "f")]
  for _ in 0..<4 {
    items.append(items.copy())
  }
  @webgl.stable_sort_by(items, (a, b) => (a.0 - b.0).to_double())
  let firsts = items.filter(it => it.0 == 1).map(it => it.1)
  inspect(firsts.length(), content="32")
  // equal keys keep their input order: b, e, b, e, ...
  inspect(firsts[0] + firsts[1] + firsts[2] + firsts[3], content="bebe")
  inspect(items[items.length() - 1].1, content="f")
  // NaN compares as equal, as in Array.prototype.sort
  let xs = [2.0, 1.0, 0.0]
  @webgl.stable_sort_by(xs, (_, _) => 0.0 / 0.0)
  debug_inspect(xs, content="[2, 1, 0]")
}

///|
test "WeakMap keys by identity" {
  let map : @webgl.WeakMap[@core.Material, Int32] = @webgl.WeakMap::new()
  let a = @core.MeshBasicMaterial::new()
  let b = @core.MeshBasicMaterial::new()
  map.set(a, 1)
  debug_inspect(map.get(a), content="Some(1)")
  debug_inspect(map.get(b), content="None")
  assert_true(map.has(a))
  map.delete(a)
  assert_true(!map.has(a))
}

///|
test "WebGLProperties records per object" {
  let properties = @webgl.WebGLProperties::new()
  let material = @core.MeshBasicMaterial::new()
  let texture = @core.Texture::new()
  assert_true(!properties.has(material))
  let m = properties.get_material(material)
  m.__version = Some(3)
  assert_true(properties.has(material))
  debug_inspect(properties.get_material(material).__version, content="Some(3)")
  properties.get_texture(texture).__webgl_init = true
  assert_true(properties.get_texture(texture).__webgl_init)
  properties.remove(material)
  debug_inspect(properties.get_material(material).__version, content="None")
  properties.dispose()
  assert_true(!properties.has(texture))
}

///|
test "WebGLShaderCache counts stage users" {
  let cache = @webgl.WebGLShaderCache::new()
  let m1 = @core.ShaderMaterial::new()
  m1.vertex_shader = Some("v")
  m1.fragment_shader = Some("f")
  let m2 = @core.ShaderMaterial::new()
  m2.vertex_shader = Some("v")
  m2.fragment_shader = Some("f2")
  let v1 = cache.get_vertex_shader_stage(m1)
  let f1 = cache.get_fragment_shader_stage(m1)
  ignore(cache.update(m1, v1, f1))
  ignore(cache.update(m1, v1, f1))
  let v2 = cache.get_vertex_shader_stage(m2)
  let f2 = cache.get_fragment_shader_stage(m2)
  ignore(cache.update(m2, v2, f2))
  assert_true(physical_equal(v1, v2))
  inspect(v1.used_times, content="2")
  inspect(f1.used_times, content="1")
  inspect(f2.id - f1.id, content="1")
  ignore(cache.remove(m1))
  inspect(v1.used_times, content="1")
  inspect(cache.shader_cache.contains("f"), content="false")
  inspect(cache.shader_cache.contains("v"), content="true")
  cache.dispose()
  inspect(cache.shader_cache.length(), content="0")
}

///|
test "same_handle and js_try" {
  let gl = mock_gl()
  let a = gl.create_buffer()
  let b = gl.create_buffer()
  assert_true(@webgl.same_handle(Some(a), Some(a)))
  assert_true(!@webgl.same_handle(Some(a), Some(b)))
  assert_true(@webgl.same_handle((None : @webgl.GLBuffer?), None))
  debug_inspect(@webgl.js_try(() => ()), content="None")
  assert_true(@webgl.js_try(() => throw_js_error()) is Some(_))
}

///|
extern "js" fn throw_js_error() -> Unit = "() => { throw new Error('boom'); }"

///|
test "side tables" {
  let u = @core.Uniform::new(Null)
  debug_inspect(@webgl.uniform_needs_update(u), content="None")
  @webgl.set_uniform_needs_update(u, false)
  debug_inspect(@webgl.uniform_needs_update(u), content="Some(false)")
  let camera = @core.PerspectiveCamera::new()
  assert_true(@webgl.camera_viewport(camera) is None)
  @webgl.set_camera_viewport(camera, Some(@math.Vector4::new(0, 0, 1, 1)))
  assert_true(@webgl.camera_viewport(camera) is Some(_))
  @webgl.set_camera_viewport(camera, None)
  assert_true(@webgl.camera_viewport(camera) is None)
  assert_true(@webgl.uniforms_lib_ltc.ltc_float_1 is None)
}
