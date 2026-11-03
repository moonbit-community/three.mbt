// nodes/accessors/Bitangent.js

///|
/// `getBitangent( crossNormalTangent, varyingName )`.
let _bitangent_get_bitangent : Node = module_nodes(
  "nodes/accessors/Bitangent.js:getBitangent",
  fn() {
    fn_(fn(inputs, builder) {
      let cross_normal_tangent = inputs.get(0).unwrap()
      let varying_name = match inputs.value(1) {
        String(s) => s
        _ => abort("getBitangent: varyingName must be a string")
      }
      let mut bitangent = cross_normal_tangent.mul(tangent_geometry.w()).xyz()
      if builder.sub_build_fn == Some("NORMAL") && !builder.is_flat_shading() {
        bitangent = bitangent.to_varying(name=varying_name)
      }
      Some(bitangent)
    }).once(sub_builds=["NORMAL"])
  },
)

///|
pub let bitangent_geometry : Node = module_nodes(
  "nodes/accessors/Bitangent.js:bitangentGeometry",
  fn() {
    _bitangent_get_bitangent
    .call([normal_geometry.cross(tangent_geometry), "v_bitangentGeometry"])
    .normalize()
    .to_var(name="bitangentGeometry")
  },
)

///|
pub let bitangent_local : Node = module_nodes(
  "nodes/accessors/Bitangent.js:bitangentLocal",
  fn() {
    _bitangent_get_bitangent
    .call([normal_local.cross(tangent_local), "v_bitangentLocal"])
    .normalize()
    .to_var(name="bitangentLocal")
  },
)

///|
pub let bitangent_view : Node = module_nodes(
  "nodes/accessors/Bitangent.js:bitangentView",
  fn() {
    fn_(
      fn(_, builder) {
        let mut node = if builder.sub_build_fn == Some("VERTEX") ||
          tangent_geometry_has(builder, "tangent") {
          _bitangent_get_bitangent
          .call([normal_view.cross(tangent_view), "v_bitangentView"])
          .normalize()
        } else {
          bitangent_view_frame
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
    .to_var(name="bitangentView")
  },
)

///|
pub let bitangent_world : Node = module_nodes(
  "nodes/accessors/Bitangent.js:bitangentWorld",
  fn() {
    _bitangent_get_bitangent
    .call([normal_world.cross(tangent_world), "v_bitangentWorld"])
    .normalize()
    .to_var(name="bitangentWorld")
  },
)
