// nodes/accessors/TangentUtils.js: the tangent frame from screen-space derivatives.

///|
let _tangent_utils_uv : Node = module_nodes(
  "nodes/accessors/TangentUtils.js:uv",
  fn() { uv() },
)

///|
let _tangent_utils_q0 : Node = module_nodes(
  "nodes/accessors/TangentUtils.js:q0",
  fn() { position_view.d_fdx() },
)

///|
let _tangent_utils_q1 : Node = module_nodes(
  "nodes/accessors/TangentUtils.js:q1",
  fn() { position_view.d_fdy() },
)

///|
let _tangent_utils_st0 : Node = module_nodes(
  "nodes/accessors/TangentUtils.js:st0",
  fn() { _tangent_utils_uv.d_fdx() },
)

///|
let _tangent_utils_st1 : Node = module_nodes(
  "nodes/accessors/TangentUtils.js:st1",
  fn() { _tangent_utils_uv.d_fdy() },
)

///|
let _tangent_utils_n : Node = normal_view

///|
let _tangent_utils_q1perp : Node = module_nodes(
  "nodes/accessors/TangentUtils.js:q1perp",
  fn() { _tangent_utils_q1.cross(_tangent_utils_n) },
)

///|
let _tangent_utils_q0perp : Node = module_nodes(
  "nodes/accessors/TangentUtils.js:q0perp",
  fn() { _tangent_utils_n.cross(_tangent_utils_q0) },
)

///|
let _tangent_utils_t : Node = module_nodes(
  "nodes/accessors/TangentUtils.js:T",
  fn() {
    _tangent_utils_q1perp
    .mul(_tangent_utils_st0.x())
    .add(_tangent_utils_q0perp.mul(_tangent_utils_st1.x()))
  },
)

///|
let _tangent_utils_b : Node = module_nodes(
  "nodes/accessors/TangentUtils.js:B",
  fn() {
    _tangent_utils_q1perp
    .mul(_tangent_utils_st0.y())
    .add(_tangent_utils_q0perp.mul(_tangent_utils_st1.y()))
  },
)

///|
let _tangent_utils_det : Node = module_nodes(
  "nodes/accessors/TangentUtils.js:det",
  fn() {
    _tangent_utils_t
    .dot(_tangent_utils_t)
    .max(_tangent_utils_b.dot(_tangent_utils_b))
  },
)

///|
let _tangent_utils_scale : Node = module_nodes(
  "nodes/accessors/TangentUtils.js:scale",
  fn() {
    _tangent_utils_det
    .equal(0.0)
    .select(0.0, else_node=_tangent_utils_det.inverse_sqrt())
  },
)

///|
pub let tangent_view_frame : Node = module_nodes(
  "nodes/accessors/TangentUtils.js:tangentViewFrame",
  fn() {
    _tangent_utils_t.mul(_tangent_utils_scale).to_var(name="tangentViewFrame")
  },
)

///|
pub let bitangent_view_frame : Node = module_nodes(
  "nodes/accessors/TangentUtils.js:bitangentViewFrame",
  fn() {
    _tangent_utils_b.mul(_tangent_utils_scale).to_var(name="bitangentViewFrame")
  },
)
