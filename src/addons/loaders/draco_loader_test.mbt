///|
test "DRACOLoader defaults" {
  let loader = @loaders.DRACOLoader::new()
  inspect(
    loader.decoder_paths.js,
    content="https://cdn.jsdelivr.net/npm/three@0.187.0/examples/jsm/libs/draco/draco_wasm_wrapper.js",
  )
  assert_eq(
    loader.decoder_paths.dep_js,
    Some(@loaders.DRACO_LIBS_URL + "draco_decoder.js"),
  )
  inspect(loader.worker_limit, content="4")
  inspect(loader.worker_next_task_id, content="1")
  inspect(loader.worker_source_url, content="")
  inspect(loader.decoder_pending is None, content="true")
  assert_eq(loader.default_attribute_ids.keys().collect(), [
    "position", "normal", "color", "uv",
  ])
  assert_eq(loader.default_attribute_ids.values().collect(), [
    "POSITION", "NORMAL", "COLOR", "TEX_COORD",
  ])
  assert_eq(loader.default_attribute_types.values().collect(), [
    "Float32Array", "Float32Array", "Float32Array", "Float32Array",
  ])
}

///|
test "DRACOLoader decoder paths" {
  let loader = @loaders.DRACOLoader::new()
  let same = loader.set_decoder_path("https://example.com/draco/")
  inspect(physical_equal(same, loader), content="true")
  inspect(
    loader.decoder_paths.js,
    content="https://example.com/draco/draco_wasm_wrapper.js",
  )
  inspect(
    loader.decoder_paths.wasm,
    content="https://example.com/draco/draco_decoder.wasm",
  )
  assert_eq(
    loader.decoder_paths.dep_js,
    Some("https://example.com/draco/draco_decoder.js"),
  )
  loader.set_decoder_path_config(
    @loaders.draco_gltf_config.js,
    @loaders.draco_gltf_config.wasm,
  )
  |> ignore
  inspect(
    loader.decoder_paths.wasm,
    content="https://cdn.jsdelivr.net/npm/three@0.187.0/examples/jsm/libs/draco/gltf/draco_decoder.wasm",
  )
  inspect(loader.decoder_paths.dep_js is None, content="true")
  inspect(loader.set_worker_limit(1).worker_limit, content="1")
}

///|
test "DRACOLoader JS decoder needs the default paths" {
  let loader = @loaders.DRACOLoader::new().set_decoder_path_config(
    "a.js", "b.wasm",
  )
  let config = @core.JsValue::object()
  config.set("type", @core.JsValue::of("js"))
  loader.set_decoder_config(config) |> ignore
  let error = @utils.addon_try(() => loader.preload() |> ignore)
  let message : String = error.unwrap().get("message").cast()
  inspect(
    message,
    content="THREE.DRACOLoader: WebAssembly is required when using a custom decoder paths.",
  )
  inspect(loader.decoder_pending is None, content="true")
}
