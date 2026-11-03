///|
extern "js" fn video_mock(with_callback : Bool) -> @core.JsValue =
  #|(withCallback) => {
  #|  const video = { readyState: 2, HAVE_CURRENT_DATA: 2, requests: 0, cancelled: 0 };
  #|  if (withCallback) {
  #|    video.requestVideoFrameCallback = function (f) { this.callback = f; return ++ this.requests; };
  #|    video.cancelVideoFrameCallback = function (id) { this.cancelled = id; };
  #|  }
  #|  return video;
  #|}

///|
extern "js" fn video_mock_frame(video : @core.JsValue) -> Unit =
  #|(video) => { video.callback(1, {}); }

///|
test "VideoTexture Instancing" {
  let object = @core.VideoTexture::new(@core.JsValue::object())
  assert_true(object.is_video_texture())
  assert_true(object.texture_type is VideoTexture)
  assert_eq(object.mag_filter, @core.LinearFilter)
  assert_eq(object.min_filter, @core.LinearFilter)
  assert_false(object.generate_mipmaps)
  assert_eq(object._request_video_frame_callback_id, 0)
}

///|
test "VideoTexture update without frame callback" {
  let video = video_mock(false)
  let object = @core.VideoTexture::new(video)
  object.update()
  assert_eq(object.version, 1)
  video.set("readyState", @core.JsValue::of(1))
  object.update()
  assert_eq(object.version, 1)
}

///|
test "VideoTexture frame callback and dispose" {
  let video = video_mock(true)
  let object = @core.VideoTexture::new(video)
  assert_eq(object._request_video_frame_callback_id, 1)
  object.update()
  assert_eq(object.version, 0)
  video_mock_frame(video)
  assert_eq(object.version, 1)
  assert_eq(object._request_video_frame_callback_id, 2)
  object.dispose()
  assert_eq(video.get("cancelled").cast(), 2)
  assert_eq(object._request_video_frame_callback_id, 0)
}

///|
test "VideoTexture clone keeps the video" {
  let video = video_mock(true)
  let object = @core.VideoTexture::new(video)
  let c = object.clone()
  assert_true(c.image() is DomImage(v) && v.strict_equal(video))
  assert_eq(video.get("requests").cast(), 2)
  assert_eq(c._request_video_frame_callback_id, 2)
}
