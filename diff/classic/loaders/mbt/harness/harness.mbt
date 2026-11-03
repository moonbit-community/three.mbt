// The MoonBit side of the loaders differential tests. `run.mjs` calls these exports.

///|
using @core {type JsValue}

///|
/// Creates the objects upstream creates lazily on first use (the shared Sprite geometry),
/// so that both sides draw the same random numbers during a round trip.
pub fn warmup() -> Unit {
  ignore(@core.Sprite::new())
}

///|
fn parse_text(text : String) -> Json {
  @json.parse(text) catch {
    e => abort("harness: bad JSON: \{e}")
  }
}

///|
/// `new ObjectLoader().parse( JSON.parse( text ) ).toJSON()`.
pub fn object_roundtrip(text : String) -> String {
  let object = @loaders.ObjectLoader::new().parse(parse_text(text))
  object.to_json().stringify()
}

///|
/// `( await new ObjectLoader().parseAsync( JSON.parse( text ) ) ).toJSON()` as a promise.
pub fn object_roundtrip_async(text : String) -> @js_async.Promise[String] {
  @js_async.Promise::from_async(async fn() -> String {
    let object = @loaders.ObjectLoader::new().parse_async(parse_text(text))
    object.to_json().stringify()
  })
}

///|
/// `new BufferGeometryLoader().parse( JSON.parse( text ) ).toJSON()`.
pub fn geometry_roundtrip(text : String) -> String {
  @loaders.BufferGeometryLoader::new().parse(parse_text(text)).to_json().stringify()
}

///|
/// `new MaterialLoader().parse( JSON.parse( text ) ).toJSON()`, without textures.
pub fn material_roundtrip(text : String) -> String {
  @loaders.MaterialLoader::new().parse(parse_text(text)).to_json().stringify()
}

///|
extern "js" fn note(label : String, value : JsValue) -> Unit = "(l, v) => globalThis.__note(l, v)"

///|
fn note_s(label : String, value : String) -> Unit {
  note(label, JsValue::of(value))
}

///|
fn manager_with_log(name : String) -> @loaders.LoadingManager {
  let manager = @loaders.LoadingManager::new(
    on_load=() => note_s(name + ".onLoad", ""),
    on_progress=(url, loaded, total) => note_s(
      name + ".onProgress",
      "\{url} \{loaded}/\{total}",
    ),
    on_error=url => note_s(name + ".onError", url),
  )
  manager.on_start = Some((url, loaded, total) => note_s(
    name + ".onStart",
    "\{url} \{loaded}/\{total}",
  ))
  manager
}

///|
/// Runs the scenario `name`; the mock environment records what happens.
pub fn run_scenario(name : String) -> Unit {
  scenarios(name)
}
