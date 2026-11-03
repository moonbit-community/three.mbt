// Upstream src/extras/lib/earcut.js, mapbox/earcut 3.0.2.
//
// `data` is read with `unsafe_get`, so an index past the end is `undefined` here too and
// degenerate inputs compare as they do upstream.

///|
priv struct EarcutNode {
  i : Int32 // vertex index in coordinates array
  x : Double // vertex coordinates
  y : Double
  mut prev_node : EarcutNode? // previous and next vertex nodes in a polygon ring
  mut next_node : EarcutNode?
  mut z : Int32 // z-order curve value
  mut prev_z : EarcutNode? // previous and next nodes in z-order
  mut next_z : EarcutNode?
  mut steiner : Bool // indicates whether this is a steiner point
}

///|
fn EarcutNode::prev(self : EarcutNode) -> EarcutNode {
  match self.prev_node {
    Some(node) => node
    None => abort("earcut: unlinked node")
  }
}

///|
fn EarcutNode::next(self : EarcutNode) -> EarcutNode {
  match self.next_node {
    Some(node) => node
    None => abort("earcut: unlinked node")
  }
}

///|
extern "js" fn earcut_math_min2(a : Double, b : Double) -> Double = "Math.min"

///|
extern "js" fn earcut_math_max2(a : Double, b : Double) -> Double = "Math.max"

///|
extern "js" fn earcut_math_min3(a : Double, b : Double, c : Double) -> Double = "Math.min"

///|
extern "js" fn earcut_math_max3(a : Double, b : Double, c : Double) -> Double = "Math.max"

///|
/// JS `x | 0`.
extern "js" fn earcut_to_int32(x : Double) -> Int32 = "(x) => x | 0"

///|
/// JS truthiness of a number.
fn earcut_truthy(x : Double) -> Bool {
  x != 0.0 && x == x
}

///|
/// The result of `earcut_flatten`.
pub(all) struct EarcutFlatten {
  vertices : Array[Double]
  holes : Array[Int32]
  dimensions : Int32
}

///|
/// Upstream's default export. Empty `hole_indices` is upstream's `undefined`.
pub fn earcut(
  data : Array[Double],
  hole_indices : Array[Int32],
  dim~ : Int32 = 2,
) -> Array[Int32] {
  let has_holes = hole_indices.length() > 0
  let outer_len = if has_holes { hole_indices[0] * dim } else { data.length() }
  let triangles = []
  guard earcut_linked_list(data, 0, outer_len, dim, true) is Some(outer) else {
    return triangles
  }
  let mut outer_node = outer
  if physical_equal(outer_node.next(), outer_node.prev()) {
    return triangles
  }
  let mut min_x = 0.0
  let mut min_y = 0.0
  let mut inv_size = 0.0
  if has_holes {
    outer_node = earcut_eliminate_holes(data, hole_indices, outer_node, dim)
  }
  // if the shape is not too simple, we'll use z-order curve hash later; calculate polygon bbox
  if data.length() > 80 * dim {
    min_x = data.unsafe_get(0)
    min_y = data.unsafe_get(1)
    let mut max_x = min_x
    let mut max_y = min_y
    for i = dim; i < outer_len; i = i + dim {
      let x = data.unsafe_get(i)
      let y = data.unsafe_get(i + 1)
      if x < min_x {
        min_x = x
      }
      if y < min_y {
        min_y = y
      }
      if x > max_x {
        max_x = x
      }
      if y > max_y {
        max_y = y
      }
    }
    // minX, minY and invSize are later used to transform coords into integers for z-order calculation
    inv_size = earcut_math_max2(max_x - min_x, max_y - min_y)
    inv_size = if inv_size != 0.0 { 32767.0 / inv_size } else { 0.0 }
  }
  earcut_linked(Some(outer_node), triangles, dim, min_x, min_y, inv_size, 0)
  triangles
}

///|
/// create a circular doubly linked list from polygon points in the specified winding order
fn earcut_linked_list(
  data : Array[Double],
  start : Int32,
  end : Int32,
  dim : Int32,
  clockwise : Bool,
) -> EarcutNode? {
  let mut last = None
  if clockwise == (earcut_signed_area(data, start, end, dim) > 0.0) {
    for i = start; i < end; i = i + dim {
      last = Some(
        earcut_insert_node(
          i / dim,
          data.unsafe_get(i),
          data.unsafe_get(i + 1),
          last,
        ),
      )
    }
  } else {
    for i = end - dim; i >= start; i = i - dim {
      last = Some(
        earcut_insert_node(
          i / dim,
          data.unsafe_get(i),
          data.unsafe_get(i + 1),
          last,
        ),
      )
    }
  }
  if last is Some(node) && earcut_equals(node, node.next()) {
    earcut_remove_node(node)
    last = Some(node.next())
  }
  last
}

///|
/// eliminate colinear or duplicate points
fn earcut_filter_points(start : EarcutNode?, end? : EarcutNode) -> EarcutNode? {
  guard start is Some(start) else { return None }
  let mut end = end.unwrap_or(start)
  let mut p = start
  while true {
    let mut again = false
    if !p.steiner &&
      (earcut_equals(p, p.next()) || earcut_area(p.prev(), p, p.next()) == 0.0) {
      earcut_remove_node(p)
      p = p.prev()
      end = p
      if physical_equal(p, p.next()) {
        break
      }
      again = true
    } else {
      p = p.next()
    }
    if !(again || !physical_equal(p, end)) {
      break
    }
  }
  Some(end)
}

///|
/// main ear slicing loop which triangulates a polygon (given as a linked list)
fn earcut_linked(
  ear : EarcutNode?,
  triangles : Array[Int32],
  dim : Int32,
  min_x : Double,
  min_y : Double,
  inv_size : Double,
  pass : Int32,
) -> Unit {
  guard ear is Some(start) else { return }
  let mut ear = start
  let hashed = earcut_truthy(inv_size)
  // interlink polygon nodes in z-order
  if pass == 0 && hashed {
    earcut_index_curve(ear, min_x, min_y, inv_size)
  }
  let mut stop = ear
  // iterate through ears, slicing them one by one
  while !physical_equal(ear.prev(), ear.next()) {
    let prev = ear.prev()
    let next = ear.next()
    let is_ear = if hashed {
      earcut_is_ear_hashed(ear, min_x, min_y, inv_size)
    } else {
      earcut_is_ear(ear)
    }
    if is_ear {
      triangles.push(prev.i) // cut off the triangle
      triangles.push(ear.i)
      triangles.push(next.i)
      earcut_remove_node(ear)
      // skipping the next vertex leads to less sliver triangles
      ear = next.next()
      stop = next.next()
      continue
    }
    ear = next
    // if we looped through the whole remaining polygon and can't find any more ears
    if physical_equal(ear, stop) {
      // try filtering points and slicing again
      if pass == 0 {
        earcut_linked(
          earcut_filter_points(Some(ear)),
          triangles,
          dim,
          min_x,
          min_y,
          inv_size,
          1,
        )
        // if this didn't work, try curing all small self-intersections locally
      } else if pass == 1 {
        let cured = earcut_cure_local_intersections(
          earcut_filter_points(Some(ear)),
          triangles,
        )
        earcut_linked(cured, triangles, dim, min_x, min_y, inv_size, 2)
        // as a last resort, try splitting the remaining polygon into two
      } else if pass == 2 {
        earcut_split(ear, triangles, dim, min_x, min_y, inv_size)
      }
      break
    }
  }
}

///|
/// check whether a polygon node forms a valid ear with adjacent nodes
fn earcut_is_ear(ear : EarcutNode) -> Bool {
  let a = ear.prev()
  let b = ear
  let c = ear.next()
  if earcut_area(a, b, c) >= 0.0 {
    return false // reflex, can't be an ear
  }
  // now make sure we don't have other points inside the potential ear
  let ax = a.x
  let bx = b.x
  let cx = c.x
  let ay = a.y
  let by = b.y
  let cy = c.y
  // triangle bbox
  let x0 = earcut_math_min3(ax, bx, cx)
  let y0 = earcut_math_min3(ay, by, cy)
  let x1 = earcut_math_max3(ax, bx, cx)
  let y1 = earcut_math_max3(ay, by, cy)
  let mut p = c.next()
  while !physical_equal(p, a) {
    if p.x >= x0 &&
      p.x <= x1 &&
      p.y >= y0 &&
      p.y <= y1 &&
      earcut_point_in_triangle_except_first(ax, ay, bx, by, cx, cy, p.x, p.y) &&
      earcut_area(p.prev(), p, p.next()) >= 0.0 {
      return false
    }
    p = p.next()
  }
  true
}

///|
fn earcut_is_ear_hashed(
  ear : EarcutNode,
  min_x : Double,
  min_y : Double,
  inv_size : Double,
) -> Bool {
  let a = ear.prev()
  let b = ear
  let c = ear.next()
  if earcut_area(a, b, c) >= 0.0 {
    return false // reflex, can't be an ear
  }
  let ax = a.x
  let bx = b.x
  let cx = c.x
  let ay = a.y
  let by = b.y
  let cy = c.y
  // triangle bbox
  let x0 = earcut_math_min3(ax, bx, cx)
  let y0 = earcut_math_min3(ay, by, cy)
  let x1 = earcut_math_max3(ax, bx, cx)
  let y1 = earcut_math_max3(ay, by, cy)
  // z-order range for the current triangle bbox;
  let min_z = earcut_z_order(x0, y0, min_x, min_y, inv_size)
  let max_z = earcut_z_order(x1, y1, min_x, min_y, inv_size)
  let inside = (q : EarcutNode) => {
    q.x >= x0 &&
    q.x <= x1 &&
    q.y >= y0 &&
    q.y <= y1 &&
    !physical_equal(q, a) &&
    !physical_equal(q, c) &&
    earcut_point_in_triangle_except_first(ax, ay, bx, by, cx, cy, q.x, q.y) &&
    earcut_area(q.prev(), q, q.next()) >= 0.0
  }
  let mut p = ear.prev_z
  let mut n = ear.next_z
  // look for points inside the triangle in both directions
  while p is Some(pp) && pp.z >= min_z && n is Some(nn) && nn.z <= max_z {
    if inside(pp) {
      return false
    }
    p = pp.prev_z
    if inside(nn) {
      return false
    }
    n = nn.next_z
  }
  // look for remaining points in decreasing z-order
  while p is Some(pp) && pp.z >= min_z {
    if inside(pp) {
      return false
    }
    p = pp.prev_z
  }
  // look for remaining points in increasing z-order
  while n is Some(nn) && nn.z <= max_z {
    if inside(nn) {
      return false
    }
    n = nn.next_z
  }
  true
}

///|
/// go through all polygon nodes and cure small local self-intersections
fn earcut_cure_local_intersections(
  start : EarcutNode?,
  triangles : Array[Int32],
) -> EarcutNode? {
  let mut start = start.unwrap()
  let mut p = start
  while true {
    let a = p.prev()
    let b = p.next().next()
    if !earcut_equals(a, b) &&
      earcut_intersects(a, p, p.next(), b) &&
      earcut_locally_inside(a, b) &&
      earcut_locally_inside(b, a) {
      triangles.push(a.i)
      triangles.push(p.i)
      triangles.push(b.i)
      // remove two nodes involved
      earcut_remove_node(p)
      earcut_remove_node(p.next())
      start = b
      p = b
    }
    p = p.next()
    if physical_equal(p, start) {
      break
    }
  }
  earcut_filter_points(Some(p))
}

///|
/// try splitting polygon into two and triangulate them independently
fn earcut_split(
  start : EarcutNode,
  triangles : Array[Int32],
  dim : Int32,
  min_x : Double,
  min_y : Double,
  inv_size : Double,
) -> Unit {
  // look for a valid diagonal that divides the polygon into two
  let mut a = start
  while true {
    let mut b = a.next().next()
    while !physical_equal(b, a.prev()) {
      if a.i != b.i && earcut_is_valid_diagonal(a, b) {
        // split the polygon in two by the diagonal
        let c = earcut_split_polygon(a, b)
        // filter colinear points around the cuts
        let filtered_a = earcut_filter_points(Some(a), end=a.next())
        let filtered_c = earcut_filter_points(Some(c), end=c.next())
        // run earcut on each half
        earcut_linked(filtered_a, triangles, dim, min_x, min_y, inv_size, 0)
        earcut_linked(filtered_c, triangles, dim, min_x, min_y, inv_size, 0)
        return
      }
      b = b.next()
    }
    a = a.next()
    if physical_equal(a, start) {
      break
    }
  }
}

///|
/// link every hole into the outer loop, producing a single-ring polygon without holes
fn earcut_eliminate_holes(
  data : Array[Double],
  hole_indices : Array[Int32],
  outer_node : EarcutNode,
  dim : Int32,
) -> EarcutNode {
  let queue = []
  let len = hole_indices.length()
  for i in 0..<len {
    let start = hole_indices[i] * dim
    let end = if i < len - 1 {
      hole_indices[i + 1] * dim
    } else {
      data.length()
    }
    let list = earcut_linked_list(data, start, end, dim, false).unwrap()
    if physical_equal(list, list.next()) {
      list.steiner = true
    }
    queue.push(earcut_get_leftmost(list))
  }
  extras_sort_by(queue, earcut_compare_x_y_slope)
  // process holes from left to right
  let mut outer_node = outer_node
  for hole in queue {
    outer_node = earcut_eliminate_hole(hole, outer_node)
  }
  outer_node
}

///|
fn earcut_compare_x_y_slope(a : EarcutNode, b : EarcutNode) -> Double {
  let mut result = a.x - b.x
  // when the left-most point of 2 holes meet at a vertex, sort the holes counterclockwise so that when we find
  // the bridge to the outer shell is always the point that they meet at.
  if result == 0.0 {
    result = a.y - b.y
    if result == 0.0 {
      let a_slope = (a.next().y - a.y) / (a.next().x - a.x)
      let b_slope = (b.next().y - b.y) / (b.next().x - b.x)
      result = a_slope - b_slope
    }
  }
  result
}

///|
/// find a bridge between vertices that connects hole with an outer ring and link it
fn earcut_eliminate_hole(
  hole : EarcutNode,
  outer_node : EarcutNode,
) -> EarcutNode {
  guard earcut_find_hole_bridge(hole, outer_node) is Some(bridge) else {
    return outer_node
  }
  let bridge_reverse = earcut_split_polygon(bridge, hole)
  // filter collinear points around the cuts
  ignore(earcut_filter_points(Some(bridge_reverse), end=bridge_reverse.next()))
  earcut_filter_points(Some(bridge), end=bridge.next()).unwrap()
}

///|
/// David Eberly's algorithm for finding a bridge between hole and outer polygon
fn earcut_find_hole_bridge(
  hole : EarcutNode,
  outer_node : EarcutNode,
) -> EarcutNode? {
  let mut p = outer_node
  let hx = hole.x
  let hy = hole.y
  let mut qx = -1.0 / 0.0
  let mut found = None
  // find a segment intersected by a ray from the hole's leftmost point to the left;
  // segment's endpoint with lesser x will be potential connection point
  // unless they intersect at a vertex, then choose the vertex
  if earcut_equals(hole, p) {
    return Some(p)
  }
  while true {
    let next = p.next()
    if earcut_equals(hole, next) {
      return Some(next)
    } else if hy <= p.y && hy >= next.y && next.y != p.y {
      let x = p.x + (hy - p.y) * (next.x - p.x) / (next.y - p.y)
      if x <= hx && x > qx {
        qx = x
        let m = if p.x < next.x { p } else { next }
        found = Some(m)
        if x == hx {
          return Some(m) // hole touches outer segment; pick leftmost endpoint
        }
      }
    }
    p = p.next()
    if physical_equal(p, outer_node) {
      break
    }
  }
  guard found is Some(m) else { return None }
  let mut m = m
  // look for points inside the triangle of hole point, segment intersection and endpoint;
  // if there are no points found, we have a valid connection;
  // otherwise choose the point of the minimum angle with the ray as connection point
  let stop = m
  let mx = m.x
  let my = m.y
  let mut tan_min = 1.0 / 0.0
  p = m
  while true {
    if hx >= p.x &&
      p.x >= mx &&
      hx != p.x &&
      earcut_point_in_triangle(
        if hy < my {
          hx
        } else {
          qx
        },
        hy,
        mx,
        my,
        if hy < my {
          qx
        } else {
          hx
        },
        hy,
        p.x,
        p.y,
      ) {
      let tan = (hy - p.y).abs() / (hx - p.x) // tangential
      if earcut_locally_inside(p, hole) &&
        (
          tan < tan_min ||
          (
            tan == tan_min &&
            (p.x > m.x || (p.x == m.x && earcut_sector_contains_sector(m, p)))
          )
        ) {
        m = p
        tan_min = tan
      }
    }
    p = p.next()
    if physical_equal(p, stop) {
      break
    }
  }
  Some(m)
}

///|
/// whether sector in vertex m contains sector in vertex p in the same coordinates
fn earcut_sector_contains_sector(m : EarcutNode, p : EarcutNode) -> Bool {
  earcut_area(m.prev(), m, p.prev()) < 0.0 &&
  earcut_area(p.next(), m, m.next()) < 0.0
}

///|
/// interlink polygon nodes in z-order
fn earcut_index_curve(
  start : EarcutNode,
  min_x : Double,
  min_y : Double,
  inv_size : Double,
) -> Unit {
  let mut p = start
  while true {
    if p.z == 0 {
      p.z = earcut_z_order(p.x, p.y, min_x, min_y, inv_size)
    }
    p.prev_z = p.prev_node
    p.next_z = p.next_node
    p = p.next()
    if physical_equal(p, start) {
      break
    }
  }
  p.prev_z.unwrap().next_z = None
  p.prev_z = None
  earcut_sort_linked(p)
}

///|
/// Simon Tatham's linked list merge sort algorithm
/// http://www.chiark.greenend.org.uk/~sgtatham/algorithms/listsort.html
fn earcut_sort_linked(start : EarcutNode) -> Unit {
  let mut list = Some(start)
  let mut num_merges = 0
  let mut in_size = 1
  while true {
    let mut p = list
    list = None
    let mut tail : EarcutNode? = None
    num_merges = 0
    while p is Some(p_node) {
      num_merges += 1
      let mut q = p
      let mut p_size = 0
      for _ in 0..<in_size {
        p_size += 1
        q = q.unwrap().next_z
        if q is None {
          break
        }
      }
      let mut q_size = in_size
      ignore(p_node)
      while p_size > 0 || (q_size > 0 && q is Some(_)) {
        let e = if p_size != 0 &&
          (q_size == 0 || q is None || p.unwrap().z <= q.unwrap().z) {
          let e = p.unwrap()
          p = e.next_z
          p_size -= 1
          e
        } else {
          let e = q.unwrap()
          q = e.next_z
          q_size -= 1
          e
        }
        if tail is Some(tail_node) {
          tail_node.next_z = Some(e)
        } else {
          list = Some(e)
        }
        e.prev_z = tail
        tail = Some(e)
      }
      p = q
    }
    tail.unwrap().next_z = None
    in_size *= 2
    if !(num_merges > 1) {
      break
    }
  }
}

///|
/// z-order of a point given coords and inverse of the longer side of data bbox
fn earcut_z_order(
  x : Double,
  y : Double,
  min_x : Double,
  min_y : Double,
  inv_size : Double,
) -> Int32 {
  // coords are transformed into non-negative 15-bit integer range
  let mut x = earcut_to_int32((x - min_x) * inv_size)
  let mut y = earcut_to_int32((y - min_y) * inv_size)
  x = (x | (x << 8)) & 0x00FF00FF
  x = (x | (x << 4)) & 0x0F0F0F0F
  x = (x | (x << 2)) & 0x33333333
  x = (x | (x << 1)) & 0x55555555
  y = (y | (y << 8)) & 0x00FF00FF
  y = (y | (y << 4)) & 0x0F0F0F0F
  y = (y | (y << 2)) & 0x33333333
  y = (y | (y << 1)) & 0x55555555
  x | (y << 1)
}

///|
/// find the leftmost node of a polygon ring
fn earcut_get_leftmost(start : EarcutNode) -> EarcutNode {
  let mut p = start
  let mut leftmost = start
  while true {
    if p.x < leftmost.x || (p.x == leftmost.x && p.y < leftmost.y) {
      leftmost = p
    }
    p = p.next()
    if physical_equal(p, start) {
      break
    }
  }
  leftmost
}

///|
/// check if a point lies within a convex triangle
fn earcut_point_in_triangle(
  ax : Double,
  ay : Double,
  bx : Double,
  by : Double,
  cx : Double,
  cy : Double,
  px : Double,
  py : Double,
) -> Bool {
  (cx - px) * (ay - py) >= (ax - px) * (cy - py) &&
  (ax - px) * (by - py) >= (bx - px) * (ay - py) &&
  (bx - px) * (cy - py) >= (cx - px) * (by - py)
}

///|
/// check if a point lies within a convex triangle but false if its equal to the first point of the triangle
fn earcut_point_in_triangle_except_first(
  ax : Double,
  ay : Double,
  bx : Double,
  by : Double,
  cx : Double,
  cy : Double,
  px : Double,
  py : Double,
) -> Bool {
  !(ax == px && ay == py) &&
  earcut_point_in_triangle(ax, ay, bx, by, cx, cy, px, py)
}

///|
/// check if a diagonal between two polygon nodes is valid (lies in polygon interior)
fn earcut_is_valid_diagonal(a : EarcutNode, b : EarcutNode) -> Bool {
  a.next().i != b.i &&
  a.prev().i != b.i &&
  !earcut_intersects_polygon(a, b) && // doesn't intersect other edges
  (
    (
      earcut_locally_inside(a, b) &&
      earcut_locally_inside(b, a) &&
      earcut_middle_inside(a, b) && // locally visible
      (
        earcut_truthy(earcut_area(a.prev(), a, b.prev())) ||
        earcut_truthy(earcut_area(a, b.prev(), b))
      )
    ) || // does not create opposite-facing sectors
    (
      earcut_equals(a, b) &&
      earcut_area(a.prev(), a, a.next()) > 0.0 &&
      earcut_area(b.prev(), b, b.next()) > 0.0
    )
  ) // special zero-length case
}

///|
/// signed area of a triangle
fn earcut_area(p : EarcutNode, q : EarcutNode, r : EarcutNode) -> Double {
  (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y)
}

///|
/// check if two points are equal
fn earcut_equals(p1 : EarcutNode, p2 : EarcutNode) -> Bool {
  p1.x == p2.x && p1.y == p2.y
}

///|
/// check if two segments intersect
fn earcut_intersects(
  p1 : EarcutNode,
  q1 : EarcutNode,
  p2 : EarcutNode,
  q2 : EarcutNode,
) -> Bool {
  let o1 = earcut_sign(earcut_area(p1, q1, p2))
  let o2 = earcut_sign(earcut_area(p1, q1, q2))
  let o3 = earcut_sign(earcut_area(p2, q2, p1))
  let o4 = earcut_sign(earcut_area(p2, q2, q1))
  if o1 != o2 && o3 != o4 {
    return true // general case
  }
  if o1 == 0 && earcut_on_segment(p1, p2, q1) {
    return true // p1, q1 and p2 are collinear and p2 lies on p1q1
  }
  if o2 == 0 && earcut_on_segment(p1, q2, q1) {
    return true // p1, q1 and q2 are collinear and q2 lies on p1q1
  }
  if o3 == 0 && earcut_on_segment(p2, p1, q2) {
    return true // p2, q2 and p1 are collinear and p1 lies on p2q2
  }
  if o4 == 0 && earcut_on_segment(p2, q1, q2) {
    return true // p2, q2 and q1 are collinear and q1 lies on p2q2
  }
  false
}

///|
/// for collinear points p, q, r, check if point q lies on segment pr
fn earcut_on_segment(p : EarcutNode, q : EarcutNode, r : EarcutNode) -> Bool {
  q.x <= earcut_math_max2(p.x, r.x) &&
  q.x >= earcut_math_min2(p.x, r.x) &&
  q.y <= earcut_math_max2(p.y, r.y) &&
  q.y >= earcut_math_min2(p.y, r.y)
}

///|
fn earcut_sign(num : Double) -> Int32 {
  if num > 0.0 {
    1
  } else if num < 0.0 {
    -1
  } else {
    0
  }
}

///|
/// check if a polygon diagonal intersects any polygon segments
fn earcut_intersects_polygon(a : EarcutNode, b : EarcutNode) -> Bool {
  let mut p = a
  while true {
    if p.i != a.i &&
      p.next().i != a.i &&
      p.i != b.i &&
      p.next().i != b.i &&
      earcut_intersects(p, p.next(), a, b) {
      return true
    }
    p = p.next()
    if physical_equal(p, a) {
      break
    }
  }
  false
}

///|
/// check if a polygon diagonal is locally inside the polygon
fn earcut_locally_inside(a : EarcutNode, b : EarcutNode) -> Bool {
  if earcut_area(a.prev(), a, a.next()) < 0.0 {
    earcut_area(a, b, a.next()) >= 0.0 && earcut_area(a, a.prev(), b) >= 0.0
  } else {
    earcut_area(a, b, a.prev()) < 0.0 || earcut_area(a, a.next(), b) < 0.0
  }
}

///|
/// check if the middle point of a polygon diagonal is inside the polygon
fn earcut_middle_inside(a : EarcutNode, b : EarcutNode) -> Bool {
  let mut p = a
  let mut inside = false
  let px = (a.x + b.x) / 2.0
  let py = (a.y + b.y) / 2.0
  while true {
    let next = p.next()
    if (p.y > py) != (next.y > py) &&
      next.y != p.y &&
      px < (next.x - p.x) * (py - p.y) / (next.y - p.y) + p.x {
      inside = !inside
    }
    p = next
    if physical_equal(p, a) {
      break
    }
  }
  inside
}

///|
/// link two polygon vertices with a bridge; if the vertices belong to the same ring, it splits polygon into two;
/// if one belongs to the outer ring and another to a hole, it merges it into a single ring
fn earcut_split_polygon(a : EarcutNode, b : EarcutNode) -> EarcutNode {
  let a2 = earcut_create_node(a.i, a.x, a.y)
  let b2 = earcut_create_node(b.i, b.x, b.y)
  let an = a.next()
  let bp = b.prev()
  a.next_node = Some(b)
  b.prev_node = Some(a)
  a2.next_node = Some(an)
  an.prev_node = Some(a2)
  b2.next_node = Some(a2)
  a2.prev_node = Some(b2)
  bp.next_node = Some(b2)
  b2.prev_node = Some(bp)
  b2
}

///|
/// create a node and optionally link it with previous one (in a circular doubly linked list)
fn earcut_insert_node(
  i : Int32,
  x : Double,
  y : Double,
  last : EarcutNode?,
) -> EarcutNode {
  let p = earcut_create_node(i, x, y)
  match last {
    None => {
      p.prev_node = Some(p)
      p.next_node = Some(p)
    }
    Some(last) => {
      p.next_node = last.next_node
      p.prev_node = Some(last)
      last.next().prev_node = Some(p)
      last.next_node = Some(p)
    }
  }
  p
}

///|
fn earcut_remove_node(p : EarcutNode) -> Unit {
  p.next().prev_node = p.prev_node
  p.prev().next_node = p.next_node
  if p.prev_z is Some(prev_z) {
    prev_z.next_z = p.next_z
  }
  if p.next_z is Some(next_z) {
    next_z.prev_z = p.prev_z
  }
}

///|
fn earcut_create_node(i : Int32, x : Double, y : Double) -> EarcutNode {
  {
    i,
    x,
    y,
    prev_node: None,
    next_node: None,
    z: 0,
    prev_z: None,
    next_z: None,
    steiner: false,
  }
}

///|
/// return a percentage difference between the polygon area and its triangulation area;
/// used to verify correctness of triangulation
pub fn earcut_deviation(
  data : Array[Double],
  hole_indices : Array[Int32],
  dim : Int32,
  triangles : Array[Int32],
) -> Double {
  let has_holes = hole_indices.length() > 0
  let outer_len = if has_holes { hole_indices[0] * dim } else { data.length() }
  let mut polygon_area = earcut_signed_area(data, 0, outer_len, dim).abs()
  if has_holes {
    let len = hole_indices.length()
    for i in 0..<len {
      let start = hole_indices[i] * dim
      let end = if i < len - 1 {
        hole_indices[i + 1] * dim
      } else {
        data.length()
      }
      polygon_area -= earcut_signed_area(data, start, end, dim).abs()
    }
  }
  let mut triangles_area = 0.0
  for i = 0; i < triangles.length(); i = i + 3 {
    let a = triangles[i] * dim
    let b = triangles[i + 1] * dim
    let c = triangles[i + 2] * dim
    triangles_area += ((data.unsafe_get(a) - data.unsafe_get(c)) *
    (data.unsafe_get(b + 1) - data.unsafe_get(a + 1)) -
    (data.unsafe_get(a) - data.unsafe_get(b)) *
    (data.unsafe_get(c + 1) - data.unsafe_get(a + 1))).abs()
  }
  if polygon_area == 0.0 && triangles_area == 0.0 {
    0.0
  } else {
    ((triangles_area - polygon_area) / polygon_area).abs()
  }
}

///|
fn earcut_signed_area(
  data : Array[Double],
  start : Int32,
  end : Int32,
  dim : Int32,
) -> Double {
  let mut sum = 0.0
  let mut j = end - dim
  for i = start; i < end; i = i + dim {
    sum += (data.unsafe_get(j) - data.unsafe_get(i)) *
      (data.unsafe_get(i + 1) + data.unsafe_get(j + 1))
    j = i
  }
  sum
}

///|
/// turn a polygon in a multi-dimensional array form (e.g. as in GeoJSON) into a form Earcut accepts
pub fn earcut_flatten(data : Array[Array[Array[Double]]]) -> EarcutFlatten {
  let vertices = []
  let holes = []
  let dimensions = data[0][0].length()
  let mut hole_index = 0
  let mut prev_len = 0
  for ring in data {
    for p in ring {
      for d in 0..<dimensions {
        vertices.push(p.unsafe_get(d))
      }
    }
    if prev_len != 0 {
      hole_index += prev_len
      holes.push(hole_index)
    }
    prev_len = ring.length()
  }
  { vertices, holes, dimensions, }
}
