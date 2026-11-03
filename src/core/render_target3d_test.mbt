///|
test "RenderTarget3D Extending" {
  let object = @core.RenderTarget3D::new()
  let mut disposed = false
  object.add_event_listener("dispose", _ => disposed = true)
  object.dispose()
  assert_true(disposed)
  let options = @core.RenderTarget3D::new(
    width=1,
    height=1,
    depth=1,
    mag_filter=@core.NearestFilter,
    wrap_r=@core.RepeatWrapping,
  )
  assert_eq(options.width, 1)
  assert_eq(options.height, 1)
  assert_eq(options.depth, 1)
  assert_eq(options.texture().mag_filter, @core.NearestFilter)
  assert_eq(options.texture().wrap_r, @core.RepeatWrapping)
}

///|
test "RenderTarget3D textures" {
  let object = @core.RenderTarget3D::new(width=2, height=3, depth=4, count=2)
  assert_true(object.render_target_type is RenderTarget3D)
  assert_eq(object.depth, 4)
  assert_eq(object.textures.length(), 2)
  let texture = object.texture()
  assert_true(texture.texture_type is Data3DTexture)
  assert_true(texture.is_render_target_texture)
  assert_true(texture.render_target is Some(t) && physical_equal(t, object))
  assert_eq(texture.depth(), 4)
  assert_eq(texture.min_filter, @core.LinearFilter)
  assert_false(texture.is_array_texture)
  object.set_size(8, 8, depth=8)
  assert_false(texture.is_array_texture)
  let c = object.clone()
  assert_true(c.render_target_type is RenderTarget3D)
  assert_true(c.texture().texture_type is Data3DTexture)
  assert_eq(c.depth, 8)
}
