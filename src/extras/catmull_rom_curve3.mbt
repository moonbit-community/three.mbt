// Upstream src/extras/curves/CatmullRomCurve3.js.

///|
/// Upstream `CubicPoly`, an optimized Catmull-Rom solution.
priv struct CatmullRomCubicPoly {
  mut c0 : Double
  mut c1 : Double
  mut c2 : Double
  mut c3 : Double
}

///|
fn CatmullRomCubicPoly::new() -> CatmullRomCubicPoly {
  { c0: 0.0, c1: 0.0, c2: 0.0, c3: 0.0, }
}

///|
fn CatmullRomCubicPoly::init(
  self : CatmullRomCubicPoly,
  x0 : Double,
  x1 : Double,
  t0 : Double,
  t1 : Double,
) -> Unit {
  self.c0 = x0
  self.c1 = t0
  self.c2 = -3.0 * x0 + 3.0 * x1 - 2.0 * t0 - t1
  self.c3 = 2.0 * x0 - 2.0 * x1 + t0 + t1
}

///|
fn CatmullRomCubicPoly::init_catmull_rom(
  self : CatmullRomCubicPoly,
  x0 : Double,
  x1 : Double,
  x2 : Double,
  x3 : Double,
  tension : Double,
) -> Unit {
  self.init(x1, x2, tension * (x2 - x0), tension * (x3 - x1))
}

///|
fn CatmullRomCubicPoly::init_nonuniform_catmull_rom(
  self : CatmullRomCubicPoly,
  x0 : Double,
  x1 : Double,
  x2 : Double,
  x3 : Double,
  dt0 : Double,
  dt1 : Double,
  dt2 : Double,
) -> Unit {
  // compute tangents when parameterized in [t1,t2]
  let mut t1 = (x1 - x0) / dt0 - (x2 - x0) / (dt0 + dt1) + (x2 - x1) / dt1
  let mut t2 = (x2 - x1) / dt1 - (x3 - x1) / (dt1 + dt2) + (x3 - x2) / dt2
  // rescale tangents for parametrization in [0,1]
  t1 *= dt1
  t2 *= dt1
  self.init(x1, x2, t1, t2)
}

///|
fn CatmullRomCubicPoly::calc(self : CatmullRomCubicPoly, t : Double) -> Double {
  let t2 = t * t
  let t3 = t2 * t
  self.c0 + self.c1 * t + self.c2 * t2 + self.c3 * t3
}

///|
let _catmull_rom_tmp : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _catmull_rom_tmp2 : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _catmull_rom_px : CatmullRomCubicPoly = CatmullRomCubicPoly::new()

///|
let _catmull_rom_py : CatmullRomCubicPoly = CatmullRomCubicPoly::new()

///|
let _catmull_rom_pz : CatmullRomCubicPoly = CatmullRomCubicPoly::new()

///|
extern "js" fn catmull_rom_math_pow(base : Double, exponent : Double) -> Double = "Math.pow"

///|
/// JS `%`.
extern "js" fn catmull_rom_rem(a : Double, b : Double) -> Double = "(a, b) => a % b"

///|
#external
pub type CatmullRomCurve3

///|
pub(all) struct CatmullRomCurve3Data {
  mut points : Array[@math.Vector3]
  mut closed : Bool
  mut curve_type : String
  mut tension : Double
}

///|
pub fn CatmullRomCurve3::new(
  points~ : Array[@math.Vector3] = [],
  closed~ : Bool = false,
  curve_type~ : String = "centripetal",
  tension~ : Double = 0.5,
) -> Curve[@math.Vector3] {
  curve_make(
    "CatmullRomCurve3",
    CatmullRom({ points, closed, curve_type, tension, }),
  )
}

///|
fn catmull_rom_required(point : @math.Vector3?) -> @math.Vector3 {
  match point {
    Some(point) => point
    None => abort("CatmullRomCurve3: point index out of range")
  }
}

///|
/// Points are `undefined` where the index leaves the array, and stay unread for an
/// unknown `curveType`, which keeps the previous polynomials.
fn[V : CurveVector] CatmullRomCurve3Data::get_point(
  self : CatmullRomCurve3Data,
  t : Double,
  point : V,
) -> V {
  let points = self.points
  let l = points.length().to_double()
  let p = (l - (if self.closed { 0.0 } else { 1.0 })) * t
  let mut int_point = curve_math_floor(p)
  let mut weight = p - int_point
  if self.closed {
    int_point += if int_point > 0.0 {
      0.0
    } else {
      (curve_math_floor(int_point.abs() / l) + 1.0) * l
    }
  } else if weight == 0.0 && int_point == l - 1.0 {
    int_point = l - 2.0
    weight = 1.0
  }
  // 4 points (p1 & p2 defined below)
  let p0 = if self.closed || int_point > 0.0 {
    curve_array_at(points, catmull_rom_rem(int_point - 1.0, l))
  } else {
    // extrapolate first point
    Some(
      _catmull_rom_tmp2
      .sub_vectors(
        catmull_rom_required(curve_array_at(points, 0.0)),
        catmull_rom_required(curve_array_at(points, 1.0)),
      )
      .add(points[0]),
    )
  }
  let p1 = curve_array_at(points, catmull_rom_rem(int_point, l))
  let p2 = curve_array_at(points, catmull_rom_rem(int_point + 1.0, l))
  let p3 = if self.closed || int_point + 2.0 < l {
    curve_array_at(points, catmull_rom_rem(int_point + 2.0, l))
  } else {
    // extrapolate last point
    Some(
      _catmull_rom_tmp
      .sub_vectors(
        catmull_rom_required(curve_array_at(points, l - 1.0)),
        catmull_rom_required(curve_array_at(points, l - 2.0)),
      )
      .add(catmull_rom_required(curve_array_at(points, l - 1.0))),
    )
  }
  if self.curve_type == "centripetal" || self.curve_type == "chordal" {
    // init Centripetal / Chordal Catmull-Rom
    let p0 = catmull_rom_required(p0)
    let p1 = catmull_rom_required(p1)
    let p2 = catmull_rom_required(p2)
    let p3 = catmull_rom_required(p3)
    let pow = if self.curve_type == "chordal" { 0.5 } else { 0.25 }
    let mut dt0 = catmull_rom_math_pow(p0.distance_to_squared(p1), pow)
    let mut dt1 = catmull_rom_math_pow(p1.distance_to_squared(p2), pow)
    let mut dt2 = catmull_rom_math_pow(p2.distance_to_squared(p3), pow)
    // safety check for repeated points
    if dt1 < 1.0e-4 {
      dt1 = 1.0
    }
    if dt0 < 1.0e-4 {
      dt0 = dt1
    }
    if dt2 < 1.0e-4 {
      dt2 = dt1
    }
    _catmull_rom_px.init_nonuniform_catmull_rom(
      p0.x,
      p1.x,
      p2.x,
      p3.x,
      dt0,
      dt1,
      dt2,
    )
    _catmull_rom_py.init_nonuniform_catmull_rom(
      p0.y,
      p1.y,
      p2.y,
      p3.y,
      dt0,
      dt1,
      dt2,
    )
    _catmull_rom_pz.init_nonuniform_catmull_rom(
      p0.z,
      p1.z,
      p2.z,
      p3.z,
      dt0,
      dt1,
      dt2,
    )
  } else if self.curve_type == "catmullrom" {
    let p0 = catmull_rom_required(p0)
    let p1 = catmull_rom_required(p1)
    let p2 = catmull_rom_required(p2)
    let p3 = catmull_rom_required(p3)
    _catmull_rom_px.init_catmull_rom(p0.x, p1.x, p2.x, p3.x, self.tension)
    _catmull_rom_py.init_catmull_rom(p0.y, p1.y, p2.y, p3.y, self.tension)
    _catmull_rom_pz.init_catmull_rom(p0.z, p1.z, p2.z, p3.z, self.tension)
  }
  point.set_by_axis(axis => {
    match axis {
      0 => _catmull_rom_px.calc(weight)
      1 => _catmull_rom_py.calc(weight)
      _ => _catmull_rom_pz.calc(weight)
    }
  })
}

///|
fn CatmullRomCurve3Data::copy(
  self : CatmullRomCurve3Data,
  source : CatmullRomCurve3Data,
) -> Unit {
  self.points = source.points.map(curve_clone_vector)
  self.closed = source.closed
  self.curve_type = source.curve_type
  self.tension = source.tension
  curve_null_copy(source, self)
}

///|
fn CatmullRomCurve3Data::to_json(
  self : CatmullRomCurve3Data,
  data : Map[String, Json],
) -> Unit {
  data["points"] = curve_json_points(self.points)
  data["closed"] = Json::boolean(self.closed)
  data["curveType"] = Json::string(self.curve_type)
  data["tension"] = curve_json_field(self, "tension", self.tension)
}

///|
fn CatmullRomCurve3Data::from_json(
  self : CatmullRomCurve3Data,
  json : Json,
) -> Unit {
  self.points = curve_json_array(json, "points").map(point => {
    curve_json_vector_from(@math.Vector3::new(0.0, 0.0, 0.0), point)
  })
  self.closed = curve_json_bool(json, "closed")
  self.curve_type = curve_json_string(json, "curveType")
  self.tension = curve_json_double_of(self, json, "tension")
}
