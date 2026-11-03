///|
test "VideoFrameTexture Instancing" {
  let object = @core.VideoFrameTexture::new()
  assert_true(object.is_video_texture())
  assert_true(object.texture_type is VideoFrameTexture)
  object.update()
  assert_eq(object.version, 0)
  let frame = @core.JsValue::object()
  object.set_frame(frame)
  assert_eq(object.version, 1)
  assert_true(object.image() is DomImage(f) && f.strict_equal(frame))
  assert_true(object.clone().texture_type is VideoFrameTexture)
}
