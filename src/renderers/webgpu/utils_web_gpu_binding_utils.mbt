// renderers/webgpu/utils/WebGPUBindingUtils.js: bind group layouts (cached by the hash of
// their entries), bind groups and uniform buffer uploads.

///|
let _web_gpu_binding_utils_bind_group_descriptor : @gpu.GPUBindGroupDescriptor = @gpu.GPUBindGroupDescriptor::default()

///|
let _web_gpu_binding_utils_buffer_descriptor : @gpu.GPUBufferDescriptor = @gpu.GPUBufferDescriptor::default()

///|
let _web_gpu_binding_utils_view_descriptor : @gpu.GPUTextureViewDescriptor = @gpu.GPUTextureViewDescriptor::default()

///|
/// `BindGroupLayout`: a cached layout and the number of bind groups using it.
pub(all) struct WebGPUBindGroupLayout {
  layout_gpu : @gpu.GPUBindGroupLayout
  mut used_times : Int32
}

///|
/// `WebGPUBindingUtils`.
pub(all) struct WebGPUBindingUtils {
  /// `backend`, linked right after the backend is built.
  mut backend_ : WebGPUBackend?
  /// `_bindGroupLayoutCache`, keyed by the layout hash.
  _bind_group_layout_cache : Map[String, WebGPUBindGroupLayout]
}

///|
/// `new WebGPUBindingUtils( backend )` (the backend is linked by `WebGPUBackend::new`).
fn WebGPUBindingUtils::new() -> WebGPUBindingUtils {
  { backend_: None, _bind_group_layout_cache: Map([]), }
}

///|
fn WebGPUBindingUtils::backend(self : WebGPUBindingUtils) -> WebGPUBackend {
  self.backend_.unwrap()
}

///|
/// `createBindingsLayout( bindGroup )`.
pub fn WebGPUBindingUtils::create_bindings_layout(
  self : WebGPUBindingUtils,
  bind_group : @nodes.BindGroup,
) -> @gpu.GPUBindGroupLayout {
  let backend = self.backend()
  let device = backend.gpu_device()
  let bindings_data = backend.get(@core.JsValue::of(bind_group))
  // check if the the bind group already has a layout
  match wgpu_opt(bindings_data, "layout") {
    Some(layout) => {
      let layout : WebGPUBindGroupLayout = layout
      return layout.layout_gpu
    }
    None => ()
  }
  // if not, assing one
  let entries = self._create_layout_entries(bind_group)
  let entries_js = entries.map(fn(e) { e.to_js() })
  let bind_group_layout_key = wgpu_number_string(
    @nodes.hash_string(@gpu.json_stringify(@core.JsValue::of(entries_js))),
  )
  // try to find an existing layout in the cache
  let bind_group_layout = match
    self._bind_group_layout_cache.get(bind_group_layout_key) {
    Some(l) => l
    None => {
      // if not create a new one
      let l = {
        layout_gpu: device.create_bind_group_layout(
          @gpu.GPUBindGroupLayoutDescriptor::new(entries~),
        ),
        used_times: 0,
      }
      self._bind_group_layout_cache[bind_group_layout_key] = l
      l
    }
  }
  bind_group_layout.used_times += 1
  bindings_data.set("layout", @core.JsValue::of(bind_group_layout))
  bindings_data.set("layoutKey", @core.JsValue::of(bind_group_layout_key))
  bind_group_layout.layout_gpu
}

///|
/// `createBindings( bindGroup, bindings, cacheKey, version = 0 )`.
pub fn WebGPUBindingUtils::create_bindings(
  self : WebGPUBindingUtils,
  bind_group : @nodes.BindGroup,
  _bindings : Array[@nodes.BindGroup],
  cache_key : String,
  version : Int32,
) -> Unit {
  let backend = self.backend()
  let bindings_data = backend.get(@core.JsValue::of(bind_group))
  // setup (static) binding layout and (dynamic) binding group
  let bind_layout_gpu = self.create_bindings_layout(bind_group)
  let mut bind_group_gpu : @core.JsValue = @core.JsValue::undefined()
  if cache_key != "" {
    if bindings_data.get("groups").is_undefined() {
      bindings_data.set("groups", @core.JsValue::object())
      bindings_data.set("versions", @core.JsValue::object())
    }
    if bindings_data
      .get("versions")
      .get(cache_key)
      .strict_equal(@core.JsValue::of(version)) {
      bind_group_gpu = bindings_data.get("groups").get(cache_key)
    }
  }
  if bind_group_gpu.is_undefined() {
    bind_group_gpu = @core.JsValue::of(
      self.create_bind_group(bind_group, bind_layout_gpu),
    )
    if cache_key != "" {
      bindings_data.get("groups").set(cache_key, bind_group_gpu)
      bindings_data.get("versions").set(cache_key, @core.JsValue::of(version))
    }
  }
  bindings_data.set("group", bind_group_gpu)
}

///|
/// `updateBinding( binding )`: uploads a uniform buffer.
pub fn WebGPUBindingUtils::update_binding(
  self : WebGPUBindingUtils,
  binding : @nodes.Binding,
) -> Unit {
  let backend = self.backend()
  let device = backend.gpu_device()
  let array = binding.buffer().unwrap() // cpu
  let buffer : @gpu.GPUBuffer = backend
    .get(@core.JsValue::of(binding))
    .get("buffer")
    .cast() // gpu
  let update_ranges = binding.update_ranges()
  if update_ranges.length() == 0 {
    device.queue().write_buffer(buffer, 0, array, data_offset=0)
  } else {
    let byte_offset_factor = 1
    // Update ranges arrive sorted and non-overlapping which makes
    // it easy to merge contiguous ranges.
    let mut start = update_ranges[0].start // start of the current merged range
    for i = 0; i < update_ranges.length(); i = i + 1 {
      let range = update_ranges[i]
      let next = if i + 1 < update_ranges.length() {
        Some(update_ranges[i + 1])
      } else {
        None
      }
      let end = range.start + range.count // exclusive end of the current range
      // keep merging while the next range is contiguous
      match next {
        Some(n) if n.start == end => continue
        _ => ()
      }
      // write the merged range
      let data_offset = start * byte_offset_factor
      let size = (end - start) * byte_offset_factor
      let buffer_offset = data_offset * array.bytes_per_element() // bufferOffset is always in bytes
      device
      .queue()
      .write_buffer(buffer, buffer_offset, array, data_offset~, size~)
      // start next if possible
      match next {
        Some(n) => start = n.start
        None => ()
      }
    }
  }
}

///|
/// `createBindGroupIndex( data, layoutGPU )`: the bind group of an array camera's
/// sub-camera index.
pub fn WebGPUBindingUtils::create_bind_group_index(
  self : WebGPUBindingUtils,
  data : @core.TypedArray,
  layout_gpu : @gpu.GPUBindGroupLayout,
) -> @gpu.GPUBindGroup {
  let backend = self.backend()
  let device = backend.gpu_device()
  let usage = @gpu.GPU_BUFFER_USAGE_UNIFORM | @gpu.GPU_BUFFER_USAGE_COPY_DST
  let index = data.get_int(0)
  let bd = _web_gpu_binding_utils_buffer_descriptor
  bd.label = Some("bindingCameraIndex_" + index.to_string())
  bd.size = 16 // uint(4) * 4
  bd.usage = usage
  let buffer = device.create_buffer(bd)
  bd.reset()
  device.queue().write_buffer(buffer, 0, data, data_offset=0)
  let bgd = _web_gpu_binding_utils_bind_group_descriptor
  bgd.label = Some("bindGroupCameraIndex_" + index.to_string())
  bgd.layout = Some(layout_gpu)
  bgd.entries.push(
    @gpu.GPUBindGroupEntry::new(
      binding=0,
      resource=BufferBinding(@gpu.GPUBufferBinding::new(buffer~)),
    ),
  )
  let bind_group = device.create_bind_group(bgd)
  bgd.reset()
  bind_group
}

///|
/// `texture.isArrayTexture || texture.isDataArrayTexture ||
/// texture.isCompressedArrayTexture`.
fn wgpu_is_any_array_texture(texture : @core.Texture) -> Bool {
  texture.is_array_texture ||
  texture.texture_type is (DataArrayTexture | CompressedArrayTexture)
}

///|
/// `createBindGroup( bindGroup, layoutGPU )`.
pub fn WebGPUBindingUtils::create_bind_group(
  self : WebGPUBindingUtils,
  bind_group : @nodes.BindGroup,
  layout_gpu : @gpu.GPUBindGroupLayout,
) -> @gpu.GPUBindGroup {
  let backend = self.backend()
  let device = backend.gpu_device()
  let mut binding_point = 0
  let bgd = _web_gpu_binding_utils_bind_group_descriptor
  bgd.label = Some("bindGroup_" + bind_group.name)
  bgd.layout = Some(layout_gpu)
  for binding in bind_group.bindings {
    if binding.has_flag("isUniformBuffer") {
      let binding_data = backend.get(@core.JsValue::of(binding))
      bgd.entries.push(
        @gpu.GPUBindGroupEntry::new(
          binding=binding_point,
          resource=BufferBinding(
            @gpu.GPUBufferBinding::new(buffer=binding_data.get("buffer").cast()),
          ),
        ),
      )
    } else if binding.has_flag("isStorageBuffer") {
      let buffer : @gpu.GPUBuffer = backend
        .get(@core.JsValue::of(binding.attribute().unwrap()))
        .get("buffer")
        .cast()
      bgd.entries.push(
        @gpu.GPUBindGroupEntry::new(
          binding=binding_point,
          resource=BufferBinding(@gpu.GPUBufferBinding::new(buffer~)),
        ),
      )
    } else if binding.has_flag("isSampledTexture") {
      let texture = binding.texture().unwrap()
      let texture_data = backend.get(@core.JsValue::of(texture))
      let resource_gpu : @gpu.GPUBindingResource = if !texture_data
        .get("externalTexture")
        .is_undefined() {
        ExternalTexture(
          device.import_external_texture(
            @gpu.GPUExternalTextureDescriptor::new(
              source=texture_data.get("externalTexture"),
            ),
          ),
        )
      } else {
        let texture_gpu : @gpu.GPUTexture = texture_data.get("texture").cast()
        let mip_level_count = if binding.store() {
          1
        } else {
          texture_gpu.mip_level_count()
        }
        let base_mip_level = if binding.store() {
          binding.mip_level()
        } else {
          0
        }
        let mut property_name = "view-\{texture_gpu.width()}-\{texture_gpu.height()}"
        if texture_gpu.depth_or_array_layers() > 1 {
          property_name = property_name +
            "-\{texture_gpu.depth_or_array_layers()}"
        }
        property_name = property_name + "-\{mip_level_count}-\{base_mip_level}"
        let view = match wgpu_opt(texture_data, property_name) {
          Some(v) => v
          None => {
            let aspect_gpu = if texture.is_depth_texture() {
              GPUTextureAspect_DepthOnly
            } else {
              GPUTextureAspect_All
            }
            let dimension_view_gpu = if binding.has_flag("isSampledCubeTexture") {
              GPUTextureViewDimension_Cube
            } else if wgpu_is_any_array_texture(texture) {
              // Prefer the texture's actual array flag over the cached 3D binding type.
              // Layered render targets can become array textures after shader compilation.
              GPUTextureViewDimension_TwoDArray
            } else if binding.has_flag("isSampledTexture3D") {
              GPUTextureViewDimension_ThreeD
            } else {
              GPUTextureViewDimension_TwoD
            }
            let vd = _web_gpu_binding_utils_view_descriptor
            vd.aspect = Some(aspect_gpu)
            vd.dimension = Some(dimension_view_gpu)
            vd.mip_level_count = Some(mip_level_count)
            vd.base_mip_level = Some(base_mip_level)
            let v = texture_gpu.create_view(descriptor=vd)
            texture_data.set(property_name, @core.JsValue::of(v))
            vd.reset()
            v
          }
        }
        TextureView(view)
      }
      bgd.entries.push(
        @gpu.GPUBindGroupEntry::new(
          binding=binding_point,
          resource=resource_gpu,
        ),
      )
    } else if binding.has_flag("isSampler") {
      let binding_data = backend.get(@core.JsValue::of(binding))
      bgd.entries.push(
        @gpu.GPUBindGroupEntry::new(
          binding=binding_point,
          resource=Sampler(binding_data.get("sampler").cast()),
        ),
      )
    }
    binding_point += 1
  }
  let bind_group_gpu = device.create_bind_group(bgd)
  bgd.reset()
  bind_group_gpu
}

///|
/// `binding.access` of the node bindings.
fn wgpu_binding_access(binding : @nodes.Binding) -> String? {
  match @nodes.NodeStorageBuffer::of(binding) {
    Some(b) => Some(b.access)
    None =>
      match @nodes.NodeSampledTexture::of(binding) {
        Some(t) => t.access
        None => None
      }
  }
}

///|
/// `_createLayoutEntries( bindGroup )`.
fn WebGPUBindingUtils::_create_layout_entries(
  self : WebGPUBindingUtils,
  bind_group : @nodes.BindGroup,
) -> Array[@gpu.GPUBindGroupLayoutEntry] {
  let entries = []
  let mut index = 0
  for binding in bind_group.bindings {
    let backend = self.backend()
    let binding_gpu = @gpu.GPUBindGroupLayoutEntry::new(
      binding=index,
      visibility=binding.visibility,
    )
    if binding.has_flag("isUniformBuffer") ||
      binding.has_flag("isStorageBuffer") {
      let buffer = @gpu.GPUBufferBindingLayout::new() // GPUBufferBindingLayout
      if binding.has_flag("isStorageBuffer") {
        let access = wgpu_binding_access(binding)
        let is_atomic = match binding.node_uniform() {
          Some(n) =>
            match @nodes.StorageBufferNode::of(n) {
              Some(s) => s.is_atomic
              None => false
            }
          None => false
        }
        if (binding.visibility & GPUShaderStage_COMPUTE) != 0 {
          if access == Some(@nodes.node_access_read_write) ||
            access == Some(@nodes.node_access_write_only) {
            buffer.type_ = Some(GPUBufferBindingType_Storage)
          } else {
            buffer.type_ = Some(GPUBufferBindingType_ReadOnlyStorage)
          }
        } else if is_atomic &&
          (binding.visibility & GPUShaderStage_FRAGMENT) != 0 {
          // Atomic buffers require a read_write storage binding. Per the WGSL
          // spec this is only valid in the fragment stage (compute is handled
          // above), so the vertex stage falls back to read-only storage.
          buffer.type_ = Some(GPUBufferBindingType_Storage)
        } else {
          buffer.type_ = Some(GPUBufferBindingType_ReadOnlyStorage)
        }
      }
      binding_gpu.buffer = Some(buffer)
    } else if binding.has_flag("isSampledTexture") && binding.store() {
      let texture = binding.texture().unwrap()
      let storage_texture = @gpu.GPUStorageTextureBindingLayout::new() // GPUStorageTextureBindingLayout
      let texture_gpu : @gpu.GPUTexture = self
        .backend()
        .get(@core.JsValue::of(texture))
        .get("texture")
        .cast()
      storage_texture.format = Some(texture_gpu.format())
      let access = wgpu_binding_access(binding)
      if access == Some(@nodes.node_access_read_write) {
        storage_texture.access = Some(GPUStorageTextureAccess_ReadWrite)
      } else if access == Some(@nodes.node_access_write_only) {
        storage_texture.access = Some(GPUStorageTextureAccess_WriteOnly)
      } else {
        storage_texture.access = Some(GPUStorageTextureAccess_ReadOnly)
      }
      if texture.is_array_texture {
        storage_texture.view_dimension = Some(GPUTextureViewDimension_TwoDArray)
      } else if texture.has_extension_flag("is3DTexture") {
        storage_texture.view_dimension = Some(GPUTextureViewDimension_ThreeD)
      }
      binding_gpu.storage_texture = Some(storage_texture)
    } else if binding.has_flag("isSampledTexture") {
      let texture = binding.texture().unwrap()
      let texture_layout = @gpu.GPUTextureBindingLayout::new() // GPUTextureBindingLayout
      let { primary_samples, .. } = backend.utils.get_texture_sample_data(
        texture,
      )
      if primary_samples > 1 {
        texture_layout.multisampled = Some(true)
        if !texture.is_depth_texture() {
          texture_layout.sample_type = Some(
            GPUTextureSampleType_UnfilterableFloat,
          )
        }
      }
      if texture.is_depth_texture() {
        if backend.compatibility_mode == Some(true) &&
          texture.compare_function is None {
          texture_layout.sample_type = Some(
            GPUTextureSampleType_UnfilterableFloat,
          )
        } else {
          texture_layout.sample_type = Some(GPUTextureSampleType_Depth)
        }
      } else {
        let type_ = texture.type_
        if type_ == @core.IntType {
          texture_layout.sample_type = Some(GPUTextureSampleType_SInt)
        } else if type_ == @core.UnsignedIntType {
          texture_layout.sample_type = Some(GPUTextureSampleType_UInt)
        } else if texture.normalized == true &&
          (type_ == @core.ShortType || type_ == @core.UnsignedShortType) {
          texture_layout.sample_type = Some(
            GPUTextureSampleType_UnfilterableFloat,
          )
        } else if type_ == @core.FloatType {
          if backend.has_feature_("float32-filterable") {
            texture_layout.sample_type = Some(GPUTextureSampleType_Float)
          } else {
            texture_layout.sample_type = Some(
              GPUTextureSampleType_UnfilterableFloat,
            )
          }
        }
      }
      if binding.has_flag("isSampledCubeTexture") {
        texture_layout.view_dimension = Some(GPUTextureViewDimension_Cube)
      } else if wgpu_is_any_array_texture(texture) {
        texture_layout.view_dimension = Some(GPUTextureViewDimension_TwoDArray)
      } else if binding.has_flag("isSampledTexture3D") {
        texture_layout.view_dimension = Some(GPUTextureViewDimension_ThreeD)
      }
      binding_gpu.texture = Some(texture_layout)
    } else if binding.has_flag("isSampler") {
      let texture = binding.texture().unwrap()
      let sampler = @gpu.GPUSamplerBindingLayout::new() // GPUSamplerBindingLayout
      if texture.is_depth_texture() {
        if texture.compare_function is Some(_) &&
          @nodes.TextureNode::is_sample_compare(binding.texture_node().unwrap()) &&
          backend.base().has_compatibility(@core.Compatibility_TEXTURE_COMPARE) {
          sampler.type_ = Some(GPUSamplerBindingType_Comparison)
        } else {
          // Depth textures without compare must use non-filtering sampler
          sampler.type_ = Some(GPUSamplerBindingType_NonFiltering)
        }
      }
      binding_gpu.sampler = Some(sampler)
    } else {
      @core.error(
        "WebGPUBindingUtils: Unsupported binding \"[object Object]\".",
      )
    }
    entries.push(binding_gpu)
    index += 1
  }
  entries
}

///|
/// `deleteBindGroupData( bindGroup )`.
pub fn WebGPUBindingUtils::delete_bind_group_data(
  self : WebGPUBindingUtils,
  bind_group : @nodes.BindGroup,
) -> Unit {
  let backend = self.backend()
  let bindings_data = backend.get(@core.JsValue::of(bind_group))
  match wgpu_opt(bindings_data, "layout") {
    Some(layout) => {
      let layout : WebGPUBindGroupLayout = layout
      layout.used_times -= 1
      if layout.used_times == 0 {
        let key : String = bindings_data.get("layoutKey").cast()
        self._bind_group_layout_cache.remove(key)
      }
      bindings_data.set("layout", @core.JsValue::undefined())
      bindings_data.set("layoutKey", @core.JsValue::undefined())
    }
    None => ()
  }
}

///|
/// `dispose()`.
pub fn WebGPUBindingUtils::dispose(self : WebGPUBindingUtils) -> Unit {
  self._bind_group_layout_cache.clear()
}
