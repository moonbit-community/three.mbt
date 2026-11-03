// renderers/common/Backend.js. WebGPUBackend and WebGLBackend implement `BackendClass`
// in their packages; every default is the base class's body (empty bodies do nothing,
// `undefined` results are `false`/`None`). Upstream's async members take a callback.

///|
/// The overridable members of `Backend`.
pub(open) trait BackendClass {
  fn class_name(Self) -> String
  fn payload(Self) -> @core.JsValue = _
  fn has_flag(Self, String) -> Bool = _
  /// `get coordinateSystem()`.
  fn coordinate_system(Self, Backend) -> Int32 = _
  /// `backend.capabilities.getUniformBufferLimit()`.
  fn get_uniform_buffer_limit(Self, Backend) -> Int32 = _
  /// `hasCompatibility( name )` (read by shadow nodes, G3); the base class says `false`.
  fn has_compatibility(Self, Backend, String) -> Bool = _
  // The members the renderer data classes call (G7); the defaults are the base class's
  // empty bodies, and abort where upstream would use the `undefined` result.
  /// `deleteVertexState( renderObject )`.
  fn delete_vertex_state(Self, Backend, RenderObject) -> Unit = _
  /// `createProgram( program )`.
  fn create_program(Self, Backend, ProgrammableStage) -> Unit = _
  /// `destroyProgram( program )`.
  fn destroy_program(Self, Backend, ProgrammableStage) -> Unit = _
  /// `createBindings( bindGroup, bindings, cacheIndex, version )`.
  fn create_bindings(Self, Backend, BindGroup, Array[BindGroup], String) -> Unit = _
  /// `updateBindings( bindGroup, bindings, cacheKey, version )`.
  fn update_bindings(Self, Backend, BindGroup, Array[BindGroup], String, Int32) -> Unit = _
  /// `updateBinding( binding )`.
  fn update_binding(Self, Backend, Binding) -> Unit = _
  /// `createRenderPipeline( renderObject, promises )`.
  fn create_render_pipeline(Self, Backend, RenderObject, Array[@core.JsValue]?) -> Unit = _
  /// `createComputePipeline( computePipeline, bindings )`.
  fn create_compute_pipeline(
    Self,
    Backend,
    Pipeline,
    Array[BindGroup],
    Array[@core.JsValue]?,
  ) -> Unit = _
  /// `destroyPipeline( pipeline )`.
  fn destroy_pipeline(Self, Backend, Pipeline) -> Unit = _
  /// `needsRenderUpdate( renderObject )`.
  fn needs_render_update(Self, Backend, RenderObject) -> Bool = _
  /// `getRenderCacheKey( renderObject )`.
  fn get_render_cache_key(Self, Backend, RenderObject) -> String = _
  /// `createNodeBuilder( object, renderer )`.
  fn create_node_builder(Self, Backend, BuilderObject, Renderer) -> NodeBuilder = _
  /// `updateSampler( sampler )`: the sampler key.
  fn update_sampler(Self, Backend, Binding) -> String = _
  /// `destroySampler( sampler )`.
  fn destroy_sampler(Self, Backend, Binding) -> Unit = _
  /// `createDefaultTexture( texture )`.
  fn create_default_texture(Self, Backend, @core.Texture) -> Unit = _
  /// `createTexture( texture, options )`.
  fn create_texture(Self, Backend, @core.Texture, TextureOptions) -> Unit = _
  /// `updateTexture( texture, options )`.
  fn update_texture(Self, Backend, @core.Texture, TextureOptions) -> Unit = _
  /// `generateMipmaps( texture )`.
  fn generate_mipmaps(Self, Backend, @core.Texture) -> Unit = _
  /// `destroyTexture( texture, isDefaultTexture )`.
  fn destroy_texture(Self, Backend, @core.Texture, Bool?) -> Unit = _
  /// `createAttribute( attribute )`.
  fn create_attribute(Self, Backend, AttributeBuffer) -> Unit = _
  /// `createIndexAttribute( attribute )`.
  fn create_index_attribute(Self, Backend, AttributeBuffer) -> Unit = _
  /// `createStorageAttribute( attribute )`.
  fn create_storage_attribute(Self, Backend, AttributeBuffer) -> Unit = _
  /// `createIndirectStorageAttribute( attribute )`.
  fn create_indirect_storage_attribute(Self, Backend, AttributeBuffer) -> Unit = _
  /// `createUniformBuffer( uniformBuffer )`.
  fn create_uniform_buffer(Self, Backend, Binding) -> Unit = _
  /// `destroyUniformBuffer( uniformBuffer )`.
  fn destroy_uniform_buffer(Self, Backend, Binding) -> Unit = _
  /// `updateAttribute( attribute )`.
  fn update_attribute(Self, Backend, AttributeBuffer) -> Unit = _
  /// `destroyAttribute( attribute )`.
  fn destroy_attribute(Self, Backend, AttributeBuffer) -> Unit = _
  /// `deleteBindGroupData( bindGroup )`.
  fn delete_bind_group_data(Self, Backend, BindGroup) -> Unit = _
  // The members the renderer calls (G6).
  /// `async init( renderer )`: calls back with `None`, or the error message.
  fn init(Self, Backend, Renderer, (String?) -> Unit) -> Unit = _
  /// `beginRender( renderContext )`.
  fn begin_render(Self, Backend, RenderContext) -> Unit = _
  /// `finishRender( renderContext )`.
  fn finish_render(Self, Backend, RenderContext) -> Unit = _
  /// `setXRTarget( xrTarget )`; `None` is `null`.
  fn set_xr_target(Self, Backend, @core.JsValue?) -> Unit = _
  /// `beginCompute( computeGroup )`.
  fn begin_compute(Self, Backend, ComputeGroup) -> Unit = _
  /// `finishCompute( computeGroup )`.
  fn finish_compute(Self, Backend, ComputeGroup) -> Unit = _
  /// `draw( renderObject, info )`.
  fn draw(Self, Backend, RenderObject, Info) -> Unit = _
  /// `compute( computeGroup, computeNode, computeBindings, computePipeline,
  /// dispatchSize )`.
  fn compute(
    Self,
    Backend,
    ComputeGroup,
    Node,
    Array[BindGroup],
    Pipeline,
    ComputeDispatchSize?,
  ) -> Unit = _
  /// `async copyTextureToBuffer( texture, x, y, width, height, faceIndex )`.
  fn copy_texture_to_buffer(
    Self,
    Backend,
    @core.Texture,
    Int32,
    Int32,
    Int32,
    Int32,
    Int32,
    (@core.TypedArray?) -> Unit,
  ) -> Unit = _
  /// `copyTextureToTexture( srcTexture, dstTexture, srcRegion, dstPosition, srcLevel,
  /// dstLevel )`.
  fn copy_texture_to_texture(
    Self,
    Backend,
    @core.Texture,
    @core.Texture,
    TextureCopyRegion?,
    TextureCopyPosition?,
    Int32,
    Int32,
  ) -> Unit = _
  /// `copyFramebufferToTexture( texture, renderContext, rectangle )`.
  fn copy_framebuffer_to_texture(
    Self,
    Backend,
    @core.Texture,
    FramebufferSource,
    @math.Vector4,
  ) -> Unit = _
  /// `getContext()`; `undefined` by default.
  fn get_context(Self, Backend) -> @core.JsValue = _
  /// `updateSize()`.
  fn update_size(Self, Backend) -> Unit = _
  /// `updateViewport( renderContext )`.
  fn update_viewport(Self, Backend, RenderContext) -> Unit = _
  /// `destroyCanvasTarget( canvasTarget )`.
  fn destroy_canvas_target(Self, Backend, CanvasTarget) -> Unit = _
  /// `isOccluded( renderContext, object )`.
  fn is_occluded(Self, Backend, RenderContext, @core.Object3D) -> Bool = _
  /// `async getArrayBufferAsync( attribute, target, offset, count )`: calls back with
  /// the `ArrayBuffer` (`undefined` by default).
  fn get_array_buffer_async(
    Self,
    Backend,
    AttributeBuffer,
    ReadbackBuffer?,
    Int32,
    Int32,
    (@core.JsValue) -> Unit,
  ) -> Unit = _
  /// `hasFeature( name )`.
  fn has_feature(Self, Backend, String) -> Bool = _
  /// `setScissorTest( boolean )`.
  fn set_scissor_test(Self, Backend, Bool) -> Unit = _
  /// `resetState()`.
  fn reset_state(Self, Backend) -> Unit = _
  /// `initRenderTarget( renderContext )`.
  fn init_render_target(Self, Backend, RenderContext) -> Unit = _
  /// `clear( color, depth, stencil, renderContext )`; `None` is `null`.
  fn clear(Self, Backend, Bool, Bool, Bool, RenderContext?) -> Unit = _
  /// `get hasTimestamp()`.
  fn has_timestamp(Self, Backend) -> Bool = _
  /// `async dispose()`.
  fn dispose(Self, Backend, () -> Unit) -> Unit = _
  /// `backend.capabilities.getMaxAnisotropy()`.
  fn get_max_anisotropy(Self, Backend) -> Int32 = _
  /// Whether the backend has `beginBundle` (`backend.beginBundle !== undefined`).
  fn has_bundles(Self) -> Bool = _
  /// `beginBundle( renderContext )` (WebGPU).
  fn begin_bundle(Self, Backend, RenderContext) -> Unit = _
  /// `finishBundle( renderContext, bundle )` (WebGPU).
  fn finish_bundle(Self, Backend, RenderContext, RenderBundle) -> Unit = _
  /// `addBundle( renderContext, bundle )` (WebGPU).
  fn add_bundle(Self, Backend, RenderContext, RenderBundle) -> Unit = _
  /// `setXRRenderTargetTextures( renderTarget, colorTexture, depthTexture or
  /// viewDescriptors )` (XR).
  fn set_xr_render_target_textures(
    Self,
    Backend,
    @core.RenderTarget,
    @core.JsValue,
    @core.JsValue,
  ) -> Unit = _
  /// `async makeXRCompatible()` (XR).
  fn make_xr_compatible(Self, Backend, () -> Unit) -> Unit = _
  /// `backend.device` (WebGPU; `undefined` otherwise).
  fn device(Self, Backend) -> @core.JsValue = _
  /// `backend.state !== null` with a `bindTexture` (WebGL), for XR foveation.
  fn has_state(Self, Backend) -> Bool = _
  /// `backend.state.bindTexture( glTextureType, textureGPU )` (WebGL).
  fn state_bind_texture(Self, Backend, Int32, @core.JsValue) -> Unit = _
  /// `backend.state.unbindTexture()` (WebGL).
  fn state_unbind_texture(Self, Backend) -> Unit = _
  /// `getClearColor()` (WebGLBackend premultiplies it; added by G10).
  fn get_clear_color(Self, Backend) -> Color4 = _
}

///|
impl BackendClass with fn get_clear_color(_, backend) {
  backend.get_clear_color_base()
}

///|
/// The `computeGroup` of `beginCompute` / `compute` / `finishCompute`: the node or
/// array passed to `renderer.compute`.
pub(all) enum ComputeGroup {
  Node(Node)
  Nodes(Array[Node])
}

///|
/// The JS value of the group (the key of `backend.get( computeGroup )`).
pub fn ComputeGroup::key(self : ComputeGroup) -> @core.JsValue {
  match self {
    Node(n) => @core.JsValue::of(n)
    Nodes(a) => @core.JsValue::of(a)
  }
}

///|
/// `srcRegion` of `copyTextureToTexture`: a `Box2` or a `Box3`.
pub(all) enum TextureCopyRegion {
  Box2(@math.Box2)
  Box3(@math.Box3)
}

///|
/// `dstPosition` of `copyTextureToTexture`: a `Vector2` or a `Vector3`.
pub(all) enum TextureCopyPosition {
  Vec2(@math.Vector2)
  Vec3(@math.Vector3)
}

///|
/// The `renderContext` of `copyFramebufferToTexture`: the current render context, the
/// render target's record when no render is running, or `null` (the canvas).
pub(all) enum FramebufferSource {
  Context(RenderContext)
  TargetData(RenderTargetData)
  NoContext
}

///|
impl BackendClass with fn init(_, backend, renderer, on_done) {
  backend.renderer = Some(renderer)
  on_done(None)
}

///|
impl BackendClass with fn begin_render(_, _, _) {

}

///|
impl BackendClass with fn finish_render(_, _, _) {

}

///|
impl BackendClass with fn set_xr_target(_, _, _) {

}

///|
impl BackendClass with fn begin_compute(_, _, _) {

}

///|
impl BackendClass with fn finish_compute(_, _, _) {

}

///|
impl BackendClass with fn draw(_, _, _, _) {

}

///|
impl BackendClass with fn compute(_, _, _, _, _, _, _) {

}

///|
impl BackendClass with fn copy_texture_to_buffer(
  _,
  _,
  _,
  _,
  _,
  _,
  _,
  _,
  on_done,
) {
  on_done(None)
}

///|
impl BackendClass with fn copy_texture_to_texture(_, _, _, _, _, _, _, _) {

}

///|
impl BackendClass with fn copy_framebuffer_to_texture(_, _, _, _, _) {

}

///|
impl BackendClass with fn get_context(_, _) {
  @core.JsValue::undefined()
}

///|
impl BackendClass with fn update_size(_, _) {

}

///|
impl BackendClass with fn update_viewport(_, _, _) {

}

///|
impl BackendClass with fn destroy_canvas_target(_, _, _) {

}

///|
impl BackendClass with fn is_occluded(_, _, _, _) {
  false
}

///|
impl BackendClass with fn get_array_buffer_async(_, _, _, _, _, _, on_done) {
  on_done(@core.JsValue::undefined())
}

///|
impl BackendClass with fn has_feature(_, _, _) {
  false
}

///|
impl BackendClass with fn set_scissor_test(_, _, _) {

}

///|
impl BackendClass with fn reset_state(_, _) {

}

///|
impl BackendClass with fn init_render_target(_, _, _) {

}

///|
impl BackendClass with fn clear(self, _, _, _, _, _) {
  // the base class has no `clear`; the renderer always calls the backend's
  abort(
    "TypeError: this.backend.clear is not a function (\{self.class_name()})",
  )
}

///|
impl BackendClass with fn has_timestamp(_, _) {
  false
}

///|
impl BackendClass with fn dispose(_, backend, on_done) {
  backend.dispose_base()
  on_done()
}

///|
impl BackendClass with fn get_max_anisotropy(_, _) {
  abort(
    "TypeError: Cannot read properties of undefined (reading 'getMaxAnisotropy')",
  )
}

///|
impl BackendClass with fn has_bundles(_) {
  false
}

///|
impl BackendClass with fn begin_bundle(_, _, _) {
  abort("TypeError: this.backend.beginBundle is not a function")
}

///|
impl BackendClass with fn finish_bundle(_, _, _, _) {
  abort("TypeError: this.backend.finishBundle is not a function")
}

///|
impl BackendClass with fn add_bundle(_, _, _, _) {
  abort("TypeError: this.backend.addBundle is not a function")
}

///|
impl BackendClass with fn set_xr_render_target_textures(_, _, _, _, _) {
  abort(
    "TypeError: renderer.backend.setXRRenderTargetTextures is not a function",
  )
}

///|
impl BackendClass with fn make_xr_compatible(_, _, _) {
  abort("TypeError: renderer.backend.makeXRCompatible is not a function")
}

///|
impl BackendClass with fn device(_, _) {
  @core.JsValue::undefined()
}

///|
impl BackendClass with fn has_state(_, _) {
  false
}

///|
impl BackendClass with fn state_bind_texture(_, _, _, _) {
  abort(
    "TypeError: Cannot read properties of undefined (reading 'bindTexture')",
  )
}

///|
impl BackendClass with fn state_unbind_texture(_, _) {
  abort(
    "TypeError: Cannot read properties of undefined (reading 'unbindTexture')",
  )
}

///|
impl BackendClass with fn payload(self) {
  @core.JsValue::of(self)
}

///|
impl BackendClass with fn has_flag(_, _) {
  false
}

///|
impl BackendClass with fn coordinate_system(self, _) {
  // the base getter returns `undefined`, which no coordinate system constant equals;
  // every backend overrides it
  abort("Backend: \{self.class_name()} has no coordinateSystem")
}

///|
impl BackendClass with fn has_compatibility(_, _, _) {
  false
}

///|
impl BackendClass with fn get_uniform_buffer_limit(_, _) {
  abort(
    "TypeError: Cannot read properties of undefined (reading 'getUniformBufferLimit')",
  )
}

///|
impl BackendClass with fn delete_vertex_state(_, _, _) {

}

///|
impl BackendClass with fn create_program(_, _, _) {

}

///|
impl BackendClass with fn destroy_program(_, _, _) {

}

///|
impl BackendClass with fn create_bindings(_, _, _, _, _) {

}

///|
impl BackendClass with fn update_bindings(_, _, _, _, _, _) {

}

///|
impl BackendClass with fn update_binding(_, _, _) {

}

///|
impl BackendClass with fn create_render_pipeline(_, _, _, _) {

}

///|
impl BackendClass with fn create_compute_pipeline(_, _, _, _, _) {

}

///|
impl BackendClass with fn destroy_pipeline(_, _, _) {

}

///|
impl BackendClass with fn needs_render_update(self, _, _) {
  abort("Backend::needs_render_update: \{self.class_name()} has no body")
}

///|
impl BackendClass with fn get_render_cache_key(self, _, _) {
  abort("Backend::get_render_cache_key: \{self.class_name()} has no body")
}

///|
impl BackendClass with fn create_node_builder(self, _, _, _) {
  abort("Backend::create_node_builder: \{self.class_name()} has no body")
}

///|
impl BackendClass with fn update_sampler(self, _, _) {
  abort("Backend::update_sampler: \{self.class_name()} has no body")
}

///|
impl BackendClass with fn destroy_sampler(_, _, _) {

}

///|
impl BackendClass with fn create_default_texture(_, _, _) {

}

///|
impl BackendClass with fn create_texture(_, _, _, _) {

}

///|
impl BackendClass with fn update_texture(_, _, _, _) {

}

///|
impl BackendClass with fn generate_mipmaps(_, _, _) {

}

///|
impl BackendClass with fn destroy_texture(_, _, _, _) {

}

///|
impl BackendClass with fn create_attribute(_, _, _) {

}

///|
impl BackendClass with fn create_index_attribute(_, _, _) {

}

///|
impl BackendClass with fn create_storage_attribute(_, _, _) {

}

///|
impl BackendClass with fn create_indirect_storage_attribute(_, _, _) {

}

///|
impl BackendClass with fn create_uniform_buffer(_, _, _) {

}

///|
impl BackendClass with fn destroy_uniform_buffer(_, _, _) {

}

///|
impl BackendClass with fn update_attribute(_, _, _) {

}

///|
impl BackendClass with fn destroy_attribute(_, _, _) {

}

///|
impl BackendClass with fn delete_bind_group_data(_, _, _) {

}

///|
pub(all) struct Backend {
  mut class_ : &BackendClass
  /// `data`: the records of `get( object )` (plain JS objects, keyed by identity).
  data : @webgl.WeakMap[@core.JsValue, @core.JsValue]
  /// `renderer`, set by `init( renderer )`.
  mut renderer : Renderer?
  /// `parameters`: a copy of the constructor's parameters object.
  parameters : @core.JsValue
  /// `domElement`; `None` is `null` (created by `getDomElement()`).
  mut dom_element : @core.JsValue?
  /// `timestampQueryPool[ TimestampQuery.RENDER ]`.
  mut timestamp_query_pool_render : TimestampQueryPool?
  /// `timestampQueryPool[ TimestampQuery.COMPUTE ]`.
  mut timestamp_query_pool_compute : TimestampQueryPool?
  mut track_timestamp : Bool
}

///|
extern "js" fn backend_assign_object(
  parameters : @core.JsValue,
) -> @core.JsValue = "(p) => Object.assign( {}, p )"

///|
/// `new Backend( parameters = {} )` with the subclass's members.
pub fn Backend::new(
  class_ : &BackendClass,
  parameters? : @core.JsValue,
) -> Backend {
  let parameters = match parameters {
    Some(p) => p
    None => @core.JsValue::object()
  }
  let track = parameters.get("trackTimestamp")
  {
    class_,
    parameters: backend_assign_object(parameters),
    data: @webgl.WeakMap::new(),
    renderer: None,
    dom_element: None,
    timestamp_query_pool_render: None,
    timestamp_query_pool_compute: None,
    track_timestamp: track.strict_equal(@core.JsValue::of(true)),
  }
}

///|
/// `async init( renderer )`.
pub fn Backend::init(
  self : Backend,
  renderer : Renderer,
  on_done : (String?) -> Unit,
) -> Unit {
  self.class_.init(self, renderer, on_done)
}

///|
pub fn Backend::begin_render(
  self : Backend,
  render_context : RenderContext,
) -> Unit {
  self.class_.begin_render(self, render_context)
}

///|
pub fn Backend::finish_render(
  self : Backend,
  render_context : RenderContext,
) -> Unit {
  self.class_.finish_render(self, render_context)
}

///|
pub fn Backend::set_xr_target(
  self : Backend,
  xr_target : @core.JsValue?,
) -> Unit {
  self.class_.set_xr_target(self, xr_target)
}

///|
pub fn Backend::begin_compute(
  self : Backend,
  compute_group : ComputeGroup,
) -> Unit {
  self.class_.begin_compute(self, compute_group)
}

///|
pub fn Backend::finish_compute(
  self : Backend,
  compute_group : ComputeGroup,
) -> Unit {
  self.class_.finish_compute(self, compute_group)
}

///|
pub fn Backend::draw(
  self : Backend,
  render_object : RenderObject,
  info : Info,
) -> Unit {
  self.class_.draw(self, render_object, info)
}

///|
pub fn Backend::compute(
  self : Backend,
  compute_group : ComputeGroup,
  compute_node : Node,
  compute_bindings : Array[BindGroup],
  compute_pipeline : Pipeline,
  dispatch_size : ComputeDispatchSize?,
) -> Unit {
  self.class_.compute(
    self, compute_group, compute_node, compute_bindings, compute_pipeline, dispatch_size,
  )
}

///|
pub fn Backend::copy_texture_to_buffer(
  self : Backend,
  texture : @core.Texture,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  face_index : Int32,
  on_done : (@core.TypedArray?) -> Unit,
) -> Unit {
  self.class_.copy_texture_to_buffer(
    self, texture, x, y, width, height, face_index, on_done,
  )
}

///|
pub fn Backend::copy_texture_to_texture(
  self : Backend,
  src_texture : @core.Texture,
  dst_texture : @core.Texture,
  src_region : TextureCopyRegion?,
  dst_position : TextureCopyPosition?,
  src_level : Int32,
  dst_level : Int32,
) -> Unit {
  self.class_.copy_texture_to_texture(
    self, src_texture, dst_texture, src_region, dst_position, src_level, dst_level,
  )
}

///|
pub fn Backend::copy_framebuffer_to_texture(
  self : Backend,
  texture : @core.Texture,
  render_context : FramebufferSource,
  rectangle : @math.Vector4,
) -> Unit {
  self.class_.copy_framebuffer_to_texture(
    self, texture, render_context, rectangle,
  )
}

///|
pub fn Backend::get_context(self : Backend) -> @core.JsValue {
  self.class_.get_context(self)
}

///|
pub fn Backend::update_size(self : Backend) -> Unit {
  self.class_.update_size(self)
}

///|
pub fn Backend::update_viewport(
  self : Backend,
  render_context : RenderContext,
) -> Unit {
  self.class_.update_viewport(self, render_context)
}

///|
pub fn Backend::destroy_canvas_target(
  self : Backend,
  canvas_target : CanvasTarget,
) -> Unit {
  self.class_.destroy_canvas_target(self, canvas_target)
}

///|
pub fn Backend::is_occluded(
  self : Backend,
  render_context : RenderContext,
  object : @core.Object3D,
) -> Bool {
  self.class_.is_occluded(self, render_context, object)
}

///|
pub fn Backend::get_array_buffer_async(
  self : Backend,
  attribute : AttributeBuffer,
  target : ReadbackBuffer?,
  offset : Int32,
  count : Int32,
  on_done : (@core.JsValue) -> Unit,
) -> Unit {
  self.class_.get_array_buffer_async(
    self, attribute, target, offset, count, on_done,
  )
}

///|
pub fn Backend::has_feature(self : Backend, name : String) -> Bool {
  self.class_.has_feature(self, name)
}

///|
pub fn Backend::set_scissor_test(self : Backend, boolean : Bool) -> Unit {
  self.class_.set_scissor_test(self, boolean)
}

///|
pub fn Backend::reset_state(self : Backend) -> Unit {
  self.class_.reset_state(self)
}

///|
pub fn Backend::init_render_target(
  self : Backend,
  render_context : RenderContext,
) -> Unit {
  self.class_.init_render_target(self, render_context)
}

///|
pub fn Backend::clear(
  self : Backend,
  color : Bool,
  depth : Bool,
  stencil : Bool,
  render_context : RenderContext?,
) -> Unit {
  self.class_.clear(self, color, depth, stencil, render_context)
}

///|
/// `get hasTimestamp()`.
pub fn Backend::has_timestamp(self : Backend) -> Bool {
  self.class_.has_timestamp(self)
}

///|
/// `async dispose()`.
pub fn Backend::dispose(self : Backend, on_done : () -> Unit) -> Unit {
  self.class_.dispose(self, on_done)
}

///|
/// The base `dispose()`: disposes the timestamp query pools.
pub fn Backend::dispose_base(self : Backend) -> Unit {
  for
    query_pool in [
      self.timestamp_query_pool_render,
      self.timestamp_query_pool_compute,
    ] {
    match query_pool {
      Some(q) => q.dispose()
      None => ()
    }
  }
}

///|
pub fn Backend::get_max_anisotropy(self : Backend) -> Int32 {
  self.class_.get_max_anisotropy(self)
}

///|
pub fn Backend::has_bundles(self : Backend) -> Bool {
  self.class_.has_bundles()
}

///|
pub fn Backend::begin_bundle(
  self : Backend,
  render_context : RenderContext,
) -> Unit {
  self.class_.begin_bundle(self, render_context)
}

///|
pub fn Backend::finish_bundle(
  self : Backend,
  render_context : RenderContext,
  bundle : RenderBundle,
) -> Unit {
  self.class_.finish_bundle(self, render_context, bundle)
}

///|
pub fn Backend::add_bundle(
  self : Backend,
  render_context : RenderContext,
  bundle : RenderBundle,
) -> Unit {
  self.class_.add_bundle(self, render_context, bundle)
}

///|
pub fn Backend::set_xr_render_target_textures(
  self : Backend,
  render_target : @core.RenderTarget,
  color_texture : @core.JsValue,
  depth_texture : @core.JsValue,
) -> Unit {
  self.class_.set_xr_render_target_textures(
    self, render_target, color_texture, depth_texture,
  )
}

///|
pub fn Backend::make_xr_compatible(
  self : Backend,
  on_done : () -> Unit,
) -> Unit {
  self.class_.make_xr_compatible(self, on_done)
}

///|
pub fn Backend::device(self : Backend) -> @core.JsValue {
  self.class_.device(self)
}

///|
/// `updateTimeStampUID( abstractRenderContext )` for a render context.
pub fn Backend::update_time_stamp_uid(
  self : Backend,
  render_context : RenderContext,
) -> Unit {
  let renderer = self.renderer.unwrap()
  let context_data = self.get(@core.JsValue::of(render_context))
  let frame = renderer.info.frame
  let prefix = "r:" + renderer.info.render.frame_calls.to_string()
  context_data.set(
    "timestampUID",
    @core.JsValue::of(
      prefix + ":" + render_context.id.to_string() + ":f" + frame.to_string(),
    ),
  )
}

///|
/// `updateTimeStampUID( abstractRenderContext )` for a compute node or an array of them.
pub fn Backend::update_time_stamp_uid_compute(
  self : Backend,
  compute_group : ComputeGroup,
) -> Unit {
  let renderer = self.renderer.unwrap()
  let context_data = self.get(compute_group.key())
  let frame = renderer.info.frame
  let id = match compute_group {
    Node(n) => n.id.to_string()
    Nodes(a) => a.map(fn(c) { c.id.to_string() }).join(",")
  }
  let prefix = "c:" + renderer.info.compute.frame_calls.to_string()
  context_data.set(
    "timestampUID",
    @core.JsValue::of(prefix + ":" + id + ":f" + frame.to_string()),
  )
}

///|
/// `getTimestampUID( abstractRenderContext )`; `None` is `undefined`.
pub fn Backend::get_timestamp_uid(
  self : Backend,
  abstract_render_context : @core.JsValue,
) -> String? {
  let v = self.get(abstract_render_context).get("timestampUID")
  if v.is_undefined() {
    None
  } else {
    Some(v.cast())
  }
}

///|
/// `getTimestampFrames( type )`.
pub fn Backend::get_timestamp_frames(
  self : Backend,
  type_ : String,
) -> Array[Int32] {
  match self._timestamp_query_pool(type_) {
    Some(query_pool) => query_pool.get_timestamp_frames()
    None => []
  }
}

///|
/// `timestampQueryPool[ type ]`.
fn Backend::_timestamp_query_pool(
  self : Backend,
  type_ : String,
) -> TimestampQueryPool? {
  if type_ == @core.TimestampQuery_RENDER {
    self.timestamp_query_pool_render
  } else if type_ == @core.TimestampQuery_COMPUTE {
    self.timestamp_query_pool_compute
  } else {
    None
  }
}

///|
/// `_getQueryPool( uid )`.
pub fn Backend::_get_query_pool(
  self : Backend,
  uid : String,
) -> TimestampQueryPool? {
  let type_ = if uid.has_prefix("c:") {
    @core.TimestampQuery_COMPUTE
  } else {
    @core.TimestampQuery_RENDER
  }
  self._timestamp_query_pool(type_)
}

///|
/// `getTimestamp( uid )`.
pub fn Backend::get_timestamp(self : Backend, uid : String) -> Double {
  match self._get_query_pool(uid) {
    Some(query_pool) => query_pool.get_timestamp(uid)
    None =>
      abort(
        "TypeError: Cannot read properties of null (reading 'getTimestamp')",
      )
  }
}

///|
/// `hasTimestampQuery( uid )`.
pub fn Backend::has_timestamp_query(self : Backend, uid : String) -> Bool {
  match self._get_query_pool(uid) {
    Some(query_pool) => query_pool.has_timestamp_query(uid)
    None =>
      abort(
        "TypeError: Cannot read properties of null (reading 'hasTimestampQuery')",
      )
  }
}

///|
/// `getOcclusionData( renderContext )`: the per-camera occlusion record.
pub fn Backend::get_occlusion_data(
  self : Backend,
  render_context : RenderContext,
) -> @core.JsValue {
  let render_context_data = self.get(@core.JsValue::of(render_context))
  if render_context_data.get("occlusionData").is_undefined() {
    render_context_data.set("occlusionData", backend_new_weak_map())
  }
  let occlusion_map = render_context_data.get("occlusionData")
  let camera = match render_context.camera {
    Some(c) => @core.JsValue::of(c)
    None => @core.JsValue::undefined()
  }
  let mut occlusion_data = backend_weak_map_get(occlusion_map, camera)
  if occlusion_data.is_undefined() {
    occlusion_data = @core.JsValue::object()
    backend_weak_map_set(occlusion_map, camera, occlusion_data)
  }
  occlusion_data
}

///|
extern "js" fn backend_new_weak_map() -> @core.JsValue = "() => new WeakMap()"

///|
extern "js" fn backend_weak_map_get(
  map : @core.JsValue,
  key : @core.JsValue,
) -> @core.JsValue = "(m, k) => m.get( k )"

///|
extern "js" fn backend_weak_map_set(
  map : @core.JsValue,
  key : @core.JsValue,
  value : @core.JsValue,
) -> Unit = "(m, k, v) => { m.set( k, v ); }"

///|
/// `async resolveTimestampsAsync( type = 'render' )`: calls back with the duration
/// (`None` is `undefined`).
pub fn Backend::resolve_timestamps_async(
  self : Backend,
  type_~ : String = "render",
  on_done : (Double?) -> Unit,
) -> Unit {
  if !self.track_timestamp {
    @core.warn_once("WebGPURenderer: Timestamp tracking is disabled.")
    on_done(None)
    return
  }
  match self._timestamp_query_pool(type_) {
    None => on_done(None)
    Some(query_pool) =>
      query_pool.resolve_queries_async(fn(duration) {
        let renderer = self.renderer.unwrap()
        let value = match duration {
          Some(d) => d
          None => backend_nan()
        }
        if type_ == "compute" {
          renderer.info.compute.timestamp = value
        } else {
          renderer.info.render.timestamp = value
        }
        on_done(duration)
      })
  }
}

///|
let _backend_vector2 : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _backend_color4 : Color4 = Color4::new()

///|
/// `getDrawingBufferSize()`: the renderer's, in a shared vector.
pub fn Backend::get_drawing_buffer_size(self : Backend) -> @math.Vector2 {
  self.renderer.unwrap().get_drawing_buffer_size(_backend_vector2)
}

///|
/// `getClearColor()`: the backend's (`BackendClass::get_clear_color`; the base
/// method by default).
pub fn Backend::get_clear_color(self : Backend) -> Color4 {
  self.class_.get_clear_color(self)
}

///|
/// The base `getClearColor()`: the renderer's clear color in the working color space,
/// in a shared `Color4`.
pub fn Backend::get_clear_color_base(self : Backend) -> Color4 {
  let renderer = self.renderer.unwrap()
  renderer.get_clear_color4(_backend_color4) |> ignore
  _backend_color4.color.get_rgb(_backend_color4.color) |> ignore
  _backend_color4
}

///|
extern "js" fn backend_dom_set_engine(
  dom_element : @core.JsValue,
  value : String,
) -> Unit = "(d, v) => { if ( 'setAttribute' in d ) d.setAttribute( 'data-engine', v ); }"

///|
/// `getDomElement()`: `parameters.canvas`, or a new canvas.
pub fn Backend::get_dom_element(self : Backend) -> @core.JsValue {
  match self.dom_element {
    Some(d) => d
    None => {
      let canvas = self.parameters.get("canvas")
      let dom_element = if !canvas.is_undefined() {
        canvas
      } else {
        @core.JsValue::of(@webgl.create_canvas_element())
      }
      // OffscreenCanvas does not have setAttribute, see #22811
      backend_dom_set_engine(dom_element, "three.js r\{@core.REVISION} webgpu")
      self.dom_element = Some(dom_element)
      dom_element
    }
  }
}

///|
pub fn Backend::coordinate_system(self : Backend) -> Int32 {
  self.class_.coordinate_system(self)
}

///|
/// `backend.capabilities.getUniformBufferLimit()`.
pub fn Backend::get_uniform_buffer_limit(self : Backend) -> Int32 {
  self.class_.get_uniform_buffer_limit(self)
}

///|
/// `hasCompatibility( name )`.
pub fn Backend::has_compatibility(self : Backend, name : String) -> Bool {
  self.class_.has_compatibility(self, name)
}

///|
pub fn Backend::has_flag(self : Backend, flag : String) -> Bool {
  self.class_.has_flag(flag)
}

///|
/// `get( object )`: the object's record, a plain JS object created on first use.
pub fn Backend::get(self : Backend, object : @core.JsValue) -> @core.JsValue {
  match self.data.get(object) {
    Some(map) => map
    None => {
      let map = @core.JsValue::object()
      self.data.set(object, map)
      map
    }
  }
}

///|
/// `set( object, value )`.
pub fn Backend::set(
  self : Backend,
  object : @core.JsValue,
  value : @core.JsValue,
) -> Unit {
  self.data.set(object, value)
}

///|
/// `has( object )`.
pub fn Backend::has(self : Backend, object : @core.JsValue) -> Bool {
  self.data.has(object)
}

///|
/// `delete( object )`.
pub fn Backend::delete(self : Backend, object : @core.JsValue) -> Unit {
  self.data.delete(object)
}

///|
/// `getBufferAttribute( attribute )`: the `InterleavedBuffer` of an interleaved
/// attribute, else the attribute.
pub fn Backend::get_buffer_attribute(
  self : Backend,
  attribute : @core.GeometryAttribute,
) -> AttributeBuffer {
  ignore(self)
  match attribute {
    Buffer(a) => Buffer(a)
    Interleaved(a) => interleaved_attribute_buffer(a)
    GL(a) => GL(a)
  }
}

///|
/// `deleteVertexState( renderObject )`.
pub fn Backend::delete_vertex_state(
  self : Backend,
  render_object : RenderObject,
) -> Unit {
  self.class_.delete_vertex_state(self, render_object)
}

///|
/// `createProgram( program )`.
pub fn Backend::create_program(
  self : Backend,
  program : ProgrammableStage,
) -> Unit {
  self.class_.create_program(self, program)
}

///|
/// `destroyProgram( program )`.
pub fn Backend::destroy_program(
  self : Backend,
  program : ProgrammableStage,
) -> Unit {
  self.class_.destroy_program(self, program)
}

///|
/// `createBindings( bindGroup, bindings, cacheIndex )`.
pub fn Backend::create_bindings(
  self : Backend,
  bind_group : BindGroup,
  bindings : Array[BindGroup],
  cache_index : String,
) -> Unit {
  self.class_.create_bindings(self, bind_group, bindings, cache_index)
}

///|
/// `updateBindings( bindGroup, bindings, cacheKey, version )`.
pub fn Backend::update_bindings(
  self : Backend,
  bind_group : BindGroup,
  bindings : Array[BindGroup],
  cache_key : String,
  version : Int32,
) -> Unit {
  self.class_.update_bindings(self, bind_group, bindings, cache_key, version)
}

///|
/// `updateBinding( binding )`.
pub fn Backend::update_binding(self : Backend, binding : Binding) -> Unit {
  self.class_.update_binding(self, binding)
}

///|
/// `createRenderPipeline( renderObject, promises )`.
pub fn Backend::create_render_pipeline(
  self : Backend,
  render_object : RenderObject,
  promises : Array[@core.JsValue]?,
) -> Unit {
  self.class_.create_render_pipeline(self, render_object, promises)
}

///|
/// `createComputePipeline( computePipeline, bindings )`.
pub fn Backend::create_compute_pipeline(
  self : Backend,
  pipeline : Pipeline,
  bindings : Array[BindGroup],
  promises : Array[@core.JsValue]?,
) -> Unit {
  self.class_.create_compute_pipeline(self, pipeline, bindings, promises)
}

///|
/// `destroyPipeline( pipeline )`.
pub fn Backend::destroy_pipeline(self : Backend, pipeline : Pipeline) -> Unit {
  self.class_.destroy_pipeline(self, pipeline)
}

///|
/// `needsRenderUpdate( renderObject )`.
pub fn Backend::needs_render_update(
  self : Backend,
  render_object : RenderObject,
) -> Bool {
  self.class_.needs_render_update(self, render_object)
}

///|
/// `getRenderCacheKey( renderObject )`.
pub fn Backend::get_render_cache_key(
  self : Backend,
  render_object : RenderObject,
) -> String {
  self.class_.get_render_cache_key(self, render_object)
}

///|
/// `createNodeBuilder( object, renderer )`.
pub fn Backend::create_node_builder(
  self : Backend,
  object : BuilderObject,
  renderer : Renderer,
) -> NodeBuilder {
  self.class_.create_node_builder(self, object, renderer)
}

///|
/// `updateSampler( sampler )`.
pub fn Backend::update_sampler(self : Backend, sampler : Binding) -> String {
  self.class_.update_sampler(self, sampler)
}

///|
/// `destroySampler( sampler )`.
pub fn Backend::destroy_sampler(self : Backend, sampler : Binding) -> Unit {
  self.class_.destroy_sampler(self, sampler)
}

///|
/// `createDefaultTexture( texture )`.
pub fn Backend::create_default_texture(
  self : Backend,
  texture : @core.Texture,
) -> Unit {
  self.class_.create_default_texture(self, texture)
}

///|
/// `createTexture( texture, options )`.
pub fn Backend::create_texture(
  self : Backend,
  texture : @core.Texture,
  options : TextureOptions,
) -> Unit {
  self.class_.create_texture(self, texture, options)
}

///|
/// `updateTexture( texture, options )`.
pub fn Backend::update_texture(
  self : Backend,
  texture : @core.Texture,
  options : TextureOptions,
) -> Unit {
  self.class_.update_texture(self, texture, options)
}

///|
/// `generateMipmaps( texture )`.
pub fn Backend::generate_mipmaps(
  self : Backend,
  texture : @core.Texture,
) -> Unit {
  self.class_.generate_mipmaps(self, texture)
}

///|
/// `destroyTexture( texture, isDefaultTexture )`; `None` is `undefined`.
pub fn Backend::destroy_texture(
  self : Backend,
  texture : @core.Texture,
  is_default_texture? : Bool,
) -> Unit {
  self.class_.destroy_texture(self, texture, is_default_texture)
}

///|
/// `createAttribute( attribute )`.
pub fn Backend::create_attribute(
  self : Backend,
  attribute : AttributeBuffer,
) -> Unit {
  self.class_.create_attribute(self, attribute)
}

///|
/// `createIndexAttribute( attribute )`.
pub fn Backend::create_index_attribute(
  self : Backend,
  attribute : AttributeBuffer,
) -> Unit {
  self.class_.create_index_attribute(self, attribute)
}

///|
/// `createStorageAttribute( attribute )`.
pub fn Backend::create_storage_attribute(
  self : Backend,
  attribute : AttributeBuffer,
) -> Unit {
  self.class_.create_storage_attribute(self, attribute)
}

///|
/// `createIndirectStorageAttribute( attribute )`.
pub fn Backend::create_indirect_storage_attribute(
  self : Backend,
  attribute : AttributeBuffer,
) -> Unit {
  self.class_.create_indirect_storage_attribute(self, attribute)
}

///|
/// `createUniformBuffer( uniformBuffer )`.
pub fn Backend::create_uniform_buffer(
  self : Backend,
  uniform_buffer : Binding,
) -> Unit {
  self.class_.create_uniform_buffer(self, uniform_buffer)
}

///|
/// `destroyUniformBuffer( uniformBuffer )`.
pub fn Backend::destroy_uniform_buffer(
  self : Backend,
  uniform_buffer : Binding,
) -> Unit {
  self.class_.destroy_uniform_buffer(self, uniform_buffer)
}

///|
/// `updateAttribute( attribute )`.
pub fn Backend::update_attribute(
  self : Backend,
  attribute : AttributeBuffer,
) -> Unit {
  self.class_.update_attribute(self, attribute)
}

///|
/// `destroyAttribute( attribute )`.
pub fn Backend::destroy_attribute(
  self : Backend,
  attribute : AttributeBuffer,
) -> Unit {
  self.class_.destroy_attribute(self, attribute)
}

///|
/// `deleteBindGroupData( bindGroup )`.
pub fn Backend::delete_bind_group_data(
  self : Backend,
  bind_group : BindGroup,
) -> Unit {
  self.class_.delete_bind_group_data(self, bind_group)
}

///|
extern "js" fn backend_nan() -> Double = "() => NaN"
