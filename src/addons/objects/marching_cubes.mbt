// Upstream examples/jsm/objects/MarchingCubes.js: metaballs and planes summed into a
// scalar field and polygonized into a dynamic `BufferGeometry`. Upstream's `count` (the
// number of vertices written) is the mesh's own `count`, as there.

///|
/// The color `addBall` takes: a `Color`, an `[ r, g, b ]` array or anything `new Color`
/// accepts (a hex here).
pub(all) enum MarchingCubesColor {
  Color(@math.Color)
  Array(Array[Double])
  Hex(Int32)
}

///|
pub(all) struct MarchingCubes {
  object : @core.Object3D
  geometry : @core.BufferGeometry
  max_poly_count : Int32
  vlist : @core.TypedArray
  nlist : @core.TypedArray
  clist : @core.TypedArray
  mut enable_uvs : Bool
  mut enable_colors : Bool
  mut resolution : Int32
  mut isolation : Double
  mut size : Int32
  mut size2 : Int32
  mut size3 : Int32
  mut halfsize : Double
  mut delta : Double
  mut yd : Int32
  mut zd : Int32
  mut field : @core.TypedArray
  mut normal_cache : @core.TypedArray
  mut palette : @core.TypedArray
  mut position_array : @core.TypedArray
  mut normal_array : @core.TypedArray
  mut uv_array : @core.TypedArray?
  mut color_array : @core.TypedArray?
}

///|
pub impl @core.Object3DExtension for MarchingCubes with fn type_name(_) {
  "Mesh"
}

///|
/// `new this.constructor()`: upstream's constructor with `resolution` undefined.
pub impl @core.Object3DExtension for MarchingCubes with fn construct(_) {
  MarchingCubes::new(0, None)
}

///|
pub impl @core.Object3DExtension for MarchingCubes with fn has_flag(_, flag) {
  flag == "isMarchingCubes" || flag == "class:MarchingCubes"
}

///|
#deprecated
pub extend MarchingCubes with @core.Object3DExtension::{
  type_name,
  construct,
  payload,
  has_flag,
  raycast,
  copy_from,
  to_json,
  update_matrix_world,
  update_world_matrix,
  intersects_frustum,
  get_world_direction,
  dispose,
}

///|
/// `new MarchingCubes( resolution, material, enableUvs, enableColors, maxPolyCount )`.
pub fn MarchingCubes::new(
  resolution : Int32,
  material : @core.Material?,
  enable_uvs~ : Bool = false,
  enable_colors~ : Bool = false,
  max_poly_count~ : Int32 = 10000,
) -> @core.Object3D {
  let geometry = @core.BufferGeometry::new()
  let object = match material {
    Some(material) => @core.Mesh::new(geometry~, material=Single(material))
    None => @core.Mesh::new(geometry~)
  }
  let mc : MarchingCubes = {
    object,
    geometry,
    max_poly_count,
    // temp buffers used in polygonize
    vlist: @core.TypedArray::float32(12 * 3),
    nlist: @core.TypedArray::float32(12 * 3),
    clist: @core.TypedArray::float32(12 * 3),
    enable_uvs,
    enable_colors,
    resolution: 0,
    isolation: 0.0,
    size: 0,
    size2: 0,
    size3: 0,
    halfsize: 0.0,
    delta: 0.0,
    yd: 0,
    zd: 0,
    field: @core.TypedArray::float32(0),
    normal_cache: @core.TypedArray::float32(0),
    palette: @core.TypedArray::float32(0),
    position_array: @core.TypedArray::float32(0),
    normal_array: @core.TypedArray::float32(0),
    uv_array: None,
    color_array: None,
  }
  object.set_extension(mc) |> ignore
  mc.init(resolution)
  object
}

///|
/// The payload of a `MarchingCubes`, or `None` for other objects.
pub fn MarchingCubes::of(object : @core.Object3D) -> MarchingCubes? {
  objects_payload(object, "class:MarchingCubes")
}

///|
fn MarchingCubes::mesh(self : MarchingCubes) -> @core.Mesh {
  match self.object.kind {
    Mesh(mesh) => mesh
    _ => abort("unreachable")
  }
}

///|
/// `this.count`, the mesh's `count`: vertices written by `update`.
pub fn MarchingCubes::count(self : MarchingCubes) -> Int32 {
  self.mesh().count
}

///|
fn MarchingCubes::set_count(self : MarchingCubes, count : Int32) -> Unit {
  self.mesh().count = count
}

///|
/// `init( resolution )`: allocates the field and the geometry buffers.
pub fn MarchingCubes::init(self : MarchingCubes, resolution : Int32) -> Unit {
  let geometry = self.geometry
  self.resolution = resolution
  // parameters
  self.isolation = 80.0
  // size of field, 32 is pushing it in Javascript :)
  self.size = resolution
  self.size2 = self.size * self.size
  self.size3 = self.size2 * self.size
  self.halfsize = self.size.to_double() / 2.0
  // deltas
  self.delta = 2.0 / self.size.to_double()
  self.yd = self.size
  self.zd = self.size2
  self.field = @core.TypedArray::float32(self.size3)
  self.normal_cache = @core.TypedArray::float32(self.size3 * 3)
  self.palette = @core.TypedArray::float32(self.size3 * 3)
  //
  self.set_count(0)
  let max_vertex_count = self.max_poly_count * 3
  self.position_array = @core.TypedArray::float32(max_vertex_count * 3)
  let position_attribute = @core.BufferAttribute::new(self.position_array, 3)
  position_attribute.set_usage(@core.DynamicDrawUsage) |> ignore
  geometry.set_attribute("position", position_attribute) |> ignore
  self.normal_array = @core.TypedArray::float32(max_vertex_count * 3)
  let normal_attribute = @core.BufferAttribute::new(self.normal_array, 3)
  normal_attribute.set_usage(@core.DynamicDrawUsage) |> ignore
  geometry.set_attribute("normal", normal_attribute) |> ignore
  if self.enable_uvs {
    let uv_array = @core.TypedArray::float32(max_vertex_count * 2)
    self.uv_array = Some(uv_array)
    let uv_attribute = @core.BufferAttribute::new(uv_array, 2)
    uv_attribute.set_usage(@core.DynamicDrawUsage) |> ignore
    geometry.set_attribute("uv", uv_attribute) |> ignore
  }
  if self.enable_colors {
    let color_array = @core.TypedArray::float32(max_vertex_count * 3)
    self.color_array = Some(color_array)
    let color_attribute = @core.BufferAttribute::new(color_array, 3)
    color_attribute.set_usage(@core.DynamicDrawUsage) |> ignore
    geometry.set_attribute("color", color_attribute) |> ignore
  }
  geometry.bounding_sphere = Some(
    @math.Sphere::new(center=@math.Vector3::new(0.0, 0.0, 0.0), radius=1.0),
  )
}

///|
fn marching_cubes_lerp(a : Double, b : Double, t : Double) -> Double {
  a + (b - a) * t
}

///|
fn MarchingCubes::v_int_x(
  self : MarchingCubes,
  q : Int32,
  offset : Int32,
  isol : Double,
  x : Double,
  y : Double,
  z : Double,
  valp1 : Double,
  valp2 : Double,
  c_offset1 : Int32,
  c_offset2 : Int32,
) -> Unit {
  let mu = (isol - valp1) / (valp2 - valp1)
  let nc = self.normal_cache
  let vlist = self.vlist
  let nlist = self.nlist
  let clist = self.clist
  let palette = self.palette
  vlist[offset + 0] = x + mu * self.delta
  vlist[offset + 1] = y
  vlist[offset + 2] = z
  nlist[offset + 0] = marching_cubes_lerp(nc[q + 0], nc[q + 3], mu)
  nlist[offset + 1] = marching_cubes_lerp(nc[q + 1], nc[q + 4], mu)
  nlist[offset + 2] = marching_cubes_lerp(nc[q + 2], nc[q + 5], mu)
  clist[offset + 0] = marching_cubes_lerp(
    palette[c_offset1 * 3 + 0],
    palette[c_offset2 * 3 + 0],
    mu,
  )
  clist[offset + 1] = marching_cubes_lerp(
    palette[c_offset1 * 3 + 1],
    palette[c_offset2 * 3 + 1],
    mu,
  )
  clist[offset + 2] = marching_cubes_lerp(
    palette[c_offset1 * 3 + 2],
    palette[c_offset2 * 3 + 2],
    mu,
  )
}

///|
fn MarchingCubes::v_int_y(
  self : MarchingCubes,
  q : Int32,
  offset : Int32,
  isol : Double,
  x : Double,
  y : Double,
  z : Double,
  valp1 : Double,
  valp2 : Double,
  c_offset1 : Int32,
  c_offset2 : Int32,
) -> Unit {
  let mu = (isol - valp1) / (valp2 - valp1)
  let nc = self.normal_cache
  let vlist = self.vlist
  let nlist = self.nlist
  let clist = self.clist
  let palette = self.palette
  vlist[offset + 0] = x
  vlist[offset + 1] = y + mu * self.delta
  vlist[offset + 2] = z
  let q2 = q + self.yd * 3
  nlist[offset + 0] = marching_cubes_lerp(nc[q + 0], nc[q2 + 0], mu)
  nlist[offset + 1] = marching_cubes_lerp(nc[q + 1], nc[q2 + 1], mu)
  nlist[offset + 2] = marching_cubes_lerp(nc[q + 2], nc[q2 + 2], mu)
  clist[offset + 0] = marching_cubes_lerp(
    palette[c_offset1 * 3 + 0],
    palette[c_offset2 * 3 + 0],
    mu,
  )
  clist[offset + 1] = marching_cubes_lerp(
    palette[c_offset1 * 3 + 1],
    palette[c_offset2 * 3 + 1],
    mu,
  )
  clist[offset + 2] = marching_cubes_lerp(
    palette[c_offset1 * 3 + 2],
    palette[c_offset2 * 3 + 2],
    mu,
  )
}

///|
fn MarchingCubes::v_int_z(
  self : MarchingCubes,
  q : Int32,
  offset : Int32,
  isol : Double,
  x : Double,
  y : Double,
  z : Double,
  valp1 : Double,
  valp2 : Double,
  c_offset1 : Int32,
  c_offset2 : Int32,
) -> Unit {
  let mu = (isol - valp1) / (valp2 - valp1)
  let nc = self.normal_cache
  let vlist = self.vlist
  let nlist = self.nlist
  let clist = self.clist
  let palette = self.palette
  vlist[offset + 0] = x
  vlist[offset + 1] = y
  vlist[offset + 2] = z + mu * self.delta
  let q2 = q + self.zd * 3
  nlist[offset + 0] = marching_cubes_lerp(nc[q + 0], nc[q2 + 0], mu)
  nlist[offset + 1] = marching_cubes_lerp(nc[q + 1], nc[q2 + 1], mu)
  nlist[offset + 2] = marching_cubes_lerp(nc[q + 2], nc[q2 + 2], mu)
  clist[offset + 0] = marching_cubes_lerp(
    palette[c_offset1 * 3 + 0],
    palette[c_offset2 * 3 + 0],
    mu,
  )
  clist[offset + 1] = marching_cubes_lerp(
    palette[c_offset1 * 3 + 1],
    palette[c_offset2 * 3 + 1],
    mu,
  )
  clist[offset + 2] = marching_cubes_lerp(
    palette[c_offset1 * 3 + 2],
    palette[c_offset2 * 3 + 2],
    mu,
  )
}

///|
fn MarchingCubes::comp_norm(self : MarchingCubes, q : Int32) -> Unit {
  let q3 = q * 3
  let nc = self.normal_cache
  let field = self.field
  if nc[q3] == 0.0 {
    nc[q3 + 0] = field[q - 1] - field[q + 1]
    nc[q3 + 1] = field[q - self.yd] - field[q + self.yd]
    nc[q3 + 2] = field[q - self.zd] - field[q + self.zd]
  }
}

///|
/// Returns total number of triangles. Fills triangles.
/// (this is where most of time is spent - it's inner work of O(n3) loop )
fn MarchingCubes::polygonize(
  self : MarchingCubes,
  fx : Double,
  fy : Double,
  fz : Double,
  q : Int32,
  isol : Double,
) -> Int32 {
  // cache indices
  let q1 = q + 1
  let qy = q + self.yd
  let qz = q + self.zd
  let q1y = q1 + self.yd
  let q1z = q1 + self.zd
  let qyz = q + self.yd + self.zd
  let q1yz = q1 + self.yd + self.zd
  let mut cubeindex = 0
  let field = self.field
  let field0 = field[q]
  let field1 = field[q1]
  let field2 = field[qy]
  let field3 = field[q1y]
  let field4 = field[qz]
  let field5 = field[q1z]
  let field6 = field[qyz]
  let field7 = field[q1yz]
  if field0 < isol {
    cubeindex = cubeindex | 1
  }
  if field1 < isol {
    cubeindex = cubeindex | 2
  }
  if field2 < isol {
    cubeindex = cubeindex | 8
  }
  if field3 < isol {
    cubeindex = cubeindex | 4
  }
  if field4 < isol {
    cubeindex = cubeindex | 16
  }
  if field5 < isol {
    cubeindex = cubeindex | 32
  }
  if field6 < isol {
    cubeindex = cubeindex | 128
  }
  if field7 < isol {
    cubeindex = cubeindex | 64
  }
  // if cube is entirely in/out of the surface - bail, nothing to draw
  let bits = edge_table[cubeindex]
  if bits == 0 {
    return 0
  }
  let d = self.delta
  let fx2 = fx + d
  let fy2 = fy + d
  let fz2 = fz + d
  // top of the cube
  if (bits & 1) != 0 {
    self.comp_norm(q)
    self.comp_norm(q1)
    self.v_int_x(q * 3, 0, isol, fx, fy, fz, field0, field1, q, q1)
  }
  if (bits & 2) != 0 {
    self.comp_norm(q1)
    self.comp_norm(q1y)
    self.v_int_y(q1 * 3, 3, isol, fx2, fy, fz, field1, field3, q1, q1y)
  }
  if (bits & 4) != 0 {
    self.comp_norm(qy)
    self.comp_norm(q1y)
    self.v_int_x(qy * 3, 6, isol, fx, fy2, fz, field2, field3, qy, q1y)
  }
  if (bits & 8) != 0 {
    self.comp_norm(q)
    self.comp_norm(qy)
    self.v_int_y(q * 3, 9, isol, fx, fy, fz, field0, field2, q, qy)
  }
  // bottom of the cube
  if (bits & 16) != 0 {
    self.comp_norm(qz)
    self.comp_norm(q1z)
    self.v_int_x(qz * 3, 12, isol, fx, fy, fz2, field4, field5, qz, q1z)
  }
  if (bits & 32) != 0 {
    self.comp_norm(q1z)
    self.comp_norm(q1yz)
    self.v_int_y(q1z * 3, 15, isol, fx2, fy, fz2, field5, field7, q1z, q1yz)
  }
  if (bits & 64) != 0 {
    self.comp_norm(qyz)
    self.comp_norm(q1yz)
    self.v_int_x(qyz * 3, 18, isol, fx, fy2, fz2, field6, field7, qyz, q1yz)
  }
  if (bits & 128) != 0 {
    self.comp_norm(qz)
    self.comp_norm(qyz)
    self.v_int_y(qz * 3, 21, isol, fx, fy, fz2, field4, field6, qz, qyz)
  }
  // vertical lines of the cube
  if (bits & 256) != 0 {
    self.comp_norm(q)
    self.comp_norm(qz)
    self.v_int_z(q * 3, 24, isol, fx, fy, fz, field0, field4, q, qz)
  }
  if (bits & 512) != 0 {
    self.comp_norm(q1)
    self.comp_norm(q1z)
    self.v_int_z(q1 * 3, 27, isol, fx2, fy, fz, field1, field5, q1, q1z)
  }
  if (bits & 1024) != 0 {
    self.comp_norm(q1y)
    self.comp_norm(q1yz)
    self.v_int_z(q1y * 3, 30, isol, fx2, fy2, fz, field3, field7, q1y, q1yz)
  }
  if (bits & 2048) != 0 {
    self.comp_norm(qy)
    self.comp_norm(qyz)
    self.v_int_z(qy * 3, 33, isol, fx, fy2, fz, field2, field6, qy, qyz)
  }
  cubeindex = cubeindex << 4 // re-purpose cubeindex into an offset into triTable
  let mut numtris = 0
  let mut i = 0
  // here is where triangles are created
  while tri_table[cubeindex + i] != -1 {
    let o1 = cubeindex + i
    let o2 = o1 + 1
    let o3 = o1 + 2
    self.posnormtriv(3 * tri_table[o1], 3 * tri_table[o2], 3 * tri_table[o3])
    i += 3
    numtris += 1
  }
  numtris
}

///|
fn MarchingCubes::posnormtriv(
  self : MarchingCubes,
  o1 : Int32,
  o2 : Int32,
  o3 : Int32,
) -> Unit {
  let pos = self.vlist
  let norm = self.nlist
  let colors = self.clist
  let count = self.count()
  let c = count * 3
  let position_array = self.position_array
  let normal_array = self.normal_array
  // positions
  position_array[c + 0] = pos[o1]
  position_array[c + 1] = pos[o1 + 1]
  position_array[c + 2] = pos[o1 + 2]
  position_array[c + 3] = pos[o2]
  position_array[c + 4] = pos[o2 + 1]
  position_array[c + 5] = pos[o2 + 2]
  position_array[c + 6] = pos[o3]
  position_array[c + 7] = pos[o3 + 1]
  position_array[c + 8] = pos[o3 + 2]
  // normals
  let flat_shading = match self.mesh().material {
    Single(material) => material.flat_shading == Some(true)
    Multiple(_) => false
  }
  if flat_shading {
    let nx = (norm[o1 + 0] + norm[o2 + 0] + norm[o3 + 0]) / 3.0
    let ny = (norm[o1 + 1] + norm[o2 + 1] + norm[o3 + 1]) / 3.0
    let nz = (norm[o1 + 2] + norm[o2 + 2] + norm[o3 + 2]) / 3.0
    normal_array[c + 0] = nx
    normal_array[c + 1] = ny
    normal_array[c + 2] = nz
    normal_array[c + 3] = nx
    normal_array[c + 4] = ny
    normal_array[c + 5] = nz
    normal_array[c + 6] = nx
    normal_array[c + 7] = ny
    normal_array[c + 8] = nz
  } else {
    normal_array[c + 0] = norm[o1 + 0]
    normal_array[c + 1] = norm[o1 + 1]
    normal_array[c + 2] = norm[o1 + 2]
    normal_array[c + 3] = norm[o2 + 0]
    normal_array[c + 4] = norm[o2 + 1]
    normal_array[c + 5] = norm[o2 + 2]
    normal_array[c + 6] = norm[o3 + 0]
    normal_array[c + 7] = norm[o3 + 1]
    normal_array[c + 8] = norm[o3 + 2]
  }
  // uvs
  if self.enable_uvs {
    let d = count * 2
    let uv_array = self.uv_array.unwrap()
    uv_array[d + 0] = pos[o1 + 0]
    uv_array[d + 1] = pos[o1 + 2]
    uv_array[d + 2] = pos[o2 + 0]
    uv_array[d + 3] = pos[o2 + 2]
    uv_array[d + 4] = pos[o3 + 0]
    uv_array[d + 5] = pos[o3 + 2]
  }
  // colors
  if self.enable_colors {
    let color_array = self.color_array.unwrap()
    color_array[c + 0] = colors[o1 + 0]
    color_array[c + 1] = colors[o1 + 1]
    color_array[c + 2] = colors[o1 + 2]
    color_array[c + 3] = colors[o2 + 0]
    color_array[c + 4] = colors[o2 + 1]
    color_array[c + 5] = colors[o2 + 2]
    color_array[c + 6] = colors[o3 + 0]
    color_array[c + 7] = colors[o3 + 1]
    color_array[c + 8] = colors[o3 + 2]
  }
  self.set_count(count + 3)
}

///|
/// `addBall( ballx, bally, ballz, strength, subtract, colors )`: adds a metaball at
/// field coordinates in [ 0, 1 ].
pub fn MarchingCubes::add_ball(
  self : MarchingCubes,
  ballx : Double,
  bally : Double,
  ballz : Double,
  strength : Double,
  subtract : Double,
  colors? : MarchingCubesColor,
) -> Unit {
  let sign = objects_math_sign(strength)
  let strength = objects_math_abs(strength)
  let ball_color = match colors {
    None => @math.Color::new(ballx, bally, ballz)
    Some(Color(c)) => c
    Some(Array(a)) =>
      @math.Color::new(
        objects_math_min(objects_math_abs(a[0]), 1.0),
        objects_math_min(objects_math_abs(a[1]), 1.0),
        objects_math_min(objects_math_abs(a[2]), 1.0),
      )
    Some(Hex(hex)) => @math.Color::from_hex(hex)
  }
  // Let's solve the equation to find the radius:
  // 1.0 / (0.000001 + radius^2) * strength - subtract = 0
  // strength / (radius^2) = subtract
  // strength = subtract * radius^2
  // radius^2 = strength / subtract
  // radius = sqrt(strength / subtract)
  let size = self.size.to_double()
  let radius = size * objects_math_sqrt(strength / subtract)
  let zs = ballz * size
  let ys = bally * size
  let xs = ballx * size
  let mut min_z = objects_math_floor(zs - radius)
  if min_z < 1.0 {
    min_z = 1.0
  }
  let mut max_z = objects_math_floor(zs + radius)
  if max_z > size - 1.0 {
    max_z = size - 1.0
  }
  let mut min_y = objects_math_floor(ys - radius)
  if min_y < 1.0 {
    min_y = 1.0
  }
  let mut max_y = objects_math_floor(ys + radius)
  if max_y > size - 1.0 {
    max_y = size - 1.0
  }
  let mut min_x = objects_math_floor(xs - radius)
  if min_x < 1.0 {
    min_x = 1.0
  }
  let mut max_x = objects_math_floor(xs + radius)
  if max_x > size - 1.0 {
    max_x = size - 1.0
  }
  // Don't polygonize in the outer layer because normals aren't
  // well-defined there.
  let field = self.field
  let palette = self.palette
  let mut z = min_z
  while z < max_z {
    let z_offset = self.size2.to_double() * z
    let fz = z / size - ballz
    let fz2 = fz * fz
    let mut y = min_y
    while y < max_y {
      let y_offset = z_offset + size * y
      let fy = y / size - bally
      let fy2 = fy * fy
      let mut x = min_x
      while x < max_x {
        let fx = x / size - ballx
        let val = strength / (0.000001 + fx * fx + fy2 + fz2) - subtract
        if val > 0.0 {
          let index = (y_offset + x).to_int()
          field[index] = field[index] + val * sign
          // optimization
          // http://www.geisswerks.com/ryan/BLOBS/blobs.html
          let ratio = objects_math_sqrt(
              (x - xs) * (x - xs) + (y - ys) * (y - ys) + (z - zs) * (z - zs),
            ) /
            radius
          let contrib = 1.0 -
            ratio * ratio * ratio * (ratio * (ratio * 6.0 - 15.0) + 10.0)
          palette[index * 3 + 0] = palette[index * 3 + 0] +
            ball_color.r * contrib
          palette[index * 3 + 1] = palette[index * 3 + 1] +
            ball_color.g * contrib
          palette[index * 3 + 2] = palette[index * 3 + 2] +
            ball_color.b * contrib
        }
        x += 1.0
      }
      y += 1.0
    }
    z += 1.0
  }
}

///|
/// `addPlaneX( strength, subtract )`.
pub fn MarchingCubes::add_plane_x(
  self : MarchingCubes,
  strength : Double,
  subtract : Double,
) -> Unit {
  // cache attribute lookups
  let size = self.size
  let yd = self.yd
  let zd = self.zd
  let field = self.field
  let mut dist = size.to_double() * objects_math_sqrt(strength / subtract)
  if dist > size.to_double() {
    dist = size.to_double()
  }
  let mut x = 0
  while x.to_double() < dist {
    let xdiv = x.to_double() / size.to_double()
    let xx = xdiv * xdiv
    let val = strength / (0.0001 + xx) - subtract
    if val > 0.0 {
      for y in 0..<size {
        let cxy = x + y * yd
        for z in 0..<size {
          field[zd * z + cxy] = field[zd * z + cxy] + val
        }
      }
    }
    x += 1
  }
}

///|
/// `addPlaneY( strength, subtract )`.
pub fn MarchingCubes::add_plane_y(
  self : MarchingCubes,
  strength : Double,
  subtract : Double,
) -> Unit {
  // cache attribute lookups
  let size = self.size
  let yd = self.yd
  let zd = self.zd
  let field = self.field
  let mut dist = size.to_double() * objects_math_sqrt(strength / subtract)
  if dist > size.to_double() {
    dist = size.to_double()
  }
  let mut y = 0
  while y.to_double() < dist {
    let ydiv = y.to_double() / size.to_double()
    let yy = ydiv * ydiv
    let val = strength / (0.0001 + yy) - subtract
    if val > 0.0 {
      let cy = y * yd
      for x in 0..<size {
        let cxy = cy + x
        for z in 0..<size {
          field[zd * z + cxy] = field[zd * z + cxy] + val
        }
      }
    }
    y += 1
  }
}

///|
/// `addPlaneZ( strength, subtract )`.
pub fn MarchingCubes::add_plane_z(
  self : MarchingCubes,
  strength : Double,
  subtract : Double,
) -> Unit {
  // cache attribute lookups
  let size = self.size
  let yd = self.yd
  let zd = self.zd
  let field = self.field
  let mut dist = size.to_double() * objects_math_sqrt(strength / subtract)
  if dist > size.to_double() {
    dist = size.to_double()
  }
  let mut z = 0
  while z.to_double() < dist {
    let zdiv = z.to_double() / size.to_double()
    let zz = zdiv * zdiv
    let val = strength / (0.0001 + zz) - subtract
    if val > 0.0 {
      let cz = zd * z
      for y in 0..<size {
        let cyz = cz + y * yd
        for x in 0..<size {
          field[cyz + x] = field[cyz + x] + val
        }
      }
    }
    z += 1
  }
}

///|
/// `setCell( x, y, z, value )`.
pub fn MarchingCubes::set_cell(
  self : MarchingCubes,
  x : Int32,
  y : Int32,
  z : Int32,
  value : Double,
) -> Unit {
  let index = self.size2 * z + self.size * y + x
  self.field[index] = value
}

///|
/// `getCell( x, y, z )`.
pub fn MarchingCubes::get_cell(
  self : MarchingCubes,
  x : Int32,
  y : Int32,
  z : Int32,
) -> Double {
  let index = self.size2 * z + self.size * y + x
  self.field[index]
}

///|
/// `blur( intensity )`: averages each cell with its diagonal neighbours.
pub fn MarchingCubes::blur(
  self : MarchingCubes,
  intensity~ : Double = 1.0,
) -> Unit {
  let field = self.field
  let field_copy = field.slice()
  let size = self.size
  let size2 = self.size2
  for x in 0..<size {
    for y in 0..<size {
      for z in 0..<size {
        let index = size2 * z + size * y + x
        let mut val = field_copy[index]
        let mut count = 1
        let mut x2 = -1
        while x2 <= 1 {
          let x3 = x2 + x
          if !(x3 < 0 || x3 >= size) {
            let mut y2 = -1
            while y2 <= 1 {
              let y3 = y2 + y
              if !(y3 < 0 || y3 >= size) {
                let mut z2 = -1
                while z2 <= 1 {
                  let z3 = z2 + z
                  if !(z3 < 0 || z3 >= size) {
                    let index2 = size2 * z3 + size * y3 + x3
                    let val2 = field_copy[index2]
                    count += 1
                    val += intensity * (val2 - val) / count.to_double()
                  }
                  z2 += 2
                }
              }
              y2 += 2
            }
          }
          x2 += 2
        }
        field[index] = val
      }
    }
  }
}

///|
/// `reset()`: wipes the field, the normal cache and the palette.
pub fn MarchingCubes::reset(self : MarchingCubes) -> Unit {
  // wipe the normal cache
  for i in 0..<self.size3 {
    self.normal_cache[i * 3] = 0.0
    self.field[i] = 0.0
    self.palette[i * 3 + 2] = 0.0
    self.palette[i * 3 + 1] = 0.0
    self.palette[i * 3] = 0.0
  }
}

///|
/// `update()`: polygonizes the field into the geometry.
pub fn MarchingCubes::update(self : MarchingCubes) -> Unit {
  self.set_count(0)
  // Triangulate. Yeah, this is slow.
  let smin2 = self.size - 2
  let halfsize = self.halfsize
  for z in 1..<smin2 {
    let z_offset = self.size2 * z
    let fz = (z.to_double() - halfsize) / halfsize //+ 1
    for y in 1..<smin2 {
      let y_offset = z_offset + self.size * y
      let fy = (y.to_double() - halfsize) / halfsize //+ 1
      for x in 1..<smin2 {
        let fx = (x.to_double() - halfsize) / halfsize //+ 1
        let q = y_offset + x
        self.polygonize(fx, fy, fz, q, self.isolation) |> ignore
      }
    }
  }
  // set the draw range to only the processed triangles
  self.mesh().geometry.set_draw_range(0, self.count().to_double())
  // update geometry data
  let geometry = self.geometry
  geometry.get_attribute("position").unwrap().set_needs_update(true)
  geometry.get_attribute("normal").unwrap().set_needs_update(true)
  if self.enable_uvs {
    geometry.get_attribute("uv").unwrap().set_needs_update(true)
  }
  if self.enable_colors {
    geometry.get_attribute("color").unwrap().set_needs_update(true)
  }
  // safety check
  if self.count().to_double() / 3.0 > self.max_poly_count.to_double() {
    println(
      "THREE.MarchingCubes: Geometry buffers too small for rendering. Please create an instance with a higher poly count.",
    )
  }
}

///|
/// `edgeTable` (256 entries).
pub let edge_table : FixedArray[Int32] = [
  0, 265, 515, 778, 1030, 1295, 1541, 1804, 2060, 2309, 2575, 2822, 3082, 3331, 3593,
  3840, 400, 153, 915, 666, 1430, 1183, 1941, 1692, 2460, 2197, 2975, 2710, 3482,
  3219, 3993, 3728, 560, 825, 51, 314, 1590, 1855, 1077, 1340, 2620, 2869, 2111,
  2358, 3642, 3891, 3129, 3376, 928, 681, 419, 170, 1958, 1711, 1445, 1196, 2988,
  2725, 2479, 2214, 4010, 3747, 3497, 3232, 1120, 1385, 1635, 1898, 102, 367, 613,
  876, 3180, 3429, 3695, 3942, 2154, 2403, 2665, 2912, 1520, 1273, 2035, 1786, 502,
  255, 1013, 764, 3580, 3317, 4095, 3830, 2554, 2291, 3065, 2800, 1616, 1881, 1107,
  1370, 598, 863, 85, 348, 3676, 3925, 3167, 3414, 2650, 2899, 2137, 2384, 1984,
  1737, 1475, 1226, 966, 719, 453, 204, 4044, 3781, 3535, 3270, 3018, 2755, 2505,
  2240, 2240, 2505, 2755, 3018, 3270, 3535, 3781, 4044, 204, 453, 719, 966, 1226,
  1475, 1737, 1984, 2384, 2137, 2899, 2650, 3414, 3167, 3925, 3676, 348, 85, 863,
  598, 1370, 1107, 1881, 1616, 2800, 3065, 2291, 2554, 3830, 4095, 3317, 3580, 764,
  1013, 255, 502, 1786, 2035, 1273, 1520, 2912, 2665, 2403, 2154, 3942, 3695, 3429,
  3180, 876, 613, 367, 102, 1898, 1635, 1385, 1120, 3232, 3497, 3747, 4010, 2214,
  2479, 2725, 2988, 1196, 1445, 1711, 1958, 170, 419, 681, 928, 3376, 3129, 3891,
  3642, 2358, 2111, 2869, 2620, 1340, 1077, 1855, 1590, 314, 51, 825, 560, 3728,
  3993, 3219, 3482, 2710, 2975, 2197, 2460, 1692, 1941, 1183, 1430, 666, 915, 153,
  400, 3840, 3593, 3331, 3082, 2822, 2575, 2309, 2060, 1804, 1541, 1295, 1030, 778,
  515, 265, 0,
]

///|
/// `triTable` (4096 entries).
pub let tri_table : FixedArray[Int32] = [
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 0, 8, 3, -1, -1,
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 0, 1, 9, -1, -1, -1, -1, -1, -1, -1,
  -1, -1, -1, -1, -1, -1, 1, 8, 3, 9, 8, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
  1, 2, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 0, 8, 3, 1, 2, 10,
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 9, 2, 10, 0, 2, 9, -1, -1, -1, -1, -1,
  -1, -1, -1, -1, -1, 2, 8, 3, 2, 10, 8, 10, 9, 8, -1, -1, -1, -1, -1, -1, -1, 3,
  11, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 0, 11, 2, 8, 11, 0,
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 9, 0, 2, 3, 11, -1, -1, -1, -1, -1,
  -1, -1, -1, -1, -1, 1, 11, 2, 1, 9, 11, 9, 8, 11, -1, -1, -1, -1, -1, -1, -1, 3,
  10, 1, 11, 10, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 0, 10, 1, 0, 8, 10, 8,
  11, 10, -1, -1, -1, -1, -1, -1, -1, 3, 9, 0, 3, 11, 9, 11, 10, 9, -1, -1, -1, -1,
  -1, -1, -1, 9, 8, 10, 10, 8, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 4, 7,
  8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 4, 3, 0, 7, 3, 4, -1, -1,
  -1, -1, -1, -1, -1, -1, -1, -1, 0, 1, 9, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1, -1,
  -1, -1, 4, 1, 9, 4, 7, 1, 7, 3, 1, -1, -1, -1, -1, -1, -1, -1, 1, 2, 10, 8, 4,
  7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 3, 4, 7, 3, 0, 4, 1, 2, 10, -1, -1,
  -1, -1, -1, -1, -1, 9, 2, 10, 9, 0, 2, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1, 2,
  10, 9, 2, 9, 7, 2, 7, 3, 7, 9, 4, -1, -1, -1, -1, 8, 4, 7, 3, 11, 2, -1, -1, -1,
  -1, -1, -1, -1, -1, -1, -1, 11, 4, 7, 11, 2, 4, 2, 0, 4, -1, -1, -1, -1, -1, -1,
  -1, 9, 0, 1, 8, 4, 7, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1, 4, 7, 11, 9, 4, 11,
  9, 11, 2, 9, 2, 1, -1, -1, -1, -1, 3, 10, 1, 3, 11, 10, 7, 8, 4, -1, -1, -1, -1,
  -1, -1, -1, 1, 11, 10, 1, 4, 11, 1, 0, 4, 7, 11, 4, -1, -1, -1, -1, 4, 7, 8, 9,
  0, 11, 9, 11, 10, 11, 0, 3, -1, -1, -1, -1, 4, 7, 11, 4, 11, 9, 9, 11, 10, -1,
  -1, -1, -1, -1, -1, -1, 9, 5, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
  -1, 9, 5, 4, 0, 8, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 0, 5, 4, 1, 5, 0,
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 8, 5, 4, 8, 3, 5, 3, 1, 5, -1, -1, -1,
  -1, -1, -1, -1, 1, 2, 10, 9, 5, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 3, 0,
  8, 1, 2, 10, 4, 9, 5, -1, -1, -1, -1, -1, -1, -1, 5, 2, 10, 5, 4, 2, 4, 0, 2, -1,
  -1, -1, -1, -1, -1, -1, 2, 10, 5, 3, 2, 5, 3, 5, 4, 3, 4, 8, -1, -1, -1, -1, 9,
  5, 4, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 0, 11, 2, 0, 8, 11, 4,
  9, 5, -1, -1, -1, -1, -1, -1, -1, 0, 5, 4, 0, 1, 5, 2, 3, 11, -1, -1, -1, -1, -1,
  -1, -1, 2, 1, 5, 2, 5, 8, 2, 8, 11, 4, 8, 5, -1, -1, -1, -1, 10, 3, 11, 10, 1,
  3, 9, 5, 4, -1, -1, -1, -1, -1, -1, -1, 4, 9, 5, 0, 8, 1, 8, 10, 1, 8, 11, 10,
  -1, -1, -1, -1, 5, 4, 0, 5, 0, 11, 5, 11, 10, 11, 0, 3, -1, -1, -1, -1, 5, 4, 8,
  5, 8, 10, 10, 8, 11, -1, -1, -1, -1, -1, -1, -1, 9, 7, 8, 5, 7, 9, -1, -1, -1,
  -1, -1, -1, -1, -1, -1, -1, 9, 3, 0, 9, 5, 3, 5, 7, 3, -1, -1, -1, -1, -1, -1,
  -1, 0, 7, 8, 0, 1, 7, 1, 5, 7, -1, -1, -1, -1, -1, -1, -1, 1, 5, 3, 3, 5, 7, -1,
  -1, -1, -1, -1, -1, -1, -1, -1, -1, 9, 7, 8, 9, 5, 7, 10, 1, 2, -1, -1, -1, -1,
  -1, -1, -1, 10, 1, 2, 9, 5, 0, 5, 3, 0, 5, 7, 3, -1, -1, -1, -1, 8, 0, 2, 8, 2,
  5, 8, 5, 7, 10, 5, 2, -1, -1, -1, -1, 2, 10, 5, 2, 5, 3, 3, 5, 7, -1, -1, -1, -1,
  -1, -1, -1, 7, 9, 5, 7, 8, 9, 3, 11, 2, -1, -1, -1, -1, -1, -1, -1, 9, 5, 7, 9,
  7, 2, 9, 2, 0, 2, 7, 11, -1, -1, -1, -1, 2, 3, 11, 0, 1, 8, 1, 7, 8, 1, 5, 7, -1,
  -1, -1, -1, 11, 2, 1, 11, 1, 7, 7, 1, 5, -1, -1, -1, -1, -1, -1, -1, 9, 5, 8, 8,
  5, 7, 10, 1, 3, 10, 3, 11, -1, -1, -1, -1, 5, 7, 0, 5, 0, 9, 7, 11, 0, 1, 0, 10,
  11, 10, 0, -1, 11, 10, 0, 11, 0, 3, 10, 5, 0, 8, 0, 7, 5, 7, 0, -1, 11, 10, 5,
  7, 11, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 10, 6, 5, -1, -1, -1, -1, -1,
  -1, -1, -1, -1, -1, -1, -1, -1, 0, 8, 3, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1,
  -1, -1, -1, 9, 0, 1, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 8, 3,
  1, 9, 8, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1, 1, 6, 5, 2, 6, 1, -1, -1, -1, -1,
  -1, -1, -1, -1, -1, -1, 1, 6, 5, 1, 2, 6, 3, 0, 8, -1, -1, -1, -1, -1, -1, -1,
  9, 6, 5, 9, 0, 6, 0, 2, 6, -1, -1, -1, -1, -1, -1, -1, 5, 9, 8, 5, 8, 2, 5, 2,
  6, 3, 2, 8, -1, -1, -1, -1, 2, 3, 11, 10, 6, 5, -1, -1, -1, -1, -1, -1, -1, -1,
  -1, -1, 11, 0, 8, 11, 2, 0, 10, 6, 5, -1, -1, -1, -1, -1, -1, -1, 0, 1, 9, 2, 3,
  11, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1, 5, 10, 6, 1, 9, 2, 9, 11, 2, 9, 8, 11,
  -1, -1, -1, -1, 6, 3, 11, 6, 5, 3, 5, 1, 3, -1, -1, -1, -1, -1, -1, -1, 0, 8, 11,
  0, 11, 5, 0, 5, 1, 5, 11, 6, -1, -1, -1, -1, 3, 11, 6, 0, 3, 6, 0, 6, 5, 0, 5,
  9, -1, -1, -1, -1, 6, 5, 9, 6, 9, 11, 11, 9, 8, -1, -1, -1, -1, -1, -1, -1, 5,
  10, 6, 4, 7, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 4, 3, 0, 4, 7, 3, 6, 5,
  10, -1, -1, -1, -1, -1, -1, -1, 1, 9, 0, 5, 10, 6, 8, 4, 7, -1, -1, -1, -1, -1,
  -1, -1, 10, 6, 5, 1, 9, 7, 1, 7, 3, 7, 9, 4, -1, -1, -1, -1, 6, 1, 2, 6, 5, 1,
  4, 7, 8, -1, -1, -1, -1, -1, -1, -1, 1, 2, 5, 5, 2, 6, 3, 0, 4, 3, 4, 7, -1, -1,
  -1, -1, 8, 4, 7, 9, 0, 5, 0, 6, 5, 0, 2, 6, -1, -1, -1, -1, 7, 3, 9, 7, 9, 4, 3,
  2, 9, 5, 9, 6, 2, 6, 9, -1, 3, 11, 2, 7, 8, 4, 10, 6, 5, -1, -1, -1, -1, -1, -1,
  -1, 5, 10, 6, 4, 7, 2, 4, 2, 0, 2, 7, 11, -1, -1, -1, -1, 0, 1, 9, 4, 7, 8, 2,
  3, 11, 5, 10, 6, -1, -1, -1, -1, 9, 2, 1, 9, 11, 2, 9, 4, 11, 7, 11, 4, 5, 10,
  6, -1, 8, 4, 7, 3, 11, 5, 3, 5, 1, 5, 11, 6, -1, -1, -1, -1, 5, 1, 11, 5, 11, 6,
  1, 0, 11, 7, 11, 4, 0, 4, 11, -1, 0, 5, 9, 0, 6, 5, 0, 3, 6, 11, 6, 3, 8, 4, 7,
  -1, 6, 5, 9, 6, 9, 11, 4, 7, 9, 7, 11, 9, -1, -1, -1, -1, 10, 4, 9, 6, 4, 10, -1,
  -1, -1, -1, -1, -1, -1, -1, -1, -1, 4, 10, 6, 4, 9, 10, 0, 8, 3, -1, -1, -1, -1,
  -1, -1, -1, 10, 0, 1, 10, 6, 0, 6, 4, 0, -1, -1, -1, -1, -1, -1, -1, 8, 3, 1, 8,
  1, 6, 8, 6, 4, 6, 1, 10, -1, -1, -1, -1, 1, 4, 9, 1, 2, 4, 2, 6, 4, -1, -1, -1,
  -1, -1, -1, -1, 3, 0, 8, 1, 2, 9, 2, 4, 9, 2, 6, 4, -1, -1, -1, -1, 0, 2, 4, 4,
  2, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 8, 3, 2, 8, 2, 4, 4, 2, 6, -1, -1,
  -1, -1, -1, -1, -1, 10, 4, 9, 10, 6, 4, 11, 2, 3, -1, -1, -1, -1, -1, -1, -1, 0,
  8, 2, 2, 8, 11, 4, 9, 10, 4, 10, 6, -1, -1, -1, -1, 3, 11, 2, 0, 1, 6, 0, 6, 4,
  6, 1, 10, -1, -1, -1, -1, 6, 4, 1, 6, 1, 10, 4, 8, 1, 2, 1, 11, 8, 11, 1, -1, 9,
  6, 4, 9, 3, 6, 9, 1, 3, 11, 6, 3, -1, -1, -1, -1, 8, 11, 1, 8, 1, 0, 11, 6, 1,
  9, 1, 4, 6, 4, 1, -1, 3, 11, 6, 3, 6, 0, 0, 6, 4, -1, -1, -1, -1, -1, -1, -1, 6,
  4, 8, 11, 6, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 7, 10, 6, 7, 8, 10, 8,
  9, 10, -1, -1, -1, -1, -1, -1, -1, 0, 7, 3, 0, 10, 7, 0, 9, 10, 6, 7, 10, -1, -1,
  -1, -1, 10, 6, 7, 1, 10, 7, 1, 7, 8, 1, 8, 0, -1, -1, -1, -1, 10, 6, 7, 10, 7,
  1, 1, 7, 3, -1, -1, -1, -1, -1, -1, -1, 1, 2, 6, 1, 6, 8, 1, 8, 9, 8, 6, 7, -1,
  -1, -1, -1, 2, 6, 9, 2, 9, 1, 6, 7, 9, 0, 9, 3, 7, 3, 9, -1, 7, 8, 0, 7, 0, 6,
  6, 0, 2, -1, -1, -1, -1, -1, -1, -1, 7, 3, 2, 6, 7, 2, -1, -1, -1, -1, -1, -1,
  -1, -1, -1, -1, 2, 3, 11, 10, 6, 8, 10, 8, 9, 8, 6, 7, -1, -1, -1, -1, 2, 0, 7,
  2, 7, 11, 0, 9, 7, 6, 7, 10, 9, 10, 7, -1, 1, 8, 0, 1, 7, 8, 1, 10, 7, 6, 7, 10,
  2, 3, 11, -1, 11, 2, 1, 11, 1, 7, 10, 6, 1, 6, 7, 1, -1, -1, -1, -1, 8, 9, 6, 8,
  6, 7, 9, 1, 6, 11, 6, 3, 1, 3, 6, -1, 0, 9, 1, 11, 6, 7, -1, -1, -1, -1, -1, -1,
  -1, -1, -1, -1, 7, 8, 0, 7, 0, 6, 3, 11, 0, 11, 6, 0, -1, -1, -1, -1, 7, 11, 6,
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 7, 6, 11, -1, -1, -1, -1, -1,
  -1, -1, -1, -1, -1, -1, -1, -1, 3, 0, 8, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1,
  -1, -1, -1, 0, 1, 9, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 8, 1, 9,
  8, 3, 1, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1, 10, 1, 2, 6, 11, 7, -1, -1, -1,
  -1, -1, -1, -1, -1, -1, -1, 1, 2, 10, 3, 0, 8, 6, 11, 7, -1, -1, -1, -1, -1, -1,
  -1, 2, 9, 0, 2, 10, 9, 6, 11, 7, -1, -1, -1, -1, -1, -1, -1, 6, 11, 7, 2, 10, 3,
  10, 8, 3, 10, 9, 8, -1, -1, -1, -1, 7, 2, 3, 6, 2, 7, -1, -1, -1, -1, -1, -1, -1,
  -1, -1, -1, 7, 0, 8, 7, 6, 0, 6, 2, 0, -1, -1, -1, -1, -1, -1, -1, 2, 7, 6, 2,
  3, 7, 0, 1, 9, -1, -1, -1, -1, -1, -1, -1, 1, 6, 2, 1, 8, 6, 1, 9, 8, 8, 7, 6,
  -1, -1, -1, -1, 10, 7, 6, 10, 1, 7, 1, 3, 7, -1, -1, -1, -1, -1, -1, -1, 10, 7,
  6, 1, 7, 10, 1, 8, 7, 1, 0, 8, -1, -1, -1, -1, 0, 3, 7, 0, 7, 10, 0, 10, 9, 6,
  10, 7, -1, -1, -1, -1, 7, 6, 10, 7, 10, 8, 8, 10, 9, -1, -1, -1, -1, -1, -1, -1,
  6, 8, 4, 11, 8, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 3, 6, 11, 3, 0, 6, 0,
  4, 6, -1, -1, -1, -1, -1, -1, -1, 8, 6, 11, 8, 4, 6, 9, 0, 1, -1, -1, -1, -1, -1,
  -1, -1, 9, 4, 6, 9, 6, 3, 9, 3, 1, 11, 3, 6, -1, -1, -1, -1, 6, 8, 4, 6, 11, 8,
  2, 10, 1, -1, -1, -1, -1, -1, -1, -1, 1, 2, 10, 3, 0, 11, 0, 6, 11, 0, 4, 6, -1,
  -1, -1, -1, 4, 11, 8, 4, 6, 11, 0, 2, 9, 2, 10, 9, -1, -1, -1, -1, 10, 9, 3, 10,
  3, 2, 9, 4, 3, 11, 3, 6, 4, 6, 3, -1, 8, 2, 3, 8, 4, 2, 4, 6, 2, -1, -1, -1, -1,
  -1, -1, -1, 0, 4, 2, 4, 6, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 9, 0,
  2, 3, 4, 2, 4, 6, 4, 3, 8, -1, -1, -1, -1, 1, 9, 4, 1, 4, 2, 2, 4, 6, -1, -1, -1,
  -1, -1, -1, -1, 8, 1, 3, 8, 6, 1, 8, 4, 6, 6, 10, 1, -1, -1, -1, -1, 10, 1, 0,
  10, 0, 6, 6, 0, 4, -1, -1, -1, -1, -1, -1, -1, 4, 6, 3, 4, 3, 8, 6, 10, 3, 0, 3,
  9, 10, 9, 3, -1, 10, 9, 4, 6, 10, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 4,
  9, 5, 7, 6, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 0, 8, 3, 4, 9, 5, 11, 7,
  6, -1, -1, -1, -1, -1, -1, -1, 5, 0, 1, 5, 4, 0, 7, 6, 11, -1, -1, -1, -1, -1,
  -1, -1, 11, 7, 6, 8, 3, 4, 3, 5, 4, 3, 1, 5, -1, -1, -1, -1, 9, 5, 4, 10, 1, 2,
  7, 6, 11, -1, -1, -1, -1, -1, -1, -1, 6, 11, 7, 1, 2, 10, 0, 8, 3, 4, 9, 5, -1,
  -1, -1, -1, 7, 6, 11, 5, 4, 10, 4, 2, 10, 4, 0, 2, -1, -1, -1, -1, 3, 4, 8, 3,
  5, 4, 3, 2, 5, 10, 5, 2, 11, 7, 6, -1, 7, 2, 3, 7, 6, 2, 5, 4, 9, -1, -1, -1, -1,
  -1, -1, -1, 9, 5, 4, 0, 8, 6, 0, 6, 2, 6, 8, 7, -1, -1, -1, -1, 3, 6, 2, 3, 7,
  6, 1, 5, 0, 5, 4, 0, -1, -1, -1, -1, 6, 2, 8, 6, 8, 7, 2, 1, 8, 4, 8, 5, 1, 5,
  8, -1, 9, 5, 4, 10, 1, 6, 1, 7, 6, 1, 3, 7, -1, -1, -1, -1, 1, 6, 10, 1, 7, 6,
  1, 0, 7, 8, 7, 0, 9, 5, 4, -1, 4, 0, 10, 4, 10, 5, 0, 3, 10, 6, 10, 7, 3, 7, 10,
  -1, 7, 6, 10, 7, 10, 8, 5, 4, 10, 4, 8, 10, -1, -1, -1, -1, 6, 9, 5, 6, 11, 9,
  11, 8, 9, -1, -1, -1, -1, -1, -1, -1, 3, 6, 11, 0, 6, 3, 0, 5, 6, 0, 9, 5, -1,
  -1, -1, -1, 0, 11, 8, 0, 5, 11, 0, 1, 5, 5, 6, 11, -1, -1, -1, -1, 6, 11, 3, 6,
  3, 5, 5, 3, 1, -1, -1, -1, -1, -1, -1, -1, 1, 2, 10, 9, 5, 11, 9, 11, 8, 11, 5,
  6, -1, -1, -1, -1, 0, 11, 3, 0, 6, 11, 0, 9, 6, 5, 6, 9, 1, 2, 10, -1, 11, 8, 5,
  11, 5, 6, 8, 0, 5, 10, 5, 2, 0, 2, 5, -1, 6, 11, 3, 6, 3, 5, 2, 10, 3, 10, 5, 3,
  -1, -1, -1, -1, 5, 8, 9, 5, 2, 8, 5, 6, 2, 3, 8, 2, -1, -1, -1, -1, 9, 5, 6, 9,
  6, 0, 0, 6, 2, -1, -1, -1, -1, -1, -1, -1, 1, 5, 8, 1, 8, 0, 5, 6, 8, 3, 8, 2,
  6, 2, 8, -1, 1, 5, 6, 2, 1, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 3, 6,
  1, 6, 10, 3, 8, 6, 5, 6, 9, 8, 9, 6, -1, 10, 1, 0, 10, 0, 6, 9, 5, 0, 5, 6, 0,
  -1, -1, -1, -1, 0, 3, 8, 5, 6, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 10,
  5, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 11, 5, 10, 7, 5, 11,
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 11, 5, 10, 11, 7, 5, 8, 3, 0, -1, -1, -1,
  -1, -1, -1, -1, 5, 11, 7, 5, 10, 11, 1, 9, 0, -1, -1, -1, -1, -1, -1, -1, 10, 7,
  5, 10, 11, 7, 9, 8, 1, 8, 3, 1, -1, -1, -1, -1, 11, 1, 2, 11, 7, 1, 7, 5, 1, -1,
  -1, -1, -1, -1, -1, -1, 0, 8, 3, 1, 2, 7, 1, 7, 5, 7, 2, 11, -1, -1, -1, -1, 9,
  7, 5, 9, 2, 7, 9, 0, 2, 2, 11, 7, -1, -1, -1, -1, 7, 5, 2, 7, 2, 11, 5, 9, 2, 3,
  2, 8, 9, 8, 2, -1, 2, 5, 10, 2, 3, 5, 3, 7, 5, -1, -1, -1, -1, -1, -1, -1, 8, 2,
  0, 8, 5, 2, 8, 7, 5, 10, 2, 5, -1, -1, -1, -1, 9, 0, 1, 5, 10, 3, 5, 3, 7, 3, 10,
  2, -1, -1, -1, -1, 9, 8, 2, 9, 2, 1, 8, 7, 2, 10, 2, 5, 7, 5, 2, -1, 1, 3, 5, 3,
  7, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 0, 8, 7, 0, 7, 1, 1, 7, 5, -1, -1,
  -1, -1, -1, -1, -1, 9, 0, 3, 9, 3, 5, 5, 3, 7, -1, -1, -1, -1, -1, -1, -1, 9, 8,
  7, 5, 9, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 5, 8, 4, 5, 10, 8, 10, 11,
  8, -1, -1, -1, -1, -1, -1, -1, 5, 0, 4, 5, 11, 0, 5, 10, 11, 11, 3, 0, -1, -1,
  -1, -1, 0, 1, 9, 8, 4, 10, 8, 10, 11, 10, 4, 5, -1, -1, -1, -1, 10, 11, 4, 10,
  4, 5, 11, 3, 4, 9, 4, 1, 3, 1, 4, -1, 2, 5, 1, 2, 8, 5, 2, 11, 8, 4, 5, 8, -1,
  -1, -1, -1, 0, 4, 11, 0, 11, 3, 4, 5, 11, 2, 11, 1, 5, 1, 11, -1, 0, 2, 5, 0, 5,
  9, 2, 11, 5, 4, 5, 8, 11, 8, 5, -1, 9, 4, 5, 2, 11, 3, -1, -1, -1, -1, -1, -1,
  -1, -1, -1, -1, 2, 5, 10, 3, 5, 2, 3, 4, 5, 3, 8, 4, -1, -1, -1, -1, 5, 10, 2,
  5, 2, 4, 4, 2, 0, -1, -1, -1, -1, -1, -1, -1, 3, 10, 2, 3, 5, 10, 3, 8, 5, 4, 5,
  8, 0, 1, 9, -1, 5, 10, 2, 5, 2, 4, 1, 9, 2, 9, 4, 2, -1, -1, -1, -1, 8, 4, 5, 8,
  5, 3, 3, 5, 1, -1, -1, -1, -1, -1, -1, -1, 0, 4, 5, 1, 0, 5, -1, -1, -1, -1, -1,
  -1, -1, -1, -1, -1, 8, 4, 5, 8, 5, 3, 9, 0, 5, 0, 3, 5, -1, -1, -1, -1, 9, 4, 5,
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 4, 11, 7, 4, 9, 11, 9, 10,
  11, -1, -1, -1, -1, -1, -1, -1, 0, 8, 3, 4, 9, 7, 9, 11, 7, 9, 10, 11, -1, -1,
  -1, -1, 1, 10, 11, 1, 11, 4, 1, 4, 0, 7, 4, 11, -1, -1, -1, -1, 3, 1, 4, 3, 4,
  8, 1, 10, 4, 7, 4, 11, 10, 11, 4, -1, 4, 11, 7, 9, 11, 4, 9, 2, 11, 9, 1, 2, -1,
  -1, -1, -1, 9, 7, 4, 9, 11, 7, 9, 1, 11, 2, 11, 1, 0, 8, 3, -1, 11, 7, 4, 11, 4,
  2, 2, 4, 0, -1, -1, -1, -1, -1, -1, -1, 11, 7, 4, 11, 4, 2, 8, 3, 4, 3, 2, 4, -1,
  -1, -1, -1, 2, 9, 10, 2, 7, 9, 2, 3, 7, 7, 4, 9, -1, -1, -1, -1, 9, 10, 7, 9, 7,
  4, 10, 2, 7, 8, 7, 0, 2, 0, 7, -1, 3, 7, 10, 3, 10, 2, 7, 4, 10, 1, 10, 0, 4, 0,
  10, -1, 1, 10, 2, 8, 7, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 4, 9, 1, 4,
  1, 7, 7, 1, 3, -1, -1, -1, -1, -1, -1, -1, 4, 9, 1, 4, 1, 7, 0, 8, 1, 8, 7, 1,
  -1, -1, -1, -1, 4, 0, 3, 7, 4, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 4, 8,
  7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 9, 10, 8, 10, 11, 8, -1,
  -1, -1, -1, -1, -1, -1, -1, -1, -1, 3, 0, 9, 3, 9, 11, 11, 9, 10, -1, -1, -1, -1,
  -1, -1, -1, 0, 1, 10, 0, 10, 8, 8, 10, 11, -1, -1, -1, -1, -1, -1, -1, 3, 1, 10,
  11, 3, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 2, 11, 1, 11, 9, 9, 11, 8,
  -1, -1, -1, -1, -1, -1, -1, 3, 0, 9, 3, 9, 11, 1, 2, 9, 2, 11, 9, -1, -1, -1, -1,
  0, 2, 11, 8, 0, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 3, 2, 11, -1, -1, -1,
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 2, 3, 8, 2, 8, 10, 10, 8, 9, -1, -1, -1,
  -1, -1, -1, -1, 9, 10, 2, 0, 9, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 2, 3,
  8, 2, 8, 10, 0, 1, 8, 1, 10, 8, -1, -1, -1, -1, 1, 10, 2, -1, -1, -1, -1, -1, -1,
  -1, -1, -1, -1, -1, -1, -1, 1, 3, 8, 9, 1, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1,
  -1, 0, 9, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 0, 3, 8, -1, -1,
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
  -1, -1, -1, -1, -1, -1, -1,
]
