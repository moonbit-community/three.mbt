// renderers/common/RenderBundles.js

///|
/// The render bundles by bundle group, camera and render context.
pub struct RenderBundles {
  priv mut bundles : ChainMap[RenderBundle]
}

///|
/// `new RenderBundles()`.
pub fn RenderBundles::new() -> RenderBundles {
  { bundles: ChainMap::new(), }
}

///|
/// `get( bundleGroup, camera, renderContext )`.
pub fn RenderBundles::get(
  self : RenderBundles,
  bundle_group : @core.Object3D,
  camera : @core.Object3D,
  render_context : RenderContext,
) -> RenderBundle {
  let bundles = self.bundles
  let chain_keys = [
    @core.JsValue::of(bundle_group),
    @core.JsValue::of(camera),
    @core.JsValue::of(render_context),
  ]
  match bundles.get(chain_keys) {
    Some(bundle) => bundle
    None => {
      let bundle = RenderBundle::new(bundle_group, camera, render_context)
      bundles.set(chain_keys, bundle) |> ignore
      bundle
    }
  }
}

///|
/// `dispose()`.
pub fn RenderBundles::dispose(self : RenderBundles) -> Unit {
  self.bundles = ChainMap::new()
}
