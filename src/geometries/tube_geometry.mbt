// Upstream src/geometries/TubeGeometry.js.

///|
#external
pub type TubeGeometry

///|
#external
priv type TubeFramesTable

///|
extern "js" fn TubeFramesTable::new() -> TubeFramesTable = "() => new WeakMap()"

///|
extern "js" fn TubeFramesTable::set(
  self : TubeFramesTable,
  geometry : @core.BufferGeometry,
  frames : @extras.FrenetFrames,
) -> Unit = "(table, geometry, frames) => { table.set(geometry, frames); }"

///|
extern "js" fn TubeFramesTable::has(
  self : TubeFramesTable,
  geometry : @core.BufferGeometry,
) -> Bool = "(table, geometry) => table.has(geometry)"

///|
extern "js" fn TubeFramesTable::get(
  self : TubeFramesTable,
  geometry : @core.BufferGeometry,
) -> @extras.FrenetFrames = "(table, geometry) => table.get(geometry)"

///|
/// Upstream's `tangents`, `normals` and `binormals` fields, which `BufferGeometry` has no
/// room for.
let _tube_frames : TubeFramesTable = TubeFramesTable::new()

///|
fn tube_default_path() -> @extras.Curve[@math.Vector3] {
  @extras.QuadraticBezierCurve3::new(
    v0=@math.Vector3::new(-1.0, -1.0, 0.0),
    v1=@math.Vector3::new(-1.0, 1.0, 0.0),
    v2=@math.Vector3::new(1.0, 1.0, 0.0),
  )
}

///|
/// `TubeGeometry.prototype.toJSON` after `super.toJSON()`.
fn tube_geometry_to_json(
  geometry : @core.BufferGeometry,
  data : Map[String, Json],
) -> Unit {
  // `this.parameters.path.toJSON()`, which throws for an undefined `path`
  guard geometry_parameters(geometry).get("path") is Some(path) else {
    abort("toJSON: Cannot read properties of undefined (reading 'toJSON')")
  }
  data["path"] = path
}

///|
pub fn TubeGeometry::new(
  path~ : @extras.Curve[@math.Vector3] = tube_default_path(),
  tubular_segments~ : Double = 64.0,
  radius~ : Double = 1.0,
  radial_segments~ : Double = 8.0,
  closed~ : Bool = false,
) -> @core.BufferGeometry {
  let geometry = new_geometry(
    "TubeGeometry",
    {
      "path": lazy_placeholder,
      "tubularSegments": @math.json_number(tubular_segments),
      "radius": @math.json_number(radius),
      "radialSegments": @math.json_number(radial_segments),
      "closed": Json::boolean(closed),
    },
    lazy_values={ "path": () => path.to_json() },
    to_json_hook=tube_geometry_to_json,
  )
  // upstream reads `frames.normals[ tubularSegments ]`, undefined here, and throws
  if tubular_segments != tubular_segments.floor() {
    abort("TubeGeometry: tubularSegments must be an integer")
  }
  let frames = path.compute_frenet_frames(tubular_segments.to_int(), closed~)
  // expose internals
  _tube_frames.set(geometry, frames)
  // helper variables
  let vertex = @math.Vector3::new(0.0, 0.0, 0.0)
  let normal = @math.Vector3::new(0.0, 0.0, 0.0)
  let uv = @math.Vector2::new(0.0, 0.0)
  let mut p = @math.Vector3::new(0.0, 0.0, 0.0)
  // buffer
  let buffers = BufferGeometryBuffers::new()
  let { indices, vertices, normals, uvs, } = buffers
  fn generate_segment(i : Double) -> Unit {
    // we use getPointAt to sample evenly distributed points from the given path
    p = path.get_point_at(i / tubular_segments, optional_target=p)
    // retrieve corresponding normal and binormal
    let n = frames.normals[i.to_int()]
    let b = frames.binormals[i.to_int()]
    // generate normals and vertices for the current segment
    for j = 0.0; j <= radial_segments; j = j + 1.0 {
      let v = j / radial_segments * _geometry_pi * 2.0
      let sin = @cmath.sin(v)
      let cos = -@cmath.cos(v)
      // normal
      normal.x = cos * n.x + sin * b.x
      normal.y = cos * n.y + sin * b.y
      normal.z = cos * n.z + sin * b.z
      normal.normalize() |> ignore
      push3(normals, normal.x, normal.y, normal.z)
      // vertex
      vertex.x = p.x + radius * normal.x
      vertex.y = p.y + radius * normal.y
      vertex.z = p.z + radius * normal.z
      push3(vertices, vertex.x, vertex.y, vertex.z)
    }
  }

  fn generate_indices() -> Unit {
    for j = 1.0; j <= tubular_segments; j = j + 1.0 {
      for i = 1.0; i <= radial_segments; i = i + 1.0 {
        let a = (radial_segments + 1.0) * (j - 1.0) + (i - 1.0)
        let b = (radial_segments + 1.0) * j + (i - 1.0)
        let c = (radial_segments + 1.0) * j + i
        let d = (radial_segments + 1.0) * (j - 1.0) + i
        // faces
        push3(indices, a, b, d)
        push3(indices, b, c, d)
      }
    }
  }

  fn generate_uvs() -> Unit {
    for i = 0.0; i <= tubular_segments; i = i + 1.0 {
      for j = 0.0; j <= radial_segments; j = j + 1.0 {
        uv.x = i / tubular_segments
        uv.y = j / radial_segments
        push2(uvs, uv.x, uv.y)
      }
    }
  }

  // create buffer data
  for i = 0.0; i < tubular_segments; i = i + 1.0 {
    generate_segment(i)
  }
  // if the geometry is not closed, generate the last row of vertices and normals
  // at the regular position on the given path
  //
  // if the geometry is closed, duplicate the first row of vertices and normals (uvs will differ)
  generate_segment(if closed { 0.0 } else { tubular_segments })
  // uvs are generated in a separate function.
  // this makes it easy compute correct values for closed geometries
  generate_uvs()
  // finally create faces
  generate_indices()
  // build geometry
  buffers.apply(geometry)
  geometry
}

///|
/// `geometry.tangents`, `.normals` and `.binormals`, or `None` where upstream has no such
/// fields. As upstream, `clone` gives the frames of the default path: `new TubeGeometry()`
/// builds them and `copy` does not replace them.
pub fn TubeGeometry::frames(
  geometry : @core.BufferGeometry,
) -> @extras.FrenetFrames? {
  if _tube_frames.has(geometry) {
    Some(_tube_frames.get(geometry))
  } else if geometry.type_ == "TubeGeometry" {
    let frames = tube_default_path().compute_frenet_frames(64, closed=false)
    _tube_frames.set(geometry, frames)
    Some(frames)
  } else {
    None
  }
}

///|
/// `new Curves[ data.type ]().fromJSON( data )` for the 3D built-in curves. A `TubeGeometry`
/// or `extrudePath` needs a curve in 3D space.
fn curve3_from_json(data : Json) -> @extras.Curve[@math.Vector3] {
  guard json_field(data, "type") is Some(String(type_)) else {
    abort("Curves: missing type")
  }
  let curve = match type_ {
    "CatmullRomCurve3" => @extras.CatmullRomCurve3::new()
    "CubicBezierCurve3" => @extras.CubicBezierCurve3::new()
    "LineCurve3" => @extras.LineCurve3::new()
    "QuadraticBezierCurve3" => @extras.QuadraticBezierCurve3::new()
    _ => abort("Curves: no 3D curve type '\{type_}'")
  }
  curve.from_json(data)
}

///|
/// Only works for built-in curves (e.g. `CatmullRomCurve3`), as upstream.
pub fn TubeGeometry::from_json(data : Json) -> @core.BufferGeometry {
  TubeGeometry::new(
    path=curve3_from_json(json_field(data, "path").unwrap()),
    tubular_segments?=json_number(data, "tubularSegments"),
    radius?=json_number(data, "radius"),
    radial_segments?=json_number(data, "radialSegments"),
    closed?=json_bool(data, "closed"),
  )
}
