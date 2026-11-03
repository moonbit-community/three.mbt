// Upstream src/animation/tracks/StringKeyframeTrack.js: discrete only, with values kept in
// a plain array.

///|
/// Namespace for the constructor; the value is a plain `KeyframeTrack`.
#external
pub type StringKeyframeTrack

///|
/// Upstream's constructor takes no interpolation.
pub fn[T : @core.TypedArrayInit] StringKeyframeTrack::new(
  name : String,
  times : T,
  values : Array[String],
) -> KeyframeTrack {
  keyframe_track_make(
    StringTrack,
    name,
    to_float32(times),
    Strings(values),
    None,
  )
}
