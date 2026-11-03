// The MoonBit half of the a6 objects mock-GPU scenarios (../gpu/scenarios.mjs), step for step.

///|
extern "js" fn env_note(
  env : @core.JsValue,
  label : String,
  value : @core.JsValue,
) -> Unit = "(e, l, v) => e.note( l, v )"

///|
fn[T] js(v : T) -> @core.JsValue {
  @core.JsValue::of(v)
}

///|
fn align() -> Unit {
  fn advance(name : String, target : Int32, f : () -> Int32) -> Unit {
    let mut id = f()
    if id >= target {
      abort("counter \{name} already at \{id}")
    }
    while id < target - 1 {
      id = f()
    }
  }

  advance("node", 20000, fn() { @nodes.Node::alloc().id })
  advance("object3d", 1000, fn() { @core.Object3D::new().id })
  advance("material", 1000, fn() { @core.Material::new().id })
  advance("texture", 1000, fn() { @core.Texture::new().id })
  advance("attribute", 1000, fn() {
    @core.BufferAttribute::new(@core.TypedArray::float32(1), 1).id
  })
  advance("geometry", 1000, fn() { @core.BufferGeometry::new().id })
}

///|
let pi : Double = 3.141592653589793

///|
fn data_texture(w : Int32, h : Int32, seed : Int32) -> @core.Texture {
  let data = @core.TypedArray::uint8(w * h * 4)
  for i in 0..<data.length() {
    data[i] = ((i * seed + 3) % 256).to_double()
  }
  let t = @core.DataTexture::new(data~, width=w, height=h)
  t.set_needs_update(true)
  t
}

///|
fn camera(x : Double, y : Double, z : Double) -> @core.Object3D {
  let c = @core.PerspectiveCamera::new(fov=50, aspect=2, near=0.1, far=1000)
  c.position.set(x, y, z) |> ignore
  c.look_at(@math.Vector3::new(0, 0, 0))
  c
}

///|
fn standard(hex : Int32) -> @core.Material {
  let m = @nodes.MeshStandardNodeMaterial::new()
  m.color.unwrap().set_hex(hex) |> ignore
  m
}

///|
fn material_of(o : @core.Object3D) -> @core.Material {
  match o.kind {
    Mesh({ material: Single(m), .. }) => m
    _ => abort("not a mesh")
  }
}

///|
fn vector3_of(node : @nodes.Node) -> @math.Vector3 {
  match @nodes.InputNode::get_value(node) {
    Vector3(v) => v
    _ => abort("not a Vector3 uniform")
  }
}

///|
fn flow_config(water : @core.Object3D) -> @core.JsValue {
  let color_node = @nodes.NodeMaterial::of(material_of(water)).unwrap().color_node.unwrap()
  js(
    vector3_of(@objects.WaterNode::of(color_node).unwrap().flow_config).to_array(),
  )
}

///|
pub fn run_scenario(
  name : String,
  env : @core.JsValue,
  done : () -> Unit,
) -> Unit {
  // the add-on modules, in the app's import order, before the counters are aligned
  @objects.load_lensflare_mesh()
  align()
  let canvas = env.get("canvas")
  let note = fn(label : String, value : Array[@core.JsValue]) {
    env_note(env, label, js(value))
  }
  let r = @webgpu.WebGPURenderer::new(canvas~)
  r.init(on_done=fn(_) {
    match name {
      "sky_mesh" => {
        r.tone_mapping = @core.ACESFilmicToneMapping
        let scene = @core.Scene::new()
        let sky = @objects.SkyMesh::new()
        sky.scale.set_scalar(450) |> ignore
        let s = @objects.SkyMesh::of(sky).unwrap()
        @nodes.InputNode::set_value(s.turbidity, Number(8))
        @nodes.InputNode::set_value(s.rayleigh, Number(1.5))
        vector3_of(s.sun_position).set_from_spherical_coords(1, 1.2, 0.4)
        |> ignore
        @nodes.InputNode::set_value(s.cloud_coverage, Number(0.6))
        scene.add(sky) |> ignore
        let m = material_of(sky)
        note("sky", [
          js(sky.type_),
          js(sky.has_extension_flag("isSkyMesh")),
          js(m.side),
          js(m.depth_write),
          js(m.fog.unwrap()),
        ])
        let cam = camera(0, 1, 5)
        r.render(scene, cam)
        @nodes.InputNode::set_value(s.show_sun_disc, Number(0))
        r.render(scene, cam)
      }
      "water_mesh" => {
        let scene = @core.Scene::new()
        scene.as_scene().background = Some(
          Color(@math.Color::from_hex(0x334455)),
        )
        scene.add(
          @core.DirectionalLight::new(
            color=@math.Color::from_hex(0xffffff),
            intensity=2,
          ),
        )
        |> ignore
        let box = @core.Mesh::new(
          geometry=@geometries.BoxGeometry::new(width=1, height=1, depth=1),
          material=Single(standard(0xcc6633)),
        )
        box.position.set(0, 1, 0) |> ignore
        scene.add(box) |> ignore
        let normals = data_texture(4, 4, 37)
        normals.wrap_t = @core.RepeatWrapping
        normals.wrap_s = @core.RepeatWrapping
        let water = @objects.WaterMesh::new(
          Some(@geometries.PlaneGeometry::new(width=20, height=20)),
          water_normals=normals,
          sun_direction=@math.Vector3::new(0.3, 0.9, 0.2).normalize(),
          sun_color=0xffffff,
          water_color=0x001e0f,
          distortion_scale=3.7,
          resolution_scale=0.5,
        )
        water.rotation.set_x(-pi / 2)
        scene.add(water) |> ignore
        let w = @objects.WaterMesh::of(water).unwrap()
        note("water", [
          js(water.type_),
          js(water.has_extension_flag("isWaterMesh")),
          js(material_of(water).transparent),
          js(w.resolution_scale),
        ])
        let cam = camera(2, 3, 8)
        r.render(scene, cam)
        note("children", water.children.map(fn(c) { js(c.type_) }))
        @nodes.InputNode::set_value(w.distortion_scale, Number(1.5))
        r.render(scene, cam)
      }
      "water2_mesh" => {
        let scene = @core.Scene::new()
        scene.as_scene().background = Some(
          Color(@math.Color::from_hex(0x223344)),
        )
        scene.add(
          @core.DirectionalLight::new(
            color=@math.Color::from_hex(0xffffff),
            intensity=1,
          ),
        )
        |> ignore
        let ground = @core.Mesh::new(
          geometry=@geometries.PlaneGeometry::new(width=20, height=20),
          material=Single(standard(0x777777)),
        )
        ground.rotation.set_x(-pi / 2)
        ground.position.y = -1
        scene.add(ground) |> ignore
        let water = @objects.Water2Mesh::new(
          Some(@geometries.PlaneGeometry::new(width=10, height=10)),
          color=0xaaccff,
          scale=4,
          flow_direction=@math.Vector2::new(1, 1),
          normal_map0=data_texture(2, 2, 3),
          normal_map1=data_texture(2, 2, 5),
        )
        water.rotation.set_x(-pi / 2)
        scene.add(water) |> ignore
        let flowing = @objects.Water2Mesh::new(
          Some(@geometries.PlaneGeometry::new(width=4, height=4)),
          flow_map=data_texture(2, 2, 7),
          flow_speed=2.5,
          reflectivity=0.3,
          normal_map0=data_texture(2, 2, 9),
          normal_map1=data_texture(2, 2, 13),
        )
        flowing.rotation.set_x(-pi / 2)
        flowing.position.set(6, 0.5, 0) |> ignore
        scene.add(flowing) |> ignore
        let cam = camera(-4, 5, 8)
        for frame in 0..<3 {
          ignore(frame)
          r.render(scene, cam)
          note("flow", [flow_config(water), flow_config(flowing)])
        }
      }
      "lensflare_mesh" => {
        let scene = @core.Scene::new()
        scene.add(
          @core.DirectionalLight::new(
            color=@math.Color::from_hex(0xffffff),
            intensity=1,
          ),
        )
        |> ignore
        let box = @core.Mesh::new(
          geometry=@geometries.BoxGeometry::new(width=1, height=1, depth=1),
          material=Single(standard(0x228822)),
        )
        box.position.set(1, 0, 0) |> ignore
        scene.add(box) |> ignore
        let light = @core.Object3D::new()
        light.position.set(-0.5, 0.3, -3) |> ignore
        scene.add(light) |> ignore
        let flare = @objects.LensflareMesh::new()
        @objects.LensflareMesh::add_element(
          flare,
          @objects.LensflareElement::new(
            data_texture(2, 2, 3),
            size=32,
            distance=0,
            color=@math.Color::from_hex(0xffccaa),
          ),
        )
        @objects.LensflareMesh::add_element(
          flare,
          @objects.LensflareElement::new(
            data_texture(2, 2, 5),
            size=12,
            distance=0.6,
          ),
        )
        @objects.LensflareMesh::add_element(
          flare,
          @objects.LensflareElement::new(
            data_texture(2, 2, 7),
            size=20,
            distance=1.0,
            color=@math.Color::from_hex(0x3366ff),
          ),
        )
        light.add(flare) |> ignore
        let fm = material_of(flare)
        let geometry = match flare.kind {
          Mesh(m) => m.geometry
          _ => abort("not a mesh")
        }
        note("lensflare", [
          js(flare.type_),
          js(flare.has_extension_flag("isLensflareMesh")),
          js(flare.frustum_culled),
          js(flare.render_order),
          js(fm.opacity),
          js(physical_equal(geometry, @objects.LensflareMesh::geometry())),
        ])
        let cam = camera(0, 0, 5)
        r.render(scene, cam)
        r.render(scene, cam)
        light.position.set(0, 0, 8) |> ignore
        r.render(scene, cam)
        light.position.set(0.2, -0.1, -2) |> ignore
        let target = @core.RenderTarget::new(
          width=48,
          height=24,
          type_=@core.HalfFloatType,
        )
        r.set_render_target(Some(target))
        r.render(scene, cam)
        r.set_render_target(None)
        r.render(scene, cam)
        flare.dispose()
      }
      _ => abort("unknown scenario \{name}")
    }
    done()
  })
}

///|
fn main {

}
