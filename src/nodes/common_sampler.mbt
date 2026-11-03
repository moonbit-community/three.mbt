// renderers/common/Sampler.js

///|
/// The `Sampler` class payload.
pub(all) struct Sampler {
  mut _texture : @core.Texture?
  mut version : Int32
  /// `null` until the bindings record the texture generation.
  mut generation : Int32?
  mut sampler_key : String
}

///|
pub impl BindingClass for Sampler with fn class_name(_) {
  "Sampler"
}

///|
pub impl BindingClass for Sampler with fn has_flag(_, flag) {
  flag == "isSampler"
}

///|
pub impl BindingClass for Sampler with fn copy_class(self) {
  self.copy_payload()
}

///|
pub impl BindingClass for Sampler with fn texture(self, _) {
  self._texture
}

///|
pub impl BindingClass for Sampler with fn set_texture(self, binding, value) {
  if _sampler_same_texture(self._texture, value) {
    return
  }
  self._texture = value
  binding.reset()
}

///|
pub impl BindingClass for Sampler with fn update(self, binding) {
  let texture = match binding.texture() {
    Some(t) => t
    None =>
      abort("TypeError: Cannot read properties of null (reading 'version')")
  }
  if self.version != texture.version {
    self.version = texture.version
    return true
  }
  false
}

///|
pub impl BindingClass for Sampler with fn release(self, _) {
  self._texture = None
}

///|
fn _sampler_same_texture(a : @core.Texture?, b : @core.Texture?) -> Bool {
  match (a, b) {
    (Some(x), Some(y)) => physical_equal(x, y)
    (None, None) => true
    _ => false
  }
}

///|
/// The fields `Object.assign` copies.
pub fn Sampler::copy_payload(self : Sampler) -> Sampler {
  {
    _texture: self._texture,
    version: self.version,
    generation: self.generation,
    sampler_key: self.sampler_key,
  }
}

///|
/// The payload of `super( name, texture )` for subclasses.
pub fn Sampler::construct(texture : @core.Texture?) -> Sampler {
  { _texture: texture, version: -1, generation: None, sampler_key: "", }
}

///|
/// `new Sampler( name, texture )`.
pub fn Sampler::new(name : String, texture : @core.Texture?) -> Binding {
  let binding = Binding::new(name~)
  binding.class_ = Sampler::construct(texture)
  binding
}

///|
pub fn Sampler::of(binding : Binding) -> Sampler? {
  match binding.class_payload("Sampler") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn _sampler(binding : Binding) -> Sampler {
  match Sampler::of(binding) {
    Some(s) => s
    None => abort("TypeError: \{binding.name} is not a Sampler")
  }
}

///|
/// `reset()`.
pub fn Binding::reset(self : Binding) -> Unit {
  let sampler = _sampler(self)
  sampler.generation = None
  sampler.version = -1
}

///|
/// `sampler.version`.
pub fn Binding::sampler_version(self : Binding) -> Int32 {
  _sampler(self).version
}

///|
/// `sampler.generation`; `None` is `null`.
pub fn Binding::generation(self : Binding) -> Int32? {
  _sampler(self).generation
}

///|
/// `sampler.generation = value`.
pub fn Binding::set_generation(self : Binding, value : Int32?) -> Unit {
  _sampler(self).generation = value
}

///|
/// `sampler.samplerKey`.
pub fn Binding::sampler_key(self : Binding) -> String {
  _sampler(self).sampler_key
}

///|
/// `sampler.samplerKey = value`.
pub fn Binding::set_sampler_key(self : Binding, value : String) -> Unit {
  _sampler(self).sampler_key = value
}
