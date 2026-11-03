// nodes/Nodes.js re-exports the node classes (`export { default as XNode }`), the core
// constants and `NodeUtils`. One package holds them all, so each class is its payload
// type here (`XNode`, with `XNode::new` returning a `Node`), and NodeUtils' functions are
// package functions (core_node_utils.mbt). `node tools/check_tsl_exports.mjs` checks
// every class name against src/nodes.
