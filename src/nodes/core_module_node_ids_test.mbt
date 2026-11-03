// Upstream's ids for the nodes created at module load (core_module_node_ids.mbt, generated
// by tools/gen_module_node_ids.mjs; `module_nodes` in core_module_nodes.mbt).

///|
test "module-level nodes are created as upstream creates them" {
  let status = @nodes.module_node_ids_status()
  let wrong = []
  for s in status {
    let (key, _, _, _, calls, upstream, created) = s
    if calls > 1 || (calls == 1 && upstream != created) {
      wrong.push(
        "\{key}: \{calls} calls, upstream [\{upstream}], port [\{created}]",
      )
    }
  }
  inspect(wrong.join("\n"), content="")
}

///|
test "module-level nodes have upstream's ids" {
  inspect(@nodes.camera_view_matrix.id, content="184")
  inspect(@nodes.background_blurriness.id, content="497")
  inspect(@nodes.background_rotation.id, content="499")
  inspect(@nodes.render_group.id, content="69")
  // nodes made at run time count on from upstream's first run-time id
  assert_true(@nodes.Node::new().id >= @nodes.NODE_FIRST_RUNTIME_ID)
  assert_true(
    @nodes.module_nodes_lowest_runtime_id().unwrap() >=
    @nodes.NODE_FIRST_RUNTIME_ID,
  )
  inspect(@nodes.NODE_FIRST_RUNTIME_ID, content="856")
}

///|
test "every module-level statement upstream creates nodes in is ported" {
  // lets nothing else in this test program reads (unread lets are not linked)
  let _ = [
    @nodes.point_width, @nodes.subgroup_index, @nodes.invocation_subgroup_index,
    @nodes.projection_depth, @nodes.mx_fractal_noise_float_2d_impl,
  ]
  let unlinked = @nodes.module_node_ids_status()
    .filter(fn(s) { s.4 == 0 })
    .map(fn(s) { s.0 })
  // `PI2` is deprecated and not ported (its id stays unused); the polyfills belong to
  // the backend packages, which check them.
  inspect(
    unlinked.join("\n"),
    content=(
      #|nodes/math/MathNode.js:PI2
      #|renderers/webgl-fallback/nodes/GLSLNodeBuilder.js:glslPolyfills
      #|renderers/webgpu/nodes/WGSLNodeBuilder.js:wgslPolyfill
    ),
  )
  inspect(@nodes.module_node_ids_status().length(), content="428")
}
