///|
test "RenderTarget Constructor" {
  let empty = @core.RenderTarget::new()
  assert_eq(empty.width, 1)
  assert_eq(empty.height, 1)
  assert_eq(empty.textures.length(), 1)
  let mrt = @core.RenderTarget::new(width=1, height=1, count=2)
  assert_eq(mrt.textures.length(), 2)
  let options = @core.RenderTarget::new(
    width=1,
    height=1,
    mag_filter=@core.NearestFilter,
  )
  assert_eq(options.texture().mag_filter, @core.NearestFilter)
}

///|
test "RenderTarget defaults" {
  let target = @core.RenderTarget::new(width=4, height=2)
  assert_eq(target.viewport.z, 4)
  assert_eq(target.scissor.w, 2)
  assert_eq(target.depth, 1)
  assert_true(target.depth_buffer)
  assert_false(target.stencil_buffer)
  assert_true(target.resolve_color_buffer)
  assert_true(target.store_multisampled_stencil_buffer)
  assert_eq(target.samples, 0)
  assert_true(target.depth_texture() is None)
  let texture = target.texture()
  assert_true(texture.is_render_target_texture)
  assert_true(texture.render_target is Some(t) && physical_equal(t, target))
  assert_false(texture.flip_y)
  assert_false(texture.generate_mipmaps)
  assert_eq(texture.min_filter, @core.LinearFilter)
  assert_eq(texture.internal_format, None)
  assert_eq(texture.width(), 4)
  let options = @core.RenderTarget::new(
    generate_mipmaps=true,
    internal_format="RGBA8",
    min_filter=@core.NearestFilter,
    flip_y=true,
    color_space="srgb",
    depth=4,
  )
  assert_true(options.texture().generate_mipmaps)
  assert_eq(options.texture().internal_format, Some("RGBA8"))
  assert_eq(options.texture().min_filter, @core.NearestFilter)
  assert_true(options.texture().flip_y)
  assert_eq(options.texture().color_space, "srgb")
  assert_true(options.texture().is_array_texture)
}

///|
test "RenderTarget setSize" {
  let target = @core.RenderTarget::new()
  let mut disposed = 0
  target.add_event_listener("dispose", _ => disposed += 1)
  target.set_size(128, 128)
  assert_eq(disposed, 1)
  assert_eq(target.width, 128)
  assert_eq(target.height, 128)
  assert_eq(target.texture().width(), 128)
  assert_eq(target.texture().height(), 128)
  assert_eq(target.viewport.z, 128)
  assert_eq(target.viewport.w, 128)
  assert_eq(target.scissor.z, 128)
  assert_eq(target.scissor.w, 128)
  // same size does not dispose
  target.set_size(128, 128)
  assert_eq(disposed, 1)
  let mrt = @core.RenderTarget::new(width=0, height=0, count=2)
  mrt.set_size(128, 128)
  assert_eq(mrt.textures[0].width(), 128)
  assert_eq(mrt.textures[1].height(), 128)
  let target3d = @core.RenderTarget::new()
  target3d.set_size(128, 128, depth=16)
  assert_eq(target3d.depth, 16)
  assert_eq(target3d.texture().depth(), 16)
  assert_true(target3d.texture().is_array_texture)
  target3d.set_size(128, 128)
  assert_false(target3d.texture().is_array_texture)
}

///|
test "RenderTarget setSize on an image array" {
  let target = @core.RenderTarget::new()
  target.set_texture(@core.CubeTexture::new(images=[NoImage]))
  target.set_size(4, 4)
  assert_eq(target.texture().width(), 4)
  assert_true(target.texture().image() is ImageArray(_))
}

///|
test "RenderTarget depthTexture" {
  let target = @core.RenderTarget::new()
  let depth_texture = @core.DepthTexture::new(width=1, height=1)
  target.set_depth_texture(Some(depth_texture))
  assert_true(
    depth_texture.render_target is Some(t) && physical_equal(t, target),
  )
  target.set_depth_texture(None)
  assert_true(depth_texture.render_target is None)
  // a depth texture owned by another target stays there
  let other = @core.RenderTarget::new(depth_texture~)
  target.set_depth_texture(Some(depth_texture))
  assert_true(
    depth_texture.render_target is Some(t) && physical_equal(t, other),
  )
  target.set_depth_texture(None)
  assert_true(
    depth_texture.render_target is Some(t) && physical_equal(t, other),
  )
}

///|
test "RenderTarget clone" {
  let target = @core.RenderTarget::new(
    width=4,
    height=2,
    count=2,
    samples=4,
    depth_texture=@core.DepthTexture::new(width=4, height=2),
  )
  target.scissor_test = true
  let c = target.clone()
  assert_eq(c.width, 4)
  assert_eq(c.samples, 4)
  assert_true(c.scissor_test)
  assert_eq(c.textures.length(), 2)
  assert_true(c.texture().render_target is Some(t) && physical_equal(t, c))
  assert_false(physical_equal(c.texture().source, target.texture().source))
  guard (c.texture().image(), target.texture().image())
    is (DataImage(a), DataImage(b)) else {
    fail("not data images")
  }
  assert_false(physical_equal(a, b))
  assert_eq(a.width, 4)
  // an owned depth texture is cloned, and the clone owns the new one
  guard (c.depth_texture(), target.depth_texture()) is (Some(a), Some(b)) else {
    fail("no depth textures")
  }
  assert_false(physical_equal(a, b))
  assert_true(a.render_target is Some(t) && physical_equal(t, c))
  // a borrowed depth texture is shared
  let borrowed = @core.RenderTarget::new()
  borrowed.set_depth_texture(target.depth_texture())
  let d = borrowed.clone()
  assert_true(d.depth_texture() is Some(x) && physical_equal(x, b))
}

///|
priv struct XRRenderTarget {
  copied : Ref[Int32]
}

///|
impl @core.RenderTargetExtension for XRRenderTarget with fn construct(self) {
  @core.RenderTarget::new().set_extension(self)
}

///|
impl @core.RenderTargetExtension for XRRenderTarget with fn copy_from(
  self,
  _,
  _,
) {
  self.copied.val += 1
}

///|
test "RenderTarget extension" {
  let extension = XRRenderTarget::{ copied: Ref(0), }
  let target = @core.RenderTarget::new(width=3).set_extension(extension)
  let c = target.clone()
  assert_eq(c.width, 3)
  assert_eq(extension.copied.val, 1)
}
