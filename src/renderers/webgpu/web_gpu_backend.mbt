// renderers/webgpu/WebGPUBackend.js: the WebGPU backend. `WebGPUBackend` is the payload of
// the base `@nodes.Backend` (its `class_`); `WebGPUBackend::new` returns the base, and
// `WebGPUBackend::of( backend )` recovers the payload. Per-object records are the base's
// `backend.get( object )` JS objects, with upstream's keys. Upstream `await` resumes on a
// later microtask (`wgpu_await`, a native `Promise.resolve( p ).then`), `.then` runs as
// soon as the promise settles, so the call order matches upstream also with the
// synchronous promises of the mock GPU.

///|
extern "js" fn wgpu_js_string(v : @core.JsValue) -> String = "(v) => String( v )"

///|
extern "js" fn wgpu_number_string(v : Double) -> String = "(v) => String( v )"

///|
extern "js" fn wgpu_truthy(v : @core.JsValue) -> Bool = "(v) => !!v"

///|
/// `await p`: `ok` runs on a later microtask with the value, `err` on rejection.
extern "js" fn wgpu_await(
  p : @core.JsValue,
  ok : (@core.JsValue) -> Unit,
  err : (@core.JsValue) -> Unit,
) -> Unit = "(p, ok, err) => { Promise.resolve( p ).then( ok, err ); }"

///|
/// `array.join()`.
extern "js" fn wgpu_join_js(a : @core.JsValue) -> String = "(a) => a.join()"

///|
fn wgpu_join(a : Array[@core.JsValue]) -> String {
  wgpu_join_js(@core.JsValue::of(a))
}

///|
extern "js" fn wgpu_new_weak_set() -> @core.JsValue = "() => new WeakSet()"

///|
extern "js" fn wgpu_weak_set_add(
  set : @core.JsValue,
  v : @core.JsValue,
) -> Unit = "(s, v) => { s.add( v ); }"

///|
extern "js" fn wgpu_weak_set_has(
  set : @core.JsValue,
  v : @core.JsValue,
) -> Bool = "(s, v) => s.has( v )"

///|
extern "js" fn wgpu_compatibility_texture_compare() -> Bool = "() => typeof navigator === 'undefined' ? true : /Android/.test( navigator.userAgent ) === false"

///|
extern "js" fn wgpu_set_data_engine(
  dom_element : @core.JsValue,
  value : String,
) -> Unit = "(d, v) => { if ( 'setAttribute' in d ) d.setAttribute( 'data-engine', v ); }"

///|
extern "js" fn wgpu_device_loss_info(
  info : @gpu.GPUDeviceLostInfo,
) -> @core.JsValue = "(info) => ( { api: 'WebGPU', message: info.message || 'Unknown reason', reason: info.reason || null, originalEvent: info } )"

///|
extern "js" fn wgpu_uncaptured_error_info(
  event : @gpu.GPUUncapturedErrorEvent,
) -> @core.JsValue =
  #|(event) => {
  #|  const gpuError = event.error;
  #|  const type = gpuError && gpuError.constructor ? gpuError.constructor.name : 'GPUError';
  #|  const message = ( gpuError && gpuError.message ) || 'Unknown uncaptured GPU error';
  #|  return { api: 'WebGPU', type, message, originalEvent: event };
  #|}

///|
extern "js" fn wgpu_error_string(e : @core.JsValue) -> String = "(e) => ( e && e.message !== undefined ) ? String( e.message ) : String( e )"

///|
/// `o[ key ]`, `None` for `undefined` and `null`.
fn[T] wgpu_opt(o : @core.JsValue, key : String) -> T? {
  let v = o.get(key)
  if v.is_undefined() || v.is_null() {
    None
  } else {
    Some(v.cast())
  }
}

///|
/// `o[ key ] = value`, `None` as `undefined`.
fn[T] wgpu_set_opt(o : @core.JsValue, key : String, value : T?) -> Unit {
  match value {
    Some(v) => o.set(key, @core.JsValue::of(v))
    None => o.set(key, @core.JsValue::undefined())
  }
}

///|
/// `navigator.gpu`.
fn wgpu_navigator_gpu() -> @gpu.GPU {
  match @gpu.gpu() {
    Some(g) => g
    None =>
      abort(
        "TypeError: Cannot read properties of undefined (reading 'getPreferredCanvasFormat')",
      )
  }
}

///|
let _web_gpu_backend_clear_value : @gpu.GPUColor = @gpu.GPUColor::new(
  r=0.0,
  g=0.0,
  b=0.0,
  a=1.0,
)

///|
let _web_gpu_backend_blend_constant : @gpu.GPUColor = @gpu.GPUColor::new(
  r=0.0,
  g=0.0,
  b=0.0,
  a=0.0,
)

///|
let _web_gpu_backend_buffer_descriptor : @gpu.GPUBufferDescriptor = @gpu.GPUBufferDescriptor::default()

///|
let _web_gpu_backend_command_encoder_descriptor : @gpu.GPUCommandEncoderDescriptor = @gpu.GPUCommandEncoderDescriptor::default()

///|
let _web_gpu_backend_compute_pass_descriptor : @gpu.GPUComputePassDescriptor = @gpu.GPUComputePassDescriptor::default()

///|
let _web_gpu_backend_query_set_descriptor : @gpu.GPUQuerySetDescriptor = @gpu.GPUQuerySetDescriptor::default()

///|
let _web_gpu_backend_shader_module_descriptor : @gpu.GPUShaderModuleDescriptor = @gpu.GPUShaderModuleDescriptor::default()

///|
let _web_gpu_backend_render_pass_timestamp_writes : @gpu.GPURenderPassTimestampWrites = @gpu.GPURenderPassTimestampWrites::default()

///|
let _web_gpu_backend_texel_copy_texture_info_src : @gpu.GPUTexelCopyTextureInfo = @gpu.GPUTexelCopyTextureInfo::default()

///|
let _web_gpu_backend_texel_copy_texture_info_dst : @gpu.GPUTexelCopyTextureInfo = @gpu.GPUTexelCopyTextureInfo::default()

///|
let _web_gpu_backend_texture_descriptor : @gpu.GPUTextureDescriptor = @gpu.GPUTextureDescriptor::default()

///|
let _web_gpu_backend_view_descriptor : @gpu.GPUTextureViewDescriptor = @gpu.GPUTextureViewDescriptor::default()

///|
let _web_gpu_backend_extent3d : @gpu.GPUExtent3D = @gpu.GPUExtent3D::default()

///|
/// The encoder draws are recorded into: a render pass or a render bundle encoder.
pub(all) enum WebGPUPassEncoder {
  Pass(@gpu.GPURenderPassEncoder)
  Bundle(@gpu.GPURenderBundleEncoder)
}

///|
fn WebGPUPassEncoder::set_pipeline(
  self : WebGPUPassEncoder,
  pipeline : @gpu.GPURenderPipeline,
) -> Unit {
  match self {
    Pass(p) => p.set_pipeline(pipeline)
    Bundle(p) => p.set_pipeline(pipeline)
  }
}

///|
fn WebGPUPassEncoder::set_bind_group(
  self : WebGPUPassEncoder,
  index : Int32,
  bind_group : @gpu.GPUBindGroup,
) -> Unit {
  match self {
    Pass(p) => p.set_bind_group(index, bind_group)
    Bundle(p) => p.set_bind_group(index, bind_group)
  }
}

///|
fn WebGPUPassEncoder::set_index_buffer(
  self : WebGPUPassEncoder,
  buffer : @gpu.GPUBuffer,
  format : String,
) -> Unit {
  match self {
    Pass(p) => p.set_index_buffer(buffer, format)
    Bundle(p) => p.set_index_buffer(buffer, format)
  }
}

///|
fn WebGPUPassEncoder::set_vertex_buffer(
  self : WebGPUPassEncoder,
  slot : Int32,
  buffer : @gpu.GPUBuffer,
) -> Unit {
  match self {
    Pass(p) => p.set_vertex_buffer(slot, buffer)
    Bundle(p) => p.set_vertex_buffer(slot, buffer)
  }
}

///|
fn WebGPUPassEncoder::draw(
  self : WebGPUPassEncoder,
  vertex_count : Int32,
  instance_count : Int32,
  first_vertex : Int32,
  first_instance : Int32,
) -> Unit {
  match self {
    Pass(p) =>
      p.draw(vertex_count, instance_count~, first_vertex~, first_instance~)
    Bundle(p) =>
      p.draw(vertex_count, instance_count~, first_vertex~, first_instance~)
  }
}

///|
fn WebGPUPassEncoder::draw_indexed(
  self : WebGPUPassEncoder,
  index_count : Int32,
  instance_count : Int32,
  first_index : Int32,
  base_vertex : Int32,
  first_instance : Int32,
) -> Unit {
  match self {
    Pass(p) =>
      p.draw_indexed(
        index_count,
        instance_count~,
        first_index~,
        base_vertex~,
        first_instance~,
      )
    Bundle(p) =>
      p.draw_indexed(
        index_count,
        instance_count~,
        first_index~,
        base_vertex~,
        first_instance~,
      )
  }
}

///|
fn WebGPUPassEncoder::draw_indirect(
  self : WebGPUPassEncoder,
  buffer : @gpu.GPUBuffer,
  offset : Int32,
) -> Unit {
  match self {
    Pass(p) => p.draw_indirect(buffer, offset)
    Bundle(p) => p.draw_indirect(buffer, offset)
  }
}

///|
fn WebGPUPassEncoder::draw_indexed_indirect(
  self : WebGPUPassEncoder,
  buffer : @gpu.GPUBuffer,
  offset : Int32,
) -> Unit {
  match self {
    Pass(p) => p.draw_indexed_indirect(buffer, offset)
    Bundle(p) => p.draw_indexed_indirect(buffer, offset)
  }
}

///|
/// A render pass method a bundle encoder does not have aborts like upstream's TypeError.
fn WebGPUPassEncoder::pass(
  self : WebGPUPassEncoder,
  name : String,
) -> @gpu.GPURenderPassEncoder {
  match self {
    Pass(p) => p
    Bundle(_) => abort("TypeError: currentPass.\{name} is not a function")
  }
}

///|
/// `currentSets`: the state already set on an encoder.
pub(all) struct WebGPUCurrentSets {
  /// `attributes[ slot ]`.
  attributes : Map[Int32, @nodes.AttributeBuffer]
  /// `bindingGroups[ index ]`.
  binding_groups : Map[Int32, @gpu.GPUBindGroup]
  mut pipeline : @gpu.GPURenderPipeline?
  /// `index`: the index attribute; `None` is `null`.
  mut index : @core.JsValue?
}

///|
/// `{ attributes: {}, bindingGroups: [], pipeline: null, index: null }`.
fn WebGPUCurrentSets::new() -> WebGPUCurrentSets {
  { attributes: Map([]), binding_groups: Map([]), pipeline: None, index: None, }
}

///|
/// `{ view, resolveTarget, depthSlice }` of the attachment views.
priv struct WebGPUTextureViewInfo {
  view : @gpu.GPUTextureView
  resolve_target : @gpu.GPUTextureView?
  depth_slice : Int32?
}

///|
/// `descriptorBase` of a render target's cached render pass descriptors.
priv struct WebGPUDescriptorBase {
  texture_views : Array[WebGPUTextureViewInfo]
  color_attachments : Array[@gpu.GPURenderPassColorAttachment]
  descriptor : @gpu.GPURenderPassDescriptor
  mut depth_stencil_attachment : @gpu.GPURenderPassDepthStencilAttachment?
}

///|
/// `colorAttachmentsConfig` of `_getRenderPassDescriptor`.
priv struct WebGPUColorAttachmentsConfig {
  load_op : String?
  store_op : String?
  clear_value : @gpu.GPUColor?
}

///|
/// `framebufferCopy` of a layered render stage.
priv struct WebGPUFramebufferCopy {
  texture : @core.Texture
  source_gpu : @gpu.GPUTexture
  destination_gpu : @gpu.GPUTexture
  rectangle : @math.Vector4
  generate_mipmaps : Bool
}

///|
/// An entry of `arrayCameraRenderStages`.
priv struct WebGPURenderStage {
  bundles : Array[@gpu.GPURenderBundle]
  framebuffer_copy : WebGPUFramebufferCopy?
}

///|
/// `programGPU.module`: `{ module, entryPoint: 'main' }`.
pub(all) struct WebGPUProgramModule {
  module_ : @gpu.GPUShaderModule
  entry_point : String
}

///|
/// `WebGPUBackend`, the payload of its `@nodes.Backend`.
pub(all) struct WebGPUBackend {
  /// The base `Backend` (upstream's `this`).
  mut base_ : @nodes.Backend?
  /// `compatibilityMode`; `None` is `null` (before `init()`).
  mut compatibility_mode : Bool?
  /// `device`; `None` is `null`.
  mut device : @gpu.GPUDevice?
  utils : WebGPUUtils
  attribute_utils : WebGPUAttributeUtils
  binding_utils : WebGPUBindingUtils
  capabilities : WebGPUCapabilities
  pipeline_utils : WebGPUPipelineUtils
  texture_utils : WebGPUTextureUtils
  /// `occludedResolveCache`.
  occluded_resolve_cache : Map[Int32, @gpu.GPUBuffer]
  /// `_compatibility`.
  _compatibility : Map[String, Bool]
}

///|
/// `new WebGPUBackend( parameters = {} )`: the base backend whose class is a new
/// `WebGPUBackend`.
pub fn WebGPUBackend::new(parameters? : @core.JsValue) -> @nodes.Backend {
  let parameters = match parameters {
    Some(p) => p
    None => @core.JsValue::object()
  }
  let payload : WebGPUBackend = {
    base_: None,
    compatibility_mode: None,
    device: None,
    utils: WebGPUUtils::new(),
    attribute_utils: WebGPUAttributeUtils::new(),
    binding_utils: WebGPUBindingUtils::new(),
    capabilities: WebGPUCapabilities::new(),
    pipeline_utils: WebGPUPipelineUtils::new(),
    texture_utils: WebGPUTextureUtils::new(),
    occluded_resolve_cache: Map([]),
    _compatibility: Map([]),
  }
  let backend = @nodes.Backend::new(payload, parameters~)
  payload.base_ = Some(backend)
  // some parameters require default values other than "undefined"
  let alpha = parameters.get("alpha")
  backend.parameters.set(
    "alpha",
    if alpha.is_undefined() {
      @core.JsValue::of(true)
    } else {
      alpha
    },
  )
  let required_limits = parameters.get("requiredLimits")
  backend.parameters.set(
    "requiredLimits",
    if required_limits.is_undefined() {
      @core.JsValue::object()
    } else {
      required_limits
    },
  )
  payload.utils.backend_ = Some(payload)
  payload.attribute_utils.backend_ = Some(payload)
  payload.binding_utils.backend_ = Some(payload)
  payload.capabilities.backend_ = Some(payload)
  payload.pipeline_utils.backend_ = Some(payload)
  payload.texture_utils.backend_ = Some(payload)
  // compatibility checks
  let compatibility_texture_compare = wgpu_compatibility_texture_compare()
  payload._compatibility[@core.Compatibility_TEXTURE_COMPARE] = compatibility_texture_compare
  backend
}

///|
/// The `WebGPUBackend` of a backend built by `WebGPUBackend::new`.
pub fn WebGPUBackend::of(backend : @nodes.Backend) -> WebGPUBackend? {
  if backend.has_flag("isWebGPUBackend") {
    Some(backend.class_.payload().cast())
  } else {
    None
  }
}

///|
/// The base `Backend`.
pub fn WebGPUBackend::base(self : WebGPUBackend) -> @nodes.Backend {
  self.base_.unwrap()
}

///|
/// `this.renderer`.
pub fn WebGPUBackend::renderer(self : WebGPUBackend) -> @nodes.Renderer {
  self.base().renderer.unwrap()
}

///|
/// `this.device` (after `init()`).
pub fn WebGPUBackend::gpu_device(self : WebGPUBackend) -> @gpu.GPUDevice {
  match self.device {
    Some(d) => d
    None => abort("TypeError: Cannot read properties of null (device)")
  }
}

///|
/// `this.get( object )`.
pub fn WebGPUBackend::get(
  self : WebGPUBackend,
  object : @core.JsValue,
) -> @core.JsValue {
  self.base().get(object)
}

///|
/// `this.delete( object )`.
pub fn WebGPUBackend::delete(
  self : WebGPUBackend,
  object : @core.JsValue,
) -> Unit {
  self.base().delete(object)
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn class_name(_) {
  "WebGPUBackend"
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn has_flag(_, flag) {
  flag == "isWebGPUBackend"
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn init(
  self,
  backend,
  renderer,
  on_done,
) {
  // super.init( renderer )
  backend.renderer = Some(renderer)
  //
  let parameters = backend.parameters
  // create the device if it is not passed with parameters
  let finish = fn(device : @gpu.GPUDevice) {
    let compatibility_mode = !device.features().has("core-features-and-limits")
    self.compatibility_mode = Some(compatibility_mode)
    if compatibility_mode {
      renderer._samples = 0
    }
    device.lost(fn(info) {
      if info.reason() == "destroyed" {
        return
      }
      let device_loss_info = wgpu_device_loss_info(info)
      (renderer.on_device_lost)(device_loss_info)
    })
    device.set_onuncapturederror(fn(event) {
      (renderer.on_error)(wgpu_uncaptured_error_info(event))
    })
    self.device = Some(device)
    backend.track_timestamp = backend.track_timestamp &&
      self.has_feature_(GPUFeatureName_TimestampQuery)
    self.update_size_()
    on_done(None)
  }
  let on_error = fn(e : @core.JsValue) { on_done(Some(wgpu_error_string(e))) }
  let device_parameter = parameters.get("device")
  if device_parameter.is_undefined() {
    let power_preference : String? = wgpu_opt(parameters, "powerPreference")
    let adapter_options = @gpu.GPURequestAdapterOptions::new(
      power_preference?,
      feature_level="compatibility",
      xr_compatible=renderer.xr.enabled,
    )
    let gpu = match @gpu.gpu() {
      Some(g) => g
      None =>
        return on_done(
          Some(
            "TypeError: Cannot read properties of undefined (reading 'requestAdapter')",
          ),
        )
    }
    wgpu_await(
      gpu.request_adapter_promise(options=adapter_options),
      fn(adapter_value) {
        if adapter_value.is_null() || adapter_value.is_undefined() {
          return on_done(
            Some("THREE.WebGPUBackend: Unable to create WebGPU adapter."),
          )
        }
        let adapter : @gpu.GPUAdapter = adapter_value.cast()
        // feature support
        let supported_features = []
        for name in gpu_feature_names {
          if adapter.features().has(name) {
            supported_features.push(name)
          }
        }
        let device_descriptor = @gpu.GPUDeviceDescriptor::new(
          required_features=supported_features,
          required_limits=parameters.get("requiredLimits"),
        )
        wgpu_await(
          adapter.request_device_promise(descriptor=device_descriptor),
          fn(device) { finish(device.cast()) },
          on_error,
        )
      },
      on_error,
    )
  } else {
    finish(device_parameter.cast())
  }
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn set_xr_render_target_textures(
  self,
  _backend,
  render_target,
  color_texture,
  view_descriptors,
) {
  // Update the external XR texture without replacing the cached MSAA attachments.
  let texture_data = self.get(@core.JsValue::of(render_target.texture()))
  let color_texture_gpu : @gpu.GPUTexture = color_texture.cast()
  texture_data.set("texture", color_texture)
  texture_data.set("format", @core.JsValue::of(color_texture_gpu.format()))
  texture_data.set("externalTexture", @core.JsValue::of(true))
  texture_data.set(
    "xrViewDescriptors",
    if view_descriptors.is_undefined() {
      @core.JsValue::null()
    } else {
      view_descriptors
    },
  )
  texture_data.set("initialized", @core.JsValue::of(true))
}

///|
/// `get context()`: the canvas context of the current canvas target, configured on
/// first use.
pub fn WebGPUBackend::context(self : WebGPUBackend) -> @gpu.GPUCanvasContext {
  let canvas_target = self.renderer().get_canvas_target()
  let canvas_data = self.get(@core.JsValue::of(canvas_target))
  match wgpu_opt(canvas_data, "context") {
    Some(context) => context
    None => {
      let parameters = self.base().parameters
      let parameters_context = parameters.get("context")
      let context : @gpu.GPUCanvasContext = if canvas_target.is_default_canvas_target ==
        true &&
        !parameters_context.is_undefined() {
        parameters_context.cast()
      } else {
        match @gpu.get_webgpu_context(canvas_target.dom_element) {
          Some(c) => c
          None =>
            abort(
              "TypeError: Cannot read properties of null (reading 'configure')",
            )
        }
      }
      // OffscreenCanvas does not have setAttribute, see #22811
      wgpu_set_data_engine(
        canvas_target.dom_element,
        "three.js r\{@core.REVISION} webgpu",
      )
      let alpha_mode = if wgpu_truthy(parameters.get("alpha")) {
        "premultiplied"
      } else {
        "opaque"
      }
      let tone_mapping_mode = if parameters
        .get("outputType")
        .strict_equal(@core.JsValue::of(@core.HalfFloatType)) {
        "extended"
      } else {
        "standard"
      }
      let device = self.device
      let format = self.utils.get_preferred_canvas_format()
      context.configure(
        @gpu.GPUCanvasConfiguration::new(
          device=match device {
            Some(d) => d
            None => @core.JsValue::null().cast()
          },
          format~,
          usage=@gpu.GPU_TEXTURE_USAGE_RENDER_ATTACHMENT |
            @gpu.GPU_TEXTURE_USAGE_COPY_SRC,
          alpha_mode~,
          tone_mapping=@gpu.GPUCanvasToneMapping::new(mode=tone_mapping_mode),
        ),
      )
      canvas_data.set("context", @core.JsValue::of(context))
      context
    }
  }
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn coordinate_system(_, _) {
  @core.WebGPUCoordinateSystem
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn has_timestamp(_, _) {
  true
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn get_array_buffer_async(
  self,
  _backend,
  attribute,
  target,
  offset,
  count,
  on_done,
) {
  self.attribute_utils.get_array_buffer_async(
    attribute, target, offset, count, on_done,
  )
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn get_context(self, _) {
  @core.JsValue::of(self.context())
}

///|
/// `_getDefaultRenderPassDescriptor()`.
fn WebGPUBackend::_get_default_render_pass_descriptor(
  self : WebGPUBackend,
) -> @gpu.GPURenderPassDescriptor {
  let renderer = self.renderer()
  let canvas_target = renderer.get_canvas_target()
  let canvas_data = self.get(@core.JsValue::of(canvas_target))
  let samples = renderer.current_samples()
  let mut descriptor : @gpu.GPURenderPassDescriptor? = wgpu_opt(
    canvas_data, "descriptor",
  )
  if descriptor is None ||
    !canvas_data.get("samples").strict_equal(@core.JsValue::of(samples)) {
    let d = @gpu.GPURenderPassDescriptor::default()
    d.color_attachments.push(@gpu.GPURenderPassColorAttachment::default())
    if renderer.depth == true || renderer.stencil == true {
      let depth_stencil_attachment = @gpu.GPURenderPassDepthStencilAttachment::default()
      depth_stencil_attachment.view = Some(
        self.texture_utils
        .get_depth_buffer(depth=renderer.depth, stencil=renderer.stencil)
        .create_view(),
      )
      d.depth_stencil_attachment = Some(depth_stencil_attachment)
    }
    let color_attachment = d.color_attachments[0]
    if samples > 0 {
      color_attachment.view = Some(
        self.texture_utils.get_color_buffer().create_view(),
      )
    } else {
      color_attachment.resolve_target = None
    }
    canvas_data.set("descriptor", @core.JsValue::of(d))
    canvas_data.set("samples", @core.JsValue::of(samples))
    descriptor = Some(d)
  }
  let descriptor = descriptor.unwrap()
  let color_attachment = descriptor.color_attachments[0]
  if samples > 0 {
    color_attachment.resolve_target = Some(
      self.context().get_current_texture().create_view(),
    )
  } else {
    color_attachment.view = Some(
      self.context().get_current_texture().create_view(),
    )
  }
  descriptor
}

///|
/// The sub-cameras of an array camera.
fn wgpu_array_cameras(camera : @core.Object3D?) -> Array[@core.Object3D] {
  match camera {
    Some(c) => @nodes.camera_sub_cameras(c)
    None => []
  }
}

///|
/// `_isRenderCameraDepthArray( renderContext )`.
fn WebGPUBackend::_is_render_camera_depth_array(
  self : WebGPUBackend,
  render_context : @nodes.RenderContext,
) -> Bool {
  ignore(self)
  match (render_context.depth_texture, render_context.camera) {
    (Some(depth_texture), Some(camera)) =>
      depth_texture.is_array_texture == true && camera.is_array_camera() == true
    _ => false
  }
}

///|
/// `_hasExternalTexture( renderContext )`.
fn WebGPUBackend::_has_external_texture(
  self : WebGPUBackend,
  render_context : @nodes.RenderContext,
) -> Bool {
  match render_context.textures {
    None => false
    Some(textures) => {
      for texture in textures {
        if self
          .get(@core.JsValue::of(texture))
          .get("externalTexture")
          .strict_equal(@core.JsValue::of(true)) {
          return true
        }
      }
      false
    }
  }
}

///|
/// `textureData.msaaTextures` (`None` is `undefined`).
fn wgpu_msaa_textures(texture_data : @core.JsValue) -> Array[@gpu.GPUTexture]? {
  wgpu_opt(texture_data, "msaaTextures")
}

///|
/// `_getExternalMSAATextures( renderContext, textureData, count )`.
fn WebGPUBackend::_get_external_msaa_textures(
  self : WebGPUBackend,
  render_context : @nodes.RenderContext,
  texture_data : @core.JsValue,
  count : Int32,
) -> Array[@gpu.GPUTexture]? {
  let samples = self.utils.get_sample_count(render_context.sample_count)
  if samples == 1 {
    match wgpu_msaa_textures(texture_data) {
      Some(msaa_textures) => {
        for texture in msaa_textures {
          texture.destroy()
        }
        texture_data.set("msaaTextures", @core.JsValue::undefined())
      }
      None => ()
    }
    return None
  }
  let render_target = render_context.render_target.unwrap()
  let width = render_target.width
  let height = render_target.height
  let format : String? = wgpu_opt(texture_data, "format")
  let msaa_textures = wgpu_msaa_textures(texture_data)
  let changed = match msaa_textures {
    None => true
    Some(m) =>
      m.length() != count ||
      !texture_data.get("msaaWidth").strict_equal(@core.JsValue::of(width)) ||
      !texture_data.get("msaaHeight").strict_equal(@core.JsValue::of(height)) ||
      !texture_data.get("msaaSamples").strict_equal(@core.JsValue::of(samples)) ||
      !texture_data
      .get("msaaFormat")
      .strict_equal(
        match format {
          Some(f) => @core.JsValue::of(f)
          None => @core.JsValue::undefined()
        },
      )
  }
  if changed {
    match msaa_textures {
      Some(m) =>
        for texture in m {
          texture.destroy()
        }
      None => ()
    }
    let td = _web_gpu_backend_texture_descriptor
    td.size.width = width
    td.size.height = Some(height)
    td.sample_count = Some(samples)
    td.format = format
    // Layered rendering can resume after a framebuffer copy,
    // so these attachments must support loading.
    td.usage = Some(@gpu.GPU_TEXTURE_USAGE_RENDER_ATTACHMENT)
    let created = []
    for i = 0; i < count; i = i + 1 {
      td.label = Some(render_target.texture().name + "-msaa-" + i.to_string())
      created.push(self.gpu_device().create_texture(td))
    }
    texture_data.set("msaaTextures", @core.JsValue::of(created))
    td.reset()
    texture_data.set("msaaWidth", @core.JsValue::of(width))
    texture_data.set("msaaHeight", @core.JsValue::of(height))
    texture_data.set("msaaSamples", @core.JsValue::of(samples))
    wgpu_set_opt(texture_data, "msaaFormat", format)
  }
  wgpu_msaa_textures(texture_data)
}

///|
extern "js" fn wgpu_array_length(a : @core.JsValue) -> Int32 = "(a) => a.length"

///|
extern "js" fn wgpu_array_get(a : @core.JsValue, i : Int32) -> @core.JsValue = "(a, i) => a[i]"

///|
/// `_createExternalTextureViews( renderContext, textureData )`.
fn WebGPUBackend::_create_external_texture_views(
  self : WebGPUBackend,
  render_context : @nodes.RenderContext,
  texture_data : @core.JsValue,
) -> Array[WebGPUTextureViewInfo] {
  let texture_views = []
  let camera = render_context.camera
  let view_descriptors = texture_data.get("xrViewDescriptors")
  let has_view_descriptors = wgpu_truthy(view_descriptors)
  let view_descriptors_length = if has_view_descriptors {
    wgpu_array_length(view_descriptors)
  } else {
    0
  }
  let mut view_count = view_descriptors_length
  if render_context.active_cube_face + 1 > view_count {
    view_count = render_context.active_cube_face + 1
  }
  if 1 > view_count {
    view_count = 1
  }
  let msaa_textures = self._get_external_msaa_textures(
    render_context, texture_data, view_count,
  )
  let texture_gpu : @gpu.GPUTexture = texture_data.get("texture").cast()
  let resolve_color_buffer = match render_context.render_target {
    Some(rt) => rt.resolve_color_buffer == true
    None => false
  }
  let is_array_camera = match camera {
    Some(c) => c.is_array_camera() == true
    None => false
  }
  if has_view_descriptors && is_array_camera {
    for i = 0; i < view_descriptors_length; i = i + 1 {
      let texture_view = texture_gpu.create_view_js(
        wgpu_array_get(view_descriptors, i),
      )
      texture_views.push({
        view: match msaa_textures {
          Some(m) => m[i].create_view()
          None => texture_view
        },
        resolve_target: if msaa_textures is Some(_) && resolve_color_buffer {
          Some(texture_view)
        } else {
          None
        },
        depth_slice: None,
      })
    }
  } else {
    let layer = render_context.active_cube_face
    let texture_view = texture_gpu.create_view(
      descriptor=@gpu.GPUTextureViewDescriptor::new(
        dimension=GPUTextureViewDimension_TwoD,
        base_array_layer=layer,
        array_layer_count=1,
      ),
    )
    texture_views.push({
      view: match msaa_textures {
        Some(m) => m[layer].create_view()
        None => texture_view
      },
      resolve_target: if msaa_textures is Some(_) && resolve_color_buffer {
        Some(texture_view)
      } else {
        None
      },
      depth_slice: None,
    })
  }
  texture_views
}

///|
/// `renderTargetData.descriptors`.
priv struct WebGPURenderTargetDescriptors {
  map : Map[String, WebGPUDescriptorBase]
}

///|
/// `_getRenderPassDescriptor( renderContext, colorAttachmentsConfig = {} )`.
fn WebGPUBackend::_get_render_pass_descriptor(
  self : WebGPUBackend,
  render_context : @nodes.RenderContext,
  color_attachments_config : WebGPUColorAttachmentsConfig,
) -> @gpu.GPURenderPassDescriptor {
  let render_target = render_context.render_target.unwrap()
  let render_target_data = self.get(@core.JsValue::of(render_target))
  let has_external_texture = self._has_external_texture(render_context)
  let mut descriptors : WebGPURenderTargetDescriptors? = wgpu_opt(
    render_target_data, "descriptors",
  )
  if descriptors is None ||
    !render_target_data
    .get("width")
    .strict_equal(@core.JsValue::of(render_target.width)) ||
    !render_target_data
    .get("height")
    .strict_equal(@core.JsValue::of(render_target.height)) ||
    !render_target_data
    .get("samples")
    .strict_equal(@core.JsValue::of(render_target.samples)) ||
    has_external_texture {
    let d = { map: Map([]), }
    render_target_data.set("descriptors", @core.JsValue::of(d))
    descriptors = Some(d)
  }
  let descriptors = descriptors.unwrap()
  let cache_key = wgpu_number_string(render_context.get_cache_key())
  let mut descriptor_base = descriptors.map.get(cache_key)
  if descriptor_base is None || has_external_texture {
    let textures = render_context.textures.unwrap()
    let texture_views : Array[WebGPUTextureViewInfo] = []
    let mut slice_index : Int32? = None
    let is_render_camera_depth_array = self._is_render_camera_depth_array(
      render_context,
    )
    let vd = _web_gpu_backend_view_descriptor
    for i = 0; i < textures.length(); i = i + 1 {
      let texture_data = self.get(@core.JsValue::of(textures[i]))
      if texture_data
        .get("externalTexture")
        .strict_equal(@core.JsValue::of(true)) {
        for
          v in self._create_external_texture_views(render_context, texture_data) {
          texture_views.push(v)
        }
        continue
      }
      let texture_gpu : @gpu.GPUTexture = texture_data.get("texture").cast()
      vd.label = Some("colorAttachment_\{i}")
      vd.base_mip_level = Some(render_context.active_mipmap_level)
      vd.mip_level_count = Some(1)
      vd.base_array_layer = Some(render_context.active_cube_face)
      vd.array_layer_count = Some(1)
      vd.dimension = Some(GPUTextureViewDimension_TwoD)
      if render_target.render_target_type is RenderTarget3D {
        slice_index = Some(render_context.active_cube_face)
        vd.base_array_layer = Some(0)
        vd.dimension = Some(GPUTextureViewDimension_ThreeD)
      } else if textures[i].image().depth() > 1.0 {
        if is_render_camera_depth_array == true {
          let cameras = wgpu_array_cameras(render_context.camera)
          for layer = 0; layer < cameras.length(); layer = layer + 1 {
            vd.base_array_layer = Some(layer)
            vd.array_layer_count = Some(1)
            vd.dimension = Some(GPUTextureViewDimension_TwoD)
            let texture_view = texture_gpu.create_view(descriptor=vd)
            let msaa_texture = match wgpu_msaa_textures(texture_data) {
              Some(m) => if layer < m.length() { Some(m[layer]) } else { None }
              None => None
            }
            texture_views.push({
              view: match msaa_texture {
                Some(m) => m.create_view()
                None => texture_view
              },
              resolve_target: if msaa_texture is Some(_) &&
                render_target.resolve_color_buffer == true {
                Some(texture_view)
              } else {
                None
              },
              depth_slice: None,
            })
          }
        } else {
          vd.dimension = Some(GPUTextureViewDimension_TwoDArray)
        }
      }
      if is_render_camera_depth_array != true {
        let texture_view = texture_gpu.create_view(descriptor=vd)
        let msaa_texture : @gpu.GPUTexture? = wgpu_opt(
          texture_data, "msaaTexture",
        )
        let (view, resolve_target) = match msaa_texture {
          Some(m) =>
            (
              m.create_view(),
              if render_target.resolve_color_buffer == true {
                Some(texture_view)
              } else {
                None
              },
            )
          None =>
            match wgpu_msaa_textures(texture_data) {
              Some(m) =>
                (
                  m[render_context.active_cube_face].create_view(),
                  if render_target.resolve_color_buffer == true {
                    Some(texture_view)
                  } else {
                    None
                  },
                )
              None => (texture_view, None)
            }
        }
        texture_views.push({ view, resolve_target, depth_slice: slice_index, })
      }
      vd.reset()
    }
    let color_attachments = []
    for view_info in texture_views {
      let attachment = @gpu.GPURenderPassColorAttachment::default()
      attachment.view = Some(view_info.view)
      attachment.depth_slice = view_info.depth_slice
      attachment.resolve_target = view_info.resolve_target
      color_attachments.push(attachment)
    }
    let base = {
      texture_views,
      color_attachments,
      descriptor: @gpu.GPURenderPassDescriptor::default(),
      depth_stencil_attachment: None,
    }
    if render_context.depth {
      let depth_texture = render_context.depth_texture.unwrap()
      let depth_texture_data = self.get(@core.JsValue::of(depth_texture))
      if depth_texture.is_array_texture || depth_texture.is_cube_texture() {
        vd.dimension = Some(GPUTextureViewDimension_TwoD)
        vd.array_layer_count = Some(1)
        vd.base_array_layer = Some(render_context.active_cube_face)
      }
      let depth_stencil_attachment = @gpu.GPURenderPassDepthStencilAttachment::default()
      let msaa_depth_texture = match wgpu_msaa_textures(depth_texture_data) {
        Some(m) =>
          if render_context.active_cube_face < m.length() {
            Some(m[render_context.active_cube_face])
          } else {
            None
          }
        None => None
      }
      depth_stencil_attachment.view = Some(
        match msaa_depth_texture {
          Some(m) => m.create_view()
          None => {
            let t : @gpu.GPUTexture = depth_texture_data.get("texture").cast()
            t.create_view(descriptor=vd)
          }
        },
      )
      base.depth_stencil_attachment = Some(depth_stencil_attachment)
      vd.reset()
    }
    descriptors.map[cache_key] = base
    render_target_data.set("width", @core.JsValue::of(render_target.width))
    render_target_data.set("height", @core.JsValue::of(render_target.height))
    render_target_data.set("samples", @core.JsValue::of(render_target.samples))
    render_target_data.set(
      "activeMipmapLevel",
      @core.JsValue::of(render_context.active_mipmap_level),
    )
    render_target_data.set(
      "activeCubeFace",
      @core.JsValue::of(render_context.active_cube_face),
    )
    descriptor_base = Some(base)
  }
  let descriptor_base = descriptor_base.unwrap()
  let descriptor = descriptor_base.descriptor
  descriptor.reset()
  // Apply dynamic properties to cached attachments
  for i = 0; i < descriptor_base.color_attachments.length(); i = i + 1 {
    let attachment = descriptor_base.color_attachments[i]
    let mut clear_value = @gpu.GPUColor::new(r=0.0, g=0.0, b=0.0, a=1.0)
    if i == 0 {
      match color_attachments_config.clear_value {
        Some(c) => clear_value = c
        None => ()
      }
    }
    attachment.load_op = Some(
      color_attachments_config.load_op.unwrap_or(GPULoadOp_Load),
    )
    attachment.store_op = Some(
      color_attachments_config.store_op.unwrap_or(GPUStoreOp_Store),
    )
    attachment.clear_value = Some(clear_value)
    descriptor.color_attachments.push(attachment)
  }
  match descriptor_base.depth_stencil_attachment {
    Some(d) => descriptor.depth_stencil_attachment = Some(d)
    None => ()
  }
  descriptor
}

///|
/// `renderContextData`: the record of a render context.
fn WebGPUBackend::render_context_data(
  self : WebGPUBackend,
  render_context : @nodes.RenderContext,
) -> @core.JsValue {
  self.get(@core.JsValue::of(render_context))
}

///|
fn wgpu_current_pass(data : @core.JsValue) -> WebGPUPassEncoder? {
  wgpu_opt(data, "currentPass")
}

///|
fn wgpu_set_current_pass(
  data : @core.JsValue,
  pass : WebGPUPassEncoder?,
) -> Unit {
  match pass {
    Some(p) => data.set("currentPass", @core.JsValue::of(p))
    None => data.set("currentPass", @core.JsValue::null())
  }
}

///|
fn wgpu_current_sets(data : @core.JsValue) -> WebGPUCurrentSets {
  data.get("currentSets").cast()
}

///|
/// The GPU color of `renderContext.clearColorValue`, one object per render context as
/// upstream assigns the context's object to the attachment.
let _web_gpu_backend_clear_color_values : @webgl.WeakMap[
  @nodes.RenderContext,
  @gpu.GPUColor,
] = @webgl.WeakMap::new()

///|
fn wgpu_clear_color_value(
  render_context : @nodes.RenderContext,
) -> @gpu.GPUColor {
  let c = render_context.clear_color_value
  match _web_gpu_backend_clear_color_values.get(render_context) {
    Some(color) => {
      color.r = c.r
      color.g = c.g
      color.b = c.b
      color.a = c.a
      color
    }
    None => {
      let color = @gpu.GPUColor::new(r=c.r, g=c.g, b=c.b, a=c.a)
      _web_gpu_backend_clear_color_values.set(render_context, color)
      color
    }
  }
}

///|
/// `mrt.getClearColor( name )` as a GPU color; `None` is `null`.
fn wgpu_mrt_clear_color(mrt : @nodes.Node?, name : String) -> @gpu.GPUColor? {
  match mrt {
    None => None
    Some(node) =>
      match @nodes.MRTNode::of(node).unwrap().get_clear_color(name) {
        Some(c) =>
          Some(@gpu.GPUColor::new(r=c.color.r, g=c.color.g, b=c.color.b, a=c.a))
        None => None
      }
  }
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn begin_render(
  self,
  backend,
  render_context,
) {
  let render_context_data = self.render_context_data(render_context)
  //
  let device = self.gpu_device()
  let occlusion_query_count = render_context.occlusion_query_count
  let occlusion_data = backend.get_occlusion_data(render_context)
  let mut occlusion_query_set : @gpu.GPUQuerySet? = None
  if occlusion_query_count > 0 {
    let current_set = occlusion_data.get("currentOcclusionQuerySet")
    if wgpu_truthy(current_set) {
      let s : @gpu.GPUQuerySet = current_set.cast()
      s.destroy()
    }
    let current_buffer = occlusion_data.get("currentOcclusionQueryBuffer")
    if wgpu_truthy(current_buffer) {
      let b : @gpu.GPUBuffer = current_buffer.cast()
      b.destroy()
    }
    // Get a reference to the array of objects with queries. The occlusionData property
    // can be changed by another render pass before the buffer.mapAsyc() completes.
    occlusion_data.set(
      "currentOcclusionQuerySet",
      occlusion_data.get("occlusionQuerySet"),
    )
    occlusion_data.set(
      "currentOcclusionQueryBuffer",
      occlusion_data.get("occlusionQueryBuffer"),
    )
    occlusion_data.set(
      "currentOcclusionQueryObjects",
      occlusion_data.get("occlusionQueryObjects"),
    )
    //
    let qsd = _web_gpu_backend_query_set_descriptor
    qsd.label = Some("occlusionQuerySet_\{render_context.id}")
    qsd.type_ = Some("occlusion")
    qsd.count = occlusion_query_count
    let query_set = device.create_query_set(qsd)
    occlusion_query_set = Some(query_set)
    qsd.reset()
    occlusion_data.set("occlusionQuerySet", @core.JsValue::of(query_set))
    occlusion_data.set("occlusionQueryIndex", @core.JsValue::of(0))
    let objects : Array[@core.Object3D?] = Array::make(
      occlusion_query_count,
      None,
    )
    occlusion_data.set("occlusionQueryObjects", @core.JsValue::of(objects))
    occlusion_data.set("lastOcclusionObject", @core.JsValue::null())
  } else if !occlusion_data.get("lastOcclusionObject").is_undefined() {
    // invalidate if there is a stale query
    occlusion_data.set("lastOcclusionObject", @core.JsValue::undefined())
    let s : @gpu.GPUQuerySet = occlusion_data.get("occlusionQuerySet").cast()
    s.destroy()
    occlusion_data.set("occlusionQuerySet", @core.JsValue::undefined())
  }
  let descriptor = if render_context.textures is None {
    self._get_default_render_pass_descriptor()
  } else {
    self._get_render_pass_descriptor(render_context, {
      load_op: Some(GPULoadOp_Load),
      store_op: None,
      clear_value: None,
    })
  }
  self.init_timestamp_query(
    @core.TimestampQuery_RENDER,
    backend.get_timestamp_uid(@core.JsValue::of(render_context)),
    fn(t) { descriptor.timestamp_writes = t },
  )
  descriptor.occlusion_query_set = occlusion_query_set
  let depth_stencil_attachment = descriptor.depth_stencil_attachment
  let render_target = render_context.render_target
  let multisampled = render_context.sample_count > 1
  let discard_color = multisampled &&
    (match render_target {
      Some(rt) => rt.store_multisampled_color_buffer == false
      None => false
    })
  let discard_depth = multisampled &&
    (match render_target {
      Some(rt) => rt.store_multisampled_depth_buffer == false
      None => false
    })
  let discard_stencil = multisampled &&
    (match render_target {
      Some(rt) => rt.store_multisampled_stencil_buffer == false
      None => false
    })
  // A fullscreen pass overwrites the external texture, so its previous contents do not need to be loaded.
  let clear_external_color = render_context.fullscreen_pass == true &&
    self._has_external_texture(render_context)
  match render_context.textures {
    Some(textures) => {
      let color_attachments = descriptor.color_attachments
      for i = 0; i < color_attachments.length(); i = i + 1 {
        let color_attachment = color_attachments[i]
        if render_context.clear_color || discard_color || clear_external_color {
          let clear_color = if render_context.mrt is Some(_) {
            wgpu_mrt_clear_color(render_context.mrt, textures[i].name)
          } else {
            None
          }
          match clear_color {
            Some(c) => color_attachment.clear_value = Some(c)
            None =>
              if i == 0 {
                color_attachment.clear_value = Some(
                  wgpu_clear_color_value(render_context),
                )
              } else {
                _web_gpu_backend_clear_value.r = 0.0
                _web_gpu_backend_clear_value.g = 0.0
                _web_gpu_backend_clear_value.b = 0.0
                _web_gpu_backend_clear_value.a = 1.0
                color_attachment.clear_value = Some(
                  _web_gpu_backend_clear_value,
                )
              }
          }
          color_attachment.load_op = Some(GPULoadOp_Clear)
        } else {
          color_attachment.load_op = Some(GPULoadOp_Load)
        }
        if discard_color {
          color_attachment.store_op = Some(GPUStoreOp_Discard)
        } else {
          color_attachment.store_op = Some(GPUStoreOp_Store)
        }
      }
    }
    None => {
      let color_attachment = descriptor.color_attachments[0]
      if render_context.clear_color {
        color_attachment.clear_value = Some(
          wgpu_clear_color_value(render_context),
        )
        color_attachment.load_op = Some(GPULoadOp_Clear)
      } else {
        color_attachment.load_op = Some(GPULoadOp_Load)
      }
      color_attachment.store_op = Some(GPUStoreOp_Store)
    }
  }
  //
  if render_context.depth {
    let dsa = depth_stencil_attachment.unwrap()
    if render_context.clear_depth || discard_depth {
      dsa.depth_clear_value = Some(render_context.clear_depth_value)
      dsa.depth_load_op = Some(GPULoadOp_Clear)
    } else {
      dsa.depth_load_op = Some(GPULoadOp_Load)
    }
    if discard_depth {
      dsa.depth_store_op = Some(GPUStoreOp_Discard)
    } else {
      dsa.depth_store_op = Some(GPUStoreOp_Store)
    }
  }
  if render_context.stencil {
    let dsa = depth_stencil_attachment.unwrap()
    if render_context.clear_stencil || discard_stencil {
      dsa.stencil_clear_value = Some(render_context.clear_stencil_value)
      dsa.stencil_load_op = Some(GPULoadOp_Clear)
    } else {
      dsa.stencil_load_op = Some(GPULoadOp_Load)
    }
    if discard_stencil {
      dsa.stencil_store_op = Some(GPUStoreOp_Discard)
    } else {
      dsa.stencil_store_op = Some(GPUStoreOp_Store)
    }
  }
  //
  let ced = _web_gpu_backend_command_encoder_descriptor
  ced.label = Some("renderContext_" + render_context.id.to_string())
  let encoder = device.create_command_encoder(descriptor=ced)
  ced.reset()
  // Layered render targets: prepare bundle encoders for each camera in the array camera.
  if self._is_render_camera_depth_array(render_context) == true {
    let cameras = wgpu_array_cameras(render_context.camera)
    // The layer descriptors hold views of the depth texture, which can be recreated (dispose, resize)
    // or belong to another render target, since render contexts are shared by attachment state.
    let depth_texture_gpu = self
      .get(@core.JsValue::of(render_context.depth_texture.unwrap()))
      .get("texture")
    let layer_descriptors : Array[@gpu.GPURenderPassDescriptor]? = wgpu_opt(
      render_context_data, "layerDescriptors",
    )
    let stale = match layer_descriptors {
      None => true
      Some(l) =>
        l.length() != cameras.length() ||
        !render_context_data
        .get("layerDepthTexture")
        .strict_equal(depth_texture_gpu)
    }
    if stale {
      self._create_array_camera_layer_descriptors(
        render_context, render_context_data, descriptor, cameras,
      )
      render_context_data.set("layerDepthTexture", depth_texture_gpu)
    } else {
      self._update_array_camera_layer_descriptors(
        render_context, render_context_data, descriptor, cameras,
      )
    }
    self._create_array_camera_bundle_encoders(
      render_context, render_context_data,
    )
    let stages : Array[WebGPURenderStage] = []
    render_context_data.set(
      "arrayCameraRenderStages",
      @core.JsValue::of(stages),
    )
    // We'll complete the bundles in finishRender
    wgpu_set_current_pass(render_context_data, None)
  } else {
    render_context_data.set("bundleEncoders", @core.JsValue::undefined())
    render_context_data.set("bundleSets", @core.JsValue::undefined())
    render_context_data.set(
      "arrayCameraRenderStages",
      @core.JsValue::undefined(),
    )
    let current_pass = encoder.begin_render_pass(descriptor)
    wgpu_set_current_pass(render_context_data, Some(Pass(current_pass)))
    if render_context.viewport {
      self.update_viewport_(render_context)
    }
    if render_context.scissor {
      self.update_scissor(render_context)
    }
  }
  //
  render_context_data.set("descriptor", @core.JsValue::of(descriptor))
  render_context_data.set("encoder", @core.JsValue::of(encoder))
  let render_bundles : Array[@gpu.GPURenderBundle] = []
  render_context_data.set("renderBundles", @core.JsValue::of(render_bundles))
  self._reset_render_context_data(render_context_data)
}

///|
/// `_resetRenderContextData( renderContextData )`.
fn WebGPUBackend::_reset_render_context_data(
  self : WebGPUBackend,
  render_context_data : @core.JsValue,
) -> Unit {
  ignore(self)
  render_context_data.set(
    "currentSets",
    @core.JsValue::of(WebGPUCurrentSets::new()),
  )
  if render_context_data.get("currentBlendColor").is_undefined() {
    render_context_data.set(
      "currentBlendColor",
      @core.JsValue::of(@math.Color::new(0.0, 0.0, 0.0)),
    )
  }
  let color : @math.Color = render_context_data.get("currentBlendColor").cast()
  color.set_rgb(0.0, 0.0, 0.0) |> ignore
  render_context_data.set("currentBlendAlpha", @core.JsValue::of(0.0))
  render_context_data.set("currentStencilRef", @core.JsValue::of(0))
}

///|
fn wgpu_bundle_encoders(
  data : @core.JsValue,
) -> Array[@gpu.GPURenderBundleEncoder]? {
  wgpu_opt(data, "bundleEncoders")
}

///|
/// `_createArrayCameraBundleEncoders( renderContext, renderContextData )`.
fn WebGPUBackend::_create_array_camera_bundle_encoders(
  self : WebGPUBackend,
  render_context : @nodes.RenderContext,
  render_context_data : @core.JsValue,
) -> Unit {
  let cameras = wgpu_array_cameras(render_context.camera)
  let bundle_encoders = []
  let bundle_sets = []
  render_context_data.set("bundleEncoders", @core.JsValue::of(bundle_encoders))
  render_context_data.set("bundleSets", @core.JsValue::of(bundle_sets))
  for i = 0; i < cameras.length(); i = i + 1 {
    let bundle_encoder = self.pipeline_utils.create_bundle_encoder(
      render_context,
      label="renderBundleArrayCamera_" + i.to_string(),
    )
    bundle_encoders.push(bundle_encoder)
    bundle_sets.push(WebGPUCurrentSets::new())
  }
}

///|
/// `_finishArrayCameraBundleEncoders( renderContextData )`.
fn WebGPUBackend::_finish_array_camera_bundle_encoders(
  self : WebGPUBackend,
  render_context_data : @core.JsValue,
) -> Array[@gpu.GPURenderBundle] {
  ignore(self)
  let bundles = []
  for bundle_encoder in wgpu_bundle_encoders(render_context_data).unwrap() {
    bundles.push(bundle_encoder.finish())
  }
  bundles
}

///|
/// `_createArrayCameraLayerDescriptors( renderContext, renderContextData, descriptor,
/// cameras )`.
fn WebGPUBackend::_create_array_camera_layer_descriptors(
  self : WebGPUBackend,
  render_context : @nodes.RenderContext,
  render_context_data : @core.JsValue,
  descriptor : @gpu.GPURenderPassDescriptor,
  cameras : Array[@core.Object3D],
) -> Unit {
  let depth_stencil_attachment = descriptor.depth_stencil_attachment
  let layer_descriptors = []
  render_context_data.set(
    "layerDescriptors",
    @core.JsValue::of(layer_descriptors),
  )
  let depth_texture_data = self.get(
    @core.JsValue::of(render_context.depth_texture.unwrap()),
  )
  if !wgpu_truthy(depth_texture_data.get("viewCache")) {
    let cache : Map[Int32, @gpu.GPUTextureView] = Map([])
    depth_texture_data.set("viewCache", @core.JsValue::of(cache))
  }
  let view_cache : Map[Int32, @gpu.GPUTextureView] = depth_texture_data
    .get("viewCache")
    .cast()
  let vd = _web_gpu_backend_view_descriptor
  for i = 0; i < cameras.length(); i = i + 1 {
    let layer_descriptor = @gpu.GPURenderPassDescriptor::default()
    layer_descriptor.label = descriptor.label
    layer_descriptor.occlusion_query_set = descriptor.occlusion_query_set
    layer_descriptor.timestamp_writes = descriptor.timestamp_writes
    if descriptor.color_attachments.length() > 0 {
      let source_attachment = descriptor.color_attachments[0]
      let layer_attachment = descriptor.color_attachments[i]
      let layer_color_attachment = @gpu.GPURenderPassColorAttachment::default()
      layer_color_attachment.view = layer_attachment.view
      layer_color_attachment.depth_slice = layer_attachment.depth_slice
      layer_color_attachment.resolve_target = layer_attachment.resolve_target
      layer_color_attachment.load_op = source_attachment.load_op
      layer_color_attachment.store_op = source_attachment.store_op
      layer_color_attachment.clear_value = source_attachment.clear_value
      layer_descriptor.color_attachments.push(layer_color_attachment)
    }
    let dsa = depth_stencil_attachment.unwrap()
    match descriptor.depth_stencil_attachment {
      Some(_) => {
        let layer_index = i
        if view_cache.get(layer_index) is None {
          let msaa_texture = match wgpu_msaa_textures(depth_texture_data) {
            Some(m) =>
              if layer_index < m.length() {
                Some(m[layer_index])
              } else {
                None
              }
            None => None
          }
          match msaa_texture {
            Some(m) => view_cache[layer_index] = m.create_view()
            None => {
              vd.dimension = Some(GPUTextureViewDimension_TwoD)
              vd.base_array_layer = Some(i)
              vd.array_layer_count = Some(1)
              let t : @gpu.GPUTexture = depth_texture_data.get("texture").cast()
              view_cache[layer_index] = t.create_view(descriptor=vd)
            }
          }
          vd.reset()
        }
        let layer_dsa = @gpu.GPURenderPassDepthStencilAttachment::default()
        layer_dsa.view = view_cache.get(layer_index)
        layer_dsa.depth_load_op = Some(
          dsa.depth_load_op.unwrap_or(GPULoadOp_Clear),
        )
        layer_dsa.depth_store_op = Some(
          dsa.depth_store_op.unwrap_or(GPUStoreOp_Store),
        )
        layer_dsa.depth_clear_value = Some(dsa.depth_clear_value.unwrap_or(1.0))
        if render_context.stencil {
          layer_dsa.stencil_load_op = dsa.stencil_load_op
          layer_dsa.stencil_store_op = dsa.stencil_store_op
          layer_dsa.stencil_clear_value = dsa.stencil_clear_value
        }
        layer_descriptor.depth_stencil_attachment = Some(layer_dsa)
      }
      None => {
        let layer_dsa = @gpu.GPURenderPassDepthStencilAttachment::default()
        layer_dsa.view = dsa.view
        layer_dsa.depth_load_op = dsa.depth_load_op
        layer_dsa.depth_store_op = dsa.depth_store_op
        layer_dsa.depth_clear_value = dsa.depth_clear_value
        layer_dsa.depth_read_only = dsa.depth_read_only
        layer_dsa.stencil_load_op = dsa.stencil_load_op
        layer_dsa.stencil_store_op = dsa.stencil_store_op
        layer_dsa.stencil_clear_value = dsa.stencil_clear_value
        layer_dsa.stencil_read_only = dsa.stencil_read_only
        layer_descriptor.depth_stencil_attachment = Some(layer_dsa)
      }
    }
    layer_descriptors.push(layer_descriptor)
  }
}

///|
/// `_updateArrayCameraLayerDescriptors( renderContext, renderContextData, descriptor,
/// cameras )`.
fn WebGPUBackend::_update_array_camera_layer_descriptors(
  self : WebGPUBackend,
  render_context : @nodes.RenderContext,
  render_context_data : @core.JsValue,
  descriptor : @gpu.GPURenderPassDescriptor,
  cameras : Array[@core.Object3D],
) -> Unit {
  ignore(self)
  let render_target = render_context.render_target
  let multisampled = render_context.sample_count > 1
  let discard_depth = multisampled &&
    (match render_target {
      Some(rt) => rt.store_multisampled_depth_buffer == false
      None => false
    })
  let discard_stencil = multisampled &&
    (match render_target {
      Some(rt) => rt.store_multisampled_stencil_buffer == false
      None => false
    })
  let layer_descriptors : Array[@gpu.GPURenderPassDescriptor] = render_context_data
    .get("layerDescriptors")
    .cast()
  for i = 0; i < cameras.length(); i = i + 1 {
    let layer_descriptor = layer_descriptors[i]
    layer_descriptor.timestamp_writes = descriptor.timestamp_writes
    if descriptor.color_attachments.length() > 0 {
      let source_color_attachment = descriptor.color_attachments[0]
      let layer_color_attachment = descriptor.color_attachments[i]
      let color_attachment = layer_descriptor.color_attachments[0]
      color_attachment.view = layer_color_attachment.view
      color_attachment.resolve_target = layer_color_attachment.resolve_target
      color_attachment.depth_slice = layer_color_attachment.depth_slice
      color_attachment.load_op = source_color_attachment.load_op
      color_attachment.store_op = source_color_attachment.store_op
      color_attachment.clear_value = source_color_attachment.clear_value
    }
    match layer_descriptor.depth_stencil_attachment {
      Some(depth_attachment) => {
        if render_context.depth {
          if render_context.clear_depth || discard_depth {
            depth_attachment.depth_clear_value = Some(
              render_context.clear_depth_value,
            )
            depth_attachment.depth_load_op = Some(GPULoadOp_Clear)
          } else {
            depth_attachment.depth_load_op = Some(GPULoadOp_Load)
          }
        }
        if render_context.stencil {
          if render_context.clear_stencil || discard_stencil {
            depth_attachment.stencil_clear_value = Some(
              render_context.clear_stencil_value,
            )
            depth_attachment.stencil_load_op = Some(GPULoadOp_Clear)
          } else {
            depth_attachment.stencil_load_op = Some(GPULoadOp_Load)
          }
        }
      }
      None => ()
    }
  }
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn finish_render(
  self,
  backend,
  render_context,
) {
  let render_context_data = self.render_context_data(render_context)
  let occlusion_query_count = render_context.occlusion_query_count
  let occlusion_data = backend.get_occlusion_data(render_context)
  let render_bundles : Array[@gpu.GPURenderBundle] = render_context_data
    .get("renderBundles")
    .cast()
  if render_bundles.length() > 0 {
    wgpu_current_pass(render_context_data)
    .unwrap()
    .pass("executeBundles")
    .execute_bundles(render_bundles)
  }
  let last_occlusion_object = occlusion_data.get("lastOcclusionObject")
  if wgpu_truthy(last_occlusion_object) &&
    @nodes.occlusion_test(last_occlusion_object.cast()) == true {
    wgpu_current_pass(render_context_data)
    .unwrap()
    .pass("endOcclusionQuery")
    .end_occlusion_query()
  }
  // Layered render targets: execute the bundle for each layer.
  let encoder : @gpu.GPUCommandEncoder = render_context_data
    .get("encoder")
    .cast()
  if self._is_render_camera_depth_array(render_context) == true {
    let bundles = self._finish_array_camera_bundle_encoders(render_context_data)
    let render_stages : Array[WebGPURenderStage] = render_context_data
      .get("arrayCameraRenderStages")
      .cast()
    render_stages.push({ bundles, framebuffer_copy: None, })
    let layer_descriptors : Array[@gpu.GPURenderPassDescriptor] = render_context_data
      .get("layerDescriptors")
      .cast()
    // A viewport texture is 2D, so each layer must be captured immediately before that layer samples it.
    for i = 0; i < layer_descriptors.length(); i = i + 1 {
      let layer_descriptor = layer_descriptors[i]
      let color_load_ops = layer_descriptor.color_attachments.map(fn(a) {
        a.load_op
      })
      let color_store_ops = layer_descriptor.color_attachments.map(fn(a) {
        a.store_op
      })
      let dsa = layer_descriptor.depth_stencil_attachment
      let depth_load_op = dsa.bind(fn(d) { d.depth_load_op })
      let depth_store_op = dsa.bind(fn(d) { d.depth_store_op })
      let stencil_load_op = dsa.bind(fn(d) { d.stencil_load_op })
      let stencil_store_op = dsa.bind(fn(d) { d.stencil_store_op })
      for stage_index = 0
          stage_index < render_stages.length()
          stage_index = stage_index + 1 {
        let render_stage = render_stages[stage_index]
        let bundle = render_stage.bundles[i]
        let is_last_stage = stage_index == render_stages.length() - 1
        for j = 0; j < layer_descriptor.color_attachments.length(); j = j + 1 {
          let attachment = layer_descriptor.color_attachments[j]
          attachment.load_op = if stage_index == 0 {
            color_load_ops[j]
          } else {
            Some(GPULoadOp_Load)
          }
          attachment.store_op = if is_last_stage {
            color_store_ops[j]
          } else {
            Some(GPUStoreOp_Store)
          }
        }
        if render_context.depth {
          let d = dsa.unwrap()
          d.depth_load_op = if stage_index == 0 {
            depth_load_op
          } else {
            Some(GPULoadOp_Load)
          }
          d.depth_store_op = if is_last_stage {
            depth_store_op
          } else {
            Some(GPUStoreOp_Store)
          }
        }
        if render_context.stencil {
          let d = dsa.unwrap()
          d.stencil_load_op = if stage_index == 0 {
            stencil_load_op
          } else {
            Some(GPULoadOp_Load)
          }
          d.stencil_store_op = if is_last_stage {
            stencil_store_op
          } else {
            Some(GPUStoreOp_Store)
          }
        }
        let render_pass = encoder.begin_render_pass(layer_descriptor)
        if render_context.viewport {
          let v = render_context.viewport_value
          render_pass.set_viewport(
            v.x,
            v.y,
            v.z,
            v.w,
            render_context.viewport_min_depth.unwrap_or(0.0),
            render_context.viewport_max_depth.unwrap_or(1.0),
          )
        }
        if render_context.scissor {
          let s = render_context.scissor_value
          render_pass.set_scissor_rect(
            s.x.to_int(),
            s.y.to_int(),
            s.z.to_int(),
            s.w.to_int(),
          )
        }
        render_pass.execute_bundles([bundle])
        render_pass.end()
        match render_stage.framebuffer_copy {
          Some(copy) =>
            self._copy_framebuffer_to_texture(
              encoder,
              copy.texture,
              copy.source_gpu,
              copy.destination_gpu,
              copy.rectangle,
              i,
              copy.generate_mipmaps,
            )
          None => ()
        }
      }
      for j = 0; j < layer_descriptor.color_attachments.length(); j = j + 1 {
        layer_descriptor.color_attachments[j].load_op = color_load_ops[j]
        layer_descriptor.color_attachments[j].store_op = color_store_ops[j]
      }
      if render_context.depth {
        let d = dsa.unwrap()
        d.depth_load_op = depth_load_op
        d.depth_store_op = depth_store_op
      }
      if render_context.stencil {
        let d = dsa.unwrap()
        d.stencil_load_op = stencil_load_op
        d.stencil_store_op = stencil_store_op
      }
    }
  } else {
    match wgpu_current_pass(render_context_data) {
      Some(pass) => pass.pass("end").end()
      None => ()
    }
  }
  if occlusion_query_count > 0 {
    let buffer_size = occlusion_query_count * 8 // 8 byte entries for query results
    //
    let bd = _web_gpu_backend_buffer_descriptor
    let query_resolve_buffer = match
      self.occluded_resolve_cache.get(buffer_size) {
      Some(b) => b
      None => {
        bd.size = buffer_size
        bd.usage = @gpu.GPU_BUFFER_USAGE_QUERY_RESOLVE |
          @gpu.GPU_BUFFER_USAGE_COPY_SRC
        let b = self.gpu_device().create_buffer(bd)
        bd.reset()
        self.occluded_resolve_cache[buffer_size] = b
        b
      }
    }
    //
    bd.size = buffer_size
    bd.usage = @gpu.GPU_BUFFER_USAGE_COPY_DST | @gpu.GPU_BUFFER_USAGE_MAP_READ
    let read_buffer = self.gpu_device().create_buffer(bd)
    bd.reset()
    // two buffers required here - WebGPU doesn't allow usage of QUERY_RESOLVE & MAP_READ to be combined
    encoder.resolve_query_set(
      occlusion_data.get("occlusionQuerySet").cast(),
      0,
      occlusion_query_count,
      query_resolve_buffer,
      0,
    )
    encoder.copy_buffer_to_buffer(
      query_resolve_buffer, 0, read_buffer, 0, buffer_size,
    )
    occlusion_data.set("occlusionQueryBuffer", @core.JsValue::of(read_buffer))
    //
    self.resolve_occluded_async(render_context, backend)
  }
  wgpu_submit(self.gpu_device(), encoder.finish())
  // pass and encoder are only valid between beginRender() and finishRender()
  wgpu_set_current_pass(render_context_data, None)
  render_context_data.set("encoder", @core.JsValue::null())
  //
  match render_context.textures {
    Some(textures) =>
      for texture in textures {
        if texture.generate_mipmaps == true &&
          texture.mipmaps_auto_update == true {
          self.texture_utils.generate_mipmaps(texture)
        }
      }
    None => ()
  }
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn is_occluded(
  _,
  backend,
  render_context,
  object,
) {
  let occlusion_data = backend.get_occlusion_data(render_context)
  let occluded = occlusion_data.get("occluded")
  wgpu_truthy(occluded) &&
  wgpu_weak_set_has(occluded, @core.JsValue::of(object))
}

///|
/// `async resolveOccludedAsync( renderContext )` (not awaited by `finishRender`).
pub fn WebGPUBackend::resolve_occluded_async(
  self : WebGPUBackend,
  render_context : @nodes.RenderContext,
  backend : @nodes.Backend,
) -> Unit {
  ignore(self)
  let occlusion_data = backend.get_occlusion_data(render_context)
  // handle occlusion query results
  let current_buffer = occlusion_data.get("currentOcclusionQueryBuffer")
  let current_objects = occlusion_data.get("currentOcclusionQueryObjects")
  if wgpu_truthy(current_buffer) && wgpu_truthy(current_objects) {
    let current_occlusion_query_buffer : @gpu.GPUBuffer = current_buffer.cast()
    let current_occlusion_query_objects : Array[@core.Object3D?] = current_objects.cast()
    let occluded = wgpu_new_weak_set()
    occlusion_data.set("currentOcclusionQueryObjects", @core.JsValue::null())
    occlusion_data.set("currentOcclusionQueryBuffer", @core.JsValue::null())
    wgpu_await(
      current_occlusion_query_buffer.map_async_promise(@gpu.GPU_MAP_MODE_READ),
      fn(_) {
        let buffer = current_occlusion_query_buffer.get_mapped_range()
        for i = 0; i < current_occlusion_query_objects.length(); i = i + 1 {
          match current_occlusion_query_objects[i] {
            Some(object) =>
              if @gpu.big_uint64_is_zero(buffer, i) {
                wgpu_weak_set_add(occluded, @core.JsValue::of(object))
              }
            None => ()
          }
        }
        current_occlusion_query_buffer.destroy()
        occlusion_data.set("occluded", occluded)
      },
      fn(_) {  },
    )
  }
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn update_viewport(
  self,
  _,
  render_context,
) {
  self.update_viewport_(render_context)
}

///|
/// `updateViewport( renderContext )`.
fn WebGPUBackend::update_viewport_(
  self : WebGPUBackend,
  render_context : @nodes.RenderContext,
) -> Unit {
  let current_pass = wgpu_current_pass(self.render_context_data(render_context))
  let v = render_context.viewport_value
  match current_pass {
    Some(pass) =>
      pass
      .pass("setViewport")
      .set_viewport(
        v.x,
        v.y,
        v.z,
        v.w,
        render_context.viewport_min_depth.unwrap_or(0.0),
        render_context.viewport_max_depth.unwrap_or(1.0),
      )
    None =>
      abort("TypeError: Cannot read properties of null (reading 'setViewport')")
  }
}

///|
/// `updateScissor( renderContext )`.
pub fn WebGPUBackend::update_scissor(
  self : WebGPUBackend,
  render_context : @nodes.RenderContext,
) -> Unit {
  let current_pass = wgpu_current_pass(self.render_context_data(render_context))
  let s = render_context.scissor_value
  match current_pass {
    Some(pass) =>
      pass
      .pass("setScissorRect")
      .set_scissor_rect(s.x.to_int(), s.y.to_int(), s.z.to_int(), s.w.to_int())
    None =>
      abort(
        "TypeError: Cannot read properties of null (reading 'setScissorRect')",
      )
  }
}

///|
/// `getClearColor()`: the base clear color, premultiplied when `alpha` is true.
pub fn WebGPUBackend::get_clear_color(self : WebGPUBackend) -> @nodes.Color4 {
  let clear_color = self.base().get_clear_color_base()
  // only premultiply alpha when alphaMode is "premultiplied"
  if self.renderer().alpha == true {
    clear_color.color.r *= clear_color.a
    clear_color.color.g *= clear_color.a
    clear_color.color.b *= clear_color.a
  }
  clear_color
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn get_clear_color(self, _) {
  self.get_clear_color()
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn clear(
  self,
  _,
  color,
  depth,
  stencil,
  render_target_context,
) {
  let device = self.gpu_device()
  let renderer = self.renderer()
  let mut color_attachments : Array[@gpu.GPURenderPassColorAttachment] = []
  let mut depth_stencil_attachment : @gpu.GPURenderPassDepthStencilAttachment? = None
  let mut supports_depth = false
  let mut supports_stencil = false
  if color {
    let clear_color = self.get_clear_color()
    _web_gpu_backend_clear_value.r = clear_color.color.r
    _web_gpu_backend_clear_value.g = clear_color.color.g
    _web_gpu_backend_clear_value.b = clear_color.color.b
    _web_gpu_backend_clear_value.a = clear_color.a
  }
  match render_target_context {
    None => {
      supports_depth = renderer.depth
      supports_stencil = renderer.stencil
      let descriptor = self._get_default_render_pass_descriptor()
      if color {
        color_attachments = descriptor.color_attachments
        let color_attachment = color_attachments[0]
        color_attachment.clear_value = Some(_web_gpu_backend_clear_value)
        color_attachment.load_op = Some(GPULoadOp_Clear)
        color_attachment.store_op = Some(GPUStoreOp_Store)
      }
      if supports_depth || supports_stencil {
        depth_stencil_attachment = descriptor.depth_stencil_attachment
      }
    }
    Some(render_target_context) => {
      supports_depth = render_target_context.depth
      supports_stencil = render_target_context.stencil
      let clear_config = {
        load_op: Some(if color { GPULoadOp_Clear } else { GPULoadOp_Load }),
        store_op: None,
        clear_value: if color {
          Some(_web_gpu_backend_clear_value)
        } else {
          None
        },
      }
      let descriptor = self._get_render_pass_descriptor(
        render_target_context, clear_config,
      )
      color_attachments = descriptor.color_attachments
      depth_stencil_attachment = descriptor.depth_stencil_attachment
    }
  }
  if supports_depth {
    match depth_stencil_attachment {
      Some(dsa) =>
        if depth {
          dsa.depth_load_op = Some(GPULoadOp_Clear)
          dsa.depth_clear_value = Some(renderer.get_clear_depth())
          dsa.depth_store_op = Some(GPUStoreOp_Store)
        } else {
          dsa.depth_load_op = Some(GPULoadOp_Load)
          dsa.depth_store_op = Some(GPUStoreOp_Store)
        }
      None => ()
    }
  }
  //
  if supports_stencil {
    match depth_stencil_attachment {
      Some(dsa) =>
        if stencil {
          dsa.stencil_load_op = Some(GPULoadOp_Clear)
          dsa.stencil_clear_value = Some(renderer.get_clear_stencil())
          dsa.stencil_store_op = Some(GPUStoreOp_Store)
        } else {
          dsa.stencil_load_op = Some(GPULoadOp_Load)
          dsa.stencil_store_op = Some(GPUStoreOp_Store)
        }
      None => ()
    }
  }
  //
  let ced = _web_gpu_backend_command_encoder_descriptor
  ced.label = Some("clear")
  let encoder = device.create_command_encoder(descriptor=ced)
  ced.reset()
  let current_pass = encoder.begin_render_pass(
    @gpu.GPURenderPassDescriptor::new(
      color_attachments~,
      depth_stencil_attachment?,
    ),
  )
  current_pass.end()
  wgpu_submit(device, encoder.finish())
}
