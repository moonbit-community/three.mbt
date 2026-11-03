///|
fn tick(f : () -> Unit) -> Unit {
  @webgl.set_timeout(f, 0.0)
}

///|
fn scene_data(scene : @core.Object3D) -> @core.Scene {
  match scene.kind {
    Scene(s) => s
    _ => abort("not a scene")
  }
}

///|
fn shadow_of(light : @core.Object3D) -> @core.LightShadow {
  match light.kind {
    Light(l) => l.shadow.unwrap()
    _ => abort("not a light")
  }
}

///|
fn opt_double(v : Double?) -> @core.JsValue {
  match v {
    Some(d) => @core.JsValue::of(d)
    None => @core.JsValue::undefined()
  }
}

///|
fn register_other() -> Unit {
  scenario("bundles", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let scene = @core.Scene::new()
      let group = @nodes.BundleGroup::new()
      group.add(@core.Mesh::new(geometry=@geometries.BoxGeometry::new(), material=Single(@nodes.MeshBasicNodeMaterial::new()))) |> ignore
      let m2 = @core.Mesh::new(geometry=@geometries.SphereGeometry::new(radius=0.5, width_segments=6.0, height_segments=4.0), material=Single(@nodes.MeshBasicNodeMaterial::new()))
      m2.position.x = 1.0
      group.add(m2) |> ignore
      scene.add(group) |> ignore
      scene.add(@core.Mesh::new(geometry=@geometries.PlaneGeometry::new(), material=Single(@nodes.MeshBasicNodeMaterial::new()))) |> ignore
      let cam = camera()
      r.render(scene, cam)
      r.render(scene, cam)
      @nodes.BundleGroup::set_needs_update(group, true)
      r.render(scene, cam)
      done()
    })
  })
  scenario("timestamps", fn(env, done) {
    let r = @webgpu.WebGPURenderer::new(canvas=env.canvas, track_timestamp=true)
    r.init(on_done=fn(_) {
      let cam = camera()
      r.render(box_scene(), cam)
      let values = @nodes.instanced_array(4, type_="float")
      let c = @nodes.fn_(fn(_, _) {
        values.element(@nodes.instance_index).assign(1)
        None
      }).call([]).compute(4)
      r.compute(c)
      r.resolve_timestamps_async(type_="render", fn(t1) {
        env.note("render", opt_double(t1))
        r.resolve_timestamps_async(type_="compute", fn(t2) {
          env.note("compute", opt_double(t2))
          r.render(box_scene(), cam)
          r.render(box_scene(), cam)
          r.resolve_timestamps_async(fn(t3) {
            env.note("render2", opt_double(t3))
            env.note("frames", @core.JsValue::of(r.backend.get_timestamp_frames("render")))
            done()
          })
        })
      })
    })
  })
  scenario("occlusion", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let scene = @core.Scene::new()
      let a = @core.Mesh::new(geometry=@geometries.BoxGeometry::new(), material=Single(@nodes.MeshBasicNodeMaterial::new()))
      @nodes.set_occlusion_test(a, true)
      scene.add(a) |> ignore
      let b = @core.Mesh::new(geometry=@geometries.PlaneGeometry::new(), material=Single(@nodes.MeshBasicNodeMaterial::new()))
      scene.add(b) |> ignore
      let c = @core.Mesh::new(geometry=@geometries.PlaneGeometry::new(), material=Single(@nodes.MeshBasicNodeMaterial::new()))
      @nodes.set_occlusion_test(c, true)
      c.position.z = -1.0
      scene.add(c) |> ignore
      let cam = camera()
      r.render(scene, cam)
      r.render(scene, cam)
      tick(fn() {
        env.note("occluded", @core.JsValue::of([r.is_occluded(a), r.is_occluded(b), r.is_occluded(c)]))
        @nodes.set_occlusion_test(a, false)
        @nodes.set_occlusion_test(c, false)
        r.render(scene, cam)
        r.render(scene, cam)
        done()
      })
    })
  })
  scenario("shadows", fn(env, done) {
    let r = renderer(env)
    r.shadow_map.enabled = true
    r.init(on_done=fn(_) {
      let scene = @core.Scene::new()
      let dl = @core.DirectionalLight::new(color=@math.Color::from_hex(0xffffff), intensity=1.0)
      dl.position.set(2.0, 3.0, 1.0) |> ignore
      dl.cast_shadow = true
      shadow_of(dl).map_size.set(16.0, 16.0) |> ignore
      scene.add(dl) |> ignore
      let spot = @core.SpotLight::new(color=@math.Color::from_hex(0xffffff), intensity=2.0)
      spot.position.set(-2.0, 3.0, 1.0) |> ignore
      spot.cast_shadow = true
      shadow_of(spot).map_size.set(8.0, 8.0) |> ignore
      scene.add(spot) |> ignore
      let point = @core.PointLight::new(color=@math.Color::from_hex(0xffffff), intensity=2.0)
      point.position.set(0.0, 2.0, 2.0) |> ignore
      point.cast_shadow = true
      shadow_of(point).map_size.set(8.0, 8.0) |> ignore
      scene.add(point) |> ignore
      let box = @core.Mesh::new(geometry=@geometries.BoxGeometry::new(), material=Single(@nodes.MeshStandardNodeMaterial::new()))
      box.cast_shadow = true
      box.receive_shadow = true
      scene.add(box) |> ignore
      let plane = @core.Mesh::new(geometry=@geometries.PlaneGeometry::new(width=4.0, height=4.0), material=Single(@nodes.MeshStandardNodeMaterial::new()))
      plane.position.y = -1.0
      plane.receive_shadow = true
      scene.add(plane) |> ignore
      let cam = camera()
      r.render(scene, cam)
      r.render(scene, cam)
      done()
    })
  })
  scenario("background_env", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let scene = box_scene()
      scene_data(scene).background = Some(Color(@math.Color::from_hex(0x112233)))
      let cam = camera()
      r.render(scene, cam)
      let data = @core.TypedArray::uint8(8 * 4 * 4)
      for i = 0; i < data.length(); i = i + 1 {
        data.set(i, (i * 13 % 255).to_double())
      }
      let env_tex = @core.DataTexture::new(data~, width=8, height=4)
      env_tex.mapping = @core.EquirectangularReflectionMapping
      env_tex.set_needs_update(true)
      let scene2 = @core.Scene::new()
      scene_data(scene2).environment = Some(env_tex)
      if env.name == "background_texture" {
        scene_data(scene2).background = Some(Texture(env_tex))
      }
      let m = @nodes.MeshStandardNodeMaterial::new()
      m.roughness = Some(0.5)
      scene2.add(@core.Mesh::new(geometry=@geometries.SphereGeometry::new(radius=0.5, width_segments=8.0, height_segments=6.0), material=Single(m))) |> ignore
      r.render(scene2, cam)
      done()
    })
  })
  scenarios["background_texture"] = scenarios["background_env"]
  scenario("postprocessing", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let scene = box_scene()
      let cam = camera()
      let pp = @nodes.RenderPipeline::new(r)
      let scene_pass = @nodes.pass(scene, cam)
      pp.output_node = scene_pass.mul(0.5)
      pp.render()
      pp.render()
      done()
    })
  })
  scenario("clearing", fn(env, done) {
    let r = @webgpu.WebGPURenderer::new(canvas=env.canvas, stencil=true)
    r.init(on_done=fn(_) {
      r.auto_clear = false
      r.set_clear_color_hex(0x336699, alpha=0.5)
      r.clear()
      r.clear_color()
      r.clear_depth()
      r.clear_stencil()
      r.clear(color=true, depth=false, stencil=true)
      r.render(box_scene(), camera())
      let depth_texture = @core.DepthTexture::new(width=4, height=4)
      let rt = @core.RenderTarget::new(width=4, height=4, stencil_buffer=true, depth_texture~)
      depth_texture.format = @core.DepthStencilFormat
      depth_texture.type_ = @core.UnsignedInt248Type
      r.set_render_target(Some(rt))
      r.clear()
      r.set_clear_color_hex(0xff0000, alpha=1.0)
      r.clear(color=true, depth=true, stencil=false)
      r.render(box_scene(), camera())
      r.set_render_target(None)
      r.auto_clear = true
      r.set_clear_alpha(0.25)
      r.render(box_scene(), camera())
      done()
    })
  })
  scenario("resize", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let scene = box_scene()
      let cam = camera()
      r.render(scene, cam)
      r.set_size(8.0, 6.0, update_style=false)
      r.render(scene, cam)
      r.set_pixel_ratio(2.0)
      r.render(scene, cam)
      r.set_viewport(1.0, 1.0, 2.0, 2.0)
      r.set_scissor(0.0, 0.0, 3.0, 3.0)
      r.set_scissor_test(true)
      r.render(scene, cam)
      done()
    })
  })
  scenario("dispose", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let scene = @core.Scene::new()
      let geo = @geometries.BoxGeometry::new()
      let mat = @nodes.MeshBasicNodeMaterial::new()
      let tex = data_tex("Uint8Array", 4, @core.RGBAFormat, @core.UnsignedByteType)
      mat.map = Some(tex)
      let mesh = @core.Mesh::new(geometry=geo, material=Single(mat))
      scene.add(mesh) |> ignore
      let cam = camera()
      let rt = @core.RenderTarget::new(width=4, height=4, samples=4)
      r.set_render_target(Some(rt))
      r.render(scene, cam)
      r.set_render_target(None)
      r.render(scene, cam)
      tex.dispose()
      geo.dispose()
      mat.dispose()
      rt.dispose()
      r.render(scene, cam)
      scene.remove(mesh) |> ignore
      r.render(scene, cam)
      r.dispose(on_done=done)
    })
  })
  scenario("compile_async", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let scene = box_scene()
      scene.add(@core.Mesh::new(geometry=@geometries.SphereGeometry::new(radius=0.5, width_segments=6.0, height_segments=4.0), material=Single(@nodes.MeshPhongNodeMaterial::new()))) |> ignore
      let cam = camera()
      r.compile_async(scene, cam, on_done=fn() {
        r.render(scene, cam)
        done()
      })
    })
  })
  scenario("pipeline_errors", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let cam = camera()
      r.render(box_scene(), cam)
      tick(fn() {
        let scene = box_scene()
        r.compile_async(scene, cam, on_done=fn() {
          r.render(scene, cam)
          done()
        })
      })
    })
  })
  scenario("compatibility", fn(env, done) {
    let r = renderer(env, antialias=true)
    r.init(on_done=fn(_) {
      env.note("compatibilityMode", @core.JsValue::of(@webgpu.WebGPUBackend::of(r.backend).unwrap().compatibility_mode.unwrap()))
      let scene = box_scene()
      let depth_texture = @core.DepthTexture::new(width=4, height=4)
      let rt = @core.RenderTarget::new(width=4, height=4, depth_texture~, count=2)
      r.set_render_target(Some(rt))
      r.render(scene, camera())
      r.set_render_target(None)
      let m = @nodes.MeshBasicNodeMaterial::new()
      m.map = Some(depth_texture)
      scene.add(@core.Mesh::new(geometry=@geometries.PlaneGeometry::new(), material=Single(m))) |> ignore
      r.render(scene, camera())
      done()
    })
  })
  scenario("features", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      env.note("features", @core.JsValue::of([r.has_feature("float32-filterable"), r.has_feature("texture-compression-s3tc"), r.has_feature("timestamp-query")]))
      let f = data_tex("Float32Array", 4, @core.RGBAFormat, @core.FloatType)
      let n = data_tex("Int16Array", 4, @core.RGBAFormat, @core.ShortType)
      n.normalized = true
      let ds = @core.DepthTexture::new(width=4, height=4)
      ds.format = @core.DepthStencilFormat
      ds.type_ = @core.FloatType
      let scene = @core.Scene::new()
      for t in [f, n] {
        let m = @nodes.MeshBasicNodeMaterial::new()
        m.map = Some(t)
        scene.add(@core.Mesh::new(geometry=@geometries.PlaneGeometry::new(), material=Single(m))) |> ignore
      }
      let rt = @core.RenderTarget::new(width=4, height=4, depth_texture=ds, stencil_buffer=true)
      r.set_render_target(Some(rt))
      r.render(scene, camera())
      done()
    })
  })
}

///|
extern "js" fn mock_lose_device(mock : @core.JsValue, device : @core.JsValue) -> Unit = "(m, d) => { m.uncapturedError( d, 'mock uncaptured' ); m.loseDevice( d, 'unknown', 'mock loss' ); }"

///|
fn register_device_lost() -> Unit {
  scenario("device_lost", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      r.render(box_scene(), camera())
      mock_lose_device(env.raw.get("mock"), r.backend.device())
      tick(fn() {
        env.note("lost", @core.JsValue::of(r._is_device_lost == true))
        done()
      })
    })
  })
}

///|
fn register_no_adapter() -> Unit {
  scenario("no_adapter", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(error) {
      env.note(
        "init",
        @core.JsValue::of([
          match error {
            Some(_) => @core.JsValue::of("rejected")
            None => @core.JsValue::null()
          },
          @core.JsValue::of(r.backend.has_flag("isWebGLBackend")),
        ]),
      )
      done()
    })
  })
}
