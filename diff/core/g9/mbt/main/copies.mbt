///|
fn register_copies() -> Unit {
  scenario("copies", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let src = data_tex("Uint8Array", 4, @core.RGBAFormat, @core.UnsignedByteType)
      let dst = data_tex("Uint8Array", 4, @core.RGBAFormat, @core.UnsignedByteType)
      r.init_texture(src)
      r.init_texture(dst)
      r.copy_texture_to_texture(src, dst)
      r.copy_texture_to_texture(src, dst, src_region=Box2(@math.Box2::new(min=@math.Vector2::new(1.0, 1.0), max=@math.Vector2::new(3.0, 3.0))), dst_position=Vec2(@math.Vector2::new(0.0, 1.0)))
      let mip_dst = data_tex("Uint8Array", 4, @core.RGBAFormat, @core.UnsignedByteType)
      mip_dst.generate_mipmaps = true
      mip_dst.min_filter = @core.LinearMipmapLinearFilter
      r.init_texture(mip_dst)
      r.copy_texture_to_texture(src, mip_dst)
      let a = @core.Data3DTexture::new(data=@core.TypedArray::uint8(4 * 8), width=2, height=2, depth=2)
      a.set_needs_update(true)
      let b = @core.Data3DTexture::new(data=@core.TypedArray::uint8(4 * 8), width=2, height=2, depth=2)
      b.set_needs_update(true)
      r.init_texture(a)
      r.init_texture(b)
      r.copy_texture_to_texture(a, b, src_region=Box3(@math.Box3::new(min=@math.Vector3::new(0.0, 0.0, 0.0), max=@math.Vector3::new(1.0, 1.0, 2.0))), dst_position=Vec3(@math.Vector3::new(1.0, 1.0, 0.0)), src_level=0, dst_level=0)
      // framebuffer copies: of a render target, of the canvas output, and in a render
      let scene = box_scene()
      let cam = camera()
      let rt = @core.RenderTarget::new(width=4, height=4)
      r.set_render_target(Some(rt))
      r.render(scene, cam)
      let fb = @core.FramebufferTexture::new(width=4, height=4)
      r.copy_framebuffer_to_texture(fb)
      r.set_render_target(None)
      r.render(scene, cam)
      let fb2 = @core.FramebufferTexture::new(width=2, height=2)
      r.copy_framebuffer_to_texture(fb2, rectangle=@math.Vector4::new(1.0, 1.0, 2.0, 2.0))
      let m = @nodes.MeshBasicNodeMaterial::new()
      @nodes.NodeMaterial::of(m).unwrap().color_node = Some(@nodes.viewport_shared_texture())
      let scene2 = box_scene()
      scene2.add(@core.Mesh::new(geometry=@geometries.PlaneGeometry::new(), material=Single(m))) |> ignore
      r.render(scene2, cam)
      r.set_render_target(Some(rt))
      r.render(scene2, cam)
      done()
    })
  })
}
