// loaders/nodes/NodeObjectLoader.js: ObjectLoader for scenes with node materials.

///|
pub struct NodeObjectLoader {
  base : @loaders.ObjectLoader
  /// The node classes by type.
  mut nodes : Map[String, () -> @tsl.Node]
  /// The node material classes by type.
  mut node_materials : Map[String, () -> @core.Material]
  /// `json.nodes` while parsing.
  mut _nodes_json : Json?
}

///|
/// `new NodeObjectLoader( manager )`.
pub fn NodeObjectLoader::new(
  manager? : @loaders.LoadingManager,
) -> NodeObjectLoader {
  let loader = {
    base: @loaders.ObjectLoader::new(manager?),
    nodes: Map([]),
    node_materials: Map([]),
    _nodes_json: None,
  }
  loader.base.set_parse_materials_override(fn(json, textures) {
    loader.parse_materials(json, textures)
  })
  loader
}

///|
pub fn NodeObjectLoader::set_nodes(
  self : NodeObjectLoader,
  value : Map[String, () -> @tsl.Node],
) -> NodeObjectLoader {
  self.nodes = value
  self
}

///|
pub fn NodeObjectLoader::set_node_materials(
  self : NodeObjectLoader,
  value : Map[String, () -> @core.Material],
) -> NodeObjectLoader {
  self.node_materials = value
  self
}

///|
fn node_object_loader_nodes_json(json : Json) -> Json? {
  match json {
    Object(o) => o.get("nodes")
    _ => None
  }
}

///|
/// `parse( json, onLoad )`.
pub fn NodeObjectLoader::parse(
  self : NodeObjectLoader,
  json : Json,
  on_load? : (@core.Object3D) -> Unit,
) -> @core.Object3D {
  self._nodes_json = node_object_loader_nodes_json(json)
  let data = self.base.parse(json, on_load?)
  self._nodes_json = None // dispose
  data
}

///|
/// `parseAsync( json )`.
pub async fn NodeObjectLoader::parse_async(
  self : NodeObjectLoader,
  json : Json,
) -> @core.Object3D raise @loaders.LoaderError {
  self._nodes_json = node_object_loader_nodes_json(json)
  let data = self.base.parse_async(json)
  self._nodes_json = None // dispose
  data
}

///|
/// `parseNodes( json, textures )`.
pub fn NodeObjectLoader::parse_nodes(
  self : NodeObjectLoader,
  json : Json?,
  textures : Map[String, @core.Texture],
) -> Map[String, @tsl.Node] {
  if json is Some(_) {
    let loader = NodeLoader::new()
    loader.set_nodes(self.nodes) |> ignore
    loader.set_textures(textures) |> ignore
    return loader.parse_nodes(json)
  }
  Map([])
}

///|
/// `parseMaterials( json, textures )`.
pub fn NodeObjectLoader::parse_materials(
  self : NodeObjectLoader,
  json : Json?,
  textures : Map[String, @core.Texture],
) -> Map[String, @core.Material] {
  let materials = Map([])
  if json is Some(Array(json)) {
    let nodes = self.parse_nodes(self._nodes_json, textures)
    let loader = NodeMaterialLoader::new()
    loader.set_textures(textures) |> ignore
    loader.set_nodes(nodes) |> ignore
    loader.set_node_materials(self.node_materials) |> ignore
    for data in json {
      let uuid = match data {
        Object(o) =>
          match o.get("uuid") {
            Some(String(u)) => u
            _ => "undefined"
          }
        _ => "undefined"
      }
      materials[uuid] = loader.parse(data)
    }
  }
  materials
}
