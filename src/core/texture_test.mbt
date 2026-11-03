///|
fn uv(x : Double, y : Double) -> @math.Vector2 {
  @math.Vector2::new(x, y)
}

///|
test "Texture Extending" {
  let object = @core.Texture::new()
  let mut disposed = 0
  object.add_event_listener("dispose", event => {
    disposed += 1
    assert_true(event.target is Some(Texture(t)) && physical_equal(t, object)) catch {
      _ => panic()
    }
  })
  // dispose
  object.dispose()
  assert_eq(disposed, 1)
}

///|
test "Texture defaults" {
  let t = @core.Texture::new()
  assert_true(t.image() is NoImage)
  assert_eq(t.mapping, @core.UVMapping)
  assert_eq(t.wrap_s, @core.ClampToEdgeWrapping)
  assert_eq(t.wrap_t, @core.ClampToEdgeWrapping)
  assert_eq(t.mag_filter, @core.LinearFilter)
  assert_eq(t.min_filter, @core.LinearMipmapLinearFilter)
  assert_eq(t.format, @core.RGBAFormat)
  assert_eq(t.type_, @core.UnsignedByteType)
  assert_eq(t.anisotropy, 1)
  assert_eq(t.color_space, @core.NoColorSpace)
  assert_eq(t.unpack_alignment, 4)
  assert_true(t.flip_y)
  assert_true(t.generate_mipmaps)
  assert_false(t.is_array_texture)
  assert_eq(t.version, 0)
  assert_eq(t.width(), 0)
  assert_true(@core.Texture::new().id > t.id)
}

///|
test "Texture DEFAULT_MAPPING and DEFAULT_ANISOTROPY" {
  @core.texture_default_mapping.val = @core.CubeReflectionMapping
  @core.texture_default_anisotropy.val = 4
  let t = @core.Texture::new()
  @core.texture_default_mapping.val = @core.UVMapping
  @core.texture_default_anisotropy.val = 1
  assert_eq(t.mapping, @core.CubeReflectionMapping)
  assert_eq(t.anisotropy, 4)
}

///|
test "Texture isArrayTexture from image depth" {
  let image = @core.DataImage::new(width=2, height=3, depth=4)
  let t = @core.Texture::new(image=DataImage(image))
  assert_true(t.is_array_texture)
  assert_eq(t.width(), 2)
  assert_eq(t.height(), 3)
  assert_eq(t.depth(), 4)
  let flat = @core.DataImage::new(width=2, height=3, depth=1)
  assert_false(@core.Texture::new(image=DataImage(flat)).is_array_texture)
}

///|
test "Texture update ranges" {
  let t = @core.Texture::new()
  t.add_update_range(1, 2)
  assert_eq(t.update_ranges.length(), 1)
  assert_eq(t.update_ranges[0].count, 2)
  t.clear_update_ranges()
  assert_eq(t.update_ranges.length(), 0)
}

///|
test "Texture updateMatrix" {
  let t = @core.Texture::new()
  t.offset.x = 0.25
  t.repeat.y = 2
  t.rotation = 0.5
  t.update_matrix()
  let expected = @math.Matrix3::new().set_uv_transform(0.25, 0, 1, 2, 0.5, 0, 0)
  assert_true(t.matrix.equals(expected))
}

///|
test "Texture needsUpdate" {
  let t = @core.Texture::new()
  t.set_needs_update(false)
  assert_eq(t.version, 0)
  t.set_needs_update(true)
  assert_eq(t.version, 1)
  assert_eq(t.source.version, 1)
  t.set_needs_pmrem_update(false)
  assert_eq(t.pmrem_version, 0)
  t.set_needs_pmrem_update(true)
  assert_eq(t.pmrem_version, 1)
}

///|
test "Texture copy and clone" {
  let t = @core.Texture::new(wrap_s=@core.RepeatWrapping)
  t.name = "name"
  t.offset.x = 2
  t.matrix.elements[1] = 5
  t.internal_format = Some("RGBA8")
  t.user_data.set("a", @core.JsValue::of(1))
  t.mipmaps.push(NoImage)
  let c = t.clone()
  assert_eq(c.name, "name")
  assert_eq(c.wrap_s, @core.RepeatWrapping)
  assert_eq(c.offset.x, 2)
  assert_false(physical_equal(c.offset, t.offset))
  assert_eq(c.matrix.elements[1], 5)
  assert_eq(c.internal_format, Some("RGBA8"))
  assert_true(physical_equal(c.source, t.source))
  assert_false(physical_equal(c.mipmaps, t.mipmaps))
  assert_eq(c.mipmaps.length(), 1)
  assert_false(physical_equal(c.user_data, t.user_data))
  assert_eq(c.user_data.key_count(), 1)
  assert_eq(c.version, 1)
  assert_eq(t.source.version, 1)
  assert_false(c.uuid == t.uuid)
}

///|
test "Texture setValues" {
  let t = @core.Texture::new()
  let offset = uv(1, 2)
  let held = t.offset
  t.set_values(offset~, name="n", internal_format=Some("R8"), flip_y=false)
  assert_true(physical_equal(t.offset, held))
  assert_eq(t.offset.y, 2)
  assert_eq(t.name, "n")
  assert_eq(t.internal_format, Some("R8"))
  assert_false(t.flip_y)
  t.set_values(internal_format=None)
  assert_eq(t.internal_format, None)
  // wrapR does not exist on a plain Texture
  t.set_values(wrap_r=@core.RepeatWrapping)
  assert_eq(t.wrap_r, @core.ClampToEdgeWrapping)
}

///|
test "Texture transformUv" {
  let t = @core.Texture::new()
  t.flip_y = false
  // no effect outside UVMapping
  t.mapping = @core.CubeReflectionMapping
  assert_eq(t.transform_uv(uv(1.5, 1.5)).x, 1.5)
  t.mapping = @core.UVMapping
  // clamp
  let clamped = t.transform_uv(uv(1.5, -0.5))
  assert_eq(clamped.x, 1)
  assert_eq(clamped.y, 0)
  // repeat
  t.wrap_s = @core.RepeatWrapping
  t.wrap_t = @core.RepeatWrapping
  let repeated = t.transform_uv(uv(1.25, -0.25))
  assert_eq(repeated.x, 0.25)
  assert_eq(repeated.y, 0.75)
  // mirrored
  t.wrap_s = @core.MirroredRepeatWrapping
  t.wrap_t = @core.MirroredRepeatWrapping
  let mirrored = t.transform_uv(uv(1.25, 2.25))
  assert_eq(mirrored.x, 0.75)
  assert_eq(mirrored.y, 0.25)
  let negative = t.transform_uv(uv(-0.25, -1.25))
  assert_eq(negative.x, 0.25)
  assert_eq(negative.y, 0.75)
  // flipY
  t.flip_y = true
  assert_eq(t.transform_uv(uv(0.25, 0.25)).y, 0.75)
}

///|
test "Texture toJSON" {
  let t = @core.Texture::new()
  t.name = "x"
  guard t.to_json() is Object(json) else { fail("not an object") }
  assert_eq(json["uuid"], Json::string(t.uuid))
  assert_eq(json["image"], Json::string(t.source.uuid))
  assert_eq(json["name"], Json::string("x"))
  assert_eq(json["internalFormat"], Json::null())
  assert_eq(
    json["wrap"],
    Json::array([1001.0, 1001.0].map(v => Json::number(v))),
  )
  assert_eq(json.get("userData"), None)
  t.user_data.set("a", @core.JsValue::of(1))
  guard t.to_json() is Object(with_user_data) else { fail("not an object") }
  assert_true(with_user_data.contains("userData"))
}

///|
test "Texture toJSON caches in meta" {
  let meta : @core.ToJsonMeta = {
    geometries: {},
    materials: {},
    textures: {},
    images: {},
    shapes: {},
    skeletons: {},
    animations: {},
    nodes: {},
  }
  let t = @core.Texture::new()
  let first = t.to_json(meta~)
  assert_true(meta.textures.contains(t.uuid))
  assert_true(meta.images.contains(t.source.uuid))
  t.name = "changed"
  assert_eq(t.to_json(meta~), first)
}

///|
priv struct StorageTexture {
  copied : Ref[Int32]
}

///|
impl @core.TextureExtension for StorageTexture with fn type_name(_) {
  "StorageTexture"
}

///|
impl @core.TextureExtension for StorageTexture with fn construct(self) {
  @core.Texture::new().set_extension(self)
}

///|
impl @core.TextureExtension for StorageTexture with fn has_flag(_, flag) {
  flag == "isStorageTexture"
}

///|
impl @core.TextureExtension for StorageTexture with fn copy_from(self, _, _) {
  self.copied.val += 1
}

///|
impl @core.TextureExtension for StorageTexture with fn to_json(_, _, _, data) {
  data["storage"] = Json::boolean(true)
}

///|
test "Texture extension" {
  let extension = StorageTexture::{ copied: Ref(0), }
  let t = @core.Texture::new().set_extension(extension)
  let c = t.clone()
  assert_true(c.has_extension_flag("isStorageTexture"))
  assert_eq(extension.copied.val, 1)
  guard c.to_json() is Object(json) else { fail("not an object") }
  assert_eq(json["storage"], Json::boolean(true))
}
