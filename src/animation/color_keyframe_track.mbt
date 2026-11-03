// Upstream src/animation/tracks/ColorKeyframeTrack.js.

///|
/// Namespace for the constructor; the value is a plain `KeyframeTrack`.
#external
pub type ColorKeyframeTrack

///|
pub fn[T : @core.TypedArrayInit, V : @core.TypedArrayInit] ColorKeyframeTrack::new(
  name : String,
  times : T,
  values : V,
  interpolation? : Int32,
) -> KeyframeTrack {
  keyframe_track_make(
    ColorTrack,
    name,
    to_float32(times),
    Numbers(to_float32(values)),
    interpolation,
  )
}
