// Shared by the geometry classes. No upstream file.

///|
let _geometry_pi : Double = 3.141592653589793

///|
let _geometry_two_pi : Double = _geometry_pi * 2.0

///|
extern "js" fn js_math_max(a : Double, b : Double) -> Double = "Math.max"

///|
extern "js" fn js_math_min(a : Double, b : Double) -> Double = "Math.min"

///|
extern "js" fn js_math_round(x : Double) -> Double = "Math.round"

///|
extern "js" fn js_math_sign(x : Double) -> Double = "Math.sign"

///|
/// JS number-to-string conversion, for the string hashes of upstream.
extern "js" fn js_number_string(x : Double) -> String = "String"

///|
fn push2(array : Array[Double], a : Double, b : Double) -> Unit {
  array.push(a)
  array.push(b)
}

///|
fn push3(array : Array[Double], a : Double, b : Double, c : Double) -> Unit {
  array.push(a)
  array.push(b)
  array.push(c)
}

///|
/// What every constructor starts with: `super()`, `this.type`, `this.parameters`.
/// `lazy_values` hold the parameters upstream keeps by reference, each with a
/// `lazy_placeholder` in `values`. `to_json_hook` is the class's `toJSON` override.
fn new_geometry(
  type_ : String,
  values : Map[String, Json],
  shapes~ : Array[&@core.SerializableResource] = [],
  lazy_values~ : Map[String, () -> Json] = Map([]),
  to_json_hook? : (@core.BufferGeometry, Map[String, Json]) -> Unit,
) -> @core.BufferGeometry {
  let geometry = @core.BufferGeometry::new()
  geometry.type_ = type_
  let parameters : @core.GeometryParameters = { values, shapes, }
  for key, value in lazy_values {
    parameters.set_lazy(key, value)
  }
  geometry.parameters = Some(parameters)
  if to_json_hook is Some(hook) {
    geometry.set_to_json_hook(hook)
  }
  geometry
}

///|
/// Holds the place in `values` of a key in `lazy_values`, which fixes the key order.
let lazy_placeholder : Json = Json::null()

///|
/// `this.parameters`, which a geometry class always has; `copy` keeps it set.
fn geometry_parameters(
  geometry : @core.BufferGeometry,
) -> @core.GeometryParameters {
  match geometry.parameters {
    Some(parameters) => parameters
    None => abort("toJSON: Cannot read properties of undefined (parameters)")
  }
}

///|
fn BufferGeometryBuffers::apply(
  self : BufferGeometryBuffers,
  geometry : @core.BufferGeometry,
) -> Unit {
  geometry.set_index(self.indices) |> ignore
  geometry.set_attribute(
    "position",
    @core.Float32BufferAttribute::new(self.vertices, 3),
  )
  |> ignore
  geometry.set_attribute(
    "normal",
    @core.Float32BufferAttribute::new(self.normals, 3),
  )
  |> ignore
  geometry.set_attribute("uv", @core.Float32BufferAttribute::new(self.uvs, 2))
  |> ignore
}

///|
/// The four buffers most constructors fill.
priv struct BufferGeometryBuffers {
  indices : Array[Double]
  vertices : Array[Double]
  normals : Array[Double]
  uvs : Array[Double]
}

///|
fn BufferGeometryBuffers::new() -> BufferGeometryBuffers {
  { indices: [], vertices: [], normals: [], uvs: [], }
}

///|
/// `data[ key ]` for the numeric arguments of `fromJSON`; `None` selects the default.
/// Upstream passes `null` (a non-finite number written by `JSON.stringify`) on, so it
/// reads as NaN and is written back as `null`.
fn json_number(data : Json, key : String) -> Double? {
  match data {
    Object(fields) =>
      match fields.get(key) {
        Some(value) => @math.json_to_number(value)
        None => None
      }
    _ => None
  }
}

///|
/// `data[ key ]` for the boolean arguments of `fromJSON`.
fn json_bool(data : Json, key : String) -> Bool? {
  match data {
    Object(fields) =>
      match fields.get(key) {
        Some(True) => Some(true)
        Some(False) => Some(false)
        _ => None
      }
    _ => None
  }
}

///|
/// `data[ key ]`.
fn json_field(data : Json, key : String) -> Json? {
  match data {
    Object(fields) => fields.get(key)
    _ => None
  }
}

///|
/// `data[ key ]` for the number-array arguments of `fromJSON`.
fn json_numbers(data : Json, key : String) -> Array[Double]? {
  match json_field(data, key) {
    Some(Array(values)) =>
      Some(
        values.map(value => {
          match @math.json_to_number(value) {
            Some(number) => number
            None => abort("fromJSON: \{key} must hold numbers")
          }
        }),
      )
    _ => None
  }
}

///|
/// `parameters.geometry` of `EdgesGeometry` and `WireframeGeometry`, which upstream holds
/// by reference. Without a source the placeholder is upstream's default, `null`.
fn source_geometry_parameter(
  geometry : @core.BufferGeometry?,
) -> Map[String, () -> Json] {
  match geometry {
    Some(geometry) => { "geometry": () => geometry.to_json() }
    None => Map([])
  }
}
