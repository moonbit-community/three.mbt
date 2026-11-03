// nodes/accessors/ModelNode.js: the Object3DNode uniforms of the rendered object, and the
// model matrices.

///|
let _model_node_model_view_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
pub(all) struct ModelNode {
  object3d_node : Object3DNode
}

///|
pub impl NodeClass for ModelNode with fn class_name(_) {
  "ModelNode"
}

///|
pub impl NodeClass for ModelNode with fn parent(self) {
  Some(self.object3d_node)
}

///|
pub impl NodeClass for ModelNode with fn update(self, node, frame) {
  self.object3d_node.object3d = frame.object
  self.object3d_node.update(node, frame)
}

///|
/// `new ModelNode( scope )`.
pub fn ModelNode::new(scope : String) -> Node {
  let node = Node::alloc()
  node.set_class(ModelNode::{
    object3d_node: Object3DNode::construct(node, scope, None),
  })
}

///|
pub fn ModelNode::of(node : Node) -> ModelNode? {
  match node.class_payload("ModelNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
pub let model_direction : Node = module_nodes(
  "nodes/accessors/ModelNode.js:modelDirection",
  fn() { ModelNode::new(Object3DNode::direction()) },
)

///|
pub let model_world_matrix : Node = module_nodes(
  "nodes/accessors/ModelNode.js:modelWorldMatrix",
  fn() { ModelNode::new(Object3DNode::world_matrix()) },
)

///|
pub let model_position : Node = module_nodes(
  "nodes/accessors/ModelNode.js:modelPosition",
  fn() { ModelNode::new(Object3DNode::position()) },
)

///|
pub let model_scale : Node = module_nodes(
  "nodes/accessors/ModelNode.js:modelScale",
  fn() { ModelNode::new(Object3DNode::scale()) },
)

///|
pub let model_view_position : Node = module_nodes(
  "nodes/accessors/ModelNode.js:modelViewPosition",
  fn() { ModelNode::new(Object3DNode::view_position()) },
)

///|
pub let model_radius : Node = module_nodes(
  "nodes/accessors/ModelNode.js:modelRadius",
  fn() { ModelNode::new(Object3DNode::radius()) },
)

///|
/// `modelNormalMatrix`.
pub let model_normal_matrix : Node = module_nodes(
  "nodes/accessors/ModelNode.js:modelNormalMatrix",
  fn() {
    uniform(@math.Matrix3::new()).on_object_update(fn(self_, frame) {
      match InputNode::get_value(self_) {
        Matrix3(m) =>
          m.get_normal_matrix(frame.object.unwrap().matrix_world) |> ignore
        _ => ()
      }
      None
    })
  },
)

///|
/// `modelWorldMatrixInverse`.
pub let model_world_matrix_inverse : Node = module_nodes(
  "nodes/accessors/ModelNode.js:modelWorldMatrixInverse",
  fn() {
    uniform(@math.Matrix4::new()).on_object_update(fn(self_, frame) {
      match InputNode::get_value(self_) {
        Matrix4(m) =>
          m.copy(frame.object.unwrap().matrix_world).invert() |> ignore
        _ => ()
      }
      None
    })
  },
)

///|
/// `modelViewMatrix`: the context's, or `mediumpModelViewMatrix`.
pub let model_view_matrix : Node = module_nodes(
  "nodes/accessors/ModelNode.js:modelViewMatrix",
  fn() {
    fn_(fn(_, builder) {
      match builder.context.get_node("modelViewMatrix") {
        Some(n) => Some(n)
        None => Some(mediump_model_view_matrix)
      }
    })
    .once()
    .call([])
    .to_var(name="modelViewMatrix")
  },
)

///|
/// `mediumpModelViewMatrix`.
pub let mediump_model_view_matrix : Node = module_nodes(
  "nodes/accessors/ModelNode.js:mediumpModelViewMatrix",
  fn() { camera_view_matrix.mul(model_world_matrix) },
)

///|
/// `highpModelViewMatrix`.
pub let highp_model_view_matrix : Node = module_nodes(
  "nodes/accessors/ModelNode.js:highpModelViewMatrix",
  fn() {
    fn_(fn(_, builder) {
      builder.context.set("isHighPrecisionModelViewMatrix", Bool(true))
      let camera = builder.camera.unwrap()
      let cameras = camera_sub_cameras(camera)
      if camera.is_array_camera() && cameras.length() > 0 {
        let matrices : Array[TslValue] = []
        for _ in cameras {
          matrices.push(Matrix4(@math.Matrix4::new()))
        }
        let model_view_matrices = uniform_array(matrices).on_object_update(fn(
          self_,
          frame,
        ) {
          let sub_cameras = camera_sub_cameras(frame.camera.unwrap())
          let array = UniformArrayNode::of(self_).unwrap().array
          let object = frame.object.unwrap()
          for i in 0..<sub_cameras.length() {
            match array[i] {
              Matrix4(m) =>
                m.multiply_matrices(
                  camera_data(sub_cameras[i]).matrix_world_inverse,
                  object.matrix_world,
                )
                |> ignore
              _ => ()
            }
          }
          None
        })
        Some(model_view_matrices.element(camera_array_index(camera)))
      } else {
        Some(
          uniform("mat4").on_object_update(fn(self_, frame) {
            let object = frame.object.unwrap()
            let camera = frame.camera.unwrap()
            InputNode::set_value(
              self_,
              Matrix4(
                object.model_view_matrix.multiply_matrices(
                  camera_data(camera).matrix_world_inverse,
                  object.matrix_world,
                ),
              ),
            )
            None
          }),
        )
      }
    })
    .once()
    .call([])
    .to_var(name="highpModelViewMatrix")
  },
)

///|
/// `highpModelNormalViewMatrix`.
pub let highp_model_normal_view_matrix : Node = module_nodes(
  "nodes/accessors/ModelNode.js:highpModelNormalViewMatrix",
  fn() {
    fn_(fn(_, builder) {
      let is_high_precision_model_view_matrix = builder.context.get_bool(
        "isHighPrecisionModelViewMatrix",
      )
      let camera = builder.camera.unwrap()
      let cameras = camera_sub_cameras(camera)
      if camera.is_array_camera() && cameras.length() > 0 {
        let matrices : Array[TslValue] = []
        for _ in cameras {
          matrices.push(Matrix3(@math.Matrix3::new()))
        }
        let normal_view_matrices = uniform_array(matrices).on_object_update(fn(
          self_,
          frame,
        ) {
          let sub_cameras = camera_sub_cameras(frame.camera.unwrap())
          let array = UniformArrayNode::of(self_).unwrap().array
          let object = frame.object.unwrap()
          for i in 0..<sub_cameras.length() {
            _model_node_model_view_matrix.multiply_matrices(
              camera_data(sub_cameras[i]).matrix_world_inverse,
              object.matrix_world,
            )
            |> ignore
            match array[i] {
              Matrix3(m) =>
                m.get_normal_matrix(_model_node_model_view_matrix) |> ignore
              _ => ()
            }
          }
          None
        })
        Some(normal_view_matrices.element(camera_array_index(camera)))
      } else {
        Some(
          uniform("mat3").on_object_update(fn(self_, frame) {
            let object = frame.object.unwrap()
            let camera = frame.camera.unwrap()
            if is_high_precision_model_view_matrix != Some(true) {
              object.model_view_matrix.multiply_matrices(
                camera_data(camera).matrix_world_inverse,
                object.matrix_world,
              )
              |> ignore
            }
            InputNode::set_value(
              self_,
              Matrix3(
                object.normal_matrix.get_normal_matrix(object.model_view_matrix),
              ),
            )
            None
          }),
        )
      }
    })
    .once()
    .call([])
    .to_var(name="highpModelNormalViewMatrix")
  },
)
