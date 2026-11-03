///|
test "LightProbe Extending" {
  assert_true(@core.LightProbe::new().is_light())
}

///|
test "LightProbe isLightProbe" {
  assert_true(@core.LightProbe::new().as_light().kind is LightProbe(_))
}

///|
test "LightProbe type" {
  assert_eq(@core.LightProbe::new().type_, "LightProbe")
}

///|
test "LightProbe keeps sh by reference" {
  let sh = @math.SphericalHarmonics3::new()
  guard @core.LightProbe::new(sh~, intensity=2.0).as_light()
    is { kind: LightProbe(probe), intensity, .. } else {
    fail("not a probe")
  }
  assert_true(physical_equal(probe.sh, sh))
  assert_eq(intensity, 2.0)
}

///|
test "LightProbe copy and toJSON" {
  let sh = @math.SphericalHarmonics3::new()
  ignore(sh.coefficients[1].set(1, 2, 3))
  let light = @core.LightProbe::new(sh~)
  let cloned = light.clone()
  guard cloned.as_light().kind is LightProbe(probe) else { fail("not a probe") }
  assert_false(physical_equal(probe.sh, sh))
  assert_true(probe.sh.equals(sh))
  let object = light_test_object(cloned)
  guard object.get("sh") is Some(Array(values)) else { fail("no sh") }
  assert_eq(values.length(), 27)
  assert_true(values[3] is Number(1.0, ..))
}
