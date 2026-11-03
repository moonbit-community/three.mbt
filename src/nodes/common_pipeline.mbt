// renderers/common/Pipeline.js: the base of `RenderObjectPipeline` and
// `ComputePipeline`, whose constructors (on marker types) return a `Pipeline`.

///|
/// The subclass data of a `Pipeline`.
pub(all) enum PipelineKind {
  /// A plain `new Pipeline( cacheKey )`.
  Base
  /// `RenderObjectPipeline`.
  RenderObject(
    vertex_program~ : ProgrammableStage,
    fragment_program~ : ProgrammableStage
  )
  /// `ComputePipeline`; `None` is `null`.
  Compute(
    compute_program~ : ProgrammableStage,
    transforms~ : Array[NodeTransform]?,
    attributes~ : Array[NodeAttribute]?
  )
}

///|
/// A GPU pipeline shared by the render objects or compute nodes with its cache key.
pub(all) struct Pipeline {
  cache_key : String
  mut used_times : Int32
  kind : PipelineKind
}

///|
/// `new Pipeline( cacheKey )`.
pub fn Pipeline::new(cache_key : String) -> Pipeline {
  { cache_key, used_times: 0, kind: Base, }
}

///|
/// `pipeline.isComputePipeline`.
pub fn Pipeline::is_compute_pipeline(self : Pipeline) -> Bool {
  self.kind is Compute(..)
}

///|
/// `pipeline.vertexProgram` of a render pipeline.
pub fn Pipeline::vertex_program(self : Pipeline) -> ProgrammableStage {
  match self.kind {
    RenderObject(vertex_program~, ..) => vertex_program
    _ => abort("Pipeline::vertex_program: not a RenderObjectPipeline")
  }
}

///|
/// `pipeline.fragmentProgram` of a render pipeline.
pub fn Pipeline::fragment_program(self : Pipeline) -> ProgrammableStage {
  match self.kind {
    RenderObject(fragment_program~, ..) => fragment_program
    _ => abort("Pipeline::fragment_program: not a RenderObjectPipeline")
  }
}

///|
/// `pipeline.computeProgram` of a compute pipeline.
pub fn Pipeline::compute_program(self : Pipeline) -> ProgrammableStage {
  match self.kind {
    Compute(compute_program~, ..) => compute_program
    _ => abort("Pipeline::compute_program: not a ComputePipeline")
  }
}
