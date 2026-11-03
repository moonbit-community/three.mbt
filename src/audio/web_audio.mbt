// Web Audio API bindings. The member list is derived from upstream src/audio with JSDoc
// and lib.dom.d.ts types (audio_diff harness, tools/web_audio_usage.mjs): 63 members.
// Each binding touches the JS object exactly as the upstream expression does, so a
// recording mock sees the same reads, writes and calls.

///|
/// A native `AudioContext` (`BaseAudioContext` members included).
#external
pub type AudioContext

///|
/// Any native `AudioNode`.
#external
pub type AudioNode

///|
#external
pub type GainNode

///|
#external
pub type PannerNode

///|
#external
pub type AnalyserNode

///|
#external
pub type AudioBufferSourceNode

///|
#external
pub type AudioParam

///|
#external
pub type AudioBuffer

///|
/// The native `AudioListener` of a context; `AudioListener` is three's class.
#external
pub type WebAudioListener

// ---- conversions

///|
pub fn AudioContext::of_js(value : @core.JsValue) -> AudioContext = "%identity"

///|
pub fn AudioContext::to_js(self : AudioContext) -> @core.JsValue = "%identity"

///|
pub fn AudioNode::of_js(value : @core.JsValue) -> AudioNode = "%identity"

///|
pub fn AudioNode::to_js(self : AudioNode) -> @core.JsValue = "%identity"

///|
/// Unchecked: upstream uses `source` as an `AudioBufferSourceNode` once it plays.
pub fn AudioNode::as_buffer_source(self : AudioNode) -> AudioBufferSourceNode = "%identity"

///|
pub fn AudioBuffer::of_js(value : @core.JsValue) -> AudioBuffer = "%identity"

///|
pub fn AudioBuffer::to_js(self : AudioBuffer) -> @core.JsValue = "%identity"

///|
pub fn GainNode::as_node(self : GainNode) -> AudioNode = "%identity"

///|
pub fn PannerNode::as_node(self : PannerNode) -> AudioNode = "%identity"

///|
pub fn AnalyserNode::as_node(self : AnalyserNode) -> AudioNode = "%identity"

///|
pub fn AudioBufferSourceNode::as_node(
  self : AudioBufferSourceNode,
) -> AudioNode = "%identity"

///|
pub fn AudioParam::to_js(self : AudioParam) -> @core.JsValue = "%identity"

// ---- window

///|
/// `new ( window.AudioContext || window.webkitAudioContext )()`.
extern "js" fn web_audio_new_context() -> AudioContext = "() => new ( window.AudioContext || window.webkitAudioContext )()"

// ---- BaseAudioContext

///|
pub extern "js" fn AudioContext::create_gain(self : AudioContext) -> GainNode = "(c) => c.createGain()"

///|
pub extern "js" fn AudioContext::create_panner(
  self : AudioContext,
) -> PannerNode = "(c) => c.createPanner()"

///|
pub extern "js" fn AudioContext::create_buffer_source(
  self : AudioContext,
) -> AudioBufferSourceNode = "(c) => c.createBufferSource()"

///|
pub extern "js" fn AudioContext::create_analyser(
  self : AudioContext,
) -> AnalyserNode = "(c) => c.createAnalyser()"

///|
/// `media_element` is an `HTMLMediaElement`.
pub extern "js" fn AudioContext::create_media_element_source(
  self : AudioContext,
  media_element : @core.JsValue,
) -> AudioNode = "(c, e) => c.createMediaElementSource( e )"

///|
/// `media_stream` is a `MediaStream`.
pub extern "js" fn AudioContext::create_media_stream_source(
  self : AudioContext,
  media_stream : @core.JsValue,
) -> AudioNode = "(c, s) => c.createMediaStreamSource( s )"

///|
pub extern "js" fn AudioContext::current_time(self : AudioContext) -> Double = "(c) => c.currentTime"

///|
pub extern "js" fn AudioContext::destination(self : AudioContext) -> AudioNode = "(c) => c.destination"

///|
pub extern "js" fn AudioContext::listener(
  self : AudioContext,
) -> WebAudioListener = "(c) => c.listener"

// ---- AudioNode

///|
pub extern "js" fn AudioNode::connect(
  self : AudioNode,
  destination : AudioNode,
) -> Unit = "(n, d) => { n.connect( d ); }"

///|
pub extern "js" fn AudioNode::disconnect(
  self : AudioNode,
  destination : AudioNode,
) -> Unit = "(n, d) => { n.disconnect( d ); }"

// ---- AudioParam

///|
pub extern "js" fn AudioParam::value(self : AudioParam) -> Double = "(p) => p.value"

///|
pub extern "js" fn AudioParam::set_target_at_time(
  self : AudioParam,
  target : Double,
  start_time : Double,
  time_constant : Double,
) -> Unit = "(p, v, t, c) => { p.setTargetAtTime( v, t, c ); }"

///|
pub extern "js" fn AudioParam::linear_ramp_to_value_at_time(
  self : AudioParam,
  value : Double,
  end_time : Double,
) -> Unit = "(p, v, t) => { p.linearRampToValueAtTime( v, t ); }"

// ---- GainNode

///|
pub extern "js" fn GainNode::gain(self : GainNode) -> AudioParam = "(n) => n.gain"

// ---- AudioListener (native)

///|
/// `if ( listener.positionX )`: the AudioParam path (Chrome, see three.js #14393).
pub extern "js" fn WebAudioListener::has_position_x(
  self : WebAudioListener,
) -> Bool = "(l) => l.positionX ? true : false"

///|
pub extern "js" fn WebAudioListener::position_x(
  self : WebAudioListener,
) -> AudioParam = "(l) => l.positionX"

///|
pub extern "js" fn WebAudioListener::position_y(
  self : WebAudioListener,
) -> AudioParam = "(l) => l.positionY"

///|
pub extern "js" fn WebAudioListener::position_z(
  self : WebAudioListener,
) -> AudioParam = "(l) => l.positionZ"

///|
pub extern "js" fn WebAudioListener::forward_x(
  self : WebAudioListener,
) -> AudioParam = "(l) => l.forwardX"

///|
pub extern "js" fn WebAudioListener::forward_y(
  self : WebAudioListener,
) -> AudioParam = "(l) => l.forwardY"

///|
pub extern "js" fn WebAudioListener::forward_z(
  self : WebAudioListener,
) -> AudioParam = "(l) => l.forwardZ"

///|
pub extern "js" fn WebAudioListener::up_x(
  self : WebAudioListener,
) -> AudioParam = "(l) => l.upX"

///|
pub extern "js" fn WebAudioListener::up_y(
  self : WebAudioListener,
) -> AudioParam = "(l) => l.upY"

///|
pub extern "js" fn WebAudioListener::up_z(
  self : WebAudioListener,
) -> AudioParam = "(l) => l.upZ"

///|
pub extern "js" fn WebAudioListener::set_position(
  self : WebAudioListener,
  x : Double,
  y : Double,
  z : Double,
) -> Unit = "(l, x, y, z) => { l.setPosition( x, y, z ); }"

///|
pub extern "js" fn WebAudioListener::set_orientation(
  self : WebAudioListener,
  x : Double,
  y : Double,
  z : Double,
  x_up : Double,
  y_up : Double,
  z_up : Double,
) -> Unit = "(l, x, y, z, ux, uy, uz) => { l.setOrientation( x, y, z, ux, uy, uz ); }"

// ---- PannerNode

///|
pub extern "js" fn PannerNode::set_panning_model(
  self : PannerNode,
  value : String,
) -> Unit = "(p, v) => { p.panningModel = v; }"

///|
pub extern "js" fn PannerNode::ref_distance(self : PannerNode) -> Double = "(p) => p.refDistance"

///|
pub extern "js" fn PannerNode::set_ref_distance(
  self : PannerNode,
  value : Double,
) -> Unit = "(p, v) => { p.refDistance = v; }"

///|
pub extern "js" fn PannerNode::rolloff_factor(self : PannerNode) -> Double = "(p) => p.rolloffFactor"

///|
pub extern "js" fn PannerNode::set_rolloff_factor(
  self : PannerNode,
  value : Double,
) -> Unit = "(p, v) => { p.rolloffFactor = v; }"

///|
pub extern "js" fn PannerNode::distance_model(self : PannerNode) -> String = "(p) => p.distanceModel"

///|
pub extern "js" fn PannerNode::set_distance_model(
  self : PannerNode,
  value : String,
) -> Unit = "(p, v) => { p.distanceModel = v; }"

///|
pub extern "js" fn PannerNode::max_distance(self : PannerNode) -> Double = "(p) => p.maxDistance"

///|
pub extern "js" fn PannerNode::set_max_distance(
  self : PannerNode,
  value : Double,
) -> Unit = "(p, v) => { p.maxDistance = v; }"

///|
pub extern "js" fn PannerNode::set_cone_inner_angle(
  self : PannerNode,
  value : Double,
) -> Unit = "(p, v) => { p.coneInnerAngle = v; }"

///|
pub extern "js" fn PannerNode::set_cone_outer_angle(
  self : PannerNode,
  value : Double,
) -> Unit = "(p, v) => { p.coneOuterAngle = v; }"

///|
pub extern "js" fn PannerNode::set_cone_outer_gain(
  self : PannerNode,
  value : Double,
) -> Unit = "(p, v) => { p.coneOuterGain = v; }"

///|
/// `if ( panner.positionX )`: the AudioParam path (Chrome and Firefox, see #14393).
pub extern "js" fn PannerNode::has_position_x(self : PannerNode) -> Bool = "(p) => p.positionX ? true : false"

///|
pub extern "js" fn PannerNode::position_x(self : PannerNode) -> AudioParam = "(p) => p.positionX"

///|
pub extern "js" fn PannerNode::position_y(self : PannerNode) -> AudioParam = "(p) => p.positionY"

///|
pub extern "js" fn PannerNode::position_z(self : PannerNode) -> AudioParam = "(p) => p.positionZ"

///|
pub extern "js" fn PannerNode::orientation_x(self : PannerNode) -> AudioParam = "(p) => p.orientationX"

///|
pub extern "js" fn PannerNode::orientation_y(self : PannerNode) -> AudioParam = "(p) => p.orientationY"

///|
pub extern "js" fn PannerNode::orientation_z(self : PannerNode) -> AudioParam = "(p) => p.orientationZ"

///|
pub extern "js" fn PannerNode::set_position(
  self : PannerNode,
  x : Double,
  y : Double,
  z : Double,
) -> Unit = "(p, x, y, z) => { p.setPosition( x, y, z ); }"

///|
pub extern "js" fn PannerNode::set_orientation(
  self : PannerNode,
  x : Double,
  y : Double,
  z : Double,
) -> Unit = "(p, x, y, z) => { p.setOrientation( x, y, z ); }"

// ---- AudioBufferSourceNode (with AudioScheduledSourceNode)

///|
extern "js" fn web_audio_set_buffer(
  source : AudioBufferSourceNode,
  buffer : @core.JsValue,
) -> Unit = "(s, b) => { s.buffer = b; }"

///|
/// `source.buffer = buffer`; `None` is `null`.
pub fn AudioBufferSourceNode::set_buffer(
  self : AudioBufferSourceNode,
  buffer : AudioBuffer?,
) -> Unit {
  web_audio_set_buffer(
    self,
    match buffer {
      Some(buffer) => buffer.to_js()
      None => @core.JsValue::null()
    },
  )
}

///|
pub extern "js" fn AudioBufferSourceNode::set_loop(
  self : AudioBufferSourceNode,
  value : Bool,
) -> Unit = "(s, v) => { s.loop = v; }"

///|
pub extern "js" fn AudioBufferSourceNode::set_loop_start(
  self : AudioBufferSourceNode,
  value : Double,
) -> Unit = "(s, v) => { s.loopStart = v; }"

///|
pub extern "js" fn AudioBufferSourceNode::set_loop_end(
  self : AudioBufferSourceNode,
  value : Double,
) -> Unit = "(s, v) => { s.loopEnd = v; }"

///|
/// `source.onended = handler`.
pub extern "js" fn AudioBufferSourceNode::set_onended(
  self : AudioBufferSourceNode,
  handler : () -> Unit,
) -> Unit = "(s, f) => { s.onended = f; }"

///|
/// `source.onended = null`.
pub extern "js" fn AudioBufferSourceNode::clear_onended(
  self : AudioBufferSourceNode,
) -> Unit = "(s) => { s.onended = null; }"

///|
extern "js" fn web_audio_start(
  source : AudioBufferSourceNode,
  when_ : Double,
  offset : Double,
  duration : @core.JsValue,
) -> Unit = "(s, w, o, d) => { s.start( w, o, d ); }"

///|
/// `source.start( when, offset, duration )`; a missing `duration` is passed as `undefined`.
pub fn AudioBufferSourceNode::start(
  self : AudioBufferSourceNode,
  when_ : Double,
  offset : Double,
  duration? : Double,
) -> Unit {
  web_audio_start(
    self,
    when_,
    offset,
    match duration {
      Some(duration) => @core.JsValue::of(duration)
      None => @core.JsValue::undefined()
    },
  )
}

///|
extern "js" fn web_audio_stop(source : AudioBufferSourceNode) -> Unit = "(s) => { s.stop(); }"

///|
extern "js" fn web_audio_stop_at(
  source : AudioBufferSourceNode,
  when_ : Double,
) -> Unit = "(s, w) => { s.stop( w ); }"

///|
/// `source.stop()`, or `source.stop( when )`.
pub fn AudioBufferSourceNode::stop(
  self : AudioBufferSourceNode,
  when_? : Double,
) -> Unit {
  match when_ {
    Some(when_) => web_audio_stop_at(self, when_)
    None => web_audio_stop(self)
  }
}

///|
/// `source.detune !== undefined`.
pub extern "js" fn AudioBufferSourceNode::has_detune(
  self : AudioBufferSourceNode,
) -> Bool = "(s) => s.detune !== undefined"

///|
pub extern "js" fn AudioBufferSourceNode::detune(
  self : AudioBufferSourceNode,
) -> AudioParam = "(s) => s.detune"

///|
pub extern "js" fn AudioBufferSourceNode::playback_rate(
  self : AudioBufferSourceNode,
) -> AudioParam = "(s) => s.playbackRate"

// ---- AnalyserNode

///|
pub extern "js" fn AnalyserNode::set_fft_size(
  self : AnalyserNode,
  value : Int32,
) -> Unit = "(a, v) => { a.fftSize = v; }"

///|
pub extern "js" fn AnalyserNode::frequency_bin_count(
  self : AnalyserNode,
) -> Int32 = "(a) => a.frequencyBinCount"

///|
pub extern "js" fn AnalyserNode::get_byte_frequency_data(
  self : AnalyserNode,
  array : @core.TypedArray,
) -> Unit = "(a, d) => { a.getByteFrequencyData( d ); }"

// ---- AudioBuffer

///|
pub extern "js" fn AudioBuffer::duration(self : AudioBuffer) -> Double = "(b) => b.duration"

// ---- JS operators upstream relies on

///|
/// JS `Math.max`, which propagates NaN.
extern "js" fn web_audio_math_max(a : Double, b : Double) -> Double = "Math.max"

///|
/// JS `%` on numbers.
extern "js" fn web_audio_remainder(a : Double, b : Double) -> Double = "(a, b) => a % b"

///|
/// JS truthiness of a number: false for `0`, `-0` and `NaN`.
fn web_audio_truthy(value : Double) -> Bool {
  value == value && value != 0.0
}
