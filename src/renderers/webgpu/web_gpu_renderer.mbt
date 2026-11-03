// renderers/webgpu/WebGPURenderer.js: the renderer with a WebGPU backend (or the WebGL 2
// fallback) and the standard node library. `WebGPURenderer::new` takes upstream's
// options as labelled arguments and returns the `@nodes.Renderer`;
// `WebGPURenderer::from_parameters` takes the parameters object.

///|
/// `WebGPURenderer` (the constructors return the common `Renderer`).
#external
pub type WebGPURenderer

///|
/// The renderers built by `WebGPURenderer` (`isWebGPURenderer`).
let _web_gpu_renderers : @webgl.WeakMap[@nodes.Renderer, Bool] = @webgl.WeakMap::new()

///|
/// `renderer.isWebGPURenderer`.
pub fn is_web_gpu_renderer(renderer : @nodes.Renderer) -> Bool {
  _web_gpu_renderers.get(renderer) == Some(true)
}

///|
/// `new WebGLBackend( parameters )`: the WebGL 2 fallback (renderers/webgl_fallback).
fn _web_gpu_renderer_webgl_backend(
  parameters : @core.JsValue,
) -> @nodes.Backend {
  @webgl_fallback.WebGLBackend::new(parameters~)
}

///|
extern "js" fn wgpu_parameter_or(
  parameters : @core.JsValue,
  key : String,
  default : @core.JsValue,
) -> @core.JsValue = "(p, k, d) => p[k] === undefined ? d : p[k]"

///|
fn wgpu_parameter_bool(
  parameters : @core.JsValue,
  key : String,
  default : Bool,
) -> Bool {
  wgpu_parameter_or(parameters, key, @core.JsValue::of(default)).cast()
}

///|
fn wgpu_parameter_int(
  parameters : @core.JsValue,
  key : String,
  default : Int32,
) -> Int32 {
  wgpu_parameter_or(parameters, key, @core.JsValue::of(default)).cast()
}

///|
/// `new WebGPURenderer( parameters = {} )` with a parameters object (upstream's keys:
/// `canvas`, `context`, `antialias`, `forceWebGL`, `trackTimestamp`, `device`, ...).
pub fn WebGPURenderer::from_parameters(
  parameters : @core.JsValue,
  library? : () -> @nodes.NodeLibrary,
) -> @nodes.Renderer {
  let backend = if wgpu_truthy(parameters.get("forceWebGL")) {
    _web_gpu_renderer_webgl_backend(parameters)
  } else {
    WebGPUBackend::new(parameters~)
  }
  let get_fallback = if wgpu_truthy(parameters.get("forceWebGL")) {
    None
  } else {
    Some(fn(_error : String) -> @nodes.Backend {
      @core.warn(
        "WebGPURenderer: WebGPU is not available, running under WebGL2 backend.",
      )
      _web_gpu_renderer_webgl_backend(parameters)
    })
  }
  //super( new Proxy( backend, debugHandler ) );
  let renderer = @nodes.Renderer::new(
    backend,
    logarithmic_depth_buffer=wgpu_parameter_bool(
      parameters, "logarithmicDepthBuffer", false,
    ),
    reversed_depth_buffer=wgpu_parameter_bool(
      parameters, "reversedDepthBuffer", false,
    ),
    alpha=wgpu_parameter_bool(parameters, "alpha", true),
    depth=wgpu_parameter_bool(parameters, "depth", true),
    stencil=wgpu_parameter_bool(parameters, "stencil", false),
    antialias=wgpu_parameter_bool(parameters, "antialias", false),
    samples=wgpu_parameter_int(parameters, "samples", 0),
    get_fallback?,
    output_buffer_type=wgpu_parameter_int(
      parameters,
      "outputBufferType",
      @core.HalfFloatType,
    ),
    multiview=wgpu_parameter_bool(parameters, "multiview", false),
  )
  // The generic default value is overwritten with the
  // standard node library for type mapping.
  renderer.library = match library {
    Some(make) => make()
    None => StandardNodeLibrary::new()
  }
  _web_gpu_renderers.set(renderer, true)
  renderer
}

///|
/// `new WebGPURenderer( { ... } )`: only the given options become keys of the
/// parameters object, in this order.
pub fn WebGPURenderer::new(
  canvas? : @core.JsValue,
  context? : @gpu.GPUCanvasContext,
  logarithmic_depth_buffer? : Bool,
  reversed_depth_buffer? : Bool,
  alpha? : Bool,
  depth? : Bool,
  stencil? : Bool,
  antialias? : Bool,
  samples? : Int32,
  force_webgl? : Bool,
  multiview? : Bool,
  output_type? : Int32,
  output_buffer_type? : Int32,
  track_timestamp? : Bool,
  power_preference? : String,
  required_limits? : @core.JsValue,
  device? : @gpu.GPUDevice,
) -> @nodes.Renderer {
  let p = @core.JsValue::object()
  let put = fn(key : String, value : @core.JsValue?) {
    match value {
      Some(v) => p.set(key, v)
      None => ()
    }
  }
  put("canvas", canvas)
  put("context", context.map(@core.JsValue::of))
  put("logarithmicDepthBuffer", logarithmic_depth_buffer.map(@core.JsValue::of))
  put("reversedDepthBuffer", reversed_depth_buffer.map(@core.JsValue::of))
  put("alpha", alpha.map(@core.JsValue::of))
  put("depth", depth.map(@core.JsValue::of))
  put("stencil", stencil.map(@core.JsValue::of))
  put("antialias", antialias.map(@core.JsValue::of))
  put("samples", samples.map(@core.JsValue::of))
  put("forceWebGL", force_webgl.map(@core.JsValue::of))
  put("multiview", multiview.map(@core.JsValue::of))
  put("outputType", output_type.map(@core.JsValue::of))
  put("outputBufferType", output_buffer_type.map(@core.JsValue::of))
  put("trackTimestamp", track_timestamp.map(@core.JsValue::of))
  put("powerPreference", power_preference.map(@core.JsValue::of))
  put("requiredLimits", required_limits)
  put("device", device.map(@core.JsValue::of))
  WebGPURenderer::from_parameters(p)
}
