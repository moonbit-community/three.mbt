// Shared pieces of the helper classes: reading the `geometry` and `material` a helper
// holds now (upstream reads `this.geometry` at call time) and recovering a payload.

///|
/// `Math.max`, which propagates NaN.
extern "js" fn helpers_math_max(a : Double, b : Double) -> Double = "Math.max"

///|
/// `object.geometry`.
fn geometry_of(object : @core.Object3D) -> @core.BufferGeometry {
  guard object.get_geometry() is Some(geometry) else {
    abort("\{object.type_}: no geometry")
  }
  geometry
}

///|
/// `object.material`, a single material.
fn material_of(object : @core.Object3D) -> @core.Material {
  guard object.get_material() is Some(Single(material)) else {
    abort("\{object.type_}: material is not a single material")
  }
  material
}

///|
/// `material.color`.
fn color_of(material : @core.Material) -> @math.Color {
  guard material.color is Some(color) else {
    abort("\{material.type_}: no color")
  }
  color
}

///|
/// The payload of a helper whose `type` is `type_name`.
fn[T] helper_payload(object : @core.Object3D, type_name : String) -> T? {
  match object.extension {
    Some(extension) =>
      if extension.type_name() == type_name {
        Some(extension.payload().cast())
      } else {
        None
      }
    None => None
  }
}

///|
/// The payload of a helper, aborting with `type_name` when `object` is not one.
fn[T] require_payload(object : @core.Object3D, type_name : String) -> T {
  match helper_payload(object, type_name) {
    Some(payload) => payload
    None => abort("\{object.type_} is not a \{type_name}")
  }
}

///|
/// `new LineBasicMaterial( { color, toneMapped: false } )`.
fn line_basic_material(color : @math.Color) -> @core.Material {
  let material = @core.LineBasicMaterial::new()
  ignore(color_of(material).copy(color))
  material.tone_mapped = false
  material
}
