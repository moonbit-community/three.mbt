///|
extern "js" fn test_mock_performance() -> @core.JsValue =
  #|() => {
  #|  const saved = Object.getOwnPropertyDescriptor( globalThis, 'performance' );
  #|  const mock = {
  #|    deltaTime: 0,
  #|    next( delta ) { this.deltaTime += delta; },
  #|    now() { return this.deltaTime; }
  #|  };
  #|  Object.defineProperty( globalThis, 'performance', { value: mock, configurable: true, writable: true } );
  #|  return { mock, restore() { Object.defineProperty( globalThis, 'performance', saved ); } };
  #|}

///|
extern "js" fn test_mock_next(mock : @core.JsValue, delta : Double) -> Unit = "(m, d) => m.mock.next( d )"

///|
extern "js" fn test_mock_restore(mock : @core.JsValue) -> Unit = "(m) => m.restore()"

///|
test "Clock Instancing" {
  let object = @core.Clock::new()
  assert_true(object.auto_start)
  let object_all = @core.Clock::new(auto_start=false)
  assert_false(object_all.auto_start)
}

///|
test "Clock with performance" {
  let mock = test_mock_performance()
  let clock = @core.Clock::new(auto_start=false)
  clock.start()
  test_mock_next(mock, 123)
  assert_true(approx(clock.get_elapsed_time(), 0.123))
  test_mock_next(mock, 100)
  assert_true(approx(clock.get_elapsed_time(), 0.223))
  clock.stop()
  test_mock_next(mock, 1000)
  assert_true(approx(clock.get_elapsed_time(), 0.223))
  test_mock_restore(mock)
}

///|
test "Clock autoStart" {
  let mock = test_mock_performance()
  let clock = @core.Clock::new()
  assert_eq(clock.get_delta(), 0)
  assert_true(clock.running)
  test_mock_next(mock, 500)
  assert_true(approx(clock.get_delta(), 0.5))
  test_mock_restore(mock)
}
