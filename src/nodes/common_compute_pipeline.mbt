// renderers/common/ComputePipeline.js

///|
/// Marker for `ComputePipeline`; `new` returns a `Pipeline`.
#external
pub type ComputePipeline

///|
/// `new ComputePipeline( cacheKey, computeProgram, transforms = null, attributes = null )`.
pub fn ComputePipeline::new(
  cache_key : String,
  compute_program : ProgrammableStage,
  transforms? : Array[NodeTransform],
  attributes? : Array[NodeAttribute],
) -> Pipeline {
  {
    cache_key,
    used_times: 0,
    kind: Compute(compute_program~, transforms~, attributes~),
  }
}
