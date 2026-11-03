// renderers/webgpu/utils/WebGPUTimestampQueryPool.js: a `TimestampQueryPool` subclass
// (the payload of the base pool's `class_`) that resolves timestamp queries into a
// mappable buffer. `async` members take callbacks; `await` resumes on a later microtask
// as upstream does (`wgpu_await`).

///|
let _web_gpu_timestamp_query_pool_buffer_descriptor : @gpu.GPUBufferDescriptor = @gpu.GPUBufferDescriptor::default()

///|
let _web_gpu_timestamp_query_pool_command_encoder_descriptor : @gpu.GPUCommandEncoderDescriptor = @gpu.GPUCommandEncoderDescriptor::default()

///|
let _web_gpu_timestamp_query_pool_query_set_descriptor : @gpu.GPUQuerySetDescriptor = @gpu.GPUQuerySetDescriptor::default()

///|
/// `WebGPUTimestampQueryPool`.
pub(all) struct WebGPUTimestampQueryPool {
  /// The base `TimestampQueryPool` fields.
  mut pool_ : @nodes.TimestampQueryPool?
  device : @gpu.GPUDevice
  type_ : String
  /// `querySet`; `None` is `null` (after `dispose()`).
  mut query_set : @gpu.GPUQuerySet?
  mut resolve_buffer : @gpu.GPUBuffer?
  mut result_buffer : @gpu.GPUBuffer?
  /// The callers waiting on `pendingResolve`; `None` is `null`.
  mut _pending : Array[(Double?) -> Unit]?
}

///|
/// `new WebGPUTimestampQueryPool( device, type, maxQueries = 2048 )`: the base pool.
pub fn WebGPUTimestampQueryPool::new(
  device : @gpu.GPUDevice,
  type_ : String,
  max_queries~ : Int32 = 2048,
) -> @nodes.TimestampQueryPool {
  let payload : WebGPUTimestampQueryPool = {
    pool_: None,
    device,
    type_,
    query_set: None,
    resolve_buffer: None,
    result_buffer: None,
    _pending: None,
  }
  let pool = @nodes.TimestampQueryPool::new(max_queries~, class_=payload)
  payload.pool_ = Some(pool)
  _web_gpu_timestamp_query_pools.set(pool, payload)
  let qsd = _web_gpu_timestamp_query_pool_query_set_descriptor
  qsd.label = Some("queryset_global_timestamp_\{type_}")
  qsd.type_ = Some("timestamp")
  qsd.count = pool.max_queries
  payload.query_set = Some(device.create_query_set(qsd))
  qsd.reset()
  let buffer_size = pool.max_queries * 8
  let bd = _web_gpu_timestamp_query_pool_buffer_descriptor
  bd.label = Some("buffer_timestamp_resolve_\{type_}")
  bd.size = buffer_size
  bd.usage = @gpu.GPU_BUFFER_USAGE_QUERY_RESOLVE |
    @gpu.GPU_BUFFER_USAGE_COPY_SRC
  payload.resolve_buffer = Some(device.create_buffer(bd))
  bd.reset()
  bd.label = Some("buffer_timestamp_result_\{type_}")
  bd.size = buffer_size
  bd.usage = @gpu.GPU_BUFFER_USAGE_COPY_DST | @gpu.GPU_BUFFER_USAGE_MAP_READ
  payload.result_buffer = Some(device.create_buffer(bd))
  bd.reset()
  pool
}

///|
/// The payload of a pool built by `WebGPUTimestampQueryPool::new`.
pub fn WebGPUTimestampQueryPool::of(
  pool : @nodes.TimestampQueryPool,
) -> WebGPUTimestampQueryPool {
  _web_gpu_timestamp_query_pools.get(pool).unwrap()
}

///|
/// The payloads of the pools built by `WebGPUTimestampQueryPool::new`.
let _web_gpu_timestamp_query_pools : @webgl.WeakMap[
  @nodes.TimestampQueryPool,
  WebGPUTimestampQueryPool,
] = @webgl.WeakMap::new()

///|
fn WebGPUTimestampQueryPool::pool(
  self : WebGPUTimestampQueryPool,
) -> @nodes.TimestampQueryPool {
  self.pool_.unwrap()
}

///|
pub impl @nodes.TimestampQueryPoolClass for WebGPUTimestampQueryPool with fn allocate_queries_for_context(
  self,
  pool,
  uid,
) {
  if !pool.track_timestamp || pool.is_disposed {
    return None
  }
  if pool.current_query_index + 2 > pool.max_queries {
    self.resolve_queries(fn(_) {  })
    pool.current_query_index = 0
    pool.query_offsets.clear()
  }
  let base_offset = pool.current_query_index
  pool.current_query_index += 2
  pool.query_offsets[uid] = base_offset
  Some(base_offset)
}

///|
pub impl @nodes.TimestampQueryPoolClass for WebGPUTimestampQueryPool with fn resolve_queries_async(
  self,
  _pool,
  on_done,
) {
  self.resolve_queries(on_done)
}

///|
/// `resolveQueriesAsync()`.
fn WebGPUTimestampQueryPool::resolve_queries(
  self : WebGPUTimestampQueryPool,
  on_done : (Double?) -> Unit,
) -> Unit {
  let pool = self.pool()
  if !pool.track_timestamp || pool.current_query_index == 0 || pool.is_disposed {
    return on_done(Some(pool.last_value))
  }
  match self._pending {
    Some(callbacks) => return callbacks.push(on_done)
    None => ()
  }
  let callbacks = [on_done]
  self._pending = Some(callbacks)
  pool.pending_resolve = true
  self._resolve_queries(fn(result) {
    // finally
    self._pending = None
    pool.pending_resolve = false
    for f in callbacks {
      f(result)
    }
  })
}

///|
/// `( match = uid.match( /^(.*):f(\d+)$/ ) )[ 2 ]`, parsed.
fn _web_gpu_timestamp_query_pool_frame(uid : String) -> Int32 {
  let chars = uid.to_array()
  let mut i = chars.length() - 1
  while i >= 0 && chars[i] >= '0' && chars[i] <= '9' {
    i = i - 1
  }
  if i < 1 || i == chars.length() - 1 || chars[i] != 'f' || chars[i - 1] != ':' {
    abort("TypeError: Cannot read properties of null (reading '2')")
  }
  let mut frame = 0
  for j = i + 1; j < chars.length(); j = j + 1 {
    frame = frame * 10 + (chars[j].to_int() - '0'.to_int())
  }
  frame
}

///|
/// `_resolveQueries()`.
fn WebGPUTimestampQueryPool::_resolve_queries(
  self : WebGPUTimestampQueryPool,
  on_done : (Double?) -> Unit,
) -> Unit {
  let pool = self.pool()
  if pool.is_disposed {
    return on_done(Some(pool.last_value))
  }
  let result_buffer = self.result_buffer.unwrap()
  let on_error = fn(e : @core.JsValue) {
    @core.error("Error resolving queries: \{wgpu_js_string(e)}")
    if result_buffer.map_state() == "mapped" {
      result_buffer.unmap()
    }
    on_done(Some(pool.last_value))
  }
  if result_buffer.map_state() != "unmapped" {
    return on_done(Some(pool.last_value))
  }
  let current_offsets : Array[(String, Int32)] = []
  for uid, base_offset in pool.query_offsets {
    current_offsets.push((uid, base_offset))
  }
  let query_count = pool.current_query_index
  let bytes_used = query_count * 8
  // Reset state before GPU work
  pool.current_query_index = 0
  pool.query_offsets.clear()
  let command_encoder = self.device.create_command_encoder(
    descriptor=_web_gpu_timestamp_query_pool_command_encoder_descriptor,
  )
  command_encoder.resolve_query_set(
    self.query_set.unwrap(),
    0,
    query_count,
    self.resolve_buffer.unwrap(),
    0,
  )
  command_encoder.copy_buffer_to_buffer(
    self.resolve_buffer.unwrap(),
    0,
    result_buffer,
    0,
    bytes_used,
  )
  let command_buffer = command_encoder.finish()
  wgpu_submit(self.device, command_buffer)
  if result_buffer.map_state() != "unmapped" {
    return on_done(Some(pool.last_value))
  }
  // Create and track the mapping operation
  wgpu_await(
    result_buffer.map_async_promise(
      @gpu.GPU_MAP_MODE_READ,
      offset=0,
      size=bytes_used,
    ),
    fn(_) {
      if pool.is_disposed {
        if result_buffer.map_state() == "mapped" {
          result_buffer.unmap()
        }
        return on_done(Some(pool.last_value))
      }
      let times = result_buffer.get_mapped_range(offset=0, size=bytes_used)
      let frames_duration : Map[Int32, Double] = Map([])
      let frames : Array[Int32] = []
      pool.timestamps.clear()
      for entry in current_offsets {
        let (uid, base_offset) = entry
        let frame = _web_gpu_timestamp_query_pool_frame(uid)
        if !frames.contains(frame) {
          frames.push(frame)
        }
        if !frames_duration.contains(frame) {
          frames_duration[frame] = 0.0
        }
        let duration = @gpu.big_uint64_difference(
            times,
            base_offset,
            base_offset + 1,
          ) /
          1.0e6
        pool.timestamps[uid] = duration
        frames_duration[frame] = frames_duration[frame] + duration
      }
      // Return the total duration of the last frame
      let total_duration = frames_duration
        .get(frames[frames.length() - 1])
        .unwrap()
      result_buffer.unmap()
      pool.last_value = total_duration
      pool.frames = frames
      on_done(Some(total_duration))
    },
    on_error,
  )
}

///|
pub impl @nodes.TimestampQueryPoolClass for WebGPUTimestampQueryPool with fn dispose(
  self,
  pool,
) {
  if pool.is_disposed {
    return
  }
  pool.is_disposed = true
  let finish = fn() {
    // Ensure buffer is unmapped before destroying
    match self.result_buffer {
      Some(b) if b.map_state() == "mapped" => b.unmap()
      _ => ()
    }
    // Destroy resources
    match self.query_set {
      Some(q) => {
        q.destroy()
        self.query_set = None
      }
      None => ()
    }
    match self.resolve_buffer {
      Some(b) => {
        b.destroy()
        self.resolve_buffer = None
      }
      None => ()
    }
    match self.result_buffer {
      Some(b) => {
        b.destroy()
        self.result_buffer = None
      }
      None => ()
    }
    pool.query_offsets.clear()
    pool.timestamps.clear()
    pool.frames = []
    self._pending = None
    pool.pending_resolve = false
  }
  // Wait for pending resolve operation
  match self._pending {
    Some(callbacks) => callbacks.push(fn(_) { finish() })
    None => finish()
  }
}
