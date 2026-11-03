///|
fn box_scene() -> @core.Object3D {
  let scene = @core.Scene::new()
  scene.add(@core.Mesh::new(geometry=@geometries.BoxGeometry::new(), material=Single(@nodes.MeshBasicNodeMaterial::new()))) |> ignore
  scene
}

///|
fn register_render_setup() -> Unit {
  scenario("render_targets", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let scene = box_scene()
      let cam = camera()
      let rt = @core.RenderTarget::new(width=4, height=4)
      r.set_render_target(Some(rt))
      r.render(scene, cam)
      let mrt_rt = @core.RenderTarget::new(width=4, height=4, count=2)
      mrt_rt.textures[0].name = "output"
      mrt_rt.textures[1].name = "normal"
      r.set_mrt(Some(@nodes.mrt(Map::from_array([("output", @nodes.output), ("normal", @nodes.vec4_of([@nodes.normal_view, 1]))])))) |> ignore
      r.set_render_target(Some(mrt_rt))
      r.render(scene, cam)
      r.set_mrt(None) |> ignore
      let msaa = @core.RenderTarget::new(width=4, height=4, samples=4)
      r.set_render_target(Some(msaa))
      r.render(scene, cam)
      let no_resolve = @core.RenderTarget::new(width=4, height=4, samples=4, resolve_depth_buffer=false)
      no_resolve.resolve_color_buffer = false
      r.set_render_target(Some(no_resolve))
      r.render(scene, cam)
      let discard = @core.RenderTarget::new(width=4, height=4, samples=4)
      discard.store_multisampled_color_buffer = false
      discard.store_multisampled_depth_buffer = false
      r.auto_clear = false
      r.set_render_target(Some(discard))
      r.render(scene, cam)
      r.auto_clear = true
      let depth_texture = @core.DepthTexture::new(width=4, height=4)
      depth_texture.format = @core.DepthStencilFormat
      depth_texture.type_ = @core.UnsignedInt248Type
      let ds = @core.RenderTarget::new(width=4, height=4, depth_texture~, stencil_buffer=true)
      let scene2 = @core.Scene::new()
      let sm = @nodes.MeshBasicNodeMaterial::new()
      sm.stencil_write = true
      sm.stencil_ref = 1
      sm.stencil_z_pass = @core.ReplaceStencilOp
      sm.stencil_func = @core.AlwaysStencilFunc
      scene2.add(@core.Mesh::new(geometry=@geometries.BoxGeometry::new(), material=Single(sm))) |> ignore
      r.set_render_target(Some(ds))
      r.render(scene2, cam)
      r.set_render_target(None)
      r.render(scene, cam)
      done()
    })
  })
  scenario("reversed_depth_nostencil", fn(env, done) {
    let r = @webgpu.WebGPURenderer::new(canvas=env.canvas, reversed_depth_buffer=true)
    r.init(on_done=fn(_) {
      r.render(box_scene(), camera())
      done()
    })
  })
  scenario("msaa_canvas", fn(env, done) {
    let r = renderer(env, antialias=true)
    r.init(on_done=fn(_) {
      r.render(box_scene(), camera())
      r.render(box_scene(), camera())
      done()
    })
  })
  scenario("reversed_depth", fn(env, done) {
    let r = @webgpu.WebGPURenderer::new(canvas=env.canvas, reversed_depth_buffer=true, stencil=true)
    r.init(on_done=fn(_) {
      let scene = box_scene()
      let m = @nodes.MeshBasicNodeMaterial::new()
      m.polygon_offset = true
      m.polygon_offset_factor = 2.0
      m.polygon_offset_units = 3.0
      m.depth_func = @core.LessDepth
      scene.add(@core.Mesh::new(geometry=@geometries.BoxGeometry::new(), material=Single(m))) |> ignore
      r.render(scene, camera())
      done()
    })
  })
}
