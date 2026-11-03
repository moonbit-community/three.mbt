// Upstream src/geometries/PolyhedronGeometry.js.

///|
#external
pub type PolyhedronGeometry

///|
/// `array[ index ]`. Where upstream reads `undefined`, which turns the vertex into NaNs.
fn number_at(array : Array[Double], index : Double) -> Double {
  if index >= 0.0 &&
    index < array.length().to_double() &&
    index == index.floor() {
    array[index.to_int()]
  } else {
    @double.not_a_number
  }
}

///|
pub fn PolyhedronGeometry::new(
  vertices~ : Array[Double] = [],
  indices~ : Array[Double] = [],
  radius~ : Double = 1.0,
  detail~ : Double = 0.0,
) -> @core.BufferGeometry {
  let geometry = new_geometry("PolyhedronGeometry", {
    "vertices": Json::array(vertices.map(value => @math.json_number(value))),
    "indices": Json::array(indices.map(value => @math.json_number(value))),
    "radius": @math.json_number(radius),
    "detail": @math.json_number(detail),
  })
  // default buffer data
  let vertex_buffer : Array[Double] = []
  let uv_buffer : Array[Double] = []
  fn push_vertex(vertex : @math.Vector3) -> Unit {
    push3(vertex_buffer, vertex.x, vertex.y, vertex.z)
  }

  fn get_vertex_by_index(index : Double, vertex : @math.Vector3) -> Unit {
    let stride = index * 3.0
    vertex.x = number_at(vertices, stride + 0.0)
    vertex.y = number_at(vertices, stride + 1.0)
    vertex.z = number_at(vertices, stride + 2.0)
  }

  fn subdivide_face(
    a : @math.Vector3,
    b : @math.Vector3,
    c : @math.Vector3,
    detail : Double,
  ) -> Unit {
    let cols = detail + 1.0
    // we use this multidimensional array as a data structure for creating the subdivision
    let v : Array[Array[@math.Vector3]] = []
    // construct all of the vertices for this subdivision
    for i = 0.0; i <= cols; i = i + 1.0 {
      let column = []
      v.push(column)
      let aj = a.clone().lerp(c, i / cols)
      let bj = b.clone().lerp(c, i / cols)
      let rows = cols - i
      for j = 0.0; j <= rows; j = j + 1.0 {
        if j == 0.0 && i == cols {
          column.push(aj)
        } else {
          column.push(aj.clone().lerp(bj, j / rows))
        }
      }
    }
    // construct all of the faces
    for i = 0; i.to_double() < cols; i = i + 1 {
      for j = 0; j.to_double() < 2.0 * (cols - i.to_double()) - 1.0; j = j + 1 {
        let k = j / 2
        if j % 2 == 0 {
          push_vertex(v[i][k + 1])
          push_vertex(v[i + 1][k])
          push_vertex(v[i][k])
        } else {
          push_vertex(v[i][k + 1])
          push_vertex(v[i + 1][k + 1])
          push_vertex(v[i + 1][k])
        }
      }
    }
  }

  fn subdivide(detail : Double) -> Unit {
    let a = @math.Vector3::new(0.0, 0.0, 0.0)
    let b = @math.Vector3::new(0.0, 0.0, 0.0)
    let c = @math.Vector3::new(0.0, 0.0, 0.0)
    // iterate over all faces and apply a subdivision with the given detail value
    for i = 0; i < indices.length(); i = i + 3 {
      // get the vertices of the face
      get_vertex_by_index(number_at(indices, (i + 0).to_double()), a)
      get_vertex_by_index(number_at(indices, (i + 1).to_double()), b)
      get_vertex_by_index(number_at(indices, (i + 2).to_double()), c)
      // perform subdivision
      subdivide_face(a, b, c, detail)
    }
  }

  fn apply_radius(radius : Double) -> Unit {
    let vertex = @math.Vector3::new(0.0, 0.0, 0.0)
    // iterate over the entire buffer and apply the radius to each vertex
    for i = 0; i < vertex_buffer.length(); i = i + 3 {
      vertex.x = vertex_buffer[i + 0]
      vertex.y = vertex_buffer[i + 1]
      vertex.z = vertex_buffer[i + 2]
      vertex.normalize().multiply_scalar(radius) |> ignore
      vertex_buffer[i + 0] = vertex.x
      vertex_buffer[i + 1] = vertex.y
      vertex_buffer[i + 2] = vertex.z
    }
  }

  // Angle around the Y axis, counter-clockwise when looking from above.
  fn azimuth(vector : @math.Vector3) -> Double {
    @cmath.atan2(vector.z, -vector.x)
  }

  // Angle above the XZ plane.
  fn inclination(vector : @math.Vector3) -> Double {
    @cmath.atan2(-vector.y, (vector.x * vector.x + vector.z * vector.z).sqrt())
  }

  fn correct_uv(
    uv : @math.Vector2,
    stride : Int32,
    vector : @math.Vector3,
    azimuth : Double,
  ) -> Unit {
    if azimuth < 0.0 && uv.x == 1.0 {
      uv_buffer[stride] = uv.x - 1.0
    }
    if vector.x == 0.0 && vector.z == 0.0 {
      uv_buffer[stride] = azimuth / 2.0 / _geometry_pi + 0.5
    }
  }

  fn correct_uvs() -> Unit {
    let a = @math.Vector3::new(0.0, 0.0, 0.0)
    let b = @math.Vector3::new(0.0, 0.0, 0.0)
    let c = @math.Vector3::new(0.0, 0.0, 0.0)
    let centroid = @math.Vector3::new(0.0, 0.0, 0.0)
    let uv_a = @math.Vector2::new(0.0, 0.0)
    let uv_b = @math.Vector2::new(0.0, 0.0)
    let uv_c = @math.Vector2::new(0.0, 0.0)
    for i = 0, j = 0; i < vertex_buffer.length(); i = i + 9, j = j + 6 {
      a.set(vertex_buffer[i + 0], vertex_buffer[i + 1], vertex_buffer[i + 2])
      |> ignore
      b.set(vertex_buffer[i + 3], vertex_buffer[i + 4], vertex_buffer[i + 5])
      |> ignore
      c.set(vertex_buffer[i + 6], vertex_buffer[i + 7], vertex_buffer[i + 8])
      |> ignore
      uv_a.set(uv_buffer[j + 0], uv_buffer[j + 1]) |> ignore
      uv_b.set(uv_buffer[j + 2], uv_buffer[j + 3]) |> ignore
      uv_c.set(uv_buffer[j + 4], uv_buffer[j + 5]) |> ignore
      centroid.copy(a).add(b).add(c).divide_scalar(3.0) |> ignore
      let azi = azimuth(centroid)
      correct_uv(uv_a, j + 0, a, azi)
      correct_uv(uv_b, j + 2, b, azi)
      correct_uv(uv_c, j + 4, c, azi)
    }
  }

  fn correct_seam() -> Unit {
    // handle case when face straddles the seam, see #3269
    for i = 0; i < uv_buffer.length(); i = i + 6 {
      // uv data of a single face
      let x0 = uv_buffer[i + 0]
      let x1 = uv_buffer[i + 2]
      let x2 = uv_buffer[i + 4]
      let max = js_math_max(js_math_max(x0, x1), x2)
      let min = js_math_min(js_math_min(x0, x1), x2)
      // 0.9 is somewhat arbitrary
      if max > 0.9 && min < 0.1 {
        if x0 < 0.2 {
          uv_buffer[i + 0] += 1.0
        }
        if x1 < 0.2 {
          uv_buffer[i + 2] += 1.0
        }
        if x2 < 0.2 {
          uv_buffer[i + 4] += 1.0
        }
      }
    }
  }

  fn generate_uvs() -> Unit {
    let vertex = @math.Vector3::new(0.0, 0.0, 0.0)
    for i = 0; i < vertex_buffer.length(); i = i + 3 {
      vertex.x = vertex_buffer[i + 0]
      vertex.y = vertex_buffer[i + 1]
      vertex.z = vertex_buffer[i + 2]
      let u = azimuth(vertex) / 2.0 / _geometry_pi + 0.5
      let v = inclination(vertex) / _geometry_pi + 0.5
      push2(uv_buffer, u, 1.0 - v)
    }
    correct_uvs()
    correct_seam()
  }

  // the subdivision creates the vertex buffer data
  subdivide(detail)
  // all vertices should lie on a conceptual sphere with a given radius
  apply_radius(radius)
  // finally, create the uv data
  generate_uvs()
  // build non-indexed geometry
  geometry.set_attribute(
    "position",
    @core.Float32BufferAttribute::new(vertex_buffer, 3),
  )
  |> ignore
  geometry.set_attribute(
    "normal",
    @core.Float32BufferAttribute::new(vertex_buffer, 3),
  )
  |> ignore
  geometry.set_attribute("uv", @core.Float32BufferAttribute::new(uv_buffer, 2))
  |> ignore
  if detail == 0.0 {
    geometry.compute_vertex_normals() // flat normals
  } else {
    geometry.normalize_normals() // smooth normals
  }
  geometry
}

///|
pub fn PolyhedronGeometry::from_json(data : Json) -> @core.BufferGeometry {
  PolyhedronGeometry::new(
    vertices?=json_numbers(data, "vertices"),
    indices?=json_numbers(data, "indices"),
    radius?=json_number(data, "radius"),
    detail?=json_number(data, "detail"),
  )
}

///|
/// What the four `PolyhedronGeometry` subclasses do after `super()`.
fn polyhedron_subclass(
  type_ : String,
  vertices : Array[Double],
  indices : Array[Double],
  radius : Double,
  detail : Double,
) -> @core.BufferGeometry {
  let geometry = PolyhedronGeometry::new(vertices~, indices~, radius~, detail~)
  geometry.type_ = type_
  geometry.parameters = Some({
    values: {
      "radius": @math.json_number(radius),
      "detail": @math.json_number(detail),
    },
    shapes: [],
  })
  geometry
}
