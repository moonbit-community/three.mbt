// loaders/nodes/NodeLoader.js: loads node graphs in the JSON format of `Node.toJSON`.
// Nodes deserialize from JS objects (`Node::deserialize` takes the parsed JSON with
// its `meta`), so the `Json` input is handed to them as a JS value.
//
// r187 assigns `node.uuid = uuid`, but `Node.uuid` only has a getter, so in its strict
// module code every assignment throws `TypeError`: `parse` and `parseNodes` with any
// node abort here the same way (`node_loader_set_uuid`).

///|
/// A loader for node graphs.
pub struct NodeLoader {
  base : @loaders.Loader
  /// The textures the nodes refer to, by uuid.
  mut textures : Map[String, @core.Texture]
  /// The node classes by type (`new this.nodes[ type ]()`).
  mut nodes : Map[String, () -> @tsl.Node]
}

///|
/// `new NodeLoader( manager )`.
pub fn NodeLoader::new(manager? : @loaders.LoadingManager) -> NodeLoader {
  { base: @loaders.Loader::new(manager?), textures: Map([]), nodes: Map([]), }
}

///|
pub impl @loaders.LoaderLike for NodeLoader with fn loader(self) {
  self.base
}

///|
pub impl @loaders.LoaderSettings for NodeLoader

///|
extern "js" fn node_loader_json_parse(text : String) -> @core.JsValue = "(t) => JSON.parse(t)"

///|
extern "js" fn node_loader_delete(object : @core.JsValue, key : String) -> Unit = "(o, k) => { delete o[k]; }"

///|
extern "js" fn node_loader_array(
  value : @core.JsValue,
) -> FixedArray[@core.JsValue] = "(v) => v"

///|
/// `node.uuid = uuid`: `uuid` is a getter-only accessor of `Node`, so upstream's strict
/// mode assignment throws.
fn node_loader_set_uuid(node : @tsl.Node, uuid : String) -> Unit {
  ignore((node, uuid))
  abort(
    "TypeError: Cannot set property uuid of #<Node> which has only a getter",
  )
}

///|
/// `json` as the JS object `Node::deserialize` reads.
pub fn node_loader_to_js(json : Json) -> @core.JsValue {
  node_loader_json_parse(json.stringify())
}

///|
/// Starts loading `url`; `on_load` receives the node.
pub fn NodeLoader::load(
  self : NodeLoader,
  url : String,
  on_load : (@tsl.Node) -> Unit,
  on_progress? : (@loaders.ProgressEvent) -> Unit,
  on_error? : (@core.JsValue) -> Unit,
) -> Unit {
  let base = self.base
  let loader = @loaders.FileLoader::new(manager=base.manager)
    .set_priority(base.priority)
    .set_cache(base.cache)
    .set_path(base.path)
    .set_request_header(base.request_header)
    .set_with_credentials(base.with_credentials)
  loader.load(
    url,
    on_load=text => {
      let text : String = text.cast()
      let parsed : Result[Json, String] = Ok(@json.parse(text)) catch {
        e => Err("\{e}")
      }
      match parsed {
        Ok(json) => on_load(self.parse(json))
        Err(e) => {
          match on_error {
            Some(on_error) => on_error(@core.JsValue::of(e))
            None => @core.error(e)
          }
          base.manager.item_error(url)
        }
      }
    },
    on_progress?,
    on_error?,
  )
}

///|
/// `parseNodes( json )`: the nodes of a JSON `nodes` array, by uuid.
pub fn NodeLoader::parse_nodes(
  self : NodeLoader,
  json : Json?,
) -> Map[String, @tsl.Node] {
  let nodes : Map[String, @tsl.Node] = Map([])
  if json is Some(json) {
    let items = node_loader_array(node_loader_to_js(json))
    for node_json in items {
      let uuid : String = node_json.get("uuid").cast()
      let type_ : String = node_json.get("type").cast()
      nodes[uuid] = self.create_node_from_type(type_)
      node_loader_set_uuid(nodes.get(uuid).unwrap(), uuid)
    }
    let meta = self.meta(nodes)
    for node_json in items {
      node_json.set("meta", meta)
      let node = nodes.get(node_json.get("uuid").cast()).unwrap()
      node.deserialize(node_json)
      node_loader_delete(node_json, "meta")
    }
  }
  nodes
}

///|
/// `{ nodes, textures: this.textures }` as a JS object.
fn NodeLoader::meta(
  self : NodeLoader,
  nodes : Map[String, @tsl.Node],
) -> @core.JsValue {
  let js_nodes = @core.JsValue::object()
  for uuid, node in nodes {
    js_nodes.set(uuid, @core.JsValue::of(node))
  }
  let js_textures = @core.JsValue::object()
  for uuid, texture in self.textures {
    js_textures.set(uuid, @core.JsValue::of(texture))
  }
  let meta = @core.JsValue::object()
  meta.set("nodes", js_nodes)
  meta.set("textures", js_textures)
  meta
}

///|
/// `parse( json )`: the root node of `json`, with its `nodes`.
pub fn NodeLoader::parse(self : NodeLoader, json : Json) -> @tsl.Node {
  let data = node_loader_to_js(json)
  let node = self.create_node_from_type(data.get("type").cast())
  node_loader_set_uuid(node, data.get("uuid").cast())
  let nodes_json = match json {
    Object(o) => o.get("nodes")
    _ => None
  }
  let nodes = self.parse_nodes(nodes_json)
  data.set("meta", self.meta(nodes))
  node.deserialize(data)
  node_loader_delete(data, "meta")
  node
}

///|
pub fn NodeLoader::set_textures(
  self : NodeLoader,
  value : Map[String, @core.Texture],
) -> NodeLoader {
  self.textures = value
  self
}

///|
pub fn NodeLoader::set_nodes(
  self : NodeLoader,
  value : Map[String, () -> @tsl.Node],
) -> NodeLoader {
  self.nodes = value
  self
}

///|
/// `createNodeFromType( type )`: `float()` for an unknown type.
pub fn NodeLoader::create_node_from_type(
  self : NodeLoader,
  type_ : String,
) -> @tsl.Node {
  match self.nodes.get(type_) {
    Some(construct) => construct()
    None => {
      @core.error("NodeLoader: Node type not found: " + type_)
      @tsl.float_of([])
    }
  }
}
