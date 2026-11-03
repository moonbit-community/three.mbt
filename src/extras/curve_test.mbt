// Port of upstream test/unit/src/extras/core/Curve.tests.js, plus what it leaves as todo.

///|
test "Curve instancing" {
  let object : @extras.Curve[@math.Vector2] = @extras.Curve::new()
  assert_true(object.kind is Abstract)
}

///|
test "Curve type" {
  let object : @extras.Curve[@math.Vector3] = @extras.Curve::new()
  assert_eq(object.type_, "Curve")
}

///|
test "Curve abstract get_point warns and gives nothing" {
  let object : @extras.Curve[@math.Vector2] = @extras.Curve::new()
  assert_true(object.get_point_or_null(0.5) is None)
}

///|
test "Curve to_json keeps upstream's key order" {
  let curve = @extras.QuadraticBezierCurve3::new(
    v0=vec3(1.0, 2.0, 3.0),
    v1=vec3(4.0, 5.0, 6.0),
    v2=vec3(7.0, 8.0, 9.5),
  )
  assert_eq(
    curve.to_json().stringify(),
    "{\"metadata\":{\"version\":4.7,\"type\":\"Curve\",\"generator\":\"Curve.toJSON\"},\"arcLengthDivisions\":200,\"type\":\"QuadraticBezierCurve3\",\"v0\":[1,2,3],\"v1\":[4,5,6],\"v2\":[7,8,9.5]}",
  )
}

///|
test "Curve from_json restores every class" {
  let spline = @extras.SplineCurve::new(points=[
    vec2(0.0, 0.0),
    vec2(1.0, 2.0),
    vec2(3.0, 1.0),
  ])
  spline.arc_length_divisions = 17
  let restored = @extras.SplineCurve::new().from_json(spline.to_json())
  assert_eq(restored.arc_length_divisions, 17)
  assert_exact_points(restored.get_points(), spline.get_points())
  let catmull = @extras.CatmullRomCurve3::new(
    points=[vec3(0.0, 0.0, 0.0), vec3(1.0, 0.0, 0.0), vec3(1.0, 1.0, 0.0)],
    closed=true,
    curve_type="catmullrom",
    tension=0.25,
  )
  let restored = @extras.CatmullRomCurve3::new().from_json(catmull.to_json())
  assert_eq(restored.to_json().stringify(), catmull.to_json().stringify())
}

///|
test "Curve clone is deep and resets the cache" {
  let v1 = vec2(0.0, 0.0)
  let curve = @extras.LineCurve::new(v1~, v2=vec2(1.0, 0.0))
  curve.arc_length_divisions = 8
  ignore(curve.get_length())
  let clone = curve.clone()
  assert_eq(clone.type_, "LineCurve")
  assert_eq(clone.arc_length_divisions, 8)
  assert_true(clone.cache_arc_lengths is None)
  ignore(v1.set(5.0, 5.0))
  assert_eq(clone.get_point(0.0).to_array(), [0.0, 0.0])
}

///|
test "Curve arc lengths are cached until needs_update" {
  let v2 = vec2(1.0, 0.0)
  let curve = @extras.LineCurve::new(v2~)
  let lengths = curve.get_lengths()
  assert_true(physical_equal(lengths, curve.get_lengths()))
  ignore(v2.set(2.0, 0.0))
  assert_eq(curve.get_length(), lengths[200])
  curve.update_arc_lengths()
  assert_num(curve.get_length(), 2.0)
}

///|
test "Curve::extended overrides get_point, as a subclass of Curve" {
  let curve : @extras.Curve[@math.Vector3] = @extras.Curve::extended(
    "CustomSinCurve",
    (_, t, target) => target.set(t, @cmath.sin(t * test_pi()), 0.0),
    to_json=(_, data) => data["scale"] = Json::number(2.0),
  )
  assert_eq(curve.type_, "CustomSinCurve")
  assert_num_list(curve.get_point(0.5).to_array(), [0.5, 1.0, 0.0])
  assert_eq(curve.get_points(divisions=2).length(), 3)
  let frames = curve.compute_frenet_frames(4)
  assert_eq(frames.tangents.length(), 5)
  guard curve.to_json() is Object(data) else { fail("not an object") }
  assert_eq(data.get("scale"), Some(Json::number(2.0)))
  assert_eq(curve.clone().type_, "CustomSinCurve")
}

///|
test "Curve::compute_frenet_frames on a 2D curve gives upstream's NaN z" {
  let frames = @extras.LineCurve::new(v2=vec2(3.0, 4.0)).compute_frenet_frames(
    1,
  )
  assert_eq(frames.tangents[0].x, 3.0)
  assert_eq(frames.tangents[0].y, 4.0)
  assert_true(frames.tangents[0].z.is_nan())
}
