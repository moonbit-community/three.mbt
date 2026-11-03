// nodes/core/PropertyNode.js

///|
pub(all) struct PropertyNode {
  // `true` for a varying property. `nodeImmutable` passes `nodeObject( false )` for
  // `ambientOcclusion`, a (truthy) node that is not `true`, so this keeps the value.
  /// `varying`: `Bool(true)` for a varying property.
  mut varying : TslValue
  mut placeholder_node : Node?
}

///|
pub impl NodeClass for PropertyNode with fn class_name(_) {
  "PropertyNode"
}

///|
pub impl NodeClass for PropertyNode with fn has_flag(_, flag) {
  flag == "isPropertyNode"
}

///|
pub impl NodeClass for PropertyNode with fn children(self, _, out) {
  push_tsl_child(out, "varying", self.varying)
  push_child(out, "placeholderNode", self.placeholder_node)
}

///|
pub impl NodeClass for PropertyNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for PropertyNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for PropertyNode with fn get_node_type(_, node, builder, _) {
  let node_type = node.get_node_type_base(builder, None)
  if node_type == Some("output") {
    return Some(builder.get_output_type())
  }
  node_type
}

///|
pub impl NodeClass for PropertyNode with fn custom_cache_key(self, node) {
  let name = node.name.unwrap_or("")
  let varying = if property_node_truthy(self.varying) { "1" } else { "0" }
  hash_string(node.type_() + ":" + name + ":" + varying)
}

///|
pub impl NodeClass for PropertyNode with fn get_hash(_, node, builder) {
  match node.name {
    Some(name) if name != "" => name
    _ => node.get_hash_base(builder)
  }
}

///|
pub impl NodeClass for PropertyNode with fn generate(self, node, builder, _) {
  let property_name = if self.varying is Bool(true) {
    let node_var = builder.get_varying_from_node(node, name?=node.name)
    node_var.needs_interpolation = true
    builder.get_property_name(Varying(node_var))
  } else {
    let node_var = builder.get_var_from_node(
      node,
      node.name,
      None,
      None,
      false,
      false,
      "variable",
    )
    let property_name = builder.get_property_name(Var(node_var))
    if self.placeholder_node is Some(placeholder_node) {
      if !builder.has_write_usage(node) {
        let snippet = placeholder_node.build(
          builder,
          output?=node.get_node_type(builder),
        )
        builder.add_line_flow_code(
          "\{builder.get_property_name(Var(node_var))} = \{snippet}",
          node~,
        )
        |> ignore
      }
    }
    property_name
  }
  Some(property_name)
}

///|
pub fn PropertyNode::construct(
  node : Node,
  name : String?,
  varying : TslValue,
  placeholder_node : TslValue,
) -> PropertyNode {
  node.name = name
  let placeholder_node = match placeholder_node {
    Undefined | Null => None
    v => Some(node_object(v))
  }
  let property = PropertyNode::{ varying, placeholder_node, }
  node.global = true
  property
}

///|
/// `new PropertyNode( nodeType, name = null, varying = false, placeholderNode = null )`.
pub fn PropertyNode::new(
  node_type : String,
  name? : String,
  varying~ : TslValue = Bool(false),
  placeholder_node? : &IntoTsl,
) -> Node {
  let node = Node::alloc(node_type~)
  let placeholder_node = match placeholder_node {
    Some(p) => p.to_tsl()
    None => Null
  }
  node.set_class(PropertyNode::construct(node, name, varying, placeholder_node))
}

///|
pub fn PropertyNode::of(node : Node) -> PropertyNode? {
  match node.class_payload("PropertyNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// JS truthiness of a `TslValue` held by a property.
fn property_node_truthy(value : TslValue) -> Bool {
  match value {
    Undefined | Null => false
    Bool(b) => b
    Number(x) => x != 0.0 && x == x
    String(s) => s != ""
    _ => true
  }
}

///|
/// `property( type, name, placeholderNode = null )`.
pub fn property(
  type_ : String,
  name? : String,
  placeholder_node? : &IntoTsl,
) -> Node {
  PropertyNode::new(type_, name?, varying=Bool(false), placeholder_node?)
}

///|
/// `varyingProperty( type, name, placeholderNode = null )`.
pub fn varying_property(
  type_ : String,
  name? : String,
  placeholder_node? : &IntoTsl,
) -> Node {
  PropertyNode::new(type_, name?, varying=Bool(true), placeholder_node?)
}

///|
pub let diffuse_color : Node = module_nodes(
  "nodes/core/PropertyNode.js:diffuseColor",
  fn() { PropertyNode::new("vec4", name="DiffuseColor") },
)

///|
pub let diffuse_contribution : Node = module_nodes(
  "nodes/core/PropertyNode.js:diffuseContribution",
  fn() { PropertyNode::new("vec3", name="DiffuseContribution") },
)

///|
pub let diffuse_roughness : Node = module_nodes(
  "nodes/core/PropertyNode.js:diffuseRoughness",
  fn() { PropertyNode::new("float", name="DiffuseRoughness") },
)

///|
pub let emissive : Node = module_nodes("nodes/core/PropertyNode.js:emissive", fn() {
  PropertyNode::new("vec3", name="EmissiveColor")
})

///|
pub let roughness : Node = module_nodes(
  "nodes/core/PropertyNode.js:roughness",
  fn() { PropertyNode::new("float", name="Roughness") },
)

///|
pub let metalness : Node = module_nodes(
  "nodes/core/PropertyNode.js:metalness",
  fn() { PropertyNode::new("float", name="Metalness") },
)

///|
pub let clearcoat : Node = module_nodes(
  "nodes/core/PropertyNode.js:clearcoat",
  fn() { PropertyNode::new("float", name="Clearcoat") },
)

///|
pub let clearcoat_roughness : Node = module_nodes(
  "nodes/core/PropertyNode.js:clearcoatRoughness",
  fn() { PropertyNode::new("float", name="ClearcoatRoughness") },
)

///|
pub let sheen : Node = module_nodes("nodes/core/PropertyNode.js:sheen", fn() {
  PropertyNode::new("vec3", name="Sheen")
})

///|
pub let sheen_roughness : Node = module_nodes(
  "nodes/core/PropertyNode.js:sheenRoughness",
  fn() { PropertyNode::new("float", name="SheenRoughness") },
)

///|
pub let iridescence : Node = module_nodes(
  "nodes/core/PropertyNode.js:iridescence",
  fn() { PropertyNode::new("float", name="Iridescence") },
)

///|
pub let iridescence_ior : Node = module_nodes(
  "nodes/core/PropertyNode.js:iridescenceIOR",
  fn() { PropertyNode::new("float", name="IridescenceIOR") },
)

///|
pub let iridescence_thickness : Node = module_nodes(
  "nodes/core/PropertyNode.js:iridescenceThickness",
  fn() { PropertyNode::new("float", name="IridescenceThickness") },
)

///|
pub let alpha_t : Node = module_nodes("nodes/core/PropertyNode.js:alphaT", fn() {
  PropertyNode::new("float", name="AlphaT")
})

///|
pub let anisotropy : Node = module_nodes(
  "nodes/core/PropertyNode.js:anisotropy",
  fn() { PropertyNode::new("float", name="Anisotropy") },
)

///|
pub let anisotropy_t : Node = module_nodes(
  "nodes/core/PropertyNode.js:anisotropyT",
  fn() { PropertyNode::new("vec3", name="AnisotropyT") },
)

///|
pub let anisotropy_b : Node = module_nodes(
  "nodes/core/PropertyNode.js:anisotropyB",
  fn() { PropertyNode::new("vec3", name="AnisotropyB") },
)

///|
pub let specular_color : Node = module_nodes(
  "nodes/core/PropertyNode.js:specularColor",
  fn() { PropertyNode::new("color", name="SpecularColor") },
)

///|
pub let specular_color_blended : Node = module_nodes(
  "nodes/core/PropertyNode.js:specularColorBlended",
  fn() { PropertyNode::new("color", name="SpecularColorBlended") },
)

///|
pub let specular_f90 : Node = module_nodes(
  "nodes/core/PropertyNode.js:specularF90",
  fn() { PropertyNode::new("float", name="SpecularF90") },
)

///|
pub let shininess : Node = module_nodes(
  "nodes/core/PropertyNode.js:shininess",
  fn() { PropertyNode::new("float", name="Shininess") },
)

///|
pub let output : Node = module_nodes("nodes/core/PropertyNode.js:output", fn() {
  PropertyNode::new("output", name="Output")
})

///|
pub let dash_size : Node = module_nodes("nodes/core/PropertyNode.js:dashSize", fn() {
  PropertyNode::new("float", name="dashSize")
})

///|
pub let gap_size : Node = module_nodes("nodes/core/PropertyNode.js:gapSize", fn() {
  PropertyNode::new("float", name="gapSize")
})

///|
pub let point_width : Node = module_nodes(
  "nodes/core/PropertyNode.js:pointWidth",
  fn() { PropertyNode::new("float", name="pointWidth") },
)

///|
pub let ior : Node = module_nodes("nodes/core/PropertyNode.js:ior", fn() {
  PropertyNode::new("float", name="IOR")
})

///|
pub let transmission : Node = module_nodes(
  "nodes/core/PropertyNode.js:transmission",
  fn() { PropertyNode::new("float", name="Transmission") },
)

///|
pub let thickness : Node = module_nodes(
  "nodes/core/PropertyNode.js:thickness",
  fn() { PropertyNode::new("float", name="Thickness") },
)

///|
pub let attenuation_distance : Node = module_nodes(
  "nodes/core/PropertyNode.js:attenuationDistance",
  fn() { PropertyNode::new("float", name="AttenuationDistance") },
)

///|
pub let attenuation_color : Node = module_nodes(
  "nodes/core/PropertyNode.js:attenuationColor",
  fn() { PropertyNode::new("color", name="AttenuationColor") },
)

///|
pub let dispersion : Node = module_nodes(
  "nodes/core/PropertyNode.js:dispersion",
  fn() { PropertyNode::new("float", name="Dispersion") },
)

///|
pub let retroreflectivity : Node = module_nodes(
  "nodes/core/PropertyNode.js:retroreflectivity",
  fn() { PropertyNode::new("float", name="Retroreflectivity") },
)

///|
// `nodeImmutable( PropertyNode, 'float', 'AmbientOcclusion', false, 1 )`: the
// arguments go through `nodeObject`, so `varying` is the bool constant node.
pub let ambient_occlusion : Node = module_nodes(
  "nodes/core/PropertyNode.js:ambientOcclusion",
  fn() {
    PropertyNode::new(
      "float",
      name="AmbientOcclusion",
      varying=Node(node_object(Bool(false))),
      placeholder_node=1,
    )
  },
)
