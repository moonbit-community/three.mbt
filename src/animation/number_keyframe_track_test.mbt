///|
test "NumberKeyframeTrack: Instancing" {
  // name, times, values
  let object = @animation.NumberKeyframeTrack::new(
    ".material.opacity",
    [0, 1],
    [0.0, 0.5],
  )
  assert_eq(object.value_type_name, "number")
  assert_eq(object.times.length(), 2)
}
