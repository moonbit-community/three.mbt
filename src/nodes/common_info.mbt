// renderers/common/Info.js

///|
extern "js" fn info_math_round(x : Double) -> Double = "Math.round"

///|
/// `info.render`.
pub(all) struct InfoRender {
  mut calls : Int32
  mut frame_calls : Int32
  mut draw_calls : Int32
  mut triangles : Double
  mut points : Double
  mut lines : Double
  mut timestamp : Double
}

///|
/// `info.compute`.
pub(all) struct InfoCompute {
  mut calls : Int32
  mut frame_calls : Int32
  mut timestamp : Double
}

///|
/// `info.memory`.
pub(all) struct InfoMemory {
  mut attributes : Int32
  mut attributes_size : Double
  mut geometries : Int32
  mut index_attributes : Int32
  mut index_attributes_size : Double
  mut indirect_storage_attributes : Int32
  mut indirect_storage_attributes_size : Double
  mut programs : Int32
  mut programs_size : Double
  mut readback_buffers : Int32
  mut readback_buffers_size : Double
  mut render_targets : Int32
  mut storage_attributes : Int32
  mut storage_attributes_size : Double
  mut textures : Int32
  mut textures_size : Double
  mut uniform_buffers : Int32
  mut uniform_buffers_size : Double
  mut total : Double
}

///|
fn InfoMemory::new() -> InfoMemory {
  {
    attributes: 0,
    attributes_size: 0.0,
    geometries: 0,
    index_attributes: 0,
    index_attributes_size: 0.0,
    indirect_storage_attributes: 0,
    indirect_storage_attributes_size: 0.0,
    programs: 0,
    programs_size: 0.0,
    readback_buffers: 0,
    readback_buffers_size: 0.0,
    render_targets: 0,
    storage_attributes: 0,
    storage_attributes_size: 0.0,
    textures: 0,
    textures_size: 0.0,
    uniform_buffers: 0,
    uniform_buffers_size: 0.0,
    total: 0.0,
  }
}

///|
/// `memory[ type ] += count; memory[ type + 'Size' ] += size` for an attribute type.
fn InfoMemory::add(
  self : InfoMemory,
  type_ : String,
  count : Int32,
  size : Double,
) -> Unit {
  match type_ {
    "attributes" => {
      self.attributes += count
      self.attributes_size += size
    }
    "indexAttributes" => {
      self.index_attributes += count
      self.index_attributes_size += size
    }
    "storageAttributes" => {
      self.storage_attributes += count
      self.storage_attributes_size += size
    }
    "indirectStorageAttributes" => {
      self.indirect_storage_attributes += count
      self.indirect_storage_attributes_size += size
    }
    "uniformBuffers" => {
      self.uniform_buffers += count
      self.uniform_buffers_size += size
    }
    "readbackBuffers" => {
      self.readback_buffers += count
      self.readback_buffers_size += size
    }
    _ => abort("Info: unknown memory type \{type_}")
  }
}

///|
/// A `memoryMap` value: a size (textures, programs) or `{ size, type }`.
priv struct InfoMemoryEntry {
  size : Double
  type_ : String?
}

///|
/// Rendering statistics and GPU memory bookkeeping.
pub(all) struct Info {
  mut auto_reset : Bool
  mut frame : Int32
  mut calls : Int32
  render : InfoRender
  compute : InfoCompute
  memory : InfoMemory
  priv mut memory_map : @webgl.WeakMap[@core.JsValue, InfoMemoryEntry]
}

///|
/// `new Info()`.
pub fn Info::new() -> Info {
  {
    auto_reset: true,
    frame: 0,
    calls: 0,
    render: {
      calls: 0,
      frame_calls: 0,
      draw_calls: 0,
      triangles: 0.0,
      points: 0.0,
      lines: 0.0,
      timestamp: 0.0,
    },
    compute: { calls: 0, frame_calls: 0, timestamp: 0.0, },
    memory: InfoMemory::new(),
    memory_map: @webgl.WeakMap::new(),
  }
}

///|
/// `update( object, count, instanceCount )`: counts one draw call.
pub fn Info::update(
  self : Info,
  object : @core.Object3D,
  count : Double,
  instance_count : Double,
) -> Unit {
  self.render.draw_calls += 1
  if object.is_mesh() || object.is_sprite() {
    self.render.triangles += instance_count * (count / 3.0)
  } else if object.is_points() {
    self.render.points += instance_count * count
  } else if object.is_line_segments() {
    self.render.lines += instance_count * (count / 2.0)
  } else if object.is_line() {
    self.render.lines += instance_count * (count - 1.0)
  } else {
    @core.error("WebGPUInfo: Unknown object type.")
  }
}

///|
/// `reset()`: clears the per-frame counters.
pub fn Info::reset(self : Info) -> Unit {
  self.render.draw_calls = 0
  self.render.frame_calls = 0
  self.compute.frame_calls = 0
  self.render.triangles = 0.0
  self.render.points = 0.0
  self.render.lines = 0.0
}

///|
/// `dispose()`.
pub fn Info::dispose(self : Info) -> Unit {
  self.reset()
  self.calls = 0
  self.render.calls = 0
  self.compute.calls = 0
  self.render.timestamp = 0.0
  self.compute.timestamp = 0.0
  let memory = self.memory
  memory.attributes = 0
  memory.attributes_size = 0.0
  memory.geometries = 0
  memory.index_attributes = 0
  memory.index_attributes_size = 0.0
  memory.indirect_storage_attributes = 0
  memory.indirect_storage_attributes_size = 0.0
  memory.programs = 0
  memory.programs_size = 0.0
  memory.readback_buffers = 0
  memory.readback_buffers_size = 0.0
  memory.render_targets = 0
  memory.storage_attributes = 0
  memory.storage_attributes_size = 0.0
  memory.textures = 0
  memory.textures_size = 0.0
  memory.uniform_buffers = 0
  memory.uniform_buffers_size = 0.0
  memory.total = 0.0
  self.memory_map = @webgl.WeakMap::new()
}

///|
/// `createTexture( texture )`.
pub fn Info::create_texture(self : Info, texture : @core.Texture) -> Unit {
  let size = self._get_texture_memory_size(texture)
  self.memory_map.set(@core.JsValue::of(texture), { size, type_: None, })
  self.memory.textures += 1
  self.memory.total += size
  self.memory.textures_size += size
}

///|
/// `destroyTexture( texture )`.
pub fn Info::destroy_texture(self : Info, texture : @core.Texture) -> Unit {
  let key = @core.JsValue::of(texture)
  let size = match self.memory_map.get(key) {
    Some(entry) => entry.size
    None => 0.0
  }
  self.memory_map.delete(key)
  self.memory.textures -= 1
  self.memory.total -= size
  self.memory.textures_size -= size
}

///|
fn Info::_create_attribute(
  self : Info,
  attribute : AttributeBuffer,
  type_ : String,
) -> Unit {
  let size = self._get_attribute_memory_size(attribute)
  self.memory_map.set(attribute.key(), { size, type_: Some(type_), })
  self.memory.add(type_, 1, size)
  self.memory.total += size
}

///|
/// `createAttribute( attribute )`.
pub fn Info::create_attribute(self : Info, attribute : AttributeBuffer) -> Unit {
  self._create_attribute(attribute, "attributes")
}

///|
/// `createIndexAttribute( attribute )`.
pub fn Info::create_index_attribute(
  self : Info,
  attribute : AttributeBuffer,
) -> Unit {
  self._create_attribute(attribute, "indexAttributes")
}

///|
/// `createStorageAttribute( attribute )`.
pub fn Info::create_storage_attribute(
  self : Info,
  attribute : AttributeBuffer,
) -> Unit {
  self._create_attribute(attribute, "storageAttributes")
}

///|
/// `createIndirectStorageAttribute( attribute )`.
pub fn Info::create_indirect_storage_attribute(
  self : Info,
  attribute : AttributeBuffer,
) -> Unit {
  self._create_attribute(attribute, "indirectStorageAttributes")
}

///|
/// `destroyAttribute( attribute )`.
pub fn Info::destroy_attribute(
  self : Info,
  attribute : AttributeBuffer,
) -> Unit {
  let key = attribute.key()
  match self.memory_map.get(key) {
    Some({ size, type_: Some(type_), }) => {
      self.memory_map.delete(key)
      self.memory.add(type_, -1, -size)
      self.memory.total -= size
    }
    _ => ()
  }
}

///|
/// `memoryMap.has( object )` (added by G6).
pub fn Info::memory_map_has(self : Info, object : @core.JsValue) -> Bool {
  self.memory_map.has(object)
}

///|
/// `createReadbackBuffer( readbackBuffer )`.
pub fn Info::create_readback_buffer(
  self : Info,
  readback_buffer : ReadbackBuffer,
) -> Unit {
  let max_byte_length = readback_buffer.max_byte_length.to_double()
  self.memory_map.set(@core.JsValue::of(readback_buffer), {
    size: max_byte_length,
    type_: Some("readbackBuffers"),
  })
  self.memory.readback_buffers += 1
  self.memory.total += max_byte_length
  self.memory.readback_buffers_size += max_byte_length
}

///|
/// `destroyReadbackBuffer( readbackBuffer )`.
pub fn Info::destroy_readback_buffer(
  self : Info,
  readback_buffer : ReadbackBuffer,
) -> Unit {
  let key = @core.JsValue::of(readback_buffer)
  let size = match self.memory_map.get(key) {
    Some(entry) => entry.size
    None => abort("TypeError: Cannot destructure property 'size' of undefined")
  }
  self.memory_map.delete(key)
  self.memory.readback_buffers -= 1
  self.memory.total -= size
  self.memory.readback_buffers_size -= size
}

///|
/// `createUniformBuffer( uniformBuffer )`.
pub fn Info::create_uniform_buffer(
  self : Info,
  uniform_buffer : Binding,
) -> Unit {
  let size = uniform_buffer.byte_length().to_double()
  self.memory_map.set(@core.JsValue::of(uniform_buffer), {
    size,
    type_: Some("uniformBuffers"),
  })
  self.memory.uniform_buffers += 1
  self.memory.total += size
  self.memory.uniform_buffers_size += size
}

///|
/// `destroyUniformBuffer( uniformBuffer )`.
pub fn Info::destroy_uniform_buffer(
  self : Info,
  uniform_buffer : Binding,
) -> Unit {
  let key = @core.JsValue::of(uniform_buffer)
  match self.memory_map.get(key) {
    Some(entry) => {
      self.memory_map.delete(key)
      self.memory.uniform_buffers -= 1
      self.memory.total -= entry.size
      self.memory.uniform_buffers_size -= entry.size
    }
    None => ()
  }
}

///|
/// `createProgram( program )`: the code length approximates the size.
pub fn Info::create_program(self : Info, program : ProgrammableStage) -> Unit {
  let size = program.code.length().to_double()
  self.memory_map.set(@core.JsValue::of(program), { size, type_: None, })
  self.memory.programs += 1
  self.memory.total += size
  self.memory.programs_size += size
}

///|
/// `destroyProgram( program )`.
pub fn Info::destroy_program(self : Info, program : ProgrammableStage) -> Unit {
  let key = @core.JsValue::of(program)
  let size = match self.memory_map.get(key) {
    Some(entry) => entry.size
    None => 0.0
  }
  self.memory_map.delete(key)
  self.memory.programs -= 1
  self.memory.total -= size
  self.memory.programs_size -= size
}

///|
/// `x || 1` for a dimension.
fn _info_or_one(x : Double) -> Double {
  if x == 0.0 || x.is_nan() {
    1.0
  } else {
    x
  }
}

///|
/// `_getTextureMemorySize( texture )`: an estimate in bytes.
pub fn Info::_get_texture_memory_size(
  self : Info,
  texture : @core.Texture,
) -> Double {
  ignore(self)
  if texture.is_compressed_texture() {
    return 1.0 // Fallback estimate since exact format decompressed isn't readily available without format maps
  }
  let type_ = texture.type_
  let mut bytes_per_channel = 1.0
  if type_ == @core.ByteType || type_ == @core.UnsignedByteType {
    bytes_per_channel = 1.0
  } else if type_ == @core.ShortType ||
    type_ == @core.UnsignedShortType ||
    type_ == @core.HalfFloatType {
    bytes_per_channel = 2.0
  } else if type_ == @core.IntType ||
    type_ == @core.UnsignedIntType ||
    type_ == @core.FloatType {
    bytes_per_channel = 4.0
  }
  let format = texture.format
  let mut channels = 4.0 // RGBA default
  if format == @core.AlphaFormat ||
    format == @core.RedFormat ||
    format == @core.RedIntegerFormat ||
    format == @core.DepthFormat ||
    format == @core.DepthStencilFormat {
    channels = 1.0
  } else if format == @core.RGFormat || format == @core.RGIntegerFormat {
    channels = 2.0
  } else if format == @core.RGBFormat || format == @core.RGBIntegerFormat {
    channels = 3.0
  }
  let mut bytes_per_pixel = bytes_per_channel * channels
  if type_ == @core.UnsignedShort4444Type ||
    type_ == @core.UnsignedShort5551Type {
    bytes_per_pixel = 2.0
  } else if type_ == @core.UnsignedInt248Type ||
    type_ == @core.UnsignedInt5999Type ||
    type_ == @core.UnsignedInt101111Type {
    bytes_per_pixel = 4.0
  }
  let width = _info_or_one(texture.width())
  let height = _info_or_one(texture.height())
  let depth = if texture.is_cube_texture() {
    6.0
  } else {
    _info_or_one(texture.depth())
  }
  let mut size = width * height * depth * bytes_per_pixel
  let mipmaps = texture.mipmaps
  if mipmaps.length() > 0 {
    let mut mipmap_size = 0.0
    for i, mipmap in mipmaps {
      match mipmap {
        DataImage({ data: Some(data), .. }) =>
          mipmap_size += data.byte_length().to_double()
        _ => {
          let w = mipmap.width()
          let h = mipmap.height()
          let mip_width = if w == 0.0 || w.is_nan() {
            _info_max1(width.to_int() >> i)
          } else {
            w
          }
          let mip_height = if h == 0.0 || h.is_nan() {
            _info_max1(height.to_int() >> i)
          } else {
            h
          }
          mipmap_size += mip_width * mip_height * depth * bytes_per_pixel
        }
      }
    }
    size += mipmap_size
  } else if texture.generate_mipmaps {
    size = size * 1.333 // MiP chain approximation
  }
  info_math_round(size)
}

///|
/// `_getAttributeMemorySize( attribute )`.
pub fn Info::_get_attribute_memory_size(
  self : Info,
  attribute : AttributeBuffer,
) -> Double {
  ignore(self)
  match attribute {
    Buffer(a) => a.array.byte_length().to_double()
    Interleaved(a) => a.array.byte_length().to_double()
    GL(a) =>
      if a.count != 0 && a.item_size != 0 {
        (a.count * a.item_size * 4).to_double() // Assume Float32
      } else {
        0.0
      }
  }
}

///|
/// `Math.max( 1, x )`.
fn _info_max1(x : Int32) -> Double {
  (if x > 1 { x } else { 1 }).to_double()
}
