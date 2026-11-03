///|
test "DataArrayTexture Instancing" {
  let data = @core.TypedArray::uint8(8)
  let object = @core.DataArrayTexture::new(data~, width=1, height=2, depth=4)
  assert_true(object.texture_type is DataArrayTexture)
  assert_eq(object.mag_filter, @core.NearestFilter)
  assert_eq(object.unpack_alignment, 1)
  assert_eq(object.height(), 2)
  assert_eq(object.depth(), 4)
  guard object.image() is DataImage(image) else { fail("not a data image") }
  assert_true(image.data is Some(d) && physical_equal(d, data))
  assert_eq(object.layer_updates, Some([]))
}

///|
test "DataArrayTexture layerUpdates and copy" {
  let object = @core.DataArrayTexture::new()
  object.add_layer_update(3)
  object.add_layer_update(3)
  assert_eq(object.layer_updates, Some([3]))
  object.wrap_r = @core.MirroredRepeatWrapping
  let c = object.clone()
  assert_eq(c.wrap_r, @core.MirroredRepeatWrapping)
  assert_eq(c.layer_updates, Some([]))
  object.clear_layer_updates()
  assert_eq(object.layer_updates, Some([]))
}
