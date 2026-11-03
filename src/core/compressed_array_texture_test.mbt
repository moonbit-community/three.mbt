///|
test "CompressedArrayTexture Instancing" {
  let object = @core.CompressedArrayTexture::new(width=2, height=2, depth=3)
  assert_true(object.is_compressed_texture())
  assert_true(object.texture_type is CompressedArrayTexture)
  assert_eq(object.depth(), 3)
  assert_eq(object.wrap_r, @core.ClampToEdgeWrapping)
  assert_false(object.is_array_texture)
}

///|
test "CompressedArrayTexture layerUpdates and copy" {
  let object = @core.CompressedArrayTexture::new()
  object.add_layer_update(1)
  object.add_layer_update(1)
  object.add_layer_update(2)
  assert_eq(object.layer_updates, Some([1, 2]))
  object.wrap_r = @core.RepeatWrapping
  let c = object.clone()
  assert_eq(c.wrap_r, @core.RepeatWrapping)
  assert_eq(c.layer_updates, Some([]))
  object.clear_layer_updates()
  assert_eq(object.layer_updates, Some([]))
}
