// Upstream src/extras/ShapeUtils.js.

///|
#external
pub type ShapeUtils

///|
/// Calculate area of a ( 2D ) contour polygon.
pub fn ShapeUtils::area(contour : Array[@math.Vector2]) -> Double {
  let n = contour.length()
  let mut a = 0.0
  let mut p = n - 1
  let mut q = 0
  while q < n {
    a += contour[p].x * contour[q].y - contour[q].x * contour[p].y
    p = q
    q += 1
  }
  a * 0.5
}

///|
pub fn ShapeUtils::is_clock_wise(pts : Array[@math.Vector2]) -> Bool {
  ShapeUtils::area(pts) < 0.0
}

///|
/// Triangulates the given shape definition. As upstream it removes a duplicated end point
/// from `contour` and `holes` in place.
pub fn ShapeUtils::triangulate_shape(
  contour : Array[@math.Vector2],
  holes : Array[Array[@math.Vector2]],
) -> Array[Array[Int32]] {
  let vertices = [] // flat array of vertices like [ x0,y0, x1,y1, x2,y2, ... ]
  let hole_indices = [] // array of hole indices
  let faces = [] // final array of vertex indices like [ [ a,b,d ], [ b,c,d ] ]
  shape_utils_remove_dup_end_pts(contour)
  shape_utils_add_contour(vertices, contour)
  let mut hole_index = contour.length()
  holes.each(shape_utils_remove_dup_end_pts)
  for hole in holes {
    hole_indices.push(hole_index)
    hole_index += hole.length()
    shape_utils_add_contour(vertices, hole)
  }
  let triangles = Earcut::triangulate(vertices, hole_indices)
  for i = 0; i < triangles.length(); i = i + 3 {
    faces.push([triangles[i], triangles[i + 1], triangles[i + 2]])
  }
  faces
}

///|
fn shape_utils_remove_dup_end_pts(points : Array[@math.Vector2]) -> Unit {
  let l = points.length()
  if l > 2 && points[l - 1].equals(points[0]) {
    ignore(points.pop())
  }
}

///|
fn shape_utils_add_contour(
  vertices : Array[Double],
  contour : Array[@math.Vector2],
) -> Unit {
  for point in contour {
    vertices.push(point.x)
    vertices.push(point.y)
  }
}

///|
extern "js" fn extras_js_sort(
  array : @core.JsValue,
  compare : @core.JsValue,
) -> Unit = "(array, compare) => { array.sort( compare ); }"

///|
/// JS `Array.prototype.sort`, which fixes the order an inconsistent comparator gives.
fn[T] extras_sort_by(array : Array[T], compare : (T, T) -> Double) -> Unit {
  extras_js_sort(@core.JsValue::of(array), @core.JsValue::of(compare))
}
