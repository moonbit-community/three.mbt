///|
test "ColorKeyframeTrack: Instancing" {
  // name, times, values
  let object = @animation.ColorKeyframeTrack::new(".material.diffuse", [0, 1], [
    0.0, 0.5, 1.0,
  ])
  assert_eq(object.value_type_name, "color")
  assert_eq(object.times.length(), 2)
}
