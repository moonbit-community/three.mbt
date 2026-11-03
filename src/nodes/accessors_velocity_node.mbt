// nodes/accessors/VelocityNode.js: the screen-space motion of a vertex since the last
// frame (for motion blur and TRAA).

///|
/// The previous and current matrices of an object or camera.
priv struct VelocityData {
  mut frame_id : Int32?
  mut previous_model_world_matrix : @math.Matrix4?
  mut current_model_world_matrix : @math.Matrix4?
  mut previous_projection_matrix : @math.Matrix4?
  mut previous_camera_view_matrix : @math.Matrix4?
  mut current_projection_matrix : @math.Matrix4?
  mut current_camera_view_matrix : @math.Matrix4?
}

///|
let _velocity_object_data : @webgl.WeakMap[@core.Object3D, VelocityData] = @webgl.WeakMap::new()

///|
/// `getData( object )`.
fn velocity_get_data(object : @core.Object3D) -> VelocityData {
  match _velocity_object_data.get(object) {
    Some(d) => d
    None => {
      let d = VelocityData::{
        frame_id: None,
        previous_model_world_matrix: None,
        current_model_world_matrix: None,
        previous_projection_matrix: None,
        previous_camera_view_matrix: None,
        current_projection_matrix: None,
        current_camera_view_matrix: None,
      }
      _velocity_object_data.set(object, d)
      d
    }
  }
}

///|
pub(all) struct VelocityNode {
  mut projection_matrix : @math.Matrix4?
  previous_model_world_matrix : Node
  current_projection_matrix : Node
  previous_projection_matrix : Node
  previous_camera_view_matrix : Node
}

///|
pub impl NodeClass for VelocityNode with fn class_name(_) {
  "VelocityNode"
}

///|
pub impl NodeClass for VelocityNode with fn children(self, _, out) {
  push_child(
    out,
    "previousModelWorldMatrix",
    Some(self.previous_model_world_matrix),
  )
  push_child(
    out,
    "currentProjectionMatrix",
    Some(self.current_projection_matrix),
  )
  push_child(
    out,
    "previousProjectionMatrix",
    Some(self.previous_projection_matrix),
  )
  push_child(
    out,
    "previousCameraViewMatrix",
    Some(self.previous_camera_view_matrix),
  )
}

///|
fn velocity_matrix(node : Node) -> @math.Matrix4 {
  match InputNode::get_value(node) {
    Matrix4(m) => m
    _ => abort("VelocityNode: uniform value is not a Matrix4")
  }
}

///|
pub impl NodeClass for VelocityNode with fn update(self, _, frame) {
  let frame_id = frame.frame_id
  let camera = frame.camera.unwrap()
  let object = frame.object.unwrap()
  let object_data = velocity_get_data(object)
  if object_data.frame_id != Some(frame_id) {
    object_data.frame_id = Some(frame_id)
    if object_data.previous_model_world_matrix is None {
      object_data.previous_model_world_matrix = Some(@math.Matrix4::new())
      object_data.current_model_world_matrix = Some(@math.Matrix4::new())
      object_data.previous_model_world_matrix.unwrap().copy(object.matrix_world)
      |> ignore
    } else {
      object_data.previous_model_world_matrix
      .unwrap()
      .copy(object_data.current_model_world_matrix.unwrap())
      |> ignore
    }
    object_data.current_model_world_matrix.unwrap().copy(object.matrix_world)
    |> ignore
  }
  velocity_matrix(self.previous_model_world_matrix).copy(
    object_data.previous_model_world_matrix.unwrap(),
  )
  |> ignore
  let camera_data_ = velocity_get_data(camera)
  if camera_data_.frame_id != Some(frame_id) {
    camera_data_.frame_id = Some(frame_id)
    let projection_matrix = self.projection_matrix.unwrap_or(
      camera_data(camera).projection_matrix,
    )
    let matrix_world_inverse = camera_data(camera).matrix_world_inverse
    if camera_data_.previous_projection_matrix is None {
      camera_data_.previous_projection_matrix = Some(@math.Matrix4::new())
      camera_data_.previous_camera_view_matrix = Some(@math.Matrix4::new())
      camera_data_.current_projection_matrix = Some(@math.Matrix4::new())
      camera_data_.current_camera_view_matrix = Some(@math.Matrix4::new())
      camera_data_.previous_projection_matrix.unwrap().copy(projection_matrix)
      |> ignore
      camera_data_.previous_camera_view_matrix
      .unwrap()
      .copy(matrix_world_inverse)
      |> ignore
    } else {
      camera_data_.previous_projection_matrix
      .unwrap()
      .copy(camera_data_.current_projection_matrix.unwrap())
      |> ignore
      camera_data_.previous_camera_view_matrix
      .unwrap()
      .copy(camera_data_.current_camera_view_matrix.unwrap())
      |> ignore
    }
    camera_data_.current_projection_matrix.unwrap().copy(projection_matrix)
    |> ignore
    camera_data_.current_camera_view_matrix.unwrap().copy(matrix_world_inverse)
    |> ignore
    velocity_matrix(self.previous_projection_matrix).copy(
      camera_data_.previous_projection_matrix.unwrap(),
    )
    |> ignore
    velocity_matrix(self.previous_camera_view_matrix).copy(
      camera_data_.previous_camera_view_matrix.unwrap(),
    )
    |> ignore
    velocity_matrix(self.current_projection_matrix).copy(
      camera_data_.current_projection_matrix.unwrap(),
    )
    |> ignore
  }
  None
}

///|
pub impl NodeClass for VelocityNode with fn setup(self, _, _) {
  let previous_model_view_matrix = self.previous_camera_view_matrix.mul(
    self.previous_model_world_matrix,
  )
  let clip_position_current = self.current_projection_matrix
    .mul(model_view_matrix)
    .mul(position_local)
  let clip_position_previous = self.previous_projection_matrix
    .mul(previous_model_view_matrix)
    .mul(position_previous)
  let ndc_position_current = clip_position_current
    .xy()
    .div(clip_position_current.w())
  let ndc_position_previous = clip_position_previous
    .xy()
    .div(clip_position_previous.w())
  let velocity = sub(ndc_position_current, ndc_position_previous)
  Some(velocity)
}

///|
/// `new VelocityNode()`.
pub fn VelocityNode::new() -> Node {
  let node = Node::alloc(node_type="vec2")
  node.update_type = NodeUpdateType::object()
  let previous_model_world_matrix = uniform(@math.Matrix4::new())
  let current_projection_matrix = uniform(@math.Matrix4::new()).set_group(
    render_group,
  )
  let previous_projection_matrix = uniform(@math.Matrix4::new()).set_group(
    render_group,
  )
  let previous_camera_view_matrix = uniform(@math.Matrix4::new()).set_group(
    render_group,
  )
  node.set_class(VelocityNode::{
    projection_matrix: None,
    previous_model_world_matrix,
    current_projection_matrix,
    previous_projection_matrix,
    previous_camera_view_matrix,
  })
}

///|
pub fn VelocityNode::of(node : Node) -> VelocityNode? {
  match node.class_payload("VelocityNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `setProjectionMatrix( projectionMatrix )`.
pub fn VelocityNode::set_projection_matrix(
  node : Node,
  projection_matrix : @math.Matrix4?,
) -> Unit {
  VelocityNode::of(node).unwrap().projection_matrix = projection_matrix
}

///|
/// `velocity`.
pub let velocity : Node = module_nodes(
  "nodes/accessors/VelocityNode.js:velocity",
  fn() { VelocityNode::new() },
)
