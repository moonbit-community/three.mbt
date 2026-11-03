// Upstream's ids for the nodes created at module load (core_module_node_ids.mbt, generated
// by tools/gen_module_node_ids.mjs). See PORTING.md, "Byte-identical shaders".

///|
/// The statement whose nodes are being created: allocation takes ids from its base.
priv struct ModuleNodeScope {
  nodes : Array[Node]
}

///|
let _module_node_scope : Ref[ModuleNodeScope?] = Ref(None)

///|
/// `(calls, nodes created)` for every key `module_nodes` ran. The class names are only
/// read by `module_node_ids_status`: nothing on the load-time path may use a string
/// constant, because the release JS build can emit a hoisted literal after the
/// module-level lets that run `module_nodes` ("Cannot access ... before initialization").
let _module_node_ids_created : Map[String, (Int32, Array[Node])] = Map::from_array([],
)

///|
/// The lowest run-time counter value `module_nodes` saw (load-time allocations happen
/// while the counter is parked at `NODE_FIRST_RUNTIME_ID` or above).
let _module_nodes_lowest_runtime_id : Ref[Int32?] = Ref(None)

///|
/// The run-time node counter as the module-level lets found it: at least
/// `NODE_FIRST_RUNTIME_ID` unless the counter does not start there. `None` before any
/// `module_nodes` ran.
pub fn module_nodes_lowest_runtime_id() -> Int32? {
  _module_nodes_lowest_runtime_id.val
}

///|
/// Called by `Node::alloc` with the node it allocated.
fn module_nodes_note(node : Node) -> Unit {
  if _module_node_scope.val is Some(scope) {
    scope.nodes.push(node)
  }
}

///|
/// Runs the initializer of the top-level let that mirrors upstream's module-level
/// statement `key` (`<path below src>:<declared name>`, see core_module_node_ids.mbt),
/// giving the nodes it creates upstream's ids: consecutive from the statement's first id.
/// The run-time counter is left alone. Aborts on an unknown key.
pub fn[T] module_nodes(key : String, f : () -> T) -> T {
  guard module_node_ids_entry(key) is Some((base, _)) else {
    abort("module_nodes: unknown key \{key}")
  }
  let saved = _node_id.val
  match _module_nodes_lowest_runtime_id.val {
    Some(lowest) if lowest <= saved => ()
    _ => _module_nodes_lowest_runtime_id.val = Some(saved)
  }
  let outer = _module_node_scope.val
  let scope = ModuleNodeScope::{ nodes: [], }
  _node_id.val = base
  _module_node_scope.val = Some(scope)
  let result = f()
  _module_node_scope.val = outer
  _node_id.val = saved
  let calls = match _module_node_ids_created.get(key) {
    Some((c, _)) => c + 1
    None => 1
  }
  _module_node_ids_created[key] = (calls, scope.nodes)
  result
}

///|
/// `(key, first id, count, MoonBit file, calls, upstream classes, created classes)` for
/// every statement upstream creates nodes in at module load. Top-level lets are
/// initialized at load (those a program does not reach are dropped), so `calls` is 1 and
/// the two class lists agree once the let mirroring `key` is ported and linked.
pub fn module_node_ids_status() -> Array[
  (String, Int32, Int32, String, Int32, String, String),
] {
  module_node_ids_keys.mapi(fn(i, key) {
    let (base, count) = module_node_ids_entry(key).unwrap()
    let (calls, nodes) = _module_node_ids_created.get(key).unwrap_or((0, []))
    let classes = nodes.map(fn(n) { n.class_.class_name() }).join(" ")
    (
      key,
      base,
      count,
      module_node_ids_files[i],
      calls,
      module_node_ids_classes[i],
      classes,
    )
  })
}
