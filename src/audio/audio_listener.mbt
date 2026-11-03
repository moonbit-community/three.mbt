// Upstream src/audio/AudioListener.js. The listener's `Object3D` is `object`; its
// extension is the listener itself, so `updateMatrixWorld` runs through core's hook.

///|
let _audio_listener_position : @math.Vector3 = @math.Vector3::new(0, 0, 0)

///|
let _audio_listener_quaternion : @math.Quaternion = @math.Quaternion::new(
  0, 0, 0, 1,
)

///|
let _audio_listener_scale : @math.Vector3 = @math.Vector3::new(0, 0, 0)

///|
let _audio_listener_forward : @math.Vector3 = @math.Vector3::new(0, 0, 0)

///|
let _audio_listener_up : @math.Vector3 = @math.Vector3::new(0, 0, 0)

///|
/// The virtual listener of all audio in the scene; add `object` to the camera.
pub(all) struct AudioListener {
  object : @core.Object3D
  context : AudioContext
  gain : GainNode
  mut filter : AudioNode?
  mut time_delta : Double
  _timer : @core.Timer
}

///|
pub fn AudioListener::new() -> AudioListener {
  let object = @core.Object3D::new()
  let context = AudioContext::get_context()
  let gain = context.create_gain()
  gain.as_node().connect(context.destination())
  let listener : AudioListener = {
    object,
    context,
    gain,
    filter: None,
    time_delta: 0,
    _timer: @core.Timer::new(),
  }
  ignore(object.set_extension(listener))
  listener
}

///|
/// The listener whose `object` this is, if any.
pub fn AudioListener::from_object(object : @core.Object3D) -> AudioListener? {
  match object.extension {
    Some(extension) if extension.has_flag("isAudioListener") =>
      Some(extension.payload().cast())
    _ => None
  }
}

///|
pub fn AudioListener::get_input(self : AudioListener) -> GainNode {
  self.gain
}

///|
pub fn AudioListener::remove_filter(self : AudioListener) -> AudioListener {
  if self.filter is Some(filter) {
    self.gain.as_node().disconnect(filter)
    filter.disconnect(self.context.destination())
    self.gain.as_node().connect(self.context.destination())
    self.filter = None
  }
  self
}

///|
pub fn AudioListener::get_filter(self : AudioListener) -> AudioNode? {
  self.filter
}

///|
pub fn AudioListener::set_filter(
  self : AudioListener,
  value : AudioNode,
) -> AudioListener {
  match self.filter {
    Some(filter) => {
      self.gain.as_node().disconnect(filter)
      filter.disconnect(self.context.destination())
    }
    None => self.gain.as_node().disconnect(self.context.destination())
  }
  self.filter = Some(value)
  self.gain.as_node().connect(value)
  value.connect(self.context.destination())
  self
}

///|
pub fn AudioListener::get_master_volume(self : AudioListener) -> Double {
  self.gain.gain().value()
}

///|
pub fn AudioListener::set_master_volume(
  self : AudioListener,
  value : Double,
) -> AudioListener {
  self.gain.gain().set_target_at_time(value, self.context.current_time(), 0.01)
  self
}

///|
/// `listener.updateMatrixWorld( force )`; the same as `self.object.update_matrix_world`.
pub fn AudioListener::update_matrix_world(
  self : AudioListener,
  force~ : Bool = false,
) -> Unit {
  self.object.update_matrix_world(force~)
}

///|
fn AudioListener::update_matrix_world_override(
  self : AudioListener,
  object : @core.Object3D,
  force : Bool,
) -> Unit {
  object.update_matrix_world_kind(force)
  ignore(self._timer.update())
  let listener = self.context.listener()
  self.time_delta = self._timer.get_delta()
  ignore(
    object.matrix_world.decompose(
      _audio_listener_position, _audio_listener_quaternion, _audio_listener_scale,
    ),
  )
  // the initial forward and up directions must be orthogonal
  ignore(
    _audio_listener_forward
    .set(0, 0, -1)
    .apply_quaternion(_audio_listener_quaternion),
  )
  ignore(
    _audio_listener_up.set(0, 1, 0).apply_quaternion(_audio_listener_quaternion),
  )
  if listener.has_position_x() {
    // code path for Chrome (see #14393)
    let end_time = self.context.current_time() + self.time_delta
    listener
    .position_x()
    .linear_ramp_to_value_at_time(_audio_listener_position.x, end_time)
    listener
    .position_y()
    .linear_ramp_to_value_at_time(_audio_listener_position.y, end_time)
    listener
    .position_z()
    .linear_ramp_to_value_at_time(_audio_listener_position.z, end_time)
    listener
    .forward_x()
    .linear_ramp_to_value_at_time(_audio_listener_forward.x, end_time)
    listener
    .forward_y()
    .linear_ramp_to_value_at_time(_audio_listener_forward.y, end_time)
    listener
    .forward_z()
    .linear_ramp_to_value_at_time(_audio_listener_forward.z, end_time)
    listener.up_x().linear_ramp_to_value_at_time(_audio_listener_up.x, end_time)
    listener.up_y().linear_ramp_to_value_at_time(_audio_listener_up.y, end_time)
    listener.up_z().linear_ramp_to_value_at_time(_audio_listener_up.z, end_time)
  } else {
    listener.set_position(
      _audio_listener_position.x,
      _audio_listener_position.y,
      _audio_listener_position.z,
    )
    listener.set_orientation(
      _audio_listener_forward.x,
      _audio_listener_forward.y,
      _audio_listener_forward.z,
      _audio_listener_up.x,
      _audio_listener_up.y,
      _audio_listener_up.z,
    )
  }
}

///|
impl @core.Object3DExtension for AudioListener with fn type_name(_) {
  "AudioListener"
}

///|
impl @core.Object3DExtension for AudioListener with fn construct(_) {
  AudioListener::new().object
}

///|
impl @core.Object3DExtension for AudioListener with fn has_flag(_, flag) {
  flag == "isAudioListener"
}

///|
impl @core.Object3DExtension for AudioListener with fn update_matrix_world(
  self,
  object,
  force,
) {
  self.update_matrix_world_override(object, force)
}
