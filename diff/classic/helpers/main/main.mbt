// MoonBit side of the helpers differential check. Every function mirrors upstream.mjs
// line by line; both sides log through globalThis.__note* (defined in run_diff.mjs).

///|
extern "js" fn n(l : String, v : Double) -> Unit = "(l, v) => globalThis.__noteNum(l, v)"

///|
extern "js" fn s(l : String, v : String) -> Unit = "(l, v) => globalThis.__noteStr(l, v)"

///|
extern "js" fn t(l : String, v : @core.TypedArray) -> Unit = "(l, v) => globalThis.__noteTyped(l, v)"

///|
extern "js" fn js_sqrt(x : Double) -> Double = "Math.sqrt"

///|
fn b(l : String, v : Bool) -> Unit {
  s(l, if v { "true" } else { "false" })
}

///|
fn ni(l : String, v : Int) -> Unit {
  n(l, v.to_double())
}

///|
fn vec(l : String, v : @math.Vector3) -> Unit {
  n(l + ".x", v.x)
  n(l + ".y", v.y)
  n(l + ".z", v.z)
}

///|
fn quat(l : String, q : @math.Quaternion) -> Unit {
  n(l + ".x", q.x)
  n(l + ".y", q.y)
  n(l + ".z", q.z)
  n(l + ".w", q.w)
}

///|
fn mat(l : String, m : @math.Matrix4) -> Unit {
  for i in 0..<16 {
    n(l + "[" + i.to_string() + "]", m.elements[i])
  }
}

///|
fn color(l : String, c : @math.Color) -> Unit {
  n(l + ".r", c.r)
  n(l + ".g", c.g)
  n(l + ".b", c.b)
}

///|
fn[T] same(l : String, a : T, b : T) -> Unit {
  s(l, if physical_equal(a, b) { "same" } else { "diff" })
}

///|
fn opt_bool(v : Bool?) -> String {
  match v {
    Some(true) => "true"
    Some(false) => "false"
    None => "undefined"
  }
}

///|
fn dump_attribute(l : String, a : @core.GeometryAttribute) -> Unit {
  ni(l + ".itemSize", a.item_size())
  ni(l + ".count", a.count())
  b(l + ".normalized", a.normalized())
  ni(l + ".version", a.version())
  t(l + ".array", a.array())
}

///|
fn dump_geometry(l : String, g : @core.BufferGeometry) -> Unit {
  let names = g.attributes.keys().collect()
  s(l + ".attributes", names.join(","))
  for name in names {
    dump_attribute(l + "." + name, g.attributes[name])
  }
  match g.index {
    Some(index) => dump_attribute(l + ".index", index)
    None => s(l + ".index", "null")
  }
  match g.bounding_sphere {
    Some(sphere) => {
      vec(l + ".boundingSphere.center", sphere.center)
      n(l + ".boundingSphere.radius", sphere.radius)
    }
    None => s(l + ".boundingSphere", "null")
  }
  match g.bounding_box {
    Some(box) => {
      vec(l + ".boundingBox.min", box.min)
      vec(l + ".boundingBox.max", box.max)
    }
    None => s(l + ".boundingBox", "null")
  }
  ni(l + ".drawRange.start", g.draw_range.start)
  n(l + ".drawRange.count", g.draw_range.count)
  ni(l + ".groups", g.groups.length())
}

///|
fn dump_material(l : String, m : @core.Material) -> Unit {
  s(l + ".type", m.type_)
  color(l + ".color", m.color.unwrap())
  b(l + ".vertexColors", m.vertex_colors)
  b(l + ".toneMapped", m.tone_mapped)
  s(l + ".fog", opt_bool(m.fog))
  s(l + ".wireframe", opt_bool(m.wireframe))
  b(l + ".transparent", m.transparent)
  n(l + ".opacity", m.opacity)
  b(l + ".depthTest", m.depth_test)
  b(l + ".depthWrite", m.depth_write)
  ni(l + ".side", m.side)
  ni(l + ".version", m.version)
}

///|
fn dump_object(l : String, o : @core.Object3D) -> Unit {
  s(l + ".type", o.type_)
  b(l + ".visible", o.visible)
  b(l + ".matrixAutoUpdate", o.matrix_auto_update)
  b(l + ".matrixWorldAutoUpdate", o.matrix_world_auto_update)
  b(l + ".matrixWorldNeedsUpdate", o.matrix_world_needs_update)
  vec(l + ".position", o.position)
  quat(l + ".quaternion", o.quaternion)
  n(l + ".rotation.x", o.rotation.x)
  n(l + ".rotation.y", o.rotation.y)
  n(l + ".rotation.z", o.rotation.z)
  s(l + ".rotation.order", o.rotation.order)
  vec(l + ".scale", o.scale)
  mat(l + ".matrix", o.matrix)
  mat(l + ".matrixWorld", o.matrix_world)
  b(l + ".isMesh", o.is_mesh())
  b(l + ".isLine", o.is_line())
  b(l + ".isLineSegments", o.is_line_segments())
  if o.is_mesh() || o.is_line() {
    dump_geometry(l + ".geometry", o.get_geometry().unwrap())
    guard o.get_material() is Some(Single(material)) else { abort("material") }
    dump_material(l + ".material", material)
  }
  ni(l + ".children", o.children.length())
  for i, child in o.children {
    dump_object(l + ".c" + i.to_string(), child)
  }
}

///|
fn dispose_all(l : String, helper : @core.Object3D) -> Unit {
  let parts : Array[Ref[Int]] = []
  helper.traverse(o => {
    let c = Ref(0)
    o.add_event_listener("dispose", _ => c.val += 1)
    parts.push(c)
    if o.is_mesh() || o.is_line() {
      let g = Ref(0)
      o.get_geometry().unwrap().add_event_listener("dispose", _ => g.val += 1)
      parts.push(g)
      guard o.get_material() is Some(Single(material)) else { abort("material") }
      let m = Ref(0)
      material.add_event_listener("dispose", _ => m.val += 1)
      parts.push(m)
    }
  })
  helper.dispose()
  s(l + ".disposed", parts.map(c => c.val.to_string()).join(","))
}

///|
fn v3(x : Double, y : Double, z : Double) -> @math.Vector3 {
  @math.Vector3::new(x, y, z)
}

///|
fn hex(h : Int) -> @math.Color {
  @math.Color::from_hex(h)
}

///|
fn material_of(o : @core.Object3D) -> @core.Material {
  guard o.get_material() is Some(Single(material)) else { abort("material") }
  material
}

///|
fn axes() -> Unit {
  let sizes = [1.0, 2.5, 0.0, -3.0, 1.0e-7, 123456.789]
  for i in 0..<sizes.length() {
    let helper = @helpers.AxesHelper::new(size=sizes[i])
    dump_object("axes" + i.to_string(), helper)
    ignore(
      @helpers.AxesHelper::set_colors(
        helper,
        hex(0x123456),
        hex(0xabcdef),
        hex(0xff00ff),
      ),
    )
    dump_geometry("axes" + i.to_string() + ".colored", helper.get_geometry().unwrap())
    let copy = helper.clone()
    dump_object("axes" + i.to_string() + ".clone", copy)
    same(
      "axes" + i.to_string() + ".clone.geometry",
      copy.get_geometry().unwrap(),
      helper.get_geometry().unwrap(),
    )
    dispose_all("axes" + i.to_string(), helper)
  }
  dump_object("axes.default", @helpers.AxesHelper::new())
}

///|
fn grid() -> Unit {
  let params : Array[(Double, Double, Int, Int)] = [
    (5.0, 3.0, 0x444444, 0x888888),
    (7.3, 7.0, 0xff0000, 0x00ff00),
    (1.0, 1.0, 0x444444, 0x888888),
    (4.0, 0.0, 0x444444, 0x888888),
    (3.0, 4.5, 0x123456, 0x654321),
    (6.0, 6.0, 0x444444, 0x888888),
    (0.7, 33.0, 0x444444, 0x888888),
    (10.0, 100.0, 0x444444, 0x888888),
    (9.1, 77.0, 0x444444, 0x888888),
  ]
  dump_object("grid.default", @helpers.GridHelper::new())
  for i in 0..<params.length() {
    let p = params[i]
    let helper = @helpers.GridHelper::new(
      size=p.0,
      divisions=p.1,
      color1=hex(p.2),
      color2=hex(p.3),
    )
    dump_object("grid" + i.to_string(), helper)
    dispose_all("grid" + i.to_string(), helper)
  }
}

///|
fn polar_grid() -> Unit {
  let params : Array[(Double, Double, Double, Double, Int, Int)] = [
    (5.0, 1.0, 3.0, 8.0, 0x444444, 0x888888),
    (3.0, 7.0, 0.0, 5.0, 0x444444, 0x888888),
    (2.0, 3.0, 2.0, 3.5, 0x444444, 0x888888),
    (4.0, 2.0, 5.0, 12.0, 0x112233, 0x445566),
    (1.0, 0.0, 1.0, 1.0, 0x444444, 0x888888),
  ]
  dump_object("polar.default", @helpers.PolarGridHelper::new())
  for i in 0..<params.length() {
    let p = params[i]
    let helper = @helpers.PolarGridHelper::new(
      radius=p.0,
      sectors=p.1,
      rings=p.2,
      divisions=p.3,
      color1=hex(p.4),
      color2=hex(p.5),
    )
    dump_object("polar" + i.to_string(), helper)
    dispose_all("polar" + i.to_string(), helper)
  }
}

///|
fn arrow() -> Unit {
  let first = @helpers.ArrowHelper::new()
  dump_object("arrow.default", first)
  let cases : Array[
    (@math.Vector3, @math.Vector3, Double, Int, Double?, Double?),
  ] = [
    (v3(0.0, 1.0, 0.0), v3(0.0, 0.0, 0.0), 1.0, 0xffff00, None, None),
    (v3(0.0, -1.0, 0.0), v3(0.0, 0.0, 0.0), 2.0, 0xffff00, None, None),
    (v3(1.0, 1.0, 1.0).normalize(), v3(1.0, 2.0, 3.0), 3.0, 0x00ff00, None, None),
    (
      v3(0.3, -0.2, 0.9).normalize(),
      v3(-1.0, 0.0, 0.5),
      0.1,
      0xffff00,
      Some(0.5),
      None,
    ),
    (v3(-1.0, 0.0, 0.0), v3(0.0, 0.0, 0.0), 0.0, 0xff0000, Some(0.3), Some(0.1)),
    (v3(0.0, 1.0, 1.0e-3).normalize(), v3(0.0, 0.0, 0.0), 1.0, 0xffff00, None, None),
    (
      v3(0.0, 0.99998, js_sqrt(1.0 - 0.99998 * 0.99998)),
      v3(0.0, 0.0, 0.0),
      1.0,
      0xffff00,
      None,
      None,
    ),
    (
      v3(0.0, -0.99998, -js_sqrt(1.0 - 0.99998 * 0.99998)),
      v3(2.0, 2.0, 2.0),
      5.0,
      0xffff00,
      Some(1.0),
      Some(0.5),
    ),
  ]
  let first_arrow = @helpers.ArrowHelper::of(first).unwrap()
  let mut last = first
  for i in 0..<cases.length() {
    let c = cases[i]
    let helper = @helpers.ArrowHelper::new(
      dir=c.0,
      origin=c.1,
      length=c.2,
      color=hex(c.3),
      head_length?=c.4,
      head_width?=c.5,
    )
    dump_object("arrow" + i.to_string(), helper)
    let arrow = @helpers.ArrowHelper::of(helper).unwrap()
    same(
      "arrow" + i.to_string() + ".lineGeometry",
      arrow.line.get_geometry().unwrap(),
      first_arrow.line.get_geometry().unwrap(),
    )
    same(
      "arrow" + i.to_string() + ".coneGeometry",
      arrow.cone.get_geometry().unwrap(),
      first_arrow.cone.get_geometry().unwrap(),
    )
    last = helper
  }
  @helpers.ArrowHelper::set_direction(last, v3(1.0, 0.0, 1.0).normalize())
  @helpers.ArrowHelper::set_length(last, 4.0)
  dump_object("arrow.len4", last)
  @helpers.ArrowHelper::set_length(last, 2.0, head_length=0.5)
  dump_object("arrow.len2", last)
  @helpers.ArrowHelper::set_length(last, 2.0, head_length=0.5, head_width=0.25)
  @helpers.ArrowHelper::set_color(last, hex(0x0000ff))
  ignore(last.position.set(1.0, -1.0, 2.0))
  last.update_matrix_world()
  dump_object("arrow.updated", last)
  let copy = last.clone()
  dump_object("arrow.clone", copy)
  let copy_arrow = @helpers.ArrowHelper::of(copy).unwrap()
  let last_arrow = @helpers.ArrowHelper::of(last).unwrap()
  same(
    "arrow.clone.lineMaterial",
    material_of(copy_arrow.line),
    material_of(last_arrow.line),
  )
  same("arrow.clone.line", copy_arrow.line, last_arrow.line)
  let target = @helpers.ArrowHelper::new(dir=v3(0.0, 1.0, 0.0))
  ignore(target.copy(last))
  dump_object("arrow.copy", target)
  dispose_all("arrow", last)
}

///|
fn box3() -> Unit {
  let boxes = [
    @math.Box3::new(min=v3(-1.0, 0.0, 2.0), max=v3(3.0, 4.0, 4.0)),
    @math.Box3::new(min=v3(-1.0, -1.0, -1.0), max=v3(1.0, 1.0, 1.0)),
    @math.Box3::new(),
    @math.Box3::new(min=v3(0.0, 0.0, 0.0), max=v3(2.0, 0.0, 2.0)),
  ]
  let colors = [0xffff00, 0x00ff00, 0xffff00, 0x123456]
  for i in 0..<boxes.length() {
    let parent = @core.Group::new()
    ignore(parent.position.set(1.0, 2.0, 3.0))
    ignore(parent.rotation.set(0.1, 0.2, 0.3))
    let helper = @helpers.Box3Helper::new(box=boxes[i], color=hex(colors[i]))
    ignore(parent.add(helper))
    parent.update_matrix_world()
    dump_object("box3_" + i.to_string(), helper)
    ignore(boxes[i].expand_by_point(v3(-5.0, 6.0, 0.5)))
    parent.update_matrix_world()
    dump_object("box3_" + i.to_string() + ".expanded", helper)
    same(
      "box3_" + i.to_string() + ".box",
      @helpers.Box3Helper::of(helper).unwrap().box.unwrap(),
      boxes[i],
    )
    dispose_all("box3_" + i.to_string(), helper)
  }
  let empty = @helpers.Box3Helper::new()
  dump_object("box3.none", empty)
  dispose_all("box3.none", empty)
}

///|
fn box_helper() -> Unit {
  let none = @helpers.BoxHelper::new()
  dump_object("box.none", none)
  let mesh = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(width=1.0, height=2.0, depth=3.0),
    material=Single(@core.MeshBasicMaterial::new()),
  )
  ignore(mesh.position.set(1.0, 2.0, 3.0))
  ignore(mesh.rotation.set(0.3, 0.5, 0.7))
  ignore(mesh.scale.set(1.0, 2.0, 0.5))
  mesh.update_matrix_world()
  let mesh_helper = @helpers.BoxHelper::new(object=mesh, color=hex(0xff0000))
  dump_object("box.mesh", mesh_helper)
  let group = @core.Group::new()
  let sphere = @core.Mesh::new(
    geometry=@geometries.SphereGeometry::new(
      radius=0.5,
      width_segments=8.0,
      height_segments=6.0,
    ),
    material=Single(@core.MeshBasicMaterial::new()),
  )
  ignore(sphere.position.set(2.0, 0.0, 0.0))
  ignore(group.add(sphere))
  let cube = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(width=1.0, height=1.0, depth=1.0),
    material=Single(@core.MeshBasicMaterial::new()),
  )
  ignore(cube.position.set(-1.0, 1.0, 0.0))
  ignore(group.add(cube))
  let line = @core.Line::new(
    geometry=@core.BufferGeometry::new().set_from_points([
      v3(0.0, 0.0, 0.0),
      v3(0.0, 5.0, -4.0),
    ]),
    material=Single(@core.LineBasicMaterial::new()),
  )
  ignore(group.add(line))
  ignore(group.rotation.set(0.0, 0.7, 0.2))
  group.update_matrix_world()
  let group_helper = @helpers.BoxHelper::new(object=group)
  dump_object("box.group", group_helper)
  // without an object, update reuses the box of the last update
  let stale = @helpers.BoxHelper::new()
  dump_object("box.stale", stale)
  ignore(mesh.position.set(-2.0, 0.0, 1.0))
  mesh.update_matrix_world()
  @helpers.BoxHelper::update(mesh_helper)
  dump_object("box.moved", mesh_helper)
  ignore(@helpers.BoxHelper::set_from_object(stale, cube))
  dump_object("box.setFromObject", stale)
  same(
    "box.setFromObject.object",
    @helpers.BoxHelper::of(stale).unwrap().object.unwrap(),
    cube,
  )
  let empty_helper = @helpers.BoxHelper::new(object=@core.Object3D::new())
  dump_object("box.emptyObject", empty_helper)
  let after = @helpers.BoxHelper::new()
  dump_object("box.afterEmpty", after)
  let copy = group_helper.clone()
  dump_object("box.clone", copy)
  same(
    "box.clone.object",
    @helpers.BoxHelper::of(copy).unwrap().object.unwrap(),
    group,
  )
  ignore(none.copy(mesh_helper))
  dump_object("box.copy", none)
  same(
    "box.copy.object",
    @helpers.BoxHelper::of(none).unwrap().object.unwrap(),
    mesh,
  )
  dispose_all("box.mesh", mesh_helper)
}

///|
fn camera_case(l : String, camera : @core.Object3D) -> Unit {
  ignore(camera.position.set(1.0, 2.0, 5.0))
  camera.look_at_xyz(0.0, 0.5, 0.0)
  camera.update_matrix_world()
  let helper = @helpers.CameraHelper::new(camera)
  dump_object(l, helper)
  same(l + ".matrix", helper.matrix, camera.matrix_world)
  ignore(camera.position.set(-3.0, 1.0, 2.0))
  camera.update_matrix_world()
  if camera.is_perspective_camera() {
    camera.as_perspective_camera().fov = 40.0
    camera.as_perspective_camera().near = 0.5
    camera.update_projection_matrix()
  } else if camera.is_orthographic_camera() {
    camera.as_orthographic_camera().left = -3.0
    camera.as_orthographic_camera().far = 30.0
    camera.update_projection_matrix()
  }
  @helpers.CameraHelper::update(helper)
  dump_object(l + ".updated", helper)
  let scene = @core.Scene::new()
  ignore(scene.add(helper))
  scene.update_matrix_world()
  mat(l + ".scene.matrixWorld", helper.matrix_world)
  ignore(
    @helpers.CameraHelper::set_colors(
      helper,
      hex(0x010203),
      hex(0x405060),
      hex(0x708090),
      hex(0xa0b0c0),
      hex(0xd0e0f0),
    ),
  )
  dump_geometry(l + ".colored", helper.get_geometry().unwrap())
  dispose_all(l, helper)
}

///|
fn camera_data(camera : @core.Object3D) -> @core.Camera {
  guard camera.kind is Camera(data) else { abort("camera") }
  data
}

///|
fn camera_helper() -> Unit {
  let perspective : Array[(Double, Double, Double, Double)] = [
    (50.0, 1.0, 0.1, 2000.0),
    (75.0, 16.0 / 9.0, 1.0, 100.0),
    (30.0, 0.5, 0.01, 10.0),
    (120.0, 2.0, 5.0, 6.0),
  ]
  for i in 0..<perspective.length() {
    let p = perspective[i]
    camera_case(
      "camera.p" + i.to_string(),
      @core.PerspectiveCamera::new(fov=p.0, aspect=p.1, near=p.2, far=p.3),
    )
  }
  let zoomed = @core.PerspectiveCamera::new(
    fov=60.0,
    aspect=1.5,
    near=0.3,
    far=40.0,
  )
  zoomed.as_perspective_camera().zoom = 2.0
  zoomed.as_perspective_camera().film_offset = 3.0
  camera_case("camera.zoomed", zoomed)
  let offset = @core.PerspectiveCamera::new(
    fov=45.0,
    aspect=1.0,
    near=1.0,
    far=20.0,
  )
  offset.set_view_offset(400.0, 300.0, 100.0, 50.0, 200.0, 150.0)
  camera_case("camera.offset", offset)
  let orthographic : Array[(Double, Double, Double, Double, Double, Double)] = [
    (-1.0, 1.0, 1.0, -1.0, 0.1, 2000.0),
    (-4.0, 2.0, 3.0, -1.0, 0.5, 50.0),
  ]
  for i in 0..<orthographic.length() {
    let p = orthographic[i]
    camera_case(
      "camera.o" + i.to_string(),
      @core.OrthographicCamera::new(
        left=p.0,
        right=p.1,
        top=p.2,
        bottom=p.3,
        near=p.4,
        far=p.5,
      ),
    )
  }
  let ortho_zoom = @core.OrthographicCamera::new(
    left=-2.0,
    right=2.0,
    top=1.0,
    bottom=-1.0,
    near=1.0,
    far=10.0,
  )
  ortho_zoom.as_orthographic_camera().zoom = 0.5
  camera_case("camera.orthoZoom", ortho_zoom)
  camera_case("camera.base", @core.Camera::new())
  let webgpu = @core.PerspectiveCamera::new(
    fov=50.0,
    aspect=1.2,
    near=0.5,
    far=30.0,
  )
  camera_data(webgpu).coordinate_system = @core.WebGPUCoordinateSystem
  camera_case("camera.webgpu", webgpu)
  let reversed = @core.PerspectiveCamera::new(
    fov=50.0,
    aspect=1.2,
    near=0.5,
    far=30.0,
  )
  camera_data(reversed)._reversed_depth = true
  camera_case("camera.reversed", reversed)
  let ortho_webgpu = @core.OrthographicCamera::new(
    left=-2.0,
    right=2.0,
    top=1.0,
    bottom=-1.0,
    near=1.0,
    far=10.0,
  )
  camera_data(ortho_webgpu).coordinate_system = @core.WebGPUCoordinateSystem
  camera_case("camera.orthoWebgpu", ortho_webgpu)
  let light = @core.DirectionalLight::new(color=hex(0xffffff), intensity=1.0)
  ignore(light.position.set(2.0, 4.0, 2.0))
  light.update_matrix_world()
  let shadow_helper = @helpers.CameraHelper::new(
    light.as_light().shadow.unwrap().camera,
  )
  dump_object("camera.shadow", shadow_helper)
}

///|
fn directional() -> Unit {
  let light = @core.DirectionalLight::new(color=hex(0xffffff), intensity=1.0)
  ignore(light.position.set(1.0, 2.0, 3.0))
  let helper = @helpers.DirectionalLightHelper::new(light)
  dump_object("dir0", helper)
  same("dir0.matrix", helper.matrix, light.matrix_world)
  let payload = @helpers.DirectionalLightHelper::of(helper).unwrap()
  same(
    "dir0.material",
    material_of(payload.light_plane),
    material_of(payload.target_line),
  )
  dispose_all("dir0", helper)
  let scene = @core.Scene::new()
  let light1 = @core.DirectionalLight::new(color=hex(0x00ff00), intensity=2.0)
  ignore(light1.position.set(0.0, 5.0, 0.0))
  ignore(light1.light_target().position.set(1.0, 0.0, 1.0))
  ignore(scene.add(light1))
  ignore(scene.add(light1.light_target()))
  let helper1 = @helpers.DirectionalLightHelper::new(
    light1,
    size=2.0,
    color=hex(0xff0000),
  )
  ignore(scene.add(helper1))
  scene.update_matrix_world()
  dump_object("dir1", helper1)
  let group = @core.Group::new()
  ignore(group.position.set(3.0, -1.0, 2.0))
  ignore(group.rotation.set(0.4, -0.3, 0.2))
  ignore(scene.add(group))
  let light2 = @core.DirectionalLight::new(color=hex(0x8080ff), intensity=1.0)
  ignore(light2.position.set(-2.0, 3.0, 1.0))
  ignore(group.add(light2))
  let shared = hex(0x336699)
  let helper2 = @helpers.DirectionalLightHelper::new(
    light2,
    size=0.5,
    color=shared,
  )
  dump_object("dir2", helper2)
  ignore(shared.set_hex(0x996633))
  ignore(light2.position.set(4.0, 4.0, -4.0))
  ignore(light2.light_target().position.set(0.0, -1.0, 0.0))
  @helpers.DirectionalLightHelper::update(helper2)
  dump_object("dir2.updated", helper2)
  ignore(light1.as_light().color.set_hex(0x0000ff))
  ignore(light1.position.set(2.0, 2.0, 2.0))
  @helpers.DirectionalLightHelper::update(helper1)
  scene.update_matrix_world()
  dump_object("dir1.updated", helper1)
  let light3 = @core.DirectionalLight::new(color=hex(0xffffff), intensity=1.0)
  let helper3 = @helpers.DirectionalLightHelper::new(light3, size=0.0)
  dump_object("dir3", helper3)
  dispose_all("dir1", helper1)
}

///|
fn ground_color(light : @core.Object3D) -> @math.Color {
  guard light.as_light().kind is HemisphereLight(hemisphere) else {
    abort("hemisphere")
  }
  hemisphere.ground_color
}

///|
fn hemisphere() -> Unit {
  let light = @core.HemisphereLight::new(
    sky_color=hex(0x88aaff),
    ground_color=hex(0x553311),
    intensity=1.0,
  )
  ignore(light.position.set(0.0, 1.0, 0.0))
  let helper = @helpers.HemisphereLightHelper::new(light)
  dump_object("hemi0", helper)
  same(
    "hemi0.material",
    @helpers.HemisphereLightHelper::of(helper).unwrap().material,
    material_of(helper.children[0]),
  )
  same("hemi0.matrix", helper.matrix, light.matrix_world)
  ignore(light.as_light().color.set_hex(0xff0000))
  ignore(ground_color(light).set_hex(0x00ff00))
  ignore(light.position.set(1.0, 1.0, 1.0))
  @helpers.HemisphereLightHelper::update(helper)
  dump_object("hemi0.updated", helper)
  dispose_all("hemi0", helper)
  let group = @core.Group::new()
  ignore(group.position.set(1.0, 2.0, 3.0))
  ignore(group.rotation.set(0.3, 0.2, 0.1))
  let light1 = @core.HemisphereLight::new(
    sky_color=hex(0x123456),
    ground_color=hex(0x654321),
    intensity=2.0,
  )
  ignore(light1.position.set(3.0, 4.0, 5.0))
  ignore(group.add(light1))
  let helper1 = @helpers.HemisphereLightHelper::new(
    light1,
    size=2.0,
    color=hex(0x123456),
  )
  dump_object("hemi1", helper1)
  group.update_matrix_world()
  @helpers.HemisphereLightHelper::update(helper1)
  dump_object("hemi1.updated", helper1)
  let light2 = @core.HemisphereLight::new(
    sky_color=hex(0xffffff),
    ground_color=hex(0x000000),
    intensity=1.0,
  )
  ignore(light2.position.set(0.0, 0.0, 0.0))
  let helper2 = @helpers.HemisphereLightHelper::new(light2, size=0.5)
  dump_object("hemi2", helper2)
}

///|
fn point() -> Unit {
  let light = @core.PointLight::new(color=hex(0xffffff), intensity=1.0)
  ignore(light.position.set(1.0, 1.0, 1.0))
  let helper = @helpers.PointLightHelper::new(light)
  dump_object("point0", helper)
  same("point0.matrix", helper.matrix, light.matrix_world)
  ignore(light.as_light().color.set_hex(0x00ffff))
  ignore(light.position.set(-1.0, 2.0, 0.0))
  @helpers.PointLightHelper::update(helper)
  dump_object("point0.updated", helper)
  dispose_all("point0", helper)
  let group = @core.Group::new()
  ignore(group.position.set(0.0, 3.0, 0.0))
  ignore(group.scale.set(2.0, 2.0, 2.0))
  let light1 = @core.PointLight::new(color=hex(0xff0000), intensity=2.0)
  ignore(light1.position.set(1.0, 0.0, 0.0))
  ignore(group.add(light1))
  let helper1 = @helpers.PointLightHelper::new(
    light1,
    sphere_size=0.5,
    color=hex(0xff8800),
  )
  dump_object("point1", helper1)
  let scene = @core.Scene::new()
  ignore(scene.add(group))
  ignore(scene.add(helper1))
  scene.update_matrix_world()
  dump_object("point1.scene", helper1)
  let helper2 = @helpers.PointLightHelper::new(light1, sphere_size=2.0)
  dump_object("point2", helper2)
}

///|
fn spot() -> Unit {
  let light = @core.SpotLight::new(color=hex(0xffffff))
  ignore(light.position.set(0.0, 3.0, 0.0))
  let helper = @helpers.SpotLightHelper::new(light)
  dump_object("spot0", helper)
  let parent = @core.Group::new()
  ignore(parent.position.set(1.0, 2.0, 3.0))
  ignore(parent.rotation.set(0.5, 0.1, -0.2))
  ignore(parent.add(helper))
  @helpers.SpotLightHelper::update(helper)
  dump_object("spot0.parented", helper)
  dispose_all("spot0", helper)
  let scene = @core.Scene::new()
  let light1 = @core.SpotLight::new(
    color=hex(0x00ff00),
    intensity=1.0,
    distance=5.0,
    angle=0.2,
  )
  ignore(light1.position.set(1.0, 2.0, 3.0))
  ignore(light1.light_target().position.set(0.0, 0.0, -1.0))
  ignore(scene.add(light1))
  ignore(scene.add(light1.light_target()))
  let helper1 = @helpers.SpotLightHelper::new(light1, color=hex(0xff0000))
  ignore(scene.add(helper1))
  scene.update_matrix_world()
  dump_object("spot1", helper1)
  light1.as_spot_light().distance = 0.0 / 0.0
  light1.as_spot_light().angle = 1.2
  @helpers.SpotLightHelper::update(helper1)
  dump_object("spot1.nan", helper1)
  let shared = hex(0x445566)
  let light2 = @core.SpotLight::new(
    color=hex(0x0000ff),
    intensity=1.0,
    distance=12.0,
    angle=3.141592653589793 / 6.0,
  )
  ignore(light2.position.set(-2.0, 5.0, 1.0))
  let helper2 = @helpers.SpotLightHelper::new(light2, color=shared)
  ignore(shared.set_hex(0x665544))
  @helpers.SpotLightHelper::update(helper2)
  dump_object("spot2", helper2)
}

///|
fn plane() -> Unit {
  let planes = [
    @math.Plane::new(normal=v3(0.0, 1.0, 0.0), constant=0.0),
    @math.Plane::new(normal=v3(1.0, 1.0, 0.0).normalize(), constant=2.0),
    @math.Plane::new(normal=v3(0.0, 0.0, -1.0), constant=-1.5),
    @math.Plane::new(normal=v3(0.2, 0.9, -0.4).normalize(), constant=0.7),
  ]
  let sizes = [1.0, 3.0, 1.0, 0.25]
  let colors = [0xffff00, 0x00ffff, 0xffff00, 0xff00ff]
  for i in 0..<planes.length() {
    let group = @core.Group::new()
    ignore(group.position.set(0.5, -1.0, 2.0))
    ignore(group.rotation.set(0.2, 0.4, 0.6))
    let helper = @helpers.PlaneHelper::new(
      plane=planes[i],
      size=sizes[i],
      color=hex(colors[i]),
    )
    ignore(group.add(helper))
    group.update_matrix_world()
    dump_object("plane" + i.to_string(), helper)
    planes[i].constant += 1.25
    ignore(planes[i].normal.set(0.6, 0.0, 0.8))
    @helpers.PlaneHelper::of(helper).unwrap().size = 2.5
    group.update_matrix_world()
    dump_object("plane" + i.to_string() + ".mutated", helper)
    dispose_all("plane" + i.to_string(), helper)
  }
  let none = @helpers.PlaneHelper::new()
  dump_object("plane.none", none)
  let source = @helpers.PlaneHelper::new(
    plane=@math.Plane::new(normal=v3(0.0, 0.0, 1.0), constant=1.0),
    size=2.0,
  )
  source.update_matrix_world()
  let copy = source.clone()
  dump_object("plane.clone", copy)
  same("plane.clone.material", material_of(copy), material_of(source))
  dispose_all("plane.none", none)
}

///|
fn skeleton() -> Unit {
  let scene = @core.Scene::new()
  let armature = @core.Group::new()
  ignore(armature.position.set(1.0, 0.0, 0.0))
  ignore(armature.rotation.set(0.0, 0.3, 0.0))
  let root = @core.Bone::new()
  let bone1 = @core.Bone::new()
  ignore(bone1.position.set(0.0, 1.0, 0.0))
  let bone2 = @core.Bone::new()
  ignore(bone2.position.set(0.0, 1.0, 0.0))
  ignore(bone2.rotation.set(0.0, 0.0, 0.5))
  let holder = @core.Object3D::new()
  ignore(holder.position.set(0.5, 0.5, 0.0))
  let bone3 = @core.Bone::new()
  ignore(bone3.position.set(1.0, 0.0, 0.0))
  let bone4 = @core.Bone::new()
  ignore(bone4.position.set(0.0, 0.0, 2.0))
  ignore(armature.add(root))
  ignore(root.add(bone1))
  ignore(bone1.add(bone2))
  ignore(bone2.add(holder))
  ignore(holder.add(bone3))
  ignore(bone3.add(bone4))
  ignore(root.add(@core.Bone::new()))
  ignore(scene.add(armature))
  let helper = @helpers.SkeletonHelper::new(armature)
  ignore(scene.add(helper))
  scene.update_matrix_world()
  dump_object("skel0", helper)
  same("skel0.matrix", helper.matrix, armature.matrix_world)
  ni("skel0.bones", @helpers.SkeletonHelper::of(helper).unwrap().bones.length())
  b("skel0.flag", helper.has_extension_flag("isSkeletonHelper"))
  ignore(bone1.rotation.set(0.2, 0.4, 0.0))
  ignore(armature.position.set(-1.0, 2.0, 0.0))
  scene.update_matrix_world()
  dump_object("skel0.moved", helper)
  ignore(
    @helpers.SkeletonHelper::set_colors(helper, hex(0xff0000), hex(0x00ffff)),
  )
  dump_geometry("skel0.colored", helper.get_geometry().unwrap())
  let bone_helper = @helpers.SkeletonHelper::new(bone1)
  ignore(scene.add(bone_helper))
  scene.update_matrix_world()
  dump_object("skel1", bone_helper)
  let skinned = @core.SkinnedMesh::new(
    geometry=@geometries.BoxGeometry::new(width=1.0, height=1.0, depth=1.0),
    material=Single(@core.MeshBasicMaterial::new()),
  )
  let sroot = @core.Bone::new()
  let stip = @core.Bone::new()
  ignore(stip.position.set(0.0, 2.0, 0.0))
  ignore(sroot.add(stip))
  ignore(skinned.add(sroot))
  skinned.bind(@core.Skeleton::new(bones=[sroot, stip]))
  ignore(skinned.position.set(0.0, -1.0, 1.0))
  ignore(stip.rotation.set(0.3, 0.0, 0.0))
  ignore(scene.add(skinned))
  let skinned_helper = @helpers.SkeletonHelper::new(skinned)
  ignore(scene.add(skinned_helper))
  scene.update_matrix_world()
  dump_object("skel2", skinned_helper)
  dispose_all("skel0", helper)
}

///|
pub fn run_mbt() -> Unit {
  axes()
  grid()
  polar_grid()
  arrow()
  box3()
  box_helper()
  camera_helper()
  directional()
  hemisphere()
  point()
  spot()
  plane()
  skeleton()
}

///|
fn main {

}
