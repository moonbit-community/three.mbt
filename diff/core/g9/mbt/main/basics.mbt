///|
fn renderer(env : Env, antialias? : Bool = false) -> @nodes.Renderer {
  @webgpu.WebGPURenderer::new(canvas=env.canvas, antialias~)
}

///|
fn camera() -> @core.Object3D {
  let camera = @core.PerspectiveCamera::new(fov=50.0, aspect=1.0, near=0.1, far=10.0)
  camera.position.z = 3.0
  camera
}

///|
fn register_basics() -> Unit {
  scenario("init", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) { done() })
  })
  scenario("smoke", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let scene = @core.Scene::new()
      let material = @nodes.MeshBasicNodeMaterial::new()
      material.color.unwrap().set_hex(0xff0000) |> ignore
      scene.add(@core.Mesh::new(geometry=@geometries.BoxGeometry::new(), material=Single(material))) |> ignore
      r.render(scene, camera())
      done()
    })
  })
}

///|
fn lights(scene : @core.Object3D) -> Unit {
  scene.add(@core.AmbientLight::new(color=@math.Color::from_hex(0x404040), intensity=1.0)) |> ignore
  let dl = @core.DirectionalLight::new(color=@math.Color::from_hex(0xffffff), intensity=2.0)
  dl.position.set(1.0, 2.0, 3.0) |> ignore
  scene.add(dl) |> ignore
  let pl = @core.PointLight::new(color=@math.Color::from_hex(0xff8800), intensity=3.0, distance=10.0, decay=2.0)
  pl.position.set(-1.0, 1.0, 2.0) |> ignore
  scene.add(pl) |> ignore
  scene.add(@core.HemisphereLight::new(sky_color=@math.Color::from_hex(0x8888ff), ground_color=@math.Color::from_hex(0x442200), intensity=0.5)) |> ignore
}

///|
fn position_geometry(values : Array[Double]) -> @core.BufferGeometry {
  let geo = @core.BufferGeometry::new()
  geo.set_attribute("position", @core.Float32BufferAttribute::new(values, 3).to_geometry_attribute()) |> ignore
  geo
}

///|
fn register_materials() -> Unit {
  scenario("materials_lit", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let scene = @core.Scene::new()
      lights(scene)
      let geo = @geometries.SphereGeometry::new(radius=0.5, width_segments=8.0, height_segments=6.0)
      let mats = [
        @nodes.MeshStandardNodeMaterial::new(), @nodes.MeshPhysicalNodeMaterial::new(),
        @nodes.MeshPhongNodeMaterial::new(), @nodes.MeshLambertNodeMaterial::new(),
        @nodes.MeshToonNodeMaterial::new(),
      ]
      for i, m in mats {
        m.color.unwrap().set_hex(0x3366cc) |> ignore
        let mesh = @core.Mesh::new(geometry=geo, material=Single(m))
        mesh.position.x = (i - 2).to_double()
        scene.add(mesh) |> ignore
      }
      r.render(scene, camera())
      done()
    })
  })
  scenario("materials_unlit", fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let scene = @core.Scene::new()
      let geo = @geometries.BoxGeometry::new()
      let normal = @core.Mesh::new(geometry=geo, material=Single(@nodes.MeshNormalNodeMaterial::new()))
      normal.position.x = -1.0
      scene.add(normal) |> ignore
      scene.add(@core.Mesh::new(geometry=geo, material=Single(@nodes.MeshMatcapNodeMaterial::new()))) |> ignore
      let line_geo = position_geometry([0.0, 0, 0, 1, 1, 0, 1, 0, 0])
      scene.add(@core.Line::new(geometry=line_geo, material=Single(@nodes.LineBasicNodeMaterial::new()))) |> ignore
      scene.add(@core.LineSegments::new(geometry=line_geo, material=Single(@nodes.LineBasicNodeMaterial::new()))) |> ignore
      let points = @nodes.PointsNodeMaterial::new()
      points.size = Some(2.0)
      scene.add(@core.Points::new(geometry=line_geo, material=Single(points))) |> ignore
      let sprite = @core.Sprite::new(material=@nodes.SpriteNodeMaterial::new())
      sprite.position.y = 1.0
      scene.add(sprite) |> ignore
      let transparent = @nodes.MeshBasicNodeMaterial::new()
      transparent.transparent = true
      transparent.opacity = 0.5
      scene.add(@core.Mesh::new(geometry=geo, material=Single(transparent))) |> ignore
      let additive = @nodes.MeshBasicNodeMaterial::new()
      additive.blending = @core.AdditiveBlending
      additive.side = @core.DoubleSide
      scene.add(@core.Mesh::new(geometry=geo, material=Single(additive))) |> ignore
      let custom = @nodes.MeshBasicNodeMaterial::new()
      custom.blending = @core.CustomBlending
      custom.blend_src = @core.ConstantColorFactor
      custom.blend_dst = @core.OneMinusSrcColorFactor
      custom.blend_equation = @core.ReverseSubtractEquation
      custom.blend_color.set_rgb(0.25, 0.5, 0.75) |> ignore
      custom.blend_alpha = 0.5
      custom.side = @core.BackSide
      scene.add(@core.Mesh::new(geometry=geo, material=Single(custom))) |> ignore
      let premultiplied = @nodes.MeshBasicNodeMaterial::new()
      premultiplied.blending = @core.MultiplyBlending
      premultiplied.premultiplied_alpha = true
      scene.add(@core.Mesh::new(geometry=geo, material=Single(premultiplied))) |> ignore
      r.render(scene, camera())
      done()
    })
  })
}
