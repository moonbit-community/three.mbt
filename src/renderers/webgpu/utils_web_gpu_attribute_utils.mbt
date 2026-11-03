// renderers/webgpu/utils/WebGPUAttributeUtils.js: vertex, index and storage buffers,
// vertex buffer layouts and readback.

///|
let _web_gpu_attribute_utils_buffer_descriptor : @gpu.GPUBufferDescriptor = @gpu.GPUBufferDescriptor::default()

///|
let _web_gpu_attribute_utils_command_encoder_descriptor : @gpu.GPUCommandEncoderDescriptor = @gpu.GPUCommandEncoderDescriptor::default()

///|
let _web_gpu_attribute_utils_tail : @core.TypedArray = @core.TypedArray::uint8(
  4,
)

///|
extern "js" fn wgpu_array_buffer_slice(
  buffer : @core.ArrayBuffer,
) -> @core.ArrayBuffer = "(b) => b.slice()"

///|
/// `typedArraysToVertexFormatPrefix.get( ArrayType )` (by typed array name).
fn _web_gpu_attribute_utils_prefixes(type_name : String) -> Array[String]? {
  match type_name {
    "Int8Array" => Some(["sint8", "snorm8"])
    "Uint8Array" => Some(["uint8", "unorm8"])
    "Int16Array" => Some(["sint16", "snorm16"])
    "Uint16Array" => Some(["uint16", "unorm16"])
    "Int32Array" => Some(["sint32"])
    "Uint32Array" => Some(["uint32"])
    "Float32Array" => Some(["float32"])
    "Float16Array" => Some(["float16"])
    _ => None
  }
}

///|
/// `typeArraysToVertexFormatPrefixForItemSize1.get( ArrayType )`.
fn _web_gpu_attribute_utils_prefix_item_size1(type_name : String) -> String? {
  match type_name {
    "Int32Array" => Some("sint32")
    "Uint32Array" => Some("uint32")
    "Float32Array" => Some("float32")
    _ => None
  }
}

///|
/// `writeBufferAligned( device, buffer, array, start, count )`: writes typed data whose
/// elements are smaller than 4 bytes in 4-byte aligned chunks.
fn _web_gpu_attribute_utils_write_buffer_aligned(
  device : @gpu.GPUDevice,
  buffer : @gpu.GPUBuffer,
  array : @core.TypedArray,
  start : Int32,
  count : Int32,
) -> Unit {
  let bytes = @core.TypedArray::view_by_name(
    "Uint8Array",
    array.buffer(),
    byte_offset=array.byte_offset(),
    length=array.byte_length(),
  )
  let bpe = array.bytes_per_element()
  let byte_start = start * bpe / 4 * 4
  let byte_end = (start + count) * bpe
  let aligned_end = byte_end / 4 * 4
  if aligned_end > byte_start {
    device
    .queue()
    .write_buffer(
      buffer,
      byte_start,
      bytes,
      data_offset=byte_start,
      size=aligned_end - byte_start,
    )
  }
  if byte_end > aligned_end {
    _web_gpu_attribute_utils_tail.fill(0.0)
    _web_gpu_attribute_utils_tail.set_from(
      bytes.subarray(start=aligned_end, end=aligned_end + 4),
    )
    device
    .queue()
    .write_buffer(buffer, aligned_end, _web_gpu_attribute_utils_tail)
  }
}

///|
/// `WebGPUAttributeUtils`.
pub(all) struct WebGPUAttributeUtils {
  /// `backend`, linked right after the backend is built.
  mut backend_ : WebGPUBackend?
}

///|
/// `new WebGPUAttributeUtils( backend )` (the backend is linked by `WebGPUBackend::new`).
fn WebGPUAttributeUtils::new() -> WebGPUAttributeUtils {
  { backend_: None, }
}

///|
fn WebGPUAttributeUtils::backend(self : WebGPUAttributeUtils) -> WebGPUBackend {
  self.backend_.unwrap()
}

///|
/// `bufferAttribute.array`.
fn wgpu_buffer_array(attribute : @nodes.AttributeBuffer) -> @core.TypedArray {
  match attribute {
    Buffer(a) => a.array
    Interleaved(a) => a.array
    GL(_) =>
      abort("TypeError: Cannot read properties of undefined (reading 'array')")
  }
}

///|
/// `bufferAttribute.array = array`.
fn wgpu_set_buffer_array(
  attribute : @nodes.AttributeBuffer,
  array : @core.TypedArray,
) -> Unit {
  match attribute {
    Buffer(a) => a.array = array
    Interleaved(a) => a.array = array
    GL(_) => ()
  }
}

///|
/// `createAttribute( attribute, usage )`.
pub fn WebGPUAttributeUtils::create_attribute(
  self : WebGPUAttributeUtils,
  attribute : @nodes.AttributeBuffer,
  usage : Int32,
) -> Unit {
  let backend = self.backend()
  let buffer_attribute = attribute
  let buffer_data = backend.get(buffer_attribute.key())
  if !buffer_data.get("buffer").is_undefined() {
    return
  }
  let device = backend.gpu_device()
  let mut array = wgpu_buffer_array(buffer_attribute)
  // WGSL has no 8 or 16 bit integer types and vertex strides must be a multiple of 4 bytes,
  // so widen these integers to 32 bit. index buffers only need uint16 unless used as storage
  match attribute {
    Buffer(a) if a.normalized == false => {
      let name = array.type_name()
      if name == "Int16Array" || name == "Int8Array" {
        array = @core.TypedArray::int32(array)
      } else if name == "Uint16Array" || name == "Uint8Array" {
        let is_index_buffer = (usage & @gpu.GPU_BUFFER_USAGE_INDEX) != 0
        let is_storage_buffer = (usage & @gpu.GPU_BUFFER_USAGE_STORAGE) != 0
        let uint_name = if is_index_buffer && !is_storage_buffer {
          "Uint16Array"
        } else {
          "Uint32Array"
        }
        if name != uint_name {
          array = @core.TypedArray::new_by_name(uint_name, array)
        }
        // widened indices need the uint32 primitive restart value
        if is_index_buffer && is_storage_buffer {
          for i = 0; i < array.length(); i = i + 1 {
            if array.get(i) == 65535.0 {
              array.set(i, 4294967295.0)
            }
          }
        }
      }
    }
    _ => ()
  }
  wgpu_set_buffer_array(buffer_attribute, array)
  let mut padded_item_size : Int32? = None
  let is_storage = wgpu_is_storage_attribute(buffer_attribute)
  let item_size = match buffer_attribute {
    Buffer(a) => Some(a.item_size)
    _ => None
  }
  let bpe = array.bytes_per_element()
  match item_size {
    Some(3) if is_storage =>
      // WGSL does not support packed vec3 data in storage buffers, pad to vec4
      padded_item_size = Some(4)
    Some(s) if s > 1 && s * bpe % 4 != 0 => {
      // arrayStride must be a multiple of 4
      let byte_stride = s * bpe
      padded_item_size = Some((byte_stride + 3) / 4 * 4 / bpe)
    }
    _ => ()
  }
  match (padded_item_size, buffer_attribute) {
    (Some(padded), Buffer(a)) => {
      let item_size = a.item_size
      let padded_array = @core.TypedArray::new_like(array, a.count * padded)
      for i = 0; i < a.count; i = i + 1 {
        padded_array.set_from(
          array.subarray(start=i * item_size, end=i * item_size + item_size),
          offset=i * padded,
        )
      }
      if is_storage {
        // update the storage attribute so storage bindings access the padded layout
        a.item_size = padded
        a.array = padded_array
      }
      array = padded_array
      // save the original and padded item size so buffer updates can apply the same padding
      buffer_data.set("_itemSize", @core.JsValue::of(item_size))
      buffer_data.set("_paddedItemSize", @core.JsValue::of(padded))
    }
    _ => ()
  }
  // total buffer size must be a multiple of 4
  let byte_length = array.byte_length()
  let size = byte_length + (4 - byte_length % 4) % 4
  let bd = _web_gpu_attribute_utils_buffer_descriptor
  bd.label = wgpu_buffer_name(buffer_attribute)
  bd.size = size
  bd.usage = usage
  bd.mapped_at_creation = Some(true)
  let buffer = device.create_buffer(bd)
  bd.reset()
  @core.TypedArray::new_like_from_buffer(array, buffer.get_mapped_range()).set_from(
    array,
  )
  buffer.unmap()
  buffer_data.set("buffer", @core.JsValue::of(buffer))
}

///|
/// `updateAttribute( attribute )`.
pub fn WebGPUAttributeUtils::update_attribute(
  self : WebGPUAttributeUtils,
  attribute : @nodes.AttributeBuffer,
) -> Unit {
  let backend = self.backend()
  let device = backend.gpu_device()
  let buffer_attribute = attribute
  let buffer_data = backend.get(buffer_attribute.key())
  let buffer : @gpu.GPUBuffer = buffer_data.get("buffer").cast()
  let mut array = wgpu_buffer_array(buffer_attribute)
  let item_size : Int32? = wgpu_opt(buffer_data, "_itemSize")
  let padded_item_size : Int32? = wgpu_opt(buffer_data, "_paddedItemSize")
  match (padded_item_size, buffer_attribute) {
    (Some(padded), Buffer(a)) => {
      let item_size = item_size.unwrap()
      // if the attribute data were padded on upload, apply the same padding on updates.
      let source = a.array
      array = @core.TypedArray::new_like(source, a.count * padded)
      for i = 0; i < a.count; i = i + 1 {
        array.set_from(
          source.subarray(start=i * item_size, end=i * item_size + item_size),
          offset=i * padded,
        )
      }
      if wgpu_is_storage_attribute(buffer_attribute) {
        // keep the storage attribute in sync with the padded layout
        a.array = array
      }
    }
    _ => ()
  }
  let update_ranges = match buffer_attribute {
    Buffer(a) => a.update_ranges
    Interleaved(a) => a.update_ranges
    GL(_) => []
  }
  let needs_alignment = array.bytes_per_element() < 4
  if update_ranges.length() == 0 {
    // Not using update ranges
    if needs_alignment {
      _web_gpu_attribute_utils_write_buffer_aligned(
        device,
        buffer,
        array,
        0,
        array.length(),
      )
    } else {
      device.queue().write_buffer(buffer, 0, array, data_offset=0)
    }
  } else {
    let byte_offset_factor = 1
    for range in update_ranges {
      let (data_offset, size) = match (padded_item_size, item_size) {
        (Some(padded), Some(item_size)) => {
          let vertex_start = range.start / item_size
          let vertex_count = wgpu_ceil_div(range.start + range.count, item_size) -
            vertex_start
          (
            vertex_start * padded * byte_offset_factor,
            vertex_count * padded * byte_offset_factor,
          )
        }
        _ =>
          (range.start * byte_offset_factor, range.count * byte_offset_factor)
      }
      if needs_alignment {
        _web_gpu_attribute_utils_write_buffer_aligned(
          device, buffer, array, data_offset, size,
        )
      } else {
        let buffer_offset = data_offset * array.bytes_per_element() // bufferOffset is always in bytes
        device
        .queue()
        .write_buffer(buffer, buffer_offset, array, data_offset~, size~)
      }
    }
    match buffer_attribute {
      Buffer(a) => a.clear_update_ranges()
      Interleaved(a) => a.clear_update_ranges()
      GL(_) => ()
    }
  }
}

///|
/// `getVertexBufferLayout( renderObject )`.
pub fn WebGPUAttributeUtils::get_vertex_buffer_layout(
  self : WebGPUAttributeUtils,
  render_object : @nodes.RenderObject,
) -> Array[@gpu.GPUVertexBufferLayout] {
  let attributes = render_object.get_attributes()
  let vertex_buffers : Array[
    (@nodes.AttributeBuffer, @gpu.GPUVertexBufferLayout),
  ] = []
  for slot = 0; slot < attributes.length(); slot = slot + 1 {
    let geometry_attribute = attributes[slot]
    let bytes_per_element = geometry_attribute.array().bytes_per_element()
    let buffer_attribute = self
      .backend()
      .base()
      .get_buffer_attribute(geometry_attribute)
    let mut vertex_buffer_layout = None
    for entry in vertex_buffers {
      if entry.0.same(buffer_attribute) {
        vertex_buffer_layout = Some(entry.1)
        break
      }
    }
    let layout = match vertex_buffer_layout {
      Some(l) => l
      None => {
        // the layout is defined by the buffer, interleaved attributes can also view a buffer attribute
        let (array_stride, step_mode) = match buffer_attribute {
          Interleaved(b) =>
            (
              b.stride * bytes_per_element,
              if b.is_instanced_interleaved_buffer {
                GPUInputStepMode_Instance
              } else {
                GPUInputStepMode_Vertex
              },
            )
          Buffer(b) => {
            let mut array_stride = b.item_size * bytes_per_element
            if b.item_size > 1 && array_stride % 4 != 0 {
              // packed attribute data are padded per vertex on upload
              array_stride = (array_stride + 3) / 4 * 4
            }
            (
              array_stride,
              if b.is_instanced_buffer_attribute() {
                GPUInputStepMode_Instance
              } else {
                GPUInputStepMode_Vertex
              },
            )
          }
          GL(b) => (b.item_size * bytes_per_element, GPUInputStepMode_Vertex)
        }
        let l = @gpu.GPUVertexBufferLayout::new(
          array_stride~,
          attributes=[],
          step_mode~,
        )
        vertex_buffers.push((buffer_attribute, l))
        l
      }
    }
    let format = self._get_vertex_format(geometry_attribute)
    let offset = match geometry_attribute {
      Interleaved(a) => a.offset * bytes_per_element
      _ => 0
    }
    layout.attributes.push(
      @gpu.GPUVertexAttribute::new(
        shader_location=slot,
        offset~,
        format=format.unwrap_or("undefined"),
      ),
    )
  }
  vertex_buffers.map(fn(e) { e.1 })
}

///|
/// `getVertexBufferLayoutCacheKey( renderObject )`.
pub fn WebGPUAttributeUtils::get_vertex_buffer_layout_cache_key(
  self : WebGPUAttributeUtils,
  render_object : @nodes.RenderObject,
) -> String {
  let vertex_buffer_layout = self.get_vertex_buffer_layout(render_object)
  let cache_key = StringBuilder()
  for entry in vertex_buffer_layout {
    cache_key.write_string(
      "\{entry.array_stride},\{entry.step_mode.unwrap_or("undefined")},",
    )
    for attribute in entry.attributes {
      cache_key.write_string(
        "\{attribute.shader_location},\{attribute.offset},\{attribute.format},",
      )
    }
  }
  cache_key.to_string()
}

///|
/// `destroyAttribute( attribute )`.
pub fn WebGPUAttributeUtils::destroy_attribute(
  self : WebGPUAttributeUtils,
  attribute : @nodes.AttributeBuffer,
) -> Unit {
  let backend = self.backend()
  let data = backend.get(attribute.key())
  let buffer : @gpu.GPUBuffer = data.get("buffer").cast()
  buffer.destroy()
  backend.delete(attribute.key())
}

///|
/// `bufferAttribute.name`; `None` (`undefined`) for interleaved buffers.
fn wgpu_buffer_name(attribute : @nodes.AttributeBuffer) -> String? {
  match attribute {
    Buffer(a) => Some(a.name)
    Interleaved(_) | GL(_) => None
  }
}

///|
/// `attribute.name` in a template string.
fn wgpu_attribute_name(attribute : @nodes.AttributeBuffer) -> String {
  wgpu_buffer_name(attribute).unwrap_or("undefined")
}

///|
/// `async getArrayBufferAsync( attribute, target = null, offset = 0, count = - 1 )`:
/// calls back with the `ArrayBuffer` or the `ReadbackBuffer`.
pub fn WebGPUAttributeUtils::get_array_buffer_async(
  self : WebGPUAttributeUtils,
  attribute : @nodes.AttributeBuffer,
  target : @nodes.ReadbackBuffer?,
  offset : Int32,
  count : Int32,
  on_done : (@core.JsValue) -> Unit,
) -> Unit {
  let backend = self.backend()
  let device = backend.gpu_device()
  let data = backend.get(attribute.key())
  let buffer_gpu : @gpu.GPUBuffer = data.get("buffer").cast()
  let byte_length = if count == -1 { buffer_gpu.size() - offset } else { count }
  let bd = _web_gpu_attribute_utils_buffer_descriptor
  let read_buffer_gpu = match target {
    Some(target) => {
      let readback_info = backend.get(@core.JsValue::of(target))
      if target._mapped == true {
        abort(
          "THREE.WebGPUAttributeUtils: ReadbackBuffer must be released before being used again.",
        )
      }
      target._mapped = true
      // initialize the GPU-side read copy buffer if it is not present
      match wgpu_opt(readback_info, "readBufferGPU") {
        Some(b) => b
        None => {
          bd.label = Some("\{target.name}_readback")
          bd.size = target.max_byte_length
          bd.usage = @gpu.GPU_BUFFER_USAGE_COPY_DST |
            @gpu.GPU_BUFFER_USAGE_MAP_READ
          let read_buffer_gpu = device.create_buffer(bd)
          bd.reset()
          // release / dispose
          let release_callback = fn(_e : @core.Event) {
            target.buffer = None
            target._mapped = false
            read_buffer_gpu.unmap()
          }
          let dispose_callback : Ref[(@core.Event) -> Unit] = Ref(fn(_) {  })
          dispose_callback.val = fn(_e) {
            target.buffer = None
            target._mapped = false
            read_buffer_gpu.destroy()
            backend.delete(@core.JsValue::of(target))
            target.remove_event_listener("release", release_callback)
            target.remove_event_listener("dispose", dispose_callback.val)
          }
          target.add_event_listener("release", release_callback)
          target.add_event_listener("dispose", dispose_callback.val)
          // register
          readback_info.set("readBufferGPU", @core.JsValue::of(read_buffer_gpu))
          read_buffer_gpu
        }
      }
    }
    None => {
      // create a new temp buffer for array buffers otherwise
      bd.label = Some("\{wgpu_attribute_name(attribute)}_readback")
      bd.size = byte_length
      bd.usage = @gpu.GPU_BUFFER_USAGE_COPY_DST | @gpu.GPU_BUFFER_USAGE_MAP_READ
      let b = device.create_buffer(bd)
      bd.reset()
      b
    }
  }
  // copy the data
  let ced = _web_gpu_attribute_utils_command_encoder_descriptor
  ced.label = Some("readback_encoder_\{wgpu_attribute_name(attribute)}")
  let cmd_encoder = device.create_command_encoder(descriptor=ced)
  ced.reset()
  cmd_encoder.copy_buffer_to_buffer(
    buffer_gpu, offset, read_buffer_gpu, 0, byte_length,
  )
  let gpu_commands = cmd_encoder.finish()
  wgpu_submit(device, gpu_commands)
  // map the data to the CPU
  wgpu_await(
    read_buffer_gpu.map_async_promise(
      @gpu.GPU_MAP_MODE_READ,
      offset=0,
      size=byte_length,
    ),
    fn(_) {
      match target {
        None => {
          // return a new array buffer and clean up the gpu handles
          let array_buffer = read_buffer_gpu.get_mapped_range(
            offset=0,
            size=byte_length,
          )
          let result = wgpu_array_buffer_slice(array_buffer)
          read_buffer_gpu.destroy()
          on_done(@core.JsValue::of(result))
        }
        Some(target) => {
          // assign the data to the read back handle
          target.buffer = Some(
            @core.JsValue::of(
              read_buffer_gpu.get_mapped_range(offset=0, size=byte_length),
            ),
          )
          on_done(@core.JsValue::of(target))
        }
      }
    },
    fn(e) { abort(wgpu_error_string(e)) },
  )
}

///|
/// `_getVertexFormat( geometryAttribute )`; `None` is `undefined`.
fn WebGPUAttributeUtils::_get_vertex_format(
  self : WebGPUAttributeUtils,
  geometry_attribute : @core.GeometryAttribute,
) -> String? {
  ignore(self)
  let item_size = geometry_attribute.item_size()
  let normalized = geometry_attribute.normalized()
  let array = geometry_attribute.array()
  let array_type = array.type_name()
  let mut format = None
  if item_size == 1 {
    format = _web_gpu_attribute_utils_prefix_item_size1(array_type)
  } else {
    let is_float16_attribute = match geometry_attribute {
      Buffer(a) => a.is_float16_buffer_attribute()
      _ => false
    }
    let prefix_options = if is_float16_attribute {
      Some(["float16"])
    } else {
      _web_gpu_attribute_utils_prefixes(array_type)
    }
    let prefix_options = match prefix_options {
      Some(p) => p
      None =>
        abort(
          "TypeError: Cannot read properties of undefined (reading '\{if normalized { 1 } else { 0 }}')",
        )
    }
    let index = if normalized { 1 } else { 0 }
    if index < prefix_options.length() {
      let prefix = prefix_options[index]
      let bytes_per_unit = array.bytes_per_element() * item_size
      let padded_bytes_per_unit = (bytes_per_unit + 3) / 4 * 4
      if padded_bytes_per_unit % array.bytes_per_element() != 0 {
        abort("THREE.WebGPUAttributeUtils: Bad vertex format item size.")
      }
      let padded_item_size = padded_bytes_per_unit / array.bytes_per_element()
      format = Some("\{prefix}x\{padded_item_size}")
    }
  }
  if format is None {
    @core.error("WebGPUAttributeUtils: Vertex format not supported yet.")
  }
  format
}
