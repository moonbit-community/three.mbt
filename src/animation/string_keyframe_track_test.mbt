///|
test "StringKeyframeTrack: Instancing" {
  // name, times, values
  let object = @animation.StringKeyframeTrack::new(".name", [0, 1], ["a", "b"])
  assert_eq(object.value_type_name, "string")
  assert_eq(object.times.length(), 2)
}
