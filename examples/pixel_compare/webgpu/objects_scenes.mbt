// The objects add-on scenes of the WebGPU pixel comparison (the WebGPU variants of
// examples/jsm/objects), mirroring webgpu_objects_scenes.js line for line; `build_addon`
// falls through to `build_objects_addon`, and `load_objects_addons` mirrors the module
// imports of `OBJECTS_ADDON_MODULES`.

///|
let objects_scene_names : Array[String] = [
  "addon_sky_mesh", "addon_water_mesh", "addon_water2_mesh", "addon_lensflare_mesh",
]

///|
/// The modules of `OBJECTS_ADDON_MODULES`: only LensflareMesh.js creates something when
/// it loads (its geometry). False for other scenes.
fn load_objects_addons(name : String) -> Bool {
  match name {
    "addon_sky_mesh" | "addon_water_mesh" | "addon_water2_mesh" => ()
    "addon_lensflare_mesh" => @objects.load_lensflare_mesh()
    _ => return false
  }
  true
}

///|
fn objects_camera(
  x : Double,
  y : Double,
  z : Double,
  tx : Double,
  ty : Double,
  tz : Double,
) -> @three.Object3D {
  let c = @three.PerspectiveCamera::new(
    fov=50.0,
    aspect=WIDTH.to_double() / HEIGHT.to_double(),
    near=0.1,
    far=100.0,
  )
  c.position.set(x, y, z) |> ignore
  c.look_at_xyz(tx, ty, tz)
  c
}

///|
/// `patternTexture( THREE, size, seed )`.
fn objects_pattern_texture(size : Int32, seed : Int32) -> @three.Texture {
  let data = @three.TypedArray::uint8(size * size * 4)
  for y in 0..<size {
    for x in 0..<size {
      let i = (y * size + x) * 4
      data[i] = ((x * 37 + y * 11 + seed) % 256).to_double()
      data[i + 1] = ((x * 13 + y * 29 + seed * 3) % 256).to_double()
      data[i + 2] = (160 + (x + y + seed) % 4 * 24).to_double()
      data[i + 3] = 255.0
    }
  }
  let texture = @three.DataTexture::new(data~, width=size, height=size)
  texture.set_needs_update(true)
  texture
}

///|
/// A lit box above the origin.
fn objects_add_box(scene : @three.Object3D, hex : Int32) -> Unit {
  scene.add(
    @three.AmbientLight::new(
      color=@three.Color::from_hex(0x404040),
      intensity=1.0,
    ),
  )
  |> ignore
  let light = @three.DirectionalLight::new(
    color=@three.Color::from_hex(0xffffff),
    intensity=2.0,
  )
  light.position.set(1.0, 3.0, 2.0) |> ignore
  scene.add(light) |> ignore
  let box = mesh(
    @three.BoxGeometry::new(width=0.8, height=0.8, depth=0.8),
    colored(@three.MeshStandardNodeMaterial::new(), hex),
  )
  box.position.set(-0.3, 0.6, 0.0) |> ignore
  box.rotation.set(0.0, 0.6, 0.0) |> ignore
  scene.add(box) |> ignore
}

///|
fn build_objects_addon(name : String) -> View? {
  let scene = @three.Scene::new()
  match name {
    "addon_sky_mesh" => {
      let sky = @objects.SkyMesh::new()
      sky.scale.set_scalar(50.0) |> ignore
      let s = @objects.SkyMesh::of(sky).unwrap()
      @three.InputNode::set_value(s.turbidity, Number(10.0))
      @three.InputNode::set_value(s.rayleigh, Number(2.5))
      match @three.InputNode::get_value(s.sun_position) {
        Vector3(v) => v.set(0.2, 0.15, -1.0) |> ignore
        _ => abort("sunPosition")
      }
      @three.InputNode::set_value(s.cloud_coverage, Number(0.5))
      scene.add(sky) |> ignore
      Some(view(scene, objects_camera(0.0, 0.5, 0.0, 0.0, 0.9, -3.0)))
    }
    "addon_water_mesh" => {
      scene.as_scene().background = Some(
        Color(@three.Color::from_hex(0x6688aa)),
      )
      objects_add_box(scene, 0xcc6633)
      let normals = objects_pattern_texture(16, 5)
      normals.wrap_s = @three.RepeatWrapping
      normals.wrap_t = @three.RepeatWrapping
      let water = @objects.WaterMesh::new(
        Some(@three.PlaneGeometry::new(width=20.0, height=20.0)),
        water_normals=normals,
        sun_direction=@three.Vector3::new(0.3, 0.9, 0.2).normalize(),
        sun_color=0xffffff,
        water_color=0x001e0f,
        distortion_scale=3.7,
      )
      water.rotation.set(-js_pi() / 2.0, 0.0, 0.0) |> ignore
      scene.add(water) |> ignore
      Some(view(scene, objects_camera(0.0, 1.5, 4.0, 0.0, 0.0, 0.0)))
    }
    "addon_water2_mesh" => {
      scene.as_scene().background = Some(
        Color(@three.Color::from_hex(0x335577)),
      )
      objects_add_box(scene, 0x44aa66)
      let ground = mesh(
        @three.PlaneGeometry::new(width=20.0, height=20.0),
        colored(@three.MeshStandardNodeMaterial::new(), 0x997755),
      )
      ground.rotation.set(-js_pi() / 2.0, 0.0, 0.0) |> ignore
      ground.position.set(0.0, -0.5, 0.0) |> ignore
      scene.add(ground) |> ignore
      let water = @objects.Water2Mesh::new(
        Some(@three.PlaneGeometry::new(width=6.0, height=6.0)),
        color=0xaaccff,
        scale=2.0,
        flow_direction=@three.Vector2::new(1.0, 0.5),
        normal_map0=objects_pattern_texture(16, 7),
        normal_map1=objects_pattern_texture(16, 11),
      )
      water.rotation.set(-js_pi() / 2.0, 0.0, 0.0) |> ignore
      scene.add(water) |> ignore
      Some(view(scene, objects_camera(0.0, 2.0, 4.0, 0.0, 0.0, 0.0)))
    }
    "addon_lensflare_mesh" => {
      objects_add_box(scene, 0x3366cc)
      let flare_light = @three.Object3D::new()
      flare_light.position.set(0.8, 0.6, -2.0) |> ignore
      scene.add(flare_light) |> ignore
      let flare = @objects.LensflareMesh::new()
      @objects.LensflareMesh::add_element(
        flare,
        @objects.LensflareElement::new(
          objects_pattern_texture(8, 1),
          size=40.0,
          distance=0.0,
          color=@three.Color::from_hex(0xffeecc),
        ),
      )
      @objects.LensflareMesh::add_element(
        flare,
        @objects.LensflareElement::new(
          objects_pattern_texture(4, 2),
          size=16.0,
          distance=0.5,
        ),
      )
      @objects.LensflareMesh::add_element(
        flare,
        @objects.LensflareElement::new(
          objects_pattern_texture(8, 3),
          size=24.0,
          distance=0.9,
          color=@three.Color::from_hex(0x6688ff),
        ),
      )
      flare_light.add(flare) |> ignore
      Some(view(scene, objects_camera(0.0, 0.5, 3.0, 0.0, 0.0, 0.0)))
    }
    _ => None
  }
}
