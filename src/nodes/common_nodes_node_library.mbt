// renderers/common/nodes/NodeLibrary.js: the node materials and tone mapping functions
// a backend's library registers. The deprecated `getLightNodeClass` and `addLight`
// are not ported (lights register their nodes with `Light.registerNode`).

///|
extern "js" fn node_library_assign_fields(
  target : @core.Material,
  source : @core.Material,
  skip : Array[String],
) -> Unit =
  #|(t, s, skip) => {
  #|  for ( const k of Object.keys( s ) ) {
  #|    if ( k === 'id' || k === 'dispatcher' || k === 'extension' || k === 'type_' || k === 'material_type' ) continue;
  #|    if ( skip.includes( k ) ) continue;
  #|    t[ k ] = s[ k ];
  #|  }
  #|}

///|
/// The node material classes and tone mapping functions of a renderer.
pub(all) struct NodeLibrary {
  /// `materialNodes`: node material constructors by core material `type`.
  material_nodes : Map[String, () -> @core.Material]
  /// `toneMappingNodes`: tone mapping functions (TSL `Fn`s) by tone mapping constant.
  tone_mapping_nodes : Map[Int32, Node]
}

///|
/// `new NodeLibrary()`.
pub fn NodeLibrary::new() -> NodeLibrary {
  { material_nodes: Map([]), tone_mapping_nodes: Map([]), }
}

///|
/// `fromMaterial( material )`: the material itself for node materials, else a new node
/// material of the registered class with every property of `material` copied (`for (
/// const key in material )`); `None` is `null`.
pub fn NodeLibrary::from_material(
  self : NodeLibrary,
  material : @core.Material,
) -> @core.Material? {
  if material.is_node_material() {
    return Some(material)
  }
  match self.get_material_node_class(material.type_) {
    Some(node_material_class) => {
      let node_material = node_material_class()
      // the flat subclass fields are copied only where `material` has them (G5)
      node_library_assign_fields(
        node_material, material, node_material_optional_fields,
      )
      NodeMaterial::assign_defined_fields(node_material, material)
      match material.dispatcher._listeners {
        Some(listeners) => node_material.dispatcher._listeners = Some(listeners)
        None => ()
      }
      Some(node_material)
    }
    None => None
  }
}

///|
/// `addToneMapping( toneMappingNode, toneMapping )`.
pub fn NodeLibrary::add_tone_mapping(
  self : NodeLibrary,
  tone_mapping_node : Node,
  tone_mapping : Int32,
) -> Unit {
  if self.tone_mapping_nodes.contains(tone_mapping) {
    @core.warn("Redefinition of node \{tone_mapping}")
    return
  }
  self.tone_mapping_nodes.set(tone_mapping, tone_mapping_node)
}

///|
/// `getToneMappingFunction( toneMapping )`; `None` is `null`.
pub fn NodeLibrary::get_tone_mapping_function(
  self : NodeLibrary,
  tone_mapping : Int32,
) -> Node? {
  self.tone_mapping_nodes.get(tone_mapping)
}

///|
/// `getMaterialNodeClass( materialType )`; `None` is `null`.
pub fn NodeLibrary::get_material_node_class(
  self : NodeLibrary,
  material_type : String,
) -> (() -> @core.Material)? {
  self.material_nodes.get(material_type)
}

///|
/// `addMaterial( materialNodeClass, materialClassType )`.
pub fn NodeLibrary::add_material(
  self : NodeLibrary,
  material_node_class : () -> @core.Material,
  material_class_type : String,
) -> Unit {
  if self.material_nodes.contains(material_class_type) {
    @core.warn("Redefinition of node \{material_class_type}")
    return
  }
  self.material_nodes.set(material_class_type, material_node_class)
}
