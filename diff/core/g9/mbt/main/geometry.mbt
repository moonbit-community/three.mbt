///|
fn register_geometry() -> Unit {
  scenario("geometry_draws", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let scene = @core.Scene::new()
      let cam = camera()
      let basic = fn() { @nodes.MeshBasicNodeMaterial::new() }
      // non-indexed
      let tri = @core.BufferGeometry::new()
      let tri_pos = @core.Float32BufferAttribute::new([0.0, 0, 0, 1, 0, 0, 0, 1, 0], 3)
      tri.set_attribute("position", tri_pos.to_geometry_attribute()) |> ignore
      scene.add(@core.Mesh::new(geometry=tri, material=Single(basic()))) |> ignore
      // indexed (uint32) with a normalized, padded color attribute
      let q = position_geometry([0.0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0])
      q.set_attribute("color", @core.Uint8BufferAttribute::new([255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255], 3, normalized=true).to_geometry_attribute()) |> ignore
      q.set_index(@core.Uint32BufferAttribute::new([0, 1, 2, 0, 2, 3], 1)) |> ignore
      let mq = basic()
      mq.vertex_colors = true
      scene.add(@core.Mesh::new(geometry=q, material=Single(mq))) |> ignore
      // interleaved position + uv
      let ib = @core.InterleavedBuffer::new(@core.TypedArray::float32([0.0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]), 5)
      let ig = @core.BufferGeometry::new()
      ig.set_attribute("position", @core.InterleavedBufferAttribute::new(ib, 3, 0).to_geometry_attribute()) |> ignore
      ig.set_attribute("uv", @core.InterleavedBufferAttribute::new(ib, 2, 3).to_geometry_attribute()) |> ignore
      scene.add(@core.Mesh::new(geometry=ig, material=Single(basic()))) |> ignore
      // instancing
      let im = @core.InstancedMesh::new(geometry=@geometries.BoxGeometry::new(), material=Single(basic()), 3)
      for i = 0; i < 3; i = i + 1 {
        im.set_matrix_at(i, @math.Matrix4::new().make_translation(i.to_double(), 0.0, 0.0)) |> ignore
        im.set_color_at(i, @math.Color::new(i.to_double() / 3.0, 0.5, 1.0)) |> ignore
      }
      scene.add(im) |> ignore
      // indirect (indexed and not)
      let ind = @geometries.BoxGeometry::new()
      ind.set_indirect(Some(@nodes.IndirectStorageBufferAttribute::from_array(@core.TypedArray::uint32([36, 1, 0, 0, 0]), 5))) |> ignore
      scene.add(@core.Mesh::new(geometry=ind, material=Single(basic()))) |> ignore
      let ind2 = position_geometry([0.0, 0, 0, 1, 0, 0, 0, 1, 0])
      ind2.set_indirect(Some(@nodes.IndirectStorageBufferAttribute::from_array(@core.TypedArray::uint32([3, 1, 0, 0]), 4))) |> ignore
      scene.add(@core.Mesh::new(geometry=ind2, material=Single(basic()))) |> ignore
      // batched mesh
      let bm = @core.BatchedMesh::new(4, 100, max_index_count=200, material=Single(basic()))
      let g1 = bm.add_geometry(@geometries.BoxGeometry::new())
      let g2 = bm.add_geometry(@geometries.PlaneGeometry::new())
      let i1 = bm.add_instance(g1)
      let i2 = bm.add_instance(g2)
      let i3 = bm.add_instance(g1)
      bm.set_matrix_at(i2, @math.Matrix4::new().make_translation(1.0, 0.0, 0.0)) |> ignore
      bm.set_matrix_at(i3, @math.Matrix4::new().make_translation(-1.0, 0.0, 0.0)) |> ignore
      scene.add(bm) |> ignore
      env.note("batched", @core.JsValue::of([i1, i2, i3]))
      r.render(scene, cam)
      // update ranges
      tri_pos.array.set(0, 0.5)
      tri_pos.add_update_range(0, 3)
      tri_pos.set_needs_update(true)
      r.render(scene, cam)
      tri_pos.set_needs_update(true)
      r.render(scene, cam)
      done()
    })
  })
}

///|
fn register_instancing_dispose() -> Unit {
  scenario("instancing_dispose", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let scene = @core.Scene::new()
      let m = @nodes.MeshBasicNodeMaterial::new()
      m.color.unwrap().set_hex(0x3399ff) |> ignore
      let instanced = @core.InstancedMesh::new(geometry=@geometries.BoxGeometry::new(width=0.4, height=0.4, depth=0.4), material=Single(m), 5)
      for i = 0; i < 5; i = i + 1 {
        instanced.set_matrix_at(i, @math.Matrix4::new().make_translation((i - 2).to_double() * 0.6, 0.0, 0.0)) |> ignore
        instanced.set_color_at(i, @math.Color::new(i.to_double() / 4.0, 1.0 - i.to_double() / 4.0, 0.5)) |> ignore
      }
      scene.add(instanced) |> ignore
      let target = @core.RenderTarget::new(width=4, height=4)
      r.set_render_target(Some(target))
      r.render(scene, camera())
      instanced.set_matrix_at(0, @math.Matrix4::new().make_translation(0.0, 1.0, 0.0)) |> ignore
      match instanced.kind {
        Mesh({ kind: InstancedMesh(im), .. }) => im.instance_matrix.set_needs_update(true)
        _ => ()
      }
      r.render(scene, camera())
      r.read_render_target_pixels_async(target, 0, 0, 4, 4, fn(pixels) {
        env.note("pixels", @core.JsValue::of(pixels.unwrap().length()))
        r.dispose(on_done=done)
      })
    })
  })
}
