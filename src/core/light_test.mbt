///|
/// A copy of `json` without the keys that differ between a light and its copy.
fn light_test_strip_ids(json : Json) -> Json {
  match json {
    Object(map) => {
      let result : Map[String, Json] = Map([])
      for key, value in map {
        if key != "uuid" && key != "target" {
          result[key] = light_test_strip_ids(value)
        }
      }
      Json::object(result)
    }
    Array(values) => Json::array(values.map(light_test_strip_ids))
    other => other
  }
}

///|
fn light_test_object(light : @core.Object3D) -> Map[String, Json] raise {
  guard light.to_json() is Object(json) &&
    json.get("object") is Some(Object(object)) else {
    fail("no object")
  }
  object
}

///|
/// Upstream `runStdLightTests`, except the round trip through `ObjectLoader`.
fn run_std_light_tests(
  lights : Array[@core.Object3D],
  make : (@math.Color) -> @core.Object3D,
) -> Unit raise {
  for light in lights {
    // copy
    let new_light = make(@math.Color::from_hex(0xc0ffee))
    ignore(new_light.copy(light))
    assert_true(new_light.uuid != light.uuid)
    assert_true(new_light.id != light.id)
    assert_eq(
      light_test_strip_ids(new_light.to_json()),
      light_test_strip_ids(light.to_json()),
    )
    // real copy?
    ignore(new_light.as_light().color.set_hex(0xc0ffee))
    assert_true(
      new_light.as_light().color.get_hex() != light.as_light().color.get_hex(),
    )
    // clone
    let clone = light.clone()
    assert_true(clone.uuid != light.uuid)
    assert_true(clone.id != light.id)
    assert_eq(
      light_test_strip_ids(clone.to_json()),
      light_test_strip_ids(light.to_json()),
    )
    // real clone?
    ignore(clone.as_light().color.set_hex(0xc0ffee))
    assert_true(
      clone.as_light().color.get_hex() != light.as_light().color.get_hex(),
    )
    // what upstream's `checkLightJsonWriting` checks
    guard clone.to_json() is Object(json) else { fail("no json") }
    guard json.get("metadata") is Some(Object(metadata)) else {
      fail("no metadata")
    }
    assert_true(metadata.get("version") is Some(Number(4.7, ..)))
    let object = light_test_object(clone)
    assert_eq(object.get("type"), Some(Json::string(clone.type_)))
    assert_eq(object.get("uuid"), Some(Json::string(clone.uuid)))
    assert_true(object.get("id") is None)
  }
}

///|
test "Light Extending" {
  let object = @core.Light::new()
  assert_true(object.is_light())
  assert_false(object.is_camera())
}

///|
test "Light type" {
  assert_eq(@core.Light::new().type_, "Light")
}

///|
test "Light dispose" {
  @core.Light::new().dispose()
}

///|
test "Light defaults" {
  let light = @core.Light::new().as_light()
  assert_true(light.color.equals(@math.Color::new(1, 1, 1)))
  assert_eq(light.intensity, 1.0)
  assert_true(light.shadow is None)
}

///|
test "Light copies its color argument" {
  let color = @math.Color::from_hex(0xaaaaaa)
  let light = @core.Light::new(color~, intensity=0.5).as_light()
  assert_false(physical_equal(light.color, color))
  assert_true(light.color.equals(color))
  assert_eq(light.intensity, 0.5)
}

///|
test "Light Standard light tests" {
  let color = @math.Color::from_hex(0xaaaaaa)
  run_std_light_tests(
    [
      @core.Light::new(),
      @core.Light::new(color~),
      @core.Light::new(color~, intensity=0.5),
    ],
    color => @core.Light::new(color~),
  )
}

///|
test "Light registerNode follows the prototype chain" {
  @core.Light::register_node("SpotLight", @core.JsValue::of(1))
  assert_true(@core.SpotLight::new().light_node() is Some(_))
  assert_true(@core.IESSpotLight::new().light_node() is Some(_))
  assert_true(@core.ProjectorLight::new().light_node() is Some(_))
  assert_true(@core.PointLight::new().light_node() is None)
  assert_true(@core.Light::light_node_of("SpotLight") is Some(_))
}

///|
test "Light power round trip" {
  let light = @core.PointLight::new()
  light.set_power(1.0)
  assert_true(approx(light.power(), 1.0))
  let light = @core.SpotLight::new()
  light.set_power(1.0)
  assert_true(approx(light.power(), 1.0))
  let light = @core.RectAreaLight::new()
  light.set_power(1.0)
  assert_true(approx(light.power(), 1.0))
}

///|
test "Light copy keeps recursive where upstream forwards it" {
  fn with_child(light : @core.Object3D) -> @core.Object3D {
    ignore(light.add(@core.Object3D::new()))
    light
  }

  // these pass `recursive` to `super.copy`
  let plain = @core.Light::new().copy(
    with_child(@core.Light::new()),
    recursive=false,
  )
  assert_eq(plain.children.length(), 0)
  let point = @core.PointLight::new().copy(
    with_child(@core.PointLight::new()),
    recursive=false,
  )
  assert_eq(point.children.length(), 0)
  let spot = @core.SpotLight::new().copy(
    with_child(@core.SpotLight::new()),
    recursive=false,
  )
  assert_eq(spot.children.length(), 0)
  let hemisphere = @core.HemisphereLight::new().copy(
    with_child(@core.HemisphereLight::new()),
    recursive=false,
  )
  assert_eq(hemisphere.children.length(), 0)
  // these declare `copy( source )` and drop it
  let directional = @core.DirectionalLight::new().copy(
    with_child(@core.DirectionalLight::new()),
    recursive=false,
  )
  assert_eq(directional.children.length(), 1)
  let rect_area = @core.RectAreaLight::new().copy(
    with_child(@core.RectAreaLight::new()),
    recursive=false,
  )
  assert_eq(rect_area.children.length(), 1)
  let probe = @core.LightProbe::new().copy(
    with_child(@core.LightProbe::new()),
    recursive=false,
  )
  assert_eq(probe.children.length(), 1)
}

///|
test "PointLight copy accepts a SpotLight, as upstream" {
  let spot = @core.SpotLight::new(distance=3.0, decay=4.0)
  let point = @core.PointLight::new()
  ignore(point.copy(spot))
  guard point.as_light().kind is PointLight(data) else { fail("not a point") }
  assert_eq(data.distance, 3.0)
  assert_eq(data.decay, 4.0)
  assert_true(point.as_light().shadow is Some({ kind: SpotLightShadow(_), .. }))
}
