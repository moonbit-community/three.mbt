// examples/jsm/tsl/utils/Raymarching.js

///|
priv struct RaymarchingModule {
  hit_box : @nodes.Node
}

///|
let utils_raymarching_module : AddonModule[RaymarchingModule] = AddonModule::new(fn() {
    let hit_box = @nodes.fn_(
      fn(inputs, _) {
        let orig = inputs.named("orig").unwrap()
        let dir = inputs.named("dir").unwrap()
        let box_min = @nodes.vec3(-0.5)
        let box_max = @nodes.vec3(0.5)
        let inv_dir = dir.reciprocal()
        let tmin_tmp = box_min.sub(orig).mul(inv_dir)
        let tmax_tmp = box_max.sub(orig).mul(inv_dir)
        let tmin = @nodes.min(tmin_tmp, tmax_tmp)
        let tmax = @nodes.max(tmin_tmp, tmax_tmp)
        let t0 = @nodes.max(tmin.x(), @nodes.max(tmin.y(), tmin.z()))
        let t1 = @nodes.min(tmax.x(), @nodes.min(tmax.y(), tmax.z()))
        Some(@nodes.vec2_of([t0, t1]))
      },
      layout=addon_short_layout([("orig", "vec3"), ("dir", "vec3")], "vec2"),
    )
    { hit_box, }
  },
)

///|
/// Evaluates Raymarching.js, as `import` does.
pub fn load_utils_raymarching() -> Unit {
  utils_raymarching_module.get() |> ignore
}

///|
/// `RaymarchingBox( steps, callback )`: marches the unit box of the object being drawn,
/// calling `callback( positionRay, stepSize )` (upstream's `{ positionRay, stepSize }`)
/// once per step inside the loop.
pub fn raymarching_box(
  steps : &@nodes.IntoTsl,
  callback : (@nodes.Node, @nodes.Node) -> Unit,
) -> Unit {
  let hit_box = utils_raymarching_module.get().hit_box
  let v_origin = @nodes.varying(
    @nodes.vec3(
      @nodes.model_world_matrix_inverse.mul(
        @nodes.vec4_of([@nodes.camera_position, 1.0]),
      ),
    ),
  )
  let v_direction = @nodes.varying(@nodes.position_geometry.sub(v_origin))
  let ray_dir = v_direction.normalize()
  let bounds = @nodes.vec2(
    hit_box.call_named({ "orig": v_origin, "dir": ray_dir }),
  ).to_var()
  bounds.x().greater_than(bounds.y()).discard()
  bounds.assign(@nodes.vec2_of([@nodes.max(bounds.x(), 0.0), bounds.y()]))
  let inc = @nodes.vec3(ray_dir.abs().reciprocal()).to_var()
  let step_size = @nodes.float(
    @nodes.min(inc.x(), @nodes.min(inc.y(), inc.z())),
  ).to_var()
  step_size.div_assign(@nodes.float(steps))
  let position_ray = @nodes.vec3(v_origin.add(bounds.x().mul(ray_dir))).to_var()
  @nodes.loop_(
    [
      @nodes.loop_range(
        type_="float",
        start=bounds.x(),
        end=bounds.y(),
        update=step_size,
      ),
    ],
    fn(_) {
      callback(position_ray, step_size)
      position_ray.add_assign(ray_dir.mul(step_size))
    },
  )
}
