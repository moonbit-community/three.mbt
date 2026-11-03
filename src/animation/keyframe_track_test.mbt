///|
test "KeyframeTrack: Instancing" {
  // name, times, values
  let object = @animation.NumberKeyframeTrack::new(
    ".material.opacity",
    [0, 1],
    [0.0, 0.5],
  )
  assert_eq(object.name, ".material.opacity")
  assert_eq(object.value_type_name, "number")

  // name, times, values, interpolation
  let object_all = @animation.NumberKeyframeTrack::new(
    ".material.opacity",
    [0, 1],
    [0.0, 0.5],
    interpolation=@core.InterpolateLinear,
  )
  assert_eq(object_all.get_interpolation(), Some(@core.InterpolateLinear))
}

///|
test "KeyframeTrack: shift" {
  let track = @animation.NumberKeyframeTrack::new(
    ".material.opacity",
    [0, 1],
    [0, 1],
    interpolation=@core.InterpolateBezier,
  )
  track.settings = Some(
    @animation.KeyframeTrackSettings::new(
      in_tangents=@core.TypedArray::float32([-0.5, 0.0, 0.5, 1.0]),
      out_tangents=@core.TypedArray::float32([0.5, 0.0, 1.5, 1.0]),
    ),
  )
  track.shift(2.0) |> ignore
  let settings = track.settings.unwrap()
  assert_eq(settings.in_tangents.unwrap().to_array(), [1.5, 0.0, 2.5, 1.0])
  assert_eq(settings.out_tangents.unwrap().to_array(), [2.5, 0.0, 3.5, 1.0])
  // Shifted curve keeps its shape.
  assert_eq(track.create_interpolant().evaluate(2.5)[0], 0.5)
}

///|
test "KeyframeTrack: validate" {
  let valid_track = @animation.NumberKeyframeTrack::new(
    ".material.opacity",
    [0, 1],
    [0.0, 0.5],
  )
  let invalid_track = @animation.NumberKeyframeTrack::new(
    ".material.opacity",
    [0, 1],
    [0.0, @double.not_a_number],
  )
  assert_true(valid_track.validate())
  assert_false(invalid_track.validate())
}

///|
test "KeyframeTrack: optimize" {
  let track = @animation.NumberKeyframeTrack::new(
    ".material.opacity",
    [0, 1, 2, 3, 4],
    [0, 0, 0, 0, 1],
  )
  assert_eq(track.values.length(), 5)
  track.optimize() |> ignore
  assert_eq(track.times.to_array(), [0.0, 3.0, 4.0])
  assert_eq(track.values.numbers().to_array(), [0.0, 0.0, 1.0])
}

///|
test "KeyframeTrack: Float32 storage" {
  let track = @animation.NumberKeyframeTrack::new(".x", [0.1, 1], [0.1, 0.2])
  // values round like upstream's Float32Array
  assert_eq(track.times[0], 0.10000000149011612)
  assert_eq(track.values.numbers()[1], 0.20000000298023224)
  // a Float32Array is kept, not copied
  let times = @core.TypedArray::float32([0.0, 1.0])
  let shared = @animation.VectorKeyframeTrack::new(".position", times, [
    0, 0, 0, 1, 1, 1,
  ])
  assert_true(physical_equal(shared.times, times))
  assert_eq(shared.get_value_size(), 3.0)
}

///|
test "KeyframeTrack: interpolation support by type" {
  let quaternion = @animation.QuaternionKeyframeTrack::new(".quaternion", [0], [
    0, 0, 0, 1,
  ])
  // smooth is unsupported: warns and keeps linear
  quaternion.set_interpolation(@core.InterpolateSmooth) |> ignore
  assert_eq(quaternion.get_interpolation(), Some(@core.InterpolateLinear))
  let boolean = @animation.BooleanKeyframeTrack::new(".visible", [0, 1], [
    true, false,
  ])
  assert_eq(boolean.get_interpolation(), Some(@core.InterpolateDiscrete))
  let clone = boolean.clone()
  assert_eq(clone.value_type_name, "bool")
  assert_eq(clone.values.length(), 2)
}

///|
test "KeyframeTrack: toJSON and parse" {
  let track = @animation.ColorKeyframeTrack::new(
    ".material.color",
    [0, 1],
    [0.0, 0.5, 1.0, 1.0, 0.5, 0.0],
    interpolation=@core.InterpolateDiscrete,
  )
  let json = track.to_json()
  assert_eq(
    json.stringify(),
    "{\"name\":\".material.color\",\"times\":[0,1],\"values\":[0,0.5,1,1,0.5,0],\"interpolation\":2300,\"type\":\"color\"}",
  )
  let parsed = @animation.KeyframeTrack::parse(json)
  assert_eq(parsed.value_type_name, "color")
  assert_eq(parsed.get_interpolation(), Some(@core.InterpolateDiscrete))
  assert_eq(parsed.values.numbers().to_array(), [0.0, 0.5, 1.0, 1.0, 0.5, 0.0])
}
