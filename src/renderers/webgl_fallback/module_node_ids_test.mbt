// Upstream's ids for the nodes this package creates at module load (see
// src/nodes/core_module_node_ids.mbt and tools/gen_module_node_ids.mjs).

///|
test "the backend's module-level nodes are created as upstream creates them" {
  let mine = @nodes.module_node_ids_status().filter(fn(s) {
    s.3.has_prefix("src/renderers/webgl_fallback/")
  })
  inspect(mine.length(), content="1")
  for s in mine {
    let (key, _, _, _, calls, upstream, created) = s
    assert_eq(calls, 1, msg=key)
    assert_eq(created, upstream, msg=key)
  }
}
