// Port of upstream test/unit/src/extras/DataUtils.tests.js.

///|
test "DataUtils toHalfFloat" {
  assert_eq(@extras.to_half_float(0.0), 0.0)
  assert_eq(@extras.to_half_float(100000.0), 31743.0)
  assert_eq(@extras.to_half_float(-100000.0), 64511.0)
  assert_eq(@extras.to_half_float(65504.0), 31743.0)
  assert_eq(@extras.to_half_float(-65504.0), 64511.0)
  assert_eq(@extras.to_half_float(test_pi()), 16968.0)
  assert_eq(@extras.to_half_float(-test_pi()), 49736.0)
  assert_eq(@extras.DataUtils::to_half_float(test_pi()), 16968.0)
}

///|
test "DataUtils fromHalfFloat" {
  assert_eq(@extras.from_half_float(0.0), 0.0)
  assert_eq(@extras.from_half_float(31744.0), 1.0 / 0.0)
  assert_eq(@extras.from_half_float(64512.0), -1.0 / 0.0)
  assert_eq(@extras.from_half_float(31743.0), 65504.0)
  assert_eq(@extras.from_half_float(64511.0), -65504.0)
  assert_eq(@extras.from_half_float(16968.0), 3.140625)
  assert_eq(@extras.from_half_float(49736.0), -3.140625)
  assert_eq(@extras.DataUtils::from_half_float(16968.0), 3.140625)
}
