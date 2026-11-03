// renderers/common/BundleGroup.js: a core `Group` with an `Object3DExtension`.

///|
/// The extension of a `BundleGroup`.
pub(all) struct BundleGroup {
  /// Whether the bundle is rendered from its recorded commands.
  mut static_ : Bool
  mut version : Int32
}

///|
pub impl @core.Object3DExtension for BundleGroup with fn type_name(_) {
  "BundleGroup"
}

///|
pub impl @core.Object3DExtension for BundleGroup with fn construct(_) {
  BundleGroup::new()
}

///|
pub impl @core.Object3DExtension for BundleGroup with fn has_flag(_, flag) {
  flag == "isBundleGroup"
}

///|
/// `new BundleGroup()`.
pub fn BundleGroup::new() -> @core.Object3D {
  let group = @core.Group::new()
  group.set_extension(BundleGroup::{ static_: true, version: 0, })
}

///|
/// The `BundleGroup` payload of a bundle group.
pub fn BundleGroup::of(object : @core.Object3D) -> BundleGroup? {
  match object.extension {
    Some(extension) if extension.has_flag("isBundleGroup") =>
      Some(extension.payload().cast())
    _ => None
  }
}

///|
/// `set needsUpdate( value )`: `true` bumps the version.
pub fn BundleGroup::set_needs_update(
  object : @core.Object3D,
  value : Bool,
) -> Unit {
  match BundleGroup::of(object) {
    Some(group) => if value { group.version += 1 }
    None => abort("BundleGroup::set_needs_update: not a BundleGroup")
  }
}
