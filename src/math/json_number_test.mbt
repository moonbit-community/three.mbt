///|
extern "js" fn json_number_test_infinity() -> Double = "() => Infinity"

///|
test "json_number writes non-finite numbers as null, as JSON.stringify" {
  let inf = json_number_test_infinity()
  inspect(@math.json_number(1.5).stringify(), content="1.5")
  inspect(@math.json_number(inf).stringify(), content="null")
  inspect(@math.json_number(-inf).stringify(), content="null")
  inspect(@math.json_number(0.0 / 0.0).stringify(), content="null")
  inspect(@math.json_numbers([1, inf, 2]).stringify(), content="[1,null,2]")
}

///|
test "json_to_number reads null as NaN" {
  inspect(@math.json_to_number(Json::number(2)), content="Some(2)")
  assert_true(@math.json_to_number(Json::null()).unwrap().is_nan())
  inspect(@math.json_to_number(Json::string("2")), content="None")
}

///|
test "an empty Box3 round-trips through its JSON text" {
  let box = @math.Box3::new()
  let json = box.to_json()
  inspect(
    json.stringify(),
    content="{\"min\":[null,null,null],\"max\":[null,null,null]}",
  )
  let back = @math.Box3::new().from_json(json)
  assert_true(back.min.x.is_nan())
  inspect(back.to_json().stringify(), content=json.stringify())
}

///|
test "Sphere, Plane and Euler accept null" {
  let inf = json_number_test_infinity()
  let sphere = @math.Sphere::new(radius=inf)
  inspect(
    sphere.to_json().stringify(),
    content="{\"radius\":null,\"center\":[0,0,0]}",
  )
  assert_true(@math.Sphere::new().from_json(sphere.to_json()).radius.is_nan())
  let plane = @math.Plane::new(constant=-inf)
  inspect(
    plane.to_json().stringify(),
    content="{\"normal\":[1,0,0],\"constant\":null}",
  )
  assert_true(@math.Plane::new().from_json(plane.to_json()).constant.is_nan())
  let euler = @math.Euler::new(inf, 0, 0)
  let array = euler.to_array()
  inspect(Json::array(array).stringify(), content="[null,0,0,\"XYZ\"]")
  assert_true(@math.Euler::new(0, 0, 0).from_array(array).x.is_nan())
}
