// nodes/fog/Fog.js: fog factors (range, density, exponential height) and `fog`.

///|
/// `context.getViewZ( node )`: the view-space z fog uses, as `ContextValue::Other`.
pub(all) struct ContextGetViewZ {
  f : (Node?) -> Node?
}

///|
/// `builder.context.getViewZ`, if set.
pub fn NodeContext::get_view_z(self : NodeContext) -> ContextGetViewZ? {
  match self.get("getViewZ") {
    Other(_) as v => v.cast()
    _ => None
  }
}

///|
/// `getViewZNode( builder )`: `-( context.getViewZ() || positionView.z )`.
fn fog_view_z_node(builder : NodeBuilder) -> Node {
  let mut view_z : Node? = None
  if builder.context.get_view_z() is Some(get_view_z) {
    // `getViewZ( this )`: `this` is `undefined` in the module function
    view_z = (get_view_z.f)(None)
  }
  view_z.unwrap_or_else(fn() { position_view.z() }).negate()
}

///|
/// `rangeFogFactor( near, far )`.
pub let range_fog_factor : Node = module_nodes(
  "nodes/fog/Fog.js:rangeFogFactor",
  fn() {
    fn_(fn(inputs, builder) {
      let near = operator_node_input(inputs, 0)
      let far = operator_node_input(inputs, 1)
      let view_z = fog_view_z_node(builder)
      Some(smoothstep(near, far, view_z))
    })
  },
)

///|
/// `densityFogFactor( density )`.
pub let density_fog_factor : Node = module_nodes(
  "nodes/fog/Fog.js:densityFogFactor",
  fn() {
    fn_(fn(inputs, builder) {
      let density = operator_node_input(inputs, 0)
      let view_z = fog_view_z_node(builder)
      Some(density.mul_of([density, view_z, view_z]).negate().exp().one_minus())
    })
  },
)

///|
/// `exponentialHeightFogFactor( density, height )`.
pub let exponential_height_fog_factor : Node = module_nodes(
  "nodes/fog/Fog.js:exponentialHeightFogFactor",
  fn() {
    fn_(fn(inputs, builder) {
      let density = operator_node_input(inputs, 0)
      let height = operator_node_input(inputs, 1)
      let view_z = fog_view_z_node(builder)
      let distance = height.sub(position_world.y()).max(0).to_const()
      let m = distance.mul(view_z).to_const()
      Some(density.mul_of([density, m, m]).negate().exp().one_minus())
    })
  },
)

///|
/// `fog( color, factor )`: the output color mixed towards the fog color.
pub let fog : Node = module_nodes("nodes/fog/Fog.js:fog", fn() {
  fn_(fn(inputs, _) {
    let color = operator_node_input(inputs, 0)
    let factor = operator_node_input(inputs, 1)
    Some(
      vec4_of([factor.to_float().mix(output.rgb(), color.to_vec3()), output.a()]),
    )
  })
})
