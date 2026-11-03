///|
test "Cache enabled and files" {
  assert_eq(@loaders.Cache::enabled(), false)
  assert_eq(@loaders.Cache::files().length(), 0)
}

///|
test "Cache add/get/remove" {
  let file = @core.JsValue::of("data")
  // disabled: nothing is stored
  @loaders.Cache::add("file:a", file)
  assert_true(@loaders.Cache::get("file:a") is None)
  @loaders.Cache::set_enabled(true)
  @loaders.Cache::add("file:a", file)
  assert_true(@loaders.Cache::get("file:a") is Some(f) && f.strict_equal(file))
  // blob URLs are never cached
  @loaders.Cache::add("file:blob:http://localhost/1", file)
  assert_true(@loaders.Cache::get("file:blob:http://localhost/1") is None)
  @loaders.Cache::remove("file:a")
  assert_true(@loaders.Cache::get("file:a") is None)
  @loaders.Cache::add("file:b", file)
  @loaders.Cache::clear()
  assert_eq(@loaders.Cache::files().length(), 0)
  @loaders.Cache::set_enabled(false)
}
