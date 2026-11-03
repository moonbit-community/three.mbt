// examples/jsm/tsl/lighting/LightProbeGridNode.js. The light is an add-on
// `LightProbeGrid` (examples/jsm/lighting/LightProbeGrid.js, a `Light`): its grid data
// (`texture`, `boundingBox`, `resolution`, `priority`) is read through the
// `@webgl.LightProbeGridSource` it registers (`@webgl.register_light_probe_grid`), its
// `intensity` from the core `Light`.

///|
/// Padding texels at each boundary of every atlas sub-volume.
pub const ATLAS_PADDING : Int32 = 1

///|
/// The registered grid data of a `LightProbeGrid` light.
fn light_probe_grid_node_source(
  light : @core.Object3D,
) -> &@webgl.LightProbeGridSource {
  match @webgl.light_probe_grid_of(light) {
    Some(source) => source
    None =>
      abort("LightProbeGridNode: the light is not a registered LightProbeGrid")
  }
}

///|
/// `texture3D( light.texture )`.
fn light_probe_grid_node_texture(light : @core.Object3D) -> @nodes.Node {
  match light_probe_grid_node_source(light).texture() {
    Some(t) => @nodes.texture3d(t)
    None => @nodes.texture3d(@nodes.TslValue::Null)
  }
}

///|
/// `evaluateGridIrradiance( atlas, uvw, res, normal )`: samples the packed SH atlas
/// (seven RGBA sub-volumes stacked along Z, each with one padding slice at both ends)
/// and evaluates the non-negative L2 irradiance.
fn light_probe_grid_node_evaluate_grid_irradiance(
  atlas : @nodes.Node,
  uvw : @nodes.Node,
  res : @nodes.Node,
  normal : @nodes.Node,
) -> @nodes.Node {
  let nz = res.z()
  let padded_slices = nz.add(2.0 * ATLAS_PADDING.to_double())
  let atlas_depth = padded_slices.mul(7.0)
  let uv_z_base = uvw.z().mul(nz).add(ATLAS_PADDING)
  let slice = fn(t : Int32) {
    atlas.sample(
      @nodes.vec3_of([
        uvw.xy(),
        uv_z_base.add(padded_slices.mul(t)).div(atlas_depth),
      ]),
    )
  }
  let s0 = slice(0)
  let s1 = slice(1)
  let s2 = slice(2)
  let s3 = slice(3)
  let s4 = slice(4)
  let s5 = slice(5)
  let s6 = slice(6)
  // Unpack 9 vec3 L2 SH coefficients and evaluate irradiance.
  let sh = @nodes.array([
    s0.xyz(),
    @nodes.vec3_of([s0.w(), s1.xy()]),
    @nodes.vec3_of([s1.zw(), s2.x()]),
    s2.yzw(),
    s3.xyz(),
    @nodes.vec3_of([s3.w(), s4.xy()]),
    @nodes.vec3_of([s4.zw(), s5.x()]),
    s5.yzw(),
    s6.xyz(),
  ])
  @nodes.get_sh_irradiance_at.call([normal, sh]).max(@nodes.vec3(0.0))
}

///|
/// `getGridIrradiance( light, min, max, res, intensity, position, normal )`.
fn light_probe_grid_node_get_grid_irradiance(
  light : @core.Object3D,
  min : @nodes.Node,
  max : @nodes.Node,
  res : @nodes.Node,
  intensity : @nodes.Node,
  position : @nodes.Node,
  normal : @nodes.Node,
) -> @nodes.Node {
  let range = max.sub(min)
  let spacing = range.div(res)
  // Offset along the normal by half a probe spacing. The bounds hold one cell per
  // probe, so they map directly to the probe grid; clamp to the outermost texel centers.
  let sample_pos = position.add(normal.mul(spacing).mul(0.5))
  let half_texel = @nodes.vec3(0.5).div(res)
  let uvw = sample_pos
    .sub(min)
    .div(range)
    .clamp(low=half_texel, high=half_texel.one_minus())
  light_probe_grid_node_evaluate_grid_irradiance(
    light_probe_grid_node_texture(light),
    uvw,
    res,
    normal,
  ).mul(intensity)
}

///|
/// `lightProbeGridIrradiance( light, position, normal )`: the irradiance of a baked
/// `LightProbeGrid` at a world-space position and normal, outside the lighting context.
pub fn light_probe_grid_irradiance(
  light : @core.Object3D,
  position : &@nodes.IntoTsl,
  normal : &@nodes.IntoTsl,
) -> @nodes.Node {
  let source = light_probe_grid_node_source(light)
  let box = source.bounding_box()
  light_probe_grid_node_get_grid_irradiance(
    light,
    @nodes.uniform(box.min),
    @nodes.uniform(box.max),
    @nodes.uniform(source.resolution()),
    @nodes.uniform(light.as_light().intensity),
    addon_node_object(position),
    addon_node_object(normal),
  )
}

///|
/// The light node of a `LightProbeGrid`: adds the grid's irradiance at the surface to
/// the lighting context.
pub(all) struct LightProbeGridNode {
  analytic : @nodes.AnalyticLightNode
  _min : @nodes.Node
  _max : @nodes.Node
  _resolution : @nodes.Node
  _intensity : @nodes.Node
  _priority : @nodes.Node
}

///|
pub impl @nodes.NodeClass for LightProbeGridNode with fn class_name(_) {
  "LightProbeGridNode"
}

///|
pub impl @nodes.NodeClass for LightProbeGridNode with fn parent(self) {
  Some(self.analytic)
}

///|
pub impl @nodes.NodeClass for LightProbeGridNode with fn update(self, _, _) {
  let light = self.analytic.light.unwrap()
  let source = light_probe_grid_node_source(light)
  let box = source.bounding_box()
  light_probe_grid_node_vector3(self._min).copy(box.min) |> ignore
  light_probe_grid_node_vector3(self._max).copy(box.max) |> ignore
  light_probe_grid_node_vector3(self._resolution).copy(source.resolution())
  |> ignore
  @nodes.InputNode::set_value(
    self._intensity,
    Number(light.as_light().intensity),
  )
  @nodes.InputNode::set_value(self._priority, Number(source.priority()))
  None
}

///|
pub impl @nodes.NodeClass for LightProbeGridNode with fn setup(self, _, builder) {
  let light = self.analytic.light.unwrap()
  let min = self._min
  let max = self._max
  let res = self._resolution
  let spacing = max.sub(min).div(res)
  let sample_pos = @nodes.position_world.add(
    @nodes.normal_world.mul(spacing).mul(0.5),
  )
  // Grow the bounds by 1% of a cell, so fragments on the bounds aren't left out by
  // precision errors or samples outside of the triangle.
  let margin = spacing.mul(0.01)
  let inside = sample_pos
    .greater_than_equal(min.sub(margin))
    .all()
    .and_(sample_pos.less_than_equal(max.add(margin)).all())
  let context = builder.context
  if context.get_node("lightProbeIrradiance") is None {
    context.set(
      "lightProbeIrradiance",
      Node(@nodes.vec3_of([]).to_var(name="lightProbeIrradiance")),
    )
  }
  if context.get_node("lightProbePriority") is None {
    context.set(
      "lightProbePriority",
      Node(@nodes.infinity.negate().to_var(name="lightProbePriority")),
    )
  }
  let prioritized = self._priority.greater_than_equal(
    context.get_node("lightProbePriority").unwrap(),
  )
  @nodes.if_(inside.and_(prioritized), fn() {
    let irradiance = light_probe_grid_node_get_grid_irradiance(
      light,
      min,
      max,
      res,
      self._intensity,
      @nodes.position_world,
      @nodes.normal_world,
    ).to_const()
    // fragments can be located in multiple grids but only the one with the highest priority defines the irradiance,
    // on ties the most recently created grid wins, see #34798
    context.get_node("lightProbeIrradiance").unwrap().assign(irradiance)
    context.get_node("lightProbePriority").unwrap().assign(self._priority)
  })
  |> ignore
  None
}

///|
pub impl @nodes.AnalyticLightNodeClass for LightProbeGridNode with fn analytic_parent(
  self,
) {
  Some(self.analytic)
}

///|
/// The `Vector3` value of a vector uniform.
fn light_probe_grid_node_vector3(node : @nodes.Node) -> @math.Vector3 {
  match @nodes.InputNode::get_value(node) {
    Vector3(v) => v
    _ => abort("LightProbeGridNode: not a vec3 uniform")
  }
}

///|
/// The constructor body after `super( light )`.
pub fn LightProbeGridNode::construct(
  node : @nodes.Node,
  light : @core.Object3D?,
) -> LightProbeGridNode {
  let analytic = @nodes.AnalyticLightNode::construct(node, light)
  // Bounce grid intensity changes between bake passes within a frame.
  let _min = @nodes.uniform(@math.Vector3::new(0.0, 0.0, 0.0))
  let _max = @nodes.uniform(@math.Vector3::new(0.0, 0.0, 0.0))
  let _resolution = @nodes.uniform(@math.Vector3::new(0.0, 0.0, 0.0))
  let _intensity = @nodes.uniform(1).set_group(@nodes.render_group)
  let _priority = @nodes.uniform(0).set_group(@nodes.render_group)
  node.update_type = @nodes.NodeUpdateType::render()
  { analytic, _min, _max, _resolution, _intensity, _priority, }
}

///|
/// `new LightProbeGridNode( light = null )`.
pub fn LightProbeGridNode::new(light? : @core.Object3D) -> @nodes.Node {
  let node = @nodes.AnalyticLightNode::alloc()
  let payload = LightProbeGridNode::construct(node, light)
  payload.analytic.class_ = payload
  node.set_class(payload)
}

///|
pub fn LightProbeGridNode::of(node : @nodes.Node) -> LightProbeGridNode? {
  addon_class_of(node, "LightProbeGridNode")
}

///|
/// The value `LightProbeGrid.registerNode( LightProbeGridNode )` stores.
pub fn LightProbeGridNode::node_class() -> @core.JsValue {
  @core.JsValue::of(@nodes.LightNodeClass::{
    create: fn(light) { LightProbeGridNode::new(light~) },
  })
}
