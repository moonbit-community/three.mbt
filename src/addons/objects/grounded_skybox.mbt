// Upstream examples/jsm/objects/GroundedSkybox.js: an environment map projected onto a
// sphere whose lower half is flattened into a ground plane.

///|
/// `new GroundedSkybox( map, height, radius, resolution )`: a `Mesh` (upstream adds no
/// members, so this returns a plain `Mesh` without an extension). `height` is the camera
/// height above the ground, `radius` the size of the sphere.
pub fn GroundedSkybox::new(
  map : @core.Texture?,
  height : Double,
  radius : Double,
  resolution~ : Int32 = 128,
) -> @core.Object3D {
  if height <= 0.0 || radius <= 0.0 || resolution <= 0 {
    abort(
      "THREE.GroundedSkybox: height, radius, and resolution must be positive.",
    )
  }
  let geometry = @geometries.SphereGeometry::new(
    radius~,
    width_segments=(2 * resolution).to_double(),
    height_segments=resolution.to_double(),
  )
  geometry.scale(1.0, 1.0, -1.0) |> ignore
  let pos = geometry.get_attribute("position").unwrap()
  let array = pos.array()
  let tmp = @math.Vector3::new(0.0, 0.0, 0.0)
  for i in 0..<pos.count() {
    tmp.set(pos.get_x(i), pos.get_y(i), pos.get_z(i)) |> ignore
    if tmp.y < 0.0 {
      // Smooth out the transition from flat floor to sphere:
      let y1 = -height * 3.0 / 2.0
      let f = if tmp.y < y1 {
        -height / tmp.y
      } else {
        1.0 - tmp.y * tmp.y / (3.0 * y1 * y1)
      }
      tmp.multiply_scalar(f) |> ignore
      array[3 * i] = tmp.x
      array[3 * i + 1] = tmp.y
      array[3 * i + 2] = tmp.z
    }
  }
  pos.set_needs_update(true)
  let material = @core.MeshBasicMaterial::new()
  material.map = map
  material.depth_write = false
  @core.Mesh::new(geometry~, material=Single(material))
}

///|
#external
pub type GroundedSkybox
