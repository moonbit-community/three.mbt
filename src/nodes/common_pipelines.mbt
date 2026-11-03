// renderers/common/Pipelines.js

///|
/// The record of a render object or compute node in `Pipelines`.
pub(all) struct PipelineData {
  /// `undefined` until a pipeline is assigned.
  mut pipeline : Pipeline?
  /// The compute node version the pipeline was built for.
  mut version : Int32?
}

///|
/// `programs`: the shader stages by code, per stage.
pub(all) struct PipelinePrograms {
  vertex : Map[String, ProgrammableStage]
  fragment : Map[String, ProgrammableStage]
  compute : Map[String, ProgrammableStage]
}

///|
fn PipelinePrograms::new() -> PipelinePrograms {
  { vertex: Map([]), fragment: Map([]), compute: Map([]), }
}

///|
fn PipelinePrograms::stage(
  self : PipelinePrograms,
  stage : String,
) -> Map[String, ProgrammableStage] {
  match stage {
    "vertex" => self.vertex
    "fragment" => self.fragment
    "compute" => self.compute
    _ =>
      abort("TypeError: Cannot read properties of undefined (reading 'delete')")
  }
}

///|
/// Creates and shares the render and compute pipelines.
pub struct Pipelines {
  priv render_objects : DataMap[RenderObject, PipelineData]
  priv compute_nodes : DataMap[Node, PipelineData]
  backend : Backend
  nodes : NodeManager
  info : Info
  /// Set by `new Bindings( ... )`.
  mut bindings : Bindings?
  mut caches : Map[String, Pipeline]
  mut programs : PipelinePrograms
}

///|
/// `new Pipelines( backend, nodes, info )`.
pub fn Pipelines::new(
  backend : Backend,
  nodes : NodeManager,
  info : Info,
) -> Pipelines {
  {
    render_objects: DataMap::new(fn() { { pipeline: None, version: None, } }),
    compute_nodes: DataMap::new(fn() { { pipeline: None, version: None, } }),
    backend,
    nodes,
    info,
    bindings: None,
    caches: Map([]),
    programs: PipelinePrograms::new(),
  }
}

///|
/// `get( renderObject )`.
pub fn Pipelines::get(
  self : Pipelines,
  render_object : RenderObject,
) -> PipelineData {
  self.render_objects.get(render_object)
}

///|
/// `has( computeNode )` (added by G6).
pub fn Pipelines::has_compute(self : Pipelines, compute_node : Node) -> Bool {
  self.compute_nodes.has(compute_node)
}

///|
/// `get( computeNode )`.
pub fn Pipelines::get_compute(
  self : Pipelines,
  compute_node : Node,
) -> PipelineData {
  self.compute_nodes.get(compute_node)
}

///|
/// `getForCompute( computeNode, bindings )`: the compute pipeline, rebuilt when the
/// node's version changed.
pub fn Pipelines::get_for_compute(
  self : Pipelines,
  compute_node : Node,
  bindings : Array[BindGroup],
  promises? : Array[@core.JsValue],
) -> Pipeline {
  let backend = self.backend
  let data = self.get_compute(compute_node)
  if self._needs_compute_update(compute_node) {
    let previous_pipeline = data.pipeline
    match previous_pipeline {
      Some(p) => {
        p.used_times -= 1
        p.compute_program().used_times -= 1
      }
      None => ()
    }
    let node_builder_state = self.nodes.get_for_compute(compute_node)
    let compute_shader = node_builder_state.compute_shader.unwrap_or("")
    let stage_compute = match self.programs.compute.get(compute_shader) {
      Some(s) => s
      None => {
        let s = ProgrammableStage::new(
          compute_shader,
          "compute",
          compute_node.name.unwrap_or(""),
        )
        self.programs.compute.set(compute_shader, s)
        backend.create_program(s)
        self.info.create_program(s)
        s
      }
    }
    let cache_key = self._get_compute_cache_key(compute_node, stage_compute)
    let pipeline = match self.caches.get(cache_key) {
      Some(p) => p
      None =>
        self._get_compute_pipeline(
          compute_node, stage_compute, cache_key, bindings, promises,
        )
    }
    pipeline.used_times += 1
    stage_compute.used_times += 1
    match previous_pipeline {
      Some(p) => {
        if p.used_times == 0 {
          self._release_pipeline(p)
        }
        if p.compute_program().used_times == 0 {
          self._release_program(p.compute_program())
        }
      }
      None => ()
    }
    data.version = Some(compute_node.version)
    data.pipeline = Some(pipeline)
  }
  data.pipeline.unwrap()
}

///|
/// `getForRender( renderObject, promises = null )`: the render pipeline, rebuilt when
/// the backend says the render object changed.
pub fn Pipelines::get_for_render(
  self : Pipelines,
  render_object : RenderObject,
  promises? : Array[@core.JsValue],
) -> Pipeline {
  let backend = self.backend
  let data = self.get(render_object)
  if self._needs_render_update(render_object) {
    let previous_pipeline = data.pipeline
    match previous_pipeline {
      Some(p) => {
        p.used_times -= 1
        p.vertex_program().used_times -= 1
        p.fragment_program().used_times -= 1
      }
      None => ()
    }
    let node_builder_state = render_object.get_node_builder_state()
    let name = render_object.material.name
    let vertex_shader = node_builder_state.vertex_shader.unwrap_or("")
    let fragment_shader = node_builder_state.fragment_shader.unwrap_or("")
    let stage_vertex = match self.programs.vertex.get(vertex_shader) {
      Some(s) => s
      None => {
        let s = ProgrammableStage::new(vertex_shader, "vertex", name)
        self.programs.vertex.set(vertex_shader, s)
        backend.create_program(s)
        self.info.create_program(s)
        s
      }
    }
    let stage_fragment = match self.programs.fragment.get(fragment_shader) {
      Some(s) => s
      None => {
        let s = ProgrammableStage::new(fragment_shader, "fragment", name)
        self.programs.fragment.set(fragment_shader, s)
        backend.create_program(s)
        self.info.create_program(s)
        s
      }
    }
    let cache_key = self._get_render_cache_key(
      render_object, stage_vertex, stage_fragment,
    )
    let pipeline = match self.caches.get(cache_key) {
      None =>
        self._get_render_pipeline(
          render_object, stage_vertex, stage_fragment, cache_key, promises,
        )
      Some(p) => {
        render_object.pipeline = Some(p)
        p
      }
    }
    pipeline.used_times += 1
    stage_vertex.used_times += 1
    stage_fragment.used_times += 1
    match previous_pipeline {
      Some(p) => {
        if p.used_times == 0 {
          self._release_pipeline(p)
        }
        if p.vertex_program().used_times == 0 {
          self._release_program(p.vertex_program())
        }
        if p.fragment_program().used_times == 0 {
          self._release_program(p.fragment_program())
        }
      }
      None => ()
    }
    data.pipeline = Some(pipeline)
  }
  data.pipeline.unwrap()
}

///|
/// `isReady( renderObject )`: whether the backend finished the render pipeline.
pub fn Pipelines::is_ready(
  self : Pipelines,
  render_object : RenderObject,
) -> Bool {
  let data = self.get(render_object)
  match data.pipeline {
    None => false
    Some(pipeline) => {
      let pipeline_data = self.backend.get(@core.JsValue::of(pipeline))
      let gpu_pipeline = pipeline_data.get("pipeline")
      !gpu_pipeline.is_undefined() && !gpu_pipeline.is_null()
    }
  }
}

///|
/// Releases `data.pipeline` and its programs when unused.
fn Pipelines::_delete_pipeline_of(
  self : Pipelines,
  data : PipelineData,
) -> Unit {
  match data.pipeline {
    Some(pipeline) => {
      pipeline.used_times -= 1
      if pipeline.used_times == 0 {
        self._release_pipeline(pipeline)
      }
      if pipeline.is_compute_pipeline() {
        pipeline.compute_program().used_times -= 1
        if pipeline.compute_program().used_times == 0 {
          self._release_program(pipeline.compute_program())
        }
      } else {
        pipeline.fragment_program().used_times -= 1
        pipeline.vertex_program().used_times -= 1
        if pipeline.vertex_program().used_times == 0 {
          self._release_program(pipeline.vertex_program())
        }
        if pipeline.fragment_program().used_times == 0 {
          self._release_program(pipeline.fragment_program())
        }
      }
    }
    None => ()
  }
}

///|
/// `delete( renderObject )`: releases the render object's pipeline.
pub fn Pipelines::delete(
  self : Pipelines,
  render_object : RenderObject,
) -> PipelineData? {
  self._delete_pipeline_of(self.get(render_object))
  self.render_objects.delete(render_object)
}

///|
/// `delete( computeNode )`: releases the compute node's pipeline.
pub fn Pipelines::delete_compute(
  self : Pipelines,
  compute_node : Node,
) -> PipelineData? {
  self._delete_pipeline_of(self.get_compute(compute_node))
  self.compute_nodes.delete(compute_node)
}

///|
/// `dispose()`.
pub fn Pipelines::dispose(self : Pipelines) -> Unit {
  self.render_objects.dispose()
  self.compute_nodes.dispose()
  self.caches = Map([])
  self.programs = PipelinePrograms::new()
}

///|
/// `updateForRender( renderObject )`.
pub fn Pipelines::update_for_render(
  self : Pipelines,
  render_object : RenderObject,
) -> Unit {
  self.get_for_render(render_object) |> ignore
}

///|
/// `_getComputePipeline( computeNode, stageCompute, cacheKey, bindings )`.
pub fn Pipelines::_get_compute_pipeline(
  self : Pipelines,
  compute_node : Node,
  stage_compute : ProgrammableStage,
  cache_key : String,
  bindings : Array[BindGroup],
  promises : Array[@core.JsValue]?,
) -> Pipeline {
  let cache_key = if cache_key == "" {
    self._get_compute_cache_key(compute_node, stage_compute)
  } else {
    cache_key
  }
  match self.caches.get(cache_key) {
    Some(p) => p
    None => {
      let state = self.nodes.get_for_compute(compute_node)
      let pipeline = ComputePipeline::new(
        cache_key,
        stage_compute,
        transforms=state.transforms,
        attributes=state.node_attributes,
      )
      self.caches.set(cache_key, pipeline)
      self.backend.create_compute_pipeline(pipeline, bindings, promises)
      pipeline
    }
  }
}

///|
/// `_getRenderPipeline( renderObject, stageVertex, stageFragment, cacheKey, promises )`.
pub fn Pipelines::_get_render_pipeline(
  self : Pipelines,
  render_object : RenderObject,
  stage_vertex : ProgrammableStage,
  stage_fragment : ProgrammableStage,
  cache_key : String,
  promises : Array[@core.JsValue]?,
) -> Pipeline {
  let cache_key = if cache_key == "" {
    self._get_render_cache_key(render_object, stage_vertex, stage_fragment)
  } else {
    cache_key
  }
  match self.caches.get(cache_key) {
    Some(p) => p
    None => {
      let pipeline = RenderObjectPipeline::new(
        cache_key, stage_vertex, stage_fragment,
      )
      self.caches.set(cache_key, pipeline)
      render_object.pipeline = Some(pipeline)
      self.backend.create_render_pipeline(render_object, promises)
      pipeline
    }
  }
}

///|
/// `_getComputeCacheKey( computeNode, stageCompute )`.
pub fn Pipelines::_get_compute_cache_key(
  self : Pipelines,
  compute_node : Node,
  stage_compute : ProgrammableStage,
) -> String {
  ignore(self)
  compute_node.id.to_string() + "," + stage_compute.id.to_string()
}

///|
/// `_getRenderCacheKey( renderObject, stageVertex, stageFragment )`.
pub fn Pipelines::_get_render_cache_key(
  self : Pipelines,
  render_object : RenderObject,
  stage_vertex : ProgrammableStage,
  stage_fragment : ProgrammableStage,
) -> String {
  stage_vertex.id.to_string() +
  "," +
  stage_fragment.id.to_string() +
  "," +
  self.backend.get_render_cache_key(render_object)
}

///|
/// `_releasePipeline( pipeline )`.
pub fn Pipelines::_release_pipeline(
  self : Pipelines,
  pipeline : Pipeline,
) -> Unit {
  self.backend.destroy_pipeline(pipeline)
  self.caches.remove(pipeline.cache_key)
}

///|
/// `_releaseProgram( program )`.
pub fn Pipelines::_release_program(
  self : Pipelines,
  program : ProgrammableStage,
) -> Unit {
  let code = program.code
  let stage = program.stage
  self.programs.stage(stage).remove(code)
  self.backend.destroy_program(program)
  self.info.destroy_program(program)
}

///|
/// `_needsComputeUpdate( computeNode )`.
pub fn Pipelines::_needs_compute_update(
  self : Pipelines,
  compute_node : Node,
) -> Bool {
  let data = self.get_compute(compute_node)
  data.pipeline is None || data.version != Some(compute_node.version)
}

///|
/// `_needsRenderUpdate( renderObject )`.
pub fn Pipelines::_needs_render_update(
  self : Pipelines,
  render_object : RenderObject,
) -> Bool {
  let data = self.get(render_object)
  data.pipeline is None || self.backend.needs_render_update(render_object)
}
