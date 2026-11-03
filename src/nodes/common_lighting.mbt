// renderers/common/Lighting.js: the `LightsNode` of each scene. Subclasses (the
// `TiledLighting` addon) override `createNode` through `LightingClass`.

///|
let _lighting_default_lights : Node = module_nodes(
  "renderers/common/Lighting.js:_defaultLights",
  fn() { LightsNode::new() },
)

///|
/// The overridable members of `Lighting`.
pub(open) trait LightingClass {
  /// `createNode( lights = [] )`.
  fn create_node(Self, Lighting, Array[@core.Object3D]) -> Node = _
}

///|
impl LightingClass with fn create_node(_, _, lights) {
  LightsNode::set_lights(LightsNode::new(), lights)
}

///|
/// The class of a plain `new Lighting()`.
priv struct BaseLighting {}

///|
impl LightingClass for BaseLighting

///|
pub(all) struct Lighting {
  mut class_ : &LightingClass
  /// Whether lights are used; `true` by default.
  mut enabled : Bool
  _cache : Array[Array[@core.Object3D]]
  _lights_node_map : @webgl.WeakMap[@core.JsValue, Node]
  _tracked : RefSet[@webgl.WeakRef[Node]]
  _registry : @webgl.FinalizationRegistry[@webgl.WeakRef[Node]]
}

///|
/// `new Lighting()`; subclasses pass their class.
pub fn Lighting::new(class_? : &LightingClass) -> Lighting {
  let tracked : RefSet[@webgl.WeakRef[Node]] = RefSet::new()
  {
    class_: match class_ {
      Some(c) => c
      None => BaseLighting::{ }
    },
    enabled: true,
    _cache: [],
    _lights_node_map: @webgl.WeakMap::new(),
    _tracked: tracked,
    _registry: @webgl.FinalizationRegistry::new(fn(ref_) {
      tracked.delete(ref_)
    }),
  }
}

///|
/// `createNode( lights = [] )`: a new `LightsNode` with the lights.
pub fn Lighting::create_node(
  self : Lighting,
  lights~ : Array[@core.Object3D] = [],
) -> Node {
  self.class_.create_node(self, lights)
}

///|
/// `getNode( scene )`: the scene's `LightsNode` (a shared empty one for objects that
/// are neither scenes nor groups).
pub fn Lighting::get_node(self : Lighting, scene : @core.Object3D) -> Node {
  // Ignore renderable objects, e.g: Mesh, Sprite, etc.
  if !scene.is_scene() && !scene.is_group() {
    return _lighting_default_lights
  }
  let key = @core.JsValue::of(scene)
  match self._lights_node_map.get(key) {
    Some(node) => node
    None => {
      let node = self.create_node()
      self._lights_node_map.set(key, node)
      self._track(node)
      node
    }
  }
}

///|
fn Lighting::_track(self : Lighting, node : Node) -> Unit {
  let ref_ = @webgl.WeakRef::new(node)
  self._tracked.add(ref_)
  self._registry.register(node, ref_, ref_)
}

///|
/// `beginRender( scene )`: remembers the scene's lights.
pub fn Lighting::begin_render(self : Lighting, scene : @core.Object3D) -> Unit {
  self._cache.push(LightsNode::get_lights(self.get_node(scene)))
}

///|
/// `finishRender( scene )`: restores the scene's lights.
pub fn Lighting::finish_render(self : Lighting, scene : @core.Object3D) -> Unit {
  let lights = match self._cache.pop() {
    Some(l) => l
    None => abort("Lighting.finishRender: no matching beginRender")
  }
  LightsNode::set_lights(self.get_node(scene), lights) |> ignore
}

///|
/// `dispose()`: disposes the lights nodes still alive.
pub fn Lighting::dispose(self : Lighting) -> Unit {
  self._tracked.each(fn(ref_) {
    match ref_.deref() {
      Some(node) => {
        self._registry.unregister(ref_)
        node.dispose()
      }
      None => ()
    }
  })
  self._tracked.clear()
}
