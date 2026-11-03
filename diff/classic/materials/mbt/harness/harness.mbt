// Differential harness: the MoonBit half. See diff.mjs.

fn jnum(v : Double) -> Json {
  if v != v { Json::string("NaN") } else if v == 1.0/0.0 { Json::string("Infinity") } else if v == -1.0/0.0 { Json::string("-Infinity") } else { Json::number(v) }
}
fn jint(v : Int) -> Json { Json::number(v.to_double()) }
fn ojint(v : Int?) -> Json { match v { Some(v) => jint(v); None => Json::null() } }
fn ojnum(v : Double?) -> Json { match v { Some(v) => jnum(v); None => Json::null() } }
fn ojbool(v : Bool?) -> Json { match v { Some(v) => Json::boolean(v); None => Json::null() } }
fn ojstr(v : String?) -> Json { match v { Some(v) => Json::string(v); None => Json::null() } }
fn jcolor(c : @math.Color) -> Json { Json::array([jnum(c.r), jnum(c.g), jnum(c.b)]) }
fn ojcolor(c : @math.Color?) -> Json { match c { Some(c) => jcolor(c); None => Json::null() } }
fn ojv2(c : @math.Vector2?) -> Json { match c { Some(c) => Json::array([jnum(c.x), jnum(c.y)]); None => Json::null() } }
fn ojeuler(c : @math.Euler?) -> Json { match c { Some(c) => Json::array([jnum(c.x), jnum(c.y), jnum(c.z), Json::string(c.order)]); None => Json::null() } }
fn ojtex(c : @core.Texture?) -> Json { match c { Some(c) => Json::string(c.uuid); None => Json::null() } }
fn ojplanes(c : Array[@math.Plane]?) -> Json { match c { Some(c) => Json::array(c.map(p => Json::array([jnum(p.normal.x), jnum(p.normal.y), jnum(p.normal.z), jnum(p.constant)]))); None => Json::null() } }
fn ojdefines(c : Map[String, Json]?) -> Json { match c { Some(c) => Json::object(c); None => Json::null() } }
fn jdoubles(c : Array[Double]) -> Json { Json::array(c.map(jnum)) }
fn juniform(v : @core.UniformValue) -> Json {
  match v {
    Null => Json::null()
    Bool(b) => Json::boolean(b)
    Int(i) => jint(i)
    Number(n) => jnum(n)
    Numbers(a) => jdoubles(a)
    Vector2(v) => { "v2": jdoubles(v.to_array()) }
    Vector3(v) => { "v3": jdoubles(v.to_array()) }
    Vector4(v) => { "v4": jdoubles(v.to_array()) }
    Color(c) => { "c": jcolor(c) }
    Quaternion(q) => { "q": jdoubles(q.to_array()) }
    Matrix3(m) => { "m3": jdoubles(m.to_array()) }
    Matrix4(m) => { "m4": jdoubles(m.to_array()) }
    Plane(p) => { "p": ojplanes(Some([p])) }
    Texture(t) => { "t": Json::string(t.name) }
    Array(a) => Json::array(a.map(juniform))
    Struct(m) => { let o = Map([]); for k, x in m { o[k] = juniform(x) }; { "s": Json::object(o) } }
    TypedArray(_) => { "typed": Json::boolean(true) }
    Other(v) => { "other": v.to_json() }
  }
}
fn ojuniforms(c : Map[String, @core.Uniform]?) -> Json {
  match c { Some(c) => { let o = Map([]); for k, u in c { o[k] = juniform(u.value) }; Json::object(o) }; None => Json::null() }
}
fn ojgroups(c : Array[@core.UniformsGroup]?) -> Json {
  match c { Some(c) => Json::array(c.map(g => { "name": Json::string(g.name), "usage": jint(g.usage) })); None => Json::null() }
}
fn ojext(c : @core.ShaderExtensions?) -> Json {
  match c { Some(c) => { "clipCullDistance": Json::boolean(c.clip_cull_distance), "multiDraw": Json::boolean(c.multi_draw) }; None => Json::null() }
}
fn ojattrs(c : Map[String, Array[Double]]?) -> Json {
  match c { Some(c) => { let o = Map([]); for k, a in c { o[k] = jdoubles(a) }; Json::object(o) }; None => Json::null() }
}
fn juser(v : @core.JsValue) -> Json { v.to_json() }

fn dump(m : @core.Material) -> Json {
  let o : Map[String, Json] = Map([])
  o["uuid_set"] = Json::boolean(m.uuid != "")
  o["name"] = Json::string(m.name)
  o["type"] = Json::string(m.type_)
  o["blending"] = jint(m.blending)
  o["side"] = jint(m.side)
  o["vertexColors"] = Json::boolean(m.vertex_colors)
  o["opacity"] = jnum(m.opacity)
  o["transparent"] = Json::boolean(m.transparent)
  o["alphaHash"] = Json::boolean(m.alpha_hash)
  o["blendSrc"] = jint(m.blend_src)
  o["blendDst"] = jint(m.blend_dst)
  o["blendEquation"] = jint(m.blend_equation)
  o["blendSrcAlpha"] = ojint(m.blend_src_alpha)
  o["blendDstAlpha"] = ojint(m.blend_dst_alpha)
  o["blendEquationAlpha"] = ojint(m.blend_equation_alpha)
  o["blendColor"] = jcolor(m.blend_color)
  o["blendAlpha"] = jnum(m.blend_alpha)
  o["depthFunc"] = jint(m.depth_func)
  o["depthTest"] = Json::boolean(m.depth_test)
  o["depthWrite"] = Json::boolean(m.depth_write)
  o["stencilWriteMask"] = jint(m.stencil_write_mask)
  o["stencilFunc"] = jint(m.stencil_func)
  o["stencilRef"] = jint(m.stencil_ref)
  o["stencilFuncMask"] = jint(m.stencil_func_mask)
  o["stencilFail"] = jint(m.stencil_fail)
  o["stencilZFail"] = jint(m.stencil_z_fail)
  o["stencilZPass"] = jint(m.stencil_z_pass)
  o["stencilWrite"] = Json::boolean(m.stencil_write)
  o["clippingPlanes"] = ojplanes(m.clipping_planes)
  o["clipIntersection"] = Json::boolean(m.clip_intersection)
  o["clipShadows"] = Json::boolean(m.clip_shadows)
  o["shadowSide"] = ojint(m.shadow_side)
  o["colorWrite"] = Json::boolean(m.color_write)
  o["precision"] = ojstr(m.precision)
  o["polygonOffset"] = Json::boolean(m.polygon_offset)
  o["polygonOffsetFactor"] = jnum(m.polygon_offset_factor)
  o["polygonOffsetUnits"] = jnum(m.polygon_offset_units)
  o["dithering"] = Json::boolean(m.dithering)
  o["alphaToCoverage"] = Json::boolean(m.alpha_to_coverage)
  o["premultipliedAlpha"] = Json::boolean(m.premultiplied_alpha)
  o["forceSinglePass"] = Json::boolean(m.force_single_pass)
  o["allowOverride"] = Json::boolean(m.allow_override)
  o["visible"] = Json::boolean(m.visible)
  o["toneMapped"] = Json::boolean(m.tone_mapped)
  o["userData"] = juser(m.user_data)
  o["version"] = jint(m.version)
  o["alphaTest"] = jnum(m._alpha_test)
  o["defines"] = ojdefines(m.defines)
  o["color"] = ojcolor(m.color)
  o["map"] = ojtex(m.map)
  o["linewidth"] = ojnum(m.linewidth)
  o["linecap"] = ojstr(m.linecap)
  o["linejoin"] = ojstr(m.linejoin)
  o["fog"] = ojbool(m.fog)
  o["scale"] = ojnum(m.scale)
  o["dashSize"] = ojnum(m.dash_size)
  o["gapSize"] = ojnum(m.gap_size)
  o["lightMap"] = ojtex(m.light_map)
  o["lightMapIntensity"] = ojnum(m.light_map_intensity)
  o["aoMap"] = ojtex(m.ao_map)
  o["aoMapIntensity"] = ojnum(m.ao_map_intensity)
  o["specularMap"] = ojtex(m.specular_map)
  o["alphaMap"] = ojtex(m.alpha_map)
  o["envMap"] = ojtex(m.env_map)
  o["envMapRotation"] = ojeuler(m.env_map_rotation)
  o["envMapIntensity"] = ojnum(m.env_map_intensity)
  o["combine"] = ojint(m.combine)
  o["reflectivity"] = ojnum(m.reflectivity())
  o["refractionRatio"] = ojnum(m.refraction_ratio)
  o["wireframe"] = ojbool(m.wireframe)
  o["wireframeLinewidth"] = ojnum(m.wireframe_linewidth)
  o["wireframeLinecap"] = ojstr(m.wireframe_linecap)
  o["wireframeLinejoin"] = ojstr(m.wireframe_linejoin)
  o["depthPacking"] = ojint(m.depth_packing)
  o["displacementMap"] = ojtex(m.displacement_map)
  o["displacementScale"] = ojnum(m.displacement_scale)
  o["displacementBias"] = ojnum(m.displacement_bias)
  o["emissive"] = ojcolor(m.emissive)
  o["emissiveIntensity"] = ojnum(m.emissive_intensity)
  o["emissiveMap"] = ojtex(m.emissive_map)
  o["bumpMap"] = ojtex(m.bump_map)
  o["bumpScale"] = ojnum(m.bump_scale)
  o["normalMap"] = ojtex(m.normal_map)
  o["normalMapType"] = ojint(m.normal_map_type)
  o["normalScale"] = ojv2(m.normal_scale)
  o["flatShading"] = ojbool(m.flat_shading)
  o["matcap"] = ojtex(m.matcap)
  o["gradientMap"] = ojtex(m.gradient_map)
  o["specular"] = ojcolor(m.specular)
  o["shininess"] = ojnum(m.shininess)
  o["roughness"] = ojnum(m.roughness)
  o["metalness"] = ojnum(m.metalness)
  o["roughnessMap"] = ojtex(m.roughness_map)
  o["metalnessMap"] = ojtex(m.metalness_map)
  o["size"] = ojnum(m.size)
  o["sizeAttenuation"] = ojbool(m.size_attenuation)
  o["rotation"] = ojnum(m.rotation)
  o["uniforms"] = ojuniforms(m.uniforms)
  o["uniformsGroups"] = ojgroups(m.uniforms_groups)
  o["vertexShader"] = ojstr(m.vertex_shader)
  o["fragmentShader"] = ojstr(m.fragment_shader)
  o["lights"] = ojbool(m.lights)
  o["clipping"] = ojbool(m.clipping)
  o["extensions"] = ojext(m.extensions)
  o["defaultAttributeValues"] = ojattrs(m.default_attribute_values)
  o["index0AttributeName"] = ojstr(m.index0_attribute_name)
  o["uniformsNeedUpdate"] = ojbool(m.uniforms_need_update)
  o["glslVersion"] = ojstr(m.glsl_version)
  o["anisotropyRotation"] = ojnum(m.anisotropy_rotation)
  o["anisotropyMap"] = ojtex(m.anisotropy_map)
  o["clearcoatMap"] = ojtex(m.clearcoat_map)
  o["clearcoatRoughness"] = ojnum(m.clearcoat_roughness)
  o["clearcoatRoughnessMap"] = ojtex(m.clearcoat_roughness_map)
  o["clearcoatNormalScale"] = ojv2(m.clearcoat_normal_scale)
  o["clearcoatNormalMap"] = ojtex(m.clearcoat_normal_map)
  o["diffuseRoughnessMap"] = ojtex(m.diffuse_roughness_map)
  o["ior"] = ojnum(m.ior)
  o["iridescenceMap"] = ojtex(m.iridescence_map)
  o["iridescenceIOR"] = ojnum(m.iridescence_ior)
  o["iridescenceThicknessMinimum"] = ojnum(m.iridescence_thickness_minimum)
  o["iridescenceThicknessMaximum"] = ojnum(m.iridescence_thickness_maximum)
  o["iridescenceThicknessMap"] = ojtex(m.iridescence_thickness_map)
  o["sheenColor"] = ojcolor(m.sheen_color)
  o["sheenColorMap"] = ojtex(m.sheen_color_map)
  o["sheenRoughness"] = ojnum(m.sheen_roughness)
  o["sheenRoughnessMap"] = ojtex(m.sheen_roughness_map)
  o["transmissionMap"] = ojtex(m.transmission_map)
  o["thickness"] = ojnum(m.thickness)
  o["thicknessMap"] = ojtex(m.thickness_map)
  o["attenuationDistance"] = ojnum(m.attenuation_distance)
  o["attenuationColor"] = ojcolor(m.attenuation_color)
  o["specularIntensity"] = ojnum(m.specular_intensity)
  o["specularIntensityMap"] = ojtex(m.specular_intensity_map)
  o["specularColor"] = ojcolor(m.specular_color)
  o["specularColorMap"] = ojtex(m.specular_color_map)
  o["anisotropy"] = ojnum(m._anisotropy)
  o["clearcoat"] = ojnum(m._clearcoat)
  o["diffuseRoughness"] = ojnum(m._diffuse_roughness)
  o["dispersion"] = ojnum(m._dispersion)
  o["iridescence"] = ojnum(m._iridescence)
  o["retroreflectivity"] = ojnum(m._retroreflectivity)
  o["sheen"] = ojnum(m._sheen)
  o["transmission"] = ojnum(m._transmission)
  Json::object(o)
}

fn construct(name : String) -> @core.Material {
  match name {
    "Material" => @core.Material::new()
    "LineBasicMaterial" => @core.LineBasicMaterial::new()
    "LineDashedMaterial" => @core.LineDashedMaterial::new()
    "MeshBasicMaterial" => @core.MeshBasicMaterial::new()
    "MeshDepthMaterial" => @core.MeshDepthMaterial::new()
    "MeshDistanceMaterial" => @core.MeshDistanceMaterial::new()
    "MeshLambertMaterial" => @core.MeshLambertMaterial::new()
    "MeshMatcapMaterial" => @core.MeshMatcapMaterial::new()
    "MeshNormalMaterial" => @core.MeshNormalMaterial::new()
    "MeshPhongMaterial" => @core.MeshPhongMaterial::new()
    "MeshPhysicalMaterial" => @core.MeshPhysicalMaterial::new()
    "MeshStandardMaterial" => @core.MeshStandardMaterial::new()
    "MeshToonMaterial" => @core.MeshToonMaterial::new()
    "PointsMaterial" => @core.PointsMaterial::new()
    "RawShaderMaterial" => @core.RawShaderMaterial::new()
    "ShaderMaterial" => @core.ShaderMaterial::new()
    "ShadowMaterial" => @core.ShadowMaterial::new()
    "SpriteMaterial" => @core.SpriteMaterial::new()
    _ => abort("class " + name)
  }
}

let textures : Map[String, @core.Texture] = Map([])
fn tex(name : String) -> @core.Texture {
  match textures.get(name) {
    Some(t) => t
    None => {
      let t = @core.Texture::new()
      t.uuid = "tex-" + name
      t.source.uuid = "src-" + name
      t.name = name
      textures[name] = t
      t
    }
  }
}

fn nums(j : Json) -> Array[Double] {
  guard j is Array(a) else { abort("nums") }
  a.map(x => { guard x is Number(n, ..) else { abort("num") }; n })
}
fn plane(j : Json) -> @math.Plane {
  let a = nums(j)
  @math.Plane::new(normal=@math.Vector3::new(a[0], a[1], a[2]), constant=a[3])
}
fn uniform_value(j : Json) -> @core.UniformValue {
  match j {
    Null => Null
    True => Bool(true)
    False => Bool(false)
    Number(n, ..) => Number(n)
    { "int": Number(n, ..), .. } => Int(n.to_int())
    { "numbers": a, .. } => Numbers(nums(a))
    { "v2": a, .. } => Vector2(@math.Vector2::new(0.0, 0.0).from_array(nums(a)))
    { "v3": a, .. } => Vector3(@math.Vector3::new(0.0, 0.0, 0.0).from_array(nums(a)))
    { "v4": a, .. } => Vector4(@math.Vector4::new(0.0, 0.0, 0.0, 0.0).from_array(nums(a)))
    { "c": Number(h, ..), .. } => Color(@math.Color::from_hex(h.to_int()))
    { "q": a, .. } => { let v = nums(a); Quaternion(@math.Quaternion::new(v[0], v[1], v[2], v[3])) }
    { "m3": a, .. } => Matrix3(@math.Matrix3::new().from_array(nums(a)))
    { "m4": a, .. } => Matrix4(@math.Matrix4::new().from_array(nums(a)))
    { "p": a, .. } => Plane(plane(a))
    { "t": String(n), .. } => Texture(tex(n))
    { "rtt": String(n), .. } => { let t = tex(n); t.is_render_target_texture = true; Texture(t) }
    { "array": Array(a), .. } => Array(a.map(uniform_value))
    { "s": Object(o), .. } => { let m = Map([]); for k, v in o { m[k] = uniform_value(v) }; Struct(m) }
    _ => abort("uniform")
  }
}
fn param(j : Json) -> @core.MaterialValue {
  match j {
    Null => Null
    True => Bool(true)
    False => Bool(false)
    Number(n, ..) => Number(n)
    String(s) => String(s)
    { "$undefined": _, .. } => Undefined
    { "$color": a, .. } => { let v = nums(a); Color(@math.Color::new(v[0], v[1], v[2])) }
    { "$v2": a, .. } => { let v = nums(a); Vector2(@math.Vector2::new(v[0], v[1])) }
    { "$euler": Array(a), .. } => Euler(@math.Euler::new(0.0, 0.0, 0.0).from_array(a))
    { "$texture": String(n), .. } => Texture(tex(n))
    { "$planes": Array(a), .. } => Planes(a.map(plane))
    { "$uniforms": Object(o), .. } => { let m = Map([]); for k, v in o { m[k] = @core.Uniform::new(uniform_value(v)) }; Uniforms(m) }
    { "$groups": Array(a), .. } => UniformsGroups(a.map(g => { guard g is String(n) else { abort("g") }; @core.UniformsGroup::new().set_name(n) }))
    { "$defines": Object(o), .. } => Defines(o)
    { "$ext": { "clipCullDistance": c, "multiDraw": d, .. }, .. } => Extensions({ clip_cull_distance: c is True, multi_draw: d is True })
    { "$attrs": Object(o), .. } => { let m = Map([]); for k, v in o { m[k] = nums(v) }; AttributeValues(m) }
    { "$user": o, .. } => Object(@core.JsValue::from_json(o))
    _ => abort("param " + j.stringify())
  }
}
fn apply(m : @core.Material, j : Json?) -> Unit {
  match j {
    Some(Object(o)) => {
      let values : Map[String, @core.MaterialValue] = Map([])
      for k, v in o { values[k] = param(v) }
      m.set_values(values~)
    }
    _ => ()
  }
}
fn jstr(o : Map[String, Json], k : String) -> String {
  guard o.get(k) is Some(String(s)) else { abort("jstr " + k) }
  s
}

/// Which uniform values of `a` and `b` are the same object.
fn shared(a : @core.Material, b : @core.Material) -> Json {
  let o = Map([])
  fn same(x : @core.UniformValue, y : @core.UniformValue) -> Bool {
    match (x, y) {
      (Vector2(p), Vector2(q)) => physical_equal(p, q)
      (Vector3(p), Vector3(q)) => physical_equal(p, q)
      (Vector4(p), Vector4(q)) => physical_equal(p, q)
      (Color(p), Color(q)) => physical_equal(p, q)
      (Quaternion(p), Quaternion(q)) => physical_equal(p, q)
      (Matrix3(p), Matrix3(q)) => physical_equal(p, q)
      (Matrix4(p), Matrix4(q)) => physical_equal(p, q)
      (Plane(p), Plane(q)) => physical_equal(p, q)
      (Texture(p), Texture(q)) => physical_equal(p, q)
      (Numbers(p), Numbers(q)) => physical_equal(p, q)
      (Array(p), Array(q)) => physical_equal(p, q)
      (Struct(p), Struct(q)) => physical_equal(p, q)
      (Texture(_), Null) => false
      _ => true // primitives
    }
  }
  for k, u in a.uniforms.unwrap() {
    if b.uniforms.unwrap().get(k) is Some(v) { o[k] = Json::boolean(same(u.value, v.value)) }
  }
  Json::object(o)
}

pub fn run(input : String) -> String {
  let parsed = @json.parse(input) catch { _ => abort("input") }
  guard parsed is Object(req) else { abort("input") }
  let op = jstr(req, "op")
  let result : Json = match op {
    "construct" => dump(construct(jstr(req, "cls")))
    "setvalues" => {
      let m = construct(jstr(req, "cls"))
      apply(m, req.get("params"))
      dump(m)
    }
    "copy" => {
      let s = construct(jstr(req, "source"))
      apply(s, req.get("params"))
      if req.get("index0") is Some(String(v)) && s.uniforms is Some(_) {
        s.index0_attribute_name = Some(v)
      }
      let t = construct(jstr(req, "target"))
      apply(t, req.get("targetParams"))
      ignore(t.copy(s))
      if t.uniforms is Some(_) && s.uniforms is Some(_) {
        { "dump": dump(t), "shared": shared(s, t) }
      } else {
        { "dump": dump(t) }
      }
    }
    "clone" => {
      let s = construct(jstr(req, "cls"))
      apply(s, req.get("params"))
      let c = s.clone()
      { "dump": dump(c), "sameUuid": Json::boolean(c.uuid == s.uuid), "dispose": Json::boolean({ let n = Ref(false); c.add_event_listener("dispose", _ => n.val = true); c.dispose(); n.val }) }
    }
    "tojson" => {
      let m = construct(jstr(req, "cls"))
      apply(m, req.get("params"))
      m.uuid = "mat"
      if req.get("meta") is Some(True) {
        let meta = @core.ToJsonMeta::new()
        let json = m.to_json(meta~)
        let keys = Json::array(meta.textures.keys().map(Json::string).collect())
        let images = Json::array(meta.images.keys().map(Json::string).collect())
        { "json": json, "textures": keys, "images": images }
      } else {
        { "json": m.to_json() }
      }
    }
    "fromjson" => {
      let m = construct(jstr(req, "cls"))
      let lib = Map([])
      if req.get("textures") is Some(Array(names)) {
        for n in names {
          guard n is String(n) else { abort("n") }
          let t = tex(n)
          lib[t.uuid] = t
        }
      }
      guard req.get("json") is Some(json) else { abort("json") }
      if req.get("noTextures") is Some(True) {
        ignore(m.from_json(json))
      } else {
        ignore(m.from_json(json, textures=lib))
      }
      dump(m)
    }
    "cachekey" => Json::string(construct(jstr(req, "cls")).custom_program_cache_key())
    "ids" => {
      let a = construct(jstr(req, "cls"))
      let b = construct(jstr(req, "cls"))
      jint(b.id - a.id)
    }
    "numericEdges" => {
      // NaN and Infinity through the alphaTest and physical setters
      let m = @core.MeshPhysicalMaterial::new()
      let nan = 0.0 / 0.0
      m.set_alpha_test(nan)
      m.set_sheen(nan)
      m.set_clearcoat(1.0 / 0.0)
      m.set_clearcoat(nan)
      m.set_alpha_test(-1.0)
      dump(m)
    }
    _ => abort("op")
  }
  result.stringify()
}

fn main { }
