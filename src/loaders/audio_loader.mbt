// Upstream src/loaders/AudioLoader.js. The shared context is `@audio.AudioContext`.

///|
/// `context.decodeAudioData( buffer, onSuccess ).catch( onError )`.
extern "js" fn js_decode_audio_data(
  context : JsValue,
  buffer : JsValue,
  on_success : (JsValue) -> Unit,
  on_error : (JsValue) -> Unit,
) -> Unit = "(c, b, f, e) => { c.decodeAudioData(b, f).catch(e); }"

///|
/// Loads audio files and decodes them into `AudioBuffer`s.
pub struct AudioLoader {
  base : Loader
}

///|
pub fn AudioLoader::new(manager? : LoadingManager) -> AudioLoader {
  { base: Loader::new(manager?), }
}

///|
pub impl LoaderLike for AudioLoader with fn loader(self) {
  self.base
}

///|
pub impl LoaderSettings for AudioLoader

///|
pub extend AudioLoader with LoaderLike::{loader}

///|
pub extend AudioLoader with LoaderSettings::{
  set_cross_origin,
  set_with_credentials,
  set_path,
  set_resource_path,
  set_request_header,
  set_priority,
  set_cache,
  abort,
}

///|
/// Starts loading `url`; `on_load` receives the decoded buffer.
pub fn AudioLoader::load(
  self : AudioLoader,
  url : String,
  on_load? : (@audio.AudioBuffer) -> Unit,
  on_progress? : (ProgressEvent) -> Unit,
  on_error? : (JsValue) -> Unit,
) -> Unit {
  let manager = self.base.manager
  fn handle_error(e : JsValue) -> Unit {
    if on_error is Some(on_error) {
      on_error(e)
    } else {
      loaders_error_value(e)
    }
    manager.item_error(url)
  }

  let loader = FileLoader::new(manager~)
    .set_priority(self.base.priority)
    .set_cache(self.base.cache)
  loader.set_response_type("arraybuffer") |> ignore
  loader
  .set_path(self.base.path)
  .set_request_header(self.base.request_header)
  .set_with_credentials(self.base.with_credentials)
  .load(
    url,
    on_load=buffer => {
      let result = js_try(() => {
        // Create a copy of the buffer. The `decodeAudioData` method
        // detaches the buffer when complete, preventing reuse.
        let buffer_copy = js_slice_buffer(buffer)
        let context = @audio.AudioContext::get_context().to_js()
        let decode_url = url + "#decode"
        manager.item_start(decode_url) // prevent loading manager from completing too early, see #33378
        js_decode_audio_data(
          context,
          buffer_copy,
          audio_buffer => {
            match on_load {
              Some(on_load) => on_load(@audio.AudioBuffer::of_js(audio_buffer))
              // upstream calls `onLoad` unconditionally, which throws without one
              None => ignore(js_throw(js_new_error("onLoad is not a function")))
            }
            manager.item_end(decode_url)
          },
          e => {
            handle_error(e)
            manager.item_end(decode_url)
          },
        )
      })
      if !result.ok() {
        handle_error(result.error())
      }
    },
    on_progress?,
    on_error?,
  )
}

///|
/// Upstream `loadAsync`.
pub async fn AudioLoader::load_async(
  self : AudioLoader,
  url : String,
  on_progress? : (ProgressEvent) -> Unit,
) -> @audio.AudioBuffer raise LoaderError {
  loader_promise((resolve, reject) => {
    self.load(url, on_load=resolve, on_progress?, on_error=reject)
  })
}
