///|
test "LoaderUtils extractUrlBase" {
  assert_eq(
    @loaders.LoaderUtils::extract_url_base("/path/to/model.glb"),
    "/path/to/",
  )
  assert_eq(@loaders.LoaderUtils::extract_url_base("model.glb"), "./")
  assert_eq(@loaders.LoaderUtils::extract_url_base("/model.glb"), "/")
}

///|
test "LoaderUtils resolveURL" {
  assert_eq(@loaders.LoaderUtils::resolve_url("", "a/"), "")
  assert_eq(
    @loaders.LoaderUtils::resolve_url("/x.png", "https://h.com/a/b/"),
    "https://h.com/x.png",
  )
  assert_eq(
    @loaders.LoaderUtils::resolve_url("http://o.com/x.png", "a/"),
    "http://o.com/x.png",
  )
  assert_eq(@loaders.LoaderUtils::resolve_url("//o.com/x", "a/"), "//o.com/x")
  assert_eq(@loaders.LoaderUtils::resolve_url("data:a,b", "a/"), "data:a,b")
  assert_eq(@loaders.LoaderUtils::resolve_url("blob:x", "a/"), "blob:x")
  assert_eq(@loaders.LoaderUtils::resolve_url("x.png", "a/"), "a/x.png")
}
