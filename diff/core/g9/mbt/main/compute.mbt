///|
fn register_compute() -> Unit {
  scenario("compute_storage", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let count = 16
      let positions = @nodes.instanced_array(count, type_="vec4")
      let counter = @nodes.instanced_array(1, type_="uint").to_atomic()
      let f = @nodes.fn_(fn(_, _) {
        positions.element(@nodes.instance_index).assign(@nodes.vec4_of([@nodes.float(@nodes.instance_index), 1, 2, 3]))
        @nodes.atomic_add(counter.element(0), 1) |> ignore
        None
      })
      let compute = f.call([]).compute(count)
      r.compute(compute)
      r.compute(compute)
      let kernel = f.call([]).compute_kernel(workgroup_size=[4])
      r.compute(kernel, dispatch_size=Size([2, 1, 1]))
      r.compute(kernel, dispatch_size=Indirect(@nodes.IndirectStorageBufferAttribute::from_array(@core.TypedArray::uint32([1, 1, 1]), 1)))
      // storage texture
      let st = @nodes.StorageTexture::new(width=4, height=4)
      let store_fn = @nodes.fn_(fn(_, _) {
        let x = @nodes.instance_index.mod(4)
        let y = @nodes.instance_index.div(4)
        @nodes.texture_store(st, @nodes.uvec2_of([x, y]), @nodes.vec4_of([1, 0, 0, 1])) |> ignore
        None
      })
      r.compute(store_fn.call([]).compute(16, workgroup_size=[8]))
      // several compute nodes in one call
      r.compute_list([compute, store_fn.call([]).compute(4)])
      // readback
      let attribute = @nodes.StorageBufferNode::of(positions).unwrap().storage_attribute
      r.get_array_buffer_async(Buffer(attribute), fn(buffer) {
        env.note("readback", buffer.get("byteLength"))
        let rt = @core.RenderTarget::new(width=4, height=4)
        r.set_render_target(Some(rt))
        r.render(box_scene(), camera())
        r.set_render_target(None)
        r.read_render_target_pixels_async(rt, 0, 0, 2, 2, fn(pixels) {
          let p = pixels.unwrap()
          env.note("pixels", @core.JsValue::of([@core.JsValue::of(p.type_name()), @core.JsValue::of(p.length())]))
          let frt = @core.RenderTarget::new(width=4, height=4, type_=@core.FloatType)
          r.set_render_target(Some(frt))
          r.render(box_scene(), camera())
          r.set_render_target(None)
          r.read_render_target_pixels_async(frt, 1, 1, 3, 2, fn(pixels) {
            let p = pixels.unwrap()
            env.note("fpixels", @core.JsValue::of([@core.JsValue::of(p.type_name()), @core.JsValue::of(p.length())]))
            done()
          })
        })
      })
    })
  })
}
