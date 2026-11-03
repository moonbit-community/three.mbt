// nodes/accessors/Camera.js. The camera uniforms are built once per build in `Fn`s:
// one uniform for a camera, a `uniformArray` indexed by `cameraIndex` (or
// `gl_ViewID_OVR`) for array cameras.

///|
/// `_cameraArrays`: renderer -> `name:count` -> uniform array.
let _camera_arrays : @webgl.WeakMap[Renderer, Map[String, Node]] = @webgl.WeakMap::new()

///|
/// `getCameraArray( renderer, camera, name, create )`.
fn camera_get_camera_array(
  renderer : Renderer,
  camera : @core.Object3D,
  name : String,
  create : (@core.Object3D) -> Node,
) -> Node {
  let arrays = match _camera_arrays.get(renderer) {
    Some(a) => a
    None => {
      let a = {}
      _camera_arrays.set(renderer, a)
      a
    }
  }
  let key = name + ":" + camera_sub_cameras(camera).length().to_string()
  match arrays.get(key) {
    Some(array) => array
    None => {
      let array = create(camera)
      arrays.set(key, array)
      array
    }
  }
}

///|
/// The camera payload of an `Object3D` (upstream reads camera fields directly).
pub fn camera_data(camera : @core.Object3D) -> @core.Camera {
  match camera.kind {
    Camera(c) => c
    _ => abort("TypeError: \{camera.type_} is not a camera")
  }
}

///|
/// `camera.near`.
pub fn camera_near_of(camera : @core.Object3D) -> Double {
  match camera_data(camera).kind {
    PerspectiveCamera(p) => p.near
    OrthographicCamera(o) => o.near
    BaseCamera => 0.0 / 0.0
  }
}

///|
/// `camera.far`.
pub fn camera_far_of(camera : @core.Object3D) -> Double {
  match camera_data(camera).kind {
    PerspectiveCamera(p) => p.far
    OrthographicCamera(o) => o.far
    BaseCamera => 0.0 / 0.0
  }
}

///|
/// `camera.cameras` of an `ArrayCamera` (empty for other cameras).
pub fn camera_sub_cameras(camera : @core.Object3D) -> Array[@core.Object3D] {
  match camera.kind {
    Camera({ kind: PerspectiveCamera({ array_camera: Some(a), .. }), .. }) =>
      a.cameras
    _ => []
  }
}

///|
/// `camera.isArrayCamera && camera.cameras.length > 0`.
fn camera_is_array_with_cameras(camera : @core.Object3D) -> Bool {
  camera.is_array_camera() && camera_sub_cameras(camera).length() > 0
}

///|
/// `camera.isMultiViewCamera`.
pub fn camera_is_multi_view(camera : @core.Object3D) -> Bool {
  match camera.kind {
    Camera({ kind: PerspectiveCamera({ array_camera: Some(a), .. }), .. }) =>
      a.is_multi_view_camera
    _ => false
  }
}

///|
/// `camera.isMultiViewCamera ? builtin( 'gl_ViewID_OVR' ) : cameraIndex`.
fn camera_array_index(camera : @core.Object3D) -> Node {
  if camera_is_multi_view(camera) {
    builtin("gl_ViewID_OVR")
  } else {
    camera_index
  }
}

///|
let _camera_projection_matrix_base : Ref[Node?] = Ref(None)

///|
let _camera_projection_matrix_inverse_base : Ref[Node?] = Ref(None)

///|
let _camera_view_matrix_base : Ref[Node?] = Ref(None)

///|
let _camera_world_matrix_base : Ref[Node?] = Ref(None)

///|
let _camera_normal_matrix_base : Ref[Node?] = Ref(None)

///|
let _camera_position_base : Ref[Node?] = Ref(None)

///|
let _camera_viewport_base : Ref[Node?] = Ref(None)

///|
/// The frame's camera (`frame.camera`).
fn camera_of_frame(frame : NodeFrame) -> @core.Object3D {
  frame.camera.unwrap()
}

///|
/// `cameraIndex`: the index of the current camera of an array camera.
pub let camera_index : Node = module_nodes(
  "nodes/accessors/Camera.js:cameraIndex",
  fn() {
    uniform(0, type_="uint")
    .set_name("u_cameraIndex")
    .set_group(shared_uniform_group("cameraIndex"))
    .to_varying(name="v_cameraIndex")
  },
)

///|
/// `cameraNear`.
pub let camera_near : Node = module_nodes(
  "nodes/accessors/Camera.js:cameraNear",
  fn() {
    uniform("float")
    .set_name("cameraNear")
    .set_group(render_group)
    .on_render_update(fn(self_, frame) {
      InputNode::set_value(
        self_,
        Number(camera_near_of(camera_of_frame(frame))),
      )
      None
    })
  },
)

///|
/// `cameraFar`.
pub let camera_far : Node = module_nodes(
  "nodes/accessors/Camera.js:cameraFar",
  fn() {
    uniform("float")
    .set_name("cameraFar")
    .set_group(render_group)
    .on_render_update(fn(self_, frame) {
      InputNode::set_value(self_, Number(camera_far_of(camera_of_frame(frame))))
      None
    })
  },
)

///|
/// One camera matrix: the base uniform, or an element of the camera array.
fn camera_matrix_node(
  builder : NodeBuilder,
  array_name : String,
  base : Ref[Node?],
  base_name : String,
  get : (@core.Object3D) -> TslValue,
) -> Node {
  let camera = builder.camera.unwrap()
  if camera_is_array_with_cameras(camera) {
    let camera_array = camera_get_camera_array(
      builder.renderer,
      camera,
      array_name,
      fn(camera) {
        let values = camera_sub_cameras(camera).map(get)
        uniform_array(values)
        .set_group(render_group)
        .set_name(array_name)
        .on_render_update(fn(self_, frame) {
          let array = UniformArrayNode::of(self_).unwrap().array
          let cameras = camera_sub_cameras(camera_of_frame(frame))
          for i in 0..<cameras.length() {
            array[i] = get(cameras[i])
          }
          None
        })
      },
    )
    camera_array.element(camera_array_index(camera))
  } else {
    match base.val {
      Some(b) => b
      None => {
        let b = uniform(get(camera))
          .set_name(base_name)
          .set_group(render_group)
          .on_render_update(fn(self_, frame) {
            InputNode::set_value(self_, get(camera_of_frame(frame)))
            None
          })
        base.val = Some(b)
        b
      }
    }
  }
}

///|
/// `cameraProjectionMatrix`.
pub let camera_projection_matrix : Node = module_nodes(
  "nodes/accessors/Camera.js:cameraProjectionMatrix",
  fn() {
    fn_(fn(_, builder) {
      Some(
        camera_matrix_node(
          builder,
          "cameraProjectionMatrices",
          _camera_projection_matrix_base,
          "cameraProjectionMatrix",
          fn(c) { Matrix4(camera_data(c).projection_matrix) },
        ),
      )
    })
    .once()
    .call([])
  },
)

///|
/// `cameraProjectionMatrixInverse`.
pub let camera_projection_matrix_inverse : Node = module_nodes(
  "nodes/accessors/Camera.js:cameraProjectionMatrixInverse",
  fn() {
    fn_(fn(_, builder) {
      Some(
        camera_matrix_node(
          builder,
          "cameraProjectionMatricesInverse",
          _camera_projection_matrix_inverse_base,
          "cameraProjectionMatrixInverse",
          fn(c) { Matrix4(camera_data(c).projection_matrix_inverse) },
        ),
      )
    })
    .once()
    .call([])
  },
)

///|
/// `cameraViewMatrix`.
pub let camera_view_matrix : Node = module_nodes(
  "nodes/accessors/Camera.js:cameraViewMatrix",
  fn() {
    fn_(fn(_, builder) {
      Some(
        camera_matrix_node(
          builder,
          "cameraViewMatrices",
          _camera_view_matrix_base,
          "cameraViewMatrix",
          fn(c) { Matrix4(camera_data(c).matrix_world_inverse) },
        ),
      )
    })
    .once()
    .call([])
  },
)

///|
/// `cameraWorldMatrix`.
pub let camera_world_matrix : Node = module_nodes(
  "nodes/accessors/Camera.js:cameraWorldMatrix",
  fn() {
    fn_(fn(_, builder) {
      Some(
        camera_matrix_node(
          builder,
          "cameraWorldMatrices",
          _camera_world_matrix_base,
          "cameraWorldMatrix",
          fn(c) { Matrix4(c.matrix_world) },
        ),
      )
    })
    .once()
    .call([])
  },
)

///|
/// `cameraNormalMatrix`.
pub let camera_normal_matrix : Node = module_nodes(
  "nodes/accessors/Camera.js:cameraNormalMatrix",
  fn() {
    fn_(fn(_, builder) {
      Some(
        camera_matrix_node(
          builder,
          "cameraNormalMatrices",
          _camera_normal_matrix_base,
          "cameraNormalMatrix",
          fn(c) { Matrix3(c.normal_matrix) },
        ),
      )
    })
    .once()
    .call([])
  },
)

///|
/// `cameraPosition`.
pub let camera_position : Node = module_nodes(
  "nodes/accessors/Camera.js:cameraPosition",
  fn() {
    fn_(fn(_, builder) {
      let camera = builder.camera.unwrap()
      if camera_is_array_with_cameras(camera) {
        let camera_array = camera_get_camera_array(
          builder.renderer,
          camera,
          "cameraPositions",
          fn(camera) {
            let positions : Array[TslValue] = []
            for _ in camera_sub_cameras(camera) {
              positions.push(Vector3(@math.Vector3::new(0.0, 0.0, 0.0)))
            }
            uniform_array(positions)
            .set_group(render_group)
            .set_name("cameraPositions")
            .on_render_update(fn(self_, frame) {
              let sub_cameras = camera_sub_cameras(camera_of_frame(frame))
              let array = UniformArrayNode::of(self_).unwrap().array
              for i in 0..<sub_cameras.length() {
                match array[i] {
                  Vector3(v) =>
                    v.set_from_matrix_position(sub_cameras[i].matrix_world)
                    |> ignore
                  _ => ()
                }
              }
              None
            })
          },
        )
        return Some(camera_array.element(camera_array_index(camera)))
      }
      match _camera_position_base.val {
        Some(b) => Some(b)
        None => {
          let b = uniform(@math.Vector3::new(0.0, 0.0, 0.0))
            .set_name("cameraPosition")
            .set_group(render_group)
            .on_render_update(fn(self_, frame) {
              match InputNode::get_value(self_) {
                Vector3(v) =>
                  v.set_from_matrix_position(
                    camera_of_frame(frame).matrix_world,
                  )
                  |> ignore
                _ => ()
              }
              None
            })
          _camera_position_base.val = Some(b)
          Some(b)
        }
      }
    })
    .once()
    .call([])
  },
)

///|
/// `cameraViewport`.
pub let camera_viewport : Node = module_nodes(
  "nodes/accessors/Camera.js:cameraViewport",
  fn() {
    fn_(fn(_, builder) {
      let camera = builder.camera.unwrap()
      if camera_is_array_with_cameras(camera) {
        let camera_array = camera_get_camera_array(
          builder.renderer,
          camera,
          "cameraViewports",
          fn(camera) {
            let values = camera_sub_cameras(camera).map(camera_viewport_value)
            uniform_array(values, element_type="vec4")
            .set_group(render_group)
            .set_name("cameraViewports")
            .on_render_update(fn(self_, frame) {
              let array = UniformArrayNode::of(self_).unwrap().array
              let cameras = camera_sub_cameras(camera_of_frame(frame))
              for i in 0..<cameras.length() {
                array[i] = camera_viewport_value(cameras[i])
              }
              None
            })
          },
        )
        return Some(camera_array.element(camera_index))
      }
      match _camera_viewport_base.val {
        Some(b) => Some(b)
        None => {
          let b = vec4_of([0, 0, screen_size.x(), screen_size.y()]).to_const(
            name="cameraViewport",
          )
          _camera_viewport_base.val = Some(b)
          Some(b)
        }
      }
    })
    .once()
    .call([])
  },
)

///|
/// `subCamera.viewport` of an `ArrayCamera` sub-camera.
fn camera_viewport_value(camera : @core.Object3D) -> TslValue {
  match @webgl.camera_viewport(camera) {
    Some(v) => Vector4(v)
    None => Undefined
  }
}
