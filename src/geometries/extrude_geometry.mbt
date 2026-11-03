// Upstream src/geometries/ExtrudeGeometry.js.

///|
#external
pub type ExtrudeGeometry

///|
/// Upstream's `UVGenerator` option. Indices count vertices of the flat `vertices` buffer,
/// which holds JS `undefined` where upstream's does (a fractional `steps`).
pub(all) struct ExtrudeUVGenerator {
  generate_top_uv : (@core.BufferGeometry, Array[Double], Int32, Int32, Int32) -> Array[
    @math.Vector2,
  ]
  generate_side_wall_uv : (
    @core.BufferGeometry,
    Array[Double],
    Int32,
    Int32,
    Int32,
    Int32,
  ) -> Array[@math.Vector2]
}

///|
extern "js" fn js_undefined() -> Double = "() => undefined"

///|
/// `new Vector2( x, y )` where `x` may be undefined, which takes the default 0. NaN stays.
extern "js" fn vector2_default(x : Double) -> Double = "(x) => x === undefined ? 0 : x"

///|
/// `placeholder[ index ]`. It is undefined for a fractional `steps` or `bevelSegments`,
/// which arithmetic and `Float32Array` treat as NaN but `new Vector2()` does not.
fn placeholder_at(placeholder : Array[Double], index : Double) -> Double {
  if index >= 0.0 &&
    index < placeholder.length().to_double() &&
    index == index.floor() {
    placeholder[index.to_int()]
  } else {
    js_undefined()
  }
}

///|
let _extrude_world_uv_generator : ExtrudeUVGenerator = {
  generate_top_uv: (_, vertices, index_a, index_b, index_c) => {
    let a_x = vertices[index_a * 3]
    let a_y = vertices[index_a * 3 + 1]
    let b_x = vertices[index_b * 3]
    let b_y = vertices[index_b * 3 + 1]
    let c_x = vertices[index_c * 3]
    let c_y = vertices[index_c * 3 + 1]
    [
      @math.Vector2::new(a_x, a_y),
      @math.Vector2::new(b_x, b_y),
      @math.Vector2::new(c_x, c_y),
    ]
  },
  generate_side_wall_uv: (_, vertices, index_a, index_b, index_c, index_d) => {
    let a_x = vertices[index_a * 3]
    let a_y = vertices[index_a * 3 + 1]
    let a_z = vertices[index_a * 3 + 2]
    let b_x = vertices[index_b * 3]
    let b_y = vertices[index_b * 3 + 1]
    let b_z = vertices[index_b * 3 + 2]
    let c_x = vertices[index_c * 3]
    let c_y = vertices[index_c * 3 + 1]
    let c_z = vertices[index_c * 3 + 2]
    let d_x = vertices[index_d * 3]
    let d_y = vertices[index_d * 3 + 1]
    let d_z = vertices[index_d * 3 + 2]
    if (a_y - b_y).abs() < (a_x - b_x).abs() {
      [
        @math.Vector2::new(a_x, 1.0 - a_z),
        @math.Vector2::new(b_x, 1.0 - b_z),
        @math.Vector2::new(c_x, 1.0 - c_z),
        @math.Vector2::new(d_x, 1.0 - d_z),
      ]
    } else {
      [
        @math.Vector2::new(a_y, 1.0 - a_z),
        @math.Vector2::new(b_y, 1.0 - b_z),
        @math.Vector2::new(c_y, 1.0 - c_z),
        @math.Vector2::new(d_y, 1.0 - d_z),
      ]
    }
  },
}

///|
let _extrude_epsilon : Double = 2.220446049250313e-16

///|
/// Upstream's `options`, each `None` where the key is absent.
priv struct ExtrudeOptions {
  curve_segments : Int32?
  steps : Double?
  depth : Double?
  bevel_enabled : Bool?
  bevel_thickness : Double?
  bevel_size : Double?
  bevel_offset : Double?
  bevel_segments : Double?
  extrude_path : @extras.Curve[@math.Vector3]?
  uv_generator : ExtrudeUVGenerator?
}

///|
/// `parameters.options` as `toJSON` writes it. Functions leave `UVGenerator` an empty object.
fn ExtrudeOptions::to_json(self : ExtrudeOptions) -> Json {
  let data : Map[String, Json] = Map([])
  fn number(key : String, value : Double?) -> Unit {
    if value is Some(value) {
      data[key] = @math.json_number(value)
    }
  }

  number("curveSegments", self.curve_segments.map(x => x.to_double()))
  number("steps", self.steps)
  number("depth", self.depth)
  if self.bevel_enabled is Some(value) {
    data["bevelEnabled"] = Json::boolean(value)
  }
  number("bevelThickness", self.bevel_thickness)
  number("bevelSize", self.bevel_size)
  number("bevelOffset", self.bevel_offset)
  number("bevelSegments", self.bevel_segments)
  if self.extrude_path is Some(path) {
    data["extrudePath"] = path.to_json()
  }
  if self.uv_generator is Some(_) {
    data["UVGenerator"] = Json::object(Map([]))
  }
  Json::object(data)
}

///|
fn merge_overlapping_points(points : Array[@math.Vector2]) -> Unit {
  guard !points.is_empty() else { return }
  let threshold = 1.0e-10
  let threshold_sq = threshold * threshold
  let mut prev_pos = points[0]
  let mut i = 1
  while i <= points.length() {
    let current_index = i % points.length()
    let current_pos = points[current_index]
    let dx = current_pos.x - prev_pos.x
    let dy = current_pos.y - prev_pos.y
    let dist_sq = dx * dx + dy * dy
    let scaling_factor_sqrt = js_math_max(
      js_math_max(
        js_math_max(current_pos.x.abs(), current_pos.y.abs()),
        prev_pos.x.abs(),
      ),
      prev_pos.y.abs(),
    )
    let threshold_sq_scaled = threshold_sq *
      scaling_factor_sqrt *
      scaling_factor_sqrt
    if dist_sq <= threshold_sq_scaled {
      points.remove(current_index) |> ignore
      continue
    }
    prev_pos = current_pos
    i += 1
  }
}

///|
fn scale_pt2(
  pt : @math.Vector2,
  vec : @math.Vector2,
  size : Double,
) -> @math.Vector2 {
  pt.clone().add_scaled_vector(vec, size)
}

///|
/// Computes for `in_pt` the corresponding point on a new contour, shifted by 1 unit
/// (length of normalized vector) to the left. Walking the contour clockwise, this new
/// contour is outside the old one.
fn get_bevel_vec(
  in_pt : @math.Vector2,
  in_prev : @math.Vector2,
  in_next : @math.Vector2,
) -> @math.Vector2 {
  // resulting translation vector for inPt
  let mut v_trans_x = 0.0
  let mut v_trans_y = 0.0
  let mut shrink_by = 0.0
  // good reading for geometry algorithms (here: line-line intersection)
  // http://geomalgorithms.com/a05-_intersect-1.html
  let v_prev_x = in_pt.x - in_prev.x
  let v_prev_y = in_pt.y - in_prev.y
  let v_next_x = in_next.x - in_pt.x
  let v_next_y = in_next.y - in_pt.y
  let v_prev_lensq = v_prev_x * v_prev_x + v_prev_y * v_prev_y
  // check for collinear edges
  let collinear0 = v_prev_x * v_next_y - v_prev_y * v_next_x
  if collinear0.abs() > _extrude_epsilon {
    // not collinear
    // length of vectors for normalizing
    let v_prev_len = v_prev_lensq.sqrt()
    let v_next_len = (v_next_x * v_next_x + v_next_y * v_next_y).sqrt()
    // shift adjacent points by unit vectors to the left
    let pt_prev_shift_x = in_prev.x - v_prev_y / v_prev_len
    let pt_prev_shift_y = in_prev.y + v_prev_x / v_prev_len
    let pt_next_shift_x = in_next.x - v_next_y / v_next_len
    let pt_next_shift_y = in_next.y + v_next_x / v_next_len
    // scaling factor for v_prev to intersection point
    let sf = (
        (pt_next_shift_x - pt_prev_shift_x) * v_next_y -
        (pt_next_shift_y - pt_prev_shift_y) * v_next_x
      ) /
      (v_prev_x * v_next_y - v_prev_y * v_next_x)
    // vector from inPt to intersection point
    v_trans_x = pt_prev_shift_x + v_prev_x * sf - in_pt.x
    v_trans_y = pt_prev_shift_y + v_prev_y * sf - in_pt.y
    // Don't normalize!, otherwise sharp corners become ugly
    //  but prevent crazy spikes
    let v_trans_lensq = v_trans_x * v_trans_x + v_trans_y * v_trans_y
    if v_trans_lensq <= 2.0 {
      return @math.Vector2::new(v_trans_x, v_trans_y)
    } else {
      shrink_by = (v_trans_lensq / 2.0).sqrt()
    }
  } else {
    // handle special case of collinear edges
    let mut direction_eq = false // assumes: opposite
    if v_prev_x > _extrude_epsilon {
      if v_next_x > _extrude_epsilon {
        direction_eq = true
      }
    } else if v_prev_x < -_extrude_epsilon {
      if v_next_x < -_extrude_epsilon {
        direction_eq = true
      }
    } else if js_math_sign(v_prev_y) == js_math_sign(v_next_y) {
      direction_eq = true
    }
    if direction_eq {
      // lines are a straight sequence
      v_trans_x = -v_prev_y
      v_trans_y = v_prev_x
      shrink_by = v_prev_lensq.sqrt()
    } else {
      // lines are a straight spike
      v_trans_x = v_prev_x
      v_trans_y = v_prev_y
      shrink_by = (v_prev_lensq / 2.0).sqrt()
    }
  }
  @math.Vector2::new(v_trans_x / shrink_by, v_trans_y / shrink_by)
}

///|
/// `getBevelVec` for each point of a closed contour.
fn contour_movements(contour : Array[@math.Vector2]) -> Array[@math.Vector2] {
  let il = contour.length()
  let movements = []
  let mut j = il - 1
  let mut k = 1
  for i = 0; i < il; i = i + 1 {
    if j == il {
      j = 0
    }
    if k == il {
      k = 0
    }
    //  (j)---(i)---(k)
    movements.push(get_bevel_vec(contour[i], contour[j], contour[k]))
    j += 1
    k += 1
  }
  movements
}

///|
fn extrude_add_shape(
  geometry : @core.BufferGeometry,
  shape : @extras.Shape,
  options : ExtrudeOptions,
  vertices_array : Array[Double],
  uv_array : Array[Double],
) -> Unit {
  let placeholder : Array[Double] = []
  // options
  let curve_segments = options.curve_segments.unwrap_or(12)
  let steps = options.steps.unwrap_or(1.0)
  let depth = options.depth.unwrap_or(1.0)
  let mut bevel_enabled = options.bevel_enabled.unwrap_or(true)
  let mut bevel_thickness = options.bevel_thickness.unwrap_or(0.2)
  let mut bevel_size = options.bevel_size.unwrap_or(bevel_thickness - 0.1)
  let mut bevel_offset = options.bevel_offset.unwrap_or(0.0)
  let mut bevel_segments = options.bevel_segments.unwrap_or(3.0)
  let uvgen = options.uv_generator.unwrap_or(_extrude_world_uv_generator)
  //
  let by_path = match options.extrude_path {
    Some(extrude_path) => {
      let divisions = steps.to_int()
      let extrude_pts = extrude_path.get_spaced_points(divisions~)
      bevel_enabled = false // bevels not supported for path extrusion
      // SETUP TNB variables
      let is_closed = match extrude_path.kind {
        CatmullRom(curve) => curve.closed
        _ => false
      }
      Some(
        (
          extrude_pts,
          extrude_path.compute_frenet_frames(divisions, closed=is_closed),
        ),
      )
    }
    None => None
  }
  let binormal = @math.Vector3::new(0.0, 0.0, 0.0)
  let normal = @math.Vector3::new(0.0, 0.0, 0.0)
  let position2 = @math.Vector3::new(0.0, 0.0, 0.0)
  // Safeguards if bevels are not enabled
  if !bevel_enabled {
    bevel_segments = 0.0
    bevel_thickness = 0.0
    bevel_size = 0.0
    bevel_offset = 0.0
  }
  // Variables initialization
  let shape_points = shape.extract_points(curve_segments)
  let mut vertices = shape_points.shape
  let holes = shape_points.holes
  let reverse = !@extras.ShapeUtils::is_clock_wise(vertices)
  if reverse {
    vertices.rev_in_place()
    // Maybe we should also check if holes are in the opposite direction, just to be safe ...
    for ahole in holes {
      if @extras.ShapeUtils::is_clock_wise(ahole) {
        ahole.rev_in_place()
      }
    }
  }
  merge_overlapping_points(vertices)
  holes.each(merge_overlapping_points)
  let num_holes = holes.length()
  // Vertices
  let contour = vertices // vertices has all points but contour has only points of circumference
  for ahole in holes {
    vertices = vertices + ahole
  }
  let vlen = vertices.length()
  // Find directions for point movement
  let contour_moves = contour_movements(contour)
  let holes_movements = []
  let mut vertices_movements = contour_moves.copy()
  for ahole in holes {
    let one_hole_movements = contour_movements(ahole)
    holes_movements.push(one_hole_movements)
    vertices_movements = vertices_movements + one_hole_movements
  }
  fn v(x : Double, y : Double, z : Double) -> Unit {
    push3(placeholder, x, y, z)
  }

  let faces = if bevel_segments == 0.0 {
    @extras.ShapeUtils::triangulate_shape(contour, holes)
  } else {
    let contracted_contour_vertices = []
    let expanded_hole_vertices = []
    // Loop bevelSegments, 1 for the front, 1 for the back
    for b = 0.0; b < bevel_segments; b = b + 1.0 {
      let t = b / bevel_segments
      let z = bevel_thickness * @cmath.cos(t * _geometry_pi / 2.0)
      let bs = bevel_size * @cmath.sin(t * _geometry_pi / 2.0) + bevel_offset
      // contract shape
      for i, point in contour {
        let vert = scale_pt2(point, contour_moves[i], bs)
        v(vert.x, vert.y, -z)
        if t == 0.0 {
          contracted_contour_vertices.push(vert)
        }
      }
      // expand holes
      for h = 0; h < num_holes; h = h + 1 {
        let ahole = holes[h]
        let one_hole_movements = holes_movements[h]
        let one_hole_vertices = []
        for i, point in ahole {
          let vert = scale_pt2(point, one_hole_movements[i], bs)
          v(vert.x, vert.y, -z)
          if t == 0.0 {
            one_hole_vertices.push(vert)
          }
        }
        if t == 0.0 {
          expanded_hole_vertices.push(one_hole_vertices)
        }
      }
    }
    @extras.ShapeUtils::triangulate_shape(
      contracted_contour_vertices, expanded_hole_vertices,
    )
  }
  let bs = bevel_size + bevel_offset
  fn along_path(vert : @math.Vector2, s : Int32) -> Unit {
    guard by_path is Some((extrude_pts, spline_tube)) else { return }
    normal.copy(spline_tube.normals[s]).multiply_scalar(vert.x) |> ignore
    binormal.copy(spline_tube.binormals[s]).multiply_scalar(vert.y) |> ignore
    position2.copy(extrude_pts[s]).add(normal).add(binormal) |> ignore
    v(position2.x, position2.y, position2.z)
  }

  // Back facing vertices
  for i = 0; i < vlen; i = i + 1 {
    let vert = if bevel_enabled {
      scale_pt2(vertices[i], vertices_movements[i], bs)
    } else {
      vertices[i]
    }
    if by_path is None {
      v(vert.x, vert.y, 0.0)
    } else {
      along_path(vert, 0)
    }
  }
  // Add stepped vertices...
  // Including front facing vertices
  for s = 1.0; s <= steps; s = s + 1.0 {
    for i = 0; i < vlen; i = i + 1 {
      let vert = if bevel_enabled {
        scale_pt2(vertices[i], vertices_movements[i], bs)
      } else {
        vertices[i]
      }
      if by_path is None {
        v(vert.x, vert.y, depth / steps * s)
      } else {
        along_path(vert, s.to_int())
      }
    }
  }
  // Add bevel segments planes
  for b = bevel_segments - 1.0; b >= 0.0; b = b - 1.0 {
    let t = b / bevel_segments
    let z = bevel_thickness * @cmath.cos(t * _geometry_pi / 2.0)
    let bs = bevel_size * @cmath.sin(t * _geometry_pi / 2.0) + bevel_offset
    // contract shape
    for i, point in contour {
      let vert = scale_pt2(point, contour_moves[i], bs)
      v(vert.x, vert.y, depth + z)
    }
    // expand holes
    for h, ahole in holes {
      let one_hole_movements = holes_movements[h]
      for i, point in ahole {
        let vert = scale_pt2(point, one_hole_movements[i], bs)
        match by_path {
          None => v(vert.x, vert.y, depth + z)
          Some((extrude_pts, _)) => {
            let last = extrude_pts[(steps - 1.0).to_int()]
            v(vert.x, vert.y + last.y, last.x + z)
          }
        }
      }
    }
  }
  fn add_vertex(index : Double) -> Unit {
    vertices_array.push(placeholder_at(placeholder, index * 3.0 + 0.0))
    vertices_array.push(placeholder_at(placeholder, index * 3.0 + 1.0))
    vertices_array.push(placeholder_at(placeholder, index * 3.0 + 2.0))
  }

  fn add_uv(vector2 : @math.Vector2) -> Unit {
    // upstream's generators build these with `new Vector2()`, which defaults undefined
    push2(uv_array, vector2_default(vector2.x), vector2_default(vector2.y))
  }

  fn f3(a : Double, b : Double, c : Double) -> Unit {
    add_vertex(a)
    add_vertex(b)
    add_vertex(c)
    let next_index = vertices_array.length() / 3
    let uvs = (uvgen.generate_top_uv)(
      geometry,
      vertices_array,
      next_index - 3,
      next_index - 2,
      next_index - 1,
    )
    add_uv(uvs[0])
    add_uv(uvs[1])
    add_uv(uvs[2])
  }

  fn f4(a : Double, b : Double, c : Double, d : Double) -> Unit {
    add_vertex(a)
    add_vertex(b)
    add_vertex(d)
    add_vertex(b)
    add_vertex(c)
    add_vertex(d)
    let next_index = vertices_array.length() / 3
    let uvs = (uvgen.generate_side_wall_uv)(
      geometry,
      vertices_array,
      next_index - 6,
      next_index - 3,
      next_index - 2,
      next_index - 1,
    )
    add_uv(uvs[0])
    add_uv(uvs[1])
    add_uv(uvs[3])
    add_uv(uvs[1])
    add_uv(uvs[2])
    add_uv(uvs[3])
  }

  let vlen = vlen.to_double()
  fn face_at(face : Array[Int32], i : Int32) -> Double {
    face[i].to_double()
  }

  fn build_lid_faces() -> Unit {
    let start = vertices_array.length() / 3
    if bevel_enabled {
      let mut layer = 0.0 // steps + 1
      let mut offset = vlen * layer
      // Bottom faces
      for face in faces {
        f3(
          face_at(face, 2) + offset,
          face_at(face, 1) + offset,
          face_at(face, 0) + offset,
        )
      }
      layer = steps + bevel_segments * 2.0
      offset = vlen * layer
      // Top faces
      for face in faces {
        f3(
          face_at(face, 0) + offset,
          face_at(face, 1) + offset,
          face_at(face, 2) + offset,
        )
      }
    } else {
      // Bottom faces
      for face in faces {
        f3(face_at(face, 2), face_at(face, 1), face_at(face, 0))
      }
      // Top faces
      for face in faces {
        f3(
          face_at(face, 0) + vlen * steps,
          face_at(face, 1) + vlen * steps,
          face_at(face, 2) + vlen * steps,
        )
      }
    }
    geometry.add_group(
      start,
      (vertices_array.length() / 3 - start).to_double(),
      material_index=0,
    )
  }

  fn sidewalls(contour : Array[@math.Vector2], layeroffset : Double) -> Unit {
    for i = contour.length() - 1; i >= 0; i = i - 1 {
      let j = i
      let k = if i - 1 < 0 { contour.length() - 1 } else { i - 1 }
      let sl = steps + bevel_segments * 2.0
      for s = 0.0; s < sl; s = s + 1.0 {
        let slen1 = vlen * s
        let slen2 = vlen * (s + 1.0)
        let a = layeroffset + j.to_double() + slen1
        let b = layeroffset + k.to_double() + slen1
        let c = layeroffset + k.to_double() + slen2
        let d = layeroffset + j.to_double() + slen2
        f4(a, b, c, d)
      }
    }
  }

  // Create faces for the z-sides of the shape
  fn build_side_faces() -> Unit {
    let start = vertices_array.length() / 3
    let mut layeroffset = 0.0
    sidewalls(contour, layeroffset)
    layeroffset += contour.length().to_double()
    for ahole in holes {
      sidewalls(ahole, layeroffset)
      layeroffset += ahole.length().to_double()
    }
    geometry.add_group(
      start,
      (vertices_array.length() / 3 - start).to_double(),
      material_index=1,
    )
  }

  // Faces
  // Top and bottom faces
  build_lid_faces()
  // Sides faces
  build_side_faces()
}

///|
/// `ExtrudeGeometry.prototype.toJSON` after `super.toJSON()`.
fn extrude_geometry_to_json(
  geometry : @core.BufferGeometry,
  data : Map[String, Json],
) -> Unit {
  let parameters = geometry_parameters(geometry)
  shapes_to_json(parameters, data)
  // `Object.assign( {}, options )` with `extrudePath.toJSON()`, which is what
  // `JSON.stringify` makes of `options`; upstream reads `extrudePath` of undefined
  guard parameters.get("options") is Some(options) else {
    abort("toJSON: Cannot read properties of undefined (reading 'extrudePath')")
  }
  data["options"] = options
}

///|
/// `single` is upstream's non-array form of `shapes`. `options_json` is evaluated when
/// serialized, since upstream holds `options.extrudePath` by reference.
fn extrude_build(
  shapes : Array[@extras.Shape],
  single : Bool,
  options : ExtrudeOptions,
  options_json : () -> Json,
) -> @core.BufferGeometry {
  let (shapes_json, resources) = shapes_parameter(shapes, single)
  let geometry = new_geometry(
    "ExtrudeGeometry",
    { "shapes": lazy_placeholder, "options": lazy_placeholder },
    shapes=resources,
    lazy_values={ "shapes": shapes_json, "options": options_json },
    to_json_hook=extrude_geometry_to_json,
  )
  let vertices_array = []
  let uv_array = []
  for shape in shapes {
    extrude_add_shape(geometry, shape, options, vertices_array, uv_array)
  }
  // build geometry
  geometry.set_attribute(
    "position",
    @core.Float32BufferAttribute::new(vertices_array, 3),
  )
  |> ignore
  geometry.set_attribute("uv", @core.Float32BufferAttribute::new(uv_array, 2))
  |> ignore
  geometry.compute_vertex_normals()
  geometry
}

///|
fn extrude_default_shapes() -> Array[@extras.Shape] {
  [
    @extras.Shape::new(points=[
      @math.Vector2::new(0.5, 0.5),
      @math.Vector2::new(-0.5, 0.5),
      @math.Vector2::new(-0.5, -0.5),
      @math.Vector2::new(0.5, -0.5),
    ]),
  ]
}

///|
/// Upstream's `options` are labelled arguments; omitted ones take upstream's defaults and
/// stay out of `parameters`. Omitted `shapes` is upstream's default, a single `Shape`.
pub fn ExtrudeGeometry::new(
  shapes? : Array[@extras.Shape],
  curve_segments? : Int32,
  steps? : Double,
  depth? : Double,
  bevel_enabled? : Bool,
  bevel_thickness? : Double,
  bevel_size? : Double,
  bevel_offset? : Double,
  bevel_segments? : Double,
  extrude_path? : @extras.Curve[@math.Vector3],
  uv_generator? : ExtrudeUVGenerator,
) -> @core.BufferGeometry {
  let options : ExtrudeOptions = {
    curve_segments,
    steps,
    depth,
    bevel_enabled,
    bevel_thickness,
    bevel_size,
    bevel_offset,
    bevel_segments,
    extrude_path,
    uv_generator,
  }
  match shapes {
    Some(shapes) =>
      extrude_build(shapes, false, options, () => options.to_json())
    None =>
      extrude_build(extrude_default_shapes(), true, options, () => {
        options.to_json()
      })
  }
}

///|
pub fn ExtrudeGeometry::from_json(
  data : Json,
  shapes : Map[String, @extras.Shape],
) -> @core.BufferGeometry {
  let geometry_shapes = shapes_from_json(data, shapes)
  guard json_field(data, "options") is Some(Object(fields)) else {
    abort("ExtrudeGeometry: missing options")
  }
  let options_json = fields.copy()
  let extrude_path = match fields.get("extrudePath") {
    Some(path) => {
      let curve = curve3_from_json(path)
      options_json["extrudePath"] = curve.to_json()
      Some(curve)
    }
    None => None
  }
  let options_data = Json::object(options_json)
  let options : ExtrudeOptions = {
    curve_segments: json_number(options_data, "curveSegments").map(x => {
      x.to_int()
    }),
    steps: json_number(options_data, "steps"),
    depth: json_number(options_data, "depth"),
    bevel_enabled: json_bool(options_data, "bevelEnabled"),
    bevel_thickness: json_number(options_data, "bevelThickness"),
    bevel_size: json_number(options_data, "bevelSize"),
    bevel_offset: json_number(options_data, "bevelOffset"),
    bevel_segments: json_number(options_data, "bevelSegments"),
    extrude_path,
    // a generator's functions do not survive JSON, and upstream calls what is left
    uv_generator: if fields.contains("UVGenerator") {
      Some({
        generate_top_uv: (_, _, _, _, _) => {
          abort("ExtrudeGeometry: uvgen.generateTopUV is not a function")
        },
        generate_side_wall_uv: (_, _, _, _, _, _) => {
          abort("ExtrudeGeometry: uvgen.generateSideWallUV is not a function")
        },
      })
    } else {
      None
    },
  }
  extrude_build(geometry_shapes, false, options, () => options_data)
}
