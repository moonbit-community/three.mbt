// Upstream examples/jsm/utils/GeometryUtils.js: point sequences of Hilbert curves and
// the Gosper curve.

///|
extern "js" fn geometry_utils_cos(x : Double) -> Double = "Math.cos"

///|
extern "js" fn geometry_utils_sin(x : Double) -> Double = "Math.sin"

///|
/// `hilbert2D( center, size, iterations, v0, v1, v2, v3 )`: the points of a 2D Hilbert
/// curve in the xz plane.
pub fn hilbert2d(
  center? : @math.Vector3,
  size~ : Double = 10.0,
  iterations~ : Int32 = 1,
  v0~ : Int32 = 0,
  v1~ : Int32 = 1,
  v2~ : Int32 = 2,
  v3~ : Int32 = 3,
) -> Array[@math.Vector3] {
  let center = match center {
    Some(center) => center
    None => @math.Vector3::new(0.0, 0.0, 0.0)
  }
  let half = size / 2.0
  let vec_s = [
    @math.Vector3::new(center.x - half, center.y, center.z - half),
    @math.Vector3::new(center.x - half, center.y, center.z + half),
    @math.Vector3::new(center.x + half, center.y, center.z + half),
    @math.Vector3::new(center.x + half, center.y, center.z - half),
  ]
  let vec = [vec_s[v0], vec_s[v1], vec_s[v2], vec_s[v3]]
  // Recurse iterations
  let iterations = iterations - 1
  if 0 <= iterations {
    return [
      ..hilbert2d(center=vec[0], size=half, iterations~, v0~, v1=v3, v2~, v3=v1),
      ..hilbert2d(center=vec[1], size=half, iterations~, v0~, v1~, v2~, v3~),
      ..hilbert2d(center=vec[2], size=half, iterations~, v0~, v1~, v2~, v3~),
      ..hilbert2d(center=vec[3], size=half, iterations~, v0=v2, v1~, v2=v0, v3~),
    ]
  }
  // Return complete Hilbert Curve.
  vec
}

///|
/// `hilbert3D( center, size, iterations, v0, ..., v7 )`: the points of a 3D Hilbert
/// curve.
pub fn hilbert3d(
  center? : @math.Vector3,
  size~ : Double = 10.0,
  iterations~ : Int32 = 1,
  v0~ : Int32 = 0,
  v1~ : Int32 = 1,
  v2~ : Int32 = 2,
  v3~ : Int32 = 3,
  v4~ : Int32 = 4,
  v5~ : Int32 = 5,
  v6~ : Int32 = 6,
  v7~ : Int32 = 7,
) -> Array[@math.Vector3] {
  let center = match center {
    Some(center) => center
    None => @math.Vector3::new(0.0, 0.0, 0.0)
  }
  // Default Vars
  let half = size / 2.0
  let vec_s = [
    @math.Vector3::new(center.x - half, center.y + half, center.z - half),
    @math.Vector3::new(center.x - half, center.y + half, center.z + half),
    @math.Vector3::new(center.x - half, center.y - half, center.z + half),
    @math.Vector3::new(center.x - half, center.y - half, center.z - half),
    @math.Vector3::new(center.x + half, center.y - half, center.z - half),
    @math.Vector3::new(center.x + half, center.y - half, center.z + half),
    @math.Vector3::new(center.x + half, center.y + half, center.z + half),
    @math.Vector3::new(center.x + half, center.y + half, center.z - half),
  ]
  let vec = [
    vec_s[v0],
    vec_s[v1],
    vec_s[v2],
    vec_s[v3],
    vec_s[v4],
    vec_s[v5],
    vec_s[v6],
    vec_s[v7],
  ]
  // Recurse iterations
  let iterations = iterations - 1
  if iterations >= 0 {
    let h = fn(
      c : @math.Vector3,
      a0 : Int32,
      a1 : Int32,
      a2 : Int32,
      a3 : Int32,
      a4 : Int32,
      a5 : Int32,
      a6 : Int32,
      a7 : Int32,
    ) {
      hilbert3d(
        center=c,
        size=half,
        iterations~,
        v0=a0,
        v1=a1,
        v2=a2,
        v3=a3,
        v4=a4,
        v5=a5,
        v6=a6,
        v7=a7,
      )
    }
    return [
      ..h(vec[0], v0, v3, v4, v7, v6, v5, v2, v1),
      ..h(vec[1], v0, v7, v6, v1, v2, v5, v4, v3),
      ..h(vec[2], v0, v7, v6, v1, v2, v5, v4, v3),
      ..h(vec[3], v2, v3, v0, v1, v6, v7, v4, v5),
      ..h(vec[4], v2, v3, v0, v1, v6, v7, v4, v5),
      ..h(vec[5], v4, v3, v2, v5, v6, v1, v0, v7),
      ..h(vec[6], v4, v3, v2, v5, v6, v1, v0, v7),
      ..h(vec[7], v6, v5, v2, v1, v0, v3, v4, v7),
    ]
  }
  // Return complete Hilbert Curve.
  vec
}

///|
/// `gosper( size )`: the Gosper curve as a flat `[ x, y, z, ... ]` array.
pub fn gosper(size~ : Double = 1.0) -> Array[Double] {
  fn fractalize(
    axiom : String,
    steps : Int32,
    rules : Map[Char, String],
  ) -> String {
    let mut output = ""
    let mut input = axiom
    let il = steps
    let mut i = 0
    while (if 0 <= il { i < il } else { i > il }) {
      let buffer = StringBuilder()
      for char in input {
        match rules.get(char) {
          Some(rule) => buffer.write_string(rule)
          None => buffer.write_char(char)
        }
      }
      output = buffer.to_string()
      input = output
      if 0 <= il {
        i += 1
      } else {
        i -= 1
      }
    }
    output
  }

  fn to_points(
    fractal : String,
    size : Double,
    angle_step : Double,
  ) -> Array[Double] {
    let mut curr_x = 0.0
    let mut curr_y = 0.0
    let mut angle = 0.0
    let path = [0.0, 0.0, 0.0]
    for char in fractal {
      if char == '+' {
        angle += angle_step
      } else if char == '-' {
        angle -= angle_step
      } else if char == 'F' {
        curr_x += size * geometry_utils_cos(angle)
        curr_y += -size * geometry_utils_sin(angle)
        path.push(curr_x)
        path.push(curr_y)
        path.push(0.0)
      }
    }
    path
  }

  //
  let gosper = fractalize(
    "A",
    4,
    Map([('A', "A+BF++BF-FA--FAFA-BF+"), ('B', "-FA+BFBF++BF+FA--FA-B")]),
  )
  to_points(gosper, size, 3.141592653589793 / 3.0) // 60 degrees
}
