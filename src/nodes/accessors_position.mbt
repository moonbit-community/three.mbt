// nodes/accessors/Position.js

///|
/// `builder.context.setupPositionView()` and the other `setup*` callbacks a node
/// material puts in the context.
pub(all) struct ContextSetup {
  f : () -> Node
}

///|
fn position_context_setup(context : NodeContext, key : String) -> ContextSetup? {
  match context.get(key) {
    Other(_) as v => v.cast()
    _ => None
  }
}

///|
/// `builder.context.setupPositionView`, if set.
pub fn NodeContext::get_setup_position_view(
  self : NodeContext,
) -> ContextSetup? {
  position_context_setup(self, "setupPositionView")
}

///|
/// `builder.context.setupModelViewProjection`, if set.
pub fn NodeContext::get_setup_model_view_projection(
  self : NodeContext,
) -> ContextSetup? {
  position_context_setup(self, "setupModelViewProjection")
}

///|
/// `builder.context.setupNormal`, if set.
pub fn NodeContext::get_setup_normal(self : NodeContext) -> ContextSetup? {
  position_context_setup(self, "setupNormal")
}

///|
/// `builder.context.setupClearcoatNormal`, if set.
pub fn NodeContext::get_setup_clearcoat_normal(
  self : NodeContext,
) -> ContextSetup? {
  position_context_setup(self, "setupClearcoatNormal")
}

///|
/// Calls the context callback `key`; aborts like upstream's `TypeError` if unset.
fn position_call_setup(builder : NodeBuilder, key : String) -> Node {
  match position_context_setup(builder.context, key) {
    Some(setup) => (setup.f)()
    None => abort("TypeError: builder.context.\{key} is not a function")
  }
}

///|
/// `clipSpace`: the clip-space position, in the fragment stage only.
pub let clip_space : Node = module_nodes(
  "nodes/accessors/Position.js:clipSpace",
  fn() {
    fn_(fn(_, builder) {
      if builder.shader_stage != Some("fragment") {
        @core.warn_once("TSL: `clipSpace` is only available in fragment stage.")
        return Some(vec4_of([]))
      }
      match builder.context.get_node("clipSpace") {
        Some(clip_space) => Some(clip_space.to_varying(name="v_clipSpace"))
        None =>
          abort(
            "TypeError: Cannot read properties of undefined (reading 'toVarying')",
          )
      }
    })
    .once()
    .call([])
  },
)

///|
pub let position_geometry : Node = module_nodes(
  "nodes/accessors/Position.js:positionGeometry",
  fn() { attribute("position", node_type="vec3") },
)

///|
pub let position_local : Node = module_nodes(
  "nodes/accessors/Position.js:positionLocal",
  fn() { position_geometry.to_varying(name="positionLocal") },
)

///|
pub let position_previous : Node = module_nodes(
  "nodes/accessors/Position.js:positionPrevious",
  fn() { position_geometry.to_varying(name="positionPrevious") },
)

///|
pub let position_world : Node = module_nodes(
  "nodes/accessors/Position.js:positionWorld",
  fn() {
    fn_(
      fn(_, builder) {
        Some(
          model_world_matrix
          .mul(position_local)
          .xyz()
          .to_varying(
            name=builder.get_sub_build_property(property="v_positionWorld"),
          ),
        )
      },
      layout=ReturnType("vec3"),
    )
    .once(sub_builds=["POSITION"])
    .call([])
  },
)

///|
pub let position_world_direction : Node = module_nodes(
  "nodes/accessors/Position.js:positionWorldDirection",
  fn() {
    fn_(
      fn(_, _) {
        let vertex_pwd = position_local
          .transform_direction(model_world_matrix)
          .to_varying(name="v_positionWorldDirection")
        Some(vertex_pwd.normalize().to_var(name="positionWorldDirection"))
      },
      layout=ReturnType("vec3"),
    )
    .once(sub_builds=["POSITION"])
    .call([])
  },
)

///|
pub let position_view : Node = module_nodes(
  "nodes/accessors/Position.js:positionView",
  fn() {
    fn_(
      fn(_, builder) {
        let vertex_node = match builder.material {
          Some(m) =>
            match NodeMaterial::of(m) {
              Some(nm) => nm.vertex_node
              None => None
            }
          None => None
        }
        if builder.shader_stage == Some("fragment") && vertex_node is Some(_) {
          // reconstruct view position from clip space
          let view_pos = camera_projection_matrix_inverse.mul(clip_space)
          return Some(
            view_pos.xyz().div(view_pos.w()).to_var(name="positionView"),
          )
        }
        Some(
          position_call_setup(builder, "setupPositionView").to_varying(
            name="v_positionView",
          ),
        )
      },
      layout=ReturnType("vec3"),
    )
    .once(sub_builds=["POSITION", "VERTEX"])
    .call([])
  },
)

///|
pub let position_view_direction : Node = module_nodes(
  "nodes/accessors/Position.js:positionViewDirection",
  fn() {
    fn_(
      fn(_, builder) {
        let output = if builder.camera.unwrap().is_orthographic_camera() {
          vec3_of([0, 0, 1])
        } else {
          position_view
          .negate()
          .to_varying(name="v_positionViewDirection")
          .normalize()
        }
        Some(output.to_var(name="positionViewDirection"))
      },
      layout=ReturnType("vec3"),
    )
    .once(sub_builds=["POSITION"])
    .call([])
  },
)
