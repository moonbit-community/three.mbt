// nodes/accessors/Instance.js: instancing (`instance( matrices, colors )` and
// `instancedMesh( mesh )`), with previous matrices for velocity.

///|
/// `{ previousInstanceMatrix, node }` of an instanced mesh.
priv struct InstancePrevious {
  previous_instance_matrix : @core.BufferAttribute
  node : Node
}

///|
let _instance_previous_instance_matrices : @webgl.WeakMap[
  @core.Object3D,
  InstancePrevious,
] = @webgl.WeakMap::new()

///|
let _instance_previous_matrices : @webgl.WeakMap[
  @core.Object3D,
  @core.BufferAttribute,
] = @webgl.WeakMap::new()

///|
let _instance_max_vertex_buffers : Int32 = 8

///|
/// `new InterleavedBufferAttribute( attribute, itemSize, offset )` over a buffer
/// attribute (upstream passes the attribute as the interleaved buffer).
fn instance_column(
  attribute : @core.BufferAttribute,
  item_size : Int32,
  offset : Int32,
) -> @core.InterleavedBufferAttribute {
  // the columns share one buffer, as upstream's share the attribute
  let buffer = attribute_interleaved_buffer(attribute)
  @core.InterleavedBufferAttribute::new(buffer, item_size, offset)
}

///|
/// `createInstanceMatrixNode( builder, instanceMatrix )`.
fn instance_create_instance_matrix_node(
  builder : NodeBuilder,
  instance_matrix : @core.BufferAttribute,
) -> Node {
  let matrix_count = if instance_matrix.count > 1 {
    instance_matrix.count
  } else {
    1
  }
  let is_storage_matrix = instance_matrix.kind is StorageInstancedAttribute
  if is_storage_matrix {
    storage(instance_matrix, type_="mat4", count=matrix_count).element(
      instance_index,
    )
  } else {
    let uniform_buffer_size = matrix_count * 16 * 4
    if uniform_buffer_size <= builder.get_uniform_buffer_limit() {
      buffer(instance_matrix.array, "mat4", matrix_count).element(
        instance_index,
      )
    } else {
      let dynamic = instance_matrix.usage == @core.DynamicDrawUsage
      let instance_buffers = [0, 4, 8, 12].map(fn(offset) {
        let column = instance_column(instance_matrix, 4, offset)
        if dynamic {
          instanced_dynamic_buffer_attribute(column)
        } else {
          instanced_buffer_attribute(column)
        }
      })
      mat4_of(instance_buffers.map(fn(n) -> &IntoTsl { n }))
    }
  }
}

///|
/// `getPreviousInstance( instancedMesh, instanceMatrix, builder )`.
fn instance_get_previous_instance(
  instanced_mesh : @core.Object3D,
  instance_matrix : @core.BufferAttribute,
  builder : NodeBuilder,
) -> Node {
  match _instance_previous_instance_matrices.get(instanced_mesh) {
    Some(data) => data.node
    None => {
      let previous_instance_matrix = instance_matrix.clone()
      let data = InstancePrevious::{
        previous_instance_matrix,
        node: instance_create_instance_matrix_node(
          builder, previous_instance_matrix,
        ),
      }
      _instance_previous_instance_matrices.set(instanced_mesh, data)
      instanced_mesh.add_event_listener(
        "dispose", _instance_on_previous_dispose,
      )
      data.node
    }
  }
}

///|
/// `onPreviousInstanceDispose( { target: object } )`.
let _instance_on_previous_dispose : (@core.Event) -> Unit = fn(event) {
  match event.target {
    Some(Object3D(object)) =>
      match _instance_previous_instance_matrices.get(object) {
        Some(data) => data.previous_instance_matrix.dispose()
        None => ()
      }
    _ => ()
  }
}

///|
/// `instancedMesh.instanceMatrix`.
fn instance_matrix_of(object : @core.Object3D) -> @core.BufferAttribute {
  match object.kind {
    Mesh({ kind: InstancedMesh(m), .. }) => m.instance_matrix
    _ =>
      abort("TypeError: Cannot read properties of undefined (instanceMatrix)")
  }
}

///|
/// `instancedMesh.instanceColor`.
fn instance_color_of(object : @core.Object3D) -> @core.BufferAttribute? {
  match object.kind {
    Mesh({ kind: InstancedMesh(m), .. }) => m.instance_color
    _ => None
  }
}

///|
/// `getPreviousMatrix( object )`.
fn instance_get_previous_matrix(
  object : @core.Object3D,
) -> @core.BufferAttribute {
  let matrices = instance_matrix_of(object)
  match _instance_previous_matrices.get(object) {
    Some(previous) if previous.count == matrices.count => previous
    previous => {
      match previous {
        None =>
          object.add_event_listener("dispose", _instance_on_matrix_dispose)
        Some(p) => p.dispose()
      }
      let previous = matrices.clone()
      _instance_previous_matrices.set(object, previous)
      previous
    }
  }
}

///|
/// `onPreviousMatrixDispose( { target: object } )`.
let _instance_on_matrix_dispose_ref : Ref[(@core.Event) -> Unit] = Ref(fn(_) {

})

///|
let _instance_on_matrix_dispose : (@core.Event) -> Unit = {
  _instance_on_matrix_dispose_ref.val = instance_on_matrix_dispose
  _instance_on_matrix_dispose_ref.val
}

///|
fn instance_on_matrix_dispose(event : @core.Event) -> Unit {
  match event.target {
    Some(Object3D(object)) => {
      object.remove_event_listener(
        "dispose",
        _instance_on_matrix_dispose_ref.val,
      )
      match _instance_previous_matrices.get(object) {
        Some(p) => p.dispose()
        None => ()
      }
      _instance_previous_matrices.delete(object)
    }
    _ => ()
  }
}

///|
/// `PreviousInstanceMatrixNode`: the instance matrices of the previous frame.
pub(all) struct PreviousInstanceMatrixNode {
  reference_attribute : ReferenceAttributeNode
}

///|
pub impl NodeClass for PreviousInstanceMatrixNode with fn class_name(_) {
  "PreviousInstanceMatrixNode"
}

///|
pub impl NodeClass for PreviousInstanceMatrixNode with fn parent(self) {
  Some(self.reference_attribute)
}

///|
pub impl ReferenceAttributeNodeClass for PreviousInstanceMatrixNode with fn reference_attribute_parent(
  self,
) {
  Some(self.reference_attribute)
}

///|
pub impl ReferenceAttributeNodeClass for PreviousInstanceMatrixNode with fn get_value_from_reference(
  _,
  _,
  object,
) {
  Some(instance_get_previous_matrix(object.unwrap()))
}

///|
/// `new PreviousInstanceMatrixNode()`.
pub fn PreviousInstanceMatrixNode::new() -> Node {
  let node = Node::alloc(node_type="mat4")
  let reference_attribute = ReferenceAttributeNode::construct(
    node,
    "previousInstanceMatrix",
    None,
  )
  let p = PreviousInstanceMatrixNode::{ reference_attribute, }
  reference_attribute.class_ = p
  node.set_class(p)
}

///|
/// `canReferenceInstanceData( object, builder )`.
fn instance_can_reference_instance_data(
  object : @core.Object3D,
  builder : NodeBuilder,
) -> Bool {
  // only render objects bind attributes per object
  if builder.renderer.is_renderer != true {
    return false
  }
  // the instance data take up to three vertex buffers next to the ones of the geometry
  let instance_buffers = 1 +
    (if instance_color_of(object) is Some(_) { 1 } else { 0 }) +
    (if builder.needs_previous_data() { 1 } else { 0 })
  object.get_geometry().unwrap().attributes.length() + instance_buffers <=
  _instance_max_vertex_buffers
}

///|
/// `transformInstance( builder, instanceMatrixNode, previousMatrixNode )`.
fn instance_transform_instance(
  builder : NodeBuilder,
  instance_matrix_node : Node,
  previous_matrix_node : Node?,
) -> Unit {
  let instance_position = instance_matrix_node.mul(position_local).xyz()
  position_local.assign(instance_position)
  match previous_matrix_node {
    Some(p) => position_previous.assign(p.mul(position_previous).xyz())
    None => ()
  }
  if builder.has_geometry_attribute("normal") {
    let instance_normal = transform_normal.call([
      normal_local, instance_matrix_node,
    ])
    normal_local.assign(instance_normal)
  }
}

///|
/// `instanceColor`.
pub let instance_color : Node = module_nodes(
  "nodes/accessors/Instance.js:instanceColor",
  fn() { varying_property("vec3", name="vInstanceColor") },
)

///|
/// A buffer attribute passed to a TSL function.
fn instance_attribute_arg(value : TslValue) -> @core.BufferAttribute? {
  match value {
    Js(v) if !v.is_null() && !v.is_undefined() => Some(v.cast())
    _ => None
  }
}

///|
/// `instance( matrices, colors = null )`: `instance.call( [ matrices, colors ] )`.
pub let instance : Node = module_nodes("nodes/accessors/Instance.js:instance", fn() {
  fn_(
    fn(inputs, builder) {
      let matrices = instance_attribute_arg(inputs.value(0)).unwrap()
      let colors = instance_attribute_arg(inputs.value(1))
      let is_storage_color = match colors {
        Some(c) => c.kind is StorageInstancedAttribute
        None => false
      }
      let instance_matrix_node = instance_create_instance_matrix_node(
        builder, matrices,
      )
      let mut instance_color_node : Node? = None
      match colors {
        Some(colors) =>
          if is_storage_color {
            let count = if colors.count > 1 { colors.count } else { 1 }
            instance_color_node = Some(
              storage(colors, type_="vec3", count~).element(instance_index),
            )
          } else {
            let n = if colors.usage == @core.DynamicDrawUsage {
              instanced_dynamic_buffer_attribute(colors)
            } else {
              instanced_buffer_attribute(colors)
            }
            instance_color_node = Some(vec3(n))
          }
        None => ()
      }
      let mut previous_instance_matrix_node : Node? = None
      if builder.needs_previous_data() {
        let instanced_mesh = builder_object(builder).unwrap()
        on_after_object_update(fn(frame) {
          match
            _instance_previous_instance_matrices.get(frame.object.unwrap()) {
            Some(data) => {
              data.previous_instance_matrix.array.set_from(matrices.array)
              data.previous_instance_matrix.version = matrices.version
            }
            None => ()
          }
        })
        |> ignore
        previous_instance_matrix_node = Some(
          instance_get_previous_instance(instanced_mesh, matrices, builder),
        )
      }
      instance_transform_instance(
        builder, instance_matrix_node, previous_instance_matrix_node,
      )
      match instance_color_node {
        Some(n) => instance_color.assign(n)
        None => ()
      }
      None
    },
    layout=ReturnType("void"),
  )
})

///|
/// `instancedMesh( instancedMesh )`: `instanced_mesh.call( [ mesh ] )`.
pub let instanced_mesh : Node = module_nodes(
  "nodes/accessors/Instance.js:instancedMesh",
  fn() {
    fn_(
      fn(inputs, builder) {
        let instanced_mesh : @core.Object3D = match inputs.value(0) {
          Js(v) => v.cast()
          _ => abort("instancedMesh: expects an InstancedMesh")
        }
        if instance_can_reference_instance_data(instanced_mesh, builder) {
          let mut previous_instance_matrix_node : Node? = None
          if builder.needs_previous_data() {
            on_after_object_update(fn(frame) {
              let object = frame.object.unwrap()
              let previous = instance_get_previous_matrix(object)
              let instance_matrix = instance_matrix_of(object)
              previous.array.set_from(instance_matrix.array)
              previous.version = instance_matrix.version
            })
            |> ignore
            previous_instance_matrix_node = Some(
              PreviousInstanceMatrixNode::new(),
            )
          }
          instance_transform_instance(
            builder,
            reference_attribute("instanceMatrix", type_="mat4"),
            previous_instance_matrix_node,
          )
          if instance_color_of(instanced_mesh) is Some(_) {
            instance_color.assign(
              reference_attribute("instanceColor", type_="vec3"),
            )
          }
        } else {
          builder.object_specific = true
          instance.call([
            instance_matrix_of(instanced_mesh),
            instance_color_of(instanced_mesh),
          ])
          |> ignore
        }
        None
      },
      layout=ReturnType("void"),
    )
  },
)
