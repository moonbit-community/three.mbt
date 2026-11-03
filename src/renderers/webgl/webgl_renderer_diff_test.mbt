// Group 4 differential scenarios: WebGLRenderer driven through the recording mock, each
// mirroring harness/scenarios/renderer_<name>.mjs in the diff/core/webgl harness step by
// step. The mock canvas and the program spec come from harness/scenarios/renderer_common.cjs,
// embedded below verbatim (`node renderer_common.cjs --print-moonbit`).

///|
extern "js" fn ffi_renderer_common() -> @core.JsValue =
  #|() =>
  #|(function () {
  #|  // A canvas stand-in that records what the renderer does to it into gl.__log.
  #|  function createMockCanvas(gl, width, height) {
  #|    let w = width;
  #|    let h = height;
  #|    const listeners = {};
  #|    const style = {};
  #|    const canvas = { style };
  #|    Object.defineProperty(canvas, 'width', { get() { return w; }, set(v) { w = v; gl.__log.push('canvas.width = ' + JSON.stringify(v)); } });
  #|    Object.defineProperty(canvas, 'height', { get() { return h; }, set(v) { h = v; gl.__log.push('canvas.height = ' + JSON.stringify(v)); } });
  #|    Object.defineProperty(style, 'width', { set(v) { gl.__log.push('canvas.style.width = ' + JSON.stringify(v)); } });
  #|    Object.defineProperty(style, 'height', { set(v) { gl.__log.push('canvas.style.height = ' + JSON.stringify(v)); } });
  #|    canvas.setAttribute = function (n, v) { gl.__log.push('canvas.setAttribute(' + JSON.stringify(n) + ', ' + JSON.stringify(v) + ')'); };
  #|    canvas.addEventListener = function (t, l) { (listeners[t] = listeners[t] || []).push(l); gl.__log.push('canvas.addEventListener(' + JSON.stringify(t) + ')'); };
  #|    canvas.removeEventListener = function (t, l) { const a = listeners[t] || []; const i = a.indexOf(l); if (i !== -1) a.splice(i, 1); gl.__log.push('canvas.removeEventListener(' + JSON.stringify(t) + ', ' + (i !== -1) + ')'); };
  #|    canvas.getContext = function () { gl.__log.push('canvas.getContext()'); return gl; };
  #|    // fires the listeners of `type` with a minimal event
  #|    canvas.__dispatch = function (type) {
  #|      const event = { type, statusMessage: 'mock', preventDefault() { gl.__log.push('event.preventDefault()'); } };
  #|      for (const l of (listeners[type] || []).slice()) l(event);
  #|    };
  #|    canvas.__listenerCount = function (type) { return (listeners[type] || []).length; };
  #|    return canvas;
  #|  }
  #|
  #|  // One active-uniform / attribute spec for every program the mock links, so uploads show
  #|  // up in the log. Types: FLOAT 0x1406, VEC2 0x8B50, VEC3 0x8B51, VEC4 0x8B52, MAT3 0x8B5B,
  #|  // MAT4 0x8B5C, BOOL 0x8B56, SAMPLER_2D 0x8B5E, SAMPLER_CUBE 0x8B60, SAMPLER_2D_SHADOW 0x8B62.
  #|  const PROGRAM_SPEC = {
  #|    attributes: [
  #|      { name: 'position', type: 0x8B51 }, { name: 'normal', type: 0x8B51 }, { name: 'uv', type: 0x8B50 },
  #|      { name: 'color', type: 0x8B51 }, { name: 'instanceMatrix', type: 0x8B5C },
  #|      { name: 'skinIndex', type: 0x8B52 }, { name: 'skinWeight', type: 0x8B52 },
  #|    ],
  #|    uniforms: [
  #|      { name: 'modelMatrix', type: 0x8B5C }, { name: 'modelViewMatrix', type: 0x8B5C },
  #|      { name: 'projectionMatrix', type: 0x8B5C }, { name: 'viewMatrix', type: 0x8B5C },
  #|      { name: 'normalMatrix', type: 0x8B5B }, { name: 'cameraPosition', type: 0x8B51 },
  #|      { name: 'isOrthographic', type: 0x8B56 }, { name: 'toneMappingExposure', type: 0x1406 },
  #|      { name: 'receiveShadow', type: 0x8B56 }, { name: 'diffuse', type: 0x8B51 },
  #|      { name: 'opacity', type: 0x1406 }, { name: 'map', type: 0x8B5E }, { name: 'mapTransform', type: 0x8B5B },
  #|      { name: 'emissive', type: 0x8B51 }, { name: 'specular', type: 0x8B51 }, { name: 'shininess', type: 0x1406 },
  #|      { name: 'roughness', type: 0x1406 }, { name: 'metalness', type: 0x1406 },
  #|      { name: 'ambientLightColor', type: 0x8B51 },
  #|      { name: 'directionalLights[0].direction', type: 0x8B51 }, { name: 'directionalLights[0].color', type: 0x8B51 },
  #|      { name: 'pointLights[0].position', type: 0x8B51 }, { name: 'pointLights[0].color', type: 0x8B51 },
  #|      { name: 'pointLights[0].distance', type: 0x1406 }, { name: 'pointLights[0].decay', type: 0x1406 },
  #|      { name: 'spotLights[0].position', type: 0x8B51 }, { name: 'spotLights[0].direction', type: 0x8B51 },
  #|      { name: 'spotLights[0].color', type: 0x8B51 }, { name: 'spotLights[0].coneCos', type: 0x1406 },
  #|      { name: 'hemisphereLights[0].direction', type: 0x8B51 }, { name: 'hemisphereLights[0].skyColor', type: 0x8B51 },
  #|      { name: 'hemisphereLights[0].groundColor', type: 0x8B51 },
  #|      { name: 'directionalShadowMap[0]', type: 0x8B62 }, { name: 'directionalShadowMatrix[0]', type: 0x8B5C },
  #|      { name: 'directionalLightShadows[0].shadowBias', type: 0x1406 },
  #|      { name: 'fogColor', type: 0x8B51 }, { name: 'fogNear', type: 0x1406 }, { name: 'fogFar', type: 0x1406 },
  #|      { name: 'size', type: 0x1406 }, { name: 'scale', type: 0x1406 }, { name: 'center', type: 0x8B50 },
  #|      { name: 'rotation', type: 0x1406 }, { name: 'boneTexture', type: 0x8B5E },
  #|      { name: 'bindMatrix', type: 0x8B5C }, { name: 'bindMatrixInverse', type: 0x8B5C },
  #|      { name: 'morphTargetBaseInfluence', type: 0x1406 }, { name: 'morphTargetsTexture', type: 0x8B5E },
  #|      { name: 'tEquirect', type: 0x8B5E }, { name: 'transmission', type: 0x1406 },
  #|      { name: 'transmissionSamplerMap', type: 0x8B5E },
  #|    ],
  #|  };
  #|  // `drop`: uniform name prefixes to leave out, for scenes without those lights (a real
  #|  // shader declares only the light structs the scene has).
  #|  function mockOptions(extra, drop) {
  #|    const spec = { attributes: PROGRAM_SPEC.attributes, uniforms: PROGRAM_SPEC.uniforms.filter((u) => !(drop || []).some((d) => u.name.startsWith(d))) };
  #|    const programs = [];
  #|    for (let i = 0; i < 64; i++) programs.push(spec);
  #|    return JSON.stringify(Object.assign({ programs, canvas: { width: 64, height: 32 } }, extra || {}));
  #|  }
  #|  return { createMockCanvas, mockOptions };
  #|})()

///|
let renderer_common : @core.JsValue = ffi_renderer_common()

///|
extern "js" fn ffi_renderer_mock_options(
  common : @core.JsValue,
  extra : String,
  drop : String,
) -> String = "(c, e, d) => c.mockOptions(JSON.parse(e), JSON.parse(d))"

///|
/// The mock options of the renderer scenarios: one program spec per link, a 64x32 canvas.
/// `drop` lists uniform name prefixes to leave out of the spec.
fn renderer_mock_options(extra : String, drop~ : Array[String] = []) -> String {
  ffi_renderer_mock_options(renderer_common, extra, Json(drop).stringify())
}

///|
extern "js" fn ffi_renderer_mock_canvas(
  common : @core.JsValue,
  gl : @webgl.WebGL2RenderingContext,
  width : Int32,
  height : Int32,
) -> @webgl.HTMLCanvasElement = "(c, gl, w, h) => c.createMockCanvas(gl, w, h)"

///|
fn renderer_mock_canvas(
  gl : @webgl.WebGL2RenderingContext,
  width : Int32,
  height : Int32,
) -> @webgl.HTMLCanvasElement {
  ffi_renderer_mock_canvas(renderer_common, gl, width, height)
}

///|
/// `canvas.__dispatch( type )`: fires the canvas listeners.
extern "js" fn renderer_canvas_dispatch(
  canvas : @webgl.HTMLCanvasElement,
  type_ : String,
) -> Unit = "(c, t) => c.__dispatch(t)"

///|
extern "js" fn renderer_canvas_listener_count(
  canvas : @webgl.HTMLCanvasElement,
  type_ : String,
) -> Int32 = "(c, t) => c.__listenerCount(t)"

///|
/// `gl[ key ]`.
extern "js" fn renderer_gl_property(
  gl : @webgl.WebGL2RenderingContext,
  key : String,
) -> @core.JsValue = "(gl, k) => gl[k]"

///|
/// `new WebGLRenderer( { canvas, context: gl, ... } )`.
fn renderer_new(
  gl : @webgl.WebGL2RenderingContext,
  canvas : @webgl.HTMLCanvasElement,
  stencil~ : Bool = false,
  antialias~ : Bool = false,
  output_buffer_type~ : Int32 = @core.UnsignedByteType,
) -> @webgl.WebGLRenderer {
  @webgl.WebGLRenderer::new(
    canvas~,
    context=gl,
    stencil~,
    antialias~,
    output_buffer_type~,
  )
}

///|
fn note_json(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  value : Json,
) -> Unit {
  mock_note(gl, label, @core.JsValue::from_json(value))
}

///|
fn v2_json(v : @math.Vector2) -> Json {
  Json([v.x, v.y])
}

///|
fn v4_json(v : @math.Vector4) -> Json {
  Json([v.x, v.y, v.z, v.w])
}

///|
test "diff renderer_basics" {
  let gl = mock_gl(options=renderer_mock_options("{}"))
  let canvas = renderer_mock_canvas(gl, 64, 32)
  let renderer = renderer_new(gl, canvas, stencil=true)
  let v2 = @math.Vector2::new(0.0, 0.0)
  let v4 = @math.Vector4::new(0.0, 0.0, 0.0, 1.0)
  let c = @math.Color::new(0.0, 0.0, 0.0)
  note_json(gl, "size", v2_json(renderer.get_size(v2)))
  note_num(gl, "pixelRatio", renderer.get_pixel_ratio())
  renderer.set_pixel_ratio(2.0)
  renderer.set_size(40.0, 20.5)
  note_json(gl, "size", v2_json(renderer.get_size(v2)))
  note_json(
    gl,
    "drawingBufferSize",
    v2_json(renderer.get_drawing_buffer_size(v2)),
  )
  note_json(gl, "viewport", v4_json(renderer.get_viewport(v4)))
  note_json(gl, "currentViewport", v4_json(renderer.get_current_viewport(v4)))
  renderer.set_viewport(1.0, 2.0, 30.3, 10.0)
  renderer.set_viewport_vector(@math.Vector4::new(0.0, 0.0, 40.0, 20.0))
  renderer.set_scissor(2.0, 3.0, 4.0, 5.0)
  renderer.set_scissor_vector(@math.Vector4::new(1.0, 1.0, 7.0, 9.0))
  note_json(gl, "scissor", v4_json(renderer.get_scissor(v4)))
  renderer.set_scissor_test(true)
  note_bool(gl, "scissorTest", renderer.get_scissor_test())
  renderer.set_scissor_test(false)
  renderer.set_drawing_buffer_size(30.0, 10.0, 1.5)
  note_num(gl, "pixelRatio", renderer.get_pixel_ratio())
  renderer.set_size(64.0, 32.0, update_style=false)
  renderer.set_pixel_ratio(1.0)
  renderer.set_size(64.0, 32.0)
  // clearing
  let cc = renderer.get_clear_color(c)
  note_json(gl, "clearColor", Json([cc.r, cc.g, cc.b]))
  note_num(gl, "clearAlpha", renderer.get_clear_alpha())
  renderer.set_clear_color_hex(0x336699, alpha=0.5)
  note_int(gl, "clearColor", renderer.get_clear_color(c).get_hex())
  renderer.set_clear_color(@math.Color::new(1.0, 0.0, 0.0))
  renderer.set_clear_alpha(0.25)
  note_num(gl, "clearAlpha", renderer.get_clear_alpha())
  renderer.clear()
  renderer.clear_color()
  renderer.clear_depth()
  renderer.clear_stencil()
  renderer.clear(color=false, depth=false, stencil=false)
  renderer.auto_clear = false
  // render targets
  let rt = @core.RenderTarget::new(width=16, height=8)
  let target = @webgl.WebGLRenderTarget::new(
    width=16,
    height=8,
    depth_buffer=true,
  )
  renderer.set_render_target(Some(target))
  note_bool(
    gl,
    "renderTarget is target",
    renderer.get_render_target() is Some(t) && physical_equal(t, target),
  )
  note_json(gl, "currentViewport", v4_json(renderer.get_current_viewport(v4)))
  renderer.clear()
  renderer.set_render_target(
    Some(target),
    active_cube_face=0,
    active_mipmap_level=1,
  )
  note_json(gl, "mip", [
    renderer.get_active_cube_face(),
    renderer.get_active_mipmap_level(),
  ])
  renderer.set_render_target(None)
  renderer.init_render_target(target)
  let integer = @webgl.WebGLRenderTarget::new(
    width=4,
    height=4,
    format=@core.RGBAIntegerFormat,
    type_=@core.UnsignedIntType,
  )
  renderer.set_render_target(Some(integer))
  renderer.set_clear_color(@math.Color::new(1.0, 0.5, 0.25), alpha=1.0)
  renderer.clear()
  let signed = @webgl.WebGLRenderTarget::new(
    width=4,
    height=4,
    format=@core.RGIntegerFormat,
    type_=@core.IntType,
  )
  renderer.set_render_target(Some(signed))
  renderer.clear(color=true, depth=false, stencil=false)
  renderer.set_render_target(None)
  note_bool(
    gl,
    "isWebGLRenderTarget plain",
    rt.has_extension_flag("isWebGLRenderTarget"),
  )
  renderer.read_render_target_pixels(
    rt,
    0,
    0,
    1,
    1,
    @core.TypedArray::new(Uint8Array, 4),
  )
  let pixels = @core.TypedArray::new(Uint8Array, 16 * 4)
  renderer.read_render_target_pixels(target, 0, 0, 4, 4, pixels)
  renderer.read_render_target_pixels(target, 14, 0, 4, 4, pixels)
  renderer.set_render_target(Some(target))
  renderer.read_render_target_pixels(target, 1, 1, 2, 2, pixels)
  renderer.set_render_target(None)
  // cube render target
  let cube = @webgl.WebGLCubeRenderTarget::new(size=8)
  @webgl.WebGLCubeRenderTarget::clear(
    cube,
    renderer,
    color=true,
    depth=true,
    stencil=false,
  )
  renderer.set_render_target(Some(cube), active_cube_face=3)
  renderer.set_render_target(None)
  // read with the canvas current: with a cube target current, upstream's restore passes the
  // per-face array to gl.bindFramebuffer, which WebGL rejects (the port aborts there)
  renderer.read_render_target_pixels(
    cube,
    0,
    0,
    2,
    2,
    pixels,
    active_cube_face_index=2,
  )
  // state reset, colour space, context
  renderer.reset_state()
  mock_note(gl, "renderTarget after reset", @core.JsValue::null())
  note_int(gl, "coordinateSystem", renderer.coordinate_system())
  note_str(gl, "outputColorSpace", renderer.output_color_space())
  renderer.set_output_color_space(@core.LinearSRGBColorSpace)
  mock_note(
    gl,
    "drawingBufferColorSpace",
    renderer_gl_property(gl, "drawingBufferColorSpace"),
  )
  mock_note(
    gl,
    "unpackColorSpace",
    renderer_gl_property(gl, "unpackColorSpace"),
  )
  mock_note(
    gl,
    "contextAttributes.alpha",
    renderer.get_context_attributes().get("alpha"),
  )
  note_bool(gl, "getContext", physical_equal(renderer.get_context(), gl))
  // context loss and restore
  renderer.shadow_map.enabled = true
  renderer.shadow_map.type_ = @core.VSMShadowMap
  renderer.info.auto_reset = false
  renderer.force_context_loss()
  renderer_canvas_dispatch(canvas, "webglcontextlost")
  let scene = @core.Scene::new()
  let camera = @core.PerspectiveCamera::new()
  renderer.render(scene, camera)
  renderer.force_context_restore()
  renderer_canvas_dispatch(canvas, "webglcontextrestored")
  note_json(gl, "after restore", [
    Json(renderer.shadow_map.enabled),
    Json(renderer.shadow_map.type_),
    Json(renderer.info.auto_reset),
  ])
  renderer_canvas_dispatch(canvas, "webglcontextcreationerror")
  renderer.render(scene, @core.Object3D::new())
  renderer.dispose()
  note_json(gl, "listeners", [
    renderer_canvas_listener_count(canvas, "webglcontextlost"),
    renderer_canvas_listener_count(canvas, "webglcontextrestored"),
  ])
  let log = emit_log("renderer_basics", gl)
  assert_true(log.length() > 100)
}

///|
/// `material.color.set( hex )`, as `new XMaterial( { color: hex } )` does.
fn renderer_set_color(material : @core.Material, hex : Int32) -> Unit {
  ignore(material.color.unwrap().set_hex(hex))
}

///|
fn renderer_basic(hex? : Int32) -> @core.Material {
  let material = @core.MeshBasicMaterial::new()
  if hex is Some(hex) {
    renderer_set_color(material, hex)
  }
  material
}

///|
fn renderer_is(value : @core.JsValue, renderer : @webgl.WebGLRenderer) -> Bool {
  value.strict_equal(@core.JsValue::of(renderer))
}

///|
test "diff renderer_frame_unlit" {
  let gl = mock_gl(options=renderer_mock_options("{}"))
  let canvas = renderer_mock_canvas(gl, 64, 32)
  let renderer = renderer_new(gl, canvas)
  let scene = @core.Scene::new()
  let camera = @core.PerspectiveCamera::new(
    fov=50.0,
    aspect=2.0,
    near=0.1,
    far=100.0,
  )
  ignore(camera.position.set(0.0, 0.0, 5.0))
  let box_geometry = @geometries.BoxGeometry::new(
    width=1.0,
    height=1.0,
    depth=1.0,
  )
  let box_material = renderer_basic(hex=0xff0000)
  let box = @core.Mesh::new(
    geometry=box_geometry,
    material=Single(box_material),
  )
  ignore(box.position.set(-1.0, 0.0, 0.0))
  ignore(box.rotation.set(0.3, 0.4, 0.0))
  ignore(scene.add(box))
  let data = @core.TypedArray::new(Uint8Array, [
    255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255,
  ])
  let texture = @core.DataTexture::new(data~, width=2, height=2)
  texture.set_needs_update(true)
  let plane_material = @core.MeshBasicMaterial::new()
  plane_material.map = Some(texture)
  let plane = @core.Mesh::new(
    geometry=@geometries.PlaneGeometry::new(width=1.0, height=1.0),
    material=Single(plane_material),
  )
  ignore(plane.position.set(1.0, 0.0, -1.0))
  ignore(scene.add(plane))
  let line_geometry = @core.BufferGeometry::new().set_from_points([
    @math.Vector3::new(0.0, 0.0, 0.0),
    @math.Vector3::new(1.0, 1.0, 0.0),
    @math.Vector3::new(1.0, 0.0, 0.0),
  ])
  let line_material = @core.LineBasicMaterial::new()
  renderer_set_color(line_material, 0x00ff00)
  ignore(
    scene.add(
      @core.Line::new(geometry=line_geometry, material=Single(line_material)),
    ),
  )
  ignore(
    scene.add(
      @core.LineSegments::new(
        geometry=line_geometry,
        material=Single(line_material),
      ),
    ),
  )
  ignore(
    scene.add(
      @core.LineLoop::new(
        geometry=line_geometry,
        material=Single(line_material),
      ),
    ),
  )
  let points_material = @core.PointsMaterial::new()
  points_material.size = Some(3.0)
  points_material.size_attenuation = Some(false)
  let points = @core.Points::new(
    geometry=line_geometry,
    material=Single(points_material),
  )
  ignore(scene.add(points))
  let sprite_material = @core.SpriteMaterial::new()
  renderer_set_color(sprite_material, 0x0000ff)
  let sprite = @core.Sprite::new(material=sprite_material)
  ignore(sprite.position.set(0.0, 1.0, 0.0))
  ignore(scene.add(sprite))
  let group = @core.Group::new()
  group.render_order = 2.0
  let instanced = @core.InstancedMesh::new(
    geometry=@geometries.BoxGeometry::new(width=0.2, height=0.2, depth=0.2),
    material=Single(@core.MeshBasicMaterial::new()),
    3,
  )
  let m = @math.Matrix4::new()
  for i in 0..<3 {
    ignore(
      instanced.set_matrix_at(
        i,
        m.make_translation(i.to_double() * 0.3, -1.0, 0.0),
      ),
    )
    ignore(
      instanced.set_color_at(i, @math.Color::new(i.to_double() / 3.0, 0.5, 1.0)),
    )
  }
  ignore(group.add(instanced))
  ignore(scene.add(group))
  let invisible = renderer_basic(hex=0x333333)
  invisible.visible = false
  let multi = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(width=0.5, height=0.5, depth=0.5),
    material=Multiple([
      renderer_basic(hex=0x111111),
      renderer_basic(hex=0x222222),
      invisible,
    ]),
  )
  ignore(multi.position.set(0.0, -1.0, 1.0))
  ignore(scene.add(multi))
  let wire_material = @core.MeshBasicMaterial::new()
  wire_material.wireframe = Some(true)
  let wire = @core.Mesh::new(
    geometry=@geometries.SphereGeometry::new(
      radius=0.3,
      width_segments=4.0,
      height_segments=3.0,
    ),
    material=Single(wire_material),
  )
  ignore(wire.position.set(0.0, 0.5, 1.0))
  ignore(scene.add(wire))
  let hidden = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(),
    material=Single(@core.MeshBasicMaterial::new()),
  )
  hidden.visible = false
  ignore(scene.add(hidden))
  let layered = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(),
    material=Single(@core.MeshBasicMaterial::new()),
  )
  layered.layers.set(3)
  ignore(scene.add(layered))
  scene.set_scene_on_before_render((r, s, c, target) => {
    note_json(gl, "scene.onBeforeRender", [
      Json(renderer_is(r, renderer)),
      Json(physical_equal(s, scene)),
      Json(physical_equal(c, camera)),
      if target is Some(_) {
        "target"
      } else {
        Json::null()
      },
    ])
  })
  scene.set_scene_on_after_render((r, s, c) => {
    note_json(gl, "scene.onAfterRender", [
      renderer_is(r, renderer),
      physical_equal(s, scene),
      physical_equal(c, camera),
    ])
  })
  box.on_before_render = (_, _, _, g, mat, grp) => {
    note_json(gl, "box.onBeforeRender", [
      Json(physical_equal(g, box_geometry)),
      Json(physical_equal(mat, box_material)),
      if grp is Some(_) {
        "group"
      } else {
        Json::null()
      },
    ])
  }
  box.on_after_render = (_, _, _, _, _, _) => {
    note_int(gl, "box.onAfterRender", 1)
  }
  box_material.on_before_render = (_, _, _, _, o, _) => {
    note_bool(gl, "material.onBeforeRender", physical_equal(o, box))
  }
  let materials = renderer.compile(scene, camera)
  note_int(gl, "compiled", materials.length())
  renderer.render(scene, camera)
  let info = renderer.info
  note_json(gl, "info.render", [
    info.render.frame.to_double(),
    info.render.calls.to_double(),
    info.render.triangles,
    info.render.points,
    info.render.lines,
  ])
  note_json(gl, "info.memory", [info.memory.geometries, info.memory.textures])
  note_int(gl, "programs", info.programs.unwrap().length())
  // second frame: cached programs, moved camera, custom sort, no sorting
  ignore(camera.position.set(0.5, 0.0, 6.0))
  renderer_set_color(box_material, 0x00ffff)
  renderer.set_opaque_sort(Some((a, b) => (b.id - a.id).to_double()))
  renderer.render(scene, camera)
  renderer.sort_objects = false
  renderer.set_opaque_sort(None)
  box_material.set_needs_update(true)
  renderer.render(scene, camera)
  note_json(gl, "info.render", [
    info.render.frame.to_double(),
    info.render.calls.to_double(),
    info.render.triangles,
  ])
  // orthographic camera, scissor, autoClear off, tone mapping variant
  renderer.sort_objects = true
  renderer.auto_clear = false
  renderer.tone_mapping = @core.ACESFilmicToneMapping
  renderer.set_scissor_test(true)
  renderer.set_scissor(0.0, 0.0, 32.0, 16.0)
  let ortho = @core.OrthographicCamera::new(
    left=-2.0,
    right=2.0,
    top=1.0,
    bottom=-1.0,
    near=0.1,
    far=50.0,
  )
  ignore(ortho.position.set(0.0, 0.0, 10.0))
  renderer.render(scene, ortho)
  renderer.set_scissor_test(false)
  // renderBufferDirect without a scene, from inside a frame (it needs the render state)
  sprite.on_before_render = (_, _, c, _, _, _) => {
    sprite.on_before_render = (_, _, _, _, _, _) => ()
    renderer.render_buffer_direct(
      c,
      None,
      box_geometry,
      box_material,
      box,
      None,
    )
  }
  // a camera with layers
  camera.layers.enable(3)
  renderer.render(scene, camera)
  // material disposal releases programs
  plane_material.dispose()
  note_int(gl, "programs after dispose", info.programs.unwrap().length())
  renderer.render(scene, camera)
  renderer.dispose()
  let log = emit_log("renderer_frame_unlit", gl)
  assert_true(log.length() > 1000)
}

///|
fn renderer_material(material : @core.Material, hex : Int32) -> @core.Material {
  renderer_set_color(material, hex)
  material
}

///|
fn renderer_mesh(
  geometry : @core.BufferGeometry,
  material : @core.Material,
) -> @core.Object3D {
  @core.Mesh::new(geometry~, material=Single(material))
}

///|
test "diff renderer_frame_lit" {
  let gl = mock_gl(options=renderer_mock_options("{}"))
  let canvas = renderer_mock_canvas(gl, 64, 32)
  let renderer = renderer_new(gl, canvas, antialias=true)
  renderer.shadow_map.enabled = true
  let scene = @core.Scene::new()
  scene.as_scene().fog = Some(
    Fog(
      @core.Fog::new(color=@math.Color::from_hex(0x202020), near=1.0, far=20.0),
    ),
  )
  let camera = @core.PerspectiveCamera::new(
    fov=45.0,
    aspect=2.0,
    near=0.5,
    far=50.0,
  )
  ignore(camera.position.set(0.0, 1.0, 6.0))
  camera.look_at_xyz(0.0, 0.0, 0.0)
  ignore(
    scene.add(
      @core.AmbientLight::new(
        color=@math.Color::from_hex(0x404040),
        intensity=0.5,
      ),
    ),
  )
  let sun = @core.DirectionalLight::new(
    color=@math.Color::from_hex(0xffffff),
    intensity=2.0,
  )
  ignore(sun.position.set(2.0, 4.0, 3.0))
  sun.cast_shadow = true
  ignore(sun.as_light().shadow.unwrap().map_size.set(64.0, 64.0))
  ignore(scene.add(sun))
  let point = @core.PointLight::new(
    color=@math.Color::from_hex(0xff8800),
    intensity=3.0,
    distance=10.0,
    decay=2.0,
  )
  ignore(point.position.set(-2.0, 1.0, 1.0))
  ignore(scene.add(point))
  let spot = @core.SpotLight::new(
    color=@math.Color::from_hex(0x00ff88),
    intensity=4.0,
    distance=12.0,
    angle=renderer_pi / 6.0,
    penumbra=0.2,
    decay=1.0,
  )
  ignore(spot.position.set(2.0, 3.0, 2.0))
  ignore(scene.add(spot))
  ignore(
    scene.add(
      @core.HemisphereLight::new(
        sky_color=@math.Color::from_hex(0x8888ff),
        ground_color=@math.Color::from_hex(0x442200),
        intensity=0.7,
      ),
    ),
  )
  let sphere = @geometries.SphereGeometry::new(
    radius=0.5,
    width_segments=8.0,
    height_segments=6.0,
  )
  let lambert = renderer_mesh(
    sphere,
    renderer_material(@core.MeshLambertMaterial::new(), 0xcc4444),
  )
  ignore(lambert.position.set(-1.2, 0.0, 0.0))
  lambert.cast_shadow = true
  ignore(scene.add(lambert))
  let phong_material = renderer_material(
    @core.MeshPhongMaterial::new(),
    0x44cc44,
  )
  phong_material.shininess = Some(50.0)
  let phong = renderer_mesh(sphere, phong_material)
  phong.cast_shadow = true
  ignore(scene.add(phong))
  let standard_material = renderer_material(
    @core.MeshStandardMaterial::new(),
    0x4444cc,
  )
  standard_material.roughness = Some(0.3)
  standard_material.metalness = Some(0.2)
  let standard = renderer_mesh(sphere, standard_material)
  ignore(standard.position.set(1.2, 0.0, 0.0))
  standard.cast_shadow = true
  ignore(scene.add(standard))
  let ground = renderer_mesh(
    @geometries.PlaneGeometry::new(width=6.0, height=6.0),
    renderer_material(@core.MeshStandardMaterial::new(), 0x888888),
  )
  ground.rotation.set_x(-renderer_pi / 2.0)
  ground.position.y = -0.6
  ground.receive_shadow = true
  ignore(scene.add(ground))
  let glass_material = renderer_material(
    @core.MeshLambertMaterial::new(),
    0xffffff,
  )
  glass_material.transparent = true
  glass_material.opacity = 0.5
  glass_material.side = @core.DoubleSide
  let glass = renderer_mesh(
    @geometries.BoxGeometry::new(width=0.6, height=0.6, depth=0.6),
    glass_material,
  )
  ignore(glass.position.set(0.0, 0.2, 1.5))
  ignore(scene.add(glass))
  // skinned mesh: two bones
  let skin_geometry = @geometries.BoxGeometry::new(
    width=0.3,
    height=1.0,
    depth=0.3,
    width_segments=1.0,
    height_segments=2.0,
    depth_segments=1.0,
  )
  let skin_position = skin_geometry.attributes["position"]
  let skin_index : Array[Double] = []
  let skin_weight : Array[Double] = []
  for i in 0..<skin_position.count() {
    let y = skin_position.get_y(i)
    skin_index.push_iter(
      [if y > 0.0 { 1.0 } else { 0.0 }, 0.0, 0.0, 0.0].iter(),
    )
    skin_weight.push_iter([1.0, 0.0, 0.0, 0.0].iter())
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
    material=Single(renderer_material(@core.MeshPhongMaterial::new(), 0xaaaa00)),
  )
  let root = @core.Bone::new()
  let tip = @core.Bone::new()
  tip.position.y = 0.5
  ignore(root.add(tip))
  ignore(skinned.add(root))
  skinned.bind(@core.Skeleton::new(bones=[root, tip]))
  tip.rotation.set_z(0.4)
  ignore(skinned.position.set(-2.0, 0.0, 0.0))
  ignore(scene.add(skinned))
  // morph targets
  let morph_geometry = @geometries.BoxGeometry::new(
    width=0.4,
    height=0.4,
    depth=0.4,
  )
  let positions = morph_geometry.attributes["position"]
  let target : Array[Double] = []
  for i in 0..<positions.count() {
    target.push_iter(
      [positions.get_x(i) * 2.0, positions.get_y(i), positions.get_z(i)].iter(),
    )
  }
  morph_geometry.morph_attributes["position"] = [
    Buffer(@core.Float32BufferAttribute::new(target, 3)),
  ]
  let morph = renderer_mesh(
    morph_geometry,
    renderer_material(@core.MeshStandardMaterial::new(), 0xff00ff),
  )
  guard morph.kind is Mesh({ morph_target_influences: Some(influences), .. }) else {
    fail("morph targets")
  }
  influences[0] = 0.5
  ignore(morph.position.set(2.0, 0.5, 0.0))
  ignore(scene.add(morph))
  renderer.render(scene, camera)
  note_json(gl, "info.render", [
    renderer.info.render.calls.to_double(),
    renderer.info.render.triangles,
  ])
  note_int(gl, "programs", renderer.info.programs.unwrap().length())
  // second frame with moved lights and shadow auto update off
  ignore(sun.position.set(-2.0, 4.0, 3.0))
  point.as_light().intensity = 1.0
  renderer.shadow_map.auto_update = false
  renderer.render(scene, camera)
  renderer.shadow_map.needs_update = true
  renderer.render(scene, camera)
  // a light added: lights hash changes, programs change
  let second = @core.DirectionalLight::new(
    color=@math.Color::from_hex(0xffffff),
    intensity=0.5,
  )
  ignore(scene.add(second))
  renderer.render(scene, camera)
  note_int(gl, "programs", renderer.info.programs.unwrap().length())
  // override material
  scene.as_scene().override_material = Some(
    renderer_material(@core.MeshBasicMaterial::new(), 0x00ff00),
  )
  renderer.render(scene, camera)
  scene.as_scene().override_material = None
  // clipping planes
  renderer.clipping_planes = [
    @math.Plane::new(normal=@math.Vector3::new(0.0, -1.0, 0.0), constant=0.5),
  ]
  renderer.local_clipping_enabled = true
  standard_material.clipping_planes = Some([
    @math.Plane::new(normal=@math.Vector3::new(1.0, 0.0, 0.0), constant=1.0),
  ])
  standard_material.set_needs_update(true)
  renderer.render(scene, camera)
  renderer.render(scene, camera)
  renderer.clipping_planes = []
  scene.as_scene().fog = Some(
    FogExp2(
      @core.FogExp2::new(color=@math.Color::from_hex(0x101010), density=0.1),
    ),
  )
  renderer.render(scene, camera)
  renderer.dispose()
  let log = emit_log("renderer_frame_lit", gl)
  assert_true(log.length() > 1000)
}

///|
/// `Math.PI`.
let renderer_pi : Double = 3.141592653589793

///|
/// `globalThis.self = value` (`undefined` deletes it): the renderer reads `self` for its
/// animation frames at construction.
extern "js" fn renderer_set_global_self(value : @core.JsValue) -> Unit = "(v) => { if (v === undefined) delete globalThis.self; else globalThis.self = v; }"

///|
/// Uniforms the RTT scene's shaders would not declare (it has one directional light only).
let renderer_rtt_drop : Array[String] = [
  "pointLights", "spotLights", "hemisphereLights", "directionalShadowMap", "directionalShadowMatrix",
  "directionalLightShadows",
]

///|
fn renderer_filled_data_texture(
  width : Int32,
  height : Int32,
  value : Double,
) -> @core.Texture {
  let data = @core.TypedArray::new(Uint8Array, width * height * 4)
  data.fill(value)
  let texture = @core.DataTexture::new(data~, width~, height~)
  texture.set_needs_update(true)
  texture
}

///|
test "diff renderer_frame_rtt" {
  // a real context answers the UNPACK_* queries copyTextureToTexture saves and restores
  let gl = mock_gl(
    options=renderer_mock_options(
      "{\"parameters\":{\"UNPACK_ROW_LENGTH\":0,\"UNPACK_IMAGE_HEIGHT\":0,\"UNPACK_SKIP_PIXELS\":0,\"UNPACK_SKIP_ROWS\":0,\"UNPACK_SKIP_IMAGES\":0}}",
      drop=renderer_rtt_drop,
    ),
  )
  let canvas = renderer_mock_canvas(gl, 64, 32)
  let frames = mock_animation_context(gl)
  renderer_set_global_self(@core.JsValue::of(frames))
  let renderer = renderer_new(gl, canvas)
  renderer_set_global_self(@core.JsValue::undefined())
  let scene = @core.Scene::new()
  let camera = @core.PerspectiveCamera::new(
    fov=60.0,
    aspect=2.0,
    near=0.1,
    far=20.0,
  )
  ignore(camera.position.set(0.0, 0.0, 4.0))
  ignore(
    scene.add(
      @core.DirectionalLight::new(
        color=@math.Color::from_hex(0xffffff),
        intensity=1.0,
      ),
    ),
  )
  let box = renderer_mesh(
    @geometries.BoxGeometry::new(width=1.0, height=1.0, depth=1.0),
    renderer_material(@core.MeshStandardMaterial::new(), 0x3366ff),
  )
  ignore(box.rotation.set(0.5, 0.5, 0.0))
  ignore(scene.add(box))
  // render to a texture, then show it on a plane
  let target = @webgl.WebGLRenderTarget::new(
    width=32,
    height=16,
    depth_buffer=true,
  )
  renderer.set_render_target(Some(target))
  renderer.render(scene, camera)
  renderer.set_render_target(None)
  let pixels = @core.TypedArray::new(Uint8Array, 4 * 4 * 4)
  renderer.read_render_target_pixels(target, 2, 2, 4, 4, pixels)
  let screen = @core.Scene::new()
  let screen_material = @core.MeshBasicMaterial::new()
  screen_material.map = Some(target.texture())
  ignore(
    screen.add(
      renderer_mesh(
        @geometries.PlaneGeometry::new(width=2.0, height=1.0),
        screen_material,
      ),
    ),
  )
  renderer.render(screen, camera)
  // multisampled target with mipmaps
  let msaa = @webgl.WebGLRenderTarget::new(
    width=16,
    height=16,
    samples=4,
    generate_mipmaps=true,
    min_filter=@core.LinearMipmapLinearFilter,
  )
  renderer.set_render_target(Some(msaa))
  renderer.render(scene, camera)
  renderer.set_render_target(None)
  // copies
  let fb_texture = @core.FramebufferTexture::new(width=16, height=16)
  renderer.copy_framebuffer_to_texture(
    fb_texture,
    position=@math.Vector2::new(2.0, 3.0),
  )
  renderer.copy_framebuffer_to_texture(fb_texture, level=1)
  let src_data = renderer_filled_data_texture(4, 4, 7.0)
  let dst_data = renderer_filled_data_texture(8, 8, 0.0)
  renderer.init_texture(dst_data)
  renderer.copy_texture_to_texture(
    src_data,
    dst_data,
    src_region=Box2(
      @math.Box2::new(
        min=@math.Vector2::new(0.0, 0.0),
        max=@math.Vector2::new(2.0, 2.0),
      ),
    ),
    dst_position=Vector2(@math.Vector2::new(1.0, 1.0)),
  )
  renderer.init_texture(src_data)
  renderer.copy_texture_to_texture(src_data, dst_data)
  // transmission
  let glass_material = @core.MeshPhysicalMaterial::new()
  glass_material.set_transmission(0.8)
  glass_material.thickness = Some(0.2)
  glass_material.side = @core.DoubleSide
  let glass = renderer_mesh(
    @geometries.SphereGeometry::new(
      radius=0.4,
      width_segments=6.0,
      height_segments=4.0,
    ),
    glass_material,
  )
  ignore(glass.position.set(0.0, 0.0, 1.0))
  ignore(scene.add(glass))
  renderer.render(scene, camera)
  renderer.transmission_resolution_scale = 0.5
  renderer.set_clear_alpha(0.5)
  renderer.render(scene, camera)
  // cube target from an equirectangular texture
  let equirect = renderer_filled_data_texture(8, 4, 128.0)
  equirect.mapping = @core.EquirectangularReflectionMapping
  let cube = @webgl.WebGLCubeRenderTarget::new(size=8)
  ignore(
    @webgl.WebGLCubeRenderTarget::from_equirectangular_texture(
      cube, renderer, equirect,
    ),
  )
  let cube_texture = cube.texture()
  note_json(gl, "cube texture", [
    Json(cube_texture.type_),
    Json(cube_texture.color_space),
    Json(cube_texture.min_filter),
    Json(equirect.min_filter),
  ])
  // compileAsync
  let extra = renderer_mesh(
    @geometries.BoxGeometry::new(),
    @core.MeshPhongMaterial::new(),
  )
  renderer.compile_async(
    extra,
    camera,
    done => note_bool(gl, "compileAsync", physical_equal(done, extra)),
    target_scene=scene,
  )
  // animation loop
  renderer.set_animation_loop(
    Some((time, _) => {
      note_num(gl, "frame", time)
      renderer.render(scene, camera)
    }),
  )
  mock_tick(frames, 16.0)
  mock_tick(frames, 32.0)
  renderer.set_animation_loop(None)
  mock_tick(frames, 48.0)
  renderer.dispose()
  let log = emit_log("renderer_frame_rtt", gl)
  assert_true(log.length() > 1000)
}

///|
test "diff renderer_frame_extra" {
  let gl = mock_gl(options=renderer_mock_options("{}", drop=renderer_rtt_drop))
  let canvas = renderer_mock_canvas(gl, 64, 32)
  let renderer = renderer_new(gl, canvas)
  let scene = @core.Scene::new()
  let scene_data = scene.as_scene()
  scene_data.background = Some(Color(@math.Color::from_hex(0x112233)))
  ignore(
    scene.add(
      @core.DirectionalLight::new(
        color=@math.Color::from_hex(0xffffff),
        intensity=1.0,
      ),
    ),
  )
  let equirect = renderer_filled_data_texture(8, 4, 200.0)
  equirect.mapping = @core.EquirectangularReflectionMapping
  scene_data.environment = Some(equirect)
  scene_data.environment_intensity = 0.5
  let sphere_material = @core.MeshStandardMaterial::new()
  sphere_material.roughness = Some(0.4)
  let sphere = renderer_mesh(
    @geometries.SphereGeometry::new(
      radius=0.5,
      width_segments=6.0,
      height_segments=4.0,
    ),
    sphere_material,
  )
  ignore(scene.add(sphere))
  let lambert = renderer_mesh(
    @geometries.SphereGeometry::new(
      radius=0.3,
      width_segments=6.0,
      height_segments=4.0,
    ),
    renderer_material(@core.MeshLambertMaterial::new(), 0x00ff00),
  )
  ignore(lambert.position.set(1.0, 0.0, 0.0))
  ignore(scene.add(lambert))
  let camera = @core.PerspectiveCamera::new(
    fov=50.0,
    aspect=2.0,
    near=0.1,
    far=10.0,
  )
  ignore(camera.position.set(0.0, 0.0, 3.0))
  renderer.render(scene, camera)
  // array camera with two viewports
  let left = @core.PerspectiveCamera::new(
    fov=50.0,
    aspect=1.0,
    near=0.1,
    far=10.0,
  )
  ignore(left.position.set(-0.5, 0.0, 3.0))
  @webgl.set_camera_viewport(
    left,
    Some(@math.Vector4::new(0.0, 0.0, 32.0, 32.0)),
  )
  left.update_matrix_world()
  let right = @core.PerspectiveCamera::new(
    fov=50.0,
    aspect=1.0,
    near=0.1,
    far=10.0,
  )
  ignore(right.position.set(0.5, 0.0, 3.0))
  @webgl.set_camera_viewport(
    right,
    Some(@math.Vector4::new(32.0, 0.0, 32.0, 32.0)),
  )
  right.update_matrix_world()
  let array = @core.ArrayCamera::new(array=[left, right])
  ignore(array.position.set(0.0, 0.0, 3.0))
  renderer.render(scene, array)
  // a render nested in another frame
  let inner = @core.Scene::new()
  ignore(
    inner.add(
      renderer_mesh(
        @geometries.BoxGeometry::new(width=0.2, height=0.2, depth=0.2),
        renderer_basic(hex=0xff0000),
      ),
    ),
  )
  let inner_target = @webgl.WebGLRenderTarget::new(width=8, height=8)
  lambert.on_after_render = (_, _, _, _, _, _) => {
    lambert.on_after_render = (_, _, _, _, _, _) => ()
    let previous = renderer.get_render_target()
    renderer.set_render_target(Some(inner_target))
    renderer.render(inner, camera)
    renderer.set_render_target(previous)
  }
  renderer.render(scene, camera)
  // 3D and array targets
  let target3d = @webgl.WebGL3DRenderTarget::new(width=4, height=4, depth=3)
  renderer.set_render_target(Some(target3d), active_cube_face=2)
  renderer.clear()
  let target_array = @webgl.WebGLArrayRenderTarget::new(
    width=4,
    height=4,
    depth=2,
  )
  renderer.set_render_target(Some(target_array), active_cube_face=1)
  renderer.render(inner, camera)
  renderer.set_render_target(None)
  // externally managed textures and framebuffers
  let external = @webgl.WebGLRenderTarget::new(
    width=8,
    height=8,
    depth_texture=@core.DepthTexture::new(width=8, height=8),
  )
  renderer.set_render_target_textures(
    external,
    Some(gl.create_texture()),
    Some(gl.create_texture()),
  )
  renderer.set_render_target(Some(external))
  renderer.set_render_target(Some(external))
  renderer.set_render_target(None)
  let framebuffer = @webgl.WebGLRenderTarget::new(width=8, height=8)
  renderer.set_render_target_framebuffer(
    framebuffer,
    Some(gl.create_framebuffer()),
  )
  renderer.set_render_target(Some(framebuffer))
  renderer.clear()
  renderer.set_render_target(None)
  // batched mesh
  let batched = @core.BatchedMesh::new(
    3,
    100,
    max_index_count=300,
    material=Single(@core.MeshBasicMaterial::new()),
  )
  let id = batched.add_geometry(
    @geometries.BoxGeometry::new(width=0.3, height=0.3, depth=0.3),
  )
  let i0 = batched.add_instance(id)
  ignore(
    batched.set_matrix_at(
      i0,
      @math.Matrix4::new().make_translation(-1.0, 1.0, 0.0),
    ),
  )
  ignore(batched.add_instance(id))
  let batched_scene = @core.Scene::new()
  ignore(batched_scene.add(batched))
  renderer.render(batched_scene, camera)
  renderer.dispose()
  // half float output with tone mapping
  let hdr = renderer_new(gl, canvas, output_buffer_type=@core.HalfFloatType)
  hdr.tone_mapping = @core.ACESFilmicToneMapping
  hdr.set_size(32.0, 16.0)
  hdr.render(inner, camera)
  hdr.set_effects(None)
  hdr.render(inner, camera)
  hdr.dispose()
  let log = emit_log("renderer_frame_extra", gl)
  assert_true(log.length() > 1000)
}

///|
test "diff renderer_async" {
  let gl = mock_gl(
    options=renderer_mock_options(
      "{\"extensions\":[\"EXT_color_buffer_float\",\"EXT_color_buffer_half_float\",\"OES_texture_float_linear\",\"WEBGL_multi_draw\"]}",
    ),
  )
  let canvas = renderer_mock_canvas(gl, 64, 32)
  let renderer = renderer_new(gl, canvas)
  let target = @webgl.WebGLRenderTarget::new(width=8, height=8)
  renderer.set_render_target(Some(target))
  renderer.clear()
  renderer.set_render_target(None)
  let buffer = @core.TypedArray::new(Uint8Array, 4 * 4 * 4)
  // the log is emitted at the end of the callback chain, after the timers ran
  renderer.read_render_target_pixels_async(target, 0, 0, 4, 4, buffer, result => {
    note_bool(gl, "resolved", physical_equal(result, buffer))
    renderer.read_render_target_pixels_async(
      target,
      6,
      6,
      4,
      4,
      buffer,
      _ => (),
      on_error=() => {
        note_bool(gl, "rejected", true)
        let scene = @core.Scene::new()
        ignore(
          scene.add(
            renderer_mesh(
              @geometries.BoxGeometry::new(),
              @core.MeshBasicMaterial::new(),
            ),
          ),
        )
        let camera = @core.PerspectiveCamera::new()
        renderer.compile_async(scene, camera, done => {
          note_bool(gl, "compileAsync", physical_equal(done, scene))
          renderer.dispose()
          ignore(emit_log("renderer_async", gl))
        })
      },
    )
  })
}
