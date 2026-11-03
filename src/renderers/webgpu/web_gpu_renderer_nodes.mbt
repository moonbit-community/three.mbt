// renderers/webgpu/WebGPURenderer.Nodes.js: the variant of `WebGPURenderer` with the basic
// node library (node materials only).

///|
/// `WebGPURenderer` of WebGPURenderer.Nodes.js.
#external
pub type WebGPURendererNodes

///|
/// `new WebGPURenderer( parameters = {} )` of WebGPURenderer.Nodes.js.
pub fn WebGPURendererNodes::from_parameters(
  parameters : @core.JsValue,
) -> @nodes.Renderer {
  // The generic default value is overwritten with the
  // standard node library for type mapping. Material
  // mapping is not supported with this version.
  WebGPURenderer::from_parameters(parameters, library=BasicNodeLibrary::new)
}
