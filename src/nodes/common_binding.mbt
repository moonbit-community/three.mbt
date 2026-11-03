// renderers/common/Binding.js: the base class and the class chain of its subclasses
// (Buffer, UniformBuffer, UniformsGroup, StorageBuffer, Sampler, SampledTexture and the
// node bindings). The members introduced below `Binding` (`update`, `buffer`, `texture`,
// ...) are `BindingClass` methods whose defaults walk to `parent`, so an unoverridden
// member falls through to the nearest superclass, and a member no class in the chain has
// aborts like upstream's `TypeError`.

///|
/// The overridable members of `Binding` subclasses; defaults walk to `parent`.
pub(open) trait BindingClass {
  fn class_name(Self) -> String
  fn parent(Self) -> &BindingClass? = _
  fn payload(Self) -> @core.JsValue = _
  fn has_flag(Self, String) -> Bool = _
  /// `binding.groupNode` of the node bindings (`NodeUniformBuffer`, `NodeSampler`, ...).
  fn group_node(Self) -> Node? = _
  /// `new this.constructor()` then `Object.assign` of the class fields: a shallow copy
  /// of the payload chain (constructor side effects such as id counters included).
  fn copy_class(Self) -> &BindingClass = _
  /// `clone()`.
  fn clone(Self, Binding) -> Binding = _
  /// `update()`: whether the binding changed.
  fn update(Self, Binding) -> Bool = _
  /// `release()`.
  fn release(Self, Binding) -> Unit = _
  /// `get buffer()`; `None` is `null`.
  fn buffer(Self, Binding) -> @core.TypedArray? = _
  /// `get byteLength()`.
  fn byte_length(Self, Binding) -> Int32 = _
  /// `get updateRanges()`.
  fn update_ranges(Self, Binding) -> Array[@core.UpdateRange] = _
  /// `set updateRanges( value )`.
  fn set_update_ranges(Self, Binding, Array[@core.UpdateRange]) -> Unit = _
  /// `addUpdateRange( start, count )`.
  fn add_update_range(Self, Binding, Int32, Int32) -> Unit = _
  /// `clearUpdateRanges()`.
  fn clear_update_ranges(Self, Binding) -> Unit = _
  /// `get texture()` of samplers; `None` is `null`.
  fn texture(Self, Binding) -> @core.Texture? = _
  /// `set texture( value )` of samplers.
  fn set_texture(Self, Binding, @core.Texture?) -> Unit = _
  /// `get attribute()` of storage buffers.
  fn attribute(Self, Binding) -> @core.BufferAttribute? = _
}

///|
impl BindingClass with fn parent(_) {
  None
}

///|
impl BindingClass with fn payload(self) {
  @core.JsValue::of(self)
}

///|
impl BindingClass with fn has_flag(self, flag) {
  match self.parent() {
    Some(p) => p.has_flag(flag)
    None => false
  }
}

///|
impl BindingClass with fn group_node(self) {
  match self.parent() {
    Some(p) => p.group_node()
    None => None
  }
}

///|
impl BindingClass with fn copy_class(self) {
  abort("Binding::clone: \{self.class_name()} has no copy_class")
}

///|
impl BindingClass with fn clone(self, binding) {
  match self.parent() {
    Some(p) => p.clone(binding)
    None => binding.clone_base()
  }
}

///|
impl BindingClass with fn update(self, binding) {
  match self.parent() {
    Some(p) => p.update(binding)
    None => abort("TypeError: binding.update is not a function")
  }
}

///|
impl BindingClass with fn release(self, binding) {
  match self.parent() {
    Some(p) => p.release(binding)
    None => abort("TypeError: binding.release is not a function")
  }
}

///|
impl BindingClass with fn buffer(self, binding) {
  match self.parent() {
    Some(p) => p.buffer(binding)
    None => None
  }
}

///|
impl BindingClass with fn byte_length(self, binding) {
  match self.parent() {
    Some(p) => p.byte_length(binding)
    None =>
      abort(
        "TypeError: Cannot read properties of undefined (reading 'byteLength')",
      )
  }
}

///|
impl BindingClass with fn update_ranges(self, binding) {
  match self.parent() {
    Some(p) => p.update_ranges(binding)
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'length')")
  }
}

///|
impl BindingClass with fn set_update_ranges(self, binding, value) {
  match self.parent() {
    Some(p) => p.set_update_ranges(binding, value)
    None => abort("Binding: updateRanges has no setter")
  }
}

///|
impl BindingClass with fn add_update_range(self, binding, start, count) {
  match self.parent() {
    Some(p) => p.add_update_range(binding, start, count)
    None => abort("TypeError: binding.addUpdateRange is not a function")
  }
}

///|
impl BindingClass with fn clear_update_ranges(self, binding) {
  match self.parent() {
    Some(p) => p.clear_update_ranges(binding)
    None => abort("TypeError: binding.clearUpdateRanges is not a function")
  }
}

///|
impl BindingClass with fn texture(self, binding) {
  match self.parent() {
    Some(p) => p.texture(binding)
    None => None
  }
}

///|
impl BindingClass with fn set_texture(self, binding, value) {
  match self.parent() {
    Some(p) => p.set_texture(binding, value)
    None => abort("Binding: texture has no setter")
  }
}

///|
impl BindingClass with fn attribute(self, binding) {
  match self.parent() {
    Some(p) => p.attribute(binding)
    None => None
  }
}

///|
/// The class of a plain `new Binding( name )`.
pub(all) struct BaseBinding {}

///|
pub impl BindingClass for BaseBinding with fn class_name(_) {
  "Binding"
}

///|
pub impl BindingClass for BaseBinding with fn copy_class(_) {
  BaseBinding::{ }
}

///|
/// Upstream's `Binding` fields; `class_` is the most derived class payload.
pub(all) struct Binding {
  mut name : String
  mut visibility : Int32
  mut class_ : &BindingClass
}

///|
/// `new Binding( name = '' )`.
pub fn Binding::new(name~ : String = "") -> Binding {
  { name, visibility: 0, class_: BaseBinding::{ }, }
}

///|
pub fn Binding::set_visibility(self : Binding, visibility : Int32) -> Unit {
  self.visibility = self.visibility | visibility
}

///|
/// `clone()`: `Object.assign( new this.constructor(), this )`, then the subclass's
/// own adjustments.
pub fn Binding::clone(self : Binding) -> Binding {
  self.class_.clone(self)
}

///|
/// `Binding.prototype.clone`: `Object.assign( new this.constructor(), this )`.
pub fn Binding::clone_base(self : Binding) -> Binding {
  {
    name: self.name,
    visibility: self.visibility,
    class_: self.class_.copy_class(),
  }
}

///|
/// An upstream `isFoo` flag of the binding's class.
pub fn Binding::has_flag(self : Binding, flag : String) -> Bool {
  self.class_.has_flag(flag)
}

///|
/// `binding.groupNode`; `None` for bindings without a group node.
pub fn Binding::group_node(self : Binding) -> Node? {
  self.class_.group_node()
}

///|
/// Finds the payload of class `name` in the chain, as a JS value for `X::of` to cast.
pub fn Binding::class_payload(self : Binding, name : String) -> @core.JsValue? {
  let mut c : &BindingClass? = Some(self.class_)
  while c is Some(k) {
    if k.class_name() == name {
      return Some(k.payload())
    }
    c = k.parent()
  }
  None
}

///|
/// `update()`.
pub fn Binding::update(self : Binding) -> Bool {
  self.class_.update(self)
}

///|
/// `release()`.
pub fn Binding::release(self : Binding) -> Unit {
  self.class_.release(self)
}

///|
/// `get buffer()`; `None` is `null`.
pub fn Binding::buffer(self : Binding) -> @core.TypedArray? {
  self.class_.buffer(self)
}

///|
/// `get byteLength()`.
pub fn Binding::byte_length(self : Binding) -> Int32 {
  self.class_.byte_length(self)
}

///|
/// `get updateRanges()`.
pub fn Binding::update_ranges(self : Binding) -> Array[@core.UpdateRange] {
  self.class_.update_ranges(self)
}

///|
/// `set updateRanges( value )`.
pub fn Binding::set_update_ranges(
  self : Binding,
  value : Array[@core.UpdateRange],
) -> Unit {
  self.class_.set_update_ranges(self, value)
}

///|
/// `addUpdateRange( start, count )`.
pub fn Binding::add_update_range(
  self : Binding,
  start : Int32,
  count : Int32,
) -> Unit {
  self.class_.add_update_range(self, start, count)
}

///|
/// `clearUpdateRanges()`.
pub fn Binding::clear_update_ranges(self : Binding) -> Unit {
  self.class_.clear_update_ranges(self)
}

///|
/// `get texture()` of samplers; `None` is `null`.
pub fn Binding::texture(self : Binding) -> @core.Texture? {
  self.class_.texture(self)
}

///|
/// `set texture( value )` of samplers.
pub fn Binding::set_texture(self : Binding, value : @core.Texture?) -> Unit {
  self.class_.set_texture(self, value)
}

///|
/// `get attribute()` of storage buffers.
pub fn Binding::attribute(self : Binding) -> @core.BufferAttribute? {
  self.class_.attribute(self)
}
