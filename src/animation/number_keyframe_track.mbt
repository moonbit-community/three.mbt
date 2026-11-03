// Upstream src/animation/tracks/NumberKeyframeTrack.js.

///|
/// Namespace for the constructor; the value is a plain `KeyframeTrack`.
#external
pub type NumberKeyframeTrack

///|
pub fn[T : @core.TypedArrayInit, V : @core.TypedArrayInit] NumberKeyframeTrack::new(
  name : String,
  times : T,
  values : V,
  interpolation? : Int32,
) -> KeyframeTrack {
  keyframe_track_make(
    NumberTrack,
    name,
    to_float32(times),
    Numbers(to_float32(values)),
    interpolation,
  )
}
