// Upstream src/extras/core/ShapePath.js.

///|
pub(all) struct ShapePath {
  mut type_ : String
  mut color : @math.Color
  mut sub_paths : Array[Path]
  mut current_path : Path?
  mut user_data : @core.JsValue
}

///|
pub fn ShapePath::new() -> ShapePath {
  {
    type_: "ShapePath",
    color: @math.Color::new(1.0, 1.0, 1.0),
    sub_paths: [],
    current_path: None,
    user_data: @core.JsValue::object(),
  }
}

///|
fn ShapePath::path(self : ShapePath) -> Path {
  match self.current_path {
    Some(path) => path
    None => abort("ShapePath: no current path")
  }
}

///|
pub fn ShapePath::move_to(
  self : ShapePath,
  x : Double,
  y : Double,
) -> ShapePath {
  let path = Path::new()
  self.current_path = Some(path)
  self.sub_paths.push(path)
  ignore(path.move_to(x, y))
  self
}

///|
pub fn ShapePath::line_to(
  self : ShapePath,
  x : Double,
  y : Double,
) -> ShapePath {
  ignore(self.path().line_to(x, y))
  self
}

///|
pub fn ShapePath::quadratic_curve_to(
  self : ShapePath,
  a_c_px : Double,
  a_c_py : Double,
  a_x : Double,
  a_y : Double,
) -> ShapePath {
  ignore(self.path().quadratic_curve_to(a_c_px, a_c_py, a_x, a_y))
  self
}

///|
pub fn ShapePath::bezier_curve_to(
  self : ShapePath,
  a_c_p1x : Double,
  a_c_p1y : Double,
  a_c_p2x : Double,
  a_c_p2y : Double,
  a_x : Double,
  a_y : Double,
) -> ShapePath {
  ignore(
    self.path().bezier_curve_to(a_c_p1x, a_c_p1y, a_c_p2x, a_c_p2y, a_x, a_y),
  )
  self
}

///|
pub fn ShapePath::spline_thru(
  self : ShapePath,
  pts : Array[@math.Vector2],
) -> ShapePath {
  ignore(self.path().spline_thru(pts))
  self
}

///|
priv enum ShapePathRole {
  Outer
  Hole
}

///|
priv struct ShapePathEntry {
  sub_path : Path
  points : Array[@math.Vector2]
  bounding_box : @math.Box2
  interior_point : @math.Vector2
  abs_area : Double
  mut winding : Int32
  mut container : ShapePathEntry?
  mut exclude : Bool
  mut role : ShapePathRole?
  /// Upstream `shapeByEntry`.
  mut shape : Shape?
}

///|
/// Point-in-polygon test using the even-odd ray-casting rule. Valid for
/// simple (non self-intersecting) polygons.
fn shape_path_point_in_polygon(
  p : @math.Vector2,
  polygon : Array[@math.Vector2],
) -> Bool {
  let mut inside = false
  let n = polygon.length()
  let mut j = n - 1
  for i in 0..<n {
    let a = polygon[i]
    let b = polygon[j]
    if (a.y > p.y) != (b.y > p.y) &&
      p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x {
      inside = !inside
    }
    j = i
  }
  inside
}

///|
/// Returns a point guaranteed to be strictly inside the given simple
/// polygon. First tries the bounding-box center; if that falls outside
/// the polygon, casts a horizontal ray at the center's y and picks the
/// midpoint between the first two sorted intercepts.
///
/// Port of paper.js' Path#getInteriorPoint()
/// https://github.com/paperjs/paper.js/blob/develop/src/path/PathItem.Boolean.js
fn shape_path_get_interior_point(
  polygon : Array[@math.Vector2],
  bounding_box : @math.Box2,
) -> @math.Vector2 {
  let point = bounding_box.get_center(@math.Vector2::new(0.0, 0.0))
  if shape_path_point_in_polygon(point, polygon) {
    return point
  }
  let y = point.y
  let intercepts : Array[Double] = []
  let n = polygon.length()
  for i in 0..<n {
    let a = polygon[i]
    let b = polygon[(i + 1) % n]
    // Half-open crossing rule — counts each vertex exactly once and
    // skips horizontal edges.
    if (a.y > y) != (b.y > y) {
      let x = a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y)
      intercepts.push(x)
    }
  }
  if intercepts.length() > 1 {
    extras_sort_by(intercepts, (a, b) => a - b)
    point.x = (intercepts[0] + intercepts[1]) / 2.0
  }
  point
}

///|
/// `( userData.style && userData.style.fillRule ) || 'nonzero'`.
extern "js" fn shape_path_fill_rule(user_data : @core.JsValue) -> String =
  #|(userData) => String( ( userData.style && userData.style.fillRule ) || 'nonzero' )

///|
/// Converts the paths into an array of shapes.
pub fn ShapePath::to_shapes(self : ShapePath) -> Array[Shape] {
  // Resolve fill-rule. Defaults to 'nonzero'.
  let mut fill_rule = shape_path_fill_rule(self.user_data)
  if fill_rule != "nonzero" && fill_rule != "evenodd" {
    @core.warn(
      "Fill-rule \"\{fill_rule}\" is not supported, falling back to \"nonzero\".",
    )
    fill_rule = "nonzero"
  }
  // Predicate that decides whether a winding number falls inside the fill
  // region, per the SVG fill-rule spec. Works for negative windings too,
  // because bitwise AND preserves odd/even under two's complement.
  let is_inside = if fill_rule == "nonzero" {
    (w : Int32) => w != 0
  } else {
    (w : Int32) => (w & 1) != 0
  }
  // Build an entry per usable subpath. Self-winding follows the standard
  // convention used by ShapeUtils: counter-clockwise (signed area > 0)
  // contributes +1 to the winding number at an interior point,
  // clockwise contributes -1.
  let entries : Array[ShapePathEntry] = []
  for sub_path in self.sub_paths {
    let points = sub_path.get_points()
    if points.length() < 3 {
      continue
    }
    let area = ShapeUtils::area(points)
    if area == 0.0 {
      continue
    }
    let bounding_box = @math.Box2::new()
    for point in points {
      ignore(bounding_box.expand_by_point(point))
    }
    entries.push({
      sub_path,
      points,
      bounding_box,
      interior_point: shape_path_get_interior_point(points, bounding_box),
      abs_area: area.abs(),
      winding: if area < 0.0 {
        -1
      } else {
        1
      },
      container: None,
      exclude: false,
      role: None,
      shape: None,
    })
  }
  // Sort by area descending. This guarantees that any subpath that could
  // contain `entries[i]` is located at a smaller index and has already
  // been processed when it's entries[i]'s turn. Port of paper.js'
  // reorientPaths() algorithm.
  extras_sort_by(entries, (a, b) => b.abs_area - a.abs_area)
  // Walk already-processed entries from closest-in-size to largest,
  // stopping at the innermost container. Accumulate the container's
  // cumulative winding into this entry's winding so that the final value
  // equals the winding number at this entry's interior point.
  //
  // A subpath only contributes to the fill boundary when crossing it
  // actually flips the "insideness" per the fill rule; otherwise it's a
  // redundant overlap and gets excluded to avoid double-counting.
  for i, entry in entries {
    let mut container_winding = 0
    for j = i - 1; j >= 0; j = j - 1 {
      let candidate = entries[j]
      if !candidate.bounding_box.contains_box(entry.bounding_box) {
        continue
      }
      if !shape_path_point_in_polygon(entry.interior_point, candidate.points) {
        continue
      }
      entry.container = if candidate.exclude {
        candidate.container
      } else {
        Some(candidate)
      }
      container_winding = candidate.winding
      entry.winding += container_winding
      break
    }
    if is_inside(entry.winding) == is_inside(container_winding) {
      entry.exclude = true
    }
  }
  // Classify retained entries. An entry is an outer shape if it has no
  // container or if its container is itself a hole (a solid nested inside
  // a hole becomes a new top-level shape); otherwise it's a hole in its
  // container. Entries were already sorted outermost-first, so each
  // container's role is known by the time we look at it.
  for entry in entries {
    if entry.exclude {
      continue
    }
    entry.role = match entry.container {
      None => Some(Outer)
      Some({ role: Some(Hole), .. }) => Some(Outer)
      Some(_) => Some(Hole)
    }
  }
  // Build Shapes for outers first, then attach holes to their container's
  // Shape.
  let shapes = []
  for entry in entries {
    if entry.exclude || !(entry.role is Some(Outer)) {
      continue
    }
    let shape = Shape::new()
    shape.set_curves(entry.sub_path.curves())
    shapes.push(shape)
    entry.shape = Some(shape)
  }
  for entry in entries {
    if entry.exclude || !(entry.role is Some(Hole)) {
      continue
    }
    guard entry.container is Some({ shape: Some(shape), .. }) else { continue }
    let hole = Path::new()
    hole.set_curves(entry.sub_path.curves())
    shape.holes().push(hole)
  }
  shapes
}
