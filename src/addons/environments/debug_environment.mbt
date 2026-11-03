// Upstream examples/jsm/environments/DebugEnvironment.js: a room with three colored
// emissive panels and a point light, for checking environment-map orientation.

///|
/// The `DebugEnvironment` subclass of `Scene`; it adds no state.
pub(all) struct DebugEnvironment {}

///|
pub impl @core.Object3DExtension for DebugEnvironment with fn type_name(_) {
  "Scene"
}

///|
pub impl @core.Object3DExtension for DebugEnvironment with fn construct(_) {
  DebugEnvironment::new()
}

///|
pub impl @core.Object3DExtension for DebugEnvironment with fn has_flag(_, flag) {
  flag == "isDebugEnvironment"
}

///|
pub impl @core.Object3DExtension for DebugEnvironment with fn dispose(_, object) {
  DebugEnvironment::dispose(object)
}

///|
fn debug_environment_lambert(color : Int32) -> @core.Material {
  let material = @core.MeshLambertMaterial::new()
  material.color.unwrap().set_hex(color) |> ignore
  material.emissive.unwrap().set_hex(0xffffff) |> ignore
  material.emissive_intensity = Some(10.0)
  material
}

///|
/// `new DebugEnvironment()`: a `Scene`.
pub fn DebugEnvironment::new() -> @core.Object3D {
  let scene = @core.Scene::new()
  scene.set_extension(DebugEnvironment::{ }) |> ignore
  let geometry = @geometries.BoxGeometry::new()
  geometry.delete_attribute("uv") |> ignore
  let room_material = @core.MeshStandardMaterial::new()
  room_material.metalness = Some(0.0)
  room_material.side = @core.BackSide
  let room = @core.Mesh::new(geometry~, material=Single(room_material))
  room.scale.set_scalar(10.0) |> ignore
  scene.add(room) |> ignore
  let main_light = @core.PointLight::new(
    color=@math.Color::from_hex(0xffffff),
    intensity=50.0,
    distance=0.0,
    decay=2.0,
  )
  scene.add(main_light) |> ignore
  let material1 = debug_environment_lambert(0xff0000)
  let light1 = @core.Mesh::new(geometry~, material=Single(material1))
  light1.position.set(-5.0, 2.0, 0.0) |> ignore
  light1.scale.set(0.1, 1.0, 1.0) |> ignore
  scene.add(light1) |> ignore
  let material2 = debug_environment_lambert(0x00ff00)
  let light2 = @core.Mesh::new(geometry~, material=Single(material2))
  light2.position.set(0.0, 5.0, 0.0) |> ignore
  light2.scale.set(1.0, 0.1, 1.0) |> ignore
  scene.add(light2) |> ignore
  let material3 = debug_environment_lambert(0x0000ff)
  let light3 = @core.Mesh::new(geometry~, material=Single(material3))
  light3.position.set(2.0, 1.0, 5.0) |> ignore
  light3.scale.set(1.5, 2.0, 0.1) |> ignore
  scene.add(light3) |> ignore
  scene
}

///|
/// The payload of a `DebugEnvironment`.
pub fn DebugEnvironment::of(object : @core.Object3D) -> DebugEnvironment? {
  match object.extension {
    Some(extension) if extension.has_flag("isDebugEnvironment") =>
      Some(extension.payload().cast())
    _ => None
  }
}

///|
/// `dispose()`: frees every geometry and material of the meshes, once each.
pub fn DebugEnvironment::dispose(object : @core.Object3D) -> Unit {
  environment_dispose_meshes(object)
}

///|
/// The `dispose()` of RoomEnvironment and DebugEnvironment: a `Set` of the meshes'
/// geometries and materials in traversal order, each disposed once.
fn environment_dispose_meshes(object : @core.Object3D) -> Unit {
  let resources : Array[EnvironmentResource] = []
  let add = fn(resource : EnvironmentResource) {
    let seen = resources
      .iter()
      .any(fn(r) {
        match (r, resource) {
          (Geometry(a), Geometry(b)) => physical_equal(a, b)
          (Material(a), Material(b)) => physical_equal(a, b)
          (Materials(a), Materials(b)) => physical_equal(a, b)
          _ => false
        }
      })
    if !seen {
      resources.push(resource)
    }
  }
  object.traverse(fn(child) {
    if child.kind is Mesh(mesh) {
      add(Geometry(mesh.geometry))
      match mesh.material {
        Single(material) => add(Material(material))
        // `resources.add( object.material )` adds the array itself
        Multiple(materials) => add(Materials(materials))
      }
    }
  })
  for resource in resources {
    match resource {
      Geometry(g) => g.dispose()
      Material(m) => m.dispose()
      // an array has no `dispose`
      Materials(_) => abort("TypeError: resource.dispose is not a function")
    }
  }
}

///|
priv enum EnvironmentResource {
  Geometry(@core.BufferGeometry)
  Material(@core.Material)
  Materials(Array[@core.Material])
}
