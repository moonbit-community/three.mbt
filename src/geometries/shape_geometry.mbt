// Upstream src/geometries/ShapeGeometry.js.

///|
#external
pub type ShapeGeometry

///|
fn shape_default_shape() -> @extras.Shape {
  @extras.Shape::new(points=[
    @math.Vector2::new(0.0, 0.5),
    @math.Vector2::new(-0.5, -0.5),
    @math.Vector2::new(0.5, -0.5),
  ])
}

///|
/// `parameters.shapes`: a lazy value, which is what `JSON.stringify` makes of the shape
/// (`single`, upstream's non-array form) or shapes upstream holds, and the resources
/// `Object3D::to_json` serializes.
fn shapes_parameter(
  shapes : Array[@extras.Shape],
  single : Bool,
) -> (() -> Json, Array[&@core.SerializableResource]) {
  (
    if single {
      () => shapes[0].to_json()
    } else {
      () => Json::array(shapes.map(shape => shape.to_json()))
    },
    shapes.map(shape => (shape : &@core.SerializableResource)),
  )
}

///|
/// The start of upstream's module-level `toJSON( shapes, ... )`: `data.shapes` as uuids.
fn shapes_to_json(
  parameters : @core.GeometryParameters,
  data : Map[String, Json],
) -> Unit {
  // upstream reads `shapes.uuid` of an undefined `shapes`
  guard parameters.values.contains("shapes") else {
    abort("toJSON: Cannot read properties of undefined (reading 'uuid')")
  }
  data["shapes"] = Json::array(
    parameters.shapes.map(shape => Json::string(shape.uuid())),
  )
}

///|
/// `ShapeGeometry.prototype.toJSON` after `super.toJSON()`.
fn shape_geometry_to_json(
  geometry : @core.BufferGeometry,
  data : Map[String, Json],
) -> Unit {
  shapes_to_json(geometry_parameters(geometry), data)
}

///|
/// `const shape = shapes[ data.shapes[ j ] ]`.
fn shapes_from_json(
  data : Json,
  shapes : Map[String, @extras.Shape],
) -> Array[@extras.Shape] {
  guard json_field(data, "shapes") is Some(Array(uuids)) else {
    abort("fromJSON: missing shapes")
  }
  uuids.map(uuid => {
    guard uuid is String(uuid) else { abort("fromJSON: shapes holds uuids") }
    shapes.get(uuid).unwrap()
  })
}

///|
/// `groups` is upstream's array form of `shapes`.
fn shape_geometry_build(
  shapes : Array[@extras.Shape],
  groups : Bool,
  curve_segments : Int32,
) -> @core.BufferGeometry {
  let (shapes_json, resources) = shapes_parameter(shapes, !groups)
  let geometry = new_geometry(
    "ShapeGeometry",
    {
      "shapes": lazy_placeholder,
      "curveSegments": Json::number(curve_segments.to_double()),
    },
    shapes=resources,
    lazy_values={ "shapes": shapes_json },
    to_json_hook=shape_geometry_to_json,
  )
  // buffers
  let buffers = BufferGeometryBuffers::new()
  let { indices, vertices, normals, uvs, } = buffers
  // helper variables
  let mut group_start = 0
  let mut group_count = 0.0
  fn add_shape(shape : @extras.Shape) -> Unit {
    let index_offset = (vertices.length() / 3).to_double()
    let points = shape.extract_points(curve_segments)
    let mut shape_vertices = points.shape
    let shape_holes = points.holes
    // check direction of vertices
    if !@extras.ShapeUtils::is_clock_wise(shape_vertices) {
      shape_vertices.rev_in_place()
    }
    for shape_hole in shape_holes {
      if @extras.ShapeUtils::is_clock_wise(shape_hole) {
        shape_hole.rev_in_place()
      }
    }
    let faces = @extras.ShapeUtils::triangulate_shape(
      shape_vertices, shape_holes,
    )
    // join vertices of inner and outer paths to a single array
    for shape_hole in shape_holes {
      shape_vertices = shape_vertices + shape_hole
    }
    // vertices, normals, uvs
    for vertex in shape_vertices {
      push3(vertices, vertex.x, vertex.y, 0.0)
      push3(normals, 0.0, 0.0, 1.0)
      push2(uvs, vertex.x, vertex.y) // world uvs
    }
    // indices
    for face in faces {
      let a = face[0].to_double() + index_offset
      let b = face[1].to_double() + index_offset
      let c = face[2].to_double() + index_offset
      push3(indices, a, b, c)
      group_count += 3.0
    }
  }

  // allow single and array values for "shapes" parameter
  for i, shape in shapes {
    add_shape(shape)
    if groups {
      geometry.add_group(group_start, group_count, material_index=i) // enables MultiMaterial support
      group_start += group_count.to_int()
      group_count = 0.0
    }
  }
  // build geometry
  buffers.apply(geometry)
  geometry
}

///|
/// One shape, which upstream gives no groups. See `new_shapes`.
pub fn ShapeGeometry::new(
  shapes~ : @extras.Shape = shape_default_shape(),
  curve_segments~ : Int32 = 12,
) -> @core.BufferGeometry {
  shape_geometry_build([shapes], false, curve_segments)
}

///|
/// Upstream's array form, with one group per shape.
pub fn ShapeGeometry::new_shapes(
  shapes : Array[@extras.Shape],
  curve_segments~ : Int32 = 12,
) -> @core.BufferGeometry {
  shape_geometry_build(shapes, true, curve_segments)
}

///|
pub fn ShapeGeometry::from_json(
  data : Json,
  shapes : Map[String, @extras.Shape],
) -> @core.BufferGeometry {
  ShapeGeometry::new_shapes(
    shapes_from_json(data, shapes),
    curve_segments?=json_number(data, "curveSegments").map(x => x.to_int()),
  )
}
