// renderers/common/DirectRenderPipeline.js: a render pipeline that renders the scene
// directly with the output transform applied in each material (`getOutput`), instead
// of a full-screen pass. `DirectRenderPipeline::new` returns a `RenderPipeline` whose
// class is the `DirectRenderPipeline` payload.

///|
/// The `DirectRenderPipeline` members.
pub(all) struct DirectRenderPipeline {
  mut _context_node : Node?
  mut _renderer_context_node : Node?
  _background_nodes : @webgl.WeakMap[@core.JsValue, Node]
}

///|
pub impl RenderPipelineClass for DirectRenderPipeline with fn has_flag(_, flag) {
  flag == "isDirectRenderPipeline"
}

///|
pub impl RenderPipelineClass for DirectRenderPipeline with fn _update(
  self,
  pipeline,
) {
  if !(self._renderer_context_node is Some(n) &&
    physical_equal(n, pipeline.renderer.context_node)) {
    self._renderer_context_node = Some(pipeline.renderer.context_node)
    pipeline.needs_update = true
  }
  pipeline._update_base()
}

///|
pub impl RenderPipelineClass for DirectRenderPipeline with fn _update_context(
  self,
  pipeline,
) {
  pipeline._update_context_base()
  let pipeline_output_node = pipeline.output_node
  let tone_mapping = pipeline._tone_mapping
  let output_color_space = pipeline._output_color_space
  let output_color_transform = pipeline.output_color_transform
  let value = pipeline._context_data.unwrap().to_context()
  value.set(
    "getOutput",
    Other(
      @core.JsValue::of(ContextGetOutput::{
        f: fn(material_output_node, builder) {
          let renderer = builder.renderer
          let render_target = renderer.get_render_target()
          if renderer.is_output_target() == false &&
            !(render_target is Some(rt) &&
            render_target_has_external_textures(rt)) {
            return material_output_node
          }
          output.assign(material_output_node)
          if output_color_transform == false {
            return pipeline_output_node
          }
          let render_output_node = render_output(
            pipeline_output_node,
            tone_mapping~,
            output_color_space~,
          )
          RenderOutputNode::of(render_output_node).unwrap().premultiplied_alpha
          = builder.material.unwrap().premultiplied_alpha
          render_output_node
        },
      }),
    ),
  )
  self._context_node = Some(
    self._renderer_context_node.unwrap().context(value~),
  )
}

///|
/// `new DirectRenderPipeline( renderer, outputNode = output )`.
pub fn DirectRenderPipeline::new(
  renderer : Renderer,
  output_node? : Node,
) -> RenderPipeline {
  let payload = DirectRenderPipeline::{
    _context_node: None,
    _renderer_context_node: None,
    _background_nodes: @webgl.WeakMap::new(),
  }
  RenderPipeline::new(
    renderer,
    output_node=output_node.unwrap_or(output),
    class_=payload,
  )
}

///|
/// The `DirectRenderPipeline` members of a pipeline, if it is one.
pub fn DirectRenderPipeline::of(
  pipeline : RenderPipeline,
) -> DirectRenderPipeline? {
  if pipeline.class_.has_flag("isDirectRenderPipeline") {
    Some(pipeline.class_.payload().cast())
  } else {
    None
  }
}

///|
/// `render( scene, camera )`: renders the scene with the pipeline's output transform.
pub fn DirectRenderPipeline::render(
  pipeline : RenderPipeline,
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> Unit {
  let self = DirectRenderPipeline::of(pipeline).unwrap()
  let renderer = pipeline.renderer
  pipeline._update()
  let background_node = self._get_background_node(pipeline, scene)
  let scene_data = match scene.kind {
    Scene(s) => Some(s)
    _ => None
  }
  let current_background_node = match background_node {
    Some(_) => scene_data.bind(fn(s) { s.background_node })
    None => None
  }
  let current_context_node = renderer.context_node
  let output_render_target = renderer.get_output_render_target()
  let use_direct_xr_render_target = output_render_target is Some(_) &&
    renderer.xr.is_presenting == true &&
    renderer.backend.has_flag("isWebGPUBackend") &&
    renderer.is_output_target() == true
  let mut samples = 0
  let mut depth_buffer = false
  match (background_node, scene_data) {
    (Some(n), Some(s)) => s.background_node = Some(@core.JsValue::of(n))
    _ => ()
  }
  renderer.context_node = self._context_node.unwrap()
  if use_direct_xr_render_target {
    let o = output_render_target.unwrap()
    samples = o.samples
    depth_buffer = o.depth_buffer
    o.samples = renderer.samples()
    o.depth_buffer = true
  }
  let context_data = pipeline._context_data.unwrap()
  for callback in context_data.on_before_pipeline_callbacks {
    callback()
  }
  let tone_mapping = renderer.tone_mapping
  let output_color_space = renderer.output_color_space
  renderer.tone_mapping = @core.NoToneMapping
  renderer.output_color_space = @math.color_management.working_color_space
  if renderer.xr.enabled {
    renderer.xr.render_layers()
  }
  renderer.render(scene, camera)
  // upstream restores in a `finally` block; an abort ends the program here
  renderer.tone_mapping = tone_mapping
  renderer.output_color_space = output_color_space
  match (background_node, scene_data) {
    (Some(n), Some(s)) =>
      if s.background_node is Some(b) && b.strict_equal(@core.JsValue::of(n)) {
        s.background_node = current_background_node
      }
    _ => ()
  }
  if self._context_node is Some(c) && physical_equal(renderer.context_node, c) {
    renderer.context_node = current_context_node
  }
  if use_direct_xr_render_target {
    let o = output_render_target.unwrap()
    o.samples = samples
    o.depth_buffer = depth_buffer
  }
  for callback in context_data.on_after_pipeline_callbacks {
    callback()
  }
}

///|
/// `_getBackgroundNode( scene )`: a uniform of the scene's background color, so the
/// background is cleared in the working color space.
fn DirectRenderPipeline::_get_background_node(
  self : DirectRenderPipeline,
  pipeline : RenderPipeline,
  scene : @core.Object3D,
) -> Node? {
  let background = match scene.kind {
    Scene({ background_node: None, background: Some(Color(c)), .. }) => c
    _ => return None
  }
  let environment_blend_mode = pipeline.renderer.xr.get_environment_blend_mode()
  if environment_blend_mode == Some("additive") ||
    environment_blend_mode == Some("alpha-blend") {
    return None
  }
  let key = @core.JsValue::of(background)
  match self._background_nodes.get(key) {
    Some(n) => Some(n)
    None => {
      let n = uniform(background)
      self._background_nodes.set(key, n)
      Some(n)
    }
  }
}
