// nodes/lighting/ShadowBaseNode.js: the base of shadow nodes (shadow material, shadow
// render function, shadow position).

///|
/// `shadowPositionWorld`.
pub let shadow_position_world : Node = module_nodes(
  "nodes/lighting/ShadowBaseNode.js:shadowPositionWorld",
  fn() { property("vec3", name="shadowPositionWorld") },
)

///|
/// The class of the shadow pass material (`material.isShadowPassMaterial = true`).
priv struct ShadowPassMaterialClass {}

///|
impl NodeMaterialClass for ShadowPassMaterialClass with fn class_name(_) {
  "ShadowPassMaterial"
}

///|
impl NodeMaterialClass for ShadowPassMaterialClass with fn type_name(_) {
  "NodeMaterial"
}

///|
impl NodeMaterialClass for ShadowPassMaterialClass with fn parent(_) {
  Some(BaseNodeMaterial::{ })
}

///|
impl NodeMaterialClass for ShadowPassMaterialClass with fn has_flag(_, flag) {
  flag == "isShadowPassMaterial"
}

///|
let shadow_base_material_lib : @webgl.WeakMap[@core.Object3D, @core.Material] = @webgl.WeakMap::new()

///|
/// A shadow render function and the shadow type it was made for.
priv struct ShadowBaseRenderObjectFunction {
  function : RenderObjectFunction
  shadow_type : Int32
}

///|
let shadow_base_render_object_library : ChainMap[ShadowBaseRenderObjectFunction] = ChainMap::new()

///|
/// `_getShadowMaterial( light )`.
fn shadow_base_get_shadow_material(light : @core.Object3D) -> @core.Material {
  match shadow_base_material_lib.get(light) {
    Some(m) => m
    None => {
      let material = NodeMaterial::new()
      let node_material = NodeMaterial::of(material).unwrap()
      node_material.color_node = Some(vec4_of([0, 0, 0, 1]))
      node_material.class_ = ShadowPassMaterialClass::{ }
      material.name = "ShadowMaterial"
      material.blending = @core.NoBlending
      material.fog = Some(false)
      shadow_base_material_lib.set(light, material)
      material
    }
  }
}

///|
/// `_disposeShadowMaterial( light )`.
fn shadow_base_dispose_shadow_material(light : @core.Object3D) -> Unit {
  if shadow_base_material_lib.get(light) is Some(material) {
    material.dispose()
    shadow_base_material_lib.delete(light)
  }
}

///|
/// `_getShadowRenderObjectFunction( renderer, shadow, shadowType )`: renders only
/// shadow casters (and VSM receivers).
fn shadow_base_get_shadow_render_object_function(
  renderer : Renderer,
  shadow : @core.LightShadow,
  shadow_type : Int32,
) -> RenderObjectFunction {
  let keys = [@core.JsValue::of(renderer), @core.JsValue::of(shadow)]
  match shadow_base_render_object_library.get(keys) {
    Some(entry) if entry.shadow_type == shadow_type => entry.function
    _ => {
      let function = RenderObjectFunction::{
        f: fn(
          object,
          scene,
          camera,
          geometry,
          material,
          group,
          lights_node,
          clipping_context,
          pass_id,
        ) {
          if object.cast_shadow == true ||
            (object.receive_shadow && shadow_type == @core.VSMShadowMap) {
            let override_material = scene.as_scene().override_material.unwrap()
            (object.on_before_shadow)(
              @core.JsValue::of(renderer),
              object,
              camera,
              shadow.camera,
              geometry,
              override_material,
              group,
            )
            renderer.render_object(
              object, scene, camera, geometry, material, group, lights_node, clipping_context,
              pass_id,
            )
            (object.on_after_shadow)(
              @core.JsValue::of(renderer),
              object,
              camera,
              shadow.camera,
              geometry,
              scene.as_scene().override_material.unwrap(),
              group,
            )
          }
        },
      }
      shadow_base_render_object_library.set(keys, ShadowBaseRenderObjectFunction::{
        function,
        shadow_type,
      })
      |> ignore
      function
    }
  }
}

///|
pub(all) struct ShadowBaseNode {
  mut light : @core.Object3D
}

///|
pub impl NodeClass for ShadowBaseNode with fn class_name(_) {
  "ShadowBaseNode"
}

///|
pub impl NodeClass for ShadowBaseNode with fn has_flag(_, flag) {
  flag == "isShadowBaseNode"
}

///|
pub impl NodeClass for ShadowBaseNode with fn is_cacheable(_, _, _) {
  false
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn ShadowBaseNode::construct(
  node : Node,
  light : @core.Object3D,
) -> ShadowBaseNode {
  node.update_before_type = NodeUpdateType::render()
  { light, }
}

///|
/// `new ShadowBaseNode( light )`.
pub fn ShadowBaseNode::new(light : @core.Object3D) -> Node {
  let node = Node::alloc()
  node.set_class(ShadowBaseNode::construct(node, light))
}

///|
pub fn ShadowBaseNode::of(node : Node) -> ShadowBaseNode? {
  match node.class_payload("ShadowBaseNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `getShadowMaterial()`.
pub fn ShadowBaseNode::get_shadow_material(
  self : ShadowBaseNode,
) -> @core.Material {
  shadow_base_get_shadow_material(self.light)
}

///|
/// `disposeShadowMaterial()`.
pub fn ShadowBaseNode::dispose_shadow_material(self : ShadowBaseNode) -> Unit {
  shadow_base_dispose_shadow_material(self.light)
}

///|
/// `getShadowRenderObjectFunction( renderer, shadow = this.light.shadow )`.
pub fn ShadowBaseNode::get_shadow_render_object_function(
  self : ShadowBaseNode,
  renderer : Renderer,
  shadow? : @core.LightShadow,
) -> RenderObjectFunction {
  let shadow = match shadow {
    Some(s) => s
    None => self.light.as_light().shadow.unwrap()
  }
  shadow_base_get_shadow_render_object_function(
    renderer,
    shadow,
    renderer.shadow_map.type_,
  )
}

///|
/// `setupShadowPosition( { context, material } )`.
pub fn ShadowBaseNode::setup_shadow_position(
  _self : ShadowBaseNode,
  builder : NodeBuilder,
) -> Unit {
  let material = NodeMaterial::of(builder.material.unwrap())
  let received = match material {
    Some(m) => m.received_shadow_position_node
    None => None
  }
  let position = match received {
    Some(n) => n
    None =>
      match builder.context.get_node("shadowPositionWorld") {
        Some(n) => n
        None => position_world
      }
  }
  shadow_position_world.assign(position)
}
