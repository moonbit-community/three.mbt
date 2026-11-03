// nodes/lighting/EnvironmentNode.js: image-based lighting from an environment (a PMREM
// of a texture or material reference, or any node): radiance, irradiance and clearcoat
// radiance. `material.useAnisotropy` / `useRetroreflection` (MeshPhysicalNodeMaterial
// getters) are read as the material's extension flags of those names.

///|
let environment_node_renderer_cache : @webgl.WeakMap[
  Renderer,
  @webgl.WeakMap[Node, Node],
] = @webgl.WeakMap::new()

///|
pub(all) struct EnvironmentNode {
  lighting : LightingNode
  mut env_node : Node?
  mut _pmrem_node : Node?
}

///|
pub impl NodeClass for EnvironmentNode with fn class_name(_) {
  "EnvironmentNode"
}

///|
pub impl NodeClass for EnvironmentNode with fn parent(self) {
  Some(self.lighting)
}

///|
pub impl NodeClass for EnvironmentNode with fn children(self, node, out) {
  NodeClass::children(self.lighting, node, out)
  push_child(out, "envNode", self.env_node)
}

///|
pub impl NodeClass for EnvironmentNode with fn setup(self, node, builder) {
  let material = builder.material.unwrap()
  let mut env_node = self.env_node.unwrap()
  if env_node.has_flag("isTextureNode") ||
    env_node.has_flag("isMaterialReferenceNode") {
    let cache = EnvironmentNode::_get_pmrem_node_cache(builder.renderer)
    let pmrem_node = match cache.get(env_node) {
      Some(p) => p
      None => {
        let p = pmrem_texture(self._get_env_texture(Builder(builder)).unwrap())
        cache.set(env_node, p)
        p
      }
    }
    self._pmrem_node = Some(pmrem_node)
    node.update_before_type = if env_node.has_flag("isMaterialReferenceNode") {
      NodeUpdateType::object()
    } else {
      NodeUpdateType::render()
    }
    env_node = pmrem_node
  }
  let use_anisotropy = material.has_extension_flag("useAnisotropy") ||
    material.anisotropy().unwrap_or(0.0) > 0.0
  let radiance_normal_view = if use_anisotropy {
    bent_normal_view
  } else {
    normal_view
  }
  let mut radiance = isolate(
    env_node
    .context(
      value=environment_node_create_radiance_context(
        roughness, radiance_normal_view,
      ),
    )
    .mul(material_env_intensity),
  )
  if material.has_extension_flag("useRetroreflection") ||
    material.retroreflectivity().unwrap_or(0.0) > 0.0 {
    let retro_radiance = isolate(
      env_node
      .context(
        value=environment_node_create_retro_radiance_context(
          roughness, radiance_normal_view,
        ),
      )
      .mul(material_env_intensity),
    )
    radiance = retroreflectivity.clamp().mix(radiance, retro_radiance)
  }
  let irradiance = env_node
    .context(value=environment_node_create_irradiance_context(normal_world))
    .mul(bsdf_pi)
    .mul(material_env_intensity)
  let isolate_irradiance = isolate(irradiance)
  builder.context.get_node("radiance").unwrap().add_assign(radiance)
  builder.context
  .get_node("iblIrradiance")
  .unwrap()
  .add_assign(isolate_irradiance)
  let clearcoat_radiance = match NodeContext::lighting_model(builder.context) {
    Some(model) =>
      match PhysicalLightingModel::of(model) {
        Some(physical) => physical.clearcoat_radiance
        None => None
      }
    None => None
  }
  if clearcoat_radiance is Some(clearcoat_radiance) {
    let clearcoat_radiance_context = env_node
      .context(
        value=environment_node_create_radiance_context(
          clearcoat_roughness, clearcoat_normal_view,
        ),
      )
      .mul(material_env_intensity)
    let isolate_clearcoat_radiance = isolate(clearcoat_radiance_context)
    clearcoat_radiance.add_assign(isolate_clearcoat_radiance)
  }
  None
}

///|
pub impl NodeClass for EnvironmentNode with fn update_before(self, _, frame) {
  let texture = self._get_env_texture(Frame(frame))
  let pmrem_node = self._pmrem_node.unwrap()
  // the texture can be removed without a rebuild of the material
  if texture is Some(texture) &&
    !physical_equal(PMREMNode::value(pmrem_node), texture) {
    PMREMNode::set_value(pmrem_node, texture)
    pmrem_node.update_before(frame) |> ignore
  }
  None
}

///|
/// `_getEnvTexture( state )`: the current texture of the environment node.
fn EnvironmentNode::_get_env_texture(
  self : EnvironmentNode,
  state : NodeUpdateState,
) -> @core.Texture? {
  let env_node = self.env_node.unwrap()
  if env_node.has_flag("isMaterialReferenceNode") {
    env_node.update_reference(state) |> ignore
    match ReferenceNode::get_value_from_reference(env_node) {
      Texture(t) => Some(t)
      _ => None
    }
  } else {
    TextureNode::get_value_opt(env_node)
  }
}

///|
/// `_getPMREMNodeCache( renderer )`.
fn EnvironmentNode::_get_pmrem_node_cache(
  renderer : Renderer,
) -> @webgl.WeakMap[Node, Node] {
  match environment_node_renderer_cache.get(renderer) {
    Some(c) => c
    None => {
      let c = @webgl.WeakMap::new()
      environment_node_renderer_cache.set(renderer, c)
      c
    }
  }
}

///|
/// `new EnvironmentNode( envNode = null )`.
pub fn EnvironmentNode::new(env_node? : Node) -> Node {
  let node = Node::alloc(node_type="vec3")
  node.set_class(EnvironmentNode::{
    lighting: LightingNode::construct(node),
    env_node,
    _pmrem_node: None,
  })
}

///|
pub fn EnvironmentNode::of(node : Node) -> EnvironmentNode? {
  match node.class_payload("EnvironmentNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// The `getUV` / `getTextureLevel` context of a sampling direction and level.
fn environment_node_uv_level_context(
  get_uv : (Node, NodeBuilder) -> Node,
  get_texture_level : (Node) -> Node,
) -> NodeContext {
  node_context([
    ("getUV", Other(@core.JsValue::of(ContextGetUV::{ f: get_uv, }))),
    (
      "getTextureLevel",
      Other(
        @core.JsValue::of(ContextGetTextureLevel::{ f: get_texture_level, }),
      ),
    ),
  ])
}

///|
/// `createRadianceContext( roughnessNode, normalViewNode )`: samples along the
/// reflection, bent toward the normal for rough surfaces.
fn environment_node_create_radiance_context(
  roughness_node : Node,
  normal_view_node : Node,
) -> NodeContext {
  let reflect_vec : Ref[Node?] = Ref(None)
  environment_node_uv_level_context(
    fn(_, _) {
      match reflect_vec.val {
        Some(v) => v
        None => {
          let mut v = position_view_direction.negate().reflect(normal_view_node)
          v = pow4(roughness_node).mix(v, normal_view_node).normalize()
          v = v.transform_direction(camera_world_matrix)
          reflect_vec.val = Some(v)
          v
        }
      }
    },
    fn(_) { roughness_node },
  )
}

///|
/// `createRetroRadianceContext( roughnessNode, normalViewNode )`: samples along the
/// view direction (the retroreflective lobe).
fn environment_node_create_retro_radiance_context(
  roughness_node : Node,
  normal_view_node : Node,
) -> NodeContext {
  let retro_vec : Ref[Node?] = Ref(None)
  environment_node_uv_level_context(
    fn(_, _) {
      match retro_vec.val {
        Some(v) => v
        None => {
          let mut v = pow4(roughness_node)
            .mix(position_view_direction, normal_view_node)
            .normalize()
          v = v.transform_direction(camera_world_matrix)
          retro_vec.val = Some(v)
          v
        }
      }
    },
    fn(_) { roughness_node },
  )
}

///|
/// `createIrradianceContext( normalWorldNode )`.
fn environment_node_create_irradiance_context(
  normal_world_node : Node,
) -> NodeContext {
  environment_node_uv_level_context(fn(_, _) { normal_world_node }, fn(_) {
    float(1.0)
  })
}
