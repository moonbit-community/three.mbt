// Port of upstream test/unit/src/extras/curves/ArcCurve.tests.js.

///|
test "ArcCurve extends Curve" {
  let object : @extras.Curve[@math.Vector2] = @extras.ArcCurve::new()
  ignore(object)
}

///|
test "ArcCurve instancing" {
  ignore(@extras.ArcCurve::new())
}

///|
test "ArcCurve type" {
  assert_eq(@extras.ArcCurve::new().type_, "ArcCurve")
}

///|
test "ArcCurve isArcCurve" {
  assert_true(@extras.ArcCurve::new().kind is Ellipse(_))
}
