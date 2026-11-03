// renderers/common/RenderList.js

///|
/// `object.occlusionTest` (set by applications); core objects have no such field.
let _render_list_occlusion_tests : @webgl.WeakMap[@core.Object3D, Bool] = @webgl.WeakMap::new()

///|
/// `object.occlusionTest = value`.
pub fn set_occlusion_test(object : @core.Object3D, value : Bool) -> Unit {
  _render_list_occlusion_tests.set(object, value)
}

///|
/// `object.occlusionTest === true`.
pub fn occlusion_test(object : @core.Object3D) -> Bool {
  _render_list_occlusion_tests.get(object) == Some(true)
}

///|
/// One entry of a render list; reused across frames, with every field `null` when
/// unused (`id` is `None`).
pub(all) struct RenderItem {
  mut id : Int32?
  mut object : @core.Object3D?
  mut geometry : @core.BufferGeometry?
  mut material : @core.Material?
  mut group_order : Int32?
  mut render_order : Double?
  mut z : Double?
  mut group : @core.GeometryGroup?
  mut clipping_context : ClippingContext?
}

///|
fn _render_list_num(value : Double?) -> Double {
  match value {
    Some(v) => v
    None => 0.0
  }
}

///|
fn _render_list_int(value : Int32?) -> Double {
  match value {
    Some(v) => v.to_double()
    None => 0.0
  }
}

///|
/// `painterSortStable( a, b )`.
pub fn painter_sort_stable(a : RenderItem, b : RenderItem) -> Double {
  if a.group_order != b.group_order {
    _render_list_int(a.group_order) - _render_list_int(b.group_order)
  } else if a.render_order != b.render_order {
    _render_list_num(a.render_order) - _render_list_num(b.render_order)
  } else if a.z != b.z {
    _render_list_num(a.z) - _render_list_num(b.z)
  } else {
    _render_list_int(a.id) - _render_list_int(b.id)
  }
}

///|
/// `reversePainterSortStable( a, b )`.
pub fn reverse_painter_sort_stable(a : RenderItem, b : RenderItem) -> Double {
  if a.group_order != b.group_order {
    _render_list_int(a.group_order) - _render_list_int(b.group_order)
  } else if a.render_order != b.render_order {
    _render_list_num(a.render_order) - _render_list_num(b.render_order)
  } else if a.z != b.z {
    _render_list_num(b.z) - _render_list_num(a.z)
  } else {
    _render_list_int(a.id) - _render_list_int(b.id)
  }
}

///|
/// `needsDoublePass( material )`: transmissive double-sided materials render twice.
fn _render_list_needs_double_pass(material : @core.Material) -> Bool {
  let has_transmission = material.transmission().unwrap_or(0.0) > 0.0 ||
    material_node_property_is_set(material, "transmissionNode")
  has_transmission &&
  material.side == @core.DoubleSide &&
  material.force_single_pass == false
}

///|
/// Whether the material goes in the transparent list.
fn _render_list_is_transparent(material : @core.Material) -> Bool {
  material.transparent ||
  material.transmission().unwrap_or(0.0) > 0.0 ||
  material_node_property_is_set(material, "transmissionNode") ||
  material_node_property_is_set(material, "backdropNode")
}

///|
/// The objects of one scene and camera in a frame, sorted for drawing.
pub struct RenderList {
  render_items : Array[RenderItem]
  mut render_items_index : Int32
  opaque_ : Array[RenderItem]
  transparent_double_pass : Array[RenderItem]
  transparent : Array[RenderItem]
  /// The `{ bundleGroup, camera, renderList }` records of the `BundleGroup`s.
  bundles : Array[RenderListBundle]
  lighting : Lighting
  lights_node : Node
  lights_array : Array[@core.Object3D]
  scene : @core.Object3D
  camera : @core.Object3D
  mut occlusion_query_count : Int32
  mut frame_id : Int32
  priv mut _last_occlusion_object : @core.Object3D?
}

///|
/// `new RenderList( lighting, scene, camera )`.
pub fn RenderList::new(
  lighting : Lighting,
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> RenderList {
  RenderList::with_lights_node(
    lighting,
    lighting.get_node(scene),
    scene,
    camera,
  )
}

///|
/// The constructor body with `lightsNode = lighting.getNode( scene )` given.
pub fn RenderList::with_lights_node(
  lighting : Lighting,
  lights_node : Node,
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> RenderList {
  {
    render_items: [],
    render_items_index: 0,
    opaque_: [],
    transparent_double_pass: [],
    transparent: [],
    bundles: [],
    lighting,
    lights_node,
    lights_array: [],
    scene,
    camera,
    occlusion_query_count: 0,
    frame_id: -1,
    _last_occlusion_object: None,
  }
}

///|
/// `begin()`: empties the lists for a new frame.
pub fn RenderList::begin(self : RenderList) -> RenderList {
  self.render_items_index = 0
  self.opaque_.clear()
  self.transparent_double_pass.clear()
  self.transparent.clear()
  self.bundles.clear()
  self.lights_array.clear()
  self.occlusion_query_count = 0
  self
}

///|
/// `getNextRenderItem( object, geometry, material, groupOrder, z, group,
/// clippingContext )`.
pub fn RenderList::get_next_render_item(
  self : RenderList,
  object : @core.Object3D,
  geometry : @core.BufferGeometry,
  material : @core.Material,
  group_order : Int32,
  z : Double,
  group : @core.GeometryGroup?,
  clipping_context : ClippingContext?,
) -> RenderItem {
  let render_item = if self.render_items_index < self.render_items.length() {
    let render_item = self.render_items[self.render_items_index]
    render_item.id = Some(object.id)
    render_item.object = Some(object)
    render_item.geometry = Some(geometry)
    render_item.material = Some(material)
    render_item.group_order = Some(group_order)
    render_item.render_order = Some(object.render_order)
    render_item.z = Some(z)
    render_item.group = group
    render_item.clipping_context = clipping_context
    render_item
  } else {
    let render_item = {
      id: Some(object.id),
      object: Some(object),
      geometry: Some(geometry),
      material: Some(material),
      group_order: Some(group_order),
      render_order: Some(object.render_order),
      z: Some(z),
      group,
      clipping_context,
    }
    self.render_items.push(render_item)
    render_item
  }
  self.render_items_index += 1
  render_item
}

///|
/// `push( object, geometry, material, groupOrder, z, group, clippingContext )`.
pub fn RenderList::push(
  self : RenderList,
  object : @core.Object3D,
  geometry : @core.BufferGeometry,
  material : @core.Material,
  group_order : Int32,
  z : Double,
  group : @core.GeometryGroup?,
  clipping_context : ClippingContext?,
) -> Unit {
  let z = if self.camera.reversed_depth() { -z } else { z }
  let render_item = self.get_next_render_item(
    object, geometry, material, group_order, z, group, clipping_context,
  )
  if occlusion_test(object) &&
    !(self._last_occlusion_object is Some(o) && physical_equal(o, object)) {
    self.occlusion_query_count += 1
    self._last_occlusion_object = Some(object)
  }
  if _render_list_is_transparent(material) {
    if _render_list_needs_double_pass(material) {
      self.transparent_double_pass.push(render_item)
    }
    self.transparent.push(render_item)
  } else {
    self.opaque_.push(render_item)
  }
}

///|
/// `unshift( object, geometry, material, groupOrder, z, group, clippingContext )`.
pub fn RenderList::unshift(
  self : RenderList,
  object : @core.Object3D,
  geometry : @core.BufferGeometry,
  material : @core.Material,
  group_order : Int32,
  z : Double,
  group : @core.GeometryGroup?,
  clipping_context : ClippingContext?,
) -> Unit {
  let render_item = self.get_next_render_item(
    object, geometry, material, group_order, z, group, clipping_context,
  )
  if _render_list_is_transparent(material) {
    if _render_list_needs_double_pass(material) {
      self.transparent_double_pass.insert(0, render_item)
    }
    self.transparent.insert(0, render_item)
  } else {
    self.opaque_.insert(0, render_item)
  }
}

///|
/// The record `StandardDrawingPipeline.project` pushes for a `BundleGroup` (added by G6).
pub(all) struct RenderListBundle {
  bundle_group : @core.Object3D
  camera : @core.Object3D
  render_list : RenderList
}

///|
/// `pushBundle( group )`.
pub fn RenderList::push_bundle(
  self : RenderList,
  group : RenderListBundle,
) -> Unit {
  self.bundles.push(group)
}

///|
/// `pushLight( light )`.
pub fn RenderList::push_light(
  self : RenderList,
  light : @core.Object3D,
) -> Unit {
  self.lights_array.push(light)
}

///|
/// `sort( customOpaqueSort, customTransparentSort )`.
pub fn RenderList::sort(
  self : RenderList,
  custom_opaque_sort : ((RenderItem, RenderItem) -> Double)?,
  custom_transparent_sort : ((RenderItem, RenderItem) -> Double)?,
) -> Unit {
  if self.opaque_.length() > 1 {
    @webgl.stable_sort_by(
      self.opaque_,
      custom_opaque_sort.unwrap_or(painter_sort_stable),
    )
  }
  if self.transparent_double_pass.length() > 1 {
    @webgl.stable_sort_by(
      self.transparent_double_pass,
      custom_transparent_sort.unwrap_or(reverse_painter_sort_stable),
    )
  }
  if self.transparent.length() > 1 {
    @webgl.stable_sort_by(
      self.transparent,
      custom_transparent_sort.unwrap_or(reverse_painter_sort_stable),
    )
  }
}

///|
/// `finish()`: hands the lights to the lights node and releases unused items.
pub fn RenderList::finish(self : RenderList) -> Unit {
  _render_list_set_lights(
    self.lights_node,
    if self.lighting.enabled {
      self.lights_array
    } else {
      []
    },
  )
  for i in self.render_items_index..<self.render_items.length() {
    let render_item = self.render_items[i]
    if render_item.id is None {
      break
    }
    _render_list_reset_render_item(render_item)
  }
  self._last_occlusion_object = None
}

///|
/// `clear()`.
pub fn RenderList::clear(self : RenderList) -> Unit {
  for render_item in self.render_items {
    if render_item.id is None {
      break
    }
    _render_list_reset_render_item(render_item)
  }
  self.opaque_.clear()
  self.transparent_double_pass.clear()
  self.transparent.clear()
  self.bundles.clear()
}

///|
/// `resetRenderItem( renderItem )`.
fn _render_list_reset_render_item(render_item : RenderItem) -> Unit {
  render_item.id = None
  render_item.object = None
  render_item.geometry = None
  render_item.material = None
  render_item.group_order = None
  render_item.render_order = None
  render_item.z = None
  render_item.group = None
  render_item.clipping_context = None
}

///|
/// `lightsNode.setLights( lights )`.
fn _render_list_set_lights(
  lights_node : Node,
  lights : Array[@core.Object3D],
) -> Unit {
  LightsNode::set_lights(lights_node, lights) |> ignore
}
