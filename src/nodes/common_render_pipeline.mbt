// renderers/common/RenderPipeline.js: renders an output node to the screen with a
// full-screen quad (post-processing). DirectRenderPipeline overrides members through
// `RenderPipelineClass`.

///|
/// `renderPipelineState` of the pipeline's context.
pub(all) struct RenderPipelineState {
  /// `viewOffsetOwner`; `None` is `null`.
  mut view_offset_owner : @core.JsValue?
}

///|
/// The context data of a render pipeline (`_contextData`).
pub(all) struct RenderPipelineContextData {
  render_pipeline : RenderPipeline
  render_pipeline_state : RenderPipelineState
  on_before_pipeline_callbacks : Array[() -> Unit]
  on_after_pipeline_callbacks : Array[() -> Unit]
  /// Set when `outputColorTransform` is off.
  mut tone_mapping : Int32?
  mut output_color_space : String?
}

///|
/// The context of the data, in upstream's key order.
pub fn RenderPipelineContextData::to_context(
  self : RenderPipelineContextData,
) -> NodeContext {
  let context = node_context([
    ("renderPipeline", Other(@core.JsValue::of(self.render_pipeline))),
    (
      "renderPipelineState",
      Other(@core.JsValue::of(self.render_pipeline_state)),
    ),
    (
      "onBeforePipelineCallbacks",
      Other(@core.JsValue::of(self.on_before_pipeline_callbacks)),
    ),
    (
      "onAfterPipelineCallbacks",
      Other(@core.JsValue::of(self.on_after_pipeline_callbacks)),
    ),
  ])
  match self.tone_mapping {
    Some(t) => context.set("toneMapping", Number(t.to_double()))
    None => ()
  }
  match self.output_color_space {
    Some(c) => context.set("outputColorSpace", String(c))
    None => ()
  }
  context
}

///|
/// The overridable members of `RenderPipeline`.
pub(open) trait RenderPipelineClass {
  fn payload(Self) -> @core.JsValue = _
  /// `isDirectRenderPipeline`-style flags.
  fn has_flag(Self, String) -> Bool = _
  /// `_update()`.
  fn _update(Self, RenderPipeline) -> Unit = _
  /// `_updateContext()`.
  fn _update_context(Self, RenderPipeline) -> Unit = _
}

///|
impl RenderPipelineClass with fn payload(self) {
  @core.JsValue::of(self)
}

///|
impl RenderPipelineClass with fn has_flag(_, _) {
  false
}

///|
impl RenderPipelineClass with fn _update(_, pipeline) {
  pipeline._update_base()
}

///|
impl RenderPipelineClass with fn _update_context(_, pipeline) {
  pipeline._update_context_base()
}

///|
priv struct BaseRenderPipeline {}

///|
impl RenderPipelineClass for BaseRenderPipeline

///|
pub(all) struct RenderPipeline {
  mut class_ : &RenderPipelineClass
  renderer : Renderer
  mut output_node : Node
  mut output_color_transform : Bool
  mut needs_update : Bool
  _quad_mesh : QuadMesh
  mut _context_data : RenderPipelineContextData?
  mut _tone_mapping : Int32
  mut _output_color_space : String
}

///|
/// `new RenderPipeline( renderer, outputNode = vec4( 0, 0, 1, 1 ) )`.
pub fn RenderPipeline::new(
  renderer : Renderer,
  output_node? : Node,
  class_? : &RenderPipelineClass,
) -> RenderPipeline {
  let output_node = match output_node {
    Some(n) => n
    None => vec4_of([0, 0, 1, 1])
  }
  let material = NodeMaterial::new()
  material.name = "RenderPipeline"
  let quad_mesh = QuadMesh::new(material~)
  quad_mesh.object.name = "Render Pipeline"
  {
    class_: match class_ {
      Some(c) => c
      None => BaseRenderPipeline::{ }
    },
    renderer,
    output_node,
    output_color_transform: true,
    needs_update: true,
    _quad_mesh: quad_mesh,
    _context_data: None,
    _tone_mapping: renderer.tone_mapping,
    _output_color_space: renderer.output_color_space,
  }
}

///|
/// `render()`: renders the output node to the screen.
pub fn RenderPipeline::render(self : RenderPipeline) -> Unit {
  let renderer = self.renderer
  self._update()
  let context_data = self._context_data.unwrap()
  for callback in context_data.on_before_pipeline_callbacks {
    callback()
  }
  let tone_mapping = renderer.tone_mapping
  let output_color_space = renderer.output_color_space
  renderer.tone_mapping = @core.NoToneMapping
  renderer.output_color_space = @math.color_management.working_color_space
  //
  let current_xr = renderer.xr.enabled
  renderer.xr.enabled = false
  self._quad_mesh.render(renderer)
  renderer.xr.enabled = current_xr
  //
  renderer.tone_mapping = tone_mapping
  renderer.output_color_space = output_color_space
  for callback in context_data.on_after_pipeline_callbacks {
    callback()
  }
}

///|
pub fn RenderPipeline::dispose(self : RenderPipeline) -> Unit {
  self._quad_mesh.material().dispose()
}

///|
pub fn RenderPipeline::_update_context(self : RenderPipeline) -> Unit {
  self.class_._update_context(self)
}

///|
/// `RenderPipeline.prototype._updateContext`.
pub fn RenderPipeline::_update_context_base(self : RenderPipeline) -> Unit {
  let tone_mapping = self._tone_mapping
  let output_color_space = self._output_color_space
  let context_data = {
    render_pipeline: self,
    render_pipeline_state: { view_offset_owner: None, },
    on_before_pipeline_callbacks: [],
    on_after_pipeline_callbacks: [],
    tone_mapping: None,
    output_color_space: None,
  }
  let mut output_node = self.output_node
  if self.output_color_transform == true {
    output_node = render_output(output_node, tone_mapping~, output_color_space~)
  } else {
    context_data.tone_mapping = Some(tone_mapping)
    context_data.output_color_space = Some(output_color_space)
  }
  self._context_data = Some(context_data)
  let material = self._quad_mesh.material()
  let node_material = NodeMaterial::of(material).unwrap()
  node_material.context_node = Some(context(value=context_data.to_context()))
  node_material.fragment_node = Some(output_node)
  material.set_needs_update(true)
}

///|
pub fn RenderPipeline::_update(self : RenderPipeline) -> Unit {
  self.class_._update(self)
}

///|
/// `RenderPipeline.prototype._update`.
pub fn RenderPipeline::_update_base(self : RenderPipeline) -> Unit {
  if self._tone_mapping != self.renderer.tone_mapping {
    self._tone_mapping = self.renderer.tone_mapping
    self.needs_update = true
  }
  if self._output_color_space != self.renderer.output_color_space {
    self._output_color_space = self.renderer.output_color_space
    self.needs_update = true
  }
  if self.needs_update == true {
    self._update_context()
    self.needs_update = false
  }
}

///|
/// `async renderAsync()` (deprecated): `init()`, then `render()`.
pub fn RenderPipeline::render_async(
  self : RenderPipeline,
  on_done~ : () -> Unit = fn() {  },
) -> Unit {
  @core.warn_once(
    "RenderPipeline: \"renderAsync()\" has been deprecated. Use \"render()\" and \"await renderer.init();\" when creating the renderer.",
  )
  self.renderer.init(on_done=fn(error) {
    match error {
      None => {
        self.render()
        on_done()
      }
      Some(e) => abort(e)
    }
  })
}
