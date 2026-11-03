// The MoonBit half of the WebGPU pixel comparison (webgpu.html): the scenes of
// webgpu_scenes.js, line for line, rendered with the port's WebGPURenderer into a render
// target and read back with `readRenderTargetPixelsAsync`. `@three` is the
// `moonbit-community/three/webgpu` facade, upstream's `THREE` (Three.WebGPU.js) and `TSL`
// (Three.TSL.js) in one package.

///|
const WIDTH : Int32 = 128

///|
const HEIGHT : Int32 = 96

///|
/// `Math.sin`, so the scene code computes exactly what webgpu_scenes.js computes.
extern "js" fn js_sin(x : Double) -> Double = "Math.sin"

///|
extern "js" fn js_pi() -> Double = "() => Math.PI"

///|
/// The scenes; the `addon_*` ones use the display add-ons (examples/jsm/tsl/display).
let names : Array[String] = [
  "unlit_box", "lit_spheres", "data_texture", "instancing", "lines_points", "transparent",
  "shadow_directional", "shadow_spot", "shadow_point", "pmrem_env", "cube_background",
  "post_pass", "tone_mapping", "tsl_material", "compute_instances", "msaa_target",
  "skinned_morph", "fog", "texture_formats", "sprites", "addon_fxaa", "addon_gaussian_blur",
  "addon_sobel", "addon_rgb_shift", "addon_dof", "addon_gtao", "addon_ssr", "addon_pixelation",
  "addon_ssaa",
] +
  objects_scene_names +
  a5_scene_names

///|
/// The scene names, in page order.
pub fn scene_names() -> Array[String] {
  names
}

///|
fn camera_at(x : Double, y : Double, z : Double) -> @three.Object3D {
  let camera = @three.PerspectiveCamera::new(
    fov=50.0,
    aspect=WIDTH.to_double() / HEIGHT.to_double(),
    near=0.1,
    far=100.0,
  )
  camera.position.set(x, y, z) |> ignore
  camera.look_at_xyz(0.0, 0.0, 0.0)
  camera
}

///|
fn colored(material : @three.Material, hex : Int32) -> @three.Material {
  material.color.unwrap().set_hex(hex) |> ignore
  material
}

///|
fn mesh(
  geometry : @three.BufferGeometry,
  material : @three.Material,
) -> @three.Object3D {
  @three.Mesh::new(geometry~, material=Single(material))
}

///|
/// What `render_scene` renders: the scene and camera, the render target's MSAA samples,
/// a step after `init` (`before(renderer, target)`) and a render that replaces
/// `renderer.render(scene, camera)`.
struct View {
  scene : @three.Object3D
  camera : @three.Object3D
  samples : Int32
  before : ((@three.Renderer, @three.RenderTarget) -> Unit)?
  render : ((@three.Renderer) -> Unit)?
}

///|
fn view(
  scene : @three.Object3D,
  camera : @three.Object3D,
  samples~ : Int32 = 0,
  before? : (@three.Renderer, @three.RenderTarget) -> Unit,
  render? : (@three.Renderer) -> Unit,
) -> View {
  { scene, camera, samples, before, render, }
}

///|
/// A box on a ground plane, both casting and receiving shadows.
fn shadow_stage(scene : @three.Object3D, hex : Int32) -> Unit {
  let box = mesh(
    @three.BoxGeometry::new(width=0.8, height=0.8, depth=0.8),
    colored(@three.MeshStandardNodeMaterial::new(), hex),
  )
  box.position.set(0.0, 0.4, 0.0) |> ignore
  box.rotation.set(0.0, 0.5, 0.0) |> ignore
  box.cast_shadow = true
  box.receive_shadow = true
  scene.add(box) |> ignore
  let ground = mesh(
    @three.PlaneGeometry::new(width=6.0, height=6.0),
    colored(@three.MeshStandardNodeMaterial::new(), 0xcccccc),
  )
  ground.rotation.set(-js_pi() / 2.0, 0.0, 0.0) |> ignore
  ground.receive_shadow = true
  scene.add(ground) |> ignore
  scene.add(
    @three.AmbientLight::new(
      color=@three.Color::from_hex(0x404040),
      intensity=1.0,
    ),
  )
  |> ignore
}

///|
fn enable_shadows(renderer : @three.Renderer) -> Unit {
  renderer.shadow_map.enabled = true
  renderer.shadow_map.type_ = @three.PCFShadowMap
}

///|
fn shadow_of(light : @three.Object3D) -> @three.LightShadow {
  light.as_light().shadow.unwrap()
}

///|
/// An equirectangular half-float sky: a vertical gradient with a bright sun texel.
fn sky_texture() -> @three.Texture {
  let w = 16
  let h = 8
  let data = @three.TypedArray::uint16(w * h * 4)
  for y = 0; y < h; y = y + 1 {
    for x = 0; x < w; x = x + 1 {
      let i = (y * w + x) * 4
      let t = y.to_double() / (h - 1).to_double()
      let sun = if x == 4 && y == 5 { 6.0 } else { 0.0 }
      data.set(i, @three.DataUtils::to_half_float(0.9 - 0.6 * t + sun))
      data.set(i + 1, @three.DataUtils::to_half_float(0.6 - 0.2 * t + sun))
      data.set(i + 2, @three.DataUtils::to_half_float(0.3 + 0.7 * t + sun))
      data.set(i + 3, @three.DataUtils::to_half_float(1.0))
    }
  }
  let texture = @three.DataTexture::new(
    data~,
    width=w,
    height=h,
    format=@three.RGBAFormat,
    type_=@three.HalfFloatType,
  )
  texture.mapping = @three.EquirectangularReflectionMapping
  texture.set_needs_update(true)
  texture
}

///|
/// A `size`x`size` RGBA8 DataTexture of one color, for the cube faces.
fn face_texture(
  size : Int32,
  r : Int32,
  g : Int32,
  b : Int32,
) -> @three.Texture {
  let data = @three.TypedArray::uint8(size * size * 4)
  for i = 0; i < size * size; i = i + 1 {
    data.set(i * 4, (if i % 2 == 0 { r } else { r / 2 }).to_double())
    data.set(i * 4 + 1, g.to_double())
    data.set(i * 4 + 2, b.to_double())
    data.set(i * 4 + 3, 255.0)
  }
  let texture = @three.DataTexture::new(data~, width=size, height=size)
  texture.set_needs_update(true)
  texture
}

///|
/// A 2D canvas with a `cells`x`cells` checker of the CSS colors `a` and `b` (the same
/// JavaScript as webgpu_scenes.js's `checkerCanvas`).
extern "js" fn checker_canvas(
  size : Int32,
  cells : Int32,
  a : String,
  b : String,
) -> @three.JsValue =
  #|( size, cells, a, b ) => {
  #|	const canvas = document.createElement( 'canvas' );
  #|	canvas.width = size;
  #|	canvas.height = size;
  #|	const context = canvas.getContext( '2d' );
  #|	const step = size / cells;
  #|	for ( let y = 0; y < cells; y ++ ) {
  #|		for ( let x = 0; x < cells; x ++ ) {
  #|			context.fillStyle = ( x + y ) % 2 === 0 ? a : b;
  #|			context.fillRect( x * step, y * step, step, step );
  #|		}
  #|	}
  #|	return canvas;
  #|}

///|
fn build(name : String) -> View? {
  let scene = @three.Scene::new()
  match name {
    "unlit_box" => {
      let box = mesh(
        @three.BoxGeometry::new(),
        colored(@three.MeshBasicNodeMaterial::new(), 0xff8800),
      )
      box.rotation.set(0.4, 0.6, 0.0) |> ignore
      scene.add(box) |> ignore
      Some(view(scene, camera_at(0.0, 0.0, 3.0)))
    }
    "lit_spheres" => {
      let sphere = @three.SphereGeometry::new(
        radius=0.5,
        width_segments=32.0,
        height_segments=16.0,
      )
      let lambert = mesh(
        sphere,
        colored(@three.MeshLambertNodeMaterial::new(), 0xcc4444),
      )
      lambert.position.set(-1.1, 0.0, 0.0) |> ignore
      scene.add(lambert) |> ignore
      let phong = colored(@three.MeshPhongNodeMaterial::new(), 0x44cc44)
      phong.shininess = Some(60.0)
      scene.add(mesh(sphere, phong)) |> ignore
      let standard = colored(@three.MeshStandardNodeMaterial::new(), 0x4444cc)
      standard.roughness = Some(0.4)
      standard.metalness = Some(0.1)
      let s = mesh(sphere, standard)
      s.position.set(1.1, 0.0, 0.0) |> ignore
      scene.add(s) |> ignore
      scene.add(
        @three.AmbientLight::new(
          color=@three.Color::from_hex(0x202020),
          intensity=1.0,
        ),
      )
      |> ignore
      let light = @three.DirectionalLight::new(
        color=@three.Color::from_hex(0xffffff),
        intensity=2.0,
      )
      light.position.set(2.0, 3.0, 4.0) |> ignore
      scene.add(light) |> ignore
      Some(view(scene, camera_at(0.0, 0.5, 4.0)))
    }
    "data_texture" => {
      let w = 8
      let h = 8
      let data = @three.TypedArray::uint8(w * h * 4)
      for y = 0; y < h; y = y + 1 {
        for x = 0; x < w; x = x + 1 {
          let i = (y * w + x) * 4
          data.set(i, if (x + y) % 2 == 0 { 255.0 } else { 30.0 })
          data.set(i + 1, (x * 255 / (w - 1)).to_double())
          data.set(i + 2, (y * 255 / (h - 1)).to_double())
          data.set(i + 3, 255.0)
        }
      }
      let texture = @three.DataTexture::new(data~, width=w, height=h)
      texture.mag_filter = @three.NearestFilter
      texture.set_needs_update(true)
      let material = @three.MeshBasicNodeMaterial::new()
      material.map = Some(texture)
      scene.add(
        mesh(@three.PlaneGeometry::new(width=2.0, height=2.0), material),
      )
      |> ignore
      Some(view(scene, camera_at(0.0, 0.0, 2.5)))
    }
    "instancing" => {
      let instanced = @three.InstancedMesh::new(
        geometry=@three.BoxGeometry::new(width=0.4, height=0.4, depth=0.4),
        material=Single(colored(@three.MeshBasicNodeMaterial::new(), 0x3399ff)),
        5,
      )
      for i = 0; i < 5; i = i + 1 {
        instanced.set_matrix_at(
          i,
          @three.Matrix4::new().make_translation(
            (i - 2).to_double() * 0.6,
            0.0,
            0.0,
          ),
        )
        |> ignore
        instanced.set_color_at(
          i,
          @three.Color::new(i.to_double() / 4.0, 1.0 - i.to_double() / 4.0, 0.5),
        )
        |> ignore
      }
      scene.add(instanced) |> ignore
      Some(view(scene, camera_at(0.0, 0.0, 3.0)))
    }
    "lines_points" => {
      let positions : Array[Double] = []
      for i = 0; i < 16; i = i + 1 {
        let t = i.to_double() / 15.0
        positions.push(t * 2.0 - 1.0)
        positions.push(js_sin(t * 6.0) * 0.5)
        positions.push(0.0)
      }
      let geometry = @three.BufferGeometry::new()
      geometry.set_attribute(
        "position",
        @three.Float32BufferAttribute::new(positions, 3).to_geometry_attribute(),
      )
      |> ignore
      scene.add(
        @three.Line::new(
          geometry~,
          material=Single(
            colored(@three.LineBasicNodeMaterial::new(), 0xffffff),
          ),
        ),
      )
      |> ignore
      let points = colored(@three.PointsNodeMaterial::new(), 0xff3333)
      scene.add(@three.Points::new(geometry~, material=Single(points)))
      |> ignore
      Some(view(scene, camera_at(0.0, 0.0, 2.5)))
    }
    "transparent" => {
      let back = mesh(
        @three.PlaneGeometry::new(width=1.5, height=1.5),
        colored(@three.MeshBasicNodeMaterial::new(), 0x2222ff),
      )
      back.position.set(-0.3, 0.0, -0.5) |> ignore
      scene.add(back) |> ignore
      let front_material = colored(
        @three.MeshBasicNodeMaterial::new(),
        0xff2222,
      )
      front_material.transparent = true
      front_material.opacity = 0.5
      let front = mesh(
        @three.PlaneGeometry::new(width=1.5, height=1.5),
        front_material,
      )
      front.position.set(0.3, 0.0, 0.0) |> ignore
      scene.add(front) |> ignore
      Some(view(scene, camera_at(0.0, 0.0, 3.0)))
    }
    "shadow_directional" => {
      shadow_stage(scene, 0xff8844)
      let light = @three.DirectionalLight::new(
        color=@three.Color::from_hex(0xffffff),
        intensity=3.0,
      )
      light.position.set(2.0, 4.0, 3.0) |> ignore
      light.cast_shadow = true
      shadow_of(light).map_size.set(256.0, 256.0) |> ignore
      scene.add(light) |> ignore
      Some(
        view(scene, camera_at(0.0, 2.0, 4.0), before=fn(renderer, _) {
          enable_shadows(renderer)
        }),
      )
    }
    "shadow_spot" => {
      shadow_stage(scene, 0x44aaff)
      let light = @three.SpotLight::new(
        color=@three.Color::from_hex(0xffffff),
        intensity=40.0,
        distance=0.0,
        angle=0.6,
        penumbra=0.3,
        decay=2.0,
      )
      light.position.set(-2.0, 4.0, 2.0) |> ignore
      light.cast_shadow = true
      shadow_of(light).map_size.set(256.0, 256.0) |> ignore
      scene.add(light) |> ignore
      Some(
        view(scene, camera_at(0.0, 2.0, 4.0), before=fn(renderer, _) {
          enable_shadows(renderer)
        }),
      )
    }
    "shadow_point" => {
      shadow_stage(scene, 0x88dd44)
      let light = @three.PointLight::new(
        color=@three.Color::from_hex(0xffffff),
        intensity=20.0,
        distance=0.0,
        decay=2.0,
      )
      light.position.set(1.0, 2.5, 1.0) |> ignore
      light.cast_shadow = true
      shadow_of(light).map_size.set(128.0, 128.0) |> ignore
      scene.add(light) |> ignore
      Some(
        view(scene, camera_at(0.0, 2.0, 4.0), before=fn(renderer, _) {
          enable_shadows(renderer)
        }),
      )
    }
    "pmrem_env" => {
      scene.as_scene().environment = Some(sky_texture())
      let sphere = @three.SphereGeometry::new(
        radius=0.5,
        width_segments=32.0,
        height_segments=16.0,
      )
      let standard = colored(@three.MeshStandardNodeMaterial::new(), 0xffffff)
      standard.metalness = Some(1.0)
      standard.roughness = Some(0.25)
      let metal = mesh(sphere, standard)
      metal.position.set(-0.6, 0.0, 0.0) |> ignore
      scene.add(metal) |> ignore
      let physical = colored(@three.MeshPhysicalNodeMaterial::new(), 0xcc3333)
      physical.roughness = Some(0.6)
      physical.set_clearcoat(1.0)
      physical.clearcoat_roughness = Some(0.1)
      let coated = mesh(sphere, physical)
      coated.position.set(0.6, 0.0, 0.0) |> ignore
      scene.add(coated) |> ignore
      Some(view(scene, camera_at(0.0, 0.0, 2.5)))
    }
    "cube_background" => {
      let faces = [
        face_texture(2, 255, 64, 64),
        face_texture(2, 64, 255, 64),
        face_texture(2, 64, 64, 255),
        face_texture(2, 255, 255, 64),
        face_texture(2, 64, 255, 255),
        face_texture(2, 255, 64, 255),
      ]
      let cube = @three.CubeTexture::new(
        images=faces.map(fn(face) { TextureImage(face) }),
      )
      cube.set_needs_update(true)
      scene.as_scene().background = Some(Texture(cube))
      let material = @three.MeshBasicNodeMaterial::new()
      material.env_map = Some(cube)
      scene.add(
        mesh(
          @three.SphereGeometry::new(
            radius=0.6,
            width_segments=32.0,
            height_segments=16.0,
          ),
          material,
        ),
      )
      |> ignore
      Some(view(scene, camera_at(2.0, 1.5, 2.0)))
    }
    "post_pass" => {
      let left = mesh(
        @three.BoxGeometry::new(width=0.8, height=0.8, depth=0.8),
        colored(@three.MeshBasicNodeMaterial::new(), 0xff3355),
      )
      left.position.set(-0.6, 0.0, 0.0) |> ignore
      left.rotation.set(0.3, 0.5, 0.0) |> ignore
      scene.add(left) |> ignore
      let right = mesh(
        @three.SphereGeometry::new(
          radius=0.45,
          width_segments=32.0,
          height_segments=16.0,
        ),
        colored(@three.MeshBasicNodeMaterial::new(), 0x33ff88),
      )
      right.position.set(0.6, 0.0, 0.0) |> ignore
      scene.add(right) |> ignore
      let camera = camera_at(0.0, 0.0, 3.0)
      Some(
        view(scene, camera, render=fn(renderer) {
          let pipeline = @three.RenderPipeline::new(renderer)
          let scene_pass = @three.pass(scene, camera)
          let gray = @three.vec3(@three.luminance(scene_pass.rgb()))
          pipeline.output_node = @three.vec4_of([
            @three.mix(
              scene_pass.rgb(),
              gray,
              @three.step(0.5, @three.uv().x()),
            ),
            1,
          ])
          pipeline.render()
        }),
      )
    }
    "tone_mapping" => {
      let sphere = @three.SphereGeometry::new(
        radius=0.5,
        width_segments=32.0,
        height_segments=16.0,
      )
      for i = 0; i < 3; i = i + 1 {
        let material = colored(@three.MeshStandardNodeMaterial::new(), 0xffaa66)
        material.roughness = Some(0.2 + i.to_double() * 0.3)
        let mesh = mesh(sphere, material)
        mesh.position.set((i - 1).to_double() * 1.1, 0.0, 0.0) |> ignore
        scene.add(mesh) |> ignore
      }
      let light = @three.DirectionalLight::new(
        color=@three.Color::from_hex(0xffffff),
        intensity=8.0,
      )
      light.position.set(1.0, 2.0, 3.0) |> ignore
      scene.add(light) |> ignore
      Some(
        view(scene, camera_at(0.0, 0.0, 3.5), before=fn(renderer, target) {
          renderer.tone_mapping = @three.ACESFilmicToneMapping
          renderer.tone_mapping_exposure = 1.5
          renderer.output_color_space = @three.SRGBColorSpace
          renderer.set_output_render_target(Some(target))
        }),
      )
    }
    "tsl_material" => {
      let scale = @three.uniform(4)
      let checker = @three.fn_(fn(inputs, _) {
        let coord = inputs.get(0).unwrap()
        let cell = coord.mul(scale).floor().to_var()
        let color = @three.vec3(0.1).to_var()
        @three.if_(cell.x().add(cell.y()).mod(2).equal(0), fn() {
          color.assign(@three.vec3_of([1, 0.5, 0]))
        })
        |> ignore
        Some(color)
      }).set_layout(name="checker", type_="vec3", inputs=[("coord", "vec2")])
      let material = @three.MeshBasicNodeMaterial::new()
      @three.NodeMaterial::of(material).unwrap().color_node = Some(
        checker.call([@three.uv()]),
      )
      @three.NodeMaterial::of(material).unwrap().position_node = Some(
        @three.position_local.add(
          @three.normal_local.mul(
            @three.mx_noise_float(texcoord=@three.position_local.mul(3)).mul(
              0.15,
            ),
          ),
        ),
      )
      scene.add(
        mesh(
          @three.SphereGeometry::new(
            radius=0.8,
            width_segments=32.0,
            height_segments=16.0,
          ),
          material,
        ),
      )
      |> ignore
      Some(view(scene, camera_at(0.0, 0.0, 3.0)))
    }
    "compute_instances" => {
      let count = 8
      let positions = @three.instanced_array(count, type_="vec3")
      let compute_positions = @three.fn_(fn(_, _) {
          let i = @three.float(@three.instance_index)
          positions
          .element(@three.instance_index)
          .assign(
            @three.vec3_of([
              i.mul(0.45).sub(1.575),
              i.mul(1.3).sin().mul(0.5),
              0,
            ]),
          )
          None
        })
        .call([])
        .compute(count)
      let material = colored(@three.MeshBasicNodeMaterial::new(), 0x33cc99)
      @three.NodeMaterial::of(material).unwrap().position_node = Some(
        @three.position_local.add(positions.to_attribute()),
      )
      scene.add(
        @three.InstancedMesh::new(
          geometry=@three.BoxGeometry::new(width=0.3, height=0.3, depth=0.3),
          material=Single(material),
          count,
        ),
      )
      |> ignore
      Some(
        view(scene, camera_at(0.0, 0.0, 3.0), before=fn(renderer, _) {
          renderer.compute(compute_positions)
        }),
      )
    }
    "msaa_target" => {
      let box = mesh(
        @three.BoxGeometry::new(),
        colored(@three.MeshBasicNodeMaterial::new(), 0xffdd00),
      )
      box.rotation.set(0.5, 0.7, 0.2) |> ignore
      scene.add(box) |> ignore
      let plane = mesh(
        @three.PlaneGeometry::new(width=3.0, height=0.1),
        colored(@three.MeshBasicNodeMaterial::new(), 0x00ccff),
      )
      plane.rotation.set(0.0, 0.0, 0.3) |> ignore
      plane.position.set(0.0, 0.0, 0.8) |> ignore
      scene.add(plane) |> ignore
      Some(view(scene, camera_at(0.0, 0.0, 3.0), samples=4))
    }
    "skinned_morph" => {
      let light = @three.DirectionalLight::new(
        color=@three.Color::from_hex(0xffffff),
        intensity=2.0,
      )
      light.position.set(1.0, 2.0, 3.0) |> ignore
      scene.add(light) |> ignore
      // morph target: a box stretched along x
      let morph_geometry = @three.BoxGeometry::new(
        width=0.6,
        height=0.6,
        depth=0.6,
      )
      let positions = morph_geometry.attributes["position"]
      let target : Array[Double] = []
      for i = 0; i < positions.count(); i = i + 1 {
        target.push(positions.get_x(i) * 2.0)
        target.push(positions.get_y(i))
        target.push(positions.get_z(i))
      }
      morph_geometry.morph_attributes["position"] = [
        Buffer(@three.Float32BufferAttribute::new(target, 3)),
      ]
      let morph = mesh(
        morph_geometry,
        colored(@three.MeshStandardNodeMaterial::new(), 0xff00ff),
      )
      if morph.kind is Mesh({ morph_target_influences: Some(influences), .. }) {
        influences[0] = 0.6
      }
      morph.position.set(-0.9, 0.0, 0.0) |> ignore
      scene.add(morph) |> ignore
      // skinned: two bones, the upper half bent
      let skin_geometry = @three.BoxGeometry::new(
        width=0.3,
        height=1.2,
        depth=0.3,
        width_segments=1.0,
        height_segments=4.0,
        depth_segments=1.0,
      )
      let skin_position = skin_geometry.attributes["position"]
      let skin_index : Array[Double] = []
      let skin_weight : Array[Double] = []
      for i = 0; i < skin_position.count(); i = i + 1 {
        let y = skin_position.get_y(i)
        skin_index.push(if y > 0.0 { 1.0 } else { 0.0 })
        skin_index.push(0.0)
        skin_index.push(0.0)
        skin_index.push(0.0)
        skin_weight.push(1.0)
        skin_weight.push(0.0)
        skin_weight.push(0.0)
        skin_weight.push(0.0)
      }
      skin_geometry.set_attribute(
        "skinIndex",
        @three.Uint16BufferAttribute::new(skin_index, 4),
      )
      |> ignore
      skin_geometry.set_attribute(
        "skinWeight",
        @three.Float32BufferAttribute::new(skin_weight, 4),
      )
      |> ignore
      let skinned = @three.SkinnedMesh::new(
        geometry=skin_geometry,
        material=Single(
          colored(@three.MeshLambertNodeMaterial::new(), 0xffcc00),
        ),
      )
      let root = @three.Bone::new()
      let tip = @three.Bone::new()
      tip.position.y = 0.0
      root.add(tip) |> ignore
      skinned.add(root) |> ignore
      skinned.bind(@three.Skeleton::new(bones=[root, tip]))
      tip.rotation.set_z(0.6)
      skinned.position.set(0.9, 0.0, 0.0) |> ignore
      scene.add(skinned) |> ignore
      Some(view(scene, camera_at(0.0, 0.0, 3.0)))
    }
    "fog" => {
      let fog_color = 0x8899aa
      scene.as_scene().background = Some(
        Color(@three.Color::from_hex(fog_color)),
      )
      scene.as_scene().fog = Some(
        Fog(
          @three.Fog::new(
            color=@three.Color::from_hex(fog_color),
            near=2.0,
            far=8.0,
          ),
        ),
      )
      let geometry = @three.BoxGeometry::new(width=0.6, height=0.6, depth=0.6)
      for i = 0; i < 5; i = i + 1 {
        let box = mesh(
          geometry,
          colored(@three.MeshLambertNodeMaterial::new(), 0xff4040),
        )
        box.position.set(i.to_double() * 0.5 - 1.0, 0.0, -i.to_double() * 1.5)
        |> ignore
        scene.add(box) |> ignore
      }
      let light = @three.DirectionalLight::new(
        color=@three.Color::from_hex(0xffffff),
        intensity=2.0,
      )
      light.position.set(1.0, 1.0, 2.0) |> ignore
      scene.add(light) |> ignore
      Some(view(scene, camera_at(0.0, 0.5, 3.0)))
    }
    "texture_formats" => {
      let w = 4
      let h = 4
      let floats = @three.TypedArray::float32(w * h * 4)
      let halves = @three.TypedArray::uint16(w * h * 4)
      for i = 0; i < w * h; i = i + 1 {
        let x = i % w
        let y = i / w
        floats.set(i * 4, x.to_double() / (w - 1).to_double())
        floats.set(i * 4 + 1, y.to_double() / (h - 1).to_double())
        floats.set(i * 4 + 2, 0.5)
        floats.set(i * 4 + 3, 1.0)
        halves.set(
          i * 4,
          @three.DataUtils::to_half_float(
            1.0 - x.to_double() / (w - 1).to_double(),
          ),
        )
        halves.set(i * 4 + 1, @three.DataUtils::to_half_float(0.25))
        halves.set(
          i * 4 + 2,
          @three.DataUtils::to_half_float(y.to_double() / (h - 1).to_double()),
        )
        halves.set(i * 4 + 3, @three.DataUtils::to_half_float(1.0))
      }
      let float_texture = @three.DataTexture::new(
        data=floats,
        width=w,
        height=h,
        format=@three.RGBAFormat,
        type_=@three.FloatType,
      )
      float_texture.mag_filter = @three.NearestFilter
      float_texture.min_filter = @three.NearestFilter
      float_texture.set_needs_update(true)
      let half_texture = @three.DataTexture::new(
        data=halves,
        width=w,
        height=h,
        format=@three.RGBAFormat,
        type_=@three.HalfFloatType,
      )
      half_texture.mag_filter = @three.NearestFilter
      half_texture.min_filter = @three.NearestFilter
      half_texture.set_needs_update(true)
      let canvas_texture = @three.CanvasTexture::new(
        canvas=checker_canvas(64, 8, "#ff8800", "#003366"),
      )
      canvas_texture.min_filter = @three.LinearMipmapLinearFilter
      canvas_texture.generate_mipmaps = true
      let textures = [float_texture, half_texture, canvas_texture]
      for i = 0; i < 3; i = i + 1 {
        let material = @three.MeshBasicNodeMaterial::new()
        material.map = Some(textures[i])
        let plane = mesh(
          @three.PlaneGeometry::new(width=0.9, height=0.9),
          material,
        )
        plane.position.set((i - 1).to_double() * 1.0, 0.0, 0.0) |> ignore
        plane.rotation.set(if i == 2 { -1.1 } else { 0.0 }, 0.0, 0.0) |> ignore
        scene.add(plane) |> ignore
      }
      Some(view(scene, camera_at(0.0, 0.0, 2.5)))
    }
    "sprites" => {
      let plain = @three.Sprite::new(
        material=colored(@three.SpriteNodeMaterial::new(), 0xff6633),
      )
      plain.position.set(-0.9, 0.0, 0.0) |> ignore
      plain.scale.set(0.6, 0.6, 1.0) |> ignore
      scene.add(plain) |> ignore
      let rotated_material = colored(@three.SpriteNodeMaterial::new(), 0x3366ff)
      @three.SpriteNodeMaterial::of(rotated_material).unwrap().rotation_node = Some(
        @three.float(0.6),
      )
      let rotated = @three.Sprite::new(material=rotated_material)
      rotated.scale.set(0.8, 0.4, 1.0) |> ignore
      scene.add(rotated) |> ignore
      let size = 16
      let data = @three.TypedArray::uint8(size * size * 4)
      for y = 0; y < size; y = y + 1 {
        for x = 0; x < size; x = x + 1 {
          let i = (y * size + x) * 4
          let dx = x.to_double() - 7.5
          let dy = y.to_double() - 7.5
          let inside = dx * dx + dy * dy < 56.0
          data.set(i, 255.0)
          data.set(i + 1, (x * 255 / (size - 1)).to_double())
          data.set(i + 2, 64.0)
          data.set(i + 3, if inside { 255.0 } else { 0.0 })
        }
      }
      let disc = @three.DataTexture::new(data~, width=size, height=size)
      disc.set_needs_update(true)
      let disc_material = @three.SpriteNodeMaterial::new()
      disc_material.map = Some(disc)
      disc_material.transparent = true
      let disc_sprite = @three.Sprite::new(material=disc_material)
      disc_sprite.position.set(0.9, 0.0, 0.0) |> ignore
      disc_sprite.scale.set(0.7, 0.7, 1.0) |> ignore
      scene.add(disc_sprite) |> ignore
      Some(view(scene, camera_at(0.0, 0.0, 2.5)))
    }
    _ => None
  }
}

///|
/// `loadAddons( name )`: the add-on modules a scene imports (`ADDON_MODULES`), loaded in
/// import order before the scene is built; `false` for a scene without add-ons.
fn load_addons(name : String) -> Bool {
  match name {
    "addon_fxaa"
    | "addon_sobel"
    | "addon_rgb_shift"
    | "addon_pixelation"
    | "addon_ssaa" => ()
    "addon_gaussian_blur" => @tsl.load_display_gaussian_blur_node()
    "addon_dof" => @tsl.load_display_depth_of_field_node()
    "addon_gtao" => @tsl.load_display_gtao_node()
    "addon_ssr" => @tsl.load_display_ssr_node()
    _ => return load_objects_addons(name) || load_a5_addons(name)
  }
  true
}

///|
/// The add-on scenes' stage: a standard box, a metallic sphere and a glossy ground under
/// an ambient and a directional light; returns the camera.
fn addon_stage(scene : @three.Object3D) -> @three.Object3D {
  let box = mesh(
    @three.BoxGeometry::new(width=0.8, height=0.8, depth=0.8),
    colored(@three.MeshStandardNodeMaterial::new(), 0x3366cc),
  )
  box.position.set(-0.6, 0.4, 0.0) |> ignore
  box.rotation.set(0.0, 0.5, 0.0) |> ignore
  scene.add(box) |> ignore
  let sphere_material = colored(
    @three.MeshStandardNodeMaterial::new(),
    0xff8833,
  )
  sphere_material.metalness = Some(0.8)
  sphere_material.roughness = Some(0.2)
  let sphere = mesh(
    @three.SphereGeometry::new(
      radius=0.45,
      width_segments=32.0,
      height_segments=16.0,
    ),
    sphere_material,
  )
  sphere.position.set(0.6, 0.45, 0.0) |> ignore
  scene.add(sphere) |> ignore
  let ground_material = colored(
    @three.MeshStandardNodeMaterial::new(),
    0xcccccc,
  )
  ground_material.metalness = Some(0.5)
  ground_material.roughness = Some(0.3)
  let ground = mesh(
    @three.PlaneGeometry::new(width=6.0, height=6.0),
    ground_material,
  )
  ground.rotation.set(-js_pi() / 2.0, 0.0, 0.0) |> ignore
  scene.add(ground) |> ignore
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
  camera_at(0.0, 1.2, 2.6)
}

///|
/// An add-on scene: the stage rendered through a RenderPipeline whose output is
/// `output(scene, camera)`.
fn addon_view(
  output : (@three.Object3D, @three.Object3D) -> @three.Node,
) -> View {
  let scene = @three.Scene::new()
  let camera = addon_stage(scene)
  view(scene, camera, render=fn(renderer) {
    let pipeline = @three.RenderPipeline::new(renderer)
    pipeline.output_node = output(scene, camera)
    pipeline.render()
  })
}

///|
/// The add-on scenes.
fn build_addon(name : String) -> View? {
  match name {
    "addon_fxaa" =>
      Some(
        addon_view(fn(scene, camera) { @tsl.fxaa(@three.pass(scene, camera)) }),
      )
    "addon_gaussian_blur" =>
      Some(
        addon_view(fn(scene, camera) {
          @tsl.gaussian_blur(
            @three.pass(scene, camera),
            direction_node=@three.vec2_of([1, 1]),
            sigma=2.0,
          )
        }),
      )
    "addon_sobel" =>
      Some(
        addon_view(fn(scene, camera) { @tsl.sobel(@three.pass(scene, camera)) }),
      )
    "addon_rgb_shift" =>
      Some(
        addon_view(fn(scene, camera) {
          @tsl.rgb_shift(@three.pass(scene, camera), amount=0.01, angle=0.5)
        }),
      )
    "addon_dof" =>
      Some(
        addon_view(fn(scene, camera) {
          let scene_pass = @three.pass(scene, camera)
          @tsl.dof(
            scene_pass,
            scene_pass.get_view_z_node(),
            focus_distance=2.6,
            focal_length=1.5,
            bokeh_scale=3,
          )
        }),
      )
    "addon_gtao" =>
      Some(
        addon_view(fn(scene, camera) {
          let scene_pass = @three.pass(scene, camera)
          scene_pass.set_mrt(
            Some(
              @three.mrt({
                "output": @three.output,
                "normal": @three.normal_view,
              }),
            ),
          )
          |> ignore
          let ao_node = @tsl.ao(
            scene_pass.get_texture_node(name="depth"),
            Some(scene_pass.get_texture_node(name="normal")),
            camera,
          )
          let occlusion = @tsl.GTAONode::of(ao_node)
            .unwrap()
            .get_texture_node()
            .sample(@three.screen_uv)
            .r()
          @three.vec4_of([
            scene_pass.get_texture_node(name="output").rgb().mul(occlusion),
            1,
          ])
        }),
      )
    "addon_ssr" =>
      Some(
        addon_view(fn(scene, camera) {
          let scene_pass = @three.pass(scene, camera)
          scene_pass.set_mrt(
            Some(
              @three.mrt({
                "output": @three.output,
                "normal": @three.normal_view,
                "metalrough": @three.vec2_of([
                  @three.metalness, @three.roughness,
                ]),
              }),
            ),
          )
          |> ignore
          let metal_rough = scene_pass.get_texture_node(name="metalrough")
          let ssr_node = @tsl.ssr(
            scene_pass.get_texture_node(name="output"),
            scene_pass.get_texture_node(name="depth"),
            scene_pass.get_texture_node(name="normal"),
            metalness_node=metal_rough.r(),
            roughness_node=metal_rough.g(),
          )
          scene_pass.get_texture_node(name="output").add(ssr_node.rgb())
        }),
      )
    "addon_pixelation" =>
      Some(
        addon_view(fn(scene, camera) {
          @tsl.pixelation_pass(
            scene,
            camera,
            pixel_size=4.0,
            normal_edge_strength=0.5,
            depth_edge_strength=0.5,
          )
        }),
      )
    "addon_ssaa" =>
      Some(
        addon_view(fn(scene, camera) {
          let ssaa = @tsl.ssaa_pass(scene, camera)
          @tsl.SSAAPassNode::of(ssaa).unwrap().sample_level = 2
          ssaa
        }),
      )
    _ =>
      match build_a5_addon(name) {
        Some(built) => Some(built)
        None => build_objects_addon(name)
      }
  }
}

///|
/// Renders scene `name` with a WebGPURenderer on `canvas` into a render target and calls
/// `done` with the pixels (a `Uint8Array`, bottom row first), or `null` for an unknown
/// scene. The renderer is disposed afterwards. `force_webgl` selects the WebGL fallback
/// backend, as upstream's `forceWebGL: true`.
pub fn render_scene(
  name : String,
  canvas : @three.JsValue,
  done : (@three.JsValue) -> Unit,
  force_webgl~ : Bool = false,
) -> Unit {
  let built = if load_addons(name) { build_addon(name) } else { build(name) }
  match built {
    None => done(@three.JsValue::null())
    Some(built) => {
      let renderer = @three.WebGPURenderer::new(
        canvas~,
        antialias=false,
        force_webgl~,
      )
      renderer.set_pixel_ratio(1.0)
      renderer.set_size(
        WIDTH.to_double(),
        HEIGHT.to_double(),
        update_style=false,
      )
      renderer.init(on_done=fn(_) {
        let target = @three.RenderTarget::new(
          width=WIDTH,
          height=HEIGHT,
          samples=built.samples,
        )
        renderer.set_render_target(Some(target))
        if built.before is Some(before) {
          before(renderer, target)
        }
        match built.render {
          Some(render) => render(renderer)
          None => renderer.render(built.scene, built.camera)
        }
        renderer.read_render_target_pixels_async(target, 0, 0, WIDTH, HEIGHT, fn(
          pixels,
        ) {
          let result = match pixels {
            Some(p) => @three.JsValue::of(p)
            None => @three.JsValue::null()
          }
          renderer.dispose(on_done=fn() { done(result) })
        })
      })
    }
  }
}

///|
fn main {

}
