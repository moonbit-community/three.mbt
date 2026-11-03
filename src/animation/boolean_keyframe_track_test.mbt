///|
test "BooleanKeyframeTrack: Instancing" {
  // name, times, values
  let object = @animation.BooleanKeyframeTrack::new(".visible", [0, 1], [
    true, false,
  ])
  assert_eq(object.value_type_name, "bool")
  assert_eq(object.times.length(), 2)
}
