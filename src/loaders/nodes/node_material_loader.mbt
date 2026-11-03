// loaders/nodes/NodeMaterialLoader.js: MaterialLoader for node materials, whose
// `inputNodes` name the node of each slot.

///|
pub struct NodeMaterialLoader {
  base : @loaders.MaterialLoader
  /// The parsed nodes by uuid.
  mut nodes : Map[String, @tsl.Node]
  /// The node material classes by type.
  mut node_materials : Map[String, () -> @core.Material]
}

///|
/// `new NodeMaterialLoader( manager )`.
pub fn NodeMaterialLoader::new(
  manager? : @loaders.LoadingManager,
) -> NodeMaterialLoader {
  {
    base: @loaders.MaterialLoader::new(manager?),
    nodes: Map([]),
    node_materials: Map([]),
  }
}

///|
/// `parse( json )`: `super.parse( json )`, then `material[ property ] = nodes[ uuid ]`
/// for each input node.
pub fn NodeMaterialLoader::parse(
  self : NodeMaterialLoader,
  json : Json,
) -> @core.Material {
  // super.parse( json ) with this class's createMaterialFromType
  let type_ = match json {
    Object(object) =>
      match object.get("type") {
        Some(String(type_)) => type_
        _ => "undefined"
      }
    _ => "undefined"
  }
  let material = self
    .create_material_from_type(type_)
    .from_json(json, textures=self.base.textures)
  let nodes = self.nodes
  match json {
    Object(object) =>
      match object.get("inputNodes") {
        Some(Object(input_nodes)) =>
          for property, uuid in input_nodes {
            let node = match uuid {
              String(uuid) => nodes.get(uuid)
              _ => None
            }
            if @tsl.NodeMaterial::of(material) is Some(_) {
              @tsl.NodeMaterial::set_node_slot(material, property, node)
              |> ignore
            }
          }
        _ => ()
      }
    _ => ()
  }
  material
}

///|
pub fn NodeMaterialLoader::set_textures(
  self : NodeMaterialLoader,
  value : Map[String, @core.Texture],
) -> NodeMaterialLoader {
  self.base.set_textures(value) |> ignore
  self
}

///|
pub fn NodeMaterialLoader::set_nodes(
  self : NodeMaterialLoader,
  value : Map[String, @tsl.Node],
) -> NodeMaterialLoader {
  self.nodes = value
  self
}

///|
pub fn NodeMaterialLoader::set_node_materials(
  self : NodeMaterialLoader,
  value : Map[String, () -> @core.Material],
) -> NodeMaterialLoader {
  self.node_materials = value
  self
}

///|
/// `createMaterialFromType( type )`: a registered node material, else
/// `MaterialLoader`'s.
pub fn NodeMaterialLoader::create_material_from_type(
  self : NodeMaterialLoader,
  type_ : String,
) -> @core.Material {
  match self.node_materials.get(type_) {
    Some(material_class) => material_class()
    None => self.base.create_material_from_type(type_)
  }
}
