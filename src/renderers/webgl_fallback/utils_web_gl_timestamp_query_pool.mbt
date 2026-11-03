// renderers/webgl-fallback/utils/WebGLTimestampQueryPool.js: GPU timer queries
// (`EXT_disjoint_timer_query_webgl2`), a subclass of the common `TimestampQueryPool`.
// `WebGLTimestampQueryPool::new` returns the common pool; `of` recovers this payload for
// `beginQuery` / `endQuery`. Promises are callbacks: `resolveQuery` is a small future
// that settles as soon as the query result is available.

///|
/// `queryStates` values.
#derive(Eq)
pub(all) enum WebGLQueryState {
  Inactive
  Started
  Ended
}

///|
/// WebGLTimestampQueryPool's own instance fields.
pub(all) struct WebGLTimestampQueryPool {
  /// The common pool this payload belongs to (`this` for base members).
  mut base : @nodes.TimestampQueryPool
  gl : @webgl.WebGL2RenderingContext
  type_ : String
  /// `ext`; `None` when timer queries are unsupported.
  ext : @webgl.GLExtension?
  mut queries : Array[@webgl.GLQuery]
  /// `activeQuery`; `None` is `null`.
  mut active_query : Int32?
  /// `queryStates`: base offset -> state, a `Map` in insertion order.
  query_states : Map[Int32, WebGLQueryState]
}

///|
priv struct WebGLTimestampQueryPoolUnset {}

///|
impl @nodes.TimestampQueryPoolClass for WebGLTimestampQueryPoolUnset

///|
/// `new WebGLTimestampQueryPool( gl, type, maxQueries = 2048 )`.
pub fn WebGLTimestampQueryPool::new(
  gl : @webgl.WebGL2RenderingContext,
  type_ : String,
  max_queries~ : Int32 = 2048,
) -> @nodes.TimestampQueryPool {
  let base = @nodes.TimestampQueryPool::new(max_queries~, class_=WebGLTimestampQueryPoolUnset::{
  })
  // Check for timer query extensions
  let ext = match gl.get_extension("EXT_disjoint_timer_query_webgl2") {
    Some(e) => Some(e)
    None => gl.get_extension("EXT_disjoint_timer_query")
  }
  let payload : WebGLTimestampQueryPool = {
    base,
    gl,
    type_,
    ext,
    queries: [],
    active_query: None,
    query_states: Map([]),
  }
  base.class_ = payload
  _webgl_timestamp_pools.set(base, payload)
  if ext is None {
    @core.warn(
      "EXT_disjoint_timer_query not supported; timestamps will be disabled.",
    )
    base.track_timestamp = false
    return base
  }
  // Create query objects
  for _ in 0..<base.max_queries {
    payload.queries.push(gl.create_query())
  }
  base
}

///|
/// The payloads of the pools made by `WebGLTimestampQueryPool::new`.
let _webgl_timestamp_pools : @webgl.WeakMap[
  @nodes.TimestampQueryPool,
  WebGLTimestampQueryPool,
] = @webgl.WeakMap::new()

///|
/// The WebGL payload of a pool made by `WebGLTimestampQueryPool::new`.
pub fn WebGLTimestampQueryPool::of(
  pool : @nodes.TimestampQueryPool,
) -> WebGLTimestampQueryPool? {
  _webgl_timestamp_pools.get(pool)
}

///|
pub impl @nodes.TimestampQueryPoolClass for WebGLTimestampQueryPool with fn allocate_queries_for_context(
  self,
  base,
  uid,
) {
  if !base.track_timestamp {
    return None
  }
  if base.current_query_index + 2 > base.max_queries {
    self.resolve_queries_async(base, fn(_) {  })
    base.current_query_index = 0
    base.query_offsets.clear()
    self.query_states.clear()
    self.active_query = None
  }
  let base_offset = base.current_query_index
  base.current_query_index += 2
  // Initialize query states
  self.query_states.set(base_offset, Inactive)
  base.query_offsets.set(uid, base_offset)
  Some(base_offset)
}

///|
/// `beginQuery( uid )`.
pub fn WebGLTimestampQueryPool::begin_query(
  self : WebGLTimestampQueryPool,
  uid : String,
) -> Unit {
  let base = self.base
  if !base.track_timestamp || base.is_disposed {
    return
  }
  let base_offset = match base.query_offsets.get(uid) {
    Some(o) => o
    None => return
  }
  // Don't start a new query if there's an active one
  if self.active_query is Some(_) {
    return
  }
  if base_offset < 0 || base_offset >= self.queries.length() {
    return
  }
  let query = self.queries[base_offset]
  let err = @webgl.js_try(fn() {
    // Only begin if query is inactive
    if self.query_states.get(base_offset) == Some(Inactive) {
      self.gl.begin_query(self.ext.unwrap().constant("TIME_ELAPSED_EXT"), query)
      self.active_query = Some(base_offset)
      self.query_states.set(base_offset, Started)
    }
  })
  if err is Some(e) {
    @core.error("Error in beginQuery: " + e)
    self.active_query = None
    self.query_states.set(base_offset, Inactive)
  }
}

///|
/// `endQuery( uid )`.
pub fn WebGLTimestampQueryPool::end_query(
  self : WebGLTimestampQueryPool,
  uid : String,
) -> Unit {
  let base = self.base
  if !base.track_timestamp || base.is_disposed {
    return
  }
  let base_offset = match base.query_offsets.get(uid) {
    Some(o) => o
    None => return
  }
  // Only end if this is the active query
  if self.active_query != Some(base_offset) {
    return
  }
  let err = @webgl.js_try(fn() {
    self.gl.end_query(self.ext.unwrap().constant("TIME_ELAPSED_EXT"))
    self.query_states.set(base_offset, Ended)
    self.active_query = None
  })
  if err is Some(e) {
    @core.error("Error in endQuery: " + e)
    // Reset state on error
    self.query_states.set(base_offset, Inactive)
    self.active_query = None
  }
}

///|
/// The promise of `resolveQuery( query )`.
priv struct WebGLQueryFuture {
  mut value : Double?
  waiters : Array[(Double) -> Unit]
}

///|
fn WebGLQueryFuture::resolve(self : WebGLQueryFuture, value : Double) -> Unit {
  if self.value is Some(_) {
    return
  }
  self.value = Some(value)
  for w in self.waiters {
    w(value)
  }
  self.waiters.clear()
}

///|
fn WebGLQueryFuture::then(
  self : WebGLQueryFuture,
  f : (Double) -> Unit,
) -> Unit {
  match self.value {
    Some(v) => f(v)
    None => self.waiters.push(f)
  }
}

///|
extern "js" fn _webgl_timestamp_frame_of(uid : String) -> Int32 = "(uid) => { const match = uid.match( /^(.*):f([0-9]+)$/ ); return parseInt( match[ 2 ] ); }"

///|
extern "js" fn _webgl_timestamp_number(value : @core.JsValue) -> Double = "(v) => Number( v ) / 1e6"

///|
pub impl @nodes.TimestampQueryPoolClass for WebGLTimestampQueryPool with fn resolve_queries_async(
  self,
  base,
  on_done,
) {
  if !base.track_timestamp || base.pending_resolve {
    on_done(Some(base.last_value))
    return
  }
  base.pending_resolve = true
  // Wait for all ended queries to complete
  let resolve_promises : Array[(String, WebGLQueryFuture)] = []
  for uid, base_offset in base.query_offsets {
    let state = self.query_states.get(base_offset)
    if state == Some(Ended) {
      let query = self.queries[base_offset]
      resolve_promises.push((uid, self.resolve_query(query)))
    }
  }
  if resolve_promises.length() == 0 {
    base.pending_resolve = false
    on_done(Some(base.last_value))
    return
  }
  //
  let frames_duration : Map[Int32, Double] = Map([])
  let frames : Array[Int32] = []
  base.timestamps.clear()
  fn step(i : Int32) -> Unit {
    if i == resolve_promises.length() {
      // Return the total duration of the last frame
      let total_duration = frames_duration
        .get(frames[frames.length() - 1])
        .unwrap()
      // Store the last valid result
      base.last_value = total_duration
      base.frames = frames
      // Reset states
      base.current_query_index = 0
      base.query_offsets.clear()
      self.query_states.clear()
      self.active_query = None
      base.pending_resolve = false
      on_done(Some(total_duration))
      return
    }
    let (uid, promise) = resolve_promises[i]
    let frame = _webgl_timestamp_frame_of(uid)
    if !frames.contains(frame) {
      frames.push(frame)
    }
    if !frames_duration.contains(frame) {
      frames_duration.set(frame, 0.0)
    }
    promise.then(fn(duration) {
      base.timestamps.set(uid, duration)
      frames_duration.set(frame, frames_duration.get(frame).unwrap() + duration)
      step(i + 1)
    })
  }
  step(0)
}

///|
/// `resolveQuery( query )`: settles with the elapsed time in milliseconds (or the last
/// value when the timer was disjoint or the pool disposed).
fn WebGLTimestampQueryPool::resolve_query(
  self : WebGLTimestampQueryPool,
  query : @webgl.GLQuery,
) -> WebGLQueryFuture {
  let future = { value: None, waiters: [], }
  let base = self.base
  if base.is_disposed {
    future.resolve(base.last_value)
    return future
  }
  let check_query : Ref[() -> Unit] = Ref(fn() {  })
  check_query.val = fn() {
    if base.is_disposed {
      future.resolve(base.last_value)
      return
    }
    let err = @webgl.js_try(fn() {
      // Check if the GPU timer was disjoint (i.e., timing was unreliable)
      let disjoint = self.gl.get_parameter(
        self.ext.unwrap().constant("GPU_DISJOINT_EXT"),
      )
      if @webgl.js_truthy(disjoint) {
        future.resolve(base.last_value)
        return
      }
      let available = self.gl.get_query_parameter(
        query,
        @webgl.GL_QUERY_RESULT_AVAILABLE,
      )
      if !@webgl.js_truthy(available) {
        @webgl.set_timeout(check_query.val, 1.0)
        return
      }
      let elapsed = self.gl.get_query_parameter(query, @webgl.GL_QUERY_RESULT)
      future.resolve(_webgl_timestamp_number(elapsed)) // Convert nanoseconds to milliseconds
    })
    if err is Some(e) {
      @core.error("Error checking query: " + e)
      future.resolve(base.last_value)
    }
  }
  (check_query.val)()
  future
}

///|
pub impl @nodes.TimestampQueryPoolClass for WebGLTimestampQueryPool with fn dispose(
  self,
  base,
) {
  if base.is_disposed {
    return
  }
  base.is_disposed = true
  if !base.track_timestamp {
    return
  }
  for query in self.queries {
    self.gl.delete_query(query)
  }
  self.queries = []
  self.query_states.clear()
  base.query_offsets.clear()
  base.timestamps.clear()
  base.frames = []
  base.last_value = 0.0
  self.active_query = None
}
