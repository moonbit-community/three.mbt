// The WebGPUBackend members WGSLNodeBuilder.js reads: `backend.compatibilityMode`,
// `backend.device` (its features), `backend.utils.getTextureSampleData( texture )`
// (WebGPUUtils) and `getFormat( texture, device )` (WebGPUTextureUtils). With a
// `WebGPUBackend` they are the backend's own members; other backends (the shader
// harness's stand-in renderers) answer from a small per-backend record,
// `WGSLBackendState`. `renderer.hasFeature` and `renderer.currentSamples` are G6's
// `Renderer::has_feature` and `Renderer::current_samples`.

///|
/// The WebGPUBackend state the builder reads from a backend that is not a
/// `WebGPUBackend` (shader tests).
pub(all) struct WGSLBackendState {
  /// `backend.device.features` (WebGPU feature names; `device` is `null` before
  /// `init()`, which reads as no features).
  features : Array[String]
  /// `backend.compatibilityMode` (`null`, i.e. false, before `init()`).
  mut compatibility_mode : Bool
}

///|
let _wgsl_backend_states : @webgl.WeakMap[@nodes.Backend, WGSLBackendState] = @webgl.WeakMap::new()

///|
/// The stand-in state of a backend, created empty on first use.
pub fn wgsl_backend_state(backend : @nodes.Backend) -> WGSLBackendState {
  match _wgsl_backend_states.get(backend) {
    Some(s) => s
    None => {
      let s = { features: [], compatibility_mode: false, }
      _wgsl_backend_states.set(backend, s)
      s
    }
  }
}

///|
/// `GPUFeatureMap`: three.js feature names that differ from the WebGPU ones.
pub fn wgsl_gpu_feature_name(name : String) -> String {
  match gpu_feature_map(name) {
    Some(n) => n
    None => name
  }
}

///|
/// `renderer.hasFeature( name )`.
pub fn wgsl_renderer_has_feature(
  renderer : @nodes.Renderer,
  name : String,
) -> Bool {
  renderer.has_feature(name)
}

///|
/// `device.features.has( name )` (a WebGPU feature name).
fn _wgsl_device_has_feature(renderer : @nodes.Renderer, name : String) -> Bool {
  match WebGPUBackend::of(renderer.backend) {
    Some(backend) =>
      match backend.device {
        Some(device) => device.features().has(name)
        None =>
          abort(
            "TypeError: Cannot read properties of null (reading 'features')",
          )
      }
    None => wgsl_backend_state(renderer.backend).features.contains(name)
  }
}

///|
/// `renderer.backend.compatibilityMode` (truthiness).
pub fn wgsl_backend_compatibility_mode(renderer : @nodes.Renderer) -> Bool {
  match WebGPUBackend::of(renderer.backend) {
    Some(backend) => backend.compatibility_mode == Some(true)
    None => wgsl_backend_state(renderer.backend).compatibility_mode
  }
}

///|
/// The result of `getTextureSampleData( texture )`.
pub(all) struct WGSLTextureSampleData {
  samples : Int32
  primary_samples : Int32
  is_msaa : Bool
}

///|
extern "js" fn _wgsl_js_sample_count(record : @core.JsValue) -> @core.JsValue = "(d) => d.texture === undefined ? undefined : d.texture.sampleCount"

///|
extern "js" fn _wgsl_js_int(value : @core.JsValue) -> Int32 = "(v) => v || 0"

///|
/// `getSampleCount( sampleCount )` of WebGPUUtils.
fn _wgsl_get_sample_count(sample_count : Int32) -> Int32 {
  if sample_count >= 4 {
    4
  } else {
    1
  }
}

///|
/// `backend.utils.getTextureSampleData( texture )` of WebGPUUtils.
pub fn wgsl_get_texture_sample_data(
  renderer : @nodes.Renderer,
  texture : @core.Texture,
) -> WGSLTextureSampleData {
  match WebGPUBackend::of(renderer.backend) {
    Some(backend) => {
      let { samples, primary_samples, is_msaa, } = backend.utils.get_texture_sample_data(
        texture,
      )
      return { samples, primary_samples, is_msaa, }
    }
    None => ()
  }
  // the same steps on a backend without WebGPUUtils
  let is_framebuffer = texture.texture_type is FramebufferTexture
  let samples = if is_framebuffer {
    1
  } else if texture.is_depth_texture() && texture.render_target is None {
    let texture_data = _wgsl_js_sample_count(
      renderer.backend.get(@core.JsValue::of(texture)),
    )
    if !texture_data.is_undefined() {
      // use the effective sample count of the allocated texture
      _wgsl_js_int(texture_data)
    } else {
      // otherwise use the current samples of the renderer
      renderer.current_samples()
    }
  } else {
    match texture.render_target {
      Some(render_target) => render_target.samples
      None => 0
    }
  }
  let samples = _wgsl_get_sample_count(if samples == 0 { 1 } else { samples })
  let has_render_target = texture.render_target is Some(_)
  let is_msaa = samples > 1 &&
    has_render_target &&
    !texture.is_depth_texture() &&
    !is_framebuffer
  let is_msaa_array_depth_texture = samples > 1 &&
    has_render_target &&
    texture.is_depth_texture() &&
    texture.is_array_texture
  let primary_samples = if is_msaa || is_msaa_array_depth_texture {
    1
  } else {
    samples
  }
  { samples, primary_samples, is_msaa, }
}

///|
/// `getFormat( texture, device )` of WebGPUTextureUtils: the GPU format of a texture
/// (`"undefined"` for an unsupported one).
pub fn wgsl_get_format(
  renderer : @nodes.Renderer,
  texture : @core.Texture,
) -> String {
  let has_device = fn() {
    match WebGPUBackend::of(renderer.backend) {
      Some(backend) => backend.device is Some(_)
      // the stand-in device exists once the renderer is initialized
      None => renderer._initialized
    }
  }
  wgpu_get_format_with(
    texture,
    fn(name) { _wgsl_device_has_feature(renderer, name) },
    has_device,
  ).unwrap_or("undefined")
}
