// renderers/common/BindGroup.js

///|
let _bind_group_id : Ref[Int32] = Ref(0)

///|
/// A group of bindings shared by the shader stages of a pipeline.
pub(all) struct BindGroup {
  mut name : String
  mut bindings : Array[Binding]
  id : Int32
}

///|
/// `new BindGroup( name = '', bindings = [] )`.
pub fn BindGroup::new(
  name~ : String = "",
  bindings~ : Array[Binding] = [],
) -> BindGroup {
  let id = _bind_group_id.val
  _bind_group_id.val += 1
  { name, bindings, id, }
}

///|
pub fn BindGroup::clone(self : BindGroup) -> BindGroup {
  BindGroup::new(
    name=self.name,
    bindings=self.bindings.map(fn(b) { b.clone() }),
  )
}
