// The objects add-on scenes of the classic pixel comparison (examples/jsm/objects on
// WebGLRenderer), mirroring objects_scenes.js line for line; `build` falls through to
// `build_objects_addon` for them.

///|
let objects_scene_names : Array[String] = [
  "addon_reflector", "addon_refractor", "addon_sky_water", "addon_lensflare_cubes",
]

///|
/// `patternTexture( THREE, size, seed )`.
fn pattern_texture(size : Int32, seed : Int32) -> @core.Texture {
  let data = @core.TypedArray::new(Uint8Array, size * size * 4)
  for y in 0..<size {
    for x in 0..<size {
      let i = (y * size + x) * 4
      data.set(i, ((x * 37 + y * 11 + seed) % 256).to_double())
      data.set(i + 1, ((x * 13 + y * 29 + seed * 3) % 256).to_double())
      data.set(i + 2, (160 + (x + y + seed) % 4 * 24).to_double())
      data.set(i + 3, 255.0)
    }
  }
  let texture = @core.DataTexture::new(data~, width=size, height=size)
  texture.set_needs_update(true)
  texture
}

///|
fn add_object_scene_lights(scene : @core.Object3D) -> Unit {
  scene.add(
    @core.AmbientLight::new(
      color=@math.Color::from_hex(0x404040),
      intensity=1.0,
    ),
  )
  |> ignore
  let light = @core.DirectionalLight::new(
    color=@math.Color::from_hex(0xffffff),
    intensity=2.0,
  )
  light.position.set(1.0, 3.0, 2.0) |> ignore
  scene.add(light) |> ignore
}

///|
fn build_objects_addon(
  name : String,
  renderer : @webgl.WebGLRenderer,
  scene : @core.Object3D,
) -> (@core.Object3D, @core.Object3D)? {
  match name {
    "addon_reflector" => {
      add_object_scene_lights(scene)
      let box = mesh(
        @geometries.BoxGeometry::new(width=0.8, height=0.8, depth=0.8),
        color(@core.MeshStandardMaterial::new(), 0x3366cc),
      )
      box.position.set(-0.5, 0.5, 0.0) |> ignore
      box.rotation.set(0.0, 0.6, 0.0) |> ignore
      scene.add(box) |> ignore
      let ball = mesh(
        @geometries.SphereGeometry::new(
          radius=0.35,
          width_segments=32.0,
          height_segments=16.0,
        ),
        color(@core.MeshPhongMaterial::new(), 0xff8833),
      )
      ball.position.set(0.6, 0.4, 0.3) |> ignore
      scene.add(ball) |> ignore
      let mirror = @objects.Reflector::new(
        geometry=@geometries.PlaneGeometry::new(width=4.0, height=4.0),
        clip_bias=0.003,
        texture_width=WIDTH,
        texture_height=HEIGHT,
        color=0xb0b0b0,
      )
      mirror.rotation.set(-pi / 2.0, 0.0, 0.0) |> ignore
      scene.add(mirror) |> ignore
      Some((scene, camera_at(0.0, 1.5, 3.5)))
    }
    "addon_refractor" => {
      let colors = [0xcc3333, 0x33cc33, 0x3333cc]
      for i in 0..<3 {
        let box = mesh(
          @geometries.BoxGeometry::new(width=0.6, height=0.6, depth=0.6),
          color(@core.MeshBasicMaterial::new(), colors[i]),
        )
        box.position.set((i - 1).to_double(), (i - 1).to_double() * 0.3, -1.5)
        |> ignore
        scene.add(box) |> ignore
      }
      let pane = @objects.Refractor::new(
        geometry=@geometries.PlaneGeometry::new(width=2.4, height=1.6),
        color=0xcccccc,
        texture_width=WIDTH,
        texture_height=HEIGHT,
        multisample=0,
      )
      pane.rotation.set(0.0, 0.15, 0.0) |> ignore
      scene.add(pane) |> ignore
      Some((scene, camera_at(0.3, 0.2, 3.0)))
    }
    "addon_sky_water" => {
      renderer.tone_mapping = @core.ACESFilmicToneMapping
      renderer.tone_mapping_exposure = 0.5
      let sky = @objects.Sky::new()
      sky.scale.set_scalar(1000.0) |> ignore
      let u = match sky.kind {
        Mesh({ material: Single(m), .. }) => m.uniforms.unwrap()
        _ => abort("not a mesh")
      }
      u["turbidity"].value = Number(10.0)
      u["rayleigh"].value = Number(2.0)
      match u["sunPosition"].value {
        Vector3(v) => v.set(0.3, 0.05, -0.95) |> ignore
        _ => abort("sunPosition")
      }
      scene.add(sky) |> ignore
      let normals = pattern_texture(16, 5)
      normals.wrap_s = @core.RepeatWrapping
      normals.wrap_t = @core.RepeatWrapping
      let water = @objects.Water::new(
        geometry=@geometries.PlaneGeometry::new(width=100.0, height=100.0),
        texture_width=WIDTH,
        texture_height=HEIGHT,
        water_normals=normals,
        sun_direction=@math.Vector3::new(0.3, 0.05, -0.95).normalize(),
        sun_color=0xffffff,
        water_color=0x001e0f,
        distortion_scale=3.7,
      )
      water.rotation.set(-pi / 2.0, 0.0, 0.0) |> ignore
      scene.add(water) |> ignore
      let camera = @core.PerspectiveCamera::new(
        fov=55.0,
        aspect=WIDTH.to_double() / HEIGHT.to_double(),
        near=1.0,
        far=2000.0,
      )
      camera.position.set(0.0, 5.0, 20.0) |> ignore
      camera.look_at_xyz(0.0, 2.0, 0.0)
      Some((scene, camera))
    }
    "addon_lensflare_cubes" => {
      add_object_scene_lights(scene)
      let cubes_object = @objects.MarchingCubes::new(
        24,
        Some(color(@core.MeshPhongMaterial::new(), 0x88aa44)),
        enable_uvs=false,
        enable_colors=false,
        max_poly_count=20000,
      )
      let cubes = @objects.MarchingCubes::of(cubes_object).unwrap()
      cubes.isolation = 50.0
      cubes.add_ball(0.45, 0.5, 0.5, 0.6, 12.0)
      cubes.add_ball(0.6, 0.55, 0.45, 0.4, 12.0)
      cubes.add_plane_y(2.0, 12.0)
      cubes.update()
      cubes_object.position.set(-0.4, 0.0, 0.0) |> ignore
      cubes_object.scale.set_scalar(0.8) |> ignore
      scene.add(cubes_object) |> ignore
      let flare_light = @core.Object3D::new()
      flare_light.position.set(0.8, 0.6, -2.0) |> ignore
      scene.add(flare_light) |> ignore
      let flare = @objects.Lensflare::new()
      @objects.Lensflare::add_element(
        flare,
        @objects.LensflareElement::new(
          pattern_texture(8, 1),
          size=40.0,
          distance=0.0,
          color=@math.Color::from_hex(0xffeecc),
        ),
      )
      @objects.Lensflare::add_element(
        flare,
        @objects.LensflareElement::new(
          pattern_texture(4, 2),
          size=16.0,
          distance=0.5,
        ),
      )
      @objects.Lensflare::add_element(
        flare,
        @objects.LensflareElement::new(
          pattern_texture(8, 3),
          size=24.0,
          distance=0.9,
          color=@math.Color::from_hex(0x6688ff),
        ),
      )
      flare_light.add(flare) |> ignore
      Some((scene, camera_at(0.0, 0.5, 3.0)))
    }
    _ => None
  }
}
