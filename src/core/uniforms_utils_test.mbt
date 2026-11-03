// Tests for upstream src/renderers/shaders/UniformsUtils.js.

///|
fn uniforms_fixture() -> Map[String, @core.Uniform] {
  let texture = @core.Texture::new(mapping=@core.CubeReflectionMapping)
  Map([
    ("floatValue", @core.Uniform::new(Number(1.23))),
    ("intValue", @core.Uniform::new(Int(1))),
    ("boolValue", @core.Uniform::new(Bool(true))),
    ("colorValue", @core.Uniform::new(Color(@math.Color::from_hex(0xFF00FF)))),
    ("vector2Value", @core.Uniform::new(Vector2(@math.Vector2::new(1.0, 2.0)))),
    (
      "vector3Value",
      @core.Uniform::new(Vector3(@math.Vector3::new(1.0, 2.0, 3.0))),
    ),
    (
      "vector4Value",
      @core.Uniform::new(Vector4(@math.Vector4::new(1.0, 2.0, 3.0, 4.0))),
    ),
    ("matrix3Value", @core.Uniform::new(Matrix3(@math.Matrix3::new()))),
    ("matrix4Value", @core.Uniform::new(Matrix4(@math.Matrix4::new()))),
    (
      "quatValue",
      @core.Uniform::new(Quaternion(@math.Quaternion::new(1.0, 2.0, 3.0, 4.0))),
    ),
    ("arrayValue", @core.Uniform::new(Numbers([1.0, 2.0, 3.0, 4.0]))),
    ("textureValue", @core.Uniform::new(Texture(texture))),
  ])
}

///|
test "UniformsUtils cloneUniforms copies values" {
  let uniforms = uniforms_fixture()
  let clones = @core.UniformsUtils::clone(uniforms)
  guard clones.get("floatValue") is Some({ value: Number(1.23), }) else {
    fail("float")
  }
  guard clones.get("intValue") is Some({ value: Int(1), }) else { fail("int") }
  guard clones.get("boolValue") is Some({ value: Bool(true), }) else {
    fail("bool")
  }
  guard clones.get("colorValue") is Some({ value: Color(color), }) &&
    uniforms.get("colorValue") is Some({ value: Color(color0), }) else {
    fail("color")
  }
  assert_true(color.equals(color0))
  guard clones.get("vector3Value") is Some({ value: Vector3(v3), }) else {
    fail("v3")
  }
  assert_eq(v3.z, 3.0)
  guard clones.get("arrayValue") is Some({ value: Numbers(array), }) else {
    fail("array")
  }
  assert_eq(array, [1.0, 2.0, 3.0, 4.0])
  guard clones.get("textureValue") is Some({ value: Texture(texture), }) &&
    uniforms.get("textureValue") is Some({ value: Texture(texture0), }) else {
    fail("texture")
  }
  assert_eq(texture.source.uuid, texture0.source.uuid)
  assert_eq(texture.mapping, texture0.mapping)
}

///|
test "UniformsUtils cloneUniforms clones properties" {
  let uniforms = uniforms_fixture()
  let clones = @core.UniformsUtils::clone(uniforms)
  // Modify the originals
  uniforms["floatValue"].value = Number(123.0)
  guard uniforms.get("colorValue") is Some({ value: Color(color), }) else {
    fail("color")
  }
  color.r = 123.0
  guard uniforms.get("vector2Value") is Some({ value: Vector2(v2), }) else {
    fail("v2")
  }
  v2.x = 123.0
  guard uniforms.get("vector3Value") is Some({ value: Vector3(v3), }) else {
    fail("v3")
  }
  v3.x = 123.0
  guard uniforms.get("vector4Value") is Some({ value: Vector4(v4), }) else {
    fail("v4")
  }
  v4.x = 123.0
  guard uniforms.get("matrix3Value") is Some({ value: Matrix3(m3), }) else {
    fail("m3")
  }
  m3.elements[0] = 123.0
  guard uniforms.get("matrix4Value") is Some({ value: Matrix4(m4), }) else {
    fail("m4")
  }
  m4.elements[0] = 123.0
  guard uniforms.get("quatValue") is Some({ value: Quaternion(q), }) else {
    fail("q")
  }
  q.set_x(123.0)
  guard uniforms.get("arrayValue") is Some({ value: Numbers(array), }) else {
    fail("array")
  }
  array[0] = 123.0
  guard uniforms.get("textureValue") is Some({ value: Texture(texture), }) else {
    fail("t")
  }
  texture.mapping = @core.UVMapping
  guard clones.get("floatValue") is Some({ value: Number(1.23), }) else {
    fail("float")
  }
  guard clones.get("colorValue") is Some({ value: Color(color1), }) else {
    fail("color")
  }
  assert_true(color1.r != 123.0)
  guard clones.get("vector2Value") is Some({ value: Vector2(v2_1), }) else {
    fail("v2")
  }
  assert_eq(v2_1.x, 1.0)
  guard clones.get("vector3Value") is Some({ value: Vector3(v3_1), }) else {
    fail("v3")
  }
  assert_eq(v3_1.x, 1.0)
  guard clones.get("vector4Value") is Some({ value: Vector4(v4_1), }) else {
    fail("v4")
  }
  assert_eq(v4_1.x, 1.0)
  guard clones.get("matrix3Value") is Some({ value: Matrix3(m3_1), }) else {
    fail("m3")
  }
  assert_eq(m3_1.elements[0], 1.0)
  guard clones.get("matrix4Value") is Some({ value: Matrix4(m4_1), }) else {
    fail("m4")
  }
  assert_eq(m4_1.elements[0], 1.0)
  guard clones.get("quatValue") is Some({ value: Quaternion(q_1), }) else {
    fail("q")
  }
  assert_eq(q_1.x, 1.0)
  guard clones.get("arrayValue") is Some({ value: Numbers(array_1), }) else {
    fail("array")
  }
  assert_eq(array_1[0], 1.0)
  guard clones.get("textureValue") is Some({ value: Texture(texture_1), }) else {
    fail("t")
  }
  assert_eq(texture_1.mapping, @core.CubeReflectionMapping)
  // Texture source remains same
  assert_eq(texture.source.uuid, texture_1.source.uuid)
}

///|
test "UniformsUtils cloneUniforms clones arrays of objects" {
  let first = @math.Vector3::new(1.0, 2.0, 3.0)
  let second = @math.Vector3::new(4.0, 5.0, 6.0)
  let array : Array[@core.UniformValue] = [Vector3(first), Vector3(second)]
  let uniforms = Map([("vector3Array", @core.Uniform::new(Array(array)))])
  let clones = @core.UniformsUtils::clone(uniforms)
  // Cloned array is a different reference and contains different object references
  guard clones.get("vector3Array") is Some({ value: Array(cloned), }) else {
    fail("array")
  }
  assert_true(!physical_equal(cloned, array))
  guard cloned is [Vector3(a), Vector3(b)] else { fail("shape") }
  assert_true(!physical_equal(a, first))
  assert_true(!physical_equal(b, second))
  // Values are equal after cloning
  assert_true(a.equals(first))
  assert_true(b.equals(second))
  // Mutating the original does not affect the clone
  first.x = 123.0
  assert_true(!a.equals(first))
}

///|
test "UniformsUtils cloneUniforms skips render target textures" {
  let texture = @core.Texture::new(mapping=@core.CubeReflectionMapping)
  texture.is_render_target_texture = true
  let uniforms = Map([("textureValue", @core.Uniform::new(Texture(texture)))])
  let clones = @core.UniformsUtils::clone(uniforms)
  assert_true(clones.get("textureValue") is Some({ value: Null, }))
}

///|
test "UniformsUtils cloneUniforms shares what upstream shares" {
  let plane = @math.Plane::new()
  let inner : Array[@core.UniformValue] = [Number(1.0)]
  let uniforms = Map([
    ("plane", @core.Uniform::new(Plane(plane))),
    ("array", @core.Uniform::new(Array([Array(inner)]))),
  ])
  let clones = @core.UniformsUtils::clone(uniforms)
  guard clones.get("plane") is Some({ value: Plane(cloned), }) else {
    fail("plane")
  }
  assert_true(physical_equal(cloned, plane))
  guard clones.get("array") is Some({ value: Array([Array(nested)]), }) else {
    fail("array")
  }
  assert_true(physical_equal(nested, inner))
}

///|
test "UniformsUtils mergeUniforms clones and later entries win" {
  let color = @math.Color::from_hex(0x00ff00)
  let a = Map([
    ("x", @core.Uniform::new(Number(1.0))),
    ("y", @core.Uniform::new(Color(color))),
  ])
  let b = Map([("x", @core.Uniform::new(Number(2.0)))])
  let merged = @core.UniformsUtils::merge([a, b])
  assert_true(merged.get("x") is Some({ value: Number(2.0), }))
  guard merged.get("y") is Some({ value: Color(copy), }) else { fail("y") }
  assert_true(!physical_equal(copy, color))
}

///|
test "UniformsUtils cloneUniformsGroups" {
  let group = @core.UniformsGroup::new().set_name("g")
  let clones = @core.clone_uniforms_groups([group])
  assert_eq(clones[0].name, "g")
  assert_true(!physical_equal(clones[0], group))
}

///|
test "UniformsUtils getUnlitUniformColorSpace" {
  assert_eq(@core.get_unlit_uniform_color_space(None, "output"), "output")
  let target = @core.RenderTarget::new()
  assert_eq(
    @core.get_unlit_uniform_color_space(Some(target), "output"),
    @math.color_management.working_color_space,
  )
}
