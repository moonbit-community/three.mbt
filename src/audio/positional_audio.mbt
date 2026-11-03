// Upstream src/audio/PositionalAudio.js. A positional audio is an `Audio` whose `panner`
// is set; its `connect`, `disconnect` and `getOutput` overrides are in audio.mbt.

///|
let _positional_audio_position : @math.Vector3 = @math.Vector3::new(0, 0, 0)

///|
let _positional_audio_quaternion : @math.Quaternion = @math.Quaternion::new(
  0, 0, 0, 1,
)

///|
let _positional_audio_scale : @math.Vector3 = @math.Vector3::new(0, 0, 0)

///|
let _positional_audio_orientation : @math.Vector3 = @math.Vector3::new(0, 0, 0)

///|
/// Namespace for the constructor; the value is an `Audio` with a `panner`.
#external
pub type PositionalAudio

///|
pub fn PositionalAudio::new(listener : AudioListener) -> Audio {
  audio_new(listener, true)
}

///|
fn Audio::panner_node(self : Audio) -> PannerNode {
  match self.panner {
    Some(panner) => panner
    None => abort("PositionalAudio method called on a non-positional Audio")
  }
}

///|
pub fn Audio::get_ref_distance(self : Audio) -> Double {
  self.panner_node().ref_distance()
}

///|
pub fn Audio::set_ref_distance(self : Audio, value : Double) -> Audio {
  self.panner_node().set_ref_distance(value)
  self
}

///|
pub fn Audio::get_rolloff_factor(self : Audio) -> Double {
  self.panner_node().rolloff_factor()
}

///|
pub fn Audio::set_rolloff_factor(self : Audio, value : Double) -> Audio {
  self.panner_node().set_rolloff_factor(value)
  self
}

///|
/// `'linear'`, `'inverse'` or `'exponential'`.
pub fn Audio::get_distance_model(self : Audio) -> String {
  self.panner_node().distance_model()
}

///|
pub fn Audio::set_distance_model(self : Audio, value : String) -> Audio {
  self.panner_node().set_distance_model(value)
  self
}

///|
pub fn Audio::get_max_distance(self : Audio) -> Double {
  self.panner_node().max_distance()
}

///|
pub fn Audio::set_max_distance(self : Audio, value : Double) -> Audio {
  self.panner_node().set_max_distance(value)
  self
}

///|
pub fn Audio::set_directional_cone(
  self : Audio,
  cone_inner_angle : Double,
  cone_outer_angle : Double,
  cone_outer_gain : Double,
) -> Audio {
  let panner = self.panner_node()
  panner.set_cone_inner_angle(cone_inner_angle)
  panner.set_cone_outer_angle(cone_outer_angle)
  panner.set_cone_outer_gain(cone_outer_gain)
  self
}

///|
/// PositionalAudio's `updateMatrixWorld` after `super.updateMatrixWorld( force )`.
fn Audio::update_panner(
  self : Audio,
  object : @core.Object3D,
  panner : PannerNode,
) -> Unit {
  if self.has_playback_control && !self.is_playing {
    return
  }
  ignore(
    object.matrix_world.decompose(
      _positional_audio_position, _positional_audio_quaternion, _positional_audio_scale,
    ),
  )
  ignore(
    _positional_audio_orientation
    .set(0, 0, 1)
    .apply_quaternion(_positional_audio_quaternion),
  )
  if panner.has_position_x() {
    // code path for Chrome and Firefox (see #14393)
    let end_time = self.context.current_time() + self.listener.time_delta
    panner
    .position_x()
    .linear_ramp_to_value_at_time(_positional_audio_position.x, end_time)
    panner
    .position_y()
    .linear_ramp_to_value_at_time(_positional_audio_position.y, end_time)
    panner
    .position_z()
    .linear_ramp_to_value_at_time(_positional_audio_position.z, end_time)
    panner
    .orientation_x()
    .linear_ramp_to_value_at_time(_positional_audio_orientation.x, end_time)
    panner
    .orientation_y()
    .linear_ramp_to_value_at_time(_positional_audio_orientation.y, end_time)
    panner
    .orientation_z()
    .linear_ramp_to_value_at_time(_positional_audio_orientation.z, end_time)
  } else {
    panner.set_position(
      _positional_audio_position.x,
      _positional_audio_position.y,
      _positional_audio_position.z,
    )
    panner.set_orientation(
      _positional_audio_orientation.x,
      _positional_audio_orientation.y,
      _positional_audio_orientation.z,
    )
  }
}
