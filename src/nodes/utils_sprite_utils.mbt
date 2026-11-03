// nodes/utils/SpriteUtils.js: `billboarding`, a vertex position facing the camera.

///|
/// `billboarding( { position = null, horizontal = true, vertical = false,
/// horizontalRotation = false } )`: call it with `billboarding.call_named({...})`.
pub let billboarding : Node = module_nodes(
  "nodes/utils/SpriteUtils.js:billboarding",
  fn() {
    fn_(fn(inputs, _) {
      let position = inputs.named("position")
      let horizontal : TslValue = match inputs.named("horizontal") {
        Some(n) => Node(n)
        None => Bool(true)
      }
      let vertical : TslValue = match inputs.named("vertical") {
        Some(n) => Node(n)
        None => Bool(false)
      }
      let horizontal_rotation : TslValue = match
        inputs.named("horizontalRotation") {
        Some(n) => Node(n)
        None => Bool(false)
      }
      let center = match position {
        Some(p) => node_object(Node(p))
        None =>
          position_world.sub(
            model_world_matrix.mul(vec4_of([position_geometry, 0])).xyz(),
          )
      }
      let world_matrix = model_world_matrix.to_var()
      world_matrix[3][0] = center.x()
      world_matrix[3][1] = center.y()
      world_matrix[3][2] = center.z()
      let model_view_matrix = camera_view_matrix.mul(world_matrix)
      let scale_x = model_world_matrix[0].length()
      let scale_y = model_world_matrix[1].length()
      let scale_z = model_world_matrix[2].length()
      let mut right : Node? = None
      let mut up : Node? = None
      let mut forward : Node? = None
      if defined(horizontal_rotation) {
        let world_position = world_matrix[3].xyz()
        let look = camera_position.sub(world_position)
        let look_xz = vec3_of([look.x(), 0, look.z()]).normalize()
        let right_w = vec3_of([look_xz.z(), 0, look_xz.x().negate()])
        right = Some(
          camera_view_matrix.mul(vec4_of([right_w, 0])).xyz().mul(scale_x),
        )
        up = Some(camera_view_matrix[1].xyz().mul(scale_y))
        forward = Some(
          camera_view_matrix.mul(vec4_of([look_xz, 0])).xyz().mul(scale_z),
        )
      } else {
        if defined(horizontal) {
          right = Some(vec3_of([scale_x, 0, 0]))
        }
        if defined(vertical) {
          up = Some(vec3_of([0, scale_y, 0]))
        }
        forward = Some(vec3_of([0, 0, 1]))
      }
      if right is Some(right) {
        model_view_matrix[0][0] = right.x()
        model_view_matrix[0][1] = right.y()
        model_view_matrix[0][2] = right.z()
      }
      if up is Some(up) {
        model_view_matrix[1][0] = up.x()
        model_view_matrix[1][1] = up.y()
        model_view_matrix[1][2] = up.z()
      }
      if forward is Some(forward) {
        model_view_matrix[2][0] = forward.x()
        model_view_matrix[2][1] = forward.y()
        model_view_matrix[2][2] = forward.z()
      }
      Some(
        camera_projection_matrix.mul(model_view_matrix).mul(position_geometry),
      )
    })
  },
)
