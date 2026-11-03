// Helpers for the objects' mock-GL scenarios: copies of src/renderers/webgl's test
// helpers (webgl_test_helpers_test.mbt) and of the renderer scenarios' mock canvas and
// program spec (harness/scenarios/renderer_common.cjs, embedded verbatim there and here).

///|
let mock_module : @core.JsValue = ffi_mock_gl_module(())

///|
extern "js" fn ffi_mock_create(
  module_ : @core.JsValue,
  options : String,
) -> @webgl.WebGL2RenderingContext = "(m, o) => m.createMockGL(JSON.parse(o))"

///|
/// A mock context; `options` is the JSON options object of `createMockGL`.
fn mock_gl(options~ : String = "{}") -> @webgl.WebGL2RenderingContext {
  ffi_mock_create(mock_module, options)
}

///|
extern "js" fn ffi_mock_log(
  gl : @webgl.WebGL2RenderingContext,
) -> FixedArray[String] = "(gl) => gl.__log.slice()"

///|
/// The calls recorded so far, one `name(args)` string each.
fn mock_log(gl : @webgl.WebGL2RenderingContext) -> Array[String] {
  Array::from_fixed_array(ffi_mock_log(gl))
}

///|
/// Clears the recorded calls.
#warnings("-unused_value")
extern "js" fn mock_clear(gl : @webgl.WebGL2RenderingContext) -> Unit = "(gl) => gl.__clear()"

///|
/// Records `# label <JSON of value>`, for results that are not GL calls.
extern "js" fn mock_note(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  value : @core.JsValue,
) -> Unit = "(gl, l, v) => gl.__note(l, v)"

///|
/// `mock_note` for a number.
fn note_num(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  value : Double,
) -> Unit {
  mock_note(gl, label, @core.JsValue::of(value))
}

///|
/// `mock_note` for an integer.
fn note_int(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  value : Int32,
) -> Unit {
  mock_note(gl, label, @core.JsValue::of(value))
}

///|
/// `mock_note` for a boolean.
fn note_bool(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  value : Bool,
) -> Unit {
  mock_note(gl, label, @core.JsValue::of(value))
}

///|
/// `mock_note` for a string.
fn note_str(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  value : String,
) -> Unit {
  mock_note(gl, label, @core.JsValue::of(value))
}

///|
/// `mock_note` for an optional integer; `None` is noted as `null`.
fn note_opt_int(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  value : Int32?,
) -> Unit {
  match value {
    Some(v) => note_int(gl, label, v)
    None => mock_note(gl, label, @core.JsValue::null())
  }
}

///|
extern "js" fn diff_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.WEBGL_DIFF === '1'"

///|
extern "js" fn ffi_log_json(gl : @webgl.WebGL2RenderingContext) -> String = "(gl) => JSON.stringify(gl.__log)"

///|
/// Prints the log for run_diff.mjs when `WEBGL_DIFF=1`; returns the log either way.
fn emit_log(name : String, gl : @webgl.WebGL2RenderingContext) -> Array[String] {
  if diff_enabled() {
    println("@@WEBGL_LOG " + name + " " + ffi_log_json(gl))
  }
  mock_log(gl)
}

///|
extern "js" fn ffi_mock_animation_context(
  module_ : @core.JsValue,
  gl : @webgl.WebGL2RenderingContext,
) -> @webgl.AnimationFrameProvider = "(m, gl) => m.createMockAnimationContext(gl)"

///|
/// A `requestAnimationFrame` provider that records into `gl`'s log.
fn mock_animation_context(
  gl : @webgl.WebGL2RenderingContext,
) -> @webgl.AnimationFrameProvider {
  ffi_mock_animation_context(mock_module, gl)
}

///|
/// Runs the pending animation frames with `time`.
extern "js" fn mock_tick(
  context : @webgl.AnimationFrameProvider,
  time : Double,
) -> Unit = "(c, t) => c.__tick(t)"

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
