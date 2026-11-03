///|
test "VectorKeyframeTrack: Instancing" {
  // name, times, values
  let object = @animation.VectorKeyframeTrack::new(".position", [0, 1], [
    0.0, 0.5,
  ])
  assert_eq(object.value_type_name, "vector")
  assert_eq(object.times.length(), 2)
}
