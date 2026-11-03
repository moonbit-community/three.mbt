// The MoonBit half of the pixel comparison: the same deterministic scenes as scenes.js
// (upstream three.js), rendered with the port into a canvas the page provides. The page
// reads the pixels back with `readPixels` and compares them with upstream's.
//
// Every scene here mirrors the function of the same name in scenes.js line by line; keep
// them in step.

///|
/// Canvas size the page uses; the cameras' aspect ratios follow it.
const WIDTH : Int32 = 128

///|
const HEIGHT : Int32 = 96

///|
/// `Math.sin` / `Math.cos`, so scene code computes exactly what scenes.js computes.
extern "js" fn js_sin(x : Double) -> Double = "Math.sin"

///|
extern "js" fn js_cos(x : Double) -> Double = "Math.cos"

///|
let pi : Double = 3.141592653589793

///|
/// The renderer of the last `render_scene`, released by `release_scene`.
let current : Ref[@webgl.WebGLRenderer?] = Ref(None)

///|
let names : Array[String] = [
  "unlit_box", "lights_directional", "lights_point", "lights_spot", "lights_hemisphere",
  "shadow", "data_texture", "fog", "skinned_morph", "instancing", "lines_points",
  "transparent", "render_to_texture", "helpers_grid_axes", "helpers_lights", "helpers_boxes_camera",
  "helpers_skeleton",
] +
  objects_scene_names

///|
/// The scene names, in page order.
pub fn scene_names() -> Array[String] {
  names
}

///|
fn color(material : @core.Material, hex : Int32) -> @core.Material {
  ignore(material.color.unwrap().set_hex(hex))
  material
}

///|
fn mesh(
  geometry : @core.BufferGeometry,
  material : @core.Material,
) -> @core.Object3D {
  @core.Mesh::new(geometry~, material=Single(material))
}

///|
fn camera_at(x : Double, y : Double, z : Double) -> @core.Object3D {
  let camera = @core.PerspectiveCamera::new(
    fov=50.0,
    aspect=WIDTH.to_double() / HEIGHT.to_double(),
    near=0.1,
    far=100.0,
  )
  ignore(camera.position.set(x, y, z))
  camera.look_at_xyz(0.0, 0.0, 0.0)
  camera
}

///|
/// Lambert, Phong and Standard spheres in a row.
fn add_spheres(scene : @core.Object3D) -> Unit {
  let sphere = @geometries.SphereGeometry::new(
    radius=0.5,
    width_segments=32.0,
    height_segments=16.0,
  )
  let lambert = mesh(sphere, color(@core.MeshLambertMaterial::new(), 0xcc4444))
  ignore(lambert.position.set(-1.1, 0.0, 0.0))
  ignore(scene.add(lambert))
  let phong_material = color(@core.MeshPhongMaterial::new(), 0x44cc44)
  phong_material.shininess = Some(60.0)
  ignore(scene.add(mesh(sphere, phong_material)))
  let standard_material = color(@core.MeshStandardMaterial::new(), 0x4444cc)
  standard_material.roughness = Some(0.4)
  standard_material.metalness = Some(0.1)
  let standard = mesh(sphere, standard_material)
  ignore(standard.position.set(1.1, 0.0, 0.0))
  ignore(scene.add(standard))
  ignore(
    scene.add(
      @core.AmbientLight::new(
        color=@math.Color::from_hex(0x202020),
        intensity=1.0,
      ),
    ),
  )
}

///|
fn data_texture(width : Int32, height : Int32) -> @core.Texture {
  let data = @core.TypedArray::new(Uint8Array, width * height * 4)
  for y in 0..<height {
    for x in 0..<width {
      let i = (y * width + x) * 4
      let on = (x + y) % 2 == 0
      data.set(i, if on { 255.0 } else { 30.0 })
      data.set(i + 1, (x * 255 / (width - 1)).to_double())
      data.set(i + 2, (y * 255 / (height - 1)).to_double())
      data.set(i + 3, 255.0)
    }
  }
  let texture = @core.DataTexture::new(data~, width~, height~)
  texture.set_needs_update(true)
  texture
}

///|
/// Builds scene `name`; `renderer` is there for scenes that need a setup pass.
fn build(
  name : String,
  renderer : @webgl.WebGLRenderer,
) -> (@core.Object3D, @core.Object3D)? {
  let scene = @core.Scene::new()
  match name {
    "unlit_box" => {
      let box = mesh(
        @geometries.BoxGeometry::new(width=1.0, height=1.0, depth=1.0),
        color(@core.MeshBasicMaterial::new(), 0xff8800),
      )
      ignore(box.rotation.set(0.5, 0.7, 0.0))
      ignore(scene.add(box))
      Some((scene, camera_at(0.0, 0.0, 3.0)))
    }
    "lights_directional" => {
      add_spheres(scene)
      let light = @core.DirectionalLight::new(
        color=@math.Color::from_hex(0xffffff),
        intensity=2.0,
      )
      ignore(light.position.set(1.0, 2.0, 3.0))
      ignore(scene.add(light))
      Some((scene, camera_at(0.0, 0.0, 4.0)))
    }
    "lights_point" => {
      add_spheres(scene)
      let light = @core.PointLight::new(
        color=@math.Color::from_hex(0xffffff),
        intensity=8.0,
        distance=0.0,
        decay=2.0,
      )
      ignore(light.position.set(0.0, 1.5, 1.5))
      ignore(scene.add(light))
      Some((scene, camera_at(0.0, 0.0, 4.0)))
    }
    "lights_spot" => {
      add_spheres(scene)
      let light = @core.SpotLight::new(
        color=@math.Color::from_hex(0xffffff),
        intensity=10.0,
        distance=0.0,
        angle=pi / 5.0,
        penumbra=0.3,
        decay=2.0,
      )
      ignore(light.position.set(0.0, 3.0, 2.0))
      ignore(scene.add(light))
      Some((scene, camera_at(0.0, 0.0, 4.0)))
    }
    "lights_hemisphere" => {
      add_spheres(scene)
      ignore(
        scene.add(
          @core.HemisphereLight::new(
            sky_color=@math.Color::from_hex(0x88aaff),
            ground_color=@math.Color::from_hex(0x553311),
            intensity=1.5,
          ),
        ),
      )
      Some((scene, camera_at(0.0, 0.0, 4.0)))
    }
    "shadow" => {
      renderer.shadow_map.enabled = true
      let sphere = mesh(
        @geometries.SphereGeometry::new(
          radius=0.5,
          width_segments=24.0,
          height_segments=12.0,
        ),
        color(@core.MeshStandardMaterial::new(), 0xdddddd),
      )
      ignore(sphere.position.set(0.0, 0.6, 0.0))
      sphere.cast_shadow = true
      ignore(scene.add(sphere))
      let ground = mesh(
        @geometries.PlaneGeometry::new(width=6.0, height=6.0),
        color(@core.MeshStandardMaterial::new(), 0x888888),
      )
      ground.rotation.set_x(-pi / 2.0)
      ground.receive_shadow = true
      ignore(scene.add(ground))
      let light = @core.DirectionalLight::new(
        color=@math.Color::from_hex(0xffffff),
        intensity=2.5,
      )
      ignore(light.position.set(2.0, 4.0, 2.0))
      light.cast_shadow = true
      ignore(light.as_light().shadow.unwrap().map_size.set(256.0, 256.0))
      ignore(scene.add(light))
      ignore(
        scene.add(
          @core.AmbientLight::new(
            color=@math.Color::from_hex(0x404040),
            intensity=1.0,
          ),
        ),
      )
      Some((scene, camera_at(0.0, 2.0, 4.0)))
    }
    "data_texture" => {
      let material = @core.MeshBasicMaterial::new()
      material.map = Some(data_texture(4, 4))
      let plane = mesh(
        @geometries.PlaneGeometry::new(width=2.0, height=2.0),
        material,
      )
      ignore(plane.rotation.set(-0.3, 0.2, 0.0))
      ignore(scene.add(plane))
      Some((scene, camera_at(0.0, 0.0, 3.0)))
    }
    "fog" => {
      let fog_color = 0x8899aa
      scene.as_scene().background = Some(
        Color(@math.Color::from_hex(fog_color)),
      )
      scene.as_scene().fog = Some(
        Fog(
          @core.Fog::new(
            color=@math.Color::from_hex(fog_color),
            near=2.0,
            far=8.0,
          ),
        ),
      )
      let geometry = @geometries.BoxGeometry::new(
        width=0.6,
        height=0.6,
        depth=0.6,
      )
      for i in 0..<5 {
        let box = mesh(
          geometry,
          color(@core.MeshLambertMaterial::new(), 0xff4040),
        )
        ignore(
          box.position.set(i.to_double() * 0.5 - 1.0, 0.0, -i.to_double() * 1.5),
        )
        ignore(scene.add(box))
      }
      let light = @core.DirectionalLight::new(
        color=@math.Color::from_hex(0xffffff),
        intensity=2.0,
      )
      ignore(light.position.set(1.0, 1.0, 2.0))
      ignore(scene.add(light))
      Some((scene, camera_at(0.0, 0.5, 3.0)))
    }
    "skinned_morph" => {
      let light = @core.DirectionalLight::new(
        color=@math.Color::from_hex(0xffffff),
        intensity=2.0,
      )
      ignore(light.position.set(1.0, 2.0, 3.0))
      ignore(scene.add(light))
      // morph target: a box stretched along x
      let morph_geometry = @geometries.BoxGeometry::new(
        width=0.6,
        height=0.6,
        depth=0.6,
      )
      let positions = morph_geometry.attributes["position"]
      let target : Array[Double] = []
      for i in 0..<positions.count() {
        target.push(positions.get_x(i) * 2.0)
        target.push(positions.get_y(i))
        target.push(positions.get_z(i))
      }
      morph_geometry.morph_attributes["position"] = [
        Buffer(@core.Float32BufferAttribute::new(target, 3)),
      ]
      let morph = mesh(
        morph_geometry,
        color(@core.MeshStandardMaterial::new(), 0xff00ff),
      )
      if morph.kind is Mesh({ morph_target_influences: Some(influences), .. }) {
        influences[0] = 0.6
      }
      ignore(morph.position.set(-0.9, 0.0, 0.0))
      ignore(scene.add(morph))
      // skinned: two bones, the upper half bent
      let skin_geometry = @geometries.BoxGeometry::new(
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
      for i in 0..<skin_position.count() {
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
      ignore(
        skin_geometry.set_attribute(
          "skinIndex",
          @core.Uint16BufferAttribute::new(skin_index, 4),
        ),
      )
      ignore(
        skin_geometry.set_attribute(
          "skinWeight",
          @core.Float32BufferAttribute::new(skin_weight, 4),
        ),
      )
      let skinned = @core.SkinnedMesh::new(
        geometry=skin_geometry,
        material=Single(color(@core.MeshLambertMaterial::new(), 0xffcc00)),
      )
      let root = @core.Bone::new()
      let tip = @core.Bone::new()
      tip.position.y = 0.0
      ignore(root.add(tip))
      ignore(skinned.add(root))
      skinned.bind(@core.Skeleton::new(bones=[root, tip]))
      tip.rotation.set_z(0.6)
      ignore(skinned.position.set(0.9, 0.0, 0.0))
      ignore(scene.add(skinned))
      Some((scene, camera_at(0.0, 0.0, 3.0)))
    }
    "instancing" => {
      let instanced = @core.InstancedMesh::new(
        geometry=@geometries.BoxGeometry::new(width=0.4, height=0.4, depth=0.4),
        material=Single(@core.MeshLambertMaterial::new()),
        9,
      )
      let matrix = @math.Matrix4::new()
      for i in 0..<9 {
        let x = (i % 3).to_double() - 1.0
        let y = (i / 3).to_double() - 1.0
        ignore(
          instanced.set_matrix_at(
            i,
            matrix
            .make_rotation_y(i.to_double() * 0.3)
            .set_position(x * 0.7, y * 0.6, 0.0),
          ),
        )
        ignore(
          instanced.set_color_at(
            i,
            @math.Color::new(
              i.to_double() / 8.0,
              0.5,
              1.0 - i.to_double() / 8.0,
            ),
          ),
        )
      }
      ignore(scene.add(instanced))
      let light = @core.DirectionalLight::new(
        color=@math.Color::from_hex(0xffffff),
        intensity=2.0,
      )
      ignore(light.position.set(1.0, 2.0, 3.0))
      ignore(scene.add(light))
      Some((scene, camera_at(0.0, 0.0, 3.0)))
    }
    "lines_points" => {
      let spiral : Array[@math.Vector3] = []
      for i in 0..<64 {
        let t = i.to_double() / 63.0
        let angle = t * pi * 6.0
        spiral.push(
          @math.Vector3::new(
            js_cos(angle) * t * 1.4,
            js_sin(angle) * t * 1.0,
            0.0,
          ),
        )
      }
      let line_material = color(@core.LineBasicMaterial::new(), 0x00ffaa)
      ignore(
        scene.add(
          @core.Line::new(
            geometry=@core.BufferGeometry::new().set_from_points(spiral),
            material=Single(line_material),
          ),
        ),
      )
      let segments = @core.LineSegments::new(
        geometry=@core.BufferGeometry::new().set_from_points([
          @math.Vector3::new(-1.6, -1.0, 0.0),
          @math.Vector3::new(1.6, -1.0, 0.0),
          @math.Vector3::new(-1.6, 1.0, 0.0),
          @math.Vector3::new(1.6, 1.0, 0.0),
        ]),
        material=Single(color(@core.LineBasicMaterial::new(), 0xffff00)),
      )
      ignore(scene.add(segments))
      let points_material = color(@core.PointsMaterial::new(), 0xff3366)
      points_material.size = Some(4.0)
      points_material.size_attenuation = Some(false)
      ignore(
        scene.add(
          @core.Points::new(
            geometry=@core.BufferGeometry::new().set_from_points(spiral),
            material=Single(points_material),
          ),
        ),
      )
      Some((scene, camera_at(0.0, 0.0, 3.0)))
    }
    "transparent" => {
      let back = mesh(
        @geometries.BoxGeometry::new(width=1.0, height=1.0, depth=1.0),
        color(@core.MeshBasicMaterial::new(), 0x2244ff),
      )
      ignore(back.position.set(0.3, 0.0, -1.0))
      ignore(back.rotation.set(0.4, 0.6, 0.0))
      ignore(scene.add(back))
      let glass_material = color(@core.MeshBasicMaterial::new(), 0xff2222)
      glass_material.transparent = true
      glass_material.opacity = 0.5
      glass_material.side = @core.DoubleSide
      let glass = mesh(
        @geometries.SphereGeometry::new(
          radius=0.6,
          width_segments=24.0,
          height_segments=12.0,
        ),
        glass_material,
      )
      ignore(scene.add(glass))
      let veil_material = color(@core.MeshBasicMaterial::new(), 0x22ff22)
      veil_material.transparent = true
      veil_material.opacity = 0.3
      let veil = mesh(
        @geometries.PlaneGeometry::new(width=1.2, height=0.8),
        veil_material,
      )
      ignore(veil.position.set(-0.4, -0.2, 0.8))
      ignore(scene.add(veil))
      Some((scene, camera_at(0.0, 0.0, 3.0)))
    }
    "render_to_texture" => {
      // pass 1: a lit box into a 64x64 target
      let inner = @core.Scene::new()
      inner.as_scene().background = Some(Color(@math.Color::from_hex(0x203040)))
      let box = mesh(
        @geometries.BoxGeometry::new(width=1.0, height=1.0, depth=1.0),
        color(@core.MeshLambertMaterial::new(), 0xffaa00),
      )
      ignore(box.rotation.set(0.6, 0.8, 0.0))
      ignore(inner.add(box))
      let light = @core.DirectionalLight::new(
        color=@math.Color::from_hex(0xffffff),
        intensity=2.0,
      )
      ignore(light.position.set(1.0, 2.0, 3.0))
      ignore(inner.add(light))
      let inner_camera = @core.PerspectiveCamera::new(
        fov=50.0,
        aspect=1.0,
        near=0.1,
        far=10.0,
      )
      ignore(inner_camera.position.set(0.0, 0.0, 2.5))
      let target = @webgl.WebGLRenderTarget::new(width=64, height=64)
      renderer.set_render_target(Some(target))
      renderer.render(inner, inner_camera)
      renderer.set_render_target(None)
      // pass 2: the target on a tilted plane
      let material = @core.MeshBasicMaterial::new()
      material.map = Some(target.texture())
      let plane = mesh(
        @geometries.PlaneGeometry::new(width=1.6, height=1.6),
        material,
      )
      ignore(plane.rotation.set(0.0, 0.5, 0.1))
      ignore(scene.add(plane))
      Some((scene, camera_at(0.0, 0.0, 2.5)))
    }
    "helpers_grid_axes" => {
      ignore(
        scene.add(
          @helpers.GridHelper::new(
            size=4.0,
            divisions=8.0,
            color1=@math.Color::from_hex(0xff4444),
            color2=@math.Color::from_hex(0x666666),
          ),
        ),
      )
      let polar = @helpers.PolarGridHelper::new(
        radius=1.5,
        sectors=8.0,
        rings=4.0,
        divisions=32.0,
        color1=@math.Color::from_hex(0x44ff44),
        color2=@math.Color::from_hex(0x4444ff),
      )
      ignore(polar.position.set(0.0, 0.5, 0.0))
      ignore(scene.add(polar))
      let axes = @helpers.AxesHelper::new(size=1.5)
      ignore(
        @helpers.AxesHelper::set_colors(
          axes,
          @math.Color::from_hex(0xff00ff),
          @math.Color::from_hex(0xffff00),
          @math.Color::from_hex(0x00ffff),
        ),
      )
      ignore(scene.add(axes))
      Some((scene, camera_at(2.5, 2.0, 3.0)))
    }
    "helpers_lights" => {
      add_spheres(scene)
      let directional = @core.DirectionalLight::new(
        color=@math.Color::from_hex(0xffffff),
        intensity=1.5,
      )
      ignore(directional.position.set(1.5, 1.5, 1.0))
      ignore(scene.add(directional))
      ignore(
        scene.add(@helpers.DirectionalLightHelper::new(directional, size=0.3)),
      )
      let point = @core.PointLight::new(
        color=@math.Color::from_hex(0xffaa44),
        intensity=4.0,
        distance=0.0,
        decay=2.0,
      )
      ignore(point.position.set(-1.2, 1.0, 0.8))
      ignore(scene.add(point))
      ignore(scene.add(@helpers.PointLightHelper::new(point, sphere_size=0.15)))
      let spot = @core.SpotLight::new(
        color=@math.Color::from_hex(0x44aaff),
        intensity=6.0,
        distance=4.0,
        angle=pi / 8.0,
        penumbra=0.2,
        decay=2.0,
      )
      ignore(spot.position.set(1.0, -1.2, 1.5))
      ignore(scene.add(spot))
      ignore(scene.add(@helpers.SpotLightHelper::new(spot)))
      let hemisphere = @core.HemisphereLight::new(
        sky_color=@math.Color::from_hex(0x8888ff),
        ground_color=@math.Color::from_hex(0x884422),
        intensity=0.5,
      )
      ignore(hemisphere.position.set(0.0, 1.2, -0.5))
      ignore(scene.add(hemisphere))
      ignore(
        scene.add(@helpers.HemisphereLightHelper::new(hemisphere, size=0.2)),
      )
      Some((scene, camera_at(0.0, 0.5, 4.5)))
    }
    "helpers_boxes_camera" => {
      let box = mesh(
        @geometries.BoxGeometry::new(width=0.8, height=0.6, depth=0.5),
        color(@core.MeshBasicMaterial::new(), 0x336699),
      )
      ignore(box.position.set(-0.8, 0.2, 0.0))
      ignore(box.rotation.set(0.4, 0.6, 0.2))
      ignore(scene.add(box))
      ignore(
        scene.add(
          @helpers.BoxHelper::new(
            object=box,
            color=@math.Color::from_hex(0xffff00),
          ),
        ),
      )
      let bounds = @math.Box3::new(
        min=@math.Vector3::new(0.3, -0.8, -0.5),
        max=@math.Vector3::new(1.3, -0.2, 0.3),
      )
      ignore(
        scene.add(
          @helpers.Box3Helper::new(
            box=bounds,
            color=@math.Color::from_hex(0x00ffff),
          ),
        ),
      )
      let watched = @core.PerspectiveCamera::new(
        fov=40.0,
        aspect=1.5,
        near=0.3,
        far=1.5,
      )
      ignore(watched.position.set(0.8, 0.6, 0.5))
      watched.look_at_xyz(-0.5, 0.0, -1.0)
      ignore(scene.add(watched))
      ignore(scene.add(@helpers.CameraHelper::new(watched)))
      let normal = @math.Vector3::new(0.0, 1.0, 0.3).normalize()
      ignore(
        scene.add(
          @helpers.PlaneHelper::new(
            plane=@math.Plane::new(normal~, constant=0.9),
            size=1.6,
            color=@math.Color::from_hex(0xff66cc),
          ),
        ),
      )
      let direction = @math.Vector3::new(1.0, 1.0, 0.0).normalize()
      ignore(
        scene.add(
          @helpers.ArrowHelper::new(
            dir=direction,
            origin=@math.Vector3::new(-1.5, -1.0, 0.0),
            length=1.2,
            color=@math.Color::from_hex(0xff8800),
          ),
        ),
      )
      Some((scene, camera_at(0.0, 1.0, 4.0)))
    }
    "helpers_skeleton" => {
      let light = @core.DirectionalLight::new(
        color=@math.Color::from_hex(0xffffff),
        intensity=2.0,
      )
      ignore(light.position.set(1.0, 2.0, 3.0))
      ignore(scene.add(light))
      ignore(
        scene.add(
          @core.AmbientLight::new(
            color=@math.Color::from_hex(0x404040),
            intensity=1.0,
          ),
        ),
      )
      let skin_geometry = @geometries.BoxGeometry::new(
        width=0.3,
        height=1.6,
        depth=0.3,
        width_segments=1.0,
        height_segments=8.0,
        depth_segments=1.0,
      )
      let skin_position = skin_geometry.attributes["position"]
      let skin_index : Array[Double] = []
      let skin_weight : Array[Double] = []
      for i in 0..<skin_position.count() {
        let y = skin_position.get_y(i)
        skin_index.push(
          if y > 0.3 {
            2.0
          } else if y > -0.3 {
            1.0
          } else {
            0.0
          },
        )
        skin_index.push(0.0)
        skin_index.push(0.0)
        skin_index.push(0.0)
        skin_weight.push(1.0)
        skin_weight.push(0.0)
        skin_weight.push(0.0)
        skin_weight.push(0.0)
      }
      ignore(
        skin_geometry.set_attribute(
          "skinIndex",
          @core.Uint16BufferAttribute::new(skin_index, 4),
        ),
      )
      ignore(
        skin_geometry.set_attribute(
          "skinWeight",
          @core.Float32BufferAttribute::new(skin_weight, 4),
        ),
      )
      let skinned = @core.SkinnedMesh::new(
        geometry=skin_geometry,
        material=Single(color(@core.MeshLambertMaterial::new(), 0x88cc44)),
      )
      let root = @core.Bone::new()
      root.position.y = -0.8
      let middle = @core.Bone::new()
      middle.position.y = 0.5
      let tip = @core.Bone::new()
      tip.position.y = 0.6
      ignore(root.add(middle))
      ignore(middle.add(tip))
      ignore(skinned.add(root))
      skinned.bind(@core.Skeleton::new(bones=[root, middle, tip]))
      middle.rotation.set_z(0.5)
      tip.rotation.set_z(0.6)
      ignore(skinned.position.set(-0.3, 0.0, 0.0))
      ignore(scene.add(skinned))
      ignore(scene.add(@helpers.SkeletonHelper::new(skinned)))
      Some((scene, camera_at(0.0, 0.0, 3.0)))
    }
    _ => build_objects_addon(name, renderer, scene)
  }
}

///|
/// Renders scene `name` into `canvas` with the port; false for an unknown name. The
/// renderer stays alive (and its frame in the drawing buffer) until `release_scene`.
pub fn render_scene(name : String, canvas : @webgl.HTMLCanvasElement) -> Bool {
  let renderer = @webgl.WebGLRenderer::new(
    canvas~,
    antialias=false,
    preserve_drawing_buffer=true,
  )
  renderer.set_pixel_ratio(1.0)
  renderer.set_size(WIDTH.to_double(), HEIGHT.to_double(), update_style=false)
  current.val = Some(renderer)
  match build(name, renderer) {
    Some((scene, camera)) => {
      renderer.render(scene, camera)
      true
    }
    None => false
  }
}

///|
/// Disposes the renderer of the last `render_scene` and releases its context.
pub fn release_scene() -> Unit {
  if current.val is Some(renderer) {
    renderer.dispose()
    renderer.force_context_loss()
    current.val = None
  }
}

///|
fn main {

}
