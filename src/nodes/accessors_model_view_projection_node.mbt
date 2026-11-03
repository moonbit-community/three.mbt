// nodes/accessors/ModelViewProjectionNode.js

///|
/// `modelViewProjection`: the clip-space position the material computes.
pub let model_view_projection : Node = module_nodes(
  "nodes/accessors/ModelViewProjectionNode.js:modelViewProjection",
  fn() {
    fn_(
      fn(_, builder) {
        Some(position_call_setup(builder, "setupModelViewProjection"))
      },
      layout=ReturnType("vec4"),
    )
    .once()
    .call([])
    .to_varying(name="v_modelViewProjection")
  },
)
