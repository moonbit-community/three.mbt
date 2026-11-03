// Upstream src/audio/Audio.js. `Audio` is also upstream's PositionalAudio when `panner` is
// set (see positional_audio.mbt); the overrides `connect`, `disconnect`, `getOutput` and
// `updateMatrixWorld` dispatch on it. The `Object3D` is `object`; its extension is the
// audio itself, so `copy`, `clone` and `updateMatrixWorld` run through core's hook.

///|
/// A non-positional audio source, or a positional one from `PositionalAudio::new`.
pub(all) struct Audio {
  object : @core.Object3D
  listener : AudioListener
  context : AudioContext
  gain : GainNode
  mut autoplay : Bool
  mut buffer : AudioBuffer?
  mut detune : Double
  mut loop_ : Bool
  mut loop_start : Double
  mut loop_end : Double
  mut offset : Double
  /// `undefined` upstream: play to the end of the buffer.
  mut duration : Double?
  mut playback_rate : Double
  mut is_playing : Bool
  mut has_playback_control : Bool
  mut source : AudioNode?
  /// `"empty"`, `"audioNode"`, `"mediaNode"`, `"mediaStreamNode"` or `"buffer"`.
  mut source_type : String
  mut _started_at : Double
  mut _progress : Double
  mut _connected : Bool
  mut filters : Array[AudioNode]
  /// PositionalAudio's `panner`; `None` for a plain `Audio`.
  panner : PannerNode?
}

///|
/// Upstream's constructor; `positional` adds PositionalAudio's panner.
fn audio_new(listener : AudioListener, positional : Bool) -> Audio {
  let object = @core.Object3D::new()
  let context = listener.context
  let gain = context.create_gain()
  gain.as_node().connect(listener.get_input().as_node())
  let panner = if positional {
    let panner = context.create_panner()
    panner.set_panning_model("HRTF")
    panner.as_node().connect(gain.as_node())
    Some(panner)
  } else {
    None
  }
  let audio : Audio = {
    object,
    listener,
    context,
    gain,
    autoplay: false,
    buffer: None,
    detune: 0,
    loop_: false,
    loop_start: 0,
    loop_end: 0,
    offset: 0,
    duration: None,
    playback_rate: 1,
    is_playing: false,
    has_playback_control: true,
    source: None,
    source_type: "empty",
    _started_at: 0,
    _progress: 0,
    _connected: false,
    filters: [],
    panner,
  }
  ignore(object.set_extension(audio))
  audio
}

///|
pub fn Audio::new(listener : AudioListener) -> Audio {
  audio_new(listener, false)
}

///|
/// The audio whose `object` this is, if any.
pub fn Audio::from_object(object : @core.Object3D) -> Audio? {
  match object.extension {
    Some(extension) if extension.has_flag("isAudio") =>
      Some(extension.payload().cast())
    _ => None
  }
}

///|
/// The gain node, or the panner of a positional audio.
pub fn Audio::get_output(self : Audio) -> AudioNode {
  match self.panner {
    Some(panner) => panner.as_node()
    None => self.gain.as_node()
  }
}

///|
pub fn Audio::set_node_source(self : Audio, audio_node : AudioNode) -> Audio {
  self.has_playback_control = false
  self.source_type = "audioNode"
  self.source = Some(audio_node)
  self.connect()
}

///|
/// `media_element` is an `HTMLMediaElement`.
pub fn Audio::set_media_element_source(
  self : Audio,
  media_element : @core.JsValue,
) -> Audio {
  self.has_playback_control = false
  self.source_type = "mediaNode"
  self.source = Some(self.context.create_media_element_source(media_element))
  self.connect()
}

///|
/// `media_stream` is a `MediaStream`.
pub fn Audio::set_media_stream_source(
  self : Audio,
  media_stream : @core.JsValue,
) -> Audio {
  self.has_playback_control = false
  self.source_type = "mediaStreamNode"
  self.source = Some(self.context.create_media_stream_source(media_stream))
  self.connect()
}

///|
pub fn Audio::set_buffer(self : Audio, audio_buffer : AudioBuffer) -> Audio {
  self.buffer = Some(audio_buffer)
  self.source_type = "buffer"
  if self.autoplay {
    ignore(self.play())
  }
  self
}

///|
fn Audio::buffer_source(self : Audio) -> AudioBufferSourceNode {
  self.source.unwrap().as_buffer_source()
}

///|
/// Starts playback after `delay` seconds; warns and does nothing if it cannot.
pub fn Audio::play(self : Audio, delay~ : Double = 0) -> Audio {
  if self.is_playing {
    @core.warn("Audio: Audio is already playing.")
    return self
  }
  if !self.has_playback_control {
    @core.warn("Audio: this Audio has no playback control.")
    return self
  }
  self._started_at = self.context.current_time() + delay
  let source = self.context.create_buffer_source()
  source.set_buffer(self.buffer)
  source.set_loop(self.loop_)
  source.set_loop_start(self.loop_start)
  source.set_loop_end(self.loop_end)
  source.set_onended(() => self.on_ended())
  source.start(
    self._started_at,
    self._progress + self.offset,
    duration?=self.duration,
  )
  self.is_playing = true
  self.source = Some(source.as_node())
  ignore(self.set_detune(self.detune))
  ignore(self.set_playback_rate(self.playback_rate))
  self.connect()
}

///|
pub fn Audio::pause(self : Audio) -> Audio {
  if !self.has_playback_control {
    @core.warn("Audio: this Audio has no playback control.")
    return self
  }
  if self.is_playing {
    // update current progress
    self._progress += web_audio_math_max(
        self.context.current_time() - self._started_at,
        0,
      ) *
      self.playback_rate
    if self.loop_ {
      // ensure _progress does not exceed duration with looped audios
      let duration = match self.duration {
        Some(duration) if web_audio_truthy(duration) => duration
        _ => self.buffer.unwrap().duration()
      }
      self._progress = web_audio_remainder(self._progress, duration)
    }
    let source = self.buffer_source()
    source.stop()
    source.clear_onended()
    self.is_playing = false
  }
  self
}

///|
pub fn Audio::stop(self : Audio, delay~ : Double = 0) -> Audio {
  if !self.has_playback_control {
    @core.warn("Audio: this Audio has no playback control.")
    return self
  }
  self._progress = 0
  if self.source is Some(source) {
    let source = source.as_buffer_source()
    source.stop(when_=self.context.current_time() + delay)
    source.clear_onended()
  }
  self.is_playing = false
  self
}

///|
/// Connects the source through the filters to the output.
pub fn Audio::connect(self : Audio) -> Audio {
  let source = self.source.unwrap()
  let filters = self.filters
  if filters.length() > 0 {
    source.connect(filters[0])
    for i in 1..<filters.length() {
      filters[i - 1].connect(filters[i])
    }
    filters[filters.length() - 1].connect(self.get_output())
  } else {
    source.connect(self.get_output())
  }
  self._connected = true
  if self.panner is Some(panner) {
    panner.as_node().connect(self.gain.as_node())
  }
  self
}

///|
pub fn Audio::disconnect(self : Audio) -> Audio {
  if self._connected {
    let source = self.source.unwrap()
    let filters = self.filters
    if filters.length() > 0 {
      source.disconnect(filters[0])
      for i in 1..<filters.length() {
        filters[i - 1].disconnect(filters[i])
      }
      filters[filters.length() - 1].disconnect(self.get_output())
    } else {
      source.disconnect(self.get_output())
    }
    self._connected = false
  }
  // PositionalAudio disconnects its panner even when the source was not connected.
  if self.panner is Some(panner) {
    panner.as_node().disconnect(self.gain.as_node())
  }
  self
}

///|
pub fn Audio::get_filters(self : Audio) -> Array[AudioNode] {
  self.filters
}

///|
/// Sets the filter chain; `None` clears it.
pub fn Audio::set_filters(self : Audio, value? : Array[AudioNode]) -> Audio {
  let value = match value {
    Some(value) => value
    None => []
  }
  if self._connected {
    ignore(self.disconnect())
    self.filters = value.copy()
    ignore(self.connect())
  } else {
    self.filters = value.copy()
  }
  self
}

///|
pub fn Audio::set_detune(self : Audio, value : Double) -> Audio {
  self.detune = value
  if self.is_playing && self.buffer_source().has_detune() {
    self
    .buffer_source()
    .detune()
    .set_target_at_time(self.detune, self.context.current_time(), 0.01)
  }
  self
}

///|
pub fn Audio::get_detune(self : Audio) -> Double {
  self.detune
}

///|
pub fn Audio::get_filter(self : Audio) -> AudioNode? {
  self.get_filters().get(0)
}

///|
pub fn Audio::set_filter(self : Audio, filter? : AudioNode) -> Audio {
  self.set_filters(
    value=match filter {
      Some(filter) => [filter]
      None => []
    },
  )
}

///|
pub fn Audio::set_playback_rate(self : Audio, value : Double) -> Audio {
  if !self.has_playback_control {
    @core.warn("Audio: this Audio has no playback control.")
    return self
  }
  self.playback_rate = value
  if self.is_playing {
    self
    .buffer_source()
    .playback_rate()
    .set_target_at_time(self.playback_rate, self.context.current_time(), 0.01)
  }
  self
}

///|
pub fn Audio::get_playback_rate(self : Audio) -> Double {
  self.playback_rate
}

///|
/// The source's `onended` handler.
pub fn Audio::on_ended(self : Audio) -> Unit {
  self.is_playing = false
  self._progress = 0
}

///|
pub fn Audio::get_loop(self : Audio) -> Bool {
  if !self.has_playback_control {
    @core.warn("Audio: this Audio has no playback control.")
    return false
  }
  self.loop_
}

///|
pub fn Audio::set_loop(self : Audio, value : Bool) -> Audio {
  if !self.has_playback_control {
    @core.warn("Audio: this Audio has no playback control.")
    return self
  }
  self.loop_ = value
  if self.is_playing {
    self.buffer_source().set_loop(self.loop_)
  }
  self
}

///|
pub fn Audio::set_loop_start(self : Audio, value : Double) -> Audio {
  self.loop_start = value
  self
}

///|
pub fn Audio::set_loop_end(self : Audio, value : Double) -> Audio {
  self.loop_end = value
  self
}

///|
pub fn Audio::get_volume(self : Audio) -> Double {
  self.gain.gain().value()
}

///|
pub fn Audio::set_volume(self : Audio, value : Double) -> Audio {
  self.gain.gain().set_target_at_time(value, self.context.current_time(), 0.01)
  self
}

///|
/// `audio.copy( source, recursive )`; the same as `self.object.copy`.
pub fn Audio::copy(
  self : Audio,
  source : Audio,
  recursive~ : Bool = true,
) -> Audio {
  ignore(self.object.copy(source.object, recursive~))
  self
}

///|
/// `new this.constructor( this.listener ).copy( this, recursive )`.
pub fn Audio::clone(self : Audio, recursive~ : Bool = true) -> Audio {
  Audio::from_object(self.object.clone(recursive~)).unwrap()
}

///|
/// `audio.updateMatrixWorld( force )`; the same as `self.object.update_matrix_world`.
pub fn Audio::update_matrix_world(self : Audio, force~ : Bool = false) -> Unit {
  self.object.update_matrix_world(force~)
}

///|
/// Upstream `Audio.copy` after `super.copy`.
fn Audio::copy_fields(self : Audio, source : @core.Object3D) -> Unit {
  let source = match Audio::from_object(source) {
    Some(source) if source.source_type == "buffer" => source
    _ => {
      @core.warn("Audio: Audio source type cannot be copied.")
      return
    }
  }
  self.autoplay = source.autoplay
  self.buffer = source.buffer
  self.detune = source.detune
  self.loop_ = source.loop_
  self.loop_start = source.loop_start
  self.loop_end = source.loop_end
  self.offset = source.offset
  self.duration = source.duration
  self.playback_rate = source.playback_rate
  self.has_playback_control = source.has_playback_control
  self.source_type = source.source_type
  self.filters = source.filters.copy()
}

///|
impl @core.Object3DExtension for Audio with fn type_name(_) {
  // PositionalAudio does not set `type`, so it stays 'Audio'.
  "Audio"
}

///|
impl @core.Object3DExtension for Audio with fn construct(self) {
  match self.panner {
    Some(_) => PositionalAudio::new(self.listener).object
    None => Audio::new(self.listener).object
  }
}

///|
impl @core.Object3DExtension for Audio with fn has_flag(self, flag) {
  match flag {
    "isAudio" => true
    "isPositionalAudio" => self.panner is Some(_)
    _ => false
  }
}

///|
impl @core.Object3DExtension for Audio with fn copy_from(
  self,
  target,
  source,
  recursive,
) {
  target.copy_kind(source, recursive)
  self.copy_fields(source)
}

///|
impl @core.Object3DExtension for Audio with fn update_matrix_world(
  self,
  object,
  force,
) {
  // Audio inherits Object3D's; PositionalAudio overrides it after `super`.
  object.update_matrix_world_kind(force)
  if self.panner is Some(panner) {
    self.update_panner(object, panner)
  }
}
