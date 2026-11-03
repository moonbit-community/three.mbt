///|
fn listeners_of(
  dispatcher : @core.EventDispatcher,
  type_ : String,
) -> Array[(@core.Event) -> Unit]? {
  match dispatcher._listeners {
    Some(listeners) => listeners.get(type_)
    None => None
  }
}

///|
test "EventDispatcher addEventListener" {
  let dispatcher = @core.EventDispatcher::new()
  let listener = fn(_e : @core.Event) { () }
  dispatcher.add_event_listener("anyType", listener)
  assert_true(listeners_of(dispatcher, "anyType").unwrap().length() == 1)
  assert_true(
    physical_equal(listeners_of(dispatcher, "anyType").unwrap()[0], listener),
  )
  dispatcher.add_event_listener("anyType", listener)
  assert_true(listeners_of(dispatcher, "anyType").unwrap().length() == 1)
  assert_true(
    physical_equal(listeners_of(dispatcher, "anyType").unwrap()[0], listener),
  )
}

///|
test "EventDispatcher hasEventListener" {
  let dispatcher = @core.EventDispatcher::new()
  let listener = fn(_e : @core.Event) { () }
  dispatcher.add_event_listener("anyType", listener)
  assert_true(dispatcher.has_event_listener("anyType", listener))
  assert_false(dispatcher.has_event_listener("anotherType", listener))
}

///|
test "EventDispatcher removeEventListener" {
  let dispatcher = @core.EventDispatcher::new()
  let listener = fn(_e : @core.Event) { () }
  assert_true(dispatcher._listeners is None)
  dispatcher.add_event_listener("anyType", listener)
  assert_true(dispatcher._listeners.unwrap().length() == 1)
  assert_true(listeners_of(dispatcher, "anyType").unwrap().length() == 1)
  dispatcher.remove_event_listener("anyType", listener)
  assert_true(listeners_of(dispatcher, "anyType").unwrap().length() == 0)
  dispatcher.remove_event_listener("unknownType", listener)
  assert_true(listeners_of(dispatcher, "unknownType") is None)
}

///|
test "EventDispatcher dispatchEvent" {
  let dispatcher = @core.EventDispatcher::new()
  let mut call_count = 0
  let listener = fn(_e : @core.Event) { call_count += 1 }
  dispatcher.add_event_listener("anyType", listener)
  assert_eq(call_count, 0)
  dispatcher.dispatch_event(@core.Event::new("anyType"))
  assert_eq(call_count, 1)
  dispatcher.dispatch_event(@core.Event::new("anyType"))
  assert_eq(call_count, 2)
}

///|
fn top_level_listener(_event : @core.Event) -> Unit {

}

///|
fn make_listener() -> (@core.Event) -> Unit {
  fn(_event) { () }
}

///|
test "listener identity follows JS function identity" {
  let dispatcher = @core.EventDispatcher::new()
  // a capturing closure, a named local function and a top-level function
  let mut count = 0
  let closure = fn(_e : @core.Event) { count += 1 }
  fn named(_e : @core.Event) -> Unit {
    count += 10
  }

  dispatcher.add_event_listener("t", closure)
  dispatcher.add_event_listener("t", named)
  dispatcher.add_event_listener("t", top_level_listener)
  dispatcher.add_event_listener("t", closure)
  dispatcher.add_event_listener("t", named)
  dispatcher.add_event_listener("t", top_level_listener)
  assert_eq(listeners_of(dispatcher, "t").unwrap().length(), 3)
  assert_true(dispatcher.has_event_listener("t", top_level_listener))
  dispatcher.dispatch_event(@core.Event::new("t"))
  assert_eq(count, 11)
  dispatcher.remove_event_listener("t", named)
  dispatcher.remove_event_listener("t", top_level_listener)
  dispatcher.dispatch_event(@core.Event::new("t"))
  assert_eq(count, 12)
  // two evaluations of a function expression are distinct, as in JS
  let a = make_listener()
  let b = make_listener()
  dispatcher.add_event_listener("u", a)
  dispatcher.add_event_listener("u", b)
  assert_eq(listeners_of(dispatcher, "u").unwrap().length(), 2)
  dispatcher.remove_event_listener("u", a)
  assert_true(dispatcher.has_event_listener("u", b))
  assert_false(dispatcher.has_event_listener("u", a))
}

///|
test "dispatchEvent sets target and survives removal while iterating" {
  let dispatcher = @core.EventDispatcher::new()
  let event = @core.Event::new("t")
  let seen = []
  fn second(e : @core.Event) -> Unit {
    seen.push("second")
    assert_true(e.target is Some(Dispatcher(_))) catch {
      _ => abort("no target")
    }
  }

  fn first(_e : @core.Event) -> Unit {
    seen.push("first")
    dispatcher.remove_event_listener("t", second)
  }

  dispatcher.add_event_listener("t", first)
  dispatcher.add_event_listener("t", second)
  dispatcher.dispatch_event(event)
  assert_eq(seen, ["first", "second"])
  assert_true(event.target is None)
  dispatcher.dispatch_event(event)
  assert_eq(seen, ["first", "second", "first"])
}
