///|
test "Uniform Instancing" {
  let b = vec3(test_x, test_y, test_z)
  let a = @core.Uniform::new(Number(5))
  assert_true(a.value is Number(5))
  let a = @core.Uniform::new(Vector3(b))
  guard a.value is Vector3(value) else { fail("not a Vector3") }
  assert_true(value.equals(b))
}

///|
test "Uniform clone" {
  let a = @core.Uniform::new(Number(23))
  let b = a.clone()
  assert_true(b.value is Number(23))
  let v = vec3(1, 2, 3)
  let a = @core.Uniform::new(Vector3(v))
  let b = a.clone()
  guard b.value is Vector3(value) else { fail("not a Vector3") }
  assert_true(value.equals(v))
  assert_false(physical_equal(value, v))
}

///|
extern "js" fn test_clonable() -> @core.JsValue =
  #|() => ({ n: 1, clone() { return { n: 2 }; } })

///|
test "Uniform clone of an opaque value calls its clone" {
  let a = @core.Uniform::new(Other(test_clonable()))
  guard a.clone().value is Other(value) else { fail("not Other") }
  let n : Double = value.get("n").cast()
  assert_eq(n, 2)
  let plain = @core.JsValue::object()
  guard @core.Uniform::new(Other(plain)).clone().value is Other(same) else {
    fail("not Other")
  }
  assert_true(same.strict_equal(plain))
}
