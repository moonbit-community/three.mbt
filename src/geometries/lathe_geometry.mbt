// Upstream src/geometries/LatheGeometry.js.

///|
#external
pub type LatheGeometry

///|
fn lathe_default_points() -> Array[@math.Vector2] {
  [
    @math.Vector2::new(0.0, -0.5),
    @math.Vector2::new(0.5, 0.0),
    @math.Vector2::new(0.0, 0.5),
  ]
}

///|
/// The constructor body. `points_json` gives `parameters.points` when serialized, since
/// upstream holds the caller's array.
fn lathe_build(
  points : Array[@math.Vector2],
  points_json : () -> Json,
  segments : Double,
  phi_start : Double,
  phi_length : Double,
) -> @core.BufferGeometry {
  let geometry = new_geometry(
    "LatheGeometry",
    {
      "points": lazy_placeholder,
      "segments": @math.json_number(segments),
      "phiStart": @math.json_number(phi_start),
      "phiLength": @math.json_number(phi_length),
    },
    lazy_values={ "points": points_json },
  )
  let segments = segments.floor()
  // clamp phiLength so it's in range of [ 0, 2PI ]
  let phi_length = @math.clamp(phi_length, 0.0, _geometry_two_pi)
  // buffers
  let indices : Array[Double] = []
  let vertices : Array[Double] = []
  let uvs : Array[Double] = []
  let init_normals : Array[Double] = []
  let normals : Array[Double] = []
  // helper variables
  let inverse_segments = 1.0 / segments
  let vertex = @math.Vector3::new(0.0, 0.0, 0.0)
  let uv = @math.Vector2::new(0.0, 0.0)
  let normal = @math.Vector3::new(0.0, 0.0, 0.0)
  let cur_normal = @math.Vector3::new(0.0, 0.0, 0.0)
  let prev_normal = @math.Vector3::new(0.0, 0.0, 0.0)
  let mut dx = 0.0
  let mut dy = 0.0
  let last = points.length() - 1
  // pre-compute normals for initial "meridian"
  for j = 0; j <= last; j = j + 1 {
    if j == 0 {
      // special handling for 1st vertex on path
      dx = points[j + 1].x - points[j].x
      dy = points[j + 1].y - points[j].y
      normal.x = dy * 1.0
      normal.y = -dx
      normal.z = dy * 0.0
      prev_normal.copy(normal) |> ignore
      normal.normalize() |> ignore
      push3(init_normals, normal.x, normal.y, normal.z)
    } else if j == last {
      // special handling for last Vertex on path
      prev_normal.normalize() |> ignore
      push3(init_normals, prev_normal.x, prev_normal.y, prev_normal.z)
    } else {
      // default handling for all vertices in between
      dx = points[j + 1].x - points[j].x
      dy = points[j + 1].y - points[j].y
      normal.x = dy * 1.0
      normal.y = -dx
      normal.z = dy * 0.0
      cur_normal.copy(normal) |> ignore
      normal.x += prev_normal.x
      normal.y += prev_normal.y
      normal.z += prev_normal.z
      normal.normalize() |> ignore
      push3(init_normals, normal.x, normal.y, normal.z)
      prev_normal.copy(cur_normal) |> ignore
    }
  }
  // generate vertices, uvs and normals
  for i = 0.0; i <= segments; i = i + 1.0 {
    let phi = phi_start + i * inverse_segments * phi_length
    let sin = @cmath.sin(phi)
    let cos = @cmath.cos(phi)
    for j = 0; j <= last; j = j + 1 {
      // vertex
      vertex.x = points[j].x * sin
      vertex.y = points[j].y
      vertex.z = points[j].x * cos
      push3(vertices, vertex.x, vertex.y, vertex.z)
      // uv
      uv.x = i / segments
      uv.y = j.to_double() / last.to_double()
      push2(uvs, uv.x, uv.y)
      // normal
      let x = init_normals[3 * j + 0] * sin
      let y = init_normals[3 * j + 1]
      let z = init_normals[3 * j + 0] * cos
      push3(normals, x, y, z)
    }
  }
  // indices
  let length = points.length().to_double()
  for i = 0.0; i < segments; i = i + 1.0 {
    for j = 0; j < last; j = j + 1 {
      let base = j.to_double() + i * length
      let a = base
      let b = base + length
      let c = base + length + 1.0
      let d = base + 1.0
      // faces
      push3(indices, a, b, d)
      push3(indices, c, d, b)
    }
  }
  // build geometry
  geometry.set_index(indices) |> ignore
  geometry.set_attribute(
    "position",
    @core.Float32BufferAttribute::new(vertices, 3),
  )
  |> ignore
  geometry.set_attribute("uv", @core.Float32BufferAttribute::new(uvs, 2))
  |> ignore
  geometry.set_attribute(
    "normal",
    @core.Float32BufferAttribute::new(normals, 3),
  )
  |> ignore
  geometry
}

///|
fn vector2_json(point : @math.Vector2) -> Json {
  Json::object({
    "x": @math.json_number(point.x),
    "y": @math.json_number(point.y),
  })
}

///|
pub fn LatheGeometry::new(
  points~ : Array[@math.Vector2] = lathe_default_points(),
  segments~ : Double = 12.0,
  phi_start~ : Double = 0.0,
  phi_length~ : Double = _geometry_two_pi,
) -> @core.BufferGeometry {
  let points_json = () => Json::array(points.map(vector2_json))
  lathe_build(points, points_json, segments, phi_start, phi_length)
}

///|
/// `points` as `Vector3`s, which upstream also accepts. `z` is ignored but serialized.
pub fn LatheGeometry::new_vector3(
  points : Array[@math.Vector3],
  segments~ : Double = 12.0,
  phi_start~ : Double = 0.0,
  phi_length~ : Double = _geometry_two_pi,
) -> @core.BufferGeometry {
  let points_json = () => {
    Json::array(
      points.map(point => {
        Json::object({
          "x": @math.json_number(point.x),
          "y": @math.json_number(point.y),
          "z": @math.json_number(point.z),
        })
      }),
    )
  }
  lathe_build(
    points.map(point => @math.Vector2::new(point.x, point.y)),
    points_json,
    segments,
    phi_start,
    phi_length,
  )
}

///|
pub fn LatheGeometry::from_json(data : Json) -> @core.BufferGeometry {
  let segments = json_number(data, "segments").unwrap_or(12.0)
  let phi_start = json_number(data, "phiStart").unwrap_or(0.0)
  let phi_length = json_number(data, "phiLength").unwrap_or(_geometry_two_pi)
  match json_field(data, "points") {
    Some(Array(points) as points_json) => {
      let points = points.map(point => {
        @math.Vector2::new(
          json_number(point, "x").unwrap(),
          json_number(point, "y").unwrap(),
        )
      })
      lathe_build(points, () => points_json, segments, phi_start, phi_length)
    }
    _ => LatheGeometry::new(segments~, phi_start~, phi_length~)
  }
}
