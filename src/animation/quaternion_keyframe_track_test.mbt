///|
test "QuaternionKeyframeTrack: Instancing" {
  // name, times, values
  let object = @animation.QuaternionKeyframeTrack::new(".rotation", [0, 1], [
    0.0, 0.5,
  ])
  assert_eq(object.value_type_name, "quaternion")
  assert_eq(object.times.length(), 2)
}
