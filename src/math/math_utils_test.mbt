///|
/// Upstream's UUID regex, without the case-insensitive letters beyond hex.
fn math_utils_test_is_uuid(uuid : String) -> Bool {
  if uuid.length() != 36 {
    return false
  }
  for i in 0..<36 {
    let c = uuid.code_unit_at(i).to_int()
    if i == 8 || i == 13 || i == 18 || i == 23 {
      if c != '-'.to_int() {
        return false
      }
    } else if i == 14 {
      if c != '4'.to_int() {
        return false
      }
    } else if !((c >= '0'.to_int() && c <= '9'.to_int()) ||
      (c >= 'a'.to_int() && c <= 'f'.to_int())) {
      return false
    }
  }
  true
}

///|
test "MathUtils generateUUID" {
  let a = @math.generate_uuid()
  assert_true(math_utils_test_is_uuid(a))
}

///|
test "MathUtils generateUUID wraps like ToInt32" {
  // `Double::to_int` saturates, which would pin these bytes below 0x80.
  let mut high = false
  for _ in 0..<256 {
    let c = @math.generate_uuid().code_unit_at(6).to_int()
    if c >= '8'.to_int() {
      high = true
    }
  }
  assert_true(high)
}

///|
test "MathUtils clamp" {
  assert_eq(@math.clamp(0.5, 0.0, 1.0), 0.5)
  assert_eq(@math.clamp(0.0, 0.0, 1.0), 0.0)
  assert_eq(@math.clamp(-0.1, 0.0, 1.0), 0.0)
  assert_eq(@math.clamp(1.1, 0.0, 1.0), 1.0)
}

///|
test "MathUtils clamp keeps Math.min/Math.max NaN semantics" {
  let nan = 0.0 / 0.0
  assert_true(@math.clamp(nan, 0.0, 1.0).is_nan())
  assert_true(@math.clamp(5.0, nan, 1.0).is_nan())
}

///|
test "MathUtils euclideanModulo" {
  assert_true(@math.euclidean_modulo(6.0, 0.0).is_nan())
  assert_eq(@math.euclidean_modulo(6.0, 1.0), 0.0)
  assert_eq(@math.euclidean_modulo(6.0, 2.0), 0.0)
  assert_eq(@math.euclidean_modulo(6.0, 5.0), 1.0)
  assert_eq(@math.euclidean_modulo(6.0, 6.0), 0.0)
  assert_eq(@math.euclidean_modulo(6.0, 7.0), 6.0)
  assert_eq(@math.euclidean_modulo(-1.0, 3.0), 2.0)
  assert_eq(@math.euclidean_modulo(5.5, -2.0), -0.5)
}

///|
test "MathUtils mapLinear" {
  assert_eq(@math.map_linear(0.5, 0.0, 1.0, 0.0, 10.0), 5.0)
  assert_eq(@math.map_linear(0.0, 0.0, 1.0, 0.0, 10.0), 0.0)
  assert_eq(@math.map_linear(1.0, 0.0, 1.0, 0.0, 10.0), 10.0)
}

///|
test "MathUtils inverseLerp" {
  assert_eq(@math.inverse_lerp(1.0, 2.0, 1.5), 0.5)
  assert_eq(@math.inverse_lerp(1.0, 2.0, 2.0), 1.0)
  assert_eq(@math.inverse_lerp(1.0, 2.0, 1.0), 0.0)
  assert_eq(@math.inverse_lerp(1.0, 1.0, 1.0), 0.0)
}

///|
test "MathUtils lerp" {
  assert_eq(@math.lerp(1.0, 2.0, 0.0), 1.0)
  assert_eq(@math.lerp(1.0, 2.0, 1.0), 2.0)
  assert_eq(@math.lerp(1.0, 2.0, 0.4), 1.4)
}

///|
test "MathUtils damp" {
  assert_eq(@math.damp(1.0, 2.0, 0.0, 0.016), 1.0)
  assert_eq(@math.damp(1.0, 2.0, 10.0, 0.016), 1.1478562110337887)
}

///|
test "MathUtils pingpong" {
  assert_eq(@math.pingpong(2.5), 0.5)
  assert_eq(@math.pingpong(2.5, length=2.0), 1.5)
  assert_eq(@math.pingpong(-1.5), 0.5)
}

///|
test "MathUtils smoothstep" {
  assert_eq(@math.smoothstep(-1.0, 0.0, 2.0), 0.0)
  assert_eq(@math.smoothstep(0.0, 0.0, 2.0), 0.0)
  assert_eq(@math.smoothstep(0.5, 0.0, 2.0), 0.15625)
  assert_eq(@math.smoothstep(1.0, 0.0, 2.0), 0.5)
  assert_eq(@math.smoothstep(1.5, 0.0, 2.0), 0.84375)
  assert_eq(@math.smoothstep(2.0, 0.0, 2.0), 1.0)
  assert_eq(@math.smoothstep(3.0, 0.0, 2.0), 1.0)
}

///|
test "MathUtils smootherstep" {
  assert_eq(@math.smootherstep(-1.0, 0.0, 2.0), 0.0)
  assert_eq(@math.smootherstep(0.0, 0.0, 2.0), 0.0)
  assert_eq(@math.smootherstep(0.5, 0.0, 2.0), 0.103515625)
  assert_eq(@math.smootherstep(1.0, 0.0, 2.0), 0.5)
  assert_eq(@math.smootherstep(1.5, 0.0, 2.0), 0.896484375)
  assert_eq(@math.smootherstep(2.0, 0.0, 2.0), 1.0)
  assert_eq(@math.smootherstep(3.0, 0.0, 2.0), 1.0)
}

///|
test "MathUtils randInt" {
  let low = 1.0
  let high = 3.0
  let a = @math.rand_int(low, high)
  assert_true(a >= low)
  assert_true(a <= high)
}

///|
test "MathUtils randFloat" {
  let low = 1.0
  let high = 3.0
  let a = @math.rand_float(low, high)
  assert_true(a >= low)
  assert_true(a <= high)
}

///|
test "MathUtils randFloatSpread" {
  let a = @math.rand_float_spread(3.0)
  assert_true(a > -3.0 / 2.0)
  assert_true(a < 3.0 / 2.0)
}

///|
test "MathUtils seededRandom matches upstream" {
  // Golden values from upstream MathUtils.js. Each row is the value of
  // `seededRandom( s )` then of two further `seededRandom()` calls.
  let rows : Array[(Double, Double, Double, Double)] = [
    (1.0, 0.6270739405881613, 0.002735721180215478, 0.5274470399599522),
    (0.0, 0.26642920868471265, 0.0003297457005828619, 0.2232720274478197),
    (-1.0, 0.8964226141106337, 0.189478256739676, 0.7156526781618595),
    (0.5, 0.26642920868471265, 0.0003297457005828619, 0.2232720274478197),
    (2147483648.0, 0.8205775609239936, 0.4481089550536126, 0.7836112855002284),
    (4294967303.0, 0.011704753153026104, 0.06195825757458806, 0.97690763277933),
    (
      9007199254740992.0, 0.8964226141106337, 0.04910933715291321, 0.09994429117068648,
    ),
    (1.0e300, 0.0, 0.0, 0.0),
  ]
  for row in rows {
    let (seed, r0, r1, r2) = row
    assert_eq(@math.seeded_random(s=seed), r0)
    assert_eq(@math.seeded_random(), r1)
    assert_eq(@math.seeded_random(), r2)
  }
}

///|
test "MathUtils degToRad" {
  assert_eq(@math.deg_to_rad(0.0), 0.0)
  assert_eq(@math.deg_to_rad(90.0), @cmath.PI / 2.0)
  assert_eq(@math.deg_to_rad(180.0), @cmath.PI)
  assert_eq(@math.deg_to_rad(360.0), @cmath.PI * 2.0)
}

///|
test "MathUtils radToDeg" {
  assert_eq(@math.rad_to_deg(0.0), 0.0)
  assert_eq(@math.rad_to_deg(@cmath.PI / 2.0), 90.0)
  assert_eq(@math.rad_to_deg(@cmath.PI), 180.0)
  assert_eq(@math.rad_to_deg(@cmath.PI * 2.0), 360.0)
}

///|
test "MathUtils DEG2RAD and RAD2DEG are the upstream expressions" {
  assert_eq(@math.DEG2RAD, @cmath.PI / 180.0)
  assert_eq(@math.RAD2DEG, 180.0 / @cmath.PI)
}

///|
test "MathUtils isPowerOfTwo" {
  assert_eq(@math.is_power_of_two(0.0), false)
  assert_eq(@math.is_power_of_two(1.0), true)
  assert_eq(@math.is_power_of_two(2.0), true)
  assert_eq(@math.is_power_of_two(3.0), false)
  assert_eq(@math.is_power_of_two(4.0), true)
  assert_eq(@math.is_power_of_two(@cmath.pow(2.0, 40.0)), true)
  assert_eq(@math.is_power_of_two(3.0 * @cmath.pow(2.0, 32.0)), false)
  assert_eq(@math.is_power_of_two(1.0 / 0.0), false)
  assert_eq(@math.is_power_of_two(0.5), false)
}

///|
test "MathUtils ceilPowerOfTwo" {
  assert_eq(@math.ceil_power_of_two(1.0), 1.0)
  assert_eq(@math.ceil_power_of_two(3.0), 4.0)
  assert_eq(@math.ceil_power_of_two(4.0), 4.0)
}

///|
test "MathUtils floorPowerOfTwo" {
  assert_eq(@math.floor_power_of_two(1.0), 1.0)
  assert_eq(@math.floor_power_of_two(3.0), 2.0)
  assert_eq(@math.floor_power_of_two(4.0), 4.0)
}

///|
test "MathUtils setQuaternionFromProperEuler" {
  let q = @math.Quaternion::new(0.0, 0.0, 0.0, 1.0)
  let mut calls = 0
  ignore(q.on_change(() => calls += 1))
  @math.set_quaternion_from_proper_euler(q, 0.0, 0.0, 0.0, "XYX")
  assert_eq(q.w, 1.0)
  assert_eq(calls, 1)
  // an unknown order only warns
  @math.set_quaternion_from_proper_euler(q, 1.0, 2.0, 3.0, "ABC")
  assert_eq(q.w, 1.0)
  assert_eq(calls, 1)
}

///|
test "MathUtils normalize/denormalize" {
  assert_eq(@math.normalize(0.5, Uint8Array), 128.0)
  assert_eq(@math.normalize(-0.5, Int8Array), -63.0)
  assert_eq(@math.normalize(0.5 / 255.0, Uint8Array), 1.0)
  assert_eq(@math.normalize(0.25, Float32Array), 0.25)
  assert_eq(@math.denormalize(-128.0, Int8Array), -1.0)
  assert_eq(@math.denormalize(255.0, Uint8Array), 1.0)
  assert_eq(@math.denormalize(0.25, Float32Array), 0.25)
}

///|
test "MathUtils getNormalizationScale" {
  assert_eq(@math.get_normalization_scale(Uint32Array), Some(4294967295.0))
  assert_eq(@math.get_normalization_scale(Uint16Array), Some(65535.0))
  assert_eq(@math.get_normalization_scale(Uint8Array), Some(255.0))
  assert_eq(@math.get_normalization_scale(Uint8ClampedArray), Some(255.0))
  assert_eq(@math.get_normalization_scale(Int32Array), Some(2147483647.0))
  assert_eq(@math.get_normalization_scale(Int16Array), Some(32767.0))
  assert_eq(@math.get_normalization_scale(Int8Array), Some(127.0))
  assert_eq(@math.get_normalization_scale(Float32Array), None)
  assert_eq(@math.get_normalization_scale(Other), None)
}

///|
test "panic MathUtils normalize invalid component type" {
  ignore(@math.normalize(1.0, Other))
}

///|
test "panic MathUtils denormalize invalid component type" {
  ignore(@math.denormalize(1.0, Other))
}
