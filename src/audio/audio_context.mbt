// Upstream src/audio/AudioContext.js: the lazily created, shared native context. Upstream's
// class only has statics, so they live on the native `AudioContext` type.

///|
extern "js" fn audio_context_undefined() -> AudioContext = "() => undefined"

///|
/// Upstream's module-level `_context`; `undefined` until first use or `set_context`.
let audio_context_context : Ref[AudioContext] = {
  val: audio_context_undefined(),
}

///|
/// Returns the global native audio context, creating it on first use.
pub fn AudioContext::get_context() -> AudioContext {
  if audio_context_context.val.to_js().is_undefined() {
    audio_context_context.val = web_audio_new_context()
  }
  audio_context_context.val
}

///|
/// Sets the global native audio context; `undefined` makes the next `get_context` create one.
pub fn AudioContext::set_context(value : AudioContext) -> Unit {
  audio_context_context.val = value
}
