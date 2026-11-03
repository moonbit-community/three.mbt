// nodes/core/NodeCache.js

///|
let _node_cache_id : Ref[Int32] = Ref(0)

///|
/// Per-node data of a build, keyed by node identity, with a parent fallback.
pub(all) struct NodeCache {
  id : Int32
  /// `nodesData`: node id -> `{ [shaderStage]: NodeData, any: NodeData }`.
  nodes_data : Map[Int32, Map[String, NodeData]]
  parent : NodeCache?
}

///|
pub fn NodeCache::new(parent? : NodeCache) -> NodeCache {
  let id = _node_cache_id.val
  _node_cache_id.val += 1
  { id, nodes_data: Map::new(), parent, }
}

///|
pub fn NodeCache::get_data(
  self : NodeCache,
  node : Node,
) -> Map[String, NodeData]? {
  match self.nodes_data.get(node.id) {
    Some(d) => Some(d)
    None =>
      match self.parent {
        Some(p) => p.get_data(node)
        None => None
      }
  }
}

///|
pub fn NodeCache::set_data(
  self : NodeCache,
  node : Node,
  data : Map[String, NodeData],
) -> Unit {
  self.nodes_data.set(node.id, data)
}
