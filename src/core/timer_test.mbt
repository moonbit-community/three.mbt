// Upstream has no Timer.tests.js; these follow the behaviour of src/core/Timer.js.

///|
test "Timer update with timestamps" {
  let mock = test_mock_performance()
  let timer = @core.Timer::new()
  ignore(timer.update(timestamp=1000))
  assert_eq(timer.get_delta(), 1)
  assert_eq(timer.get_elapsed(), 1)
  ignore(timer.update(timestamp=1500))
  assert_eq(timer.get_delta(), 0.5)
  assert_eq(timer.get_elapsed(), 1.5)
  ignore(timer.set_timescale(2))
  assert_eq(timer.get_timescale(), 2)
  ignore(timer.update(timestamp=2000))
  assert_eq(timer.get_delta(), 1)
  assert_eq(timer.get_elapsed(), 2.5)
  test_mock_restore(mock)
}

///|
test "Timer update reads performance.now" {
  let mock = test_mock_performance()
  test_mock_next(mock, 100)
  let timer = @core.Timer::new()
  test_mock_next(mock, 250)
  ignore(timer.update())
  assert_eq(timer.get_delta(), 0.25)
  test_mock_next(mock, 750)
  ignore(timer.reset())
  ignore(timer.update())
  assert_eq(timer.get_delta(), 0)
  test_mock_restore(mock)
}

///|
extern "js" fn test_mock_document(hidden : Bool) -> @core.JsValue =
  #|(hidden) => ({
  #|  hidden,
  #|  handlers: [],
  #|  addEventListener( type, h ) { this.handlers.push( h ); },
  #|  removeEventListener( type, h ) { this.handlers = this.handlers.filter( x => x !== h ); },
  #|  fire() { for ( const h of this.handlers ) h(); },
  #|  count() { return this.handlers.length; }
  #|})

///|
extern "js" fn test_document_fire(document : @core.JsValue) -> Unit = "(d) => d.fire()"

///|
extern "js" fn test_document_count(document : @core.JsValue) -> Int32 = "(d) => d.count()"

///|
extern "js" fn test_document_set_hidden(
  document : @core.JsValue,
  hidden : Bool,
) -> Unit = "(d, h) => { d.hidden = h; }"

///|
test "Timer connect and page visibility" {
  let mock = test_mock_performance()
  let document = test_mock_document(false)
  let timer = @core.Timer::new()
  timer.connect(document)
  assert_eq(test_document_count(document), 1)
  ignore(timer.update(timestamp=100))
  assert_eq(timer.get_delta(), 0.1)
  // hidden pages produce a zero delta
  test_document_set_hidden(document, true)
  ignore(timer.update(timestamp=5000))
  assert_eq(timer.get_delta(), 0)
  // becoming visible resets the current time, so no large delta
  test_document_set_hidden(document, false)
  test_mock_next(mock, 6000)
  test_document_fire(document)
  ignore(timer.update(timestamp=6100))
  assert_eq(timer.get_delta(), 0.1)
  timer.dispose()
  assert_eq(test_document_count(document), 0)
  assert_true(timer._document is None)
  test_mock_restore(mock)
}
