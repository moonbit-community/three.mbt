// Geometry and payload helpers for the src/objects tests, which upstream builds from
// src/geometries.

///|
/// `new PlaneGeometry()`.
fn test_plane_geometry() -> @core.BufferGeometry {
  let geometry = @core.BufferGeometry::new()
  ignore(geometry.set_index([0, 2, 1, 2, 3, 1]))
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new(
        [-0.5, 0.5, 0.0, 0.5, 0.5, 0.0, -0.5, -0.5, 0.0, 0.5, -0.5, 0.0],
        3,
      ),
    ),
  )
  ignore(
    geometry.set_attribute(
      "normal",
      @core.Float32BufferAttribute::new(
        [0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0],
        3,
      ),
    ),
  )
  ignore(
    geometry.set_attribute(
      "uv",
      @core.Float32BufferAttribute::new(
        [0.0, 1.0, 1.0, 1.0, 0.0, 0.0, 1.0, 0.0],
        2,
      ),
    ),
  )
  geometry
}

///|
/// A unit cube with 24 vertices and 36 indices, like `new BoxGeometry( 1, 1, 1 )`.
fn test_box_geometry() -> @core.BufferGeometry {
  let corners : Array[Double] = [
    // +x
    0.5, 0.5, 0.5, 0.5, -0.5, 0.5, 0.5, -0.5, -0.5, 0.5, 0.5, -0.5,
    // -x
     -0.5, 0.5, -0.5, -0.5, -0.5, -0.5, -0.5, -0.5, 0.5, -0.5, 0.5, 0.5,
    // +y
     -0.5, 0.5, -0.5, -0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, -0.5,
    // -y
     -0.5, -0.5, 0.5, -0.5, -0.5, -0.5, 0.5, -0.5, -0.5, 0.5, -0.5, 0.5,
    // +z
     -0.5, 0.5, 0.5, -0.5, -0.5, 0.5, 0.5, -0.5, 0.5, 0.5, 0.5, 0.5,
    // -z
     0.5, 0.5, -0.5, 0.5, -0.5, -0.5, -0.5, -0.5, -0.5, -0.5, 0.5, -0.5,
  ]
  let indices : Array[Int32] = []
  for face in 0..<6 {
    let v = face * 4
    indices.push_iter([v, v + 1, v + 2, v, v + 2, v + 3].iter())
  }
  let geometry = @core.BufferGeometry::new()
  ignore(geometry.set_index(indices))
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new(corners, 3),
    ),
  )
  geometry
}

///|
extern "js" fn test_cos(x : Double) -> Double = "Math.cos"

///|
extern "js" fn test_sin(x : Double) -> Double = "Math.sin"

///|
/// A unit sphere like `new SphereGeometry( 1, segments, segments )`.
fn test_sphere_geometry(segments : Int32) -> @core.BufferGeometry {
  let vertices : Array[Double] = []
  let indices : Array[Int32] = []
  let row = segments + 1
  for iy in 0..<=segments {
    let v = iy.to_double() / segments.to_double()
    for ix in 0..<=segments {
      let u = ix.to_double() / segments.to_double()
      vertices.push(-test_cos(u * 2.0 * test_pi()) * test_sin(v * test_pi()))
      vertices.push(test_cos(v * test_pi()))
      vertices.push(test_sin(u * 2.0 * test_pi()) * test_sin(v * test_pi()))
    }
  }
  for iy in 0..<segments {
    for ix in 0..<segments {
      let a = iy * row + ix + 1
      let b = iy * row + ix
      let c = (iy + 1) * row + ix
      let d = (iy + 1) * row + ix + 1
      if iy != 0 {
        indices.push_iter([a, b, d].iter())
      }
      if iy != segments - 1 {
        indices.push_iter([b, c, d].iter())
      }
    }
  }
  let geometry = @core.BufferGeometry::new()
  ignore(geometry.set_index(indices))
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new(vertices, 3),
    ),
  )
  geometry
}

///|
fn test_mesh_data(object : @core.Object3D) -> @core.Mesh {
  guard object.kind is Mesh(mesh) else { abort("not a Mesh") }
  mesh
}

///|
fn test_line_data(object : @core.Object3D) -> @core.Line {
  guard object.kind is Line(line) else { abort("not a Line") }
  line
}

///|
fn test_points_data(object : @core.Object3D) -> @core.Points {
  guard object.kind is Points(points) else { abort("not Points") }
  points
}

///|
fn test_morph_geometry() -> @core.BufferGeometry {
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new([0.0, 0.0, 0.0, 1.0, 1.0, 1.0], 3),
    ),
  )
  let target = @core.Float32BufferAttribute::new(
    [1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
    3,
  )
  target.name = "target"
  geometry.morph_attributes["position"] = [Buffer(target)]
  geometry
}

///|
fn test_same_slot(a : @core.MaterialSlot, b : @core.MaterialSlot) -> Bool {
  match (a, b) {
    (Single(a), Single(b)) => physical_equal(a, b)
    (Multiple(a), Multiple(b)) => physical_equal(a, b)
    _ => false
  }
}
