// renderers/common/TimestampQueryPool.js: the base of the backends' timestamp query
// pools; `allocateQueriesForContext`, `resolveQueriesAsync` and `dispose` are theirs.

///|
/// The overridable members of `TimestampQueryPool` subclasses.
pub(open) trait TimestampQueryPoolClass {
  /// `allocateQueriesForContext( uid )`: the query offset; `None` is `undefined`.
  fn allocate_queries_for_context(Self, TimestampQueryPool, String) -> Int32? = _
  /// `resolveQueriesAsync()`: calls back with the total duration.
  fn resolve_queries_async(Self, TimestampQueryPool, (Double?) -> Unit) -> Unit = _
  /// `dispose()`.
  fn dispose(Self, TimestampQueryPool) -> Unit = _
}

///|
impl TimestampQueryPoolClass with fn allocate_queries_for_context(_, _, _) {
  None
}

///|
impl TimestampQueryPoolClass with fn resolve_queries_async(_, _, on_done) {
  on_done(None)
}

///|
impl TimestampQueryPoolClass with fn dispose(_, _) {

}

///|
/// The class of a plain `new TimestampQueryPool()`.
priv struct BaseTimestampQueryPool {}

///|
impl TimestampQueryPoolClass for BaseTimestampQueryPool

///|
/// Timestamp queries of one kind (render or compute) and their results.
pub(all) struct TimestampQueryPool {
  mut class_ : &TimestampQueryPoolClass
  mut track_timestamp : Bool
  mut max_queries : Int32
  mut current_query_index : Int32
  query_offsets : Map[String, Int32]
  mut is_disposed : Bool
  mut last_value : Double
  /// The frame ids with resolved timestamps.
  mut frames : Array[Int32]
  mut pending_resolve : Bool
  timestamps : Map[String, Double]
}

///|
/// `new TimestampQueryPool( maxQueries = 256 )`; subclasses pass their class payload.
pub fn TimestampQueryPool::new(
  max_queries~ : Int32 = 256,
  class_? : &TimestampQueryPoolClass,
) -> TimestampQueryPool {
  {
    class_: match class_ {
      Some(c) => c
      None => BaseTimestampQueryPool::{ }
    },
    track_timestamp: true,
    max_queries,
    current_query_index: 0,
    query_offsets: Map([]),
    is_disposed: false,
    last_value: 0.0,
    frames: [],
    pending_resolve: false,
    timestamps: Map([]),
  }
}

///|
/// `getTimestampFrames()`.
pub fn TimestampQueryPool::get_timestamp_frames(
  self : TimestampQueryPool,
) -> Array[Int32] {
  self.frames
}

///|
/// `getTimestamp( uid )`: the duration, or 0 with a warning when there is none.
pub fn TimestampQueryPool::get_timestamp(
  self : TimestampQueryPool,
  uid : String,
) -> Double {
  match self.timestamps.get(uid) {
    Some(timestamp) => timestamp
    None => {
      @core.warn("TimestampQueryPool: No timestamp available for uid \{uid}.")
      0.0
    }
  }
}

///|
/// `hasTimestampQuery( uid )`.
pub fn TimestampQueryPool::has_timestamp_query(
  self : TimestampQueryPool,
  uid : String,
) -> Bool {
  self.timestamps.contains(uid)
}

///|
/// `allocateQueriesForContext( uid )`.
pub fn TimestampQueryPool::allocate_queries_for_context(
  self : TimestampQueryPool,
  uid : String,
) -> Int32? {
  self.class_.allocate_queries_for_context(self, uid)
}

///|
/// `resolveQueriesAsync()`.
pub fn TimestampQueryPool::resolve_queries_async(
  self : TimestampQueryPool,
  on_done : (Double?) -> Unit,
) -> Unit {
  self.class_.resolve_queries_async(self, on_done)
}

///|
/// `dispose()`.
pub fn TimestampQueryPool::dispose(self : TimestampQueryPool) -> Unit {
  self.class_.dispose(self)
}
