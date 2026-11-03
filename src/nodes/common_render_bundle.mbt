// renderers/common/RenderBundle.js

///|
/// A `BundleGroup` drawn with one camera in one render context.
pub(all) struct RenderBundle {
  /// The `BundleGroup`.
  bundle_group : @core.Object3D
  camera : @core.Object3D
  render_context : RenderContext
}

///|
/// `new RenderBundle( bundleGroup, camera, renderContext )`.
pub fn RenderBundle::new(
  bundle_group : @core.Object3D,
  camera : @core.Object3D,
  render_context : RenderContext,
) -> RenderBundle {
  { bundle_group, camera, render_context, }
}
