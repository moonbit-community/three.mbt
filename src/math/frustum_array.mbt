///|
/// Cached frustums for each sub-camera of an array camera.
pub(all) struct FrustumArray {
  mut coordinate_system : Int32
  mut frustums : Array[Frustum]
  mut count : Int32
}

///|
pub fn FrustumArray::new() -> FrustumArray {
  { coordinate_system: WebGLCoordinateSystem, frustums: [], count: 0, }
}

///|
pub fn FrustumArray::get_frustum(
  self : FrustumArray,
  index : Int32,
) -> Frustum? {
  self.frustums.get(index)
}

///|
pub fn FrustumArray::intersects_sphere(
  self : FrustumArray,
  sphere : Sphere,
) -> Bool {
  let frustums = self.frustums
  for i in 0..<self.count {
    if frustums[i].intersects_sphere(sphere) {
      return true
    }
  }
  false
}

///|
pub fn FrustumArray::intersects_box(self : FrustumArray, box : Box3) -> Bool {
  let frustums = self.frustums
  for i in 0..<self.count {
    if frustums[i].intersects_box(box) {
      return true
    }
  }
  false
}

///|
pub fn FrustumArray::contains_point(
  self : FrustumArray,
  point : Vector3,
) -> Bool {
  let frustums = self.frustums
  for i in 0..<self.count {
    if frustums[i].contains_point(point) {
      return true
    }
  }
  false
}

///|
pub fn FrustumArray::copy(
  self : FrustumArray,
  source : FrustumArray,
) -> FrustumArray {
  self.coordinate_system = source.coordinate_system
  let frustums = self.frustums
  let source_frustums = source.frustums
  for i in 0..<source.count {
    if i >= frustums.length() {
      frustums.push(Frustum::new())
    }
    frustums[i].copy(source_frustums[i]) |> ignore
  }
  self.count = source.count
  self
}

///|
pub fn FrustumArray::clone(self : FrustumArray) -> FrustumArray {
  FrustumArray::new().copy(self)
}
