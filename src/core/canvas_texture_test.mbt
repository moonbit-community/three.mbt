///|
test "CanvasTexture Instancing" {
  let object = @core.CanvasTexture::new()
  assert_true(object.texture_type is CanvasTexture)
  assert_true(object.image() is NoImage)
  // needsUpdate is set by the constructor
  assert_eq(object.version, 1)
  assert_eq(object.source.version, 1)
  let canvas = @core.JsValue::object()
  let t = @core.CanvasTexture::new(canvas~, anisotropy=2)
  assert_true(t.image() is DomImage(c) && c.strict_equal(canvas))
  assert_eq(t.anisotropy, 2)
  assert_true(t.clone().texture_type is CanvasTexture)
  assert_eq(t.clone().version, 2)
}
