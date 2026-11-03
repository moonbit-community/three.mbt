// Upstream src/core/UniformsGroup.js.

///|
let _uniforms_group_id : Ref[Int32] = Ref(0)

///|
pub fn UniformsGroup::new() -> UniformsGroup {
  let id = _uniforms_group_id.val
  _uniforms_group_id.val += 1
  {
    id,
    dispatcher: EventDispatcher::new(),
    name: "",
    usage: StaticDrawUsage,
    uniforms: [],
  }
}

///|
pub impl EventSource for UniformsGroup with fn event_dispatcher(self) {
  self.dispatcher
}

///|
pub impl EventSource for UniformsGroup with fn event_target(self) {
  UniformsGroup(self)
}

///|
pub extend UniformsGroup with EventSource::{
  event_dispatcher,
  event_target,
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
pub fn UniformsGroup::add(
  self : UniformsGroup,
  uniform : Uniform,
) -> UniformsGroup {
  self.uniforms.push(Single(uniform))
  self
}

///|
/// `add` with an array of uniforms, which upstream's std140 layout treats as one entry.
pub fn UniformsGroup::add_array(
  self : UniformsGroup,
  uniforms : Array[Uniform],
) -> UniformsGroup {
  self.uniforms.push(Multiple(uniforms))
  self
}

///|
pub fn UniformsGroup::remove(
  self : UniformsGroup,
  uniform : Uniform,
) -> UniformsGroup {
  for i, entry in self.uniforms {
    if entry is Single(item) && physical_equal(item, uniform) {
      ignore(self.uniforms.remove(i))
      break
    }
  }
  self
}

///|
pub fn UniformsGroup::remove_array(
  self : UniformsGroup,
  uniforms : Array[Uniform],
) -> UniformsGroup {
  for i, entry in self.uniforms {
    if entry is Multiple(item) && physical_equal(item, uniforms) {
      ignore(self.uniforms.remove(i))
      break
    }
  }
  self
}

///|
pub fn UniformsGroup::set_name(
  self : UniformsGroup,
  name : String,
) -> UniformsGroup {
  self.name = name
  self
}

///|
pub fn UniformsGroup::set_usage(
  self : UniformsGroup,
  value : Int32,
) -> UniformsGroup {
  self.usage = value
  self
}

///|
pub fn UniformsGroup::dispose(self : UniformsGroup) -> Unit {
  self.dispatch_event(Event::new("dispose"))
}

///|
pub fn UniformsGroup::copy(
  self : UniformsGroup,
  source : UniformsGroup,
) -> UniformsGroup {
  self.name = source.name
  self.usage = source.usage
  let uniforms_source = source.uniforms
  self.uniforms.clear()
  for entry in uniforms_source {
    match entry {
      Single(uniform) => self.uniforms.push(Single(uniform.clone()))
      Multiple(array) => self.uniforms.push(Multiple(array.map(u => u.clone())))
    }
  }
  self
}

///|
pub fn UniformsGroup::clone(self : UniformsGroup) -> UniformsGroup {
  UniformsGroup::new().copy(self)
}
