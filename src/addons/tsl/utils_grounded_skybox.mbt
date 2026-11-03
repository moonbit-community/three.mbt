// examples/jsm/tsl/utils/GroundedSkybox.js

///|
priv struct GroundedSkyboxModule {
  get_ground_projected_normal : @nodes.Node
}

///|
let utils_grounded_skybox_module : AddonModule[GroundedSkyboxModule] = AddonModule::new(fn() {
    let get_ground_projected_normal = @nodes.fn_(fn(inputs, _) {
      let radius_node = addon_arg(inputs, 0)
      let height_node = addon_arg(inputs, 1)
      let p = @nodes.position_world
        .sub(@nodes.camera_position)
        .normalize()
        .to_const()
      let cam_pos = @nodes.camera_position.to_var()
      cam_pos.y().sub_assign(height_node)
      // sphereIntersect( camPos, p, vec3( 0 ), radius )
      let b = cam_pos.dot(p).to_const()
      let c = cam_pos.dot(cam_pos).sub(radius_node.mul(radius_node)).to_const()
      let h = b.mul(b).sub(c).to_const()
      let intersection = h
        .greater_than_equal(0)
        .select(h.sqrt().sub(b), else_node=-1)
      let projected = @nodes.vec3_of([0, 1, 0]).to_var()
      @nodes.if_(intersection.greater_than(0), fn() {
        // diskIntersectWithBackFaceCulling( camPos, p, diskCenter, n, radius )
        let disk_center = @nodes.vec3_of([0, height_node.negate(), 0]).to_const()
        let n = @nodes.vec3_of([0, 1, 0]).to_const()
        let d = p.dot(n).to_const()
        let intersection2 = @nodes.float(1.0e6).to_var()
        @nodes.if_(d.less_than_equal(0), fn() {
          let o = cam_pos.sub(disk_center).to_const()
          let t = n.dot(o).negate().div(d).to_const()
          let q = o.add(p.mul(t)).to_const()
          @nodes.if_(q.dot(q).less_than(radius_node.mul(radius_node)), fn() {
            intersection2.assign(t)
          })
          |> ignore
        })
        |> ignore
        projected.assign(
          cam_pos
          .add(p.mul(@nodes.min(intersection, intersection2)))
          .div(radius_node),
        )
      })
      |> ignore
      Some(projected)
    })
    { get_ground_projected_normal, }
  },
)

///|
/// Evaluates GroundedSkybox.js, as `import` does.
pub fn load_utils_grounded_skybox() -> Unit {
  utils_grounded_skybox_module.get() |> ignore
}

///|
/// `getGroundProjectedNormal( radiusNode, heightNode )`: the skybox lookup direction of a
/// ground-projected (grounded) skybox.
pub fn get_ground_projected_normal() -> @nodes.Node {
  utils_grounded_skybox_module.get().get_ground_projected_normal
}
