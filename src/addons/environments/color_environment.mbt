// Upstream examples/jsm/environments/ColorEnvironment.js: a scene with one back-faced
// sphere of a solid color, to be turned into an environment map with PMREM.

///|
/// The `ColorEnvironment` subclass of `Scene`; it adds no state.
pub(all) struct ColorEnvironment {}

///|
pub impl @core.Object3DExtension for ColorEnvironment with fn type_name(_) {
  "Scene"
}

///|
pub impl @core.Object3DExtension for ColorEnvironment with fn construct(_) {
  ColorEnvironment::new()
}

///|
pub impl @core.Object3DExtension for ColorEnvironment with fn has_flag(_, flag) {
  flag == "isColorEnvironment"
}

///|
pub impl @core.Object3DExtension for ColorEnvironment with fn dispose(_, object) {
  ColorEnvironment::dispose(object)
}

///|
/// `new ColorEnvironment( color )`: a `Scene`.
pub fn ColorEnvironment::new(color~ : Int32 = 0xffffff) -> @core.Object3D {
  let scene = @core.Scene::new()
  scene.set_extension(ColorEnvironment::{ }) |> ignore
  scene.name = "ColorEnvironment"
  let geometry = @geometries.SphereGeometry::new(
    radius=1.0,
    width_segments=16.0,
    height_segments=16.0,
  )
  let material = @core.MeshBasicMaterial::new()
  material.color.unwrap().set_hex(color) |> ignore
  material.side = @core.BackSide
  scene.add(@core.Mesh::new(geometry~, material=Single(material))) |> ignore
  scene
}

///|
/// The payload of a `ColorEnvironment`.
pub fn ColorEnvironment::of(object : @core.Object3D) -> ColorEnvironment? {
  match object.extension {
    Some(extension) if extension.has_flag("isColorEnvironment") =>
      Some(extension.payload().cast())
    _ => None
  }
}

///|
/// `dispose()`: frees the sphere's geometry and material.
pub fn ColorEnvironment::dispose(object : @core.Object3D) -> Unit {
  let child = object.children[0]
  child.get_geometry().unwrap().dispose()
  match child.get_material() {
    Some(Single(material)) => material.dispose()
    _ => abort("ColorEnvironment.dispose: the child has no single material")
  }
}
