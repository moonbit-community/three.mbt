// Upstream examples/jsm/environments/RoomEnvironment.js: a lit room with boxes and
// emissive panels, to be turned into an environment map with PMREM.

///|
/// The `RoomEnvironment` subclass of `Scene`; it adds no state.
pub(all) struct RoomEnvironment {}

///|
pub impl @core.Object3DExtension for RoomEnvironment with fn type_name(_) {
  "Scene"
}

///|
pub impl @core.Object3DExtension for RoomEnvironment with fn construct(_) {
  RoomEnvironment::new()
}

///|
pub impl @core.Object3DExtension for RoomEnvironment with fn has_flag(_, flag) {
  flag == "isRoomEnvironment"
}

///|
pub impl @core.Object3DExtension for RoomEnvironment with fn dispose(_, object) {
  RoomEnvironment::dispose(object)
}

///|
/// `new RoomEnvironment()`: a `Scene`.
pub fn RoomEnvironment::new() -> @core.Object3D {
  let scene = @core.Scene::new()
  scene.set_extension(RoomEnvironment::{ }) |> ignore
  scene.name = "RoomEnvironment"
  scene.position.y = -3.5
  let geometry = @geometries.BoxGeometry::new()
  geometry.delete_attribute("uv") |> ignore
  let room_material = @core.MeshStandardMaterial::new()
  room_material.side = @core.BackSide
  let box_material = @core.MeshStandardMaterial::new()
  let main_light = @core.PointLight::new(
    color=@math.Color::from_hex(0xffffff),
    intensity=900.0,
    distance=28.0,
    decay=2.0,
  )
  main_light.position.set(0.418, 16.199, 0.300) |> ignore
  scene.add(main_light) |> ignore
  let room = @core.Mesh::new(geometry~, material=Single(room_material))
  room.position.set(-0.757, 13.219, 0.717) |> ignore
  room.scale.set(31.713, 28.305, 28.591) |> ignore
  scene.add(room) |> ignore
  let boxes = @core.InstancedMesh::new(
    geometry~,
    material=Single(box_material),
    6,
  )
  let transform = @core.Object3D::new()
  let set_box = fn(
    index : Int32,
    position : (Double, Double, Double),
    rotation_y : Double,
    scale : (Double, Double, Double),
  ) {
    transform.position.set(position.0, position.1, position.2) |> ignore
    transform.rotation.set(0.0, rotation_y, 0.0) |> ignore
    transform.scale.set(scale.0, scale.1, scale.2) |> ignore
    transform.update_matrix()
    boxes.set_matrix_at(index, transform.matrix) |> ignore
  }
  // box1
  set_box(0, (-10.906, 2.009, 1.846), -0.195, (2.328, 7.905, 4.651))
  // box2
  set_box(1, (-5.607, -0.754, -0.758), 0.994, (1.970, 1.534, 3.955))
  // box3
  set_box(2, (6.167, 0.857, 7.803), 0.561, (3.927, 6.285, 3.687))
  // box4
  set_box(3, (-2.017, 0.018, 6.124), 0.333, (2.002, 4.566, 2.064))
  // box5
  set_box(4, (2.291, -0.756, -2.621), -0.286, (1.546, 1.552, 1.496))
  // box6
  set_box(5, (-2.193, -0.369, -5.547), 0.516, (3.875, 3.487, 2.986))
  scene.add(boxes) |> ignore
  let light = fn(
    intensity : Double,
    position : (Double, Double, Double),
    scale : (Double, Double, Double),
  ) {
    let light = @core.Mesh::new(
      geometry~,
      material=Single(room_environment_area_light_material(intensity)),
    )
    light.position.set(position.0, position.1, position.2) |> ignore
    light.scale.set(scale.0, scale.1, scale.2) |> ignore
    scene.add(light) |> ignore
  }
  // -x right
  light(50.0, (-16.116, 14.37, 8.208), (0.1, 2.428, 2.739))
  // -x left
  light(50.0, (-16.109, 18.021, -8.207), (0.1, 2.425, 2.751))
  // +x
  light(17.0, (14.904, 12.198, -1.832), (0.15, 4.265, 6.331))
  // +z
  light(43.0, (-0.462, 8.89, 14.520), (4.38, 5.441, 0.088))
  // -z
  light(20.0, (3.235, 11.486, -12.541), (2.5, 2.0, 0.1))
  // +y
  light(100.0, (0.0, 20.0, 0.0), (1.0, 0.1, 1.0))
  scene
}

///|
/// The payload of a `RoomEnvironment`.
pub fn RoomEnvironment::of(object : @core.Object3D) -> RoomEnvironment? {
  match object.extension {
    Some(extension) if extension.has_flag("isRoomEnvironment") =>
      Some(extension.payload().cast())
    _ => None
  }
}

///|
/// `dispose()`: frees every geometry and material of the meshes, once each.
pub fn RoomEnvironment::dispose(object : @core.Object3D) -> Unit {
  environment_dispose_meshes(object)
}

///|
/// `createAreaLightMaterial( intensity )`: an emissive-only material. See #31348.
fn room_environment_area_light_material(intensity : Double) -> @core.Material {
  let material = @core.MeshLambertMaterial::new()
  material.color.unwrap().set_hex(0x000000) |> ignore
  material.emissive.unwrap().set_hex(0xffffff) |> ignore
  material.emissive_intensity = Some(intensity)
  material
}
