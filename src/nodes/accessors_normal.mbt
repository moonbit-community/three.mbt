// nodes/accessors/Normal.js

///|
pub let normal_geometry : Node = module_nodes(
  "nodes/accessors/Normal.js:normalGeometry",
  fn() { attribute("normal", node_type="vec3") },
)

///|
pub let normal_local : Node = module_nodes(
  "nodes/accessors/Normal.js:normalLocal",
  fn() {
    fn_(
      fn(_, builder) {
        let has_normal = match builder.geometry {
          Some(g) => g.has_attribute("normal")
          None =>
            abort(
              "TypeError: Cannot read properties of null (reading 'hasAttribute')",
            )
        }
        if !has_normal {
          @core.warn("TSL: Vertex attribute \"normal\" not found on geometry.")
          return Some(vec3_of([0, 1, 0]))
        }
        Some(normal_geometry)
      },
      layout=ReturnType("vec3"),
    )
    .once()
    .call([])
    .to_var(name="normalLocal")
  },
)

///|
pub let normal_flat : Node = module_nodes(
  "nodes/accessors/Normal.js:normalFlat",
  fn() {
    position_view
    .d_fdx()
    .cross(position_view.d_fdy())
    .normalize()
    .to_var(name="normalFlat")
  },
)

///|
pub let normal_view_geometry : Node = module_nodes(
  "nodes/accessors/Normal.js:normalViewGeometry",
  fn() {
    fn_(
      fn(_, builder) {
        let node = if builder.is_flat_shading() {
          normal_flat
        } else {
          transform_normal_to_view
          .call([normal_local])
          .to_varying(name="v_normalViewGeometry")
          .normalize()
        }
        Some(node)
      },
      layout=ReturnType("vec3"),
    )
    .once()
    .call([])
    .to_var(name="normalViewGeometry")
  },
)

///|
pub let normal_world_geometry : Node = module_nodes(
  "nodes/accessors/Normal.js:normalWorldGeometry",
  fn() {
    fn_(
      fn(_, builder) {
        let mut normal = normal_view_geometry.transform_normal_by_inverse_view_matrix(
          camera_view_matrix,
        )
        if !builder.is_flat_shading() {
          normal = normal.to_varying(name="v_normalWorldGeometry")
        }
        Some(normal.normalize().to_var(name="normalWorldGeometry"))
      },
      layout=ReturnType("vec3"),
    )
    .once()
    .call([])
  },
)

///|
/// `.context( { getUV: null, getTextureLevel: null } )`.
fn normal_clear_texture_context() -> NodeContext {
  node_context([("getUV", Null), ("getTextureLevel", Null)])
}

///|
pub let normal_view : Node = module_nodes(
  "nodes/accessors/Normal.js:normalView",
  fn() {
    fn_(
      fn(_, builder) {
        let node = if builder.sub_build_fn == Some("NORMAL") ||
          builder.sub_build_fn == Some("VERTEX") {
          let mut node = normal_view_geometry
          if !builder.is_flat_shading() {
            node = negate_on_back_side.call([node])
          }
          node
        } else {
          position_call_setup(builder, "setupNormal").context(
            value=normal_clear_texture_context(),
          )
        }
        Some(node)
      },
      layout=ReturnType("vec3"),
    )
    .once(sub_builds=["NORMAL", "VERTEX"])
    .call([])
    .to_var(name="normalView")
  },
)

///|
pub let normal_world : Node = module_nodes(
  "nodes/accessors/Normal.js:normalWorld",
  fn() {
    normal_view
    .transform_normal_by_inverse_view_matrix(camera_view_matrix)
    .to_var(name="normalWorld")
  },
)

///|
pub let clearcoat_normal_view : Node = module_nodes(
  "nodes/accessors/Normal.js:clearcoatNormalView",
  fn() {
    fn_(
      fn(_, builder) {
        let node = if builder.sub_build_fn == Some("NORMAL") ||
          builder.sub_build_fn == Some("VERTEX") {
          normal_view
        } else {
          position_call_setup(builder, "setupClearcoatNormal").context(
            value=normal_clear_texture_context(),
          )
        }
        Some(node)
      },
      layout=ReturnType("vec3"),
    )
    .once(sub_builds=["NORMAL", "VERTEX"])
    .call([])
    .to_var(name="clearcoatNormalView")
  },
)

///|
/// `transformNormal( normal, matrix = modelWorldMatrix )`.
pub let transform_normal : Node = module_nodes(
  "nodes/accessors/Normal.js:transformNormal",
  fn() {
    fn_(fn(inputs, _) {
      let normal = inputs.get(0).unwrap()
      let matrix = inputs.get(1).unwrap_or_else(fn() { model_world_matrix })
      let normal_matrix = mat3(matrix).inverse().transpose()
      Some(normal_matrix.mul(normal).normalize())
    })
  },
)

///|
/// `transformNormal( matrix )`, chained.
pub fn Node::transform_normal(self : Node, matrix? : &IntoTsl) -> Node {
  match matrix {
    Some(m) => transform_normal.call([self, m])
    None => transform_normal.call([self])
  }
}

///|
/// `transformNormalToView( normal )`.
pub let transform_normal_to_view : Node = module_nodes(
  "nodes/accessors/Normal.js:transformNormalToView",
  fn() {
    fn_(fn(inputs, builder) {
      let normal = inputs.get(0).unwrap()
      match builder.context.get_node("modelNormalViewMatrix") {
        Some(model_normal_view_matrix) =>
          return Some(
            normal.transform_normal_by_view_matrix(model_normal_view_matrix),
          )
        None => ()
      }
      let transformed_normal = model_normal_matrix.mul(normal)
      Some(
        transformed_normal.transform_normal_by_view_matrix(camera_view_matrix),
      )
    })
  },
)
