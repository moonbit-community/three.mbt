// Upstream src/animation/tracks/BooleanKeyframeTrack.js: discrete only, with values kept in
// a plain array.

///|
/// Namespace for the constructor; the value is a plain `KeyframeTrack`.
#external
pub type BooleanKeyframeTrack

///|
/// Upstream's constructor takes no interpolation.
pub fn[T : @core.TypedArrayInit] BooleanKeyframeTrack::new(
  name : String,
  times : T,
  values : Array[Bool],
) -> KeyframeTrack {
  keyframe_track_make(
    BooleanTrack,
    name,
    to_float32(times),
    Booleans(values),
    None,
  )
}
