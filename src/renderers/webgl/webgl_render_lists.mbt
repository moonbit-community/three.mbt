// Upstream src/renderers/webgl/WebGLRenderLists.js.

///|
/// One entry of a render list. Items are pooled; `finish` releases the references of the
/// unused tail as upstream does (`released` is upstream's `id === null`).
pub(all) struct RenderItem {
  mut id : Int32
  mut object : @core.Object3D
  mut geometry : @core.BufferGeometry
  mut material : @core.Material
  /// 2 for instanced meshes plus 1 for skinned meshes
  mut material_variant : Int32
  mut group_order : Double
  mut render_order : Double
  mut z : Double
  mut group : @core.GeometryGroup?
  mut released : Bool
}

///|
/// The default opaque sort.
pub fn painter_sort_stable(a : RenderItem, b : RenderItem) -> Double {
  if a.group_order != b.group_order {
    a.group_order - b.group_order
  } else if a.render_order != b.render_order {
    a.render_order - b.render_order
  } else if a.material.id != b.material.id {
    (a.material.id - b.material.id).to_double()
  } else if a.material_variant != b.material_variant {
    (a.material_variant - b.material_variant).to_double()
  } else if a.z != b.z {
    a.z - b.z
  } else {
    (a.id - b.id).to_double()
  }
}

///|
/// The default transparent and transmissive sort.
pub fn reverse_painter_sort_stable(a : RenderItem, b : RenderItem) -> Double {
  if a.group_order != b.group_order {
    a.group_order - b.group_order
  } else if a.render_order != b.render_order {
    a.render_order - b.render_order
  } else if a.z != b.z {
    b.z - a.z
  } else {
    (a.id - b.id).to_double()
  }
}

///|
pub struct WebGLRenderList {
  render_items : Array[RenderItem]
  mut render_items_index : Int32
  /// upstream `opaque` (a reserved word here)
  opaque_ : Array[RenderItem]
  transmissive : Array[RenderItem]
  transparent : Array[RenderItem]
}

///|
/// `new WebGLRenderList()`.
pub fn WebGLRenderList::new() -> WebGLRenderList {
  {
    render_items: [],
    render_items_index: 0,
    opaque_: [],
    transmissive: [],
    transparent: [],
  }
}

///|
/// `list.init()`.
pub fn WebGLRenderList::init(self : WebGLRenderList) -> Unit {
  self.render_items_index = 0
  self.opaque_.clear()
  self.transmissive.clear()
  self.transparent.clear()
}

///|
fn webgl_render_list_material_variant(object : @core.Object3D) -> Int32 {
  let mut variant = 0
  if object.is_instanced_mesh() {
    variant += 2
  }
  if object.is_skinned_mesh() {
    variant += 1
  }
  variant
}

///|
fn WebGLRenderList::get_next_render_item(
  self : WebGLRenderList,
  object : @core.Object3D,
  geometry : @core.BufferGeometry,
  material : @core.Material,
  group_order : Double,
  z : Double,
  group : @core.GeometryGroup?,
) -> RenderItem {
  let render_item = match self.render_items.get(self.render_items_index) {
    None => {
      let render_item : RenderItem = {
        id: object.id,
        object,
        geometry,
        material,
        material_variant: webgl_render_list_material_variant(object),
        group_order,
        render_order: object.render_order,
        z,
        group,
        released: false,
      }
      self.render_items.push(render_item)
      render_item
    }
    Some(render_item) => {
      render_item.id = object.id
      render_item.object = object
      render_item.geometry = geometry
      render_item.material = material
      render_item.material_variant = webgl_render_list_material_variant(object)
      render_item.group_order = group_order
      render_item.render_order = object.render_order
      render_item.z = z
      render_item.group = group
      render_item.released = false
      render_item
    }
  }
  self.render_items_index += 1
  render_item
}

///|
fn webgl_render_list_is_transmissive(material : @core.Material) -> Bool {
  match material.transmission() {
    Some(transmission) => transmission > 0.0
    None => false
  }
}

///|
/// `list.push( object, geometry, material, groupOrder, z, group, camera )`.
pub fn WebGLRenderList::push(
  self : WebGLRenderList,
  object : @core.Object3D,
  geometry : @core.BufferGeometry,
  material : @core.Material,
  group_order : Double,
  z : Double,
  group : @core.GeometryGroup?,
  camera : @core.Object3D,
) -> Unit {
  // with a reversed depth buffer the projected z is inverted
  let z = if camera.reversed_depth() { -z } else { z }
  let render_item = self.get_next_render_item(
    object, geometry, material, group_order, z, group,
  )
  if webgl_render_list_is_transmissive(material) {
    self.transmissive.push(render_item)
  } else if material.transparent {
    self.transparent.push(render_item)
  } else {
    self.opaque_.push(render_item)
  }
}

///|
/// `list.unshift( object, geometry, material, groupOrder, z, group )`.
pub fn WebGLRenderList::unshift(
  self : WebGLRenderList,
  object : @core.Object3D,
  geometry : @core.BufferGeometry,
  material : @core.Material,
  group_order : Double,
  z : Double,
  group : @core.GeometryGroup?,
) -> Unit {
  let render_item = self.get_next_render_item(
    object, geometry, material, group_order, z, group,
  )
  if webgl_render_list_is_transmissive(material) {
    self.transmissive.insert(0, render_item)
  } else if material.transparent {
    self.transparent.insert(0, render_item)
  } else {
    self.opaque_.insert(0, render_item)
  }
}

///|
/// `list.sort( customOpaqueSort, customTransparentSort )`.
pub fn WebGLRenderList::sort(
  self : WebGLRenderList,
  custom_opaque_sort : ((RenderItem, RenderItem) -> Double)?,
  custom_transparent_sort : ((RenderItem, RenderItem) -> Double)?,
) -> Unit {
  if self.opaque_.length() > 1 {
    stable_sort_by(
      self.opaque_,
      custom_opaque_sort.unwrap_or(painter_sort_stable),
    )
  }
  let transparent_sort = custom_transparent_sort.unwrap_or(
    reverse_painter_sort_stable,
  )
  if self.transmissive.length() > 1 {
    stable_sort_by(self.transmissive, transparent_sort)
  }
  if self.transparent.length() > 1 {
    stable_sort_by(self.transparent, transparent_sort)
  }
}

///|
/// `list.finish()`: clears references from inactive render items.
pub fn WebGLRenderList::finish(self : WebGLRenderList) -> Unit {
  for i in self.render_items_index..<self.render_items.length() {
    let render_item = self.render_items[i]
    if render_item.released {
      break
    }
    render_item.released = true
    render_item.object = uninitialized()
    render_item.geometry = uninitialized()
    render_item.material = uninitialized()
    render_item.group = None
  }
}

///|
pub struct WebGLRenderLists {
  /// scene -> one list per nested render call depth
  mut lists : WeakMap[@core.Object3D, Array[WebGLRenderList]]
}

///|
/// `new WebGLRenderLists()`.
pub fn WebGLRenderLists::new() -> WebGLRenderLists {
  { lists: WeakMap::new(), }
}

///|
/// `renderLists.get( scene, renderCallDepth )`.
pub fn WebGLRenderLists::get(
  self : WebGLRenderLists,
  scene : @core.Object3D,
  render_call_depth : Int32,
) -> WebGLRenderList {
  match self.lists.get(scene) {
    None => {
      let list = WebGLRenderList::new()
      self.lists.set(scene, [list])
      list
    }
    Some(list_array) =>
      if render_call_depth >= list_array.length() {
        let list = WebGLRenderList::new()
        list_array.push(list)
        list
      } else {
        list_array[render_call_depth]
      }
  }
}

///|
/// `renderLists.dispose()`.
pub fn WebGLRenderLists::dispose(self : WebGLRenderLists) -> Unit {
  self.lists = WeakMap::new()
}
