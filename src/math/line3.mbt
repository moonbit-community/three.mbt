///|
let _line3_start_p : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _line3_start_end : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _line3_d1 : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _line3_d2 : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _line3_r : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _line3_c1 : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _line3_c2 : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
/// A line segment in 3D space defined by a start and end point.
pub(all) struct Line3 {
  mut start : Vector3
  mut end : Vector3
}

///|
pub fn Line3::new(
  start~ : Vector3 = Vector3::new(0.0, 0.0, 0.0),
  end~ : Vector3 = Vector3::new(0.0, 0.0, 0.0),
) -> Line3 {
  { start, end, }
}

///|
pub fn Line3::set(self : Line3, start : Vector3, end : Vector3) -> Line3 {
  self.start.copy(start) |> ignore
  self.end.copy(end) |> ignore
  self
}

///|
pub fn Line3::copy(self : Line3, line : Line3) -> Line3 {
  self.start.copy(line.start) |> ignore
  self.end.copy(line.end) |> ignore
  self
}

///|
pub fn Line3::get_center(self : Line3, target : Vector3) -> Vector3 {
  target.add_vectors(self.start, self.end).multiply_scalar(0.5)
}

///|
pub fn Line3::delta(self : Line3, target : Vector3) -> Vector3 {
  target.sub_vectors(self.end, self.start)
}

///|
pub fn Line3::distance_sq(self : Line3) -> Double {
  self.start.distance_to_squared(self.end)
}

///|
pub fn Line3::distance(self : Line3) -> Double {
  self.start.distance_to(self.end)
}

///|
pub fn Line3::at(self : Line3, t : Double, target : Vector3) -> Vector3 {
  self.delta(target).multiply_scalar(t).add(self.start)
}

///|
pub fn Line3::closest_point_to_point_parameter(
  self : Line3,
  point : Vector3,
  clamp_to_line : Bool,
) -> Double {
  _line3_start_p.sub_vectors(point, self.start) |> ignore
  _line3_start_end.sub_vectors(self.end, self.start) |> ignore
  let start_end2 = _line3_start_end.dot(_line3_start_end)
  if start_end2 == 0.0 {
    return 0.0
  }
  let start_end_start_p = _line3_start_end.dot(_line3_start_p)
  let mut t = start_end_start_p / start_end2
  if clamp_to_line {
    t = clamp(t, 0.0, 1.0)
  }
  t
}

///|
pub fn Line3::closest_point_to_point(
  self : Line3,
  point : Vector3,
  clamp_to_line : Bool,
  target : Vector3,
) -> Vector3 {
  let t = self.closest_point_to_point_parameter(point, clamp_to_line)
  self.delta(target).multiply_scalar(t).add(self.start)
}

///|
pub fn Line3::distance_sq_to_line3(
  self : Line3,
  line : Line3,
  c1~ : Vector3 = _line3_c1,
  c2~ : Vector3 = _line3_c2,
) -> Double {
  // from Real-Time Collision Detection by Christer Ericson, chapter 5.1.9
  // Computes closest points C1 and C2 of S1(s)=P1+s*(Q1-P1) and
  // S2(t)=P2+t*(Q2-P2), returning s and t. Function result is squared
  // distance between between S1(s) and S2(t)
  let epsilon = 1.0e-8 * 1.0e-8 // must be squared since we compare squared length
  let mut s = 0.0
  let mut t = 0.0
  let p1 = self.start
  let p2 = line.start
  let q1 = self.end
  let q2 = line.end
  _line3_d1.sub_vectors(q1, p1) |> ignore // Direction vector of segment S1
  _line3_d2.sub_vectors(q2, p2) |> ignore // Direction vector of segment S2
  _line3_r.sub_vectors(p1, p2) |> ignore
  let a = _line3_d1.dot(_line3_d1) // Squared length of segment S1, always nonnegative
  let e = _line3_d2.dot(_line3_d2) // Squared length of segment S2, always nonnegative
  let f = _line3_d2.dot(_line3_r)
  // Check if either or both segments degenerate into points
  if a <= epsilon && e <= epsilon {
    // Both segments degenerate into points
    c1.copy(p1) |> ignore
    c2.copy(p2) |> ignore
    return c1.distance_to_squared(c2)
  }
  if a <= epsilon {
    // First segment degenerates into a point
    s = 0.0
    t = f / e // s = 0 => t = (b*s + f) / e = f / e
    t = clamp(t, 0.0, 1.0)
  } else {
    let c = _line3_d1.dot(_line3_r)
    if e <= epsilon {
      // Second segment degenerates into a point
      t = 0.0
      s = clamp(-c / a, 0.0, 1.0) // t = 0 => s = (b*t - c) / a = -c / a
    } else {
      // The general nondegenerate case starts here
      let b = _line3_d1.dot(_line3_d2)
      let denom = a * e - b * b // Always nonnegative
      // If segments not parallel, compute closest point on L1 to L2 and
      // clamp to segment S1. Else pick arbitrary s (here 0)
      if denom != 0.0 {
        s = clamp((b * f - c * e) / denom, 0.0, 1.0)
      } else {
        s = 0.0
      }
      // Compute point on L2 closest to S1(s) using
      // t = Dot((P1 + D1*s) - P2,D2) / Dot(D2,D2) = (b*s + f) / e
      t = (b * s + f) / e
      // If t in [0,1] done. Else clamp t, recompute s for the new value
      // of t using s = Dot((P2 + D2*t) - P1,D1) / Dot(D1,D1)= (t*b - c) / a
      // and clamp s to [0, 1]
      if t < 0.0 {
        t = 0.0
        s = clamp(-c / a, 0.0, 1.0)
      } else if t > 1.0 {
        t = 1.0
        s = clamp((b - c) / a, 0.0, 1.0)
      }
    }
  }
  c1.copy(p1).add_scaled_vector(_line3_d1, s) |> ignore
  c2.copy(p2).add_scaled_vector(_line3_d2, t) |> ignore
  c1.distance_to_squared(c2)
}

///|
pub fn Line3::apply_matrix4(self : Line3, matrix : Matrix4) -> Line3 {
  self.start.apply_matrix4(matrix) |> ignore
  self.end.apply_matrix4(matrix) |> ignore
  self
}

///|
pub fn Line3::equals(self : Line3, line : Line3) -> Bool {
  line.start.equals(self.start) && line.end.equals(self.end)
}

///|
pub fn Line3::clone(self : Line3) -> Line3 {
  Line3::new().copy(self)
}
