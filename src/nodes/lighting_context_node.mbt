// nodes/lighting/LightingContextNode.js: the context a lighting model builds in
// (`radiance`, `irradiance`, `reflectedLight`, ...). The context keys this group owns
// have typed accessors here: `lightingModel`, `reflectedLight`, `materialLightings`.

///|
/// `reflectedLight`: the four light accumulators.
pub(all) struct ReflectedLight {
  direct_diffuse : Node
  direct_specular : Node
  indirect_diffuse : Node
  indirect_specular : Node
}

///|
/// `builder.context.lightingModel`, if set.
pub fn NodeContext::lighting_model(self : NodeContext) -> LightingModel? {
  match self.get("lightingModel") {
    Other(_) as v => v.cast()
    _ => None
  }
}

///|
/// `builder.context.reflectedLight`, if set.
pub fn NodeContext::reflected_light(self : NodeContext) -> ReflectedLight? {
  match self.get("reflectedLight") {
    Other(_) as v => v.cast()
    _ => None
  }
}

///|
/// `builder.context.materialLightings`, if set.
pub fn NodeContext::material_lightings(self : NodeContext) -> Array[Node]? {
  match self.get("materialLightings") {
    Other(_) as v => v.cast()
    _ => None
  }
}

///|
/// A context value holding a lighting model.
pub fn ContextValue::lighting_model(model : LightingModel) -> ContextValue {
  Other(@core.JsValue::of(model))
}

///|
pub(all) struct LightingContextNode {
  context : ContextNode
  mut lighting_model : LightingModel?
  mut material_lightings : Array[Node]
  mut backdrop_node : Node?
  mut backdrop_alpha_node : Node?
  mut _value : NodeContext?
}

///|
pub impl NodeClass for LightingContextNode with fn class_name(_) {
  "LightingContextNode"
}

///|
pub impl NodeClass for LightingContextNode with fn parent(self) {
  Some(self.context)
}

///|
pub impl NodeClass for LightingContextNode with fn children(self, node, out) {
  NodeClass::children(self.context, node, out)
  push_children(out, "materialLightings", self.material_lightings.map(Some(_)))
  push_child(out, "backdropNode", self.backdrop_node)
  push_child(out, "backdropAlphaNode", self.backdrop_alpha_node)
}

///|
pub impl NodeClass for LightingContextNode with fn setup(self, node, builder) {
  let value = match self._value {
    Some(v) => v
    None => {
      let v = self.get_context()
      self._value = Some(v)
      v
    }
  }
  self.context.value = value
  value.set(
    "lightingModel",
    match self.lighting_model {
      Some(m) => ContextValue::lighting_model(m)
      None => builder.context.get("lightingModel")
    },
  )
  NodeClass::setup(self.context, node, builder)
}

///|
/// `getContext()`: the lighting variables and accumulators.
pub fn LightingContextNode::get_context(
  self : LightingContextNode,
) -> NodeContext {
  let direct_diffuse = vec3_of([]).to_var(name="directDiffuse")
  let direct_specular = vec3_of([]).to_var(name="directSpecular")
  let indirect_diffuse = vec3_of([]).to_var(name="indirectDiffuse")
  let indirect_specular = vec3_of([]).to_var(name="indirectSpecular")
  let reflected_light = ReflectedLight::{
    direct_diffuse,
    direct_specular,
    indirect_diffuse,
    indirect_specular,
  }
  let radiance = vec3_of([]).to_var(name="radiance")
  let irradiance = vec3_of([]).to_var(name="irradiance")
  let ibl_irradiance = vec3_of([]).to_var(name="iblIrradiance")
  let ambient_occlusion = float(1).to_var(name="ambientOcclusion")
  node_context([
    ("radiance", Node(radiance)),
    ("irradiance", Node(irradiance)),
    ("iblIrradiance", Node(ibl_irradiance)),
    ("ambientOcclusion", Node(ambient_occlusion)),
    ("reflectedLight", Other(@core.JsValue::of(reflected_light))),
    ("materialLightings", Other(@core.JsValue::of(self.material_lightings))),
    (
      "backdrop",
      match self.backdrop_node {
        Some(n) => Node(n)
        None => Null
      },
    ),
    (
      "backdropAlpha",
      match self.backdrop_alpha_node {
        Some(n) => Node(n)
        None => Null
      },
    ),
  ])
}

///|
pub fn LightingContextNode::construct(
  node : Node,
  lights_node : Node,
  lighting_model : LightingModel?,
  material_lightings : Array[Node],
  backdrop_node : Node?,
  backdrop_alpha_node : Node?,
) -> LightingContextNode {
  let context = ContextNode::construct(
    node,
    Some(lights_node),
    NodeContext::new(),
  )
  {
    context,
    lighting_model,
    material_lightings,
    backdrop_node,
    backdrop_alpha_node,
    _value: None,
  }
}

///|
/// `new LightingContextNode( lightsNode, lightingModel = null, materialLightings = [],
/// backdropNode = null, backdropAlphaNode = null )`.
pub fn LightingContextNode::new(
  lights_node : Node,
  lighting_model? : LightingModel,
  material_lightings~ : Array[Node] = [],
  backdrop_node? : Node,
  backdrop_alpha_node? : Node,
) -> Node {
  let node = Node::alloc()
  node.set_class(
    LightingContextNode::construct(
      node, lights_node, lighting_model, material_lightings, backdrop_node, backdrop_alpha_node,
    ),
  )
}

///|
pub fn LightingContextNode::of(node : Node) -> LightingContextNode? {
  match node.class_payload("LightingContextNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `lightingContext( lightsNode, lightingModel, materialLightings, backdropNode,
/// backdropAlphaNode )`.
pub fn lighting_context(
  lights_node : Node,
  lighting_model? : LightingModel,
  material_lightings~ : Array[Node] = [],
  backdrop_node? : Node,
  backdrop_alpha_node? : Node,
) -> Node {
  LightingContextNode::new(
    lights_node,
    lighting_model?,
    material_lightings~,
    backdrop_node?,
    backdrop_alpha_node?,
  )
}
