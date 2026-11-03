// renderers/common/nodes/NodeManager.js: builds and caches the node builds of render
// objects and compute nodes, and the scene's environment, background and fog nodes.

///|
/// `_outputLayerIndex`: the array layer `getOutputNode` reads for array outputs.
let _node_manager_output_layer_index : Node = module_nodes(
  "renderers/common/nodes/NodeManager.js:_outputLayerIndex",
  fn() { uniform(0, type_="int").set_group(render_group) },
)

///|
/// What a node builder is created for: the second argument of
/// `renderer.debug.onNodeBuilderCreated`.
pub(all) enum NodeBuilderOwner {
  RenderObject(RenderObject)
  Compute(Node)
}

///|
/// The record of a render object in `NodeManager`.
pub(all) struct NodeManagerRenderObjectData {
  mut node_builder_state : NodeBuilderState?
  mut pending_build : Bool?
}

///|
/// The record of a compute node in `NodeManager`.
pub(all) struct NodeManagerComputeData {
  mut node_builder_state : NodeBuilderState?
  mut version : Int32?
}

///|
/// The record of a scene in `NodeManager`.
pub(all) struct NodeManagerSceneData {
  mut environment_node : Node?
  mut environment : @core.Texture?
  mut background_node : Node?
  mut background : @core.SceneBackground?
  mut background_blurriness : Double?
  mut fog_node : Node?
  mut fog : @core.SceneFog?
}

///|
/// The record of a material in `NodeManager`.
pub(all) struct NodeManagerMaterialData {
  mut cache_key_version : Int32?
  mut cache_key : String?
}

///|
/// `{ callId, cacheKey }` of `callHashCache`.
priv struct NodeManagerCallHash {
  mut call_id : Int32?
  mut cache_key : Double
}

///|
/// `{ version }` of `groupsData`.
priv struct NodeManagerGroupData {
  mut version : Int32?
}

///|
/// Node builds and scene nodes of a renderer.
pub struct NodeManager {
  priv render_objects : DataMap[RenderObject, NodeManagerRenderObjectData]
  priv compute_nodes : DataMap[Node, NodeManagerComputeData]
  priv scenes : DataMap[@core.Object3D, NodeManagerSceneData]
  priv materials : DataMap[@core.Material, NodeManagerMaterialData]
  renderer : Renderer
  backend : Backend
  mut node_frame : NodeFrame
  /// Builds shared by render objects with the same cache key.
  mut node_builder_cache : Map[Double, NodeBuilderState]
  priv call_hash_cache : ChainMap[NodeManagerCallHash]
  priv groups_data : ChainMap[NodeManagerGroupData]
  priv _build_queue : Array[(() -> Unit) -> Unit]
  priv mut _build_in_progress : Bool
  priv mut cache_lib : Map[String, @webgl.WeakMap[@core.JsValue, Node]]
}

///|
/// `new NodeManager( renderer, backend )`.
pub fn NodeManager::new(renderer : Renderer, backend : Backend) -> NodeManager {
  {
    render_objects: DataMap::new(fn() {
      { node_builder_state: None, pending_build: None, }
    }),
    compute_nodes: DataMap::new(fn() {
      { node_builder_state: None, version: None, }
    }),
    scenes: DataMap::new(fn() {
      {
        environment_node: None,
        environment: None,
        background_node: None,
        background: None,
        background_blurriness: None,
        fog_node: None,
        fog: None,
      }
    }),
    materials: DataMap::new(fn() {
      { cache_key_version: None, cache_key: None, }
    }),
    renderer,
    backend,
    node_frame: NodeFrame::new(),
    node_builder_cache: Map([]),
    call_hash_cache: ChainMap::new(),
    groups_data: ChainMap::new(),
    _build_queue: [],
    _build_in_progress: false,
    cache_lib: Map([]),
  }
}

///|
/// `get( renderObject )`.
pub fn NodeManager::get(
  self : NodeManager,
  render_object : RenderObject,
) -> NodeManagerRenderObjectData {
  self.render_objects.get(render_object)
}

///|
/// `get( computeNode )`.
pub fn NodeManager::get_compute(
  self : NodeManager,
  compute_node : Node,
) -> NodeManagerComputeData {
  self.compute_nodes.get(compute_node)
}

///|
/// `get( scene )`.
pub fn NodeManager::get_scene(
  self : NodeManager,
  scene : @core.Object3D,
) -> NodeManagerSceneData {
  self.scenes.get(scene)
}

///|
/// `get( material )`.
pub fn NodeManager::get_material(
  self : NodeManager,
  material : @core.Material,
) -> NodeManagerMaterialData {
  self.materials.get(material)
}

///|
/// `updateGroup( nodeUniformsGroup )`: whether the group's uniforms need an update.
pub fn NodeManager::update_group(
  self : NodeManager,
  node_uniforms_group : Binding,
) -> Bool {
  let group_node = match node_uniforms_group.group_node() {
    Some(g) => g
    None =>
      abort(
        "TypeError: Cannot read properties of undefined (reading 'updateType')",
      )
  }
  if group_node.update_type == NodeUpdateType::object() {
    return true
  }
  let chain_keys = [
    @core.JsValue::of(group_node),
    @core.JsValue::of(node_uniforms_group),
  ]
  let group_data = match self.groups_data.get(chain_keys) {
    Some(d) => d
    None => {
      let d = { version: None, }
      self.groups_data.set(chain_keys, d) |> ignore
      d
    }
  }
  if group_data.version != Some(group_node.version) {
    group_data.version = Some(group_node.version)
    return true
  }
  false
}

///|
/// `getForRenderCacheKey( renderObject )`.
pub fn NodeManager::get_for_render_cache_key(
  self : NodeManager,
  render_object : RenderObject,
) -> Double {
  ignore(self)
  render_object.initial_cache_key
}

///|
/// `_createNodeBuilder( renderObject, material )`.
pub fn NodeManager::_create_node_builder(
  self : NodeManager,
  render_object : RenderObject,
  material : @core.Material,
) -> NodeBuilder {
  let node_builder = self.backend.create_node_builder(
    Object3D(render_object.object),
    self.renderer,
  )
  match self.renderer.debug.on_node_builder_created {
    Some(f) => f(node_builder, RenderObject(render_object))
    None => ()
  }
  node_builder.scene = Some(render_object.scene)
  node_builder.material = Some(material)
  node_builder.camera = Some(render_object.camera)
  node_builder.context.set("material", Material(material))
  node_builder.lights_node = Some(render_object.lights_node)
  node_builder.environment_node = self.get_environment_node(render_object.scene)
  node_builder.fog_node = self.get_fog_node(render_object.scene)
  node_builder.clipping_context = render_object.clipping_context
  match self.renderer.get_output_render_target() {
    Some(rt) if rt.multiview => node_builder.enable_multiview()
    _ => ()
  }
  node_builder
}

///|
/// `_reportBuildError( e )`.
pub fn NodeManager::_report_build_error(self : NodeManager, e : String) -> Unit {
  ignore(self)
  @core.error("TSL: " + e)
}

///|
/// `nodeBuilder.build()`, rebuilt with a default `NodeMaterial` when it throws.
fn NodeManager::_build_with_fallback(
  self : NodeManager,
  render_object : RenderObject,
) -> NodeBuilder {
  let mut node_builder = self._create_node_builder(
    render_object,
    render_object.material,
  )
  let error = @webgl.js_try(fn() { node_builder.build() |> ignore })
  match error {
    Some(e) => {
      node_builder = self._create_node_builder(
        render_object,
        NodeMaterial::new(),
      )
      node_builder.build() |> ignore
      self._report_build_error(e)
    }
    None => ()
  }
  node_builder
}

///|
/// `getForRender( renderObject )`: the render object's node build, built once per
/// cache key.
pub fn NodeManager::get_for_render(
  self : NodeManager,
  render_object : RenderObject,
) -> NodeBuilderState {
  let render_object_data = self.get(render_object)
  match render_object_data.node_builder_state {
    Some(state) => state
    None => {
      let node_builder_cache = self.node_builder_cache
      let cache_key = self.get_for_render_cache_key(render_object)
      let node_builder_state = match node_builder_cache.get(cache_key) {
        Some(state) => state
        None => {
          let node_builder = self._build_with_fallback(render_object)
          let state = self._create_node_builder_state(node_builder)
          if node_builder.object_specific == false {
            node_builder_cache.set(cache_key, state)
          }
          state
        }
      }
      node_builder_state.used_times += 1
      render_object_data.node_builder_state = Some(node_builder_state)
      node_builder_state
    }
  }
}

///|
/// `getForRender( renderObject, yieldFn )` and `getForRenderAsync( renderObject,
/// yieldFn )`: builds with `buildAsync`, then calls `on_done` with the state.
pub fn NodeManager::get_for_render_async(
  self : NodeManager,
  render_object : RenderObject,
  on_done : (NodeBuilderState) -> Unit,
  yield_fn? : (() -> Unit) -> Unit,
) -> Unit {
  let render_object_data = self.get(render_object)
  match render_object_data.node_builder_state {
    Some(state) => on_done(state)
    None => {
      let node_builder_cache = self.node_builder_cache
      let cache_key = self.get_for_render_cache_key(render_object)
      match node_builder_cache.get(cache_key) {
        Some(state) => {
          state.used_times += 1
          render_object_data.node_builder_state = Some(state)
          on_done(state)
        }
        None => {
          let finish = fn(node_builder : NodeBuilder) {
            let state = self._create_node_builder_state(node_builder)
            if node_builder.object_specific == false {
              node_builder_cache.set(cache_key, state)
            }
            state.used_times += 1
            render_object_data.node_builder_state = Some(state)
            on_done(state)
          }
          let node_builder = self._create_node_builder(
            render_object,
            render_object.material,
          )
          let error = @webgl.js_try(fn() {
            node_builder.build_async(finish, yield_fn?)
          })
          match error {
            Some(e) => {
              let fallback = self._create_node_builder(
                render_object,
                NodeMaterial::new(),
              )
              fallback.build_async(
                fn(b) {
                  self._report_build_error(e)
                  finish(b)
                },
                yield_fn?,
              )
            }
            None => ()
          }
        }
      }
    }
  }
}

///|
/// `getForRenderDeferred( renderObject )`: the build if ready, else queues an async
/// build and returns `None` (`null`).
pub fn NodeManager::get_for_render_deferred(
  self : NodeManager,
  render_object : RenderObject,
) -> NodeBuilderState? {
  let render_object_data = self.get(render_object)
  match render_object_data.node_builder_state {
    Some(state) => return Some(state)
    None => ()
  }
  let cache_key = self.get_for_render_cache_key(render_object)
  match self.node_builder_cache.get(cache_key) {
    Some(state) => {
      state.used_times += 1
      render_object_data.node_builder_state = Some(state)
      return Some(state)
    }
    None => ()
  }
  if render_object_data.pending_build != Some(true) {
    render_object_data.pending_build = Some(true)
    self._build_queue.push(fn(done) {
      self.get_for_render_async(render_object, fn(_) {
        render_object_data.pending_build = Some(false)
        done()
      })
    })
    self._process_build_queue()
  }
  None // Not ready
}

///|
/// `_processBuildQueue()`: runs the queued builds one at a time.
pub fn NodeManager::_process_build_queue(self : NodeManager) -> Unit {
  if self._build_in_progress || self._build_queue.length() == 0 {
    return
  }
  self._build_in_progress = true
  let build_fn = self._build_queue.remove(0)
  build_fn(fn() {
    self._build_in_progress = false
    self._process_build_queue()
  })
}

///|
/// `delete( renderObject )`: releases the render object's build.
pub fn NodeManager::delete(
  self : NodeManager,
  render_object : RenderObject,
) -> NodeManagerRenderObjectData? {
  match self.get(render_object).node_builder_state {
    Some(node_builder_state) => {
      node_builder_state.used_times -= 1
      if node_builder_state.used_times == 0 {
        self.node_builder_cache.remove(
          self.get_for_render_cache_key(render_object),
        )
      }
    }
    None => ()
  }
  self.render_objects.delete(render_object)
}

///|
/// `delete( computeNode )`.
pub fn NodeManager::delete_compute(
  self : NodeManager,
  compute_node : Node,
) -> NodeManagerComputeData? {
  self.compute_nodes.delete(compute_node)
}

///|
/// The compute node's builder, as `getForCompute` creates it.
fn NodeManager::_create_compute_node_builder(
  self : NodeManager,
  compute_node : Node,
) -> NodeBuilder {
  let node_builder = self.backend.create_node_builder(NoObject, self.renderer)
  node_builder.compute = Some(compute_node)
  match self.renderer.debug.on_node_builder_created {
    Some(f) => f(node_builder, Compute(compute_node))
    None => ()
  }
  node_builder
}

///|
/// `getForCompute( computeNode )`: the compute node's build, rebuilt when its version
/// changed.
pub fn NodeManager::get_for_compute(
  self : NodeManager,
  compute_node : Node,
) -> NodeBuilderState {
  let compute_data = self.get_compute(compute_node)
  match compute_data.node_builder_state {
    Some(state) if compute_data.version == Some(compute_node.version) => state
    _ => {
      let node_builder = self._create_compute_node_builder(compute_node)
      node_builder.build() |> ignore
      let state = self._create_node_builder_state(node_builder)
      compute_data.node_builder_state = Some(state)
      compute_data.version = Some(compute_node.version)
      state
    }
  }
}

///|
/// `getForCompute( computeNode, true, yieldFn )` / `getForComputeAsync`.
pub fn NodeManager::get_for_compute_async(
  self : NodeManager,
  compute_node : Node,
  on_done : (NodeBuilderState) -> Unit,
  yield_fn? : (() -> Unit) -> Unit,
) -> Unit {
  let compute_data = self.get_compute(compute_node)
  match compute_data.node_builder_state {
    Some(state) if compute_data.version == Some(compute_node.version) =>
      on_done(state)
    _ => {
      let node_builder = self._create_compute_node_builder(compute_node)
      node_builder.build_async(
        fn(b) {
          let state = self._create_node_builder_state(b)
          compute_data.node_builder_state = Some(state)
          compute_data.version = Some(compute_node.version)
          on_done(state)
        },
        yield_fn?,
      )
    }
  }
}

///|
/// `_createNodeBuilderState( nodeBuilder )`.
pub fn NodeManager::_create_node_builder_state(
  self : NodeManager,
  node_builder : NodeBuilder,
) -> NodeBuilderState {
  ignore(self)
  NodeBuilderState::new(
    node_builder.vertex_shader,
    node_builder.fragment_shader,
    node_builder.compute_shader,
    node_builder.get_attributes_array(),
    node_builder.get_bindings(),
    node_builder.update_nodes,
    node_builder.update_before_nodes,
    node_builder.update_after_nodes,
    node_builder.observer,
    node_builder.hardware_clipping,
    transforms=node_builder.transforms(),
  )
}

///|
fn _node_manager_scene(scene : @core.Object3D) -> @core.Scene? {
  match scene.kind {
    Scene(s) => Some(s)
    _ => None
  }
}

///|
/// A scene's `backgroundNode`, `environmentNode` or `fogNode` set by the application.
fn _node_manager_scene_node(value : @core.JsValue?) -> Node? {
  match value {
    Some(v) if !v.is_null() && !v.is_undefined() => Some(v.cast())
    _ => None
  }
}

///|
/// `getEnvironmentNode( scene )`; `None` is `null`.
pub fn NodeManager::get_environment_node(
  self : NodeManager,
  scene : @core.Object3D,
) -> Node? {
  if self.renderer.lighting.enabled == false {
    return None
  }
  self.update_environment(scene)
  match _node_manager_scene(scene) {
    Some(s) =>
      match _node_manager_scene_node(s.environment_node) {
        Some(node) => return Some(node)
        None => ()
      }
    None => ()
  }
  self.get_scene(scene).environment_node
}

///|
/// `getBackgroundNode( scene )`; `None` is `null`.
pub fn NodeManager::get_background_node(
  self : NodeManager,
  scene : @core.Object3D,
) -> Node? {
  self.update_background(scene)
  match _node_manager_scene(scene) {
    Some(s) =>
      match _node_manager_scene_node(s.background_node) {
        Some(node) => return Some(node)
        None => ()
      }
    None => ()
  }
  self.get_scene(scene).background_node
}

///|
/// `getFogNode( scene )`; `None` is `null`.
pub fn NodeManager::get_fog_node(
  self : NodeManager,
  scene : @core.Object3D,
) -> Node? {
  self.update_fog(scene)
  match _node_manager_scene(scene) {
    Some(s) =>
      match _node_manager_scene_node(s.fog_node) {
        Some(node) => return Some(node)
        None => ()
      }
    None => ()
  }
  self.get_scene(scene).fog_node
}

///|
/// `getCustomProgramCacheKey( material, scene )`: `material.customProgramCacheKey()`,
/// cached per material version (except for the scene's override material).
pub fn NodeManager::get_custom_program_cache_key(
  self : NodeManager,
  material : @core.Material,
  scene : @core.Object3D,
) -> String {
  let is_override = match _node_manager_scene(scene) {
    Some({ override_material: Some(m), .. }) => physical_equal(m, material)
    _ => false
  }
  if is_override {
    material.custom_program_cache_key()
  } else {
    let material_data = self.get_material(material)
    if material_data.cache_key_version != Some(material.version) {
      material_data.cache_key_version = Some(material.version)
      material_data.cache_key = Some(material.custom_program_cache_key())
    }
    material_data.cache_key.unwrap()
  }
}

///|
/// `getCacheKey( scene, lightsNode )`: the hash of the scene state that changes
/// shaders, computed once per render call.
pub fn NodeManager::get_cache_key(
  self : NodeManager,
  scene : @core.Object3D,
  lights_node : Node,
) -> Double {
  let chain_keys = [@core.JsValue::of(scene), @core.JsValue::of(lights_node)]
  let call_id = self.renderer.info.calls
  let cache_key_data = match self.call_hash_cache.get(chain_keys) {
    Some(d) => d
    None => { call_id: None, cache_key: 0.0, }
  }
  if cache_key_data.call_id != Some(call_id) {
    let cache_key_values = []
    let multiview = match self.renderer.get_output_render_target() {
      Some(rt) => rt.multiview
      None => false
    }
    cache_key_values.push(if multiview { 1.0 } else { 0.0 })
    let lighting_enabled = self.renderer.lighting.enabled
    cache_key_values.push(if lighting_enabled { 1.0 } else { 0.0 })
    if lighting_enabled {
      cache_key_values.push(lights_node.get_cache_key(force=true))
      cache_key_values.push(
        if self.renderer.shadow_map.enabled {
          1.0
        } else {
          0.0
        },
      )
      cache_key_values.push(self.renderer.shadow_map.type_.to_double())
      match self.get_environment_node(scene) {
        Some(environment_node) =>
          cache_key_values.push(environment_node.get_cache_key())
        None => ()
      }
    }
    match self.get_fog_node(scene) {
      Some(fog_node) => cache_key_values.push(fog_node.get_cache_key())
      None => ()
    }
    cache_key_data.call_id = Some(call_id)
    cache_key_data.cache_key = hash_array(cache_key_values)
    self.call_hash_cache.set(chain_keys, cache_key_data) |> ignore
  }
  cache_key_data.cache_key
}

///|
/// `get isToneMappingState()`.
pub fn NodeManager::is_tone_mapping_state(self : NodeManager) -> Bool {
  self.renderer.get_render_target() is None
}

///|
/// `scene.background === background` for the recorded background.
fn _node_manager_same_background(
  a : @core.SceneBackground?,
  b : @core.SceneBackground,
) -> Bool {
  match (a, b) {
    (Some(Color(x)), Color(y)) => physical_equal(x, y)
    (Some(Texture(x)), Texture(y)) => physical_equal(x, y)
    _ => false
  }
}

///|
/// `updateBackground( scene )`.
pub fn NodeManager::update_background(
  self : NodeManager,
  scene : @core.Object3D,
) -> Unit {
  let scene_data = self.get_scene(scene)
  let s = match _node_manager_scene(scene) {
    Some(s) => s
    None => return
  }
  match s.background {
    Some(background) => {
      let previous_blurriness = scene_data.background_blurriness
      let force_update = (
          s.background_blurriness == 0.0 &&
          previous_blurriness.unwrap_or(0.0) > 0.0
        ) ||
        (s.background_blurriness > 0.0 && previous_blurriness == Some(0.0))
      if !_node_manager_same_background(scene_data.background, background) ||
        force_update {
        let background_node = match background {
          Texture(texture) =>
            Some(
              self.get_cache_node(
                "background",
                @core.JsValue::of(texture),
                Some(texture),
                fn() {
                  if texture.is_cube_texture() ||
                    texture.mapping == @core.EquirectangularReflectionMapping ||
                    texture.mapping == @core.EquirectangularRefractionMapping {
                    if s.background_blurriness > 0.0 || texture.is_pmrem_texture {
                      _node_manager_pmrem_texture(texture)
                    } else {
                      let env_map = if texture.is_cube_texture() {
                        _node_manager_cube_texture(texture)
                      } else {
                        _node_manager_texture(texture, None)
                      }
                      _node_manager_cube_map_node(env_map)
                    }
                  } else {
                    _node_manager_screen_texture(texture)
                  }
                },
                force_update~,
              ),
            )
          Color(_) => None
        }
        scene_data.background_node = background_node
        scene_data.background = Some(background)
        scene_data.background_blurriness = Some(s.background_blurriness)
      }
    }
    None =>
      if scene_data.background_node is Some(_) {
        scene_data.background_node = None
        scene_data.background = None
      }
  }
}

///|
/// `getCacheNode( type, object, callback, forceUpdate = false )`: a node cached per
/// object; texture entries are dropped (and disposed) with the texture.
pub fn NodeManager::get_cache_node(
  self : NodeManager,
  type_ : String,
  object : @core.JsValue,
  texture : @core.Texture?,
  callback : () -> Node,
  force_update~ : Bool = false,
) -> Node {
  let node_cache = match self.cache_lib.get(type_) {
    Some(c) => c
    None => {
      let c = @webgl.WeakMap::new()
      self.cache_lib.set(type_, c)
      c
    }
  }
  let node = node_cache.get(object)
  match node {
    Some(node) if !force_update => node
    _ => {
      if node is None {
        match texture {
          Some(t) => {
            fn on_texture_dispose(_e : @core.Event) -> Unit {
              t.remove_event_listener("dispose", on_texture_dispose)
              match node_cache.get(object) {
                Some(node) => {
                  node_cache.delete(object)
                  node.dispose()
                }
                None => ()
              }
            }

            t.add_event_listener("dispose", on_texture_dispose)
          }
          None => ()
        }
      }
      let node = callback()
      node_cache.set(object, node)
      node
    }
  }
}

///|
/// `scene.fog === fog` for the recorded fog.
fn _node_manager_same_fog(a : @core.SceneFog?, b : @core.SceneFog) -> Bool {
  match (a, b) {
    (Some(Fog(x)), Fog(y)) => physical_equal(x, y)
    (Some(FogExp2(x)), FogExp2(y)) => physical_equal(x, y)
    _ => false
  }
}

///|
/// `updateFog( scene )`.
pub fn NodeManager::update_fog(
  self : NodeManager,
  scene : @core.Object3D,
) -> Unit {
  let scene_data = self.get_scene(scene)
  let s = match _node_manager_scene(scene) {
    Some(s) => s
    None => return
  }
  match s.fog {
    Some(scene_fog) =>
      if !_node_manager_same_fog(scene_data.fog, scene_fog) {
        let key = match scene_fog {
          Fog(f) => @core.JsValue::of(f)
          FogExp2(f) => @core.JsValue::of(f)
        }
        let fog_node = self.get_cache_node("fog", key, None, fn() {
          _node_manager_fog_node(scene_fog)
        })
        scene_data.fog_node = Some(fog_node)
        scene_data.fog = Some(scene_fog)
      }
    None => {
      scene_data.fog_node = None
      scene_data.fog = None
    }
  }
}

///|
/// `updateEnvironment( scene )`.
pub fn NodeManager::update_environment(
  self : NodeManager,
  scene : @core.Object3D,
) -> Unit {
  let scene_data = self.get_scene(scene)
  let s = match _node_manager_scene(scene) {
    Some(s) => s
    None => return
  }
  match s.environment {
    Some(environment) => {
      let same = match scene_data.environment {
        Some(e) => physical_equal(e, environment)
        None => false
      }
      if !same {
        let environment_node = self.get_cache_node(
          "environment",
          @core.JsValue::of(environment),
          Some(environment),
          fn() {
            if environment.is_cube_texture() {
              _node_manager_cube_texture(environment)
            } else {
              _node_manager_texture(environment, None)
            }
          },
        )
        scene_data.environment_node = Some(environment_node)
        scene_data.environment = Some(environment)
      }
    }
    None =>
      if scene_data.environment_node is Some(_) {
        scene_data.environment_node = None
        scene_data.environment = None
      }
  }
}

///|
/// `getNodeFrame( renderer = this.renderer, scene = null, object = null, camera = null,
/// material = null, compute = null )`.
pub fn NodeManager::get_node_frame(
  self : NodeManager,
  renderer? : Renderer,
  scene? : @core.Object3D,
  object? : @core.Object3D,
  camera? : @core.Object3D,
  material? : @core.Material,
  compute? : Node,
) -> NodeFrame {
  let node_frame = self.node_frame
  node_frame.renderer = Some(
    match renderer {
      Some(r) => r
      None => self.renderer
    },
  )
  node_frame.scene = scene
  node_frame.object = object
  node_frame.camera = camera
  node_frame.material = material
  node_frame.compute = compute
  node_frame
}

///|
/// `getNodeFrameForRender( renderObject )`.
pub fn NodeManager::get_node_frame_for_render(
  self : NodeManager,
  render_object : RenderObject,
) -> NodeFrame {
  self.get_node_frame(
    renderer=render_object.renderer,
    scene=render_object.scene,
    object=render_object.object,
    camera=render_object.camera,
    material=render_object.material,
  )
}

///|
/// `getNodeFrameForCompute( computeNode )`.
pub fn NodeManager::get_node_frame_for_compute(
  self : NodeManager,
  compute_node : Node,
) -> NodeFrame {
  self.get_node_frame(renderer=self.renderer, compute=compute_node)
}

///|
/// `getOutputCacheKey()`.
pub fn NodeManager::get_output_cache_key(self : NodeManager) -> String {
  let renderer = self.renderer
  renderer.tone_mapping.to_string() +
  "," +
  renderer.current_color_space() +
  "," +
  renderer.xr_is_presenting().to_string()
}

///|
/// `getOutputNode( outputTarget )`: samples the output texture with tone mapping and
/// color space conversion.
pub fn NodeManager::get_output_node(
  self : NodeManager,
  output_target : @core.Texture,
) -> Node {
  let renderer = self.renderer
  _node_manager_output_node(
    output_target,
    output_target.is_array_texture,
    self.backend.has_flag("isWebGLBackend"),
    renderer.tone_mapping,
    renderer.current_color_space(),
  )
}

///|
/// `setOutputLayerIndex( index )`.
pub fn NodeManager::set_output_layer_index(
  self : NodeManager,
  index : Int32,
) -> Unit {
  ignore(self)
  InputNode::set_value(
    _node_manager_output_layer_index,
    Number(index.to_double()),
  )
}

///|
/// `updateBefore( renderObject )`.
pub fn NodeManager::update_before(
  self : NodeManager,
  render_object : RenderObject,
) -> Unit {
  let node_builder = render_object.get_node_builder_state()
  for node in node_builder.update_before_nodes {
    self.get_node_frame_for_render(render_object).update_before_node(node)
  }
}

///|
/// `updateAfter( renderObject )`.
pub fn NodeManager::update_after(
  self : NodeManager,
  render_object : RenderObject,
) -> Unit {
  let node_builder = render_object.get_node_builder_state()
  for node in node_builder.update_after_nodes {
    self.get_node_frame_for_render(render_object).update_after_node(node)
  }
}

///|
/// `updateBeforeForCompute( computeNode )`.
pub fn NodeManager::update_before_for_compute(
  self : NodeManager,
  compute_node : Node,
) -> Unit {
  let node_builder = self.get_for_compute(compute_node)
  for node in node_builder.update_before_nodes {
    self.get_node_frame_for_compute(compute_node).update_before_node(node)
  }
}

///|
/// `updateAfterForCompute( computeNode )`.
pub fn NodeManager::update_after_for_compute(
  self : NodeManager,
  compute_node : Node,
) -> Unit {
  let node_builder = self.get_for_compute(compute_node)
  for node in node_builder.update_after_nodes {
    self.get_node_frame_for_compute(compute_node).update_after_node(node)
  }
}

///|
/// `updateForCompute( computeNode )`.
pub fn NodeManager::update_for_compute(
  self : NodeManager,
  compute_node : Node,
) -> Unit {
  let node_frame = self.get_node_frame()
  let node_builder = self.get_for_compute(compute_node)
  for node in node_builder.update_nodes {
    node_frame.update_node(node)
  }
}

///|
/// `updateForRender( renderObject )`.
pub fn NodeManager::update_for_render(
  self : NodeManager,
  render_object : RenderObject,
) -> Unit {
  let node_frame = self.get_node_frame_for_render(render_object)
  let node_builder = render_object.get_node_builder_state()
  for node in node_builder.update_nodes {
    node_frame.update_node(node)
  }
}

///|
/// `needsRefresh( renderObject )`: asks the material observer.
pub fn NodeManager::needs_refresh(
  self : NodeManager,
  render_object : RenderObject,
) -> Int32 {
  let node_frame = self.get_node_frame_for_render(render_object)
  match render_object.get_monitor() {
    Some(monitor) =>
      _node_manager_observer_needs_refresh(monitor, render_object, node_frame)
    None =>
      abort(
        "TypeError: Cannot read properties of null (reading 'needsRefresh')",
      )
  }
}

///|
/// `dispose()`.
pub fn NodeManager::dispose(self : NodeManager) -> Unit {
  self.render_objects.dispose()
  self.compute_nodes.dispose()
  self.scenes.dispose()
  self.materials.dispose()
  self.node_frame = NodeFrame::new()
  self.node_builder_cache = Map([])
  self.cache_lib = Map([])
}

// The TSL functions and node members upstream calls here (NodeMaterialObserver is
// still group G5's stub).

///|
/// `pmremTexture( texture )`.
fn _node_manager_pmrem_texture(texture : @core.Texture) -> Node {
  pmrem_texture(texture)
}

///|
/// `cubeTexture( texture )`.
fn _node_manager_cube_texture(texture : @core.Texture) -> Node {
  cube_texture(texture)
}

///|
/// `texture( value, uv )`.
fn _node_manager_texture(value : @core.Texture, uv : Node?) -> Node {
  match uv {
    Some(uv) => texture(value, uv_node=uv)
    None => texture(value)
  }
}

///|
/// `cubeMapNode( envNode )`.
fn _node_manager_cube_map_node(env_node : Node) -> Node {
  cube_map_node(env_node)
}

///|
/// `texture( background, screenUV.flipY() ).setUpdateMatrix( true )`.
fn _node_manager_screen_texture(texture : @core.Texture) -> Node {
  _node_manager_texture(texture, Some(screen_uv.flip_y())).set_update_matrix(
    true,
  )
}

///|
/// The fog node of a scene fog: `fog( color, densityFogFactor( density ) )` or
/// `fog( color, rangeFogFactor( near, far ) )` over `reference(...)` uniforms.
fn _node_manager_fog_node(scene_fog : @core.SceneFog) -> Node {
  let ref_ = fn(name : String, type_ : String) {
    ReferenceNode::set_group(
      reference(name, type_, object=Fog(scene_fog)),
      render_group,
    )
  }
  match scene_fog {
    FogExp2(_) => {
      let color = ref_("color", "color")
      let density = ref_("density", "float")
      fog.call([color, density_fog_factor.call([density])])
    }
    Fog(_) => {
      let color = ref_("color", "color")
      let near = ref_("near", "float")
      let far = ref_("far", "float")
      fog.call([color, range_fog_factor.call([near, far])])
    }
  }
}

///|
/// `texture( outputTarget, screenUV )[ .depth( layer ) ].renderOutput( toneMapping,
/// colorSpace )`.
fn _node_manager_output_node(
  output_target : @core.Texture,
  is_array_texture : Bool,
  is_webgl_backend : Bool,
  tone_mapping : Int32,
  color_space : String,
) -> Node {
  let sampled = texture(output_target, uv_node=screen_uv)
  let sampled = if is_array_texture {
    if is_webgl_backend {
      sampled.depth(builtin("gl_ViewID_OVR"))
    } else {
      sampled.depth(_node_manager_output_layer_index)
    }
  } else {
    sampled
  }
  sampled.render_output(tone_mapping~, output_color_space=color_space)
}

///|
/// `monitor.needsRefresh( renderObject, nodeFrame )`.
fn _node_manager_observer_needs_refresh(
  monitor : NodeMaterialObserver,
  render_object : RenderObject,
  node_frame : NodeFrame,
) -> Int32 {
  monitor.needs_refresh(render_object, node_frame)
}
