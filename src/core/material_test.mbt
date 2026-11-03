// Tests for upstream src/materials/Material.js. Key lists come from upstream's toJSON.

///|
let material_json_base_keys : String = "metadata,uuid,type,blending,side,shadowSide,vertexColors,opacity,transparent,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,colorWrite,clipIntersection,clipShadows,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaTest,alphaHash,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,visible,toneMapped,name"

///|
fn json_keys(json : Json) -> String {
  guard json is Object(object) else { abort("not an object") }
  let keys = []
  for key, _ in object {
    keys.push(key)
  }
  keys.join(",")
}

///|
test "Material Extending" {
  let object = @core.Material::new()
  let count = Ref(0)
  object.add_event_listener("x", _ => count.val += 1)
  object.dispatch_event(@core.Event::new("x"))
  assert_eq(count.val, 1)
}

///|
test "Material Instancing" {
  let object = @core.Material::new()
  let other = @core.Material::new()
  assert_eq(other.id, object.id + 1)
  assert_true(object.uuid != other.uuid)
}

///|
test "Material type" {
  let object = @core.Material::new()
  assert_eq(object.type_, "Material")
  assert_true(object.material_type is Material)
}

///|
test "Material dispose" {
  let object = @core.Material::new()
  let count = Ref(0)
  object.add_event_listener("dispose", event => {
    count.val += 1
    assert_true(event.target is Some(Material(_))) catch {
      _ => abort("target")
    }
  })
  object.dispose()
  assert_eq(count.val, 1)
}

///|
test "Material defaults" {
  let object = @core.Material::new()
  assert_eq(object.blending, @core.NormalBlending)
  assert_eq(object.side, @core.FrontSide)
  assert_eq(object.blend_src, @core.SrcAlphaFactor)
  assert_eq(object.blend_dst, @core.OneMinusSrcAlphaFactor)
  assert_eq(object.depth_func, @core.LessEqualDepth)
  assert_eq(object.stencil_write_mask, 0xff)
  assert_eq(object.stencil_func, @core.AlwaysStencilFunc)
  assert_eq(object.stencil_fail, @core.KeepStencilOp)
  assert_eq(object.opacity, 1.0)
  assert_true(object.tone_mapped)
  assert_true(object.color is None)
  assert_true(object.map is None)
  assert_true(object.defines is None)
}

///|
test "Material alphaTest bumps version when crossing zero" {
  let object = @core.Material::new()
  object.set_alpha_test(0.5)
  assert_eq(object.alpha_test(), 0.5)
  assert_eq(object.version, 1)
  object.set_alpha_test(0.25)
  assert_eq(object.version, 1)
  object.set_alpha_test(0.0)
  assert_eq(object.version, 2)
}

///|
test "Material needsUpdate" {
  let object = @core.Material::new()
  object.set_needs_update(false)
  assert_eq(object.version, 0)
  object.set_needs_update(true)
  assert_eq(object.version, 1)
}

///|
test "Material customProgramCacheKey" {
  let object = @core.Material::new()
  assert_eq(
    object.custom_program_cache_key(),
    "onBeforeCompile( /* shaderobject, renderer */ ) {}",
  )
  object.on_before_compile = Some((_, _) => ())
  assert_true(object.custom_program_cache_key().contains("=>"))
  object.custom_program_cache_key = Some(() => "key")
  assert_eq(object.custom_program_cache_key(), "key")
}

///|
test "Material setValues assigns by upstream name" {
  let object = @core.MeshBasicMaterial::new()
  object.set_values()
  let planes = [@math.Plane::new()]
  object.set_values(
    values=Map([
      ("opacity", Number(0.5)),
      ("vertexColors", Bool(true)),
      ("side", Number(2.0)),
      ("name", String("n")),
      ("alphaTest", Number(0.5)),
      ("clippingPlanes", Planes(planes)),
      ("wireframeLinecap", String("butt")),
      ("shadowSide", Number(1.0)),
    ]),
  )
  assert_eq(object.opacity, 0.5)
  assert_true(object.vertex_colors)
  assert_eq(object.side, 2)
  assert_eq(object.name, "n")
  assert_eq(object.version, 1)
  assert_true(physical_equal(object.clipping_planes.unwrap(), planes))
  assert_eq(object.wireframe_linecap, Some("butt"))
  assert_eq(object.shadow_side, Some(1))
  object.set_values(values=Map([("shadowSide", Null)]))
  assert_eq(object.shadow_side, None)
}

///|
test "Material setValues sets colors in place" {
  let object = @core.MeshPhongMaterial::new()
  let color = object.color.unwrap()
  object.set_values(values=Map([("color", Number(0xff0000.0))]))
  assert_true(physical_equal(object.color.unwrap(), color))
  assert_eq(color.get_hex(), 0xff0000)
  object.set_values(values=Map([("color", String("#00ff00"))]))
  assert_eq(color.get_hex(), 0x00ff00)
  object.set_values(
    values=Map([("color", Color(@math.Color::from_hex(0x0000ff)))]),
  )
  assert_eq(color.get_hex(), 0x0000ff)
  // `Color.set( null )` does nothing
  object.set_values(values=Map([("color", Null)]))
  assert_eq(color.get_hex(), 0x0000ff)
  object.set_values(values=Map([("blendColor", Number(0x112233.0))]))
  assert_eq(object.blend_color.get_hex(), 0x112233)
}

///|
test "Material setValues copies vectors and eulers in place" {
  let object = @core.MeshPhongMaterial::new()
  let scale = object.normal_scale.unwrap()
  let rotation = object.env_map_rotation.unwrap()
  object.set_values(
    values=Map([
      ("normalScale", Vector2(@math.Vector2::new(2.0, 3.0))),
      ("envMapRotation", Euler(@math.Euler::new(1.0, 2.0, 3.0))),
    ]),
  )
  assert_true(physical_equal(object.normal_scale.unwrap(), scale))
  assert_eq(scale.y, 3.0)
  assert_true(physical_equal(object.env_map_rotation.unwrap(), rotation))
  assert_eq(rotation.z, 3.0)
}

///|
test "Material setValues skips what the class does not have" {
  let object = @core.PointsMaterial::new()
  object.set_values(
    values=Map([
      // `undefined` properties
      ("roughness", Number(0.5)),
      ("linewidth", Number(2.0)),
      ("needsUpdate", Bool(true)),
      ("notAProperty", Number(1.0)),
      // `undefined` values
      ("size", Undefined),
    ]),
  )
  assert_eq(object.roughness, None)
  assert_eq(object.linewidth, None)
  assert_eq(object.version, 0)
  assert_eq(object.size, Some(1.0))
}

///|
test "Material setValues tells null properties from undefined ones" {
  let shader = @core.ShaderMaterial::new()
  shader.set_values(
    values=Map([
      // upstream initializes this to `undefined`
      ("index0AttributeName", String("position")),
      ("glslVersion", String("300 es")),
    ]),
  )
  assert_eq(shader.index0_attribute_name, None)
  assert_eq(shader.glsl_version, Some("300 es"))
  let physical = @core.MeshPhysicalMaterial::new()
  physical.set_values(
    values=Map([("reflectivity", Number(1.0)), ("clearcoat", Number(1.0))]),
  )
  assert_true(approx(physical.ior.unwrap(), 1.4 / 0.6))
  assert_eq(physical.clearcoat(), Some(1.0))
  assert_eq(physical.version, 1)
  let standard = @core.MeshStandardMaterial::new()
  standard.set_values(
    values=Map([("reflectivity", Number(1.0)), ("clearcoat", Number(1.0))]),
  )
  assert_eq(standard.reflectivity(), None)
  assert_eq(standard.clearcoat(), None)
}

///|
test "Material copy copies blending and stencil properties" {
  let source = @core.Material::new()
  source.name = "s"
  source.blending = @core.CustomBlending
  source.blend_src = @core.OneFactor
  source.blend_dst_alpha = Some(@core.ZeroFactor)
  ignore(source.blend_color.set_hex(0x123456))
  source.blend_alpha = 0.25
  source.stencil_write = true
  source.stencil_ref = 3
  source.stencil_func_mask = 0x0f
  source.stencil_z_pass = @core.ReplaceStencilOp
  source.polygon_offset_units = 2.0
  source.shadow_side = Some(1)
  source.precision = Some("lowp")
  source.set_alpha_test(0.5)
  let object = @core.Material::new().copy(source)
  assert_eq(object.name, "s")
  assert_eq(object.blending, @core.CustomBlending)
  assert_eq(object.blend_src, @core.OneFactor)
  assert_eq(object.blend_dst_alpha, Some(@core.ZeroFactor))
  assert_true(!physical_equal(object.blend_color, source.blend_color))
  assert_eq(object.blend_color.get_hex(), 0x123456)
  assert_eq(object.blend_alpha, 0.25)
  assert_true(object.stencil_write)
  assert_eq(object.stencil_ref, 3)
  assert_eq(object.stencil_func_mask, 0x0f)
  assert_eq(object.stencil_z_pass, @core.ReplaceStencilOp)
  assert_eq(object.polygon_offset_units, 2.0)
  assert_eq(object.shadow_side, Some(1))
  assert_eq(object.precision, Some("lowp"))
  assert_eq(object.alpha_test(), 0.5)
  assert_eq(object.version, 1)
}

///|
test "Material copy clones planes and userData" {
  let source = @core.Material::new()
  source.clipping_planes = Some([@math.Plane::new(constant=2.0)])
  source.user_data.set("a", @core.JsValue::of(1.0))
  let object = @core.Material::new().copy(source)
  let plane = object.clipping_planes.unwrap()[0]
  assert_true(!physical_equal(plane, source.clipping_planes.unwrap()[0]))
  assert_eq(plane.constant, 2.0)
  assert_true(!object.user_data.strict_equal(source.user_data))
  assert_eq(object.user_data.key_count(), 1)
  source.clipping_planes = None
  assert_true(object.copy(source).clipping_planes is None)
}

///|
test "Material copy keeps subclass colors apart and shares textures" {
  let source = @core.MeshBasicMaterial::new()
  ignore(source.color.unwrap().set_hex(0x445566))
  source.map = Some(@core.Texture::new())
  let object = @core.MeshBasicMaterial::new().copy(source)
  assert_true(!physical_equal(object.color.unwrap(), source.color.unwrap()))
  assert_eq(object.color.unwrap().get_hex(), 0x445566)
  assert_true(physical_equal(object.map.unwrap(), source.map.unwrap()))
}

///|
test "Material copy reads the reflectivity accessor of a physical source" {
  let object = @core.MeshBasicMaterial::new()
  ignore(object.copy(@core.MeshPhysicalMaterial::new()))
  assert_eq(object.reflectivity, Some(0.5))
}

///|
test "Material toJSON metadata and fields" {
  let object = @core.MeshStandardMaterial::new()
  object.name = "m"
  object.roughness = Some(0.25)
  guard object.to_json()
    is {
      "metadata": {
        "version": Number(version, ..),
        "type": "Material",
        "generator": "Material.toJSON",
        ..
      },
      "type": "MeshStandardMaterial",
      "name": "m",
      "roughness": Number(roughness, ..),
      "color": Number(color, ..),
      "shadowSide": Null,
      ..
    } else {
    fail("shape")
  }
  assert_eq(version, 4.7)
  assert_eq(roughness, 0.25)
  assert_eq(color, 0xffffff.0)
}

///|
test "Material toJSON writes maps with their dependent properties" {
  let object = @core.MeshStandardMaterial::new()
  let texture = @core.Texture::new()
  object.normal_map = Some(texture)
  object.env_map = Some(texture)
  guard object.to_json()
    is {
      "normalMap": String(uuid),
      "normalMapType": Number(_, ..),
      "normalScale": [Number(1.0, ..), Number(1.0, ..)],
      "envMap": String(env_map),
      "textures": [_],
      "images": [_],
      ..
    } else {
    fail("shape")
  }
  assert_eq(uuid, texture.uuid)
  assert_eq(env_map, texture.uuid)
}

///|
test "Material toJSON leaves textures in meta when given one" {
  let object = @core.MeshBasicMaterial::new()
  let texture = @core.Texture::new()
  object.map = Some(texture)
  let meta = @core.ToJsonMeta::new()
  let json = object.to_json(meta~)
  guard json is { "map": String(uuid), .. } else { fail("shape") }
  assert_eq(uuid, texture.uuid)
  assert_true(meta.textures.contains(texture.uuid))
  assert_true(json_keys(json).contains("textures") == false)
}

///|
test "Material toJSON keeps userData and clipping planes" {
  let object = @core.Material::new()
  object.user_data.set("a", @core.JsValue::of(1.0))
  object.clipping_planes = Some([@math.Plane::new(constant=2.0)])
  guard object.to_json()
    is {
      "userData": { "a": Number(1.0, ..), .. },
      "clippingPlanes": [{ "constant": Number(2.0, ..), .. }],
      ..
    } else {
    fail("shape")
  }
}

///|
test "Material fromJSON round trip" {
  let source = @core.MeshStandardMaterial::new()
  source.name = "m"
  source.opacity = 0.5
  source.roughness = Some(0.25)
  source.side = @core.DoubleSide
  source.blend_src_alpha = Some(@core.OneFactor)
  source.set_alpha_test(0.5)
  ignore(source.color.unwrap().set_hex(0xff0000))
  let texture = @core.Texture::new()
  source.normal_map = Some(texture)
  source.normal_scale = Some(@math.Vector2::new(2.0, 3.0))
  ignore(source.env_map_rotation.unwrap().set(1.0, 0.0, 0.0))
  let object = @core.MeshStandardMaterial::new().from_json(
    source.to_json(),
    textures=Map([(texture.uuid, texture)]),
  )
  assert_eq(object.uuid, source.uuid)
  assert_eq(object.name, "m")
  assert_eq(object.opacity, 0.5)
  assert_eq(object.roughness, Some(0.25))
  assert_eq(object.side, @core.DoubleSide)
  assert_eq(object.blend_src_alpha, Some(@core.OneFactor))
  assert_eq(object.alpha_test(), 0.5)
  assert_eq(object.color.unwrap().get_hex(), 0xff0000)
  assert_true(physical_equal(object.normal_map.unwrap(), texture))
  assert_eq(object.normal_scale.unwrap().y, 3.0)
  assert_eq(object.env_map_rotation.unwrap().x, 1.0)
}

///|
test "Material fromJSON legacy forms" {
  let object = @core.MeshPhysicalMaterial::new()
  ignore(
    object.from_json(
      {
        "vertexColors": 2.0,
        "normalScale": 3.0,
        "iridescenceThicknessRange": [10.0, 20.0],
        "map": "unknown",
      },
      textures=Map([]),
    ),
  )
  assert_true(object.vertex_colors)
  assert_eq(object.normal_scale.unwrap().x, 3.0)
  assert_eq(object.iridescence_thickness_minimum, Some(10.0))
  assert_eq(object.iridescence_thickness_maximum, Some(20.0))
  assert_true(object.map is None)
}

///|
struct MaterialTestExtension {
  log : Array[String]
}

///|
impl @core.MaterialExtension for MaterialTestExtension with fn type_name(_) {
  "TestMaterial"
}

///|
impl @core.MaterialExtension for MaterialTestExtension with fn construct(self) {
  @core.Material::new().set_extension(self)
}

///|
impl @core.MaterialExtension for MaterialTestExtension with fn has_flag(_, flag) {
  flag == "isNodeMaterial"
}

///|
impl @core.MaterialExtension for MaterialTestExtension with fn copy_from(
  self,
  _,
  _,
) {
  self.log.push("copy")
}

///|
impl @core.MaterialExtension for MaterialTestExtension with fn to_json(
  _,
  _,
  _,
  data,
) {
  data["extra"] = Json::boolean(true)
}

///|
impl @core.MaterialExtension for MaterialTestExtension with fn custom_program_cache_key(
  _,
  _,
) {
  Some("extension")
}

///|
impl @core.MaterialExtension for MaterialTestExtension with fn dispose(self, _) {
  self.log.push("dispose")
}

///|
test "Material extension reaches every override" {
  let extension = { log: [], }
  let object = @core.Material::new().set_extension(extension)
  assert_eq(object.type_, "TestMaterial")
  assert_true(object.is_node_material())
  assert_eq(object.custom_program_cache_key(), "extension")
  // An instance override wins over the subclass method, as in JS.
  object.custom_program_cache_key = Some(() => "instance")
  assert_eq(object.custom_program_cache_key(), "instance")
  object.custom_program_cache_key = None
  let cloned = object.clone()
  assert_eq(cloned.type_, "TestMaterial")
  assert_eq(extension.log, ["copy"])
  assert_true(object.to_json() is { "extra": True, "type": "TestMaterial", .. })
  object.dispose()
  assert_eq(extension.log, ["copy", "dispose"])
}
