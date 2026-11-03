// Upstream src/loaders/AnimationLoader.js. Clips are `@animation.AnimationClip`s.

///|
/// Loads arrays of animation clips in the JSON format of `AnimationClip.toJSON`.
pub struct AnimationLoader {
  base : Loader
}

///|
pub fn AnimationLoader::new(manager? : LoadingManager) -> AnimationLoader {
  { base: Loader::new(manager?), }
}

///|
pub impl LoaderLike for AnimationLoader with fn loader(self) {
  self.base
}

///|
pub impl LoaderSettings for AnimationLoader

///|
pub extend AnimationLoader with LoaderLike::{loader}

///|
pub extend AnimationLoader with LoaderSettings::{
  set_cross_origin,
  set_with_credentials,
  set_path,
  set_resource_path,
  set_request_header,
  set_priority,
  set_cache,
  abort,
}

///|
/// Starts loading `url`; `on_load` receives the clips.
pub fn AnimationLoader::load(
  self : AnimationLoader,
  url : String,
  on_load : (Array[@animation.AnimationClip]) -> Unit,
  on_progress? : (ProgressEvent) -> Unit,
  on_error? : (JsValue) -> Unit,
) -> Unit {
  json_loader_load(
    self.base,
    url,
    json => on_load(self.parse(json)),
    on_progress,
    on_error,
  )
}

///|
/// Upstream `loadAsync`.
pub async fn AnimationLoader::load_async(
  self : AnimationLoader,
  url : String,
  on_progress? : (ProgressEvent) -> Unit,
) -> Array[@animation.AnimationClip] raise LoaderError {
  loader_promise((resolve, reject) => {
    self.load(url, resolve, on_progress?, on_error=reject)
  })
}

///|
/// Parses an array of serialized clips.
pub fn AnimationLoader::parse(
  self : AnimationLoader,
  json : Json,
) -> Array[@animation.AnimationClip] {
  ignore(self)
  let animations = []
  for data in json_array(json, "animations") {
    let clip = @animation.AnimationClip::parse(data)
    animations.push(clip)
  }
  animations
}

///|
/// `AnimationClip.parse( data )` as the resource `Object3D.animations` holds.
fn object_loader_parse_clip(data : Json) -> &@core.SerializableResource {
  @animation.AnimationClip::parse(data)
}
