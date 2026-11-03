// renderers/common/nodes/NodeBuilderState.js

///|
/// A transform feedback varying of the WebGL fallback: `{ varyingName, attributeNode }`.
pub(all) struct NodeTransform {
  varying_name : String
  attribute_node : Node
}

///|
/// The result of a node build: the shaders and what rendering needs from the builder.
pub(all) struct NodeBuilderState {
  vertex_shader : String?
  fragment_shader : String?
  compute_shader : String?
  transforms : Array[NodeTransform]
  node_attributes : Array[NodeAttribute]
  bindings : Array[BindGroup]
  update_nodes : Array[Node]
  update_before_nodes : Array[Node]
  update_after_nodes : Array[Node]
  observer : NodeMaterialObserver?
  hardware_clipping : Bool
  mut used_times : Int32
}

///|
/// `new NodeBuilderState( vertexShader, fragmentShader, computeShader, nodeAttributes,
/// bindings, updateNodes, updateBeforeNodes, updateAfterNodes, observer,
/// hardwareClipping, transforms = [] )`.
pub fn NodeBuilderState::new(
  vertex_shader : String?,
  fragment_shader : String?,
  compute_shader : String?,
  node_attributes : Array[NodeAttribute],
  bindings : Array[BindGroup],
  update_nodes : Array[Node],
  update_before_nodes : Array[Node],
  update_after_nodes : Array[Node],
  observer : NodeMaterialObserver?,
  hardware_clipping : Bool,
  transforms~ : Array[NodeTransform] = [],
) -> NodeBuilderState {
  {
    vertex_shader,
    fragment_shader,
    compute_shader,
    transforms,
    node_attributes,
    bindings,
    update_nodes,
    update_before_nodes,
    update_after_nodes,
    observer,
    hardware_clipping,
    used_times: 0,
  }
}

///|
/// `createBindings( bindings, renderContext )`: per-object copies of the instance bind
/// groups, and the shared groups from `bindings`.
pub fn NodeBuilderState::create_bindings(
  self : NodeBuilderState,
  bindings : Bindings?,
  render_context : RenderContext?,
) -> Array[BindGroup] {
  let bind_groups = []
  for instance_group in self.bindings {
    // All bindings in the group must have the same groupNode.
    let shared = match instance_group.bindings[0].group_node() {
      Some(group_node) =>
        match UniformGroupNode::of(group_node) {
          Some(u) => u.shared
          None => false
        }
      None =>
        abort(
          "TypeError: Cannot read properties of undefined (reading 'shared')",
        )
    }
    if !shared {
      let bindings_group = BindGroup::new(name=instance_group.name, bindings=[])
      bind_groups.push(bindings_group)
      for instance_binding in instance_group.bindings {
        bindings_group.bindings.push(instance_binding.clone())
      }
    } else {
      match bindings {
        Some(b) =>
          bind_groups.push(
            b.get_shared_bind_group(instance_group, render_context?),
          )
        None =>
          abort(
            "TypeError: Cannot read properties of undefined (reading 'getSharedBindGroup')",
          )
      }
    }
  }
  bind_groups
}
