// renderers/common/RenderObjects.js

///|
/// Creates and caches the `RenderObject`s of each pass.
pub struct RenderObjects {
  renderer : Renderer
  nodes : NodeManager
  geometries : Geometries
  pipelines : Pipelines
  bindings : Bindings
  info : Info
  priv mut _chain_maps : Map[String, ChainMap[RenderObject]]
  priv _render_objects : RefSet[RenderObject]
}

///|
/// `new RenderObjects( renderer, nodes, geometries, pipelines, bindings, info )`.
pub fn RenderObjects::new(
  renderer : Renderer,
  nodes : NodeManager,
  geometries : Geometries,
  pipelines : Pipelines,
  bindings : Bindings,
  info : Info,
) -> RenderObjects {
  {
    renderer,
    nodes,
    geometries,
    pipelines,
    bindings,
    info,
    _chain_maps: Map([]),
    _render_objects: RefSet::new(),
  }
}

///|
/// `get( object, material, scene, camera, lightsNode, renderContext, clippingContext,
/// passId )`: the cached render object, recreated when its cache key changed.
pub fn RenderObjects::get(
  self : RenderObjects,
  object : @core.Object3D,
  material : @core.Material,
  scene : @core.Object3D,
  camera : @core.Object3D,
  lights_node : Node,
  render_context : RenderContext,
  clipping_context : ClippingContext?,
  pass_id? : String,
) -> RenderObject {
  // `None` is the renderer's `passId = null`, a chain map of its own (`'null'`);
  // upstream's `undefined` (getShaderAsync) is `'default'`
  let chain_map = self.get_chain_map(pass_id=pass_id.unwrap_or("null"))
  let source_material = self.renderer._current_source_material
  let source_material_version = match source_material {
    Some(m) => m.version
    None => 0
  }
  let chain_keys = [
    @core.JsValue::of(object),
    @core.JsValue::of(material),
    @core.JsValue::of(render_context),
    @core.JsValue::of(lights_node),
  ]
  match source_material {
    Some(m) => chain_keys.push(@core.JsValue::of(m))
    None => ()
  }
  match chain_map.get(chain_keys) {
    None => {
      let render_object = self.create_render_object(
        self.nodes,
        self.geometries,
        self.renderer,
        object,
        material,
        scene,
        camera,
        lights_node,
        render_context,
        clipping_context,
        pass_id?,
      )
      chain_map.set(chain_keys, render_object) |> ignore
      render_object
    }
    Some(render_object) => {
      let mut force = false
      render_object.camera = camera
      render_object.update_clipping(clipping_context)
      if render_object.needs_geometry_update() {
        match object.get_geometry() {
          Some(g) => render_object.set_geometry(g)
          None =>
            abort(
              "TypeError: Cannot read properties of undefined (reading 'addEventListener')",
            )
        }
        if render_object.initial_geometry_cache_key !=
          render_object.get_geometry_cache_key() {
          force = true
        }
      }
      if render_object.version != material.version ||
        render_object.source_material_version != source_material_version ||
        render_object.needs_update() ||
        force {
        if render_object.initial_cache_key != render_object.get_cache_key() {
          render_object.dispose()
          return self.get(
            object,
            material,
            scene,
            camera,
            lights_node,
            render_context,
            clipping_context,
            pass_id?,
          )
        } else {
          render_object.version = material.version
          render_object.source_material_version = source_material_version
        }
      }
      render_object
    }
  }
}

///|
/// `getChainMap( passId = 'default' )`.
pub fn RenderObjects::get_chain_map(
  self : RenderObjects,
  pass_id~ : String = "default",
) -> ChainMap[RenderObject] {
  match self._chain_maps.get(pass_id) {
    Some(m) => m
    None => {
      let m = ChainMap::new()
      self._chain_maps.set(pass_id, m)
      m
    }
  }
}

///|
/// `dispose()`.
pub fn RenderObjects::dispose(self : RenderObjects) -> Unit {
  self._render_objects.each(fn(render_object) { render_object.dispose() })
  self._render_objects.clear()
  self._chain_maps = Map([])
}

///|
/// `createRenderObject( nodes, geometries, renderer, object, material, scene, camera,
/// lightsNode, renderContext, clippingContext, passId )`.
pub fn RenderObjects::create_render_object(
  self : RenderObjects,
  nodes : NodeManager,
  geometries : Geometries,
  renderer : Renderer,
  object : @core.Object3D,
  material : @core.Material,
  scene : @core.Object3D,
  camera : @core.Object3D,
  lights_node : Node,
  render_context : RenderContext,
  clipping_context : ClippingContext?,
  pass_id? : String,
) -> RenderObject {
  // `None` is the renderer's `passId = null`, a chain map of its own (`'null'`);
  // upstream's `undefined` (getShaderAsync) is `'default'`
  let chain_map = self.get_chain_map(pass_id=pass_id.unwrap_or("null"))
  let render_object = RenderObject::new(
    nodes, geometries, renderer, object, material, scene, camera, lights_node, render_context,
    clipping_context,
  )
  render_object.on_dispose = Some(fn() {
    self.geometries.delete_vertex_state(render_object)
    self.pipelines.delete(render_object) |> ignore
    self.bindings.delete_for_render(render_object)
    self.nodes.delete(render_object) |> ignore
    chain_map.delete(render_object.get_chain_array()) |> ignore
    self._render_objects.delete(render_object)
  })
  self._render_objects.add(render_object)
  render_object
}
