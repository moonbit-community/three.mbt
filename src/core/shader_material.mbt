// Upstream src/materials/ShaderMaterial.js.

///|
#external
pub type ShaderMaterial

///|
pub fn ShaderMaterial::new() -> Material {
  let material = Material::new()
  material.type_ = "ShaderMaterial"
  material.material_type = ShaderMaterial
  material.defines = Some(Map([]))
  material.uniforms = Some(Map([]))
  material.uniforms_groups = Some([])
  material.vertex_shader = Some(default_vertex)
  material.fragment_shader = Some(default_fragment)
  material.linewidth = Some(1.0)
  material.wireframe = Some(false)
  material.wireframe_linewidth = Some(1.0)
  material.fog = Some(false)
  material.lights = Some(false)
  material.clipping = Some(false)
  material.force_single_pass = true
  material.extensions = Some({ clip_cull_distance: false, multi_draw: false, })
  material.default_attribute_values = Some(
    Map([("color", [1.0, 1.0, 1.0]), ("uv", [0.0, 0.0]), ("uv1", [0.0, 0.0])]),
  )
  material.uniforms_need_update = Some(false)
  material
}

///|
/// `isShaderMaterial`; also true for `RawShaderMaterial`.
pub fn Material::is_shader_material(self : Material) -> Bool {
  self.material_type is (ShaderMaterial | RawShaderMaterial)
}

///|
/// `Object.assign( {}, source )`.
fn[V] shader_assign_map(source : Map[String, V]?) -> Map[String, V] {
  let target = Map([])
  if source is Some(source) {
    for key, value in source {
      target[key] = value
    }
  }
  target
}

///|
fn Material::copy_shader(self : Material, source : Material) -> Unit {
  self.copy_base(source)
  self.fragment_shader = source.fragment_shader
  self.vertex_shader = source.vertex_shader
  self.uniforms = Some(clone_uniforms(source.uniforms.unwrap()))
  self.uniforms_groups = Some(
    clone_uniforms_groups(source.uniforms_groups.unwrap()),
  )
  self.defines = Some(shader_assign_map(source.defines))
  self.wireframe = source.wireframe
  self.wireframe_linewidth = source.wireframe_linewidth
  self.fog = source.fog
  self.lights = source.lights
  self.clipping = source.clipping
  self.extensions = Some(
    match source.extensions {
      Some(extensions) =>
        {
          clip_cull_distance: extensions.clip_cull_distance,
          multi_draw: extensions.multi_draw,
        }
      None => { clip_cull_distance: false, multi_draw: false, }
    },
  )
  self.glsl_version = source.glsl_version
  self.default_attribute_values = Some(
    shader_assign_map(source.default_attribute_values),
  )
  self.index0_attribute_name = source.index0_attribute_name
  self.uniforms_need_update = source.uniforms_need_update
}

///|
/// What `JSON.stringify` writes for `value`; `None` is `undefined`, which it leaves out.
fn shader_uniform_plain_json(value : UniformValue) -> Json? {
  let json : Json = match value {
    Null => Json::null()
    Bool(v) => Json::boolean(v)
    Int(v) => json_int(v)
    Number(v) => material_json_number(v)
    Numbers(v) => material_json_numbers(v)
    Vector2(v) =>
      Json::object(
        Map([("x", material_json_number(v.x)), ("y", material_json_number(v.y))]),
      )
    Vector3(v) =>
      Json::object(
        Map([
          ("x", material_json_number(v.x)),
          ("y", material_json_number(v.y)),
          ("z", material_json_number(v.z)),
        ]),
      )
    Vector4(v) =>
      Json::object(
        Map([
          ("x", material_json_number(v.x)),
          ("y", material_json_number(v.y)),
          ("z", material_json_number(v.z)),
          ("w", material_json_number(v.w)),
        ]),
      )
    Color(v) => json_int(v.get_hex())
    Quaternion(v) => material_json_numbers(v.to_json())
    Matrix3(v) =>
      Json::object(Map([("elements", material_json_numbers(v.elements))]))
    Matrix4(v) =>
      Json::object(Map([("elements", material_json_numbers(v.elements))]))
    Plane(v) => v.to_json()
    Texture(v) => v.to_json()
    TypedArray(v) => JsValue::of(v).to_json()
    Array(v) =>
      Json::array(
        v.map(item => {
          match shader_uniform_plain_json(item) {
            Some(item) => item
            None => Json::null()
          }
        }),
      )
    Struct(v) => {
      let object = Map([])
      for key, item in v {
        if shader_uniform_plain_json(item) is Some(item) {
          object[key] = item
        }
      }
      Json::object(object)
    }
    Other(v) => {
      if v.is_undefined() {
        return None
      }
      v.to_json()
    }
  }
  Some(json)
}

///|
fn shader_uniform_to_json(value : UniformValue, meta : ToJsonMeta?) -> Json {
  fn typed(type_ : String, value : Json) -> Json {
    Json::object(Map([("type", Json::string(type_)), ("value", value)]))
  }

  match value {
    Texture(v) => typed("t", material_texture_uuid(v, meta))
    Color(v) => typed("c", json_int(v.get_hex()))
    Vector2(v) => typed("v2", material_json_numbers(v.to_array()))
    Vector3(v) => typed("v3", material_json_numbers(v.to_array()))
    Vector4(v) => typed("v4", material_json_numbers(v.to_array()))
    Matrix3(v) => typed("m3", material_json_numbers(v.to_array()))
    Matrix4(v) => typed("m4", material_json_numbers(v.to_array()))
    _ => {
      // note: the array variants v2v, v3v, v4v, m4v and tv are not supported so far
      let object = Map([])
      if shader_uniform_plain_json(value) is Some(value) {
        object["value"] = value
      }
      Json::object(object)
    }
  }
}

///|
/// The additions of `ShaderMaterial.toJSON` after `super.toJSON( meta )`.
fn Material::to_json_shader(
  self : Material,
  meta : ToJsonMeta?,
  data : Map[String, Json],
) -> Unit {
  data["glslVersion"] = match self.glsl_version {
    Some(version) => Json::string(version)
    None => Json::null()
  }
  let uniforms = Map([])
  if self.uniforms is Some(source) {
    for name, uniform in source {
      uniforms[name] = shader_uniform_to_json(uniform.value, meta)
    }
  }
  data["uniforms"] = Json::object(uniforms)
  if self.defines is Some(defines) && defines.length() > 0 {
    data["defines"] = Json::object(defines)
  }
  material_put_string(data, "vertexShader", self.vertex_shader)
  material_put_string(data, "fragmentShader", self.fragment_shader)
  material_put_bool(data, "lights", self.lights)
  material_put_bool(data, "clipping", self.clipping)
  let extensions = Map([])
  if self.extensions is Some(source) {
    if source.clip_cull_distance {
      extensions["clipCullDistance"] = Json::boolean(true)
    }
    if source.multi_draw {
      extensions["multiDraw"] = Json::boolean(true)
    }
  }
  if extensions.length() > 0 {
    data["extensions"] = Json::object(extensions)
  }
}

///|
/// The value upstream keeps as parsed; `undefined` and `null` both become `Null`.
fn shader_uniform_from_plain_json(json : Json?) -> UniformValue {
  match json {
    None | Some(Null) => Null
    Some(True) => Bool(true)
    Some(False) => Bool(false)
    Some(Number(value, ..)) => Number(value)
    Some(String(_) as value) => Other(JsValue::from_json(value))
    Some(Array(values)) => {
      let numbers = []
      for value in values {
        guard value is Number(number, ..) else {
          return Array(
            values.map(item => shader_uniform_from_plain_json(Some(item))),
          )
        }
        numbers.push(number)
      }
      Numbers(numbers)
    }
    Some(Object(values)) => {
      let object = Map([])
      for key, value in values {
        object[key] = shader_uniform_from_plain_json(Some(value))
      }
      Struct(object)
    }
  }
}

///|
fn shader_uniform_from_json(
  uniform : Json,
  textures : Map[String, Texture]?,
) -> UniformValue {
  guard uniform is Object(uniform) else {
    abort("ShaderMaterial::from_json: uniform is not an object")
  }
  let value = uniform.get("value")
  fn numbers() -> Array[Double] {
    match value {
      Some(value) => material_read_numbers(value)
      None => abort("ShaderMaterial::from_json: uniform has no value")
    }
  }

  fn hex() -> Int32 {
    guard value is Some(Number(hex, ..)) else {
      abort("ShaderMaterial::from_json: uniform has no hex value")
    }
    hex.to_int()
  }

  match uniform.get("type") {
    Some(String("t")) => {
      guard textures is Some(textures) else {
        abort("ShaderMaterial::from_json: no textures for a uniform")
      }
      match value {
        Some(String(uuid)) =>
          match textures.get(uuid) {
            Some(texture) => Texture(texture)
            None => Null
          }
        _ => Null
      }
    }
    Some(String("c")) => Color(@math.Color::new(1.0, 1.0, 1.0).set_hex(hex()))
    Some(String("v2")) =>
      Vector2(@math.Vector2::new(0.0, 0.0).from_array(numbers()))
    Some(String("v3")) =>
      Vector3(@math.Vector3::new(0.0, 0.0, 0.0).from_array(numbers()))
    Some(String("v4")) =>
      Vector4(@math.Vector4::new(0.0, 0.0, 0.0, 1.0).from_array(numbers()))
    Some(String("m3")) => Matrix3(@math.Matrix3::new().from_array(numbers()))
    Some(String("m4")) => Matrix4(@math.Matrix4::new().from_array(numbers()))
    _ => shader_uniform_from_plain_json(value)
  }
}

///|
/// The additions of `ShaderMaterial.fromJSON` after `super.fromJSON( json, textures )`.
fn Material::from_json_shader(
  self : Material,
  json : Map[String, Json],
  textures : Map[String, Texture]?,
) -> Unit {
  if json.get("uniforms") is Some(Object(uniforms)) {
    let target = self.uniforms.unwrap()
    for name, uniform in uniforms {
      target[name] = Uniform::new(shader_uniform_from_json(uniform, textures))
    }
  }
  if json.get("defines") is Some(Object(defines)) {
    self.defines = Some(defines)
  }
  self.vertex_shader = material_read_opt_string(
    json,
    "vertexShader",
    self.vertex_shader,
  )
  self.fragment_shader = material_read_opt_string(
    json,
    "fragmentShader",
    self.fragment_shader,
  )
  self.glsl_version = material_read_opt_string(
    json,
    "glslVersion",
    self.glsl_version,
  )
  if json.get("extensions") is Some(Object(extensions)) {
    let target = self.extensions.unwrap()
    target.clip_cull_distance = material_read_bool(
      extensions,
      "clipCullDistance",
      target.clip_cull_distance,
    )
    target.multi_draw = material_read_bool(
      extensions,
      "multiDraw",
      target.multi_draw,
    )
  }
  self.lights = material_read_opt_bool(json, "lights", self.lights)
  self.clipping = material_read_opt_bool(json, "clipping", self.clipping)
}
