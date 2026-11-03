// renderers/common/ProgrammableStage.js

///|
let _programmable_stage_id : Ref[Int32] = Ref(0)

///|
/// A shader stage: its code and how many pipelines use it.
pub(all) struct ProgrammableStage {
  id : Int32
  code : String
  /// `'vertex'`, `'fragment'` or `'compute'`.
  stage : String
  name : String
  mut used_times : Int32
}

///|
/// `new ProgrammableStage( code, stage, name )`.
pub fn ProgrammableStage::new(
  code : String,
  stage : String,
  name : String,
) -> ProgrammableStage {
  let id = _programmable_stage_id.val
  _programmable_stage_id.val += 1
  { id, code, stage, name, used_times: 0, }
}
