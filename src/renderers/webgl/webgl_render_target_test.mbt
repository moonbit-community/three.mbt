// Upstream test/unit/src/renderers/WebGLRenderTarget.tests.js, WebGL3DRenderTarget.tests.js,
// WebGLArrayRenderTarget.tests.js and WebGLCubeRenderTarget.tests.js. "extends" checks
// become extension flags.

///|
test "WebGLRenderTarget Extending" {
  let object = @webgl.WebGLRenderTarget::new()
  assert_true(object.has_extension_flag("isWebGLRenderTarget"))
  // WebGLRenderTarget extends from EventDispatcher
  let called = Ref(0)
  let listener = (_ : @core.Event) => called.val += 1
  object.add_event_listener("dispose", listener)
  object.dispose()
  inspect(called.val, content="1")
  let options = @webgl.WebGLRenderTarget::new(
    width=1,
    height=1,
    mag_filter=@core.NearestFilter,
  )
  assert_true(
    options.width == 1 &&
    options.height == 1 &&
    options.texture().mag_filter == @core.NearestFilter,
  )
}

///|
test "WebGLRenderTarget Instancing and dispose" {
  let object = @webgl.WebGLRenderTarget::new()
  inspect(object.width, content="1")
  object.dispose()
  inspect(
    @webgl.webgl_render_target_kind(object) == Some(WebGLRenderTarget),
    content="true",
  )
  inspect(
    @webgl.webgl_render_target_kind(@core.RenderTarget::new()) is None,
    content="true",
  )
}

///|
test "WebGL3DRenderTarget Extending" {
  let object = @webgl.WebGL3DRenderTarget::new()
  assert_true(object.has_extension_flag("isWebGLRenderTarget"))
  assert_true(object.has_extension_flag("isWebGL3DRenderTarget"))
  let options = @webgl.WebGL3DRenderTarget::new(
    width=1,
    height=1,
    depth=1,
    mag_filter=@core.NearestFilter,
  )
  assert_true(
    options.width == 1 &&
    options.height == 1 &&
    options.depth == 1 &&
    options.texture().mag_filter == @core.NearestFilter,
  )
  let t = @webgl.WebGL3DRenderTarget::new(width=4, height=2, depth=3)
  inspect(t.texture().texture_type is Data3DTexture, content="true")
  inspect(t.texture().is_render_target_texture, content="true")
  inspect(t.depth, content="3")
  // clone rebuilds the subclass through the extension
  assert_true(t.clone().has_extension_flag("isWebGL3DRenderTarget"))
}

///|
test "WebGLArrayRenderTarget Extending" {
  let object = @webgl.WebGLArrayRenderTarget::new()
  assert_true(object.has_extension_flag("isWebGLRenderTarget"))
  assert_true(object.has_extension_flag("isWebGLArrayRenderTarget"))
  let options = @webgl.WebGLArrayRenderTarget::new(
    width=1,
    height=1,
    depth=1,
    mag_filter=@core.NearestFilter,
  )
  assert_true(
    options.width == 1 &&
    options.height == 1 &&
    options.depth == 1 &&
    options.texture().mag_filter == @core.NearestFilter,
  )
  inspect(object.texture().texture_type is DataArrayTexture, content="true")
}

///|
test "WebGLCubeRenderTarget Extending" {
  let object = @webgl.WebGLCubeRenderTarget::new()
  assert_true(object.has_extension_flag("isWebGLRenderTarget"))
  assert_true(object.has_extension_flag("isWebGLCubeRenderTarget"))
  let options = @webgl.WebGLCubeRenderTarget::new(
    size=1,
    mag_filter=@core.NearestFilter,
  )
  assert_true(
    options.width == 1 &&
    options.height == 1 &&
    options.texture().mag_filter == @core.NearestFilter,
  )
  inspect(object.texture().is_cube_texture(), content="true")
  inspect(object.texture().is_render_target_texture, content="true")
}

///|
test "WebGLCubeRenderTarget Instancing" {
  let object = @webgl.WebGLCubeRenderTarget::new(size=8)
  inspect(object.width, content="8")
  guard object.texture().image() is ImageArray(images) else {
    fail("cube texture without six images")
  }
  inspect(images.length(), content="6")
  inspect(images[0].width(), content="8")
}
