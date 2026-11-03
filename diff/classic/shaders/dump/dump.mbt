///|
extern "js" fn js_array(a : Array[@core.JsValue]) -> @core.JsValue = "(a) => a"

///|
fn obj(fields : Array[(String, @core.JsValue)]) -> @core.JsValue {
  let o = @core.JsValue::object()
  for pair in fields {
    o.set(pair.0, pair.1)
  }
  o
}

///|
fn[T] of(x : T) -> @core.JsValue {
  @core.JsValue::of(x)
}

///|
fn ser(v : @core.UniformValue) -> @core.JsValue {
  match v {
    Null => obj([("t", of("null"))])
    Number(x) => obj([("t", of("number")), ("v", of(x))])
    Color(c) =>
      obj([
        ("t", of("color")),
        ("r", of(c.r)),
        ("g", of(c.g)),
        ("b", of(c.b)),
        ("ref", of(c)),
      ])
    Vector2(a) =>
      obj([("t", of("vector2")), ("x", of(a.x)), ("y", of(a.y)), ("ref", of(a))])
    Vector3(a) =>
      obj([
        ("t", of("vector3")),
        ("x", of(a.x)),
        ("y", of(a.y)),
        ("z", of(a.z)),
        ("ref", of(a)),
      ])
    Matrix3(m) =>
      obj([("t", of("matrix3")), ("e", of(m.elements)), ("ref", of(m))])
    Array(items) =>
      obj([
        ("t", of("array")),
        ("items", js_array(items.map(ser))),
        ("ref", of(items)),
      ])
    _ => obj([("t", of("UNEXPECTED_VARIANT"))])
  }
}

///|
fn ser_uniforms(m : Map[String, @core.Uniform]) -> @core.JsValue {
  let out = []
  for k, u in m {
    out.push(js_array([of(k), ser(u.value), of(u)]))
  }
  js_array(out)
}

///|
fn dfg(t : @core.Texture) -> @core.JsValue {
  let (w, h, depth, data) = match t.image() {
    DataImage(i) => (of(i.width), of(i.height), of(i.depth), of(i.data.unwrap()))
    _ => (of("x"), of("x"), of("x"), of("x"))
  }
  obj([
    ("name", of(t.name)),
    ("width", w),
    ("height", h),
    ("depth", depth),
    ("data", data),
    ("format", of(t.format)),
    ("type", of(t.type_)),
    ("internalFormat", of(t.internal_format)),
    ("magFilter", of(t.mag_filter)),
    ("minFilter", of(t.min_filter)),
    ("wrapS", of(t.wrap_s)),
    ("wrapT", of(t.wrap_t)),
    ("mapping", of(t.mapping)),
    ("channel", of(t.channel)),
    ("anisotropy", of(t.anisotropy)),
    ("colorSpace", of(t.color_space)),
    ("generateMipmaps", of(t.generate_mipmaps)),
    ("mipmapsAutoUpdate", of(t.mipmaps_auto_update)),
    ("premultiplyAlpha", of(t.premultiply_alpha)),
    ("flipY", of(t.flip_y)),
    ("unpackAlignment", of(t.unpack_alignment)),
    ("matrixAutoUpdate", of(t.matrix_auto_update)),
    ("rotation", of(t.rotation)),
    ("offset", of(t.offset.to_array())),
    ("repeat", of(t.repeat.to_array())),
    ("center", of(t.center.to_array())),
    ("matrix", of(t.matrix.elements)),
    ("mipmapsLength", of(t.mipmaps.length())),
    ("version", of(t.version)),
    ("sourceVersion", of(t.source.version)),
    ("isDataTexture", of(t.texture_type is DataTexture)),
  ])
}

///|
pub fn dump() -> @core.JsValue {
  let chunks = []
  for k, v in @shaders.shader_chunk {
    chunks.push(js_array([of(k), of(v)]))
  }
  let lib = []
  for k, e in @shaders.shader_lib {
    lib.push(
      js_array([
        of(k),
        ser_uniforms(e.uniforms),
        of(e.vertex_shader),
        of(e.fragment_shader),
      ]),
    )
  }
  let groups = []
  for k, g in @shaders.uniforms_lib {
    groups.push(js_array([of(k), ser_uniforms(g)]))
  }
  let properties = []
  for k, p in @shaders.uniforms_lib_properties {
    properties.push(js_array([of(k), of(p.stringify())]))
  }
  let lut = @shaders.get_dfg_lut()
  obj([
    ("chunks", js_array(chunks)),
    ("lib", js_array(lib)),
    ("groups", js_array(groups)),
    ("properties", js_array(properties)),
    ("vsm", js_array([of(@shaders.vsm_vertex), of(@shaders.vsm_fragment)])),
    ("defaults", js_array([of(@core.default_vertex), of(@core.default_fragment)])),
    ("dfg", dfg(lut)),
    ("dfgSame", of(physical_equal(lut, @shaders.get_dfg_lut()))),
  ])
}
