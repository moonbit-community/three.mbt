// How classes above `core` plug in. Each extensible type has an `extension` field next
// to its `kind` or type enum, so `AxesHelper` keeps `Line(..)` data and adds an
// extension, and `NodeMaterial` keeps `MaterialType::Material` and adds one.
//
// The call chain for an overridable `Object3D` method `m`:
//   `Object3D::m` -> `extension.m` if an extension is set -> `Object3D::m_kind`
//   -> the class's hook, or `Object3D::m_base` (upstream's `Object3D.prototype.m`).
// Default trait methods call `m_kind`, so an override reaches `super` by calling it.
// `payload` recovers the concrete value: `ext.payload().cast()`.

///|
/// `Frustum` or `FrustumArray`, the argument of `intersectsFrustum`.
pub(all) enum FrustumRef {
  Single(@math.Frustum)
  Array(@math.FrustumArray)
}

///|
/// A value core stores and serializes without knowing its class: `AnimationClip`,
/// `Shape`.
pub(open) trait SerializableResource {
  fn uuid(Self) -> String
  fn to_json(Self) -> Json
  fn payload(Self) -> JsValue = _
}

///|
impl SerializableResource with fn payload(self) {
  JsValue::of(self)
}

///|
/// Upstream subclasses of `Object3D` and its subclasses that live above core.
pub(open) trait Object3DExtension {
  /// Upstream's `type`.
  fn type_name(Self) -> String
  /// `new this.constructor()`; the first half of `clone`.
  fn construct(Self) -> Object3D
  fn payload(Self) -> JsValue = _
  /// Answers upstream `isFoo` checks: `has_flag("isAudio")`.
  fn has_flag(Self, String) -> Bool = _
  fn raycast(Self, Object3D, Raycaster, Array[Intersection]) -> Unit = _
  /// `target.copy( source, recursive )`.
  fn copy_from(Self, Object3D, Object3D, Bool) -> Unit = _
  /// Adds to `data.object` after the standard fields.
  fn to_json(Self, Object3D, ToJsonMeta, Map[String, Json]) -> Unit = _
  fn update_matrix_world(Self, Object3D, Bool) -> Unit = _
  fn update_world_matrix(Self, Object3D, Bool, Bool, Bool) -> Unit = _
  fn intersects_frustum(Self, Object3D, FrustumRef) -> Bool = _
  fn get_world_direction(Self, Object3D, @math.Vector3) -> @math.Vector3 = _
  fn dispose(Self, Object3D) -> Unit = _
}

///|
impl Object3DExtension with fn payload(self) {
  JsValue::of(self)
}

///|
impl Object3DExtension with fn has_flag(_, _) {
  false
}

///|
impl Object3DExtension with fn raycast(_, object, raycaster, intersects) {
  object.raycast_kind(raycaster, intersects)
}

///|
impl Object3DExtension with fn copy_from(_, target, source, recursive) {
  target.copy_kind(source, recursive)
}

///|
impl Object3DExtension with fn to_json(_, _, _, _) {

}

///|
impl Object3DExtension with fn update_matrix_world(_, object, force) {
  object.update_matrix_world_kind(force)
}

///|
impl Object3DExtension with fn update_world_matrix(
  _,
  object,
  update_parents,
  update_children,
  force,
) {
  object.update_world_matrix_kind(update_parents, update_children, force)
}

///|
impl Object3DExtension with fn intersects_frustum(_, object, frustum) {
  object.intersects_frustum_kind(frustum)
}

///|
impl Object3DExtension with fn get_world_direction(_, object, target) {
  object.get_world_direction_kind(target)
}

///|
impl Object3DExtension with fn dispose(_, object) {
  object.dispose_kind()
}

///|
/// Upstream subclasses of `Material` that live above core, such as `NodeMaterial`.
pub(open) trait MaterialExtension {
  /// Upstream's `type`.
  fn type_name(Self) -> String
  /// `new this.constructor()`.
  fn construct(Self) -> Material
  fn payload(Self) -> JsValue = _
  /// Answers upstream `isFoo` checks: `has_flag("isNodeMaterial")`.
  fn has_flag(Self, String) -> Bool = _
  /// Runs after `Material::copy` has copied the flat fields; arguments are target, source.
  fn copy_from(Self, Material, Material) -> Unit = _
  /// Adds to the serialized material after the standard fields.
  fn to_json(Self, Material, ToJsonMeta?, Map[String, Json]) -> Unit = _
  /// Overrides `customProgramCacheKey`; `None` falls back to the standard key.
  fn custom_program_cache_key(Self, Material) -> String? = _
  fn dispose(Self, Material) -> Unit = _
}

///|
impl MaterialExtension with fn payload(self) {
  JsValue::of(self)
}

///|
impl MaterialExtension with fn has_flag(_, _) {
  false
}

///|
impl MaterialExtension with fn copy_from(_, _, _) {

}

///|
impl MaterialExtension with fn to_json(_, _, _, _) {

}

///|
impl MaterialExtension with fn custom_program_cache_key(_, _) {
  None
}

///|
impl MaterialExtension with fn dispose(_, _) {

}

///|
/// Upstream subclasses of `Texture` that live above core, such as `StorageTexture`.
pub(open) trait TextureExtension {
  /// The class name, for diagnostics; `Texture` has no `type` upstream.
  fn type_name(Self) -> String
  /// `new this.constructor()`.
  fn construct(Self) -> Texture
  fn payload(Self) -> JsValue = _
  /// Answers upstream `isFoo` checks: `has_flag("isStorageTexture")`.
  fn has_flag(Self, String) -> Bool = _
  /// Runs after `Texture::copy` has copied the flat fields; arguments are target, source.
  fn copy_from(Self, Texture, Texture) -> Unit = _
  /// Adds to the serialized texture after the standard fields.
  fn to_json(Self, Texture, ToJsonMeta?, Map[String, Json]) -> Unit = _
}

///|
impl TextureExtension with fn payload(self) {
  JsValue::of(self)
}

///|
impl TextureExtension with fn has_flag(_, _) {
  false
}

///|
impl TextureExtension with fn copy_from(_, _, _) {

}

///|
impl TextureExtension with fn to_json(_, _, _, _) {

}

///|
/// Upstream subclasses of `RenderTarget` that live above core, such as
/// `WebGLRenderTarget`.
pub(open) trait RenderTargetExtension {
  /// `new this.constructor()`.
  fn construct(Self) -> RenderTarget
  fn payload(Self) -> JsValue = _
  /// Answers upstream `isFoo` checks: `has_flag("isXRRenderTarget")`.
  fn has_flag(Self, String) -> Bool = _
  /// Runs after `RenderTarget::copy` has copied the fields; arguments are target, source.
  fn copy_from(Self, RenderTarget, RenderTarget) -> Unit = _
}

///|
impl RenderTargetExtension with fn payload(self) {
  JsValue::of(self)
}

///|
impl RenderTargetExtension with fn has_flag(_, _) {
  false
}

///|
impl RenderTargetExtension with fn copy_from(_, _, _) {

}

///|
/// Sets the extension of a subclass above core and takes `type_` from it.
pub fn Object3D::set_extension(
  self : Object3D,
  extension : &Object3DExtension,
) -> Object3D {
  self.extension = Some(extension)
  self.type_ = extension.type_name()
  self
}

///|
/// Upstream's `isFoo` flag of a class above core.
pub fn Object3D::has_extension_flag(self : Object3D, flag : String) -> Bool {
  match self.extension {
    Some(extension) => extension.has_flag(flag)
    None => false
  }
}

///|
/// Sets the extension of a subclass above core and takes `type_` from it.
pub fn Material::set_extension(
  self : Material,
  extension : &MaterialExtension,
) -> Material {
  self.extension = Some(extension)
  self.type_ = extension.type_name()
  self
}

///|
/// Upstream's `isFoo` flag of a class above core.
pub fn Material::has_extension_flag(self : Material, flag : String) -> Bool {
  match self.extension {
    Some(extension) => extension.has_flag(flag)
    None => false
  }
}

///|
/// `material.isNodeMaterial`.
pub fn Material::is_node_material(self : Material) -> Bool {
  self.has_extension_flag("isNodeMaterial")
}

///|
/// Sets the extension of a subclass above core.
pub fn Texture::set_extension(
  self : Texture,
  extension : &TextureExtension,
) -> Texture {
  self.extension = Some(extension)
  self
}

///|
/// Upstream's `isFoo` flag of a class above core.
pub fn Texture::has_extension_flag(self : Texture, flag : String) -> Bool {
  match self.extension {
    Some(extension) => extension.has_flag(flag)
    None => false
  }
}

///|
/// Sets the extension of a subclass above core.
pub fn RenderTarget::set_extension(
  self : RenderTarget,
  extension : &RenderTargetExtension,
) -> RenderTarget {
  self.extension = Some(extension)
  self
}

///|
/// Upstream's `isFoo` flag of a class above core.
pub fn RenderTarget::has_extension_flag(
  self : RenderTarget,
  flag : String,
) -> Bool {
  match self.extension {
    Some(extension) => extension.has_flag(flag)
    None => false
  }
}
