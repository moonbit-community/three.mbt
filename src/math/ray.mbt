///|
let _ray_vector : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _ray_seg_center : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _ray_seg_dir : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _ray_diff : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
/// A ray that emits from an origin in a certain direction.
pub(all) struct Ray {
  mut origin : Vector3
  mut direction : Vector3
}

///|
pub fn Ray::new(
  origin~ : Vector3 = Vector3::new(0.0, 0.0, 0.0),
  direction~ : Vector3 = Vector3::new(0.0, 0.0, -1.0),
) -> Ray {
  { origin, direction, }
}

///|
pub fn Ray::set(self : Ray, origin : Vector3, direction : Vector3) -> Ray {
  self.origin.copy(origin) |> ignore
  self.direction.copy(direction) |> ignore
  self
}

///|
pub fn Ray::copy(self : Ray, ray : Ray) -> Ray {
  self.origin.copy(ray.origin) |> ignore
  self.direction.copy(ray.direction) |> ignore
  self
}

///|
pub fn Ray::at(self : Ray, t : Double, target : Vector3) -> Vector3 {
  target.copy(self.origin).add_scaled_vector(self.direction, t)
}

///|
pub fn Ray::look_at(self : Ray, v : Vector3) -> Ray {
  self.direction.copy(v).sub(self.origin).normalize() |> ignore
  self
}

///|
pub fn Ray::recast(self : Ray, t : Double) -> Ray {
  self.origin.copy(self.at(t, _ray_vector)) |> ignore
  self
}

///|
pub fn Ray::closest_point_to_point(
  self : Ray,
  point : Vector3,
  target : Vector3,
) -> Vector3 {
  target.sub_vectors(point, self.origin) |> ignore
  let direction_distance = target.dot(self.direction)
  if direction_distance < 0.0 {
    return target.copy(self.origin)
  }
  target.copy(self.origin).add_scaled_vector(self.direction, direction_distance)
}

///|
pub fn Ray::distance_to_point(self : Ray, point : Vector3) -> Double {
  self.distance_sq_to_point(point).sqrt()
}

///|
pub fn Ray::distance_sq_to_point(self : Ray, point : Vector3) -> Double {
  let direction_distance = _ray_vector
    .sub_vectors(point, self.origin)
    .dot(self.direction)
  // point behind the ray
  if direction_distance < 0.0 {
    return self.origin.distance_to_squared(point)
  }
  _ray_vector
  .copy(self.origin)
  .add_scaled_vector(self.direction, direction_distance)
  |> ignore
  _ray_vector.distance_to_squared(point)
}

///|
pub fn Ray::distance_sq_to_segment(
  self : Ray,
  v0 : Vector3,
  v1 : Vector3,
  optional_point_on_ray? : Vector3,
  optional_point_on_segment? : Vector3,
) -> Double {
  // from https://github.com/pmjoniak/GeometricTools/blob/master/GTEngine/Include/Mathematics/GteDistRaySegment.h
  // It returns the min distance between the ray and the segment
  // defined by v0 and v1
  // It can also set two optional targets :
  // - The closest point on the ray
  // - The closest point on the segment
  _ray_seg_center.copy(v0).add(v1).multiply_scalar(0.5) |> ignore
  _ray_seg_dir.copy(v1).sub(v0).normalize() |> ignore
  _ray_diff.copy(self.origin).sub(_ray_seg_center) |> ignore
  let seg_extent = v0.distance_to(v1) * 0.5
  let a01 = -self.direction.dot(_ray_seg_dir)
  let b0 = _ray_diff.dot(self.direction)
  let b1 = -_ray_diff.dot(_ray_seg_dir)
  let c = _ray_diff.length_sq()
  let det = (1.0 - a01 * a01).abs()
  let mut s0 = 0.0
  let mut s1 = 0.0
  let mut sqr_dist = 0.0
  if det > 0.0 {
    // The ray and segment are not parallel.
    s0 = a01 * b1 - b0
    s1 = a01 * b0 - b1
    let ext_det = seg_extent * det
    if s0 >= 0.0 {
      if s1 >= -ext_det {
        if s1 <= ext_det {
          // region 0
          // Minimum at interior points of ray and segment.
          let inv_det = 1.0 / det
          s0 *= inv_det
          s1 *= inv_det
          sqr_dist = s0 * (s0 + a01 * s1 + 2.0 * b0) +
            s1 * (a01 * s0 + s1 + 2.0 * b1) +
            c
        } else {
          // region 1
          s1 = seg_extent
          s0 = _bounds_math_max(0.0, -(a01 * s1 + b0))
          sqr_dist = -s0 * s0 + s1 * (s1 + 2.0 * b1) + c
        }
      } else {
        // region 5
        s1 = -seg_extent
        s0 = _bounds_math_max(0.0, -(a01 * s1 + b0))
        sqr_dist = -s0 * s0 + s1 * (s1 + 2.0 * b1) + c
      }
    } else if s1 <= -ext_det {
      // region 4
      s0 = _bounds_math_max(0.0, -(-a01 * seg_extent + b0))
      s1 = if s0 > 0.0 {
        -seg_extent
      } else {
        _bounds_math_min(_bounds_math_max(-seg_extent, -b1), seg_extent)
      }
      sqr_dist = -s0 * s0 + s1 * (s1 + 2.0 * b1) + c
    } else if s1 <= ext_det {
      // region 3
      s0 = 0.0
      s1 = _bounds_math_min(_bounds_math_max(-seg_extent, -b1), seg_extent)
      sqr_dist = s1 * (s1 + 2.0 * b1) + c
    } else {
      // region 2
      s0 = _bounds_math_max(0.0, -(a01 * seg_extent + b0))
      s1 = if s0 > 0.0 {
        seg_extent
      } else {
        _bounds_math_min(_bounds_math_max(-seg_extent, -b1), seg_extent)
      }
      sqr_dist = -s0 * s0 + s1 * (s1 + 2.0 * b1) + c
    }
  } else {
    // Ray and segment are parallel.
    s1 = if a01 > 0.0 { -seg_extent } else { seg_extent }
    s0 = _bounds_math_max(0.0, -(a01 * s1 + b0))
    sqr_dist = -s0 * s0 + s1 * (s1 + 2.0 * b1) + c
  }
  if optional_point_on_ray is Some(point_on_ray) {
    point_on_ray.copy(self.origin).add_scaled_vector(self.direction, s0)
    |> ignore
  }
  if optional_point_on_segment is Some(point_on_segment) {
    point_on_segment.copy(_ray_seg_center).add_scaled_vector(_ray_seg_dir, s1)
    |> ignore
  }
  sqr_dist
}

///|
pub fn Ray::intersect_sphere(
  self : Ray,
  sphere : Sphere,
  target : Vector3,
) -> Vector3? {
  if sphere.radius < 0.0 {
    return None // handle empty spheres, see #31187
  }
  _ray_vector.sub_vectors(sphere.center, self.origin) |> ignore
  let tca = _ray_vector.dot(self.direction)
  let d2 = _ray_vector.dot(_ray_vector) - tca * tca
  let radius2 = sphere.radius * sphere.radius
  if d2 > radius2 {
    return None
  }
  let thc = (radius2 - d2).sqrt()
  // t0 = first intersect point - entrance on front of sphere
  let t0 = tca - thc
  // t1 = second intersect point - exit point on back of sphere
  let t1 = tca + thc
  // test to see if t1 is behind the ray - if so, return null
  if t1 < 0.0 {
    return None
  }
  // test to see if t0 is behind the ray:
  // if it is, the ray is inside the sphere, so return the second exit point scaled by t1,
  // in order to always return an intersect point that is in front of the ray.
  if t0 < 0.0 {
    return Some(self.at(t1, target))
  }
  // else t0 is in front of the ray, so return the first collision point scaled by t0
  Some(self.at(t0, target))
}

///|
pub fn Ray::intersects_sphere(self : Ray, sphere : Sphere) -> Bool {
  if sphere.radius < 0.0 {
    return false // handle empty spheres, see #31187
  }
  self.distance_sq_to_point(sphere.center) <= sphere.radius * sphere.radius
}

///|
pub fn Ray::distance_to_plane(self : Ray, plane : Plane) -> Double? {
  let denominator = plane.normal.dot(self.direction)
  if denominator == 0.0 {
    // line is coplanar, return origin
    if plane.distance_to_point(self.origin) == 0.0 {
      return Some(0.0)
    }
    // Null is preferable to undefined since undefined means.... it is undefined
    return None
  }
  let t = -(self.origin.dot(plane.normal) + plane.constant) / denominator
  // Return if the ray never intersects the plane
  if t >= 0.0 {
    Some(t)
  } else {
    None
  }
}

///|
pub fn Ray::intersect_plane(
  self : Ray,
  plane : Plane,
  target : Vector3,
) -> Vector3? {
  match self.distance_to_plane(plane) {
    None => None
    Some(t) => Some(self.at(t, target))
  }
}

///|
pub fn Ray::intersects_plane(self : Ray, plane : Plane) -> Bool {
  // check if the ray lies on the plane first
  let dist_to_point = plane.distance_to_point(self.origin)
  if dist_to_point == 0.0 {
    return true
  }
  let denominator = plane.normal.dot(self.direction)
  if denominator * dist_to_point < 0.0 {
    return true
  }
  // ray origin is behind the plane (and is pointing behind it)
  false
}

///|
pub fn Ray::intersect_box(self : Ray, box : Box3, target : Vector3) -> Vector3? {
  let mut tmin = 0.0
  let mut tmax = 0.0
  let mut tymin = 0.0
  let mut tymax = 0.0
  let mut tzmin = 0.0
  let mut tzmax = 0.0
  let invdirx = 1.0 / self.direction.x
  let invdiry = 1.0 / self.direction.y
  let invdirz = 1.0 / self.direction.z
  let origin = self.origin
  if invdirx >= 0.0 {
    tmin = (box.min.x - origin.x) * invdirx
    tmax = (box.max.x - origin.x) * invdirx
  } else {
    tmin = (box.max.x - origin.x) * invdirx
    tmax = (box.min.x - origin.x) * invdirx
  }
  if invdiry >= 0.0 {
    tymin = (box.min.y - origin.y) * invdiry
    tymax = (box.max.y - origin.y) * invdiry
  } else {
    tymin = (box.max.y - origin.y) * invdiry
    tymax = (box.min.y - origin.y) * invdiry
  }
  if tmin > tymax || tymin > tmax {
    return None
  }
  if tymin > tmin || tmin.is_nan() {
    tmin = tymin
  }
  if tymax < tmax || tmax.is_nan() {
    tmax = tymax
  }
  if invdirz >= 0.0 {
    tzmin = (box.min.z - origin.z) * invdirz
    tzmax = (box.max.z - origin.z) * invdirz
  } else {
    tzmin = (box.max.z - origin.z) * invdirz
    tzmax = (box.min.z - origin.z) * invdirz
  }
  if tmin > tzmax || tzmin > tmax {
    return None
  }
  if tzmin > tmin || tmin.is_nan() {
    tmin = tzmin
  }
  if tzmax < tmax || tmax.is_nan() {
    tmax = tzmax
  }
  //return point closest to the ray (positive side)
  if tmax < 0.0 {
    return None
  }
  Some(self.at(if tmin >= 0.0 { tmin } else { tmax }, target))
}

///|
pub fn Ray::intersects_box(self : Ray, box : Box3) -> Bool {
  self.intersect_box(box, _ray_vector) is Some(_)
}

///|
pub fn Ray::intersect_triangle(
  self : Ray,
  a : Vector3,
  b : Vector3,
  c : Vector3,
  backface_culling : Bool,
  target : Vector3,
) -> Vector3? {
  // Watertight ray/triangle intersection. Reference: Woop, Benthin, Wald,
  // "Watertight Ray/Triangle Intersection", JCGT vol. 2 no. 1 (2013), Appendix A.
  // https://jcgt.org/published/0002/01/05/
  let origin = self.origin
  let direction = self.direction
  let dx = direction.x
  let dy = direction.y
  let dz = direction.z
  // triangle vertices relative to the ray origin
  let aox = a.x - origin.x
  let aoy = a.y - origin.y
  let aoz = a.z - origin.z
  let box = b.x - origin.x
  let boy = b.y - origin.y
  let boz = b.z - origin.z
  let cox = c.x - origin.x
  let coy = c.y - origin.y
  let coz = c.z - origin.z
  // Use the dimension where the ray direction is maximal as the projection
  // axis (kz) and read every component already permuted into (kx, ky, kz).
  // kx and ky are swapped when the direction's kz component is negative, to
  // preserve the winding order of triangles.
  let adx = dx.abs()
  let ady = dy.abs()
  let adz = dz.abs()
  let mut dkx = 0.0
  let mut dky = 0.0
  let mut dkz = 0.0
  let mut akx = 0.0
  let mut aky = 0.0
  let mut akz = 0.0
  let mut bkx = 0.0
  let mut bky = 0.0
  let mut bkz = 0.0
  let mut ckx = 0.0
  let mut cky = 0.0
  let mut ckz = 0.0
  if adx >= ady && adx >= adz {
    dkz = dx
    akz = aox
    bkz = box
    ckz = cox
    if dx >= 0.0 {
      dkx = dy
      dky = dz
      akx = aoy
      aky = aoz
      bkx = boy
      bky = boz
      ckx = coy
      cky = coz
    } else {
      dkx = dz
      dky = dy
      akx = aoz
      aky = aoy
      bkx = boz
      bky = boy
      ckx = coz
      cky = coy
    }
  } else if ady >= adz {
    dkz = dy
    akz = aoy
    bkz = boy
    ckz = coy
    if dy >= 0.0 {
      dkx = dz
      dky = dx
      akx = aoz
      aky = aox
      bkx = boz
      bky = box
      ckx = coz
      cky = cox
    } else {
      dkx = dx
      dky = dz
      akx = aox
      aky = aoz
      bkx = box
      bky = boz
      ckx = cox
      cky = coz
    }
  } else {
    dkz = dz
    akz = aoz
    bkz = boz
    ckz = coz
    if dz >= 0.0 {
      dkx = dx
      dky = dy
      akx = aox
      aky = aoy
      bkx = box
      bky = boy
      ckx = cox
      cky = coy
    } else {
      dkx = dy
      dky = dx
      akx = aoy
      aky = aox
      bkx = boy
      bky = box
      ckx = coy
      cky = cox
    }
  }
  // a zero direction has no maximal axis and cannot intersect
  if dkz == 0.0 {
    return None
  }
  // shear constants that align the ray with the +kz axis
  let sx = dkx / dkz
  let sy = dky / dkz
  let sz = 1.0 / dkz
  // sheared and scaled vertices
  let ax = akx - sx * akz
  let ay = aky - sy * akz
  let bx = bkx - sx * bkz
  let by = bky - sy * bkz
  let cx = ckx - sx * ckz
  let cy = cky - sy * ckz
  // scaled barycentric coordinates (signed edge functions); the shear makes a
  // shared edge evaluate identically for both adjacent triangles, so the ray
  // can never fall between them
  let u = cx * by - cy * bx
  let v = ax * cy - ay * cx
  let w = bx * ay - by * ax
  if backface_culling {
    if u < 0.0 || v < 0.0 || w < 0.0 {
      return None
    }
  } else if (u < 0.0 || v < 0.0 || w < 0.0) && (u > 0.0 || v > 0.0 || w > 0.0) {
    return None
  }
  let det = u + v + w
  // ray is co-planar with the triangle
  if det == 0.0 {
    return None
  }
  // scaled hit distance; t = tScaled / det must lie in front of the origin
  let t_scaled = sz * (u * akz + v * bkz + w * ckz)
  if (if det > 0.0 { t_scaled < 0.0 } else { t_scaled > 0.0 }) {
    return None
  }
  Some(self.at(t_scaled / det, target))
}

///|
pub fn Ray::apply_matrix4(self : Ray, matrix4 : Matrix4) -> Ray {
  self.origin.apply_matrix4(matrix4) |> ignore
  self.direction.transform_direction(matrix4) |> ignore
  self
}

///|
pub fn Ray::equals(self : Ray, ray : Ray) -> Bool {
  ray.origin.equals(self.origin) && ray.direction.equals(self.direction)
}

///|
pub fn Ray::clone(self : Ray) -> Ray {
  Ray::new().copy(self)
}
