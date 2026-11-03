// renderers/common/SampledTexture.js: `SampledTexture`, `SampledArrayTexture`,
// `Sampled3DTexture`, `SampledCubeTexture`.

///|
let _sampled_texture_id : Ref[Int32] = Ref(0)

///|
/// The `SampledTexture` class payload.
pub(all) struct SampledTexture {
  parent_ : Sampler
  mut id : Int32
  mut store : Bool
  mut mip_level : Int32
}

///|
pub impl BindingClass for SampledTexture with fn class_name(_) {
  "SampledTexture"
}

///|
pub impl BindingClass for SampledTexture with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl BindingClass for SampledTexture with fn has_flag(self, flag) {
  flag == "isSampledTexture" || self.parent_.has_flag(flag)
}

///|
pub impl BindingClass for SampledTexture with fn copy_class(self) {
  self.copy_payload()
}

///|
/// `new this.constructor()` (which takes the next id) then `Object.assign`.
pub fn SampledTexture::copy_payload(self : SampledTexture) -> SampledTexture {
  _sampled_texture_id.val += 1
  {
    parent_: self.parent_.copy_payload(),
    id: self.id,
    store: self.store,
    mip_level: self.mip_level,
  }
}

///|
/// The payload of `super( name, texture )` for subclasses.
pub fn SampledTexture::construct(texture : @core.Texture?) -> SampledTexture {
  let id = _sampled_texture_id.val
  _sampled_texture_id.val += 1
  { parent_: Sampler::construct(texture), id, store: false, mip_level: 0, }
}

///|
/// `new SampledTexture( name, texture )`.
pub fn SampledTexture::new(name : String, texture : @core.Texture?) -> Binding {
  let binding = Binding::new(name~)
  binding.class_ = SampledTexture::construct(texture)
  binding
}

///|
pub fn SampledTexture::of(binding : Binding) -> SampledTexture? {
  match binding.class_payload("SampledTexture") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn _sampled_texture(binding : Binding) -> SampledTexture {
  match SampledTexture::of(binding) {
    Some(s) => s
    None => abort("TypeError: \{binding.name} is not a SampledTexture")
  }
}

///|
/// `sampledTexture.store`.
pub fn Binding::store(self : Binding) -> Bool {
  _sampled_texture(self).store
}

///|
/// `sampledTexture.mipLevel`.
pub fn Binding::mip_level(self : Binding) -> Int32 {
  _sampled_texture(self).mip_level
}

///|
/// The `SampledArrayTexture` class payload.
pub(all) struct SampledArrayTexture {
  parent_ : SampledTexture
}

///|
pub impl BindingClass for SampledArrayTexture with fn class_name(_) {
  "SampledArrayTexture"
}

///|
pub impl BindingClass for SampledArrayTexture with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl BindingClass for SampledArrayTexture with fn has_flag(self, flag) {
  flag == "isSampledArrayTexture" || self.parent_.has_flag(flag)
}

///|
pub impl BindingClass for SampledArrayTexture with fn copy_class(self) {
  SampledArrayTexture::{ parent_: self.parent_.copy_payload(), }
}

///|
/// `new SampledArrayTexture( name, texture )`.
pub fn SampledArrayTexture::new(
  name : String,
  texture : @core.Texture?,
) -> Binding {
  let binding = Binding::new(name~)
  binding.class_ = SampledArrayTexture::{
    parent_: SampledTexture::construct(texture),
  }
  binding
}

///|
/// The `Sampled3DTexture` class payload.
pub(all) struct Sampled3DTexture {
  parent_ : SampledTexture
}

///|
pub impl BindingClass for Sampled3DTexture with fn class_name(_) {
  "Sampled3DTexture"
}

///|
pub impl BindingClass for Sampled3DTexture with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl BindingClass for Sampled3DTexture with fn has_flag(self, flag) {
  flag == "isSampled3DTexture" || self.parent_.has_flag(flag)
}

///|
pub impl BindingClass for Sampled3DTexture with fn copy_class(self) {
  Sampled3DTexture::{ parent_: self.parent_.copy_payload(), }
}

///|
/// `new Sampled3DTexture( name, texture )`.
pub fn Sampled3DTexture::new(
  name : String,
  texture : @core.Texture?,
) -> Binding {
  let binding = Binding::new(name~)
  binding.class_ = Sampled3DTexture::{
    parent_: SampledTexture::construct(texture),
  }
  binding
}

///|
/// The `SampledCubeTexture` class payload.
pub(all) struct SampledCubeTexture {
  parent_ : SampledTexture
}

///|
pub impl BindingClass for SampledCubeTexture with fn class_name(_) {
  "SampledCubeTexture"
}

///|
pub impl BindingClass for SampledCubeTexture with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl BindingClass for SampledCubeTexture with fn has_flag(self, flag) {
  flag == "isSampledCubeTexture" || self.parent_.has_flag(flag)
}

///|
pub impl BindingClass for SampledCubeTexture with fn copy_class(self) {
  SampledCubeTexture::{ parent_: self.parent_.copy_payload(), }
}

///|
/// `new SampledCubeTexture( name, texture )`.
pub fn SampledCubeTexture::new(
  name : String,
  texture : @core.Texture?,
) -> Binding {
  let binding = Binding::new(name~)
  binding.class_ = SampledCubeTexture::{
    parent_: SampledTexture::construct(texture),
  }
  binding
}
