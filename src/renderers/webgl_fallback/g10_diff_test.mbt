// MoonBit side of the G10 mock-gl differential scenarios: `Renderer::new(
// WebGLBackend::new( parameters ) )` with the StandardNodeLibrary (what
// `WebGPURenderer( { forceWebGL: true } )` builds) renders on the recording mock WebGL 2
// context. Each scenario is the test "g10diff <name>" and prints `@@G10_LOG <name>
// <json>` with G10_DIFF=1; the upstream side is scenarios.mjs of the
// diff/core/g10 harness (`node harness/run.mjs`), which compares the logs entry by entry.

///|
/// Advances the global id counters to the values upstream's harness uses.
fn g10_align() -> Unit {
  fn advance(name : String, target : Int32, f : () -> Int32) -> Unit {
    let mut id = f()
    if id >= target {
      abort("counter \{name} already at \{id}")
    }
    while id < target - 1 {
      id = f()
    }
  }

  // module-level nodes have upstream's ids below this; run-time ones count from it
  let first = @nodes.Node::alloc().id
  if first < @nodes.NODE_FIRST_RUNTIME_ID {
    abort("node counter at \{first}, below the first run-time id")
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
/// The fake `self` / `requestAnimationFrame` of common.mjs.
extern "js" fn g10_install_frames(gl : @webgl.WebGL2RenderingContext) -> Unit =
  #|( gl ) => {
  #|  const callbacks = [];
  #|  globalThis.self = {
  #|    requestAnimationFrame( cb ) { callbacks.push( cb ); return callbacks.length; },
  #|    cancelAnimationFrame( id ) { gl.__note( 'cancelAnimationFrame', id ); },
  #|  };
  #|  globalThis.requestAnimationFrame = ( cb ) => { callbacks.push( cb ); return callbacks.length; };
  #|}

///|
/// `makeCanvas( gl, width, height )` of common.mjs.
extern "js" fn g10_make_canvas(
  gl : @webgl.WebGL2RenderingContext,
  width : Int32,
  height : Int32,
) -> @core.JsValue =
  #|( gl, width, height ) => ( {
  #|  style: {}, width, height,
  #|  addEventListener( type ) { gl.__note( 'canvas.addEventListener', type ); },
  #|  removeEventListener( type ) { gl.__note( 'canvas.removeEventListener', type ); },
  #|  setAttribute() {},
  #|  getContext( type, attributes ) { gl.__note( 'getContext ' + type, JSON.stringify( attributes ) ); return gl; },
  #|} )

///|
/// A scenario's renderer: `makeRenderer( options, mockOptions )` of common.mjs.
priv struct G10Context {
  renderer : @nodes.Renderer
  gl : @webgl.WebGL2RenderingContext
  canvas : @core.JsValue
}

///|
fn g10_make_renderer(
  width~ : Int32 = 300,
  height~ : Int32 = 150,
  mock~ : String = "{}",
  parameters? : @core.JsValue,
  antialias~ : Bool = false,
  samples~ : Int32 = 0,
  stencil~ : Bool = false,
  depth~ : Bool = true,
  alpha~ : Bool = true,
  reversed_depth_buffer~ : Bool = false,
  logarithmic_depth_buffer~ : Bool = false,
) -> G10Context {
  let gl = g10_mock_gl(options=mock)
  g10_install_frames(gl)
  let canvas = g10_make_canvas(gl, width, height)
  let parameters = match parameters {
    Some(p) => p
    None => @core.JsValue::object()
  }
  parameters.set("canvas", canvas)
  parameters.set("forceWebGL", @core.JsValue::of(true))
  let backend = @webgl_fallback.WebGLBackend::new(parameters~)
  let renderer = @nodes.Renderer::new(
    backend,
    antialias~,
    samples~,
    stencil~,
    depth~,
    alpha~,
    reversed_depth_buffer~,
    logarithmic_depth_buffer~,
  )
  renderer.library = g10_standard_node_library()
  renderer.init()
  { renderer, gl, canvas, }
}

///|
fn g10_box(material : @core.Material) -> @core.Object3D {
  @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(width=1, height=1, depth=1),
    material=Single(material),
  )
}

///|
fn g10_camera() -> @core.Object3D {
  let c = @core.PerspectiveCamera::new(fov=50, aspect=2, near=0.1, far=100)
  c.position.set(0, 0, 3) |> ignore
  c
}

///|
fn g10_basic(hex : Int32) -> @core.Material {
  let m = @nodes.MeshBasicNodeMaterial::new()
  m.color = Some(@math.Color::from_hex(hex))
  m
}

///|
/// Runs a scenario when `G10_DIFF=1` (the harness selects one with `-f`).
fn g10_scenario(name : String, f : () -> @webgl.WebGL2RenderingContext) -> Unit {
  if !g10_diff_enabled() {
    return
  }
  g10_align()
  let gl = f()
  g10_emit_log(name, gl)
}

///|
/// `g10_scenario` for a scenario that finishes in a callback (promises settle after the
/// test body returns, as upstream's `await`s do).
fn g10_scenario_async(
  name : String,
  f : ((@webgl.WebGL2RenderingContext) -> Unit) -> Unit,
) -> Unit {
  if !g10_diff_enabled() {
    return
  }
  g10_align()
  f(fn(gl) { g10_emit_log(name, gl) })
}

///|
test "g10diff init_basic" {
  g10_scenario("init_basic", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    g10_note(
      gl,
      "coordinateSystem",
      @core.JsValue::of(renderer.coordinate_system()),
    )
    g10_note(
      gl,
      "hasFeature multi_draw",
      @core.JsValue::of(renderer.has_feature("WEBGL_multi_draw")),
    )
    g10_note(
      gl,
      "hasFeature timestamp",
      @core.JsValue::of(renderer.has_feature("timestamp-query")),
    )
    gl
  })
}

///|
test "g10diff render_basic" {
  g10_scenario("render_basic", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    let scene = @core.Scene::new()
    scene.add(g10_box(g10_basic(0xff0000))) |> ignore
    renderer.render(scene, g10_camera())
    g10_note(gl, "frame", @core.JsValue::of(2))
    renderer.render(scene, g10_camera())
    gl
  })
}

///|
fn g10_params(pairs : Array[(String, @core.JsValue)]) -> @core.JsValue {
  let p = @core.JsValue::object()
  for pair in pairs {
    p.set(pair.0, pair.1)
  }
  p
}

///|
fn g10_add_box(
  scene : @core.Object3D,
  material : @core.Material,
  x? : Double,
) -> @core.Object3D {
  let o = g10_box(material)
  match x {
    Some(x) => o.position.x = x
    None => ()
  }
  scene.add(o) |> ignore
  o
}

///|
fn g10_shadow(light : @core.Object3D) -> @core.LightShadow {
  light.as_light().shadow.unwrap()
}

///|
test "g10diff init_options" {
  g10_scenario("init_options", fn() {
    let { renderer, gl, .. } = g10_make_renderer(
      parameters=g10_params([
        ("antialias", @core.JsValue::of(true)),
        ("stencil", @core.JsValue::of(true)),
        ("reversedDepthBuffer", @core.JsValue::of(true)),
      ]),
      antialias=true,
      stencil=true,
      reversed_depth_buffer=true,
    )
    g10_note(gl, "samples", @core.JsValue::of(renderer.samples()))
    g10_note(
      gl,
      "reversedDepthBuffer",
      @core.JsValue::of(renderer.reversed_depth_buffer),
    )
    g10_note(
      gl,
      "maxAnisotropy",
      @core.JsValue::of(renderer.get_max_anisotropy()),
    )
    g10_note(
      gl,
      "hasTimestamp",
      @core.JsValue::of(renderer.backend.has_timestamp()),
    )
    let scene = @core.Scene::new()
    g10_add_box(scene, @nodes.MeshBasicNodeMaterial::new()) |> ignore
    renderer.render(scene, g10_camera())
    gl
  })
}

///|
test "g10diff init_no_extensions" {
  g10_scenario("init_no_extensions", fn() {
    let { renderer, gl, .. } = g10_make_renderer(
      mock="{\"extensions\":[]}",
      parameters=g10_params([
        ("reversedDepthBuffer", @core.JsValue::of(true)),
        ("samples", @core.JsValue::of(2)),
      ]),
      reversed_depth_buffer=true,
      samples=2,
    )
    g10_note(
      gl,
      "reversedDepthBuffer",
      @core.JsValue::of(renderer.reversed_depth_buffer),
    )
    g10_note(
      gl,
      "maxAnisotropy",
      @core.JsValue::of(renderer.get_max_anisotropy()),
    )
    g10_note(
      gl,
      "float32Filterable",
      @core.JsValue::of(renderer.has_feature("float32-filterable")),
    )
    let scene = @core.Scene::new()
    g10_add_box(scene, @nodes.MeshBasicNodeMaterial::new()) |> ignore
    renderer.render(scene, g10_camera())
    gl
  })
}

///|
test "g10diff materials_unlit" {
  g10_scenario("materials_unlit", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    let scene = @core.Scene::new()
    let m0 = g10_basic(0x00ff00)
    m0.transparent = true
    m0.opacity = 0.5
    let points = @nodes.PointsNodeMaterial::new()
    points.size = Some(3)
    g10_add_box(scene, m0, x=-1) |> ignore
    let normal = @nodes.MeshNormalNodeMaterial::new()
    g10_add_box(scene, normal) |> ignore
    normal.side = @core.DoubleSide
    let m2 = g10_add_box(scene, @nodes.MeshMatcapNodeMaterial::new())
    m2.scale.x = -1
    let line_geometry = @core.BufferGeometry::new().set_from_points([
      @math.Vector3::new(0, 0, 0),
      @math.Vector3::new(1, 1, 0),
      @math.Vector3::new(1, 0, 0),
    ])
    scene.add(
      @core.Line::new(
        geometry=line_geometry,
        material=Single(@nodes.LineBasicNodeMaterial::new()),
      ),
    )
    |> ignore
    scene.add(
      @core.LineSegments::new(
        geometry=line_geometry,
        material=Single(@nodes.LineBasicNodeMaterial::new()),
      ),
    )
    |> ignore
    scene.add(
      @core.LineLoop::new(
        geometry=line_geometry,
        material=Single(@nodes.LineBasicNodeMaterial::new()),
      ),
    )
    |> ignore
    scene.add(
      @core.Points::new(geometry=line_geometry, material=Single(points)),
    )
    |> ignore
    scene.add(@core.Sprite::new(material=@nodes.SpriteNodeMaterial::new()))
    |> ignore
    let wire = g10_basic(0xffffff)
    wire.wireframe = Some(true)
    g10_add_box(scene, wire) |> ignore
    renderer.render(scene, g10_camera())
    gl
  })
}

///|
test "g10diff materials_lit" {
  g10_scenario("materials_lit", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    let scene = @core.Scene::new()
    scene.add(
      @core.AmbientLight::new(
        color=@math.Color::from_hex(0x404040),
        intensity=1,
      ),
    )
    |> ignore
    let dir = @core.DirectionalLight::new(
      color=@math.Color::from_hex(0xffffff),
      intensity=2,
    )
    dir.position.set(1, 2, 3) |> ignore
    scene.add(dir) |> ignore
    let point = @core.PointLight::new(
      color=@math.Color::from_hex(0xff8800),
      intensity=3,
      distance=10,
      decay=2,
    )
    point.position.set(-1, 1, 1) |> ignore
    scene.add(point) |> ignore
    let spot = @core.SpotLight::new(
      color=@math.Color::from_hex(0x88ff00),
      intensity=2,
      distance=20,
      angle=@cmath.PI / 6,
      penumbra=0.2,
      decay=2,
    )
    spot.position.set(0, 3, 0) |> ignore
    scene.add(spot) |> ignore
    scene.add(
      @core.HemisphereLight::new(
        sky_color=@math.Color::from_hex(0x8888ff),
        ground_color=@math.Color::from_hex(0x442200),
        intensity=0.5,
      ),
    )
    |> ignore
    let phong = @nodes.MeshPhongNodeMaterial::new()
    phong.shininess = Some(50)
    let standard = @nodes.MeshStandardNodeMaterial::new()
    standard.roughness = Some(0.3)
    standard.metalness = Some(0.7)
    let physical = @nodes.MeshPhysicalNodeMaterial::new()
    physical.set_clearcoat(1)
    let mats = [
      @nodes.MeshLambertNodeMaterial::new(),
      phong,
      standard,
      physical,
      @nodes.MeshToonNodeMaterial::new(),
    ]
    for i, m in mats {
      g10_add_box(scene, m, x=i.to_double() - 2) |> ignore
    }
    renderer.render(scene, g10_camera())
    gl
  })
}

///|
test "g10diff shadows" {
  g10_scenario("shadows", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    renderer.shadow_map.enabled = true
    let scene = @core.Scene::new()
    let dir = @core.DirectionalLight::new(
      color=@math.Color::from_hex(0xffffff),
      intensity=2,
    )
    dir.position.set(1, 2, 3) |> ignore
    dir.cast_shadow = true
    g10_shadow(dir).map_size.set(64, 64) |> ignore
    scene.add(dir) |> ignore
    let spot = @core.SpotLight::new(
      color=@math.Color::from_hex(0xffffff),
      intensity=2,
    )
    spot.position.set(0, 3, 0) |> ignore
    spot.cast_shadow = true
    g10_shadow(spot).map_size.set(32, 32) |> ignore
    scene.add(spot) |> ignore
    let caster = g10_add_box(scene, @nodes.MeshStandardNodeMaterial::new())
    caster.cast_shadow = true
    let ground = g10_add_box(scene, @nodes.MeshStandardNodeMaterial::new())
    ground.receive_shadow = true
    ground.position.y = -1
    renderer.render(scene, g10_camera())
    gl
  })
}

///|
test "g10diff shadows_point" {
  g10_scenario("shadows_point", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    renderer.shadow_map.enabled = true
    let scene = @core.Scene::new()
    let point = @core.PointLight::new(
      color=@math.Color::from_hex(0xffffff),
      intensity=2,
      distance=10,
    )
    point.position.set(0, 2, 0) |> ignore
    point.cast_shadow = true
    g10_shadow(point).map_size.set(16, 16) |> ignore
    scene.add(point) |> ignore
    let caster = g10_add_box(scene, @nodes.MeshPhongNodeMaterial::new())
    caster.cast_shadow = true
    caster.receive_shadow = true
    renderer.render(scene, g10_camera())
    gl
  })
}

///|
fn g10_data_texture(
  data : @core.TypedArray,
  format : Int32,
  type_ : Int32,
  width~ : Int32 = 2,
  height~ : Int32 = 2,
) -> @core.Texture {
  let t = @core.DataTexture::new(data~, width~, height~, format~, type_~)
  t
}

///|
fn g10_basic_map(map : @core.Texture) -> @core.Material {
  let m = @nodes.MeshBasicNodeMaterial::new()
  m.map = Some(map)
  m
}

///|
fn g10_basic_color_node(node : @nodes.Node) -> @core.Material {
  let m = @nodes.MeshBasicNodeMaterial::new()
  @nodes.NodeMaterial::of(m).unwrap().color_node = Some(node)
  m
}

///|
test "g10diff textures_formats" {
  g10_scenario("textures_formats", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    let scene = @core.Scene::new()
    let t0 = g10_data_texture(
      @core.TypedArray::uint8(16),
      @core.RGBAFormat,
      @core.UnsignedByteType,
    )
    t0.color_space = @core.SRGBColorSpace
    t0.flip_y = true
    t0.anisotropy = 4
    t0.wrap_s = @core.RepeatWrapping
    t0.wrap_t = @core.MirroredRepeatWrapping
    t0.min_filter = @core.LinearMipmapLinearFilter
    t0.mag_filter = @core.LinearFilter
    t0.generate_mipmaps = true
    let t1 = g10_data_texture(
      @core.TypedArray::float32(16),
      @core.RGBAFormat,
      @core.FloatType,
    )
    t1.mag_filter = @core.NearestFilter
    let t2 = g10_data_texture(
      @core.TypedArray::uint16(8),
      @core.RGFormat,
      @core.HalfFloatType,
    )
    let t3 = g10_data_texture(
      @core.TypedArray::uint8(4),
      @core.RedFormat,
      @core.UnsignedByteType,
    )
    t3.generate_mipmaps = true
    t3.min_filter = @core.LinearMipmapLinearFilter
    t3.mag_filter = @core.LinearFilter
    let t4 = g10_data_texture(
      @core.TypedArray::uint32(4),
      @core.RedIntegerFormat,
      @core.UnsignedIntType,
    )
    let t5 = g10_data_texture(
      @core.TypedArray::uint8(16),
      @core.RGBAFormat,
      @core.UnsignedByteType,
    )
    t5.premultiply_alpha = true
    t5.unpack_alignment = 1
    let textures = [t0, t1, t2, t3, t4, t5]
    for i, t in textures {
      t.set_needs_update(true)
      let m = if i == 4 {
        g10_basic_color_node(
          @nodes.vec4(@nodes.texture_load(t, uv_node=@nodes.ivec2_of([0, 0]))),
        )
      } else {
        g10_basic_map(t)
      }
      g10_add_box(scene, m, x=i.to_double()) |> ignore
    }
    renderer.render(scene, g10_camera())
    t0.set_needs_update(true)
    renderer.render(scene, g10_camera())
    gl
  })
}

///|
test "g10diff textures_kinds" {
  g10_scenario("textures_kinds", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    let scene = @core.Scene::new()
    let face = fn() -> @core.TextureImage {
      DataImage(
        @core.DataImage::new(
          data=@core.TypedArray::uint8(16),
          width=2,
          height=2,
        ),
      )
    }
    let cube = @core.CubeTexture::new(images=[
      face(),
      face(),
      face(),
      face(),
      face(),
      face(),
    ])
    cube.set_needs_update(true)
    let tex3d = @core.Data3DTexture::new(
      data=@core.TypedArray::uint8(2 * 2 * 2 * 4),
      width=2,
      height=2,
      depth=2,
    )
    tex3d.set_needs_update(true)
    let array = @core.DataArrayTexture::new(
      data=@core.TypedArray::uint8(2 * 2 * 3 * 4),
      width=2,
      height=2,
      depth=3,
    )
    array.set_needs_update(true)
    let compressed = @core.CompressedTexture::new(
      mipmaps=[
        DataImage(
          @core.DataImage::new(
            data=@core.TypedArray::uint8(8),
            width=4,
            height=4,
          ),
        ),
        DataImage(
          @core.DataImage::new(
            data=@core.TypedArray::uint8(8),
            width=2,
            height=2,
          ),
        ),
      ],
      width=4,
      height=4,
      format=@core.RGBA_S3TC_DXT1_Format,
    )
    compressed.set_needs_update(true)
    let mats = [
      g10_basic_color_node(
        @nodes.cube_texture(cube, uv_node=@nodes.normal_view),
      ),
      g10_basic_color_node(@nodes.texture3d(tex3d, uv_node=@nodes.vec3(0.5))),
      g10_basic_color_node(@nodes.texture(array, uv_node=@nodes.uv()).depth(1)),
      g10_basic_map(compressed),
    ]
    for i, m in mats {
      g10_add_box(scene, m, x=i.to_double()) |> ignore
    }
    renderer.render(scene, g10_camera())
    gl
  })
}

///|
test "g10diff render_targets" {
  g10_scenario("render_targets", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    let scene = @core.Scene::new()
    g10_add_box(scene, g10_basic(0x336699)) |> ignore
    let rt = @core.RenderTarget::new(width=8, height=8, depth_buffer=true)
    rt.set_depth_texture(Some(@core.DepthTexture::new(width=8, height=8)))
    renderer.set_render_target(Some(rt))
    renderer.render(scene, g10_camera())
    renderer.set_render_target(None)
    let quad = @core.Scene::new()
    g10_add_box(quad, g10_basic_map(rt.textures[0])) |> ignore
    renderer.render(quad, g10_camera())
    let msaa = @core.RenderTarget::new(width=8, height=8, samples=4)
    renderer.set_render_target(Some(msaa))
    renderer.render(scene, g10_camera())
    renderer.set_render_target(None)
    renderer.read_render_target_pixels_async(rt, 0, 0, 2, 2, fn(pixels) {
      g10_note(gl, "pixels", g10_array_from(pixels.unwrap()))
    })
    gl
  })
}

///|
extern "js" fn g10_array_from(a : @core.TypedArray) -> @core.JsValue = "(a) => Array.from( a )"

///|
test "g10diff render_targets_mrt" {
  g10_scenario("render_targets_mrt", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    let scene = @core.Scene::new()
    g10_add_box(scene, @nodes.MeshStandardNodeMaterial::new()) |> ignore
    scene.add(
      @core.DirectionalLight::new(
        color=@math.Color::from_hex(0xffffff),
        intensity=1,
      ),
    )
    |> ignore
    let rt = @core.RenderTarget::new(width=8, height=8, count=2)
    rt.textures[0].name = "output"
    rt.textures[1].name = "normal"
    renderer.set_mrt(
      Some(
        @nodes.mrt({
          "output": @nodes.output,
          "normal": @nodes.vec4_of([@nodes.normal_view, 1]),
        }),
      ),
    )
    |> ignore
    renderer.set_render_target(Some(rt))
    renderer.render(scene, g10_camera())
    let msaa = @core.RenderTarget::new(width=8, height=8, count=2, samples=4)
    msaa.textures[0].name = "output"
    msaa.textures[1].name = "normal"
    renderer.set_render_target(Some(msaa))
    renderer.render(scene, g10_camera())
    renderer.set_render_target(None)
    renderer.set_mrt(None) |> ignore
    gl
  })
}

///|
test "g10diff copies" {
  g10_scenario("copies", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    let scene = @core.Scene::new()
    g10_add_box(scene, @nodes.MeshBasicNodeMaterial::new()) |> ignore
    renderer.render(scene, g10_camera())
    let fb_texture = @core.FramebufferTexture::new(width=16, height=16)
    renderer.copy_framebuffer_to_texture_at(
      fb_texture,
      @math.Vector2::new(4, 4),
    )
    let src = @core.DataTexture::new(
      data=@core.TypedArray::uint8(4 * 4 * 4),
      width=4,
      height=4,
    )
    src.set_needs_update(true)
    let dst = @core.DataTexture::new(
      data=@core.TypedArray::uint8(8 * 8 * 4),
      width=8,
      height=8,
    )
    dst.set_needs_update(true)
    renderer.init_texture(src)
    renderer.init_texture(dst)
    renderer.copy_texture_to_texture(
      src,
      dst,
      dst_position=Vec2(@math.Vector2::new(2, 2)),
    )
    renderer.copy_texture_to_texture(
      src,
      dst,
      src_region=Box2(
        @math.Box2::new(
          min=@math.Vector2::new(1, 1),
          max=@math.Vector2::new(3, 3),
        ),
      ),
      dst_position=Vec2(@math.Vector2::new(0, 0)),
    )
    gl
  })
}

///|
test "g10diff geometry_kinds" {
  g10_scenario("geometry_kinds", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    let scene = @core.Scene::new()
    let inst = @core.InstancedMesh::new(
      geometry=@geometries.BoxGeometry::new(),
      material=Single(@nodes.MeshBasicNodeMaterial::new()),
      3,
    )
    for i in 0..<3 {
      inst.set_matrix_at(
        i,
        @math.Matrix4::new().make_translation(i.to_double(), 0, 0),
      )
      |> ignore
    }
    scene.add(inst) |> ignore
    let non_indexed = @geometries.BoxGeometry::new().to_non_indexed()
    non_indexed.set_draw_range(3, 12)
    scene.add(
      @core.Mesh::new(
        geometry=non_indexed,
        material=Single(@nodes.MeshBasicNodeMaterial::new()),
      ),
    )
    |> ignore
    let interleaved_geometry = @core.BufferGeometry::new()
    let ib = @core.InterleavedBuffer::new(
      @core.TypedArray::float32([
        0.0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 1,
      ]),
      6,
    )
    interleaved_geometry.set_attribute(
      "position",
      @core.GeometryAttribute::Interleaved(
        @core.InterleavedBufferAttribute::new(ib, 3, 0),
      ),
    )
    |> ignore
    interleaved_geometry.set_attribute(
      "normal",
      @core.GeometryAttribute::Interleaved(
        @core.InterleavedBufferAttribute::new(ib, 3, 3),
      ),
    )
    |> ignore
    scene.add(
      @core.Mesh::new(
        geometry=interleaved_geometry,
        material=Single(@nodes.MeshNormalNodeMaterial::new()),
      ),
    )
    |> ignore
    scene.add(
      @core.Mesh::new(
        geometry=@geometries.BoxGeometry::new(),
        material=Multiple([g10_basic(0xff0000), g10_basic(0x00ff00)]),
      ),
    )
    |> ignore
    renderer.render(scene, g10_camera())
    gl
  })
}

///|
extern "js" fn g10_concat_logs(
  a : @webgl.WebGL2RenderingContext,
  b : @webgl.WebGL2RenderingContext,
) -> Unit = "(a, b) => { a.__log.push( ...b.__log ); }"

///|
test "g10diff batched_mesh" {
  g10_scenario("batched_mesh", fn() {
    let out = g10_mock_gl()
    out.get_error() |> ignore
    g10_ffi_clear(out)
    for mock in ["{}", "{\"extensions\":[\"EXT_color_buffer_float\"]}"] {
      let { renderer, gl, .. } = g10_make_renderer(mock~)
      let scene = @core.Scene::new()
      let batched = @core.BatchedMesh::new(
        4,
        200,
        max_index_count=400,
        material=Single(@nodes.MeshBasicNodeMaterial::new()),
      )
      let g0 = batched.add_geometry(@geometries.BoxGeometry::new())
      let g1 = batched.add_geometry(@geometries.PlaneGeometry::new())
      let i0 = batched.add_instance(g0)
      let i1 = batched.add_instance(g1)
      batched.add_instance(g0) |> ignore
      batched.set_matrix_at(i1, @math.Matrix4::new().make_translation(2, 0, 0))
      |> ignore
      batched.set_color_at(i0, @math.Color::new(1, 0, 0)) |> ignore
      scene.add(batched) |> ignore
      renderer.render(scene, g10_camera())
      g10_concat_logs(out, gl)
    }
    out
  })
}

///|
extern "js" fn g10_ffi_clear(gl : @webgl.WebGL2RenderingContext) -> Unit = "(gl) => gl.__clear()"

///|
extern "js" fn g10_float32_array_from(buffer : @core.JsValue) -> @core.JsValue = "(b) => Array.from( new Float32Array( b ) )"

///|
test "g10diff compute_transform_feedback" {
  g10_scenario("compute_transform_feedback", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    let a = @nodes.StorageBufferAttribute::from_array(
      @core.TypedArray::float32(8),
      1,
    )
    let b = @nodes.StorageBufferAttribute::from_array(
      @core.TypedArray::float32(8 * 4),
      4,
    )
    let k = @nodes.uniform(2)
    let a_node = @nodes.storage(a, type_="float", count=8)
    let b_node = @nodes.storage(b, type_="vec4", count=8)
    let kernel = g10_fn_unit(fn() {
      a_node
      .element(@nodes.instance_index)
      .assign(@nodes.float(@nodes.instance_index).mul(k))
      b_node
      .element(@nodes.instance_index)
      .assign(@nodes.vec4(a_node.element(@nodes.instance_index)))
    }).compute(8)
    renderer.compute(kernel)
    @nodes.InputNode::set_value(k, Number(3))
    renderer.compute(kernel)
    renderer.get_array_buffer_async(Buffer(a), fn(buffer) {
      g10_note(gl, "readback", g10_float32_array_from(buffer))
    })
    gl
  })
}

///|
test "g10diff compute_then_render" {
  g10_scenario("compute_then_render", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    let offsets = @nodes.StorageInstancedBufferAttribute::from_array(
      @core.TypedArray::float32(3 * 3),
      3,
    )
    let offset_node = @nodes.storage(offsets, type_="vec3", count=3)
    let kernel = g10_fn_unit(fn() {
      offset_node
      .element(@nodes.instance_index)
      .assign(@nodes.vec3_of([@nodes.float(@nodes.instance_index), 0, 0]))
    }).compute(3)
    renderer.compute(kernel)
    let scene = @core.Scene::new()
    let material = @nodes.MeshBasicNodeMaterial::new()
    @nodes.NodeMaterial::of(material).unwrap().position_node = Some(
      @nodes.position_local.add(offset_node.to_attribute()),
    )
    let mesh = @core.InstancedMesh::new(
      geometry=@geometries.BoxGeometry::new(),
      material=Single(material),
      3,
    )
    scene.add(mesh) |> ignore
    renderer.render(scene, g10_camera())
    gl
  })
}

///|
test "g10diff queries" {
  g10_scenario("queries", fn() {
    let { renderer, gl, .. } = g10_make_renderer(
      parameters=g10_params([("trackTimestamp", @core.JsValue::of(true))]),
      mock="{\"extensions\":[\"EXT_color_buffer_float\",\"WEBGL_multi_draw\",\"EXT_disjoint_timer_query_webgl2\",\"KHR_parallel_shader_compile\"],\"queries\":{\"available\":true,\"result\":0}}",
    )
    let scene = @core.Scene::new()
    let a = g10_add_box(scene, @nodes.MeshBasicNodeMaterial::new())
    @nodes.set_occlusion_test(a, true)
    let b = g10_add_box(scene, @nodes.MeshBasicNodeMaterial::new(), x=1)
    @nodes.set_occlusion_test(b, true)
    renderer.render(scene, g10_camera())
    g10_note(gl, "occluded", g10_occluded(renderer, a))
    renderer.render(scene, g10_camera())
    g10_note(gl, "occluded", g10_occluded(renderer, a))
    g10_note(
      gl,
      "hasTimestamp",
      @core.JsValue::of(renderer.backend.has_timestamp()),
    )
    renderer.resolve_timestamps_async(type_="render", fn(t) {
      g10_note(
        gl,
        "timestamp",
        match t {
          Some(t) => @core.JsValue::of(t)
          None => @core.JsValue::undefined()
        },
      )
    })
    gl
  })
}

///|
/// `renderer.isOccluded( object )` as upstream notes it: `renderContext && ...` is
/// `null` outside a render.
fn g10_occluded(
  renderer : @nodes.Renderer,
  object : @core.Object3D,
) -> @core.JsValue {
  if renderer._current_render_context is None {
    @core.JsValue::null()
  } else {
    @core.JsValue::of(renderer.is_occluded(object))
  }
}

///|
fn g10_cube_texture() -> @core.Texture {
  let face = fn() -> @core.TextureImage {
    DataImage(
      @core.DataImage::new(data=@core.TypedArray::uint8(16), width=2, height=2),
    )
  }
  let cube = @core.CubeTexture::new(images=[
    face(),
    face(),
    face(),
    face(),
    face(),
    face(),
  ])
  cube.set_needs_update(true)
  cube
}

///|
test "g10diff background_environment" {
  g10_scenario("background_environment", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    let scene = @core.Scene::new()
    let data = scene.as_scene()
    data.background = Some(Color(@math.Color::from_hex(0x112233)))
    g10_add_box(scene, @nodes.MeshStandardNodeMaterial::new()) |> ignore
    renderer.render(scene, g10_camera())
    let env = @core.DataTexture::new(
      data=@core.TypedArray::uint8(16),
      width=2,
      height=2,
    )
    env.mapping = @core.EquirectangularReflectionMapping
    env.set_needs_update(true)
    data.environment = Some(env)
    renderer.render(scene, g10_camera())
    gl
  })
}

///|
/// A known foundation difference: see scenarios.mjs.
test "g10diff background_cube" {
  g10_scenario("background_cube", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    let scene = @core.Scene::new()
    scene.as_scene().background = Some(Texture(g10_cube_texture()))
    g10_add_box(scene, @nodes.MeshBasicNodeMaterial::new()) |> ignore
    renderer.render(scene, g10_camera())
    gl
  })
}

///|
test "g10diff fog_tone_mapping" {
  g10_scenario("fog_tone_mapping", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    renderer.tone_mapping = @core.ACESFilmicToneMapping
    renderer.tone_mapping_exposure = 1.5
    let scene = @core.Scene::new()
    let data = scene.as_scene()
    data.fog = Some(
      Fog(@core.Fog::new(color=@math.Color::from_hex(0x888888), near=1, far=10)),
    )
    g10_add_box(scene, @nodes.MeshStandardNodeMaterial::new()) |> ignore
    scene.add(
      @core.DirectionalLight::new(
        color=@math.Color::from_hex(0xffffff),
        intensity=1,
      ),
    )
    |> ignore
    renderer.render(scene, g10_camera())
    data.fog = Some(
      FogExp2(
        @core.FogExp2::new(color=@math.Color::from_hex(0x888888), density=0.1),
      ),
    )
    renderer.tone_mapping = @core.AgXToneMapping
    renderer.output_color_space = @core.LinearSRGBColorSpace
    renderer.render(scene, g10_camera())
    gl
  })
}

///|
test "g10diff post_processing" {
  g10_scenario("post_processing", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    let scene = @core.Scene::new()
    g10_add_box(scene, g10_basic(0x00ff00)) |> ignore
    let cam = g10_camera()
    let pipeline = @nodes.RenderPipeline::new(renderer)
    let scene_pass = @nodes.pass(scene, cam)
    pipeline.output_node = scene_pass.get_texture_node().mul(0.5)
    pipeline.render()
    pipeline.render()
    gl
  })
}

///|
test "g10diff clear_resize_dispose" {
  g10_scenario("clear_resize_dispose", fn() {
    let { renderer, gl, .. } = g10_make_renderer(
      parameters=g10_params([("stencil", @core.JsValue::of(true))]),
      stencil=true,
    )
    renderer.set_clear_color_hex(0x334455, alpha=0.5)
    renderer.clear()
    renderer.clear(color=true, depth=false, stencil=true)
    renderer.set_clear_depth(0.5)
    renderer.set_clear_stencil(3)
    renderer.clear_depth()
    renderer.clear_stencil()
    let rt = @core.RenderTarget::new(width=4, height=4, stencil_buffer=true)
    renderer.set_render_target(Some(rt))
    renderer.clear()
    renderer.set_render_target(None)
    renderer.set_pixel_ratio(2)
    renderer.set_size(100, 50, update_style=false)
    renderer.set_viewport(10, 10, 50, 20)
    renderer.set_scissor(5, 5, 20, 10)
    renderer.set_scissor_test(true)
    let scene = @core.Scene::new()
    g10_add_box(scene, @nodes.MeshBasicNodeMaterial::new()) |> ignore
    renderer.render(scene, g10_camera())
    renderer.set_scissor_test(false)
    rt.dispose()
    renderer.dispose(on_done=fn() {
      g10_note(gl, "disposed", @core.JsValue::of(true))
    })
    gl
  })
}

///|
test "g10diff cube_render_target" {
  g10_scenario("cube_render_target", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    let scene = @core.Scene::new()
    g10_add_box(scene, @nodes.MeshBasicNodeMaterial::new()) |> ignore
    let crt = @nodes.CubeRenderTarget::new(size=8)
    let cube_camera = @core.CubeCamera::new(near=0.1, far=10, render_target=crt)
    cube_camera.update_cube_camera(renderer, scene)
    let array = @core.RenderTarget::new(width=4, height=4, depth=2)
    array.textures[0].is_array_texture = true
    renderer.set_render_target(Some(array), active_cube_face=1)
    renderer.render(scene, g10_camera())
    renderer.set_render_target(None)
    gl
  })
}

///|
/// A known difference outside this package: see scenarios.mjs.
test "g10diff environment_cube" {
  g10_scenario("environment_cube", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    let scene = @core.Scene::new()
    scene.as_scene().environment = Some(g10_cube_texture())
    g10_add_box(scene, @nodes.MeshStandardNodeMaterial::new()) |> ignore
    renderer.render(scene, g10_camera())
    gl
  })
}

///|
test "g10diff compute_pbo_render" {
  g10_scenario("compute_pbo_render", fn() {
    let { renderer, gl, .. } = g10_make_renderer()
    let data = @nodes.StorageBufferAttribute::from_array(
      @core.TypedArray::float32(6),
      1,
    )
    let write_node = @nodes.storage(data, type_="float", count=6)
    let read_node = @nodes.storage(data, type_="float", count=6).set_pbo(true)
    let scene = @core.Scene::new()
    g10_add_box(
      scene,
      g10_basic_color_node(@nodes.vec4(read_node.element(@nodes.int(2)))),
    )
    |> ignore
    renderer.render(scene, g10_camera())
    let kernel = g10_fn_unit(fn() {
      write_node
      .element(@nodes.instance_index)
      .assign(@nodes.float(@nodes.instance_index).add(1))
    }).compute(6)
    renderer.compute(kernel)
    renderer.render(scene, g10_camera())
    gl
  })
}

///|
test "g10diff compile_async_parallel" {
  g10_scenario_async("compile_async_parallel", fn(done) {
    let { renderer, gl, .. } = g10_make_renderer()
    let scene = @core.Scene::new()
    g10_add_box(scene, @nodes.MeshPhongNodeMaterial::new()) |> ignore
    scene.add(
      @core.PointLight::new(color=@math.Color::from_hex(0xffffff), intensity=1),
    )
    |> ignore
    renderer.compile_async(scene, g10_camera(), on_done=fn() {
      g10_note(gl, "compiled", @core.JsValue::of(true))
      renderer.render(scene, g10_camera())
      done(gl)
    })
  })
}

///|
test "g10diff user_context" {
  g10_scenario("user_context", fn() {
    let gl = g10_mock_gl()
    g10_install_frames(gl)
    let canvas = g10_make_canvas(gl, 300, 150)
    let parameters = g10_params([
      ("canvas", canvas),
      ("context", @core.JsValue::of(gl)),
      ("forceWebGL", @core.JsValue::of(true)),
    ])
    let renderer = @nodes.Renderer::new(
      @webgl_fallback.WebGLBackend::new(parameters~),
    )
    renderer.library = g10_standard_node_library()
    renderer.init()
    let scene = @core.Scene::new()
    g10_add_box(scene, @nodes.MeshBasicNodeMaterial::new()) |> ignore
    renderer.render(scene, g10_camera())
    renderer.dispose()
    gl
  })
}
