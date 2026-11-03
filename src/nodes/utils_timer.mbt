// nodes/utils/Timer.js: the `time`, `deltaTime` and `frameId` uniforms, updated once
// per render.

///|
/// `time`: the elapsed time in seconds.
pub let time : Node = module_nodes("nodes/utils/Timer.js:time", fn() {
  uniform(0)
  .set_group(render_group)
  .on_render_update(fn(n, frame) {
    InputNode::set_value(n, Number(frame.time))
    None
  })
})

///|
/// `deltaTime`: the time since the last frame in seconds.
pub let delta_time : Node = module_nodes("nodes/utils/Timer.js:deltaTime", fn() {
  uniform(0)
  .set_group(render_group)
  .on_render_update(fn(n, frame) {
    InputNode::set_value(n, Number(frame.delta_time))
    None
  })
})

///|
/// `frameId`: the frame number.
pub let frame_id : Node = module_nodes("nodes/utils/Timer.js:frameId", fn() {
  uniform(0, type_="uint")
  .set_group(render_group)
  .on_render_update(fn(n, frame) {
    InputNode::set_value(n, Number(frame.frame_id.to_double()))
    None
  })
})
