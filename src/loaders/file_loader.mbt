// Upstream src/loaders/FileLoader.js. The `fetch` chain is rebuilt with the same
// `.then` steps, so callbacks run in the same order and microtasks as upstream.
// Loaded data is a `JsValue`: a string, `ArrayBuffer`, `Blob`, `Document` or JSON value.

///|
/// The callbacks of one request, as upstream's `loading[ url ]` entries.
priv struct FileLoaderCallbacks {
  on_load : ((JsValue) -> Unit)?
  on_progress : ((ProgressEvent) -> Unit)?
  on_error : ((JsValue) -> Unit)?
}

///|
/// Upstream's module-level `loading`, the pending requests by URL.
let file_loader_loading : Map[String, Array[FileLoaderCallbacks]] = Map([])

///|
/// Loads files with `fetch`.
pub struct FileLoader {
  base : Loader
  mut mime_type : String
  mut response_type : String
  mut _abort_controller : AbortController
}

///|
pub fn FileLoader::new(manager? : LoadingManager) -> FileLoader {
  {
    base: Loader::new(manager?),
    mime_type: "",
    response_type: "",
    _abort_controller: AbortController::new(),
  }
}

///|
pub impl LoaderLike for FileLoader with fn loader(self) {
  self.base
}

///|
pub impl LoaderSettings for FileLoader with fn abort(self) {
  self._abort_controller.abort()
  self._abort_controller = AbortController::new()
  self
}

///|
pub extend FileLoader with LoaderLike::{loader}

///|
pub extend FileLoader with LoaderSettings::{
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
/// Starts loading `url`; `on_load` receives the data.
pub fn FileLoader::load(
  self : FileLoader,
  url : String,
  on_load? : (JsValue) -> Unit,
  on_progress? : (ProgressEvent) -> Unit,
  on_error? : (JsValue) -> Unit,
) -> Unit {
  let base = self.base
  let url = base.manager.resolve_url(base.path + url)
  let manager = base.manager
  if Cache::get("file:\{url}") is Some(cached) {
    manager.item_start(url)
    js_set_timeout(
      () => {
        if on_load is Some(on_load) {
          on_load(cached)
        }
        manager.item_end(url)
      },
      0,
    )
    return
  }

  // Check if request is duplicate
  if file_loader_loading.get(url) is Some(callbacks) {
    callbacks.push({ on_load, on_progress, on_error, })
    return
  }

  // Initialise array for duplicate requests
  file_loader_loading[url] = [{ on_load, on_progress, on_error, }]

  // create request
  let req = js_new_request(
    url,
    request_header_object(base.request_header),
    if base.with_credentials {
      "include"
    } else {
      "same-origin"
    },
    base.priority,
    base.cache,
    js_abort_signal(self._abort_controller, manager.abort_controller()),
  )

  // record states ( avoid data race )
  let mime_type = self.mime_type
  let response_type = self.response_type

  // start the fetch
  js_fetch(req)
  .then_(response => {
    let status = js_response_status(response)
    if status == 200.0 || status == 0.0 {
      // Some browsers return HTTP Status 0 when using non-http protocol
      // e.g. 'file://' or 'data://'. Handle as success.
      if status == 0.0 {
        @core.warn("FileLoader: HTTP Status 0 received.")
      }

      // Workaround: Checking if response.body === undefined for Alipay browser #23548
      if js_response_has_no_reader(response) {
        return response
      }
      let callbacks = file_loader_loading.get(url).unwrap_or([])
      let reader = js_response_reader(response)

      // Nginx needs X-File-Size check
      // https://serverfault.com/questions/482875/why-does-nginx-remove-content-length-header-for-chunked-content
      let total = js_response_total(response)
      let length_computable = total != 0.0
      let mut loaded = 0.0

      // periodically read data into the new stream tracking while download progress
      js_stream_response(controller => {
        fn read_data() -> Unit {
          js_reader_read(reader).then2(
            chunk => {
              if js_chunk_done(chunk) {
                js_controller_close(controller)
              } else {
                let value = js_chunk_value(chunk)
                loaded += js_byte_length(value)
                let event = ProgressEvent::new(
                  "progress", length_computable, loaded, total,
                )
                for callback in callbacks {
                  if callback.on_progress is Some(on_progress) {
                    on_progress(event)
                  }
                }
                js_controller_enqueue(controller, value)
                read_data()
              }
              JsValue::undefined()
            },
            e => {
              js_controller_error(controller, e)
              JsValue::undefined()
            },
          )
          |> ignore
        }

        read_data()
      })
    } else {
      js_throw(js_http_error(response))
    }
  })
  .then_(response => {
    match response_type {
      "arraybuffer" => js_response_body(response, "arrayBuffer")
      "blob" => js_response_body(response, "blob")
      "document" => js_response_document(response, mime_type)
      "json" => js_response_body(response, "json")
      _ =>
        if mime_type == "" {
          js_response_body(response, "text")
        } else {
          // sniff encoding
          js_response_decode(response, mime_type)
        }
    }
  })
  .then_(data => {
    // Add to cache only on HTTP success, so that we do not cache
    // error response bodies as proper responses to requests.
    Cache::add("file:\{url}", data)
    let callbacks = file_loader_loading.get(url).unwrap_or([])
    file_loader_loading.remove(url)
    for callback in callbacks {
      if callback.on_load is Some(on_load) {
        on_load(data)
      }
    }
    JsValue::undefined()
  })
  .catch_(err => {
    // Abort errors and other errors are handled the same
    guard file_loader_loading.get(url) is Some(callbacks) else {
      // When onLoad was called and url was deleted in `loading`
      manager.item_error(url)
      return js_throw(err)
    }
    file_loader_loading.remove(url)
    for callback in callbacks {
      if callback.on_error is Some(on_error) {
        on_error(err)
      }
    }
    manager.item_error(url)
    JsValue::undefined()
  })
  .finally_(() => manager.item_end(url))
  |> ignore
  manager.item_start(url)
}

///|
/// Upstream `loadAsync`.
pub async fn FileLoader::load_async(
  self : FileLoader,
  url : String,
  on_progress? : (ProgressEvent) -> Unit,
) -> JsValue raise LoaderError {
  loader_promise((resolve, reject) => {
    self.load(url, on_load=resolve, on_progress?, on_error=reject)
  })
}

///|
pub fn FileLoader::set_response_type(
  self : FileLoader,
  value : String,
) -> FileLoader {
  self.response_type = value
  self
}

///|
pub fn FileLoader::set_mime_type(
  self : FileLoader,
  value : String,
) -> FileLoader {
  self.mime_type = value
  self
}
