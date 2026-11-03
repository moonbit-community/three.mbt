// Upstream src/loaders/LoadingManager.js. The closure locals of the constructor
// (`isLoading`, `itemsLoaded`, `itemsTotal`, `urlModifier`, `handlers`) are fields.

///|
/// Tracks loaded and pending data; loaders report each item to it.
pub(all) struct LoadingManager {
  mut on_start : ((String, Int32, Int32) -> Unit)?
  mut on_load : (() -> Unit)?
  mut on_progress : ((String, Int32, Int32) -> Unit)?
  mut on_error : ((String) -> Unit)?
  mut _abort_controller : AbortController?
  mut is_loading : Bool
  mut items_loaded : Int32
  mut items_total : Int32
  mut url_modifier : ((String) -> String)?
  handlers : Array[(RegExp, &LoaderLike)]
}

///|
pub fn LoadingManager::new(
  on_load? : () -> Unit,
  on_progress? : (String, Int32, Int32) -> Unit,
  on_error? : (String) -> Unit,
) -> LoadingManager {
  {
    on_start: None,
    on_load,
    on_progress,
    on_error,
    _abort_controller: None,
    is_loading: false,
    items_loaded: 0,
    items_total: 0,
    url_modifier: None,
    handlers: [],
  }
}

///|
/// Upstream `DefaultLoadingManager`, used by loaders made without a manager.
pub let default_loading_manager : LoadingManager = LoadingManager::new()

///|
pub fn LoadingManager::item_start(self : LoadingManager, url : String) -> Unit {
  self.items_total += 1
  if self.is_loading == false {
    if self.on_start is Some(on_start) {
      on_start(url, self.items_loaded, self.items_total)
    }
  }
  self.is_loading = true
}

///|
pub fn LoadingManager::item_end(self : LoadingManager, url : String) -> Unit {
  self.items_loaded += 1
  if self.on_progress is Some(on_progress) {
    on_progress(url, self.items_loaded, self.items_total)
  }
  if self.items_loaded == self.items_total {
    self.is_loading = false
    if self.on_load is Some(on_load) {
      on_load()
    }
  }
}

///|
pub fn LoadingManager::item_error(self : LoadingManager, url : String) -> Unit {
  if self.on_error is Some(on_error) {
    on_error(url)
  }
}

///|
pub fn LoadingManager::resolve_url(
  self : LoadingManager,
  url : String,
) -> String {
  // Normalize to NFC so that Unicode URIs (e.g. from glTF)
  // are percent-encoded correctly per RFC 3987.
  let url = js_normalize_nfc(url)
  if self.url_modifier is Some(url_modifier) {
    return url_modifier(url)
  }
  url
}

///|
pub fn LoadingManager::set_url_modifier(
  self : LoadingManager,
  transform : ((String) -> String)?,
) -> LoadingManager {
  self.url_modifier = transform
  self
}

///|
pub fn LoadingManager::add_handler(
  self : LoadingManager,
  regex : RegExp,
  loader : &LoaderLike,
) -> LoadingManager {
  self.handlers.push((regex, loader))
  self
}

///|
pub fn LoadingManager::remove_handler(
  self : LoadingManager,
  regex : RegExp,
) -> LoadingManager {
  for i, handler in self.handlers {
    if handler.0.same(regex) {
      self.handlers.remove(i) |> ignore
      break
    }
  }
  self
}

///|
/// `None` is upstream's `null`.
pub fn LoadingManager::get_handler(
  self : LoadingManager,
  file : String,
) -> &LoaderLike? {
  for handler in self.handlers {
    let (regex, loader) = handler
    if regex.global() {
      regex.set_last_index(0) // see #17920
    }
    if regex.test_(file) {
      return Some(loader)
    }
  }
  None
}

///|
pub fn LoadingManager::abort(self : LoadingManager) -> LoadingManager {
  self.abort_controller().abort()
  self._abort_controller = None
  self
}

///|
/// Upstream's lazy `abortController` getter.
pub fn LoadingManager::abort_controller(
  self : LoadingManager,
) -> AbortController {
  match self._abort_controller {
    Some(controller) => controller
    None => {
      let controller = AbortController::new()
      self._abort_controller = Some(controller)
      controller
    }
  }
}
