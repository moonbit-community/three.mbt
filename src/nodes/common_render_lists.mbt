// renderers/common/RenderLists.js

///|
/// The render lists by scene, camera and lighting; lists unused for more than ten
/// frames are cleared.
pub struct RenderLists {
  priv mut lists : ChainMap[RenderList]
  priv _active_lists : RefSet[RenderList]
  priv mut _frame_id : Int32
}

///|
/// `new RenderLists()`.
pub fn RenderLists::new() -> RenderLists {
  { lists: ChainMap::new(), _active_lists: RefSet::new(), _frame_id: -1, }
}

///|
/// `get( scene, camera, lighting )`.
pub fn RenderLists::get(
  self : RenderLists,
  scene : @core.Object3D,
  camera : @core.Object3D,
  lighting : Lighting,
) -> RenderList {
  let lists = self.lists
  let chain_keys = [
    @core.JsValue::of(scene),
    @core.JsValue::of(camera),
    @core.JsValue::of(lighting),
  ]
  let list = match lists.get(chain_keys) {
    Some(list) => list
    None => {
      let list = RenderList::new(lighting, scene, camera)
      lists.set(chain_keys, list) |> ignore
      list
    }
  }
  list.frame_id = self._frame_id
  self._active_lists.add(list)
  list
}

///|
/// `update( frameId )`: clears the lists not used in the last ten frames.
pub fn RenderLists::update(self : RenderLists, frame_id : Int32) -> Unit {
  if frame_id == self._frame_id {
    return
  }
  self._frame_id = frame_id
  self._active_lists.each(fn(list) {
    if frame_id - list.frame_id > 10 {
      list.clear()
      self._active_lists.delete(list)
    }
  })
}

///|
/// `dispose()`.
pub fn RenderLists::dispose(self : RenderLists) -> Unit {
  self.lists = ChainMap::new()
  self._active_lists.clear()
  self._frame_id = -1
}
