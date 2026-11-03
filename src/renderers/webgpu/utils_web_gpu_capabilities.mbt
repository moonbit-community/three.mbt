// renderers/webgpu/utils/WebGPUCapabilities.js.

///|
/// `WebGPUCapabilities`: device limits the renderer asks for.
pub(all) struct WebGPUCapabilities {
  /// `backend`, linked right after the backend is built.
  mut backend_ : WebGPUBackend?
}

///|
/// `new WebGPUCapabilities( backend )` (the backend is linked by `WebGPUBackend::new`).
fn WebGPUCapabilities::new() -> WebGPUCapabilities {
  { backend_: None, }
}

///|
/// `getMaxAnisotropy()`.
pub fn WebGPUCapabilities::get_max_anisotropy(
  self : WebGPUCapabilities,
) -> Int32 {
  ignore(self)
  16
}

///|
/// `getUniformBufferLimit()`: `device.limits.maxUniformBufferBindingSize`.
pub fn WebGPUCapabilities::get_uniform_buffer_limit(
  self : WebGPUCapabilities,
) -> Int32 {
  self.backend_
  .unwrap()
  .gpu_device()
  .limits()
  .max_uniform_buffer_binding_size()
  .to_int()
}
