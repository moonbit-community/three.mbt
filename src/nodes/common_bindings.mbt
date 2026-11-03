// renderers/common/Bindings.js

///|
/// The record of a render object in `Bindings`.
pub(all) struct BindingsRenderObjectData {
  mut initialized : Bool
}

///|
/// The record of a compute node in `Bindings`.
pub(all) struct BindingsComputeData {
  mut initialized : Bool
  /// `undefined` until the bindings are created.
  mut bindings : Array[BindGroup]?
}

///|
/// The record of a bind group in `Bindings`.
pub(all) struct BindingsGroupData {
  /// `undefined` until the group's bindings are created.
  mut bind_group : BindGroup?
  mut used_times : Int32
  /// The render context (or renderer) a shared group is cached for.
  mut render_context : @core.JsValue?
  /// The cache key of a shared group.
  mut cache_key : Double?
}

///|
/// The record of a storage texture in `Bindings`.
pub(all) struct BindingsTextureData {
  mut needs_mipmap : Bool?
}

///|
/// Creates and updates the bind groups of render objects and compute nodes.
pub struct Bindings {
  priv render_objects : DataMap[RenderObject, BindingsRenderObjectData]
  priv compute_nodes : DataMap[Node, BindingsComputeData]
  priv groups : DataMap[BindGroup, BindingsGroupData]
  priv textures_data : DataMap[@core.Texture, BindingsTextureData]
  backend : Backend
  textures : Textures
  pipelines : Pipelines
  attributes : Attributes
  nodes : NodeManager
  info : Info
  priv _shared_bind_groups : @webgl.WeakMap[
    @core.JsValue,
    Map[Double, BindGroup],
  ]
}

///|
/// `new Bindings( backend, nodes, textures, attributes, pipelines, info )`.
pub fn Bindings::new(
  backend : Backend,
  nodes : NodeManager,
  textures : Textures,
  attributes : Attributes,
  pipelines : Pipelines,
  info : Info,
) -> Bindings {
  let bindings = {
    render_objects: DataMap::new(fn() { { initialized: false, } }),
    compute_nodes: DataMap::new(fn() { { initialized: false, bindings: None, } }),
    groups: DataMap::new(fn() {
      {
        bind_group: None,
        used_times: 0,
        render_context: None,
        cache_key: None,
      }
    }),
    textures_data: DataMap::new(fn() { { needs_mipmap: None, } }),
    backend,
    textures,
    pipelines,
    attributes,
    nodes,
    info,
    _shared_bind_groups: @webgl.WeakMap::new(),
  }
  pipelines.bindings = Some(bindings) // assign bindings to pipelines
  bindings
}

///|
/// `get( bindGroup )`: the bind group's record.
pub fn Bindings::get(
  self : Bindings,
  bind_group : BindGroup,
) -> BindingsGroupData {
  self.groups.get(bind_group)
}

///|
/// `has( bindGroup )`.
pub fn Bindings::has(self : Bindings, bind_group : BindGroup) -> Bool {
  self.groups.has(bind_group)
}

///|
/// `get( renderObject )`.
pub fn Bindings::get_render_object(
  self : Bindings,
  render_object : RenderObject,
) -> BindingsRenderObjectData {
  self.render_objects.get(render_object)
}

///|
/// `get( computeNode )`.
pub fn Bindings::get_compute(
  self : Bindings,
  compute_node : Node,
) -> BindingsComputeData {
  self.compute_nodes.get(compute_node)
}

///|
/// `get( texture )`.
pub fn Bindings::get_texture(
  self : Bindings,
  texture : @core.Texture,
) -> BindingsTextureData {
  self.textures_data.get(texture)
}

///|
/// `dispose()`.
pub fn Bindings::dispose(self : Bindings) -> Unit {
  self.render_objects.dispose()
  self.compute_nodes.dispose()
  self.groups.dispose()
  self.textures_data.dispose()
}

///|
/// `getForRender( renderObject )`: the render object's bind groups, created once.
pub fn Bindings::get_for_render(
  self : Bindings,
  render_object : RenderObject,
) -> Array[BindGroup] {
  let bindings = render_object.get_bindings()
  let render_object_data = self.render_objects.get(render_object)
  if render_object_data.initialized != true {
    self._create_bindings(bindings)
    render_object_data.initialized = true
  }
  bindings
}

///|
/// `getForCompute( computeNode )`: the compute node's bind groups, recreated when its
/// build changed.
pub fn Bindings::get_for_compute(
  self : Bindings,
  compute_node : Node,
) -> Array[BindGroup] {
  let bindings = self.nodes.get_for_compute(compute_node).bindings
  let compute_node_data = self.compute_nodes.get(compute_node)
  let same = match compute_node_data.bindings {
    Some(b) => physical_equal(b, bindings)
    None => false
  }
  if compute_node_data.initialized != true || !same {
    match compute_node_data.bindings {
      Some(previous) => self._destroy_bindings(previous)
      None => ()
    }
    self._create_bindings(bindings)
    compute_node_data.initialized = true
    compute_node_data.bindings = Some(bindings)
  }
  bindings
}

///|
/// `getSharedBindGroup( bindGroup, renderContext = null )`: one bind group per render
/// context for groups whose uniforms are shared.
pub fn Bindings::get_shared_bind_group(
  self : Bindings,
  bind_group : BindGroup,
  render_context? : RenderContext,
) -> BindGroup {
  let render_context_key = match render_context {
    Some(c) => @core.JsValue::of(c)
    None =>
      match self.backend.renderer {
        Some(renderer) =>
          match renderer._current_render_context {
            Some(c) => @core.JsValue::of(c)
            None => @core.JsValue::of(renderer) // use renderer as fallback until we have a compute context
          }
        None =>
          abort(
            "TypeError: Cannot read properties of null (reading '_currentRenderContext')",
          )
      }
  }
  let mut cache_key_string = ""
  for binding in bind_group.bindings {
    if binding.has_flag("isNodeUniformsGroup") {
      let uniforms = binding.uniforms()
      @webgl.stable_sort_by(uniforms, fn(a, b) {
        (_bindings_uniform_node_id(a) - _bindings_uniform_node_id(b)).to_double()
      })
      for uniform in uniforms {
        cache_key_string += _bindings_uniform_node_id(uniform).to_string() + ","
      }
    } else {
      match binding.node_uniform() {
        Some(node) => cache_key_string += node.id.to_string() + ","
        None =>
          abort("TypeError: Cannot read properties of undefined (reading 'id')")
      }
    }
  }
  let cache_key = hash_string(cache_key_string)
  let bind_groups_cache = match
    self._shared_bind_groups.get(render_context_key) {
    Some(cache) => cache
    None => {
      let cache = Map([])
      self._shared_bind_groups.set(render_context_key, cache)
      cache
    }
  }
  match bind_groups_cache.get(cache_key) {
    Some(shared_bind_group) => shared_bind_group
    None => {
      let shared_bind_group = if self.has(bind_group) {
        bind_group.clone()
      } else {
        bind_group
      }
      bind_groups_cache.set(cache_key, shared_bind_group)
      let group_data = self.get(shared_bind_group)
      group_data.render_context = Some(render_context_key)
      group_data.cache_key = Some(cache_key)
      shared_bind_group
    }
  }
}

///|
/// `uniform.nodeUniform.node.id` of a node uniform.
fn _bindings_uniform_node_id(uniform : Uniform) -> Int32 {
  match _bindings_node_uniform_of(uniform) {
    Some(node_uniform) => node_uniform.node.id
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'node')")
  }
}

///|
/// `uniform.nodeUniform` of the node uniform classes.
fn _bindings_node_uniform_of(uniform : Uniform) -> NodeUniform? {
  if NumberNodeUniform::of(uniform) is Some(u) {
    return Some(u.node_uniform)
  }
  if Vector2NodeUniform::of(uniform) is Some(u) {
    return Some(u.node_uniform)
  }
  if Vector3NodeUniform::of(uniform) is Some(u) {
    return Some(u.node_uniform)
  }
  if Vector4NodeUniform::of(uniform) is Some(u) {
    return Some(u.node_uniform)
  }
  if ColorNodeUniform::of(uniform) is Some(u) {
    return Some(u.node_uniform)
  }
  if Matrix2NodeUniform::of(uniform) is Some(u) {
    return Some(u.node_uniform)
  }
  if Matrix3NodeUniform::of(uniform) is Some(u) {
    return Some(u.node_uniform)
  }
  if Matrix4NodeUniform::of(uniform) is Some(u) {
    return Some(u.node_uniform)
  }
  None
}

///|
/// `updateForCompute( computeNode )`.
pub fn Bindings::update_for_compute(
  self : Bindings,
  compute_node : Node,
) -> Unit {
  self._update_bindings(self.get_for_compute(compute_node))
}

///|
/// `updateForRender( renderObject )`.
pub fn Bindings::update_for_render(
  self : Bindings,
  render_object : RenderObject,
) -> Unit {
  self._update_bindings(self.get_for_render(render_object))
}

///|
/// `updateSharedForRender( renderObject )`: updates the shared uniform groups only.
pub fn Bindings::update_shared_for_render(
  self : Bindings,
  render_object : RenderObject,
) -> Unit {
  let bindings = self.get_for_render(render_object)
  for bind_group in bindings {
    for binding in bind_group.bindings {
      if (
          binding.has_flag("isNodeUniformsGroup") ||
          binding.has_flag("isNodeUniformBuffer")
        ) &&
        _bindings_group_shared(binding) {
        let updated_group = self.nodes.update_group(binding)
        if !updated_group {
          continue
        }
        let updated = binding.update()
        if updated {
          self.backend.update_binding(binding)
        }
        if binding.update_ranges().length() > 0 {
          binding.clear_update_ranges()
        }
      }
    }
  }
}

///|
/// `binding.groupNode.shared === true`.
fn _bindings_group_shared(binding : Binding) -> Bool {
  match binding.group_node() {
    Some(group_node) =>
      match UniformGroupNode::of(group_node) {
        Some(u) => u.shared
        None => false
      }
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'shared')")
  }
}

///|
/// `deleteForCompute( computeNode )`.
pub fn Bindings::delete_for_compute(
  self : Bindings,
  compute_node : Node,
) -> Unit {
  let compute_node_data = self.compute_nodes.get(compute_node)
  let bindings = match compute_node_data.bindings {
    Some(b) => b
    None => self.nodes.get_for_compute(compute_node).bindings
  }
  self._destroy_bindings(bindings)
  self.compute_nodes.delete(compute_node) |> ignore
}

///|
/// `deleteForRender( renderObject )`.
pub fn Bindings::delete_for_render(
  self : Bindings,
  render_object : RenderObject,
) -> Unit {
  let bindings = render_object.get_bindings()
  self._destroy_bindings(bindings)
  self.render_objects.delete(render_object) |> ignore
}

///|
/// The attribute type of a storage buffer's attribute.
fn _bindings_storage_type(attribute : @core.BufferAttribute) -> AttributeType {
  if is_indirect_storage_buffer_attribute(attribute) {
    INDIRECT
  } else {
    STORAGE
  }
}

///|
/// `binding.attribute` of a storage buffer.
fn _bindings_attribute(binding : Binding) -> @core.BufferAttribute {
  match binding.attribute() {
    Some(a) => a
    None =>
      abort(
        "TypeError: Cannot read properties of undefined (reading 'isIndirectStorageBufferAttribute')",
      )
  }
}

///|
/// `_createBindings( bindings )`.
pub fn Bindings::_create_bindings(
  self : Bindings,
  bindings : Array[BindGroup],
) -> Unit {
  for bind_group in bindings {
    let group_data = self.get(bind_group)
    if group_data.bind_group is None {
      for binding in bind_group.bindings {
        if binding.has_flag("isUniformBuffer") {
          self.backend.create_uniform_buffer(binding)
          self.info.create_uniform_buffer(binding)
        } else if binding.has_flag("isSampledTexture") {
          binding.set_generation(
            self.textures.update_texture(_bindings_texture(binding)),
          )
        } else if binding.has_flag("isSampler") {
          binding.set_sampler_key(self.textures.update_sampler(binding))
        } else if binding.has_flag("isStorageBuffer") {
          let attribute = _bindings_attribute(binding)
          let attribute_type = _bindings_storage_type(attribute)
          self.attributes.update(Buffer(attribute), attribute_type)
        }
      }
      self.backend.create_bindings(bind_group, bindings, "")
      group_data.bind_group = Some(bind_group)
      group_data.used_times = 1
    } else {
      group_data.used_times += 1
    }
  }
}

///|
/// `binding.texture` of a sampled texture.
fn _bindings_texture(binding : Binding) -> @core.Texture {
  match binding.texture() {
    Some(t) => t
    None =>
      abort("TypeError: Cannot read properties of null (reading 'version')")
  }
}

///|
/// `_destroyBindings( bindings )`.
pub fn Bindings::_destroy_bindings(
  self : Bindings,
  bindings : Array[BindGroup],
) -> Unit {
  for bind_group in bindings {
    let group_data = self.get(bind_group)
    group_data.used_times -= 1
    if group_data.used_times == 0 {
      for binding in bind_group.bindings {
        if binding.has_flag("isUniformBuffer") {
          self.backend.destroy_uniform_buffer(binding)
          self.info.destroy_uniform_buffer(binding)
          binding.release()
        } else if binding.has_flag("isSampler") {
          if !binding.has_flag("isSampledTexture") {
            self.backend.destroy_sampler(binding)
          } else {
            match binding.texture() {
              Some(texture) => {
                let texture_data = self.textures.get(texture)
                match texture_data.bind_groups {
                  Some(bind_groups) => bind_groups.delete(bind_group)
                  None => ()
                }
              }
              None => ()
            }
          }
          binding.release()
        }
      }
      match group_data.cache_key {
        Some(cache_key) => {
          let key = match group_data.render_context {
            Some(k) => k
            None => @core.JsValue::undefined()
          }
          match self._shared_bind_groups.get(key) {
            Some(bind_groups_cache) => bind_groups_cache.remove(cache_key)
            None =>
              abort(
                "TypeError: Cannot read properties of undefined (reading 'delete')",
              )
          }
        }
        None => ()
      }
      self.backend.delete_bind_group_data(bind_group)
      self.groups.delete(bind_group) |> ignore
    }
  }
}

///|
/// `_updateBindings( bindings )`.
pub fn Bindings::_update_bindings(
  self : Bindings,
  bindings : Array[BindGroup],
) -> Unit {
  for bind_group in bindings {
    self._update(bind_group, bindings)
  }
}

///|
/// `_update( bindGroup, bindings )`: uploads changed uniforms and recreates the GPU
/// bind group when a resource changed.
pub fn Bindings::_update(
  self : Bindings,
  bind_group : BindGroup,
  bindings : Array[BindGroup],
) -> Unit {
  let backend = self.backend
  let mut needs_bindings_update = false
  let mut cache_bindings = true
  let cache_key_ids : Array[Int32] = []
  let mut version = 0
  for binding in bind_group.bindings {
    let updated_group = self.nodes.update_group(binding)
    if !updated_group {
      continue
    }
    if binding.has_flag("isStorageBuffer") {
      let attribute = _bindings_attribute(binding)
      let attribute_type = _bindings_storage_type(attribute)
      let binding_data = backend.get(@core.JsValue::of(binding))
      self.attributes.update(Buffer(attribute), attribute_type)
      let generation = match self.attributes.get(Buffer(attribute)).generation {
        Some(g) => g
        None => abort("Bindings: storage attribute without a generation")
      }
      let previous_attribute = binding_data.get("attribute")
      let previous_generation = binding_data.get("generation")
      if !previous_attribute.strict_equal(@core.JsValue::of(attribute)) ||
        !previous_generation.strict_equal(@core.JsValue::of(generation)) {
        binding_data.set("attribute", @core.JsValue::of(attribute))
        binding_data.set("generation", @core.JsValue::of(generation))
        needs_bindings_update = true
      }
      cache_key_ids.push(attribute.id)
      version += generation
    }
    if binding.has_flag("isUniformBuffer") {
      let updated = binding.update()
      if updated {
        backend.update_binding(binding)
      }
    } else if binding.has_flag("isSampledTexture") {
      let updated = binding.update()
      let texture = _bindings_texture(binding)
      let textures_texture_data = self.textures.get(texture)
      if updated {
        let generation = self.textures.update_texture(texture)
        if binding.generation() != generation {
          binding.set_generation(generation)
          needs_bindings_update = true
        }
        match textures_texture_data.bind_groups {
          Some(bind_groups) => bind_groups.add(bind_group)
          None =>
            abort(
              "TypeError: Cannot read properties of undefined (reading 'add')",
            )
        }
      }
      let texture_data = backend.get(@core.JsValue::of(texture))
      if !texture_data.get("externalTexture").is_undefined() ||
        textures_texture_data.is_default_texture == Some(true) {
        cache_bindings = false
      } else {
        cache_key_ids.push(texture.id)
        version += texture.version
      }
      if is_storage_texture(texture) && texture.mipmaps_auto_update {
        let texture_data = self.textures_data.get(texture)
        if binding.store() {
          texture_data.needs_mipmap = Some(true)
        } else if self.textures.needs_mipmaps(texture) &&
          texture_data.needs_mipmap == Some(true) {
          self.backend.generate_mipmaps(texture)
          texture_data.needs_mipmap = Some(false)
        }
      }
    } else if binding.has_flag("isSampler") {
      let updated = binding.update()
      if updated {
        let sampler_key = self.textures.update_sampler(binding)
        if binding.sampler_key() != sampler_key {
          binding.set_sampler_key(sampler_key)
          needs_bindings_update = true
        }
      }
    }
    if binding.has_flag("isBuffer") && binding.update_ranges().length() > 0 {
      binding.clear_update_ranges()
    }
  }
  if needs_bindings_update {
    let cache_key = if cache_bindings {
      cache_key_ids.map(fn(id) { id.to_string() }).join(",")
    } else {
      ""
    }
    self.backend.update_bindings(bind_group, bindings, cache_key, version)
  }
}
