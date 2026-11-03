///|
/// Node has `fetch` but no `ProgressEvent`.
extern "js" fn file_loader_test_define_progress_event() -> Unit =
  #|() => { if (typeof ProgressEvent === 'undefined') globalThis.ProgressEvent = class { constructor(type, init) { Object.assign(this, init); this.type = type; } }; }

///|
async test "FileLoader loadAsync from a data URL" {
  file_loader_test_define_progress_event()
  let events = []
  let manager = @loaders.LoadingManager::new(on_load=() => events.push("load"))
  let loader = @loaders.FileLoader::new(manager~)
  let mut progress = 0.0
  let text = loader.load_async("data:text/plain,hello%20world", on_progress=e => {
    progress = e.loaded()
  })
  let text : String = text.cast()
  assert_eq(text, "hello world")
  assert_eq(progress, 11.0)
  @async.sleep(1)
  assert_eq(events, ["load"])
}

///|
async test "FileLoader loadAsync rejects with the HTTP error" {
  file_loader_test_define_progress_event()
  let loader = @loaders.FileLoader::new(manager=@loaders.LoadingManager::new())
  let result = try {
    ignore(loader.load_async("data:invalid"))
    "loaded"
  } catch {
    @loaders.LoaderError(_) => "rejected"
  }
  assert_eq(result, "rejected")
}

///|
async test "FileLoader responseType json and arraybuffer" {
  file_loader_test_define_progress_event()
  let json = @loaders.FileLoader::new()
    .set_response_type("json")
    .load_async("data:application/json,%7B%22a%22%3A%5B1%2C2%5D%7D")
  assert_eq(json.to_json(), { "a": [1, 2] })
  let buffer = @loaders.FileLoader::new()
    .set_response_type("arraybuffer")
    .load_async("data:application/octet-stream;base64,AQID")
  let bytes : @core.TypedArray = @core.TypedArray::view_by_name(
    "Uint8Array",
    buffer.cast(),
  )
  assert_eq(bytes.to_array(), [1.0, 2, 3])
}

///|
async test "BufferGeometryLoader and MaterialLoader loadAsync" {
  file_loader_test_define_progress_event()
  let geometry = @loaders.BufferGeometryLoader::new().load_async(
    "data:application/json,%7B%22data%22%3A%7B%22attributes%22%3A%7B%22position%22%3A%7B%22itemSize%22%3A3%2C%22type%22%3A%22Float32Array%22%2C%22array%22%3A%5B1%2C2%2C3%5D%7D%7D%7D%7D",
  )
  guard geometry.get_attribute("position") is Some(position) else {
    fail("no position")
  }
  assert_eq(position.array().to_array(), [1.0, 2, 3])
  let material = @loaders.MaterialLoader::new().load_async(
    "data:application/json,%7B%22type%22%3A%22MeshPhongMaterial%22%2C%22shininess%22%3A5%7D",
  )
  assert_true(material.is_mesh_phong_material())
  assert_eq(material.shininess, Some(5.0))
  let bad = try {
    ignore(
      @loaders.MaterialLoader::new().load_async("data:application/json,%7Bnope"),
    )
    "loaded"
  } catch {
    @loaders.LoaderError(_) => "rejected"
  }
  assert_eq(bad, "rejected")
}
