// nodes/accessors/Tangent.js

///|
pub let tangent_geometry : Node = module_nodes(
  "nodes/accessors/Tangent.js:tangentGeometry",
  fn() { attribute("tangent", node_type="vec4") },
)

///|
pub let tangent_local : Node = module_nodes(
  "nodes/accessors/Tangent.js:tangentLocal",
  fn() { tangent_geometry.xyz().to_var(name="tangentLocal") },
)

///|
/// `builder.geometry.hasAttribute( name )`.
fn tangent_geometry_has(builder : NodeBuilder, name : String) -> Bool {
  match builder.geometry {
    Some(g) => g.has_attribute(name)
    None =>
      abort(
        "TypeError: Cannot read properties of null (reading 'hasAttribute')",
      )
  }
}

///|
pub let tangent_view : Node = module_nodes(
  "nodes/accessors/Tangent.js:tangentView",
  fn() {
    fn_(
      fn(_, builder) {
        let mut node = if builder.sub_build_fn == Some("VERTEX") ||
          tangent_geometry_has(builder, "tangent") {
          model_view_matrix
          .mul(vec4_of([tangent_local, 0]))
          .xyz()
          .to_varying(name="v_tangentView")
          .normalize()
        } else {
          tangent_view_frame
        }
        if !builder.is_flat_shading() {
          node = negate_on_back_side.call([node])
        }
        Some(node)
      },
      layout=ReturnType("vec3"),
    )
    .once(sub_builds=["NORMAL", "VERTEX"])
    .call([])
    .to_var(name="tangentView")
  },
)

///|
pub let tangent_world : Node = module_nodes(
  "nodes/accessors/Tangent.js:tangentWorld",
  fn() {
    tangent_view
    .transform_direction(camera_world_matrix)
    .to_varying(name="v_tangentWorld")
    .normalize()
    .to_var(name="tangentWorld")
  },
)
