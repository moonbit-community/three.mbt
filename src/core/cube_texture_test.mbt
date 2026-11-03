///|
test "CubeTexture Instancing" {
  let object = @core.CubeTexture::new()
  assert_true(object.is_cube_texture())
  assert_false(object.flip_y)
  assert_eq(object.mapping, @core.CubeReflectionMapping)
  assert_true(object.images() is ImageArray([]))
  object.set_images(ImageArray([NoImage]))
  assert_true(object.image() is ImageArray([NoImage]))
  assert_true(object.clone().texture_type is CubeTexture)
}
