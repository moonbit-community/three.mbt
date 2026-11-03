// renderers/common/RenderObjectPipeline.js

///|
/// Marker for `RenderObjectPipeline`; `new` returns a `Pipeline`.
#external
pub type RenderObjectPipeline

///|
/// `new RenderObjectPipeline( cacheKey, vertexProgram, fragmentProgram )`.
pub fn RenderObjectPipeline::new(
  cache_key : String,
  vertex_program : ProgrammableStage,
  fragment_program : ProgrammableStage,
) -> Pipeline {
  {
    cache_key,
    used_times: 0,
    kind: RenderObject(vertex_program~, fragment_program~),
  }
}
