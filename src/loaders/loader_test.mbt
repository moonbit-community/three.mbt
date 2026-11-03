///|
test "Loader request settings" {
  let loader = @loaders.Loader::new()
  assert_eq(loader.priority, "auto")
  assert_eq(loader.cache, "default")
  assert_true(physical_equal(loader.set_priority("high"), loader))
  assert_true(physical_equal(loader.set_cache("no-store"), loader))
  assert_eq(loader.priority, "high")
  assert_eq(loader.cache, "no-store")
}

///|
test "Loader defaults" {
  let loader = @loaders.Loader::new()
  assert_true(physical_equal(loader.manager, @loaders.default_loading_manager))
  assert_eq(loader.cross_origin, "anonymous")
  assert_eq(loader.with_credentials, false)
  assert_eq(loader.path, "")
  assert_eq(loader.resource_path, "")
  assert_eq(loader.request_header.length(), 0)
  assert_eq(@loaders.Loader_DEFAULT_MATERIAL_NAME, "__DEFAULT")
}

///|
test "Loader setters chain" {
  let manager = @loaders.LoadingManager::new()
  let loader = @loaders.FileLoader::new(manager~)
    .set_cross_origin("use-credentials")
    .set_with_credentials(true)
    .set_path("a/")
    .set_resource_path("b/")
    .set_request_header({ "X": "1" })
  assert_true(physical_equal(loader.loader().manager, manager))
  assert_eq(loader.loader().cross_origin, "use-credentials")
  assert_eq(loader.loader().with_credentials, true)
  assert_eq(loader.loader().path, "a/")
  assert_eq(loader.loader().resource_path, "b/")
  assert_eq(loader.loader().request_header.get("X"), Some("1"))
  assert_eq(loader.set_mime_type("text/plain").mime_type, "text/plain")
  assert_eq(loader.set_response_type("json").response_type, "json")
}

///|
/// Upstream's "Extending" and "Instancing" tests: every loader carries a `Loader`.
test "loaders extend Loader" {
  let manager = @loaders.LoadingManager::new()
  let loaders : Array[&@loaders.LoaderLike] = [
    @loaders.AnimationLoader::new(manager~),
    @loaders.AudioLoader::new(manager~),
    @loaders.BufferGeometryLoader::new(manager~),
    @loaders.CompressedTextureLoader::new(manager~),
    @loaders.CubeTextureLoader::new(manager~),
    @loaders.DataTextureLoader::new(manager~),
    @loaders.FileLoader::new(manager~),
    @loaders.ImageLoader::new(manager~),
    @loaders.MaterialLoader::new(manager~),
    @loaders.ObjectLoader::new(manager~),
    @loaders.TextureLoader::new(manager~),
  ]
  for loader in loaders {
    assert_true(physical_equal(loader.loader().manager, manager))
  }
}
