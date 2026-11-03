// Upstream test/unit/src/renderers/webgl/WebGLRenderLists.tests.js. Upstream pushes plain
// objects; here they are meshes, and items are compared field by field.

///|
test "WebGLRenderLists get" {
  let render_lists = @webgl.WebGLRenderLists::new()
  let scene_a = @core.Scene::new()
  let scene_b = @core.Scene::new()
  let list_a = render_lists.get(scene_a, 0)
  let list_b = render_lists.get(scene_b, 0)
  inspect(list_a.opaque_.length() + list_a.transparent.length(), content="0")
  inspect(list_b.opaque_.length() + list_b.transparent.length(), content="0")
  assert_true(!physical_equal(list_a, list_b))
  assert_true(physical_equal(render_lists.get(scene_a, 0), list_a))
  assert_true(!physical_equal(render_lists.get(scene_a, 1), list_a))
}

///|
fn render_list_mesh(
  name : String,
  transparent : Bool,
) -> (@core.Object3D, @core.BufferGeometry, @core.Material) {
  let geometry = @core.BufferGeometry::new()
  let material = @core.MeshBasicMaterial::new()
  material.transparent = transparent
  let object = @core.Mesh::new(geometry~, material=Single(material))
  object.name = name
  (object, geometry, material)
}

///|
fn check_render_item(
  item : @webgl.RenderItem,
  object : @core.Object3D,
  geometry : @core.BufferGeometry,
  material : @core.Material,
  group_order : Double,
  z : Double,
) -> Unit raise {
  assert_eq(item.id, object.id)
  assert_true(physical_equal(item.object, object))
  assert_true(physical_equal(item.geometry, geometry))
  assert_true(physical_equal(item.material, material))
  assert_eq(item.material_variant, 0)
  assert_eq(item.group_order, group_order)
  assert_eq(item.render_order, 0.0)
  assert_eq(item.z, z)
  assert_true(item.group is None)
}

///|
test "WebGLRenderList init" {
  let list = @webgl.WebGLRenderList::new()
  let camera = @core.Camera::new()
  inspect(list.transparent.length(), content="0")
  inspect(list.opaque_.length(), content="0")
  let (o1, g1, m1) = render_list_mesh("a", true)
  let (o2, g2, m2) = render_list_mesh("b", false)
  list.push(o1, g1, m1, 0, 0, None, camera)
  list.push(o2, g2, m2, 0, 0, None, camera)
  inspect(list.transparent.length(), content="1")
  inspect(list.opaque_.length(), content="1")
  list.init()
  inspect(list.transparent.length(), content="0")
  inspect(list.opaque_.length(), content="0")
}

///|
test "WebGLRenderList push" {
  let list = @webgl.WebGLRenderList::new()
  let camera = @core.Camera::new()
  let (obj_a, geo_a, mat_a) = render_list_mesh("A", true)
  let (obj_b, geo_b, mat_b) = render_list_mesh("B", true)
  let (obj_c, geo_c, mat_c) = render_list_mesh("C", false)
  let (obj_d, geo_d, mat_d) = render_list_mesh("D", false)
  list.push(obj_a, geo_a, mat_a, 0, 0.5, None, camera)
  inspect(list.transparent.length(), content="1")
  inspect(list.opaque_.length(), content="0")
  check_render_item(list.transparent[0], obj_a, geo_a, mat_a, 0, 0.5)
  list.push(obj_b, geo_b, mat_b, 1, 1.5, None, camera)
  inspect(list.transparent.length(), content="2")
  inspect(list.opaque_.length(), content="0")
  check_render_item(list.transparent[1], obj_b, geo_b, mat_b, 1, 1.5)
  list.push(obj_c, geo_c, mat_c, 2, 2.5, None, camera)
  inspect(list.transparent.length(), content="2")
  inspect(list.opaque_.length(), content="1")
  check_render_item(list.opaque_[0], obj_c, geo_c, mat_c, 2, 2.5)
  list.push(obj_d, geo_d, mat_d, 3, 3.5, None, camera)
  inspect(list.transparent.length(), content="2")
  inspect(list.opaque_.length(), content="2")
  check_render_item(list.opaque_[1], obj_d, geo_d, mat_d, 3, 3.5)
}

///|
test "WebGLRenderList unshift" {
  let list = @webgl.WebGLRenderList::new()
  let (obj_a, geo_a, mat_a) = render_list_mesh("A", true)
  let (obj_b, geo_b, mat_b) = render_list_mesh("B", true)
  let (obj_c, geo_c, mat_c) = render_list_mesh("C", false)
  let (obj_d, geo_d, mat_d) = render_list_mesh("D", false)
  list.unshift(obj_a, geo_a, mat_a, 0, 0.5, None)
  inspect(list.transparent.length(), content="1")
  inspect(list.opaque_.length(), content="0")
  check_render_item(list.transparent[0], obj_a, geo_a, mat_a, 0, 0.5)
  list.unshift(obj_b, geo_b, mat_b, 1, 1.5, None)
  inspect(list.transparent.length(), content="2")
  check_render_item(list.transparent[0], obj_b, geo_b, mat_b, 1, 1.5)
  list.unshift(obj_c, geo_c, mat_c, 2, 2.5, None)
  inspect(list.opaque_.length(), content="1")
  check_render_item(list.opaque_[0], obj_c, geo_c, mat_c, 2, 2.5)
  list.unshift(obj_d, geo_d, mat_d, 3, 3.5, None)
  inspect(list.transparent.length(), content="2")
  inspect(list.opaque_.length(), content="2")
  check_render_item(list.opaque_[0], obj_d, geo_d, mat_d, 3, 3.5)
}

///|
test "WebGLRenderList sort" {
  let list = @webgl.WebGLRenderList::new()
  let camera = @core.Camera::new()
  let geometry = @core.BufferGeometry::new()
  let transparent = @core.MeshBasicMaterial::new()
  transparent.transparent = true
  let opaque_material = @core.MeshBasicMaterial::new()
  let items = [4, 5, 2, 3].map(id => {
    let o = @core.Mesh::new(geometry~, material=Single(opaque_material))
    o.name = id.to_string()
    // the comparators below read the id back from here
    o.user_data = @core.JsValue::of(id.to_double())
    o
  })
  for item in items {
    list.push(item, geometry, transparent, 0, 0, None, camera)
    list.push(item, geometry, opaque_material, 0, 0, None, camera)
  }
  let id = (it : @webgl.RenderItem) => (it.object.user_data.cast() : Double)
  list.sort(Some((a, b) => id(a) - id(b)), Some((a, b) => id(b) - id(a)))
  debug_inspect(
    list.opaque_.map(it => it.object.name),
    content=(
      #|["2", "3", "4", "5"]
    ),
  )
  debug_inspect(
    list.transparent.map(it => it.object.name),
    content=(
      #|["5", "4", "3", "2"]
    ),
  )
}
