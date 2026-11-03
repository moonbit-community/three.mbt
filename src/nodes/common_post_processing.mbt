// renderers/common/PostProcessing.js: the deprecated name of `RenderPipeline`.
// `PostProcessing::new` returns a `RenderPipeline`.

///|
/// Marker for `PostProcessing`.
pub(all) struct PostProcessing {
  mut _placeholder : Unit
}

///|
/// `new PostProcessing( renderer, outputNode )` (deprecated).
pub fn PostProcessing::new(
  renderer : Renderer,
  output_node? : Node,
) -> RenderPipeline {
  @core.warn_once(
    "PostProcessing: \"PostProcessing\" has been renamed to \"RenderPipeline\". Please update your code to use \"THREE.RenderPipeline\" instead.",
  )
  RenderPipeline::new(renderer, output_node?)
}
