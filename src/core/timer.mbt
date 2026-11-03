// Upstream src/core/Timer.js.

///|
extern "js" fn timer_add_visibility_listener(
  document : JsValue,
  handler : JsValue,
) -> Unit = "(d, h) => d.addEventListener( 'visibilitychange', h, false )"

///|
extern "js" fn timer_remove_visibility_listener(
  document : JsValue,
  handler : JsValue,
) -> Unit = "(d, h) => d.removeEventListener( 'visibilitychange', h )"

///|
extern "js" fn timer_document_hidden(document : JsValue) -> JsValue = "(d) => d.hidden"

///|
pub fn Timer::new() -> Timer {
  {
    _previous_time: 0,
    _current_time: 0,
    _start_time: utils_performance_now(),
    _delta: 0,
    _elapsed: 0,
    _timescale: 1,
    _document: None,
    _page_visibility_handler: None,
  }
}

///|
/// Connects to the DOM `document` so hidden pages produce no large deltas.
pub fn Timer::connect(self : Timer, document : JsValue) -> Unit {
  self._document = Some(document)
  // use Page Visibility API to avoid large time delta values
  if !timer_document_hidden(document).is_undefined() {
    let handler : () -> Unit = () => {
      if timer_document_hidden(document).strict_equal(JsValue::of(false)) {
        ignore(self.reset())
      }
    }
    self._page_visibility_handler = Some(JsValue::of(handler))
    timer_add_visibility_listener(document, JsValue::of(handler))
  }
}

///|
pub fn Timer::disconnect(self : Timer) -> Unit {
  if self._page_visibility_handler is Some(handler) {
    if self._document is Some(document) {
      timer_remove_visibility_listener(document, handler)
    }
    self._page_visibility_handler = None
  }
  self._document = None
}

///|
pub fn Timer::get_delta(self : Timer) -> Double {
  self._delta / 1000.0
}

///|
pub fn Timer::get_elapsed(self : Timer) -> Double {
  self._elapsed / 1000.0
}

///|
pub fn Timer::get_timescale(self : Timer) -> Double {
  self._timescale
}

///|
pub fn Timer::set_timescale(self : Timer, timescale : Double) -> Timer {
  self._timescale = timescale
  self
}

///|
pub fn Timer::reset(self : Timer) -> Timer {
  self._current_time = utils_performance_now() - self._start_time
  self
}

///|
pub fn Timer::dispose(self : Timer) -> Unit {
  self.disconnect()
}

///|
pub fn Timer::update(self : Timer, timestamp? : Double) -> Timer {
  let hidden = match (self._page_visibility_handler, self._document) {
    (Some(_), Some(document)) =>
      timer_document_hidden(document).strict_equal(JsValue::of(true))
    _ => false
  }
  if hidden {
    self._delta = 0
  } else {
    self._previous_time = self._current_time
    self._current_time = timestamp.unwrap_or_else(utils_performance_now) -
      self._start_time
    self._delta = (self._current_time - self._previous_time) * self._timescale
    self._elapsed += self._delta // _elapsed is the accumulation of all previous deltas
  }
  self
}
