// nodes/core/NodeFrame.js

///|
/// `{ renderId, frameId }` of one update reference: when it was last updated.
pub(all) struct NodeFrameMaps {
  mut render_id : Int32
  mut frame_id : Int32
}

///|
/// Runs node updates once per frame, render or object, as each node asks.
pub(all) struct NodeFrame {
  mut time : Double
  mut delta_time : Double
  mut frame_id : Int32
  mut render_id : Int32
  /// `lastTime`, set by the first `update()`; `None` is `undefined`.
  mut last_time : Double?
  /// Keyed by `node.updateReference( frame )`.
  update_map : @webgl.WeakMap[@core.JsValue, NodeFrameMaps]
  update_before_map : @webgl.WeakMap[@core.JsValue, NodeFrameMaps]
  update_after_map : @webgl.WeakMap[@core.JsValue, NodeFrameMaps]
  mut renderer : Renderer?
  mut material : @core.Material?
  mut camera : @core.Object3D?
  mut object : @core.Object3D?
  mut scene : @core.Object3D?
  mut compute : Node?
}

///|
pub fn NodeFrame::new() -> NodeFrame {
  {
    time: 0.0,
    delta_time: 0.0,
    frame_id: 0,
    render_id: 0,
    last_time: None,
    update_map: @webgl.WeakMap::new(),
    update_before_map: @webgl.WeakMap::new(),
    update_after_map: @webgl.WeakMap::new(),
    renderer: None,
    material: None,
    camera: None,
    object: None,
    scene: None,
    compute: None,
  }
}

///|
/// `_getMaps( referenceMap, nodeRef )`.
fn NodeFrame::_get_maps(
  _self : NodeFrame,
  reference_map : @webgl.WeakMap[@core.JsValue, NodeFrameMaps],
  node_ref : @core.JsValue,
) -> NodeFrameMaps {
  match reference_map.get(node_ref) {
    Some(maps) => maps
    None => {
      let maps = NodeFrameMaps::{ render_id: 0, frame_id: 0, }
      reference_map.set(node_ref, maps)
      maps
    }
  }
}

///|
pub fn NodeFrame::update_before_node(self : NodeFrame, node : Node) -> Unit {
  let update_type = node.get_update_before_type(frame=self)
  let reference = node.update_reference(Frame(self))
  if update_type == NodeUpdateType::frame() {
    let maps = self._get_maps(self.update_before_map, reference)
    if maps.frame_id != self.frame_id {
      let previous_frame_id = maps.frame_id
      maps.frame_id = self.frame_id
      if node.update_before(self) == Some(false) {
        maps.frame_id = previous_frame_id
      }
    }
  } else if update_type == NodeUpdateType::render() {
    let maps = self._get_maps(self.update_before_map, reference)
    if maps.render_id != self.render_id {
      let previous_render_id = maps.render_id
      maps.render_id = self.render_id
      if node.update_before(self) == Some(false) {
        maps.render_id = previous_render_id
      }
    }
  } else if update_type == NodeUpdateType::object() {
    node.update_before(self) |> ignore
  }
}

///|
pub fn NodeFrame::update_after_node(self : NodeFrame, node : Node) -> Unit {
  let update_type = node.get_update_after_type()
  let reference = node.update_reference(Frame(self))
  if update_type == NodeUpdateType::frame() {
    let maps = self._get_maps(self.update_after_map, reference)
    if maps.frame_id != self.frame_id {
      if node.update_after(self) != Some(false) {
        maps.frame_id = self.frame_id
      }
    }
  } else if update_type == NodeUpdateType::render() {
    let maps = self._get_maps(self.update_after_map, reference)
    if maps.render_id != self.render_id {
      if node.update_after(self) != Some(false) {
        maps.render_id = self.render_id
      }
    }
  } else if update_type == NodeUpdateType::object() {
    node.update_after(self) |> ignore
  }
}

///|
pub fn NodeFrame::update_node(self : NodeFrame, node : Node) -> Unit {
  let update_type = node.get_update_type()
  let reference = node.update_reference(Frame(self))
  if update_type == NodeUpdateType::frame() {
    let maps = self._get_maps(self.update_map, reference)
    if maps.frame_id != self.frame_id {
      if node.update(self) != Some(false) {
        maps.frame_id = self.frame_id
      }
    }
  } else if update_type == NodeUpdateType::render() {
    let maps = self._get_maps(self.update_map, reference)
    if maps.render_id != self.render_id {
      if node.update(self) != Some(false) {
        maps.render_id = self.render_id
      }
    }
  } else if update_type == NodeUpdateType::object() {
    node.update(self) |> ignore
  }
}

///|
extern "js" fn node_frame_performance_now() -> Double = "() => performance.now()"

///|
/// Advances the frame: `frameId`, `deltaTime` (seconds) and `time`.
pub fn NodeFrame::update(self : NodeFrame) -> Unit {
  self.frame_id += 1
  if self.last_time is None {
    self.last_time = Some(node_frame_performance_now())
  }
  self.delta_time = (node_frame_performance_now() - self.last_time.unwrap()) /
    1000.0
  self.last_time = Some(node_frame_performance_now())
  self.time += self.delta_time
}
