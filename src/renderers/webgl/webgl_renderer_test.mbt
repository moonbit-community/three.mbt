// Group 4: direct checks of WebGLRenderer on the mock context (the call logs themselves
// are compared with upstream in webgl_renderer_diff_test.mbt).

///|
test "WebGLRenderer scene callbacks and CubeCameraRenderer" {
  let gl = mock_gl(options=renderer_mock_options("{}"))
  let canvas = renderer_mock_canvas(gl, 64, 32)
  let renderer = renderer_new(gl, canvas)
  let scene = @core.Scene::new()
  let camera = @core.PerspectiveCamera::new()
  // the default scene callbacks are no-ops
  renderer.render(scene, camera)
  let calls : Array[String] = []
  scene.set_scene_on_before_render((_, _, _, target) => {
    calls.push("before " + (target is Some(_)).to_string())
  })
  scene.set_scene_on_after_render((_, _, _) => calls.push("after"))
  let target = @webgl.WebGLRenderTarget::new(width=4, height=4)
  renderer.set_render_target(Some(target))
  renderer.render(scene, camera)
  renderer.set_render_target(None)
  // a non-scene root does not get the scene callbacks
  renderer.render(@core.Group::new(), camera)
  assert_eq(calls.join(","), "before true,after")
  inspect(renderer.info.render.frame, content="3")
  // core drives the renderer through the trait
  let r : &@core.CubeCameraRenderer = renderer
  inspect(r.coordinate_system(), content="2000")
  r.set_render_target(Some(target), 0, 0)
  assert_true(r.get_render_target() is Some(t) && physical_equal(t, target))
  r.set_render_target(None, 0, 0)
  inspect(r.auto_clear(), content="true")
  inspect(r.reversed_depth_buffer(), content="false")
  r.set_xr_enabled(true)
  inspect(renderer.xr.enabled, content="true")
  renderer.dispose()
}

///|
test "WebGLRenderer compile and render lists" {
  let gl = mock_gl(options=renderer_mock_options("{}"))
  let renderer = renderer_new(gl, renderer_mock_canvas(gl, 64, 32))
  let scene = @core.Scene::new()
  let shared = @core.MeshBasicMaterial::new()
  let transparent = @core.MeshBasicMaterial::new()
  transparent.transparent = true
  transparent.side = @core.DoubleSide
  for material in [shared, shared, transparent] {
    ignore(scene.add(renderer_mesh(@geometries.BoxGeometry::new(), material)))
  }
  let camera = @core.PerspectiveCamera::new()
  ignore(camera.position.set(0.0, 0.0, 5.0))
  // the Set of prepared materials keeps first-seen order without duplicates
  let materials = renderer.compile(scene, camera)
  inspect(materials.length(), content="2")
  // the double-sided transparent material is compiled for both sides and restored
  inspect(transparent.side == @core.DoubleSide, content="true")
  renderer.render(scene, camera)
  // two opaque boxes, the transparent one drawn twice (back, then front)
  inspect(renderer.info.render.calls, content="4")
  inspect(renderer.render_list_stack.length(), content="0")
  inspect(renderer.render_state_stack.length(), content="0")
  // setEffects needs a float output buffer
  renderer.set_effects(None)
  renderer.dispose()
}

///|
test "WebGLCubeRenderTarget clear restores the render target" {
  let gl = mock_gl(options=renderer_mock_options("{}"))
  let renderer = renderer_new(gl, renderer_mock_canvas(gl, 64, 32))
  let cube = @webgl.WebGLCubeRenderTarget::new(size=4)
  let previous = @webgl.WebGLRenderTarget::new(width=2, height=2)
  renderer.set_render_target(Some(previous))
  // allocate the cube framebuffers first, so only the per-face binds remain
  renderer.init_render_target(cube)
  mock_clear(gl)
  @webgl.WebGLCubeRenderTarget::clear(cube, renderer)
  let faces = mock_log(gl).filter(l => l.has_prefix("framebufferTexture2D("))
  inspect(faces.length(), content="6")
  assert_true(
    renderer.get_render_target() is Some(t) && physical_equal(t, previous),
  )
  inspect(renderer.get_active_cube_face(), content="0")
  renderer.dispose()
}
