// Differential scenarios of the WebGLNodesHandler port (webgl_nodes_handler.mbt): node
// materials rendered by the classic WebGLRenderer on the recording mock context. The
// upstream side is diff/addons/tsl/a5/webgl_nodes/upstream.mjs, step for step; with
// WEBGL_DIFF=1 each scenario prints `@@WEBGL_LOG <name> <json>` and that directory's run.mjs
// compares the logs entry by entry. The scenarios run in one callback chain (a tick is a
// `setTimeout`, as upstream's `await`, so the handler's queued geometry disposals run in
// between), each from its own counter base.

///|
extern "js" fn wnh_diff_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.WEBGL_DIFF === '1'"

///|
extern "js" fn wnh_mock() -> @core.JsValue =
  #|() => {
  #|  const { createRequire } = process.getBuiltinModule( 'node:module' );
  #|  const fs = process.getBuiltinModule( 'node:fs' );
  #|  const path = process.getBuiltinModule( 'node:path' );
  #|  // diff/addons/tsl/a5/webgl_nodes/wnh_mock.cjs of this repository: walk up from the module root (moon test's cwd).
  #|  let root = process.cwd();
  #|  while ( ! fs.existsSync( path.join( root, 'diff/addons/tsl/a5/webgl_nodes/wnh_mock.cjs' ) ) ) {
  #|    const up = path.dirname( root );
  #|    if ( up === root ) throw new Error( 'diff/addons/tsl/a5/webgl_nodes/wnh_mock.cjs not found above ' + process.cwd() );
  #|    root = up;
  #|  }
  #|  return createRequire( '/' )( path.join( root, 'diff/addons/tsl/a5/webgl_nodes/wnh_mock.cjs' ) );
  #|}

///|
let wnh_module : @core.JsValue = wnh_mock()

///|
extern "js" fn wnh_create_gl(
  m : @core.JsValue,
  width : Int32,
  height : Int32,
) -> @webgl.WebGL2RenderingContext = "(m, width, height) => m.createGL( { canvas: { width, height } } )"

///|
extern "js" fn wnh_create_canvas(
  m : @core.JsValue,
  gl : @webgl.WebGL2RenderingContext,
  width : Int32,
  height : Int32,
) -> @webgl.HTMLCanvasElement = "(m, gl, width, height) => m.createMockCanvas( gl, width, height )"

///|
extern "js" fn wnh_note_string(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  value : String,
) -> Unit = "(gl, label, value) => gl.__note( label, value )"

///|
extern "js" fn wnh_note_number(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  value : Double,
) -> Unit = "(gl, label, value) => gl.__note( label, value )"

///|
extern "js" fn wnh_log_json(gl : @webgl.WebGL2RenderingContext) -> String = "(gl) => JSON.stringify( gl.__log )"

///|
extern "js" fn wnh_log_length(gl : @webgl.WebGL2RenderingContext) -> Int32 = "(gl) => gl.__log.length"

///|
extern "js" fn wnh_set_timeout(f : () -> Unit) -> Unit = "(f) => setTimeout( f, 0 )"

///|
/// One scenario: its name and its run, which calls `done( gl )` at the end.
priv struct WnhScenario {
  name : String
  run : ((@webgl.WebGL2RenderingContext) -> Unit) -> Unit
}

///|
/// The counters each scenario starts from: scenario `k` aligns to base + k * step.
fn wnh_align(k : Int32) -> Unit {
  fn advance(name : String, target : Int32, f : () -> Int32) -> Unit {
    let mut id = f()
    if id >= target {
      if wnh_diff_enabled() {
        abort("counter \{name} already at \{id}")
      }
      return
    }
    while id < target - 1 {
      id = f()
    }
  }

  advance("fn", 3000 + k * 1000, fn() {
    let f = @nodes.fn_(
      fn(_, _) { None },
      layout=@nodes.FnLayout::short([], return_="float"),
    )
    let name = @nodes.ShaderNodeInternal::get_layout(
        @nodes.FnNode::of(f).unwrap().shader_node,
      ).unwrap().name
    let mut v = 0
    for c in name.view(start_offset=2) {
      v = v * 10 + (c.to_int() - '0'.to_int())
    }
    v
  })
  advance("node", 300000 + k * 100000, fn() { @nodes.Node::alloc().id })
  advance("object3d", 10000 + k * 5000, fn() { @core.Object3D::new().id })
  advance("material", 10000 + k * 5000, fn() { @core.Material::new().id })
  advance("texture", 10000 + k * 5000, fn() { @core.Texture::new().id })
  advance("attribute", 10000 + k * 5000, fn() {
    @core.BufferAttribute::new(@core.TypedArray::float32(1), 1).id
  })
  advance("geometry", 10000 + k * 5000, fn() { @core.BufferGeometry::new().id })
}

///|
/// `setup( k, options )`: a mock context and canvas, a WebGLRenderer with the handler,
/// then the counters.
fn wnh_setup(
  k : Int32,
  width~ : Int32 = 64,
  height~ : Int32 = 32,
  antialias~ : Bool = false,
) -> (@webgl.WebGL2RenderingContext, @webgl.WebGLRenderer) {
  let gl = wnh_create_gl(wnh_module, width, height)
  let canvas = wnh_create_canvas(wnh_module, gl, width, height)
  let renderer = @webgl.WebGLRenderer::new(
    canvas~,
    context=gl,
    antialias~,
    output_buffer_type=@core.UnsignedByteType,
  )
  renderer.set_nodes_handler(@tsl.WebGLNodesHandler::new())
  wnh_align(k)
  wnh_note_string(gl, "setup", "done")
  (gl, renderer)
}

///|
fn wnh_nm(m : @core.Material) -> @nodes.NodeMaterial {
  @nodes.NodeMaterial::of(m).unwrap()
}

///|
fn wnh_camera() -> @core.Object3D {
  let camera = @core.PerspectiveCamera::new(
    fov=45.0,
    aspect=2.0,
    near=0.5,
    far=50.0,
  )
  camera.position.set(0.0, 1.0, 6.0) |> ignore
  camera.look_at_xyz(0.0, 0.0, 0.0)
  camera
}

///|
/// A chain of steps, each run on a later tick.
fn wnh_steps(steps : Array[() -> Unit], done : () -> Unit) -> Unit {
  fn go(i : Int32) -> Unit {
    if i >= steps.length() {
      done()
      return
    }
    steps[i]()
    wnh_set_timeout(() => go(i + 1))
  }

  go(0)
}

///|
fn wnh_basic(k : Int32, done : (@webgl.WebGL2RenderingContext) -> Unit) -> Unit {
  let (gl, renderer) = wnh_setup(k)
  let scene = @core.Scene::new()
  let camera = wnh_camera()
  let tint = @nodes.uniform(@math.Color::from_hex(0xff8800))
  let material = @nodes.MeshBasicNodeMaterial::new()
  wnh_nm(material).color_node = Some(tint)
  let mesh = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(width=1.0, height=1.0, depth=1.0),
    material=Single(material),
  )
  scene.add(mesh) |> ignore
  // a second mesh sharing the material (its object uniforms are uploaded per draw)
  let twin = @core.Mesh::new(
    geometry=@geometries.PlaneGeometry::new(width=1.0, height=1.0),
    material=Single(material),
  )
  twin.position.x = 1.5
  scene.add(twin) |> ignore
  wnh_steps(
    [
      () => renderer.render(scene, camera),
      () => {
        wnh_note_number(gl, "frame", 1.0)
        match @nodes.InputNode::get_value(tint) {
          Color(c) => c.set_hex(0x0088ff) |> ignore
          _ => ()
        }
        mesh.rotation.set_y(0.5)
        renderer.render(scene, camera)
      },
    ],
    () => done(gl),
  )
}

///|
fn wnh_set_material(object : @core.Object3D, material : @core.Material) -> Unit {
  match object.kind {
    Mesh(mesh) => mesh.material = Single(material)
    _ => abort("not a mesh")
  }
}

///|
fn wnh_color_value(node : @nodes.Node) -> @math.Color {
  match @nodes.InputNode::get_value(node) {
    Color(c) => c
    _ => abort("not a color uniform")
  }
}

///|
/// webgl_tsl_clearcoat: standard / physical node materials under ambient, directional and
/// point lights with fog and tone mapping; uniform and light updates over frames; a fog
/// change picked up after material.dispose(); a material swap.
fn wnh_lit(k : Int32, done : (@webgl.WebGL2RenderingContext) -> Unit) -> Unit {
  let (gl, renderer) = wnh_setup(k)
  renderer.tone_mapping = @core.ACESFilmicToneMapping
  renderer.tone_mapping_exposure = 1.25
  let scene = @core.Scene::new()
  scene.as_scene().fog = Some(
    Fog(
      @core.Fog::new(color=@math.Color::from_hex(0x222244), near=2.0, far=30.0),
    ),
  )
  let cam = wnh_camera()
  scene.add(
    @core.AmbientLight::new(
      color=@math.Color::from_hex(0x404040),
      intensity=2.0,
    ),
  )
  |> ignore
  let sun = @core.DirectionalLight::new(
    color=@math.Color::from_hex(0xffffff),
    intensity=3.0,
  )
  sun.position.set(3.0, 5.0, 2.0) |> ignore
  scene.add(sun) |> ignore
  let point = @core.PointLight::new(
    color=@math.Color::from_hex(0xff8844),
    intensity=30.0,
    distance=20.0,
    decay=2.0,
  )
  point.position.set(-2.0, 1.0, 2.0) |> ignore
  scene.add(point) |> ignore
  let geometry = @geometries.SphereGeometry::new(
    radius=0.8,
    width_segments=8.0,
    height_segments=6.0,
  )
  let tint = @nodes.uniform(@math.Color::from_hex(0x3366cc))
  let rough = @nodes.uniform(0.4)
  let standard = @nodes.MeshStandardNodeMaterial::new()
  standard.metalness = Some(0.2)
  wnh_nm(standard).color_node = Some(tint)
  @nodes.MeshStandardNodeMaterial::of(standard).unwrap().roughness_node = Some(
    rough,
  )
  let a = @core.Mesh::new(geometry~, material=Single(standard))
  a.position.x = -1.0
  scene.add(a) |> ignore
  let physical = @nodes.MeshPhysicalNodeMaterial::new()
  physical.set_clearcoat(1.0)
  physical.clearcoat_roughness = Some(0.1)
  physical.metalness = Some(0.9)
  physical.roughness = Some(0.5)
  physical.color.unwrap().set_hex(0x0000ff) |> ignore
  let b = @core.Mesh::new(geometry~, material=Single(physical))
  b.position.x = 1.0
  scene.add(b) |> ignore
  wnh_steps(
    [
      () => renderer.render(scene, cam),
      () => {
        wnh_note_number(gl, "frame", 1.0)
        wnh_color_value(tint).set_hex(0xcc6633) |> ignore
        @nodes.InputNode::set_value(rough, Number(0.8))
        point.position.set(2.0, 2.0, 1.0) |> ignore
        sun.as_light().intensity = 1.5
        renderer.render(scene, cam)
      },
      () => {
        wnh_note_number(gl, "frame", 2.0)
        scene.as_scene().fog = Some(
          FogExp2(
            @core.FogExp2::new(
              color=@math.Color::from_hex(0x101010),
              density=0.05,
            ),
          ),
        )
        standard.dispose()
        physical.clearcoat_roughness = Some(0.3)
        renderer.render(scene, cam)
      },
      () => {
        wnh_note_number(gl, "frame", 3.0)
        let basic = @nodes.MeshBasicNodeMaterial::new()
        basic.color.unwrap().set_hex(0x00ff00) |> ignore
        wnh_set_material(b, basic)
        renderer.tone_mapping = @core.NoToneMapping
        renderer.render(scene, cam)
      },
    ],
    () => done(gl),
  )
}

///|
/// scene.environment: an equirectangular float DataTexture, prefiltered by the WebGL
/// PMREMGenerator the builder gives the PMREMNode (a nested render during the build).
fn wnh_env(k : Int32, done : (@webgl.WebGL2RenderingContext) -> Unit) -> Unit {
  let (gl, renderer) = wnh_setup(k)
  let scene = @core.Scene::new()
  let cam = wnh_camera()
  let data : Array[Double] = []
  for i in 0..<(8 * 4 * 4) {
    data.push((i % 7).to_double() / 6.0)
  }
  let env = @core.DataTexture::new(
    data=@core.TypedArray::float32(data),
    width=8,
    height=4,
    format=@core.RGBAFormat,
    type_=@core.FloatType,
  )
  env.mapping = @core.EquirectangularReflectionMapping
  env.set_needs_update(true)
  scene.as_scene().environment = Some(env)
  scene.as_scene().background = Some(Color(@math.Color::from_hex(0x112233)))
  let material = @nodes.MeshStandardNodeMaterial::new()
  material.roughness = Some(0.3)
  material.metalness = Some(1.0)
  let mesh = @core.Mesh::new(
    geometry=@geometries.SphereGeometry::new(
      radius=1.0,
      width_segments=8.0,
      height_segments=6.0,
    ),
    material=Single(material),
  )
  scene.add(mesh) |> ignore
  wnh_steps(
    [
      () => renderer.render(scene, cam),
      () => {
        wnh_note_number(gl, "frame", 1.0)
        material.roughness = Some(0.7)
        scene.as_scene().environment_intensity = 0.5
        renderer.render(scene, cam)
      },
    ],
    () => done(gl),
  )
}

///|
fn wnh_instance_matrix(mesh : @core.Object3D) -> @core.BufferAttribute {
  match mesh.kind {
    Mesh({ kind: InstancedMesh(im), .. }) => im.instance_matrix
    _ => abort("not an instanced mesh")
  }
}

///|
/// webgl_tsl_instancing: an InstancedMesh with a phong node material whose colorNode
/// reads positionWorld and a uniform; instance matrix / color updates over frames.
fn wnh_instancing(
  k : Int32,
  done : (@webgl.WebGL2RenderingContext) -> Unit,
) -> Unit {
  let (gl, renderer) = wnh_setup(k)
  let scene = @core.Scene::new()
  scene.as_scene().background = Some(Color(@math.Color::from_hex(0xffffff)))
  let cam = wnh_camera()
  scene.add(
    @core.AmbientLight::new(
      color=@math.Color::from_hex(0xffffff),
      intensity=2.0,
    ),
  )
  |> ignore
  let sun = @core.DirectionalLight::new(
    color=@math.Color::from_hex(0xffffff),
    intensity=1.0,
  )
  sun.position.set(1.0, 2.0, 3.0) |> ignore
  scene.add(sun) |> ignore
  let t = @nodes.uniform(0.0)
  let pos_y = @nodes.position_world
  let material = @nodes.MeshPhongNodeMaterial::new()
  wnh_nm(material).color_node = Some(
    @nodes.vec3_of([
      @nodes.sin(pos_y.mul(0.1).add(t)).mul(0.5).add(0.5).x(),
      @nodes.sin(pos_y.mul(0.1).add(t.mul(0.5).add(2))).mul(0.5).add(0.5).y(),
      @nodes.sin(pos_y.mul(0.1).add(t.mul(1.5).add(4))).mul(0.5).add(0.5).z(),
    ]),
  )
  let geometry = @geometries.BoxGeometry::new(width=0.3, height=0.3, depth=0.3)
  let mesh = @core.InstancedMesh::new(geometry~, material=Single(material), 4)
  let matrix = @math.Matrix4::new()
  for i in 0..<4 {
    matrix.make_translation(i.to_double() - 1.5, (i % 2).to_double() * 0.5, 0.0)
    |> ignore
    mesh.set_matrix_at(i, matrix) |> ignore
    mesh.set_color_at(
      i,
      @math.Color::new(i.to_double() / 4.0, 1.0 - i.to_double() / 4.0, 0.5),
    )
    |> ignore
  }
  scene.add(mesh) |> ignore
  wnh_steps(
    [
      () => renderer.render(scene, cam),
      () => {
        wnh_note_number(gl, "frame", 1.0)
        @nodes.InputNode::set_value(t, Number(0.75))
        matrix.make_translation(0.0, 1.0, 0.0) |> ignore
        mesh.set_matrix_at(2, matrix) |> ignore
        wnh_instance_matrix(mesh).set_needs_update(true)
        renderer.render(scene, cam)
      },
      () => {
        wnh_note_number(gl, "frame", 2.0)
        @nodes.InputNode::set_value(t, Number(1.5))
        renderer.render(scene, cam)
      },
    ],
    () => done(gl),
  )
}

///|
/// webgl_tsl_skinning: a SkinnedMesh with a standard node material; bone updates.
fn wnh_skinning(
  k : Int32,
  done : (@webgl.WebGL2RenderingContext) -> Unit,
) -> Unit {
  let (gl, renderer) = wnh_setup(k)
  let scene = @core.Scene::new()
  let cam = wnh_camera()
  scene.add(
    @core.HemisphereLight::new(
      sky_color=@math.Color::from_hex(0x8888ff),
      ground_color=@math.Color::from_hex(0x442200),
      intensity=2.0,
    ),
  )
  |> ignore
  let sun = @core.DirectionalLight::new(
    color=@math.Color::from_hex(0xffffff),
    intensity=2.0,
  )
  sun.position.set(1.0, 3.0, 2.0) |> ignore
  scene.add(sun) |> ignore
  let geometry = @geometries.BoxGeometry::new(
    width=0.4,
    height=2.0,
    depth=0.4,
    width_segments=1.0,
    height_segments=4.0,
    depth_segments=1.0,
  )
  let position = geometry.attributes["position"]
  let skin_index : Array[Double] = []
  let skin_weight : Array[Double] = []
  for i in 0..<position.count() {
    let y = position.get_y(i) + 1.0
    let w = y / 2.0
    skin_index.push_iter([0.0, 1.0, 0.0, 0.0].iter())
    skin_weight.push_iter([1.0 - w, w, 0.0, 0.0].iter())
  }
  geometry.set_attribute(
    "skinIndex",
    @core.Uint16BufferAttribute::new(skin_index, 4),
  )
  |> ignore
  geometry.set_attribute(
    "skinWeight",
    @core.Float32BufferAttribute::new(skin_weight, 4),
  )
  |> ignore
  let material = @nodes.MeshStandardNodeMaterial::new()
  material.color.unwrap().set_hex(0xaa6633) |> ignore
  material.roughness = Some(0.6)
  let mesh = @core.SkinnedMesh::new(geometry~, material=Single(material))
  let root = @core.Bone::new()
  root.position.y = -1.0
  let tip = @core.Bone::new()
  tip.position.y = 2.0
  root.add(tip) |> ignore
  mesh.add(root) |> ignore
  mesh.bind(@core.Skeleton::new(bones=[root, tip]))
  scene.add(mesh) |> ignore
  wnh_steps(
    [
      () => renderer.render(scene, cam),
      () => {
        wnh_note_number(gl, "frame", 1.0)
        tip.rotation.set_z(0.5)
        root.rotation.set_x(0.2)
        renderer.render(scene, cam)
      },
      () => {
        wnh_note_number(gl, "frame", 2.0)
        tip.rotation.set_z(-0.3)
        renderer.render(scene, cam)
      },
    ],
    () => done(gl),
  )
}

///|
/// webgl_tsl_shadowmap: directional and spot light shadows (WebGLRenderer's shadow maps
/// read by the node shadows), a maskNode material clone, receiveShadow changes forcing
/// program updates, fog.
fn wnh_shadow(
  k : Int32,
  done : (@webgl.WebGL2RenderingContext) -> Unit,
) -> Unit {
  let (gl, renderer) = wnh_setup(k)
  renderer.shadow_map.enabled = true
  let scene = @core.Scene::new()
  scene.as_scene().fog = Some(
    Fog(
      @core.Fog::new(color=@math.Color::from_hex(0x222244), near=5.0, far=40.0),
    ),
  )
  let cam = wnh_camera()
  scene.add(
    @core.AmbientLight::new(
      color=@math.Color::from_hex(0x444444),
      intensity=2.0,
    ),
  )
  |> ignore
  let spot = @core.SpotLight::new(
    color=@math.Color::from_hex(0xff8888),
    intensity=40.0,
  )
  match spot.as_light().kind {
    SpotLight(s) => {
      s.angle = @tsl.ADDON_PI / 5.0
      s.penumbra = 0.3
    }
    _ => ()
  }
  spot.position.set(3.0, 5.0, 2.0) |> ignore
  spot.cast_shadow = true
  let spot_shadow = spot.as_light().shadow.unwrap()
  spot_shadow.camera.as_perspective_camera().near = 1.0
  spot_shadow.camera.as_perspective_camera().far = 20.0
  spot_shadow.map_size.set(32.0, 32.0) |> ignore
  scene.add(spot) |> ignore
  let dir = @core.DirectionalLight::new(
    color=@math.Color::from_hex(0x8888ff),
    intensity=3.0,
  )
  dir.position.set(2.0, 6.0, 4.0) |> ignore
  dir.cast_shadow = true
  let dir_shadow = dir.as_light().shadow.unwrap()
  let ortho = dir_shadow.camera.as_orthographic_camera()
  ortho.left = -4.0
  ortho.right = 4.0
  ortho.top = 4.0
  ortho.bottom = -4.0
  dir_shadow.map_size.set(32.0, 32.0) |> ignore
  let group = @core.Group::new()
  group.add(dir) |> ignore
  scene.add(group) |> ignore
  let material = @nodes.MeshPhongNodeMaterial::new()
  material.color.unwrap().set_hex(0x999999) |> ignore
  material.shininess = Some(0.0)
  material.specular.unwrap().set_hex(0x222222) |> ignore
  let masked = material.clone()
  masked.transparent = true
  wnh_nm(masked).mask_node = Some(@nodes.position_local.x().greater_than(0.0))
  let knot = @core.Mesh::new(
    geometry=@geometries.TorusGeometry::new(
      radius=0.6,
      tube=0.2,
      radial_segments=6.0,
      tubular_segments=8.0,
    ),
    material=Single(masked),
  )
  knot.position.y = 1.0
  knot.cast_shadow = true
  knot.receive_shadow = true
  scene.add(knot) |> ignore
  let pillar = @core.Mesh::new(
    geometry=@geometries.CylinderGeometry::new(
      radius_top=0.2,
      radius_bottom=0.2,
      height=2.0,
      radial_segments=6.0,
    ),
    material=Single(material),
  )
  pillar.position.set(1.5, 1.0, 0.0) |> ignore
  pillar.cast_shadow = true
  scene.add(pillar) |> ignore
  let ground_material = @nodes.MeshPhongNodeMaterial::new()
  ground_material.color.unwrap().set_hex(0x999999) |> ignore
  ground_material.shininess = Some(0.0)
  wnh_nm(ground_material).color_node = Some(
    @nodes.fn_((_, _) => {
      Some(@nodes.position_world.xz().mul(0.1).sin().x().mul(0.2).add(0.5))
    }).call([]),
  )
  let ground = @core.Mesh::new(
    geometry=@geometries.PlaneGeometry::new(width=10.0, height=10.0),
    material=Single(ground_material),
  )
  ground.rotation.set_x(-@tsl.ADDON_PI / 2.0)
  ground.receive_shadow = true
  scene.add(ground) |> ignore
  wnh_steps(
    [
      () => renderer.render(scene, cam),
      () => {
        wnh_note_number(gl, "frame", 1.0)
        group.rotation.set_y(0.4)
        knot.rotation.set_x(0.3)
        renderer.render(scene, cam)
      },
      () => {
        wnh_note_number(gl, "frame", 2.0)
        pillar.receive_shadow = true
        renderer.render(scene, cam)
      },
      () => {
        wnh_note_number(gl, "frame", 3.0)
        pillar.receive_shadow = false
        renderer.render(scene, cam)
      },
    ],
    () => done(gl),
  )
}

///|
/// renderer.compile, then frames, then disposing materials, geometries and the renderer.
fn wnh_compile_dispose(
  k : Int32,
  done : (@webgl.WebGL2RenderingContext) -> Unit,
) -> Unit {
  let (gl, renderer) = wnh_setup(k)
  let scene = @core.Scene::new()
  let cam = wnh_camera()
  scene.add(
    @core.PointLight::new(color=@math.Color::from_hex(0xffffff), intensity=20.0),
  )
  |> ignore
  let tint = @nodes.uniform(@math.Color::from_hex(0x44aa88))
  let lambert = @nodes.MeshLambertNodeMaterial::new()
  wnh_nm(lambert).color_node = Some(tint)
  let a = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(),
    material=Single(lambert),
  )
  a.position.set(-1.0, 0.0, -1.0) |> ignore
  scene.add(a) |> ignore
  let basic = @nodes.MeshBasicNodeMaterial::new()
  basic.color.unwrap().set_hex(0xff0000) |> ignore
  basic.transparent = true
  basic.opacity = 0.5
  let b = @core.Mesh::new(
    geometry=@geometries.PlaneGeometry::new(),
    material=Single(basic),
  )
  b.position.set(1.0, 0.0, 0.0) |> ignore
  scene.add(b) |> ignore
  wnh_steps(
    [
      () => renderer.compile(scene, cam) |> ignore,
      () => {
        wnh_note_number(gl, "compiled", 1.0)
        renderer.render(scene, cam)
      },
      () => {
        wnh_note_number(gl, "frame", 1.0)
        wnh_color_value(tint).set_hex(0x8844aa) |> ignore
        basic.opacity = 0.25
        renderer.render(scene, cam)
      },
      () => {
        wnh_note_number(gl, "frame", 2.0)
        lambert.dispose()
        a.get_geometry().unwrap().dispose()
        renderer.render(scene, cam)
      },
      () => {
        wnh_note_number(gl, "frame", 3.0)
        basic.dispose()
        renderer.dispose()
      },
    ],
    () => done(gl),
  )
}

///|
/// Buffer uniforms (uniformArray: a UniformsGroup per buffer, named by the builder),
/// int / uint uniforms in the groups, a texture node (a sampler uniform) whose value
/// changes, a mesh shared by two scenes.
fn wnh_arrays(
  k : Int32,
  done : (@webgl.WebGL2RenderingContext) -> Unit,
) -> Unit {
  let (gl, renderer) = wnh_setup(k)
  let scene = @core.Scene::new()
  let cam = wnh_camera()
  let palette = @nodes.uniform_array(
    @nodes.TslValue::Array([
      Color(@math.Color::from_hex(0xff0000)),
      Color(@math.Color::from_hex(0x00ff00)),
      Color(@math.Color::from_hex(0x0000ff)),
    ]),
  )
  let index = @nodes.uniform(1, type_="int")
  let count = @nodes.uniform(2, type_="uint")
  let weights = @nodes.uniform_array(
    @nodes.TslValue::Array([
      Number(0.25),
      Number(0.5),
      Number(0.75),
      Number(1.0),
    ]),
    element_type="float",
  )
  let pixels : Array[Double] = []
  for i in 0..<(4 * 4 * 4) {
    pixels.push((i * 37 % 256).to_double())
  }
  let map = @core.DataTexture::new(
    data=@core.TypedArray::new(Uint8Array, pixels),
    width=4,
    height=4,
  )
  map.set_needs_update(true)
  let other = @core.DataTexture::new(
    data=@core.TypedArray::new(Uint8Array, Array::make(2 * 2 * 4, 200.0)),
    width=2,
    height=2,
  )
  other.set_needs_update(true)
  let sampled = @nodes.texture(@nodes.TslValue::Texture(map))
  let material = @nodes.MeshBasicNodeMaterial::new()
  wnh_nm(material).color_node = Some(
    palette.element(index).mul(weights.element(count)).mul(sampled.rgb()),
  )
  let mesh = @core.Mesh::new(
    geometry=@geometries.PlaneGeometry::new(width=2.0, height=2.0),
    material=Single(material),
  )
  scene.add(mesh) |> ignore
  wnh_steps(
    [
      () => renderer.render(scene, cam),
      () => {
        wnh_note_number(gl, "frame", 1.0)
        @nodes.InputNode::set_value(index, Number(2.0))
        @nodes.InputNode::set_value(count, Number(3.0))
        match @nodes.UniformArrayNode::of(palette).unwrap().array[2] {
          Color(c) => c.set_hex(0xffff00) |> ignore
          _ => ()
        }
        @nodes.UniformArrayNode::of(weights).unwrap().array[3] = Number(0.125)
        @nodes.TextureNode::set_value(sampled, Some(other))
        renderer.render(scene, cam)
      },
      () => {
        wnh_note_number(gl, "frame", 2.0)
        let second = @core.Scene::new()
        second.add(
          @core.AmbientLight::new(
            color=@math.Color::from_hex(0xffffff),
            intensity=1.0,
          ),
        )
        |> ignore
        second.add(mesh) |> ignore
        renderer.render(second, cam)
      },
    ],
    () => done(gl),
  )
}

///|
/// A cube texture environment (cubeTexture node, PMREM from a cube map), changed after
/// dispose; MeshPhysicalNodeMaterial sheen / iridescence.
fn wnh_cube_env(
  k : Int32,
  done : (@webgl.WebGL2RenderingContext) -> Unit,
) -> Unit {
  let (gl, renderer) = wnh_setup(k)
  let scene = @core.Scene::new()
  let cam = wnh_camera()
  let face = (v : Double) => {
    @core.TextureImage::TextureImage(
      @core.DataTexture::new(
        data=@core.TypedArray::float32(Array::make(4 * 4 * 4, v)),
        width=4,
        height=4,
        format=@core.RGBAFormat,
        type_=@core.FloatType,
      ),
    )
  }
  let env = @core.CubeTexture::new(images=[
    face(0.1),
    face(0.2),
    face(0.3),
    face(0.4),
    face(0.5),
    face(0.6),
  ])
  env.type_ = @core.FloatType
  env.format = @core.RGBAFormat
  env.set_needs_update(true)
  scene.as_scene().environment = Some(env)
  let material = @nodes.MeshPhysicalNodeMaterial::new()
  material.roughness = Some(0.2)
  material.metalness = Some(0.5)
  material.set_sheen(1.0)
  material.sheen_roughness = Some(0.4)
  material.set_iridescence(0.5)
  let mesh = @core.Mesh::new(
    geometry=@geometries.SphereGeometry::new(
      radius=1.0,
      width_segments=8.0,
      height_segments=6.0,
    ),
    material=Single(material),
  )
  scene.add(mesh) |> ignore
  wnh_steps(
    [
      () => renderer.render(scene, cam),
      () => {
        wnh_note_number(gl, "frame", 1.0)
        scene.as_scene().environment = None
        material.dispose()
        renderer.render(scene, cam)
      },
    ],
    () => done(gl),
  )
}

///|
/// A point light shadow (PointShadowNode reading WebGLRenderer's cube shadow map), soft
/// shadows, renderer.compile with a target scene, a second camera.
fn wnh_point_shadow(
  k : Int32,
  done : (@webgl.WebGL2RenderingContext) -> Unit,
) -> Unit {
  let (gl, renderer) = wnh_setup(k)
  renderer.shadow_map.enabled = true
  renderer.shadow_map.type_ = @core.PCFSoftShadowMap
  let scene = @core.Scene::new()
  let cam = wnh_camera()
  let point = @core.PointLight::new(
    color=@math.Color::from_hex(0xffffff),
    intensity=30.0,
  )
  point.position.set(0.0, 2.0, 0.0) |> ignore
  point.cast_shadow = true
  point.as_light().shadow.unwrap().map_size.set(16.0, 16.0) |> ignore
  scene.add(point) |> ignore
  let material = @nodes.MeshStandardNodeMaterial::new()
  material.color.unwrap().set_hex(0x8899aa) |> ignore
  let ball = @core.Mesh::new(
    geometry=@geometries.SphereGeometry::new(
      radius=0.5,
      width_segments=8.0,
      height_segments=6.0,
    ),
    material=Single(material),
  )
  ball.cast_shadow = true
  ball.receive_shadow = true
  scene.add(ball) |> ignore
  let floor = @core.Mesh::new(
    geometry=@geometries.PlaneGeometry::new(width=6.0, height=6.0),
    material=Single(@nodes.MeshLambertNodeMaterial::new()),
  )
  floor.rotation.set_x(-@tsl.ADDON_PI / 2.0)
  floor.position.y = -1.0
  floor.receive_shadow = true
  let extra = @core.Scene::new()
  extra.add(floor) |> ignore
  wnh_steps(
    [
      () => renderer.compile(extra, cam, target_scene=scene) |> ignore,
      () => {
        wnh_note_number(gl, "compiled", 1.0)
        scene.add(floor) |> ignore
        renderer.render(scene, cam)
      },
      () => {
        wnh_note_number(gl, "frame", 1.0)
        let top = @core.OrthographicCamera::new(
          left=-3.0,
          right=3.0,
          top=1.5,
          bottom=-1.5,
          near=0.1,
          far=20.0,
        )
        top.position.set(0.0, 8.0, 0.0) |> ignore
        top.look_at_xyz(0.0, 0.0, 0.0)
        point.position.x = 1.0
        renderer.render(scene, top)
      },
    ],
    () => done(gl),
  )
}

///|
fn wnh_scenarios() -> Array[WnhScenario] {
  let all : Array[
    (String, (Int32, (@webgl.WebGL2RenderingContext) -> Unit) -> Unit),
  ] = [
    ("wnh_basic", wnh_basic),
    ("wnh_lit", wnh_lit),
    ("wnh_env", wnh_env),
    ("wnh_instancing", wnh_instancing),
    ("wnh_skinning", wnh_skinning),
    ("wnh_shadow", wnh_shadow),
    ("wnh_compile_dispose", wnh_compile_dispose),
    ("wnh_arrays", wnh_arrays),
    ("wnh_cube_env", wnh_cube_env),
    ("wnh_point_shadow", wnh_point_shadow),
    // SCENARIOS
  ]
  all.mapi((k, s) => { name: s.0, run: done => (s.1)(k, done), })
}

///|
test "webgl nodes handler scenarios" {
  let scenarios = wnh_scenarios()
  fn go(i : Int32) -> Unit {
    if i >= scenarios.length() {
      return
    }
    let s = scenarios[i]
    (s.run)(gl => {
      if wnh_diff_enabled() {
        println("@@WEBGL_LOG " + s.name + " " + wnh_log_json(gl))
      } else if wnh_log_length(gl) < 100 {
        abort("\{s.name}: short log")
      }
      go(i + 1)
    })
  }

  go(0)
}
