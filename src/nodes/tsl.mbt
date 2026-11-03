// nodes/TSL.js re-exports every TSL function, node and constant of nodes/**. One package
// holds them all, so there is nothing to re-export: each name is defined once, in the
// file of the upstream module that exports it (PORTING.md names it). The list is checked
// against upstream by `node tools/check_tsl_exports.mjs`, which loads nodes/TSL.js under
// Node and looks up the MoonBit name of every export in src/nodes. The `Three.TSL.js`
// facade (src/webgpu) re-exports this package.
