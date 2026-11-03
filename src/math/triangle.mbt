///|
let _triangle_v0 : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _triangle_v1 : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _triangle_v2 : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _triangle_v3 : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _triangle_vab : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _triangle_vac : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _triangle_vbc : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _triangle_vap : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _triangle_vbp : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _triangle_vcp : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
/// Vertex values `Triangle::get_interpolation` can blend. Upstream duck-types these.
pub(open) trait Interpolatable {
  fn set_scalar(Self, Double) -> Self
  fn add_scaled_vector(Self, Self, Double) -> Self
}

///|
pub impl Interpolatable for Vector2 with fn set_scalar(self, scalar) {
  Vector2::set_scalar(self, scalar)
}

///|
pub impl Interpolatable for Vector2 with fn add_scaled_vector(self, v, s) {
  Vector2::add_scaled_vector(self, v, s)
}

///|
pub impl Interpolatable for Vector3 with fn set_scalar(self, scalar) {
  Vector3::set_scalar(self, scalar)
}

///|
pub impl Interpolatable for Vector3 with fn add_scaled_vector(self, v, s) {
  Vector3::add_scaled_vector(self, v, s)
}

///|
pub impl Interpolatable for Vector4 with fn set_scalar(self, scalar) {
  Vector4::set_scalar(self, scalar)
}

///|
pub impl Interpolatable for Vector4 with fn add_scaled_vector(self, v, s) {
  Vector4::add_scaled_vector(self, v, s)
}

///|
/// A triangle in 3D space defined by three corners.
pub(all) struct Triangle {
  mut a : Vector3
  mut b : Vector3
  mut c : Vector3
}

///|
pub fn Triangle::new(
  a~ : Vector3 = Vector3::new(0.0, 0.0, 0.0),
  b~ : Vector3 = Vector3::new(0.0, 0.0, 0.0),
  c~ : Vector3 = Vector3::new(0.0, 0.0, 0.0),
) -> Triangle {
  { a, b, c, }
}

///|
/// Upstream static `Triangle.getNormal`.
pub fn Triangle::get_normal_static(
  a : Vector3,
  b : Vector3,
  c : Vector3,
  target : Vector3,
) -> Vector3 {
  target.sub_vectors(c, b) |> ignore
  _triangle_v0.sub_vectors(a, b) |> ignore
  target.cross(_triangle_v0) |> ignore
  let target_length_sq = target.length_sq()
  if target_length_sq > 0.0 {
    return target.multiply_scalar(1.0 / target_length_sq.sqrt())
  }
  target.set(0.0, 0.0, 0.0)
}

///|
/// Upstream static `Triangle.getBarycoord`. `None` if the triangle is degenerate.
pub fn Triangle::get_barycoord_static(
  point : Vector3,
  a : Vector3,
  b : Vector3,
  c : Vector3,
  target : Vector3,
) -> Vector3? {
  _triangle_v0.sub_vectors(c, a) |> ignore
  _triangle_v1.sub_vectors(b, a) |> ignore
  _triangle_v2.sub_vectors(point, a) |> ignore
  let dot00 = _triangle_v0.dot(_triangle_v0)
  let dot01 = _triangle_v0.dot(_triangle_v1)
  let dot02 = _triangle_v0.dot(_triangle_v2)
  let dot11 = _triangle_v1.dot(_triangle_v1)
  let dot12 = _triangle_v1.dot(_triangle_v2)
  let denom = dot00 * dot11 - dot01 * dot01
  // collinear or singular triangle
  if denom == 0.0 {
    target.set(0.0, 0.0, 0.0) |> ignore
    return None
  }
  let inv_denom = 1.0 / denom
  let u = (dot11 * dot02 - dot01 * dot12) * inv_denom
  let v = (dot00 * dot12 - dot01 * dot02) * inv_denom
  // barycentric coordinates must always sum to 1
  Some(target.set(1.0 - u - v, v, u))
}

///|
/// Upstream static `Triangle.containsPoint`.
pub fn Triangle::contains_point_static(
  point : Vector3,
  a : Vector3,
  b : Vector3,
  c : Vector3,
) -> Bool {
  // if the triangle is degenerate then we can't contain a point
  if Triangle::get_barycoord_static(point, a, b, c, _triangle_v3) is None {
    return false
  }
  _triangle_v3.x >= 0.0 &&
  _triangle_v3.y >= 0.0 &&
  _triangle_v3.x + _triangle_v3.y <= 1.0
}

///|
/// Upstream static `Triangle.getInterpolation`. `None` if the triangle is degenerate.
pub fn[T : Interpolatable] Triangle::get_interpolation_static(
  point : Vector3,
  p1 : Vector3,
  p2 : Vector3,
  p3 : Vector3,
  v1 : T,
  v2 : T,
  v3 : T,
  target : T,
) -> T? {
  if Triangle::get_barycoord_static(point, p1, p2, p3, _triangle_v3) is None {
    target.set_scalar(0.0) |> ignore
    return None
  }
  target.set_scalar(0.0) |> ignore
  target.add_scaled_vector(v1, _triangle_v3.x) |> ignore
  target.add_scaled_vector(v2, _triangle_v3.y) |> ignore
  target.add_scaled_vector(v3, _triangle_v3.z) |> ignore
  Some(target)
}

///|
/// Upstream static `Triangle.isFrontFacing`.
pub fn Triangle::is_front_facing_static(
  a : Vector3,
  b : Vector3,
  c : Vector3,
  direction : Vector3,
) -> Bool {
  _triangle_v0.sub_vectors(c, b) |> ignore
  _triangle_v1.sub_vectors(a, b) |> ignore
  // strictly front facing
  _triangle_v0.cross(_triangle_v1).dot(direction) < 0.0
}

///|
pub fn Triangle::set(
  self : Triangle,
  a : Vector3,
  b : Vector3,
  c : Vector3,
) -> Triangle {
  self.a.copy(a) |> ignore
  self.b.copy(b) |> ignore
  self.c.copy(c) |> ignore
  self
}

///|
pub fn Triangle::set_from_points_and_indices(
  self : Triangle,
  points : Array[Vector3],
  i0 : Int32,
  i1 : Int32,
  i2 : Int32,
) -> Triangle {
  self.a.copy(points[i0]) |> ignore
  self.b.copy(points[i1]) |> ignore
  self.c.copy(points[i2]) |> ignore
  self
}

///|
pub fn Triangle::clone(self : Triangle) -> Triangle {
  Triangle::new().copy(self)
}

///|
pub fn Triangle::copy(self : Triangle, triangle : Triangle) -> Triangle {
  self.a.copy(triangle.a) |> ignore
  self.b.copy(triangle.b) |> ignore
  self.c.copy(triangle.c) |> ignore
  self
}

///|
pub fn Triangle::get_area(self : Triangle) -> Double {
  _triangle_v0.sub_vectors(self.c, self.b) |> ignore
  _triangle_v1.sub_vectors(self.a, self.b) |> ignore
  _triangle_v0.cross(_triangle_v1).length() * 0.5
}

///|
pub fn Triangle::get_midpoint(self : Triangle, target : Vector3) -> Vector3 {
  target.add_vectors(self.a, self.b).add(self.c).multiply_scalar(1.0 / 3.0)
}

///|
pub fn Triangle::get_normal(self : Triangle, target : Vector3) -> Vector3 {
  Triangle::get_normal_static(self.a, self.b, self.c, target)
}

///|
pub fn Triangle::get_plane(self : Triangle, target : Plane) -> Plane {
  target.set_from_coplanar_points(self.a, self.b, self.c)
}

///|
pub fn Triangle::get_barycoord(
  self : Triangle,
  point : Vector3,
  target : Vector3,
) -> Vector3? {
  Triangle::get_barycoord_static(point, self.a, self.b, self.c, target)
}

///|
pub fn[T : Interpolatable] Triangle::get_interpolation(
  self : Triangle,
  point : Vector3,
  v1 : T,
  v2 : T,
  v3 : T,
  target : T,
) -> T? {
  Triangle::get_interpolation_static(
    point,
    self.a,
    self.b,
    self.c,
    v1,
    v2,
    v3,
    target,
  )
}

///|
pub fn Triangle::contains_point(self : Triangle, point : Vector3) -> Bool {
  Triangle::contains_point_static(point, self.a, self.b, self.c)
}

///|
pub fn Triangle::is_front_facing(self : Triangle, direction : Vector3) -> Bool {
  Triangle::is_front_facing_static(self.a, self.b, self.c, direction)
}

///|
pub fn Triangle::intersects_box(self : Triangle, box : Box3) -> Bool {
  box.intersects_triangle(self)
}

///|
pub fn Triangle::closest_point_to_point(
  self : Triangle,
  p : Vector3,
  target : Vector3,
) -> Vector3 {
  let a = self.a
  let b = self.b
  let c = self.c
  // algorithm thanks to Real-Time Collision Detection by Christer Ericson,
  // published by Morgan Kaufmann Publishers, (c) 2005 Elsevier Inc.,
  // under the accompanying license; see chapter 5.1.5 for detailed explanation.
  // basically, we're distinguishing which of the voronoi regions of the triangle
  // the point lies in with the minimum amount of redundant computation.
  _triangle_vab.sub_vectors(b, a) |> ignore
  _triangle_vac.sub_vectors(c, a) |> ignore
  _triangle_vap.sub_vectors(p, a) |> ignore
  let d1 = _triangle_vab.dot(_triangle_vap)
  let d2 = _triangle_vac.dot(_triangle_vap)
  if d1 <= 0.0 && d2 <= 0.0 {
    // vertex region of A; barycentric coords (1, 0, 0)
    return target.copy(a)
  }
  _triangle_vbp.sub_vectors(p, b) |> ignore
  let d3 = _triangle_vab.dot(_triangle_vbp)
  let d4 = _triangle_vac.dot(_triangle_vbp)
  if d3 >= 0.0 && d4 <= d3 {
    // vertex region of B; barycentric coords (0, 1, 0)
    return target.copy(b)
  }
  let vc = d1 * d4 - d3 * d2
  if vc <= 0.0 && d1 >= 0.0 && d3 <= 0.0 && d1 - d3 > 0.0 { // modification of the algorithm: d1 - d3 is the squared length of AB, so skip this region if a and b coincide
    let v = d1 / (d1 - d3)
    // edge region of AB; barycentric coords (1-v, v, 0)
    return target.copy(a).add_scaled_vector(_triangle_vab, v)
  }
  _triangle_vcp.sub_vectors(p, c) |> ignore
  let d5 = _triangle_vab.dot(_triangle_vcp)
  let d6 = _triangle_vac.dot(_triangle_vcp)
  if d6 >= 0.0 && d5 <= d6 {
    // vertex region of C; barycentric coords (0, 0, 1)
    return target.copy(c)
  }
  let vb = d5 * d2 - d1 * d6
  if vb <= 0.0 && d2 >= 0.0 && d6 <= 0.0 {
    let w = d2 / (d2 - d6)
    // edge region of AC; barycentric coords (1-w, 0, w)
    return target.copy(a).add_scaled_vector(_triangle_vac, w)
  }
  let va = d3 * d6 - d5 * d4
  if va <= 0.0 && d4 - d3 >= 0.0 && d5 - d6 >= 0.0 {
    _triangle_vbc.sub_vectors(c, b) |> ignore
    let w = (d4 - d3) / (d4 - d3 + (d5 - d6))
    // edge region of BC; barycentric coords (0, 1-w, w)
    return target.copy(b).add_scaled_vector(_triangle_vbc, w) // edge region of BC
  }
  // face region
  let denom = 1.0 / (va + vb + vc)
  // u = va * denom
  let v = vb * denom
  let w = vc * denom
  target
  .copy(a)
  .add_scaled_vector(_triangle_vab, v)
  .add_scaled_vector(_triangle_vac, w)
}

///|
pub fn Triangle::equals(self : Triangle, triangle : Triangle) -> Bool {
  triangle.a.equals(self.a) &&
  triangle.b.equals(self.b) &&
  triangle.c.equals(self.c)
}
