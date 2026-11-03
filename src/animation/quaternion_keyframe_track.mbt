// Upstream src/animation/tracks/QuaternionKeyframeTrack.js: linear interpolation slerps,
// smooth interpolation is unsupported.

///|
/// Namespace for the constructor; the value is a plain `KeyframeTrack`.
#external
pub type QuaternionKeyframeTrack

///|
pub fn[T : @core.TypedArrayInit, V : @core.TypedArrayInit] QuaternionKeyframeTrack::new(
  name : String,
  times : T,
  values : V,
  interpolation? : Int32,
) -> KeyframeTrack {
  keyframe_track_make(
    QuaternionTrack,
    name,
    to_float32(times),
    Numbers(to_float32(values)),
    interpolation,
  )
}
