// Upstream src/animation/tracks/VectorKeyframeTrack.js.

///|
/// Namespace for the constructor; the value is a plain `KeyframeTrack`.
#external
pub type VectorKeyframeTrack

///|
pub fn[T : @core.TypedArrayInit, V : @core.TypedArrayInit] VectorKeyframeTrack::new(
  name : String,
  times : T,
  values : V,
  interpolation? : Int32,
) -> KeyframeTrack {
  keyframe_track_make(
    VectorTrack,
    name,
    to_float32(times),
    Numbers(to_float32(values)),
    interpolation,
  )
}
