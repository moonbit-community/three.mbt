///|
let _frustum_vector : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
/// A frustum defined by six planes, used for camera culling.
pub(all) struct Frustum {
  mut planes : Array[Plane]
}

///|
pub fn Frustum::new(
  p0~ : Plane = Plane::new(),
  p1~ : Plane = Plane::new(),
  p2~ : Plane = Plane::new(),
  p3~ : Plane = Plane::new(),
  p4~ : Plane = Plane::new(),
  p5~ : Plane = Plane::new(),
) -> Frustum {
  { planes: [p0, p1, p2, p3, p4, p5], }
}

///|
pub fn Frustum::set(
  self : Frustum,
  p0 : Plane,
  p1 : Plane,
  p2 : Plane,
  p3 : Plane,
  p4 : Plane,
  p5 : Plane,
) -> Frustum {
  let planes = self.planes
  planes[0].copy(p0) |> ignore
  planes[1].copy(p1) |> ignore
  planes[2].copy(p2) |> ignore
  planes[3].copy(p3) |> ignore
  planes[4].copy(p4) |> ignore
  planes[5].copy(p5) |> ignore
  self
}

///|
pub fn Frustum::copy(self : Frustum, frustum : Frustum) -> Frustum {
  let planes = self.planes
  for i in 0..<6 {
    planes[i].copy(frustum.planes[i]) |> ignore
  }
  self
}

///|
pub fn Frustum::set_from_projection_matrix(
  self : Frustum,
  m : Matrix4,
  coordinate_system~ : Int32 = WebGLCoordinateSystem,
  reversed_depth~ : Bool = false,
) -> Frustum {
  let planes = self.planes
  let me_ = m.elements
  let me0 = me_[0]
  let me1 = me_[1]
  let me2 = me_[2]
  let me3 = me_[3]
  let me4 = me_[4]
  let me5 = me_[5]
  let me6 = me_[6]
  let me7 = me_[7]
  let me8 = me_[8]
  let me9 = me_[9]
  let me10 = me_[10]
  let me11 = me_[11]
  let me12 = me_[12]
  let me13 = me_[13]
  let me14 = me_[14]
  let me15 = me_[15]
  planes[0]
  .set_components(me3 - me0, me7 - me4, me11 - me8, me15 - me12)
  .normalize()
  |> ignore
  planes[1]
  .set_components(me3 + me0, me7 + me4, me11 + me8, me15 + me12)
  .normalize()
  |> ignore
  planes[2]
  .set_components(me3 + me1, me7 + me5, me11 + me9, me15 + me13)
  .normalize()
  |> ignore
  planes[3]
  .set_components(me3 - me1, me7 - me5, me11 - me9, me15 - me13)
  .normalize()
  |> ignore
  if reversed_depth {
    planes[4].set_components(me2, me6, me10, me14).normalize() |> ignore // far
    planes[5]
    .set_components(me3 - me2, me7 - me6, me11 - me10, me15 - me14)
    .normalize()
    |> ignore // near
  } else {
    planes[4]
    .set_components(me3 - me2, me7 - me6, me11 - me10, me15 - me14)
    .normalize()
    |> ignore // far
    if coordinate_system == WebGLCoordinateSystem {
      planes[5]
      .set_components(me3 + me2, me7 + me6, me11 + me10, me15 + me14)
      .normalize()
      |> ignore // near
    } else if coordinate_system == WebGPUCoordinateSystem {
      planes[5].set_components(me2, me6, me10, me14).normalize() |> ignore // near
    } else {
      abort(
        "THREE.Frustum.setFromProjectionMatrix(): Invalid coordinate system: \{coordinate_system}",
      )
    }
  }
  self
}

///|
pub fn Frustum::intersects_sphere(self : Frustum, sphere : Sphere) -> Bool {
  let planes = self.planes
  let center = sphere.center
  let neg_radius = -sphere.radius
  for i in 0..<6 {
    let distance = planes[i].distance_to_point(center)
    if distance < neg_radius {
      return false
    }
  }
  true
}

///|
pub fn Frustum::intersects_box(self : Frustum, box : Box3) -> Bool {
  let planes = self.planes
  for i in 0..<6 {
    let plane = planes[i]
    // corner at max distance
    _frustum_vector.x = if plane.normal.x > 0.0 { box.max.x } else { box.min.x }
    _frustum_vector.y = if plane.normal.y > 0.0 { box.max.y } else { box.min.y }
    _frustum_vector.z = if plane.normal.z > 0.0 { box.max.z } else { box.min.z }
    if plane.distance_to_point(_frustum_vector) < 0.0 {
      return false
    }
  }
  true
}

///|
pub fn Frustum::contains_point(self : Frustum, point : Vector3) -> Bool {
  let planes = self.planes
  for i in 0..<6 {
    if planes[i].distance_to_point(point) < 0.0 {
      return false
    }
  }
  true
}

///|
pub fn Frustum::clone(self : Frustum) -> Frustum {
  Frustum::new().copy(self)
}
