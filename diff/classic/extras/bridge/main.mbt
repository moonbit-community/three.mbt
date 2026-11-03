///|
using @core {type JsValue}

///|
using @math {type Vector2, type Vector3}

///|
using @extras {type Curve}

///|
extern "js" fn js_kind(v : JsValue) -> Int =
  #|(v) => v === null || v === undefined ? 0 : typeof v === 'number' ? 1 : typeof v === 'string' ? 2 : typeof v === 'boolean' ? 3 : Array.isArray(v) ? 4 : 5

///|
extern "js" fn js_keys(v : JsValue) -> Array[String] = "(v) => Object.keys(v)"

///|
fn js_to_json(v : JsValue) -> Json {
  match js_kind(v) {
    0 => Json::null()
    1 => Json::number(v.cast())
    2 => Json::string(v.cast())
    3 => Json::boolean(v.cast())
    4 => {
      let a : Array[JsValue] = v.cast()
      Json::array(a.map(js_to_json))
    }
    _ => {
      let m : Map[String, Json] = Map([])
      for k in js_keys(v) {
        m[k] = js_to_json(v.get(k))
      }
      Json::object(m)
    }
  }
}

///|
fn json_to_js(j : Json) -> JsValue {
  match j {
    Null => JsValue::null()
    True => JsValue::of(true)
    False => JsValue::of(false)
    Number(n, ..) => JsValue::of(n)
    String(s) => JsValue::of(s)
    Array(a) => JsValue::of(a.map(json_to_js))
    Object(m) => {
      let o = JsValue::object()
      for k, v in m {
        o.set(k, json_to_js(v))
      }
      o
    }
  }
}

///|
fn v2(a : JsValue) -> Vector2 {
  let a : Array[Double] = a.cast()
  Vector2::new(a[0], a[1])
}

///|
fn v3(a : JsValue) -> Vector3 {
  let a : Array[Double] = a.cast()
  Vector3::new(a[0], a[1], a[2])
}

///|
fn arr(a : JsValue) -> Array[JsValue] {
  a.cast()
}

///|
fn[T : @extras.PathLike] apply_path_ops(p : T, ops : JsValue, arc : (T, Array[JsValue]) -> Unit) -> Unit {
  for op in arr(ops) {
    let o = arr(op)
    let n = (i : Int) => { let d : Double = o[i].cast(); d }
    let name : String = o[0].cast()
    match name {
      "moveTo" => ignore(p.move_to(n(1), n(2)))
      "lineTo" => ignore(p.line_to(n(1), n(2)))
      "quad" => ignore(p.quadratic_curve_to(n(1), n(2), n(3), n(4)))
      "bez" => ignore(p.bezier_curve_to(n(1), n(2), n(3), n(4), n(5), n(6)))
      "spline" => ignore(p.spline_thru(arr(o[1]).map(v2)))
      "setFromPoints" => ignore(p.set_from_points(arr(o[1]).map(v2)))
      "closePath" => ignore(p.close_path())
      _ => arc(p, o)
    }
  }
}

///|
fn b(v : JsValue) -> Bool {
  v.cast()
}

///|
fn d(v : JsValue) -> Double {
  v.cast()
}

///|
fn make_path(spec : JsValue) -> @extras.Path {
  let p = match js_kind(spec.get("points")) {
    4 => @extras.Path::new(points=arr(spec.get("points")).map(v2))
    _ => @extras.Path::new()
  }
  apply_path_ops(p, spec.get("ops"), (p, o) => {
    let name : String = o[0].cast()
    match name {
      "arc" => ignore(p.arc(d(o[1]), d(o[2]), d(o[3]), d(o[4]), d(o[5]), a_clockwise=b(o[6])))
      "absarc" => ignore(p.absarc(d(o[1]), d(o[2]), d(o[3]), d(o[4]), d(o[5]), a_clockwise=b(o[6])))
      "ellipse" => ignore(p.ellipse(d(o[1]), d(o[2]), d(o[3]), d(o[4]), d(o[5]), d(o[6]), a_clockwise=b(o[7]), a_rotation=d(o[8])))
      "absellipse" => ignore(p.absellipse(d(o[1]), d(o[2]), d(o[3]), d(o[4]), d(o[5]), d(o[6]), a_clockwise=b(o[7]), a_rotation=d(o[8])))
      _ => abort("op " + name)
    }
  })
  if b(spec.get("autoClose")) { p.set_auto_close(true) }
  p
}

///|
fn make_shape(spec : JsValue) -> @extras.Shape {
  let p = match js_kind(spec.get("points")) {
    4 => @extras.Shape::new(points=arr(spec.get("points")).map(v2))
    _ => @extras.Shape::new()
  }
  apply_path_ops(p, spec.get("ops"), (p, o) => {
    let name : String = o[0].cast()
    match name {
      "arc" => ignore(p.arc(d(o[1]), d(o[2]), d(o[3]), d(o[4]), d(o[5]), a_clockwise=b(o[6])))
      "absarc" => ignore(p.absarc(d(o[1]), d(o[2]), d(o[3]), d(o[4]), d(o[5]), a_clockwise=b(o[6])))
      "ellipse" => ignore(p.ellipse(d(o[1]), d(o[2]), d(o[3]), d(o[4]), d(o[5]), d(o[6]), a_clockwise=b(o[7]), a_rotation=d(o[8])))
      "absellipse" => ignore(p.absellipse(d(o[1]), d(o[2]), d(o[3]), d(o[4]), d(o[5]), d(o[6]), a_clockwise=b(o[7]), a_rotation=d(o[8])))
      _ => abort("op " + name)
    }
  })
  if b(spec.get("autoClose")) { p.set_auto_close(true) }
  for h in arr(spec.get("holes")) {
    p.holes().push(make_path(h))
  }
  p
}

///|
pub fn build2(spec : JsValue) -> Curve[Vector2] {
  let k : String = spec.get("k").cast()
  let v = () => arr(spec.get("v")).map(v2)
  let a = () => arr(spec.get("args"))
  match k {
    "Base" => Curve::new()
    "Line" => @extras.LineCurve::new(v1=v()[0], v2=v()[1])
    "LineD" => @extras.LineCurve::new()
    "QB" => {
      let p = v()
      @extras.QuadraticBezierCurve::new(v0=p[0], v1=p[1], v2=p[2])
    }
    "QBD" => @extras.QuadraticBezierCurve::new()
    "CB" => {
      let p = v()
      @extras.CubicBezierCurve::new(v0=p[0], v1=p[1], v2=p[2], v3=p[3])
    }
    "CBD" => @extras.CubicBezierCurve::new()
    "Ell" => {
      let a = a()
      @extras.EllipseCurve::new(a_x=d(a[0]), a_y=d(a[1]), x_radius=d(a[2]), y_radius=d(a[3]), a_start_angle=d(a[4]), a_end_angle=d(a[5]), a_clockwise=b(a[6]), a_rotation=d(a[7]))
    }
    "EllD" => @extras.EllipseCurve::new()
    "Arc" => {
      let a = a()
      @extras.ArcCurve::new(a_x=d(a[0]), a_y=d(a[1]), a_radius=d(a[2]), a_start_angle=d(a[3]), a_end_angle=d(a[4]), a_clockwise=b(a[5]))
    }
    "ArcD" => @extras.ArcCurve::new()
    "Spline" => @extras.SplineCurve::new(points=v())
    "SplineD" => @extras.SplineCurve::new()
    "CP" => {
      let c : Curve[Vector2] = @extras.CurvePath::new()
      for s in arr(spec.get("curves")) {
        c.add(build2(s))
      }
      if b(spec.get("autoClose")) { c.set_auto_close(true) }
      if b(spec.get("close")) { ignore(c.close_path()) }
      c
    }
    "Path" => make_path(spec).curve
    "Shape" => make_shape(spec).curve
    _ => abort("spec " + k)
  }
}

///|
pub fn build3(spec : JsValue) -> Curve[Vector3] {
  let k : String = spec.get("k").cast()
  let v = () => arr(spec.get("v")).map(v3)
  match k {
    "Base" => Curve::new()
    "Line3" => @extras.LineCurve3::new(v1=v()[0], v2=v()[1])
    "Line3D" => @extras.LineCurve3::new()
    "QB3" => {
      let p = v()
      @extras.QuadraticBezierCurve3::new(v0=p[0], v1=p[1], v2=p[2])
    }
    "QB3D" => @extras.QuadraticBezierCurve3::new()
    "CB3" => {
      let p = v()
      @extras.CubicBezierCurve3::new(v0=p[0], v1=p[1], v2=p[2], v3=p[3])
    }
    "CB3D" => @extras.CubicBezierCurve3::new()
    "Cat" =>
      @extras.CatmullRomCurve3::new(points=v(), closed=b(spec.get("closed")), curve_type=spec.get("curveType").cast(), tension=d(spec.get("tension")))
    "CatD" => @extras.CatmullRomCurve3::new()
    "CP" => {
      let c : Curve[Vector3] = @extras.CurvePath::new()
      for s in arr(spec.get("curves")) {
        c.add(build3(s))
      }
      if b(spec.get("autoClose")) { c.set_auto_close(true) }
      if b(spec.get("close")) { ignore(c.close_path()) }
      c
    }
    _ => abort("spec " + k)
  }
}

///|
fn[V : @extras.CurveVector] pt(p : V) -> JsValue {
  JsValue::of(p.to_array())
}

///|
fn[V : @extras.CurveVector] opt_pt(p : V?) -> JsValue {
  match p {
    Some(p) => pt(p)
    None => JsValue::null()
  }
}

///|
fn[V : @extras.CurveVector] pts(a : Array[V]) -> JsValue {
  JsValue::of(a.map(pt))
}

///|
fn opt_int(v : JsValue) -> Int? {
  if js_kind(v) == 0 { None } else { Some(d(v).to_int()) }
}

///|
fn frames(f : @extras.FrenetFrames) -> JsValue {
  JsValue::of([pts(f.tangents), pts(f.normals), pts(f.binormals)])
}

///|
fn[V : @extras.CurveVector] apply(
  c : Curve[V],
  o : Array[JsValue],
  mk : (Curve[V]) -> Curve[V],
) -> JsValue {
  let name : String = o[0].cast()
  match name {
    "getPoint" => opt_pt(c.get_point_or_null(d(o[1])))
    "getPointT" => {
      let t = V::zero().from_array([7.0, 8.0, 9.0])
      match c.get_point_or_null(d(o[1]), optional_target=t) {
        Some(r) => JsValue::of([JsValue::of(physical_equal(r, t)), pt(r)])
        None => JsValue::null()
      }
    }
    "getPointAt" => opt_pt(c.get_point_at_or_null(d(o[1])))
    "getPointAtT" => {
      let t = V::zero().from_array([7.0, 8.0, 9.0])
      match c.get_point_at_or_null(d(o[1]), optional_target=t) {
        Some(r) => JsValue::of([JsValue::of(physical_equal(r, t)), pt(r)])
        None => JsValue::null()
      }
    }
    "getPoints" =>
      match opt_int(o[1]) {
        Some(n) => pts(c.get_points(divisions=n))
        None => pts(c.get_points())
      }
    "getSpacedPoints" =>
      match opt_int(o[1]) {
        Some(n) => pts(c.get_spaced_points(divisions=n))
        None => pts(c.get_spaced_points())
      }
    "getLength" => JsValue::of(c.get_length())
    "getLengths" =>
      match opt_int(o[1]) {
        Some(n) => JsValue::of(c.get_lengths(divisions=n))
        None => JsValue::of(c.get_lengths())
      }
    "lengthsCached" => {
      let a = c.get_lengths()
      JsValue::of(physical_equal(a, c.get_lengths()))
    }
    "uToT" =>
      if js_kind(o[2]) == 0 {
        JsValue::of(c.get_uto_tmapping(d(o[1])))
      } else {
        JsValue::of(c.get_uto_tmapping(d(o[1]), distance=d(o[2])))
      }
    "tangent" => pt(c.get_tangent(d(o[1])))
    "tangentT" => {
      let t = V::zero().from_array([7.0, 8.0, 9.0])
      let r = c.get_tangent(d(o[1]), optional_target=t)
      JsValue::of([JsValue::of(physical_equal(r, t)), pt(r)])
    }
    "tangentAt" => pt(c.get_tangent_at(d(o[1])))
    "tangentAtT" => {
      let t = V::zero().from_array([7.0, 8.0, 9.0])
      let r = c.get_tangent_at(d(o[1]), optional_target=t)
      JsValue::of([JsValue::of(physical_equal(r, t)), pt(r)])
    }
    "frenet" => frames(c.compute_frenet_frames(d(o[1]).to_int(), closed=b(o[2])))
    "updateArc" => {
      c.update_arc_lengths()
      JsValue::null()
    }
    "setDiv" => {
      c.arc_length_divisions = d(o[1]).to_int()
      JsValue::null()
    }
    "setNeedsUpdate" => {
      c.needs_update = true
      JsValue::null()
    }
    "curveLengths" => JsValue::of(c.get_curve_lengths())
    "toJSON" => json_to_js(c.to_json())
    "fromUpstreamJSON" => json_to_js(mk(c).from_json(js_to_json(o[1])).to_json())
    "selfRoundtrip" => {
      let j = c.to_json()
      let r = mk(c).from_json(j)
      JsValue::of([json_to_js(r.to_json()), pts(r.get_points())])
    }
    "clone" => {
      let r = c.clone()
      JsValue::of([
        json_to_js(r.to_json()),
        pts(r.get_points()),
        JsValue::of(r.arc_length_divisions.to_double()),
        JsValue::of(r.type_),
      ])
    }
    "copy" => {
      let r = mk(c).copy(c)
      JsValue::of([json_to_js(r.to_json()), pts(r.get_points())])
    }
    "cloneIndependent" => {
      // A clone must not alias the source's vectors or curve list.
      let r = c.clone()
      let before = json_to_js(c.to_json())
      match r.kind {
        Line(l) => ignore(l.v1.set_by_axis(_ => 99.0))
        QuadraticBezier(l) => ignore(l.v0.set_by_axis(_ => 99.0))
        CubicBezier(l) => ignore(l.v3.set_by_axis(_ => 99.0))
        Spline(s) => if s.points.length() > 0 { ignore(s.points[0].set_by_axis(_ => 99.0)) }
        CatmullRom(s) => if s.points.length() > 0 { ignore(s.points[0].set_x(99.0)) }
        CurvePath(p) | Path(p, _) | Shape(p, _, _) => p.curves.clear()
        _ => ()
      }
      JsValue::of([before, json_to_js(c.to_json())])
    }
    "aliasAutoClose" => {
      let p = c.get_points()
      JsValue::of(p.length() > 1 && physical_equal(p[p.length() - 1], p[0]))
    }
    "closePath" => {
      ignore(c.close_path())
      JsValue::of(c.curves().length())
    }
    "mutate" => {
      match c.kind {
        Line(l) => ignore(l.v2.set_by_axis(i => l.v2.component(i) + 1.0))
        QuadraticBezier(l) => ignore(l.v2.set_by_axis(i => l.v2.component(i) + 1.0))
        CubicBezier(l) => ignore(l.v3.set_by_axis(i => l.v3.component(i) + 1.0))
        Ellipse(e) => e.x_radius += 1.0
        Spline(s) => if s.points.length() > 0 { ignore(s.points[0].set_by_axis(i => s.points[0].component(i) + 1.0)) }
        CatmullRom(s) => if s.points.length() > 0 { ignore(s.points[0].set_x(s.points[0].x + 1.0)) }
        _ => ()
      }
      JsValue::null()
    }
    _ => abort("op " + name)
  }
}

///|
pub fn apply2(c : Curve[Vector2], o : Array[JsValue], spec : JsValue) -> JsValue {
  apply(c, o, _ => build_default2(spec))
}

///|
pub fn apply3(c : Curve[Vector3], o : Array[JsValue], spec : JsValue) -> JsValue {
  apply(c, o, _ => build_default3(spec))
}

///|
fn build_default2(spec : JsValue) -> Curve[Vector2] {
  let k : String = spec.get("k").cast()
  match k {
    "Base" => Curve::new()
    "Line" | "LineD" => @extras.LineCurve::new()
    "QB" | "QBD" => @extras.QuadraticBezierCurve::new()
    "CB" | "CBD" => @extras.CubicBezierCurve::new()
    "Ell" | "EllD" => @extras.EllipseCurve::new()
    "Arc" | "ArcD" => @extras.ArcCurve::new()
    "Spline" | "SplineD" => @extras.SplineCurve::new()
    "CP" => @extras.CurvePath::new()
    "Path" => @extras.Path::new().curve
    "Shape" => @extras.Shape::new().curve
    _ => abort("spec " + k)
  }
}

///|
fn build_default3(spec : JsValue) -> Curve[Vector3] {
  let k : String = spec.get("k").cast()
  match k {
    "Base" => Curve::new()
    "Line3" | "Line3D" => @extras.LineCurve3::new()
    "QB3" | "QB3D" => @extras.QuadraticBezierCurve3::new()
    "CB3" | "CB3D" => @extras.CubicBezierCurve3::new()
    "Cat" | "CatD" => @extras.CatmullRomCurve3::new()
    "CP" => @extras.CurvePath::new()
    _ => abort("spec " + k)
  }
}

///|
pub fn earcut(data : Array[Double], holes : Array[Int], dim : Int) -> Array[Int] {
  @extras.Earcut::triangulate(data, holes, dim~)
}

///|
pub fn earcut_dev(data : Array[Double], holes : Array[Int], dim : Int, tris : Array[Int]) -> Double {
  @extras.earcut_deviation(data, holes, dim, tris)
}

///|
pub fn earcut_flat(data : Array[Array[Array[Double]]]) -> JsValue {
  let r = @extras.earcut_flatten(data)
  JsValue::of([JsValue::of(r.vertices), JsValue::of(r.holes), JsValue::of(r.dimensions)])
}

///|
pub fn shape_area(p : JsValue) -> Double {
  @extras.ShapeUtils::area(arr(p).map(v2))
}

///|
pub fn shape_cw(p : JsValue) -> Bool {
  @extras.ShapeUtils::is_clock_wise(arr(p).map(v2))
}

///|
pub fn shape_tri(c : JsValue, h : JsValue) -> JsValue {
  let contour = arr(c).map(v2)
  let holes = arr(h).map(x => arr(x).map(v2))
  let f = @extras.ShapeUtils::triangulate_shape(contour, holes)
  JsValue::of([JsValue::of(f), pts(contour), JsValue::of(holes.map(pts))])
}

///|
fn mask_uuid(v : JsValue) -> JsValue {
  match js_kind(v) {
    4 => JsValue::of(arr(v).map(mask_uuid))
    5 => {
      let o = JsValue::object()
      for k in js_keys(v) {
        o.set(k, if k == "uuid" { JsValue::of("u") } else { mask_uuid(v.get(k)) })
      }
      o
    }
    _ => v
  }
}

///|
pub fn to_shapes(spec : JsValue) -> JsValue {
  let sp = @extras.ShapePath::new()
  sp.user_data = spec.get("userData")
  for op in arr(spec.get("ops")) {
    let o = arr(op)
    let name : String = o[0].cast()
    match name {
      "moveTo" => ignore(sp.move_to(d(o[1]), d(o[2])))
      "lineTo" => ignore(sp.line_to(d(o[1]), d(o[2])))
      "quad" => ignore(sp.quadratic_curve_to(d(o[1]), d(o[2]), d(o[3]), d(o[4])))
      "bez" => ignore(sp.bezier_curve_to(d(o[1]), d(o[2]), d(o[3]), d(o[4]), d(o[5]), d(o[6])))
      "spline" => ignore(sp.spline_thru(arr(o[1]).map(v2)))
      _ => abort(name)
    }
  }
  let shapes = sp.to_shapes()
  JsValue::of(
    shapes.map(s => {
      let e = s.extract_points(12)
      JsValue::of([
        pts(e.shape),
        JsValue::of(e.holes.map(pts)),
        JsValue::of(s.curves().map(c => JsValue::of(c.type_))),
        JsValue::of(s.holes().map(h => JsValue::of(h.curves().map(c => JsValue::of(c.type_))))),
        JsValue::of(@core.SerializableResource::uuid(s) != ""),
        mask_uuid(json_to_js(s.to_json())),
      ])
    }),
  )
}

///|
pub fn byte_length(w : Int, h : Int, format : Int, type_ : Int) -> Double {
  @extras.TextureUtils::get_byte_length(w, h, format, type_)
}

///|
extern "js" fn make_dom_image(w : Double, h : Double) -> JsValue = "(w, h) => ({ width: w, height: h })"

///|
pub fn fit(mode : Int, kind : Int, w : Double, h : Double, aspect : Double) -> Array[Double] {
  let t = @core.Texture::new()
  match kind {
    1 => t.set_image(DomImage(make_dom_image(w, h)))
    2 => t.set_image(DataImage({ data: None, width: w.to_int(), height: h.to_int(), depth: None, mipmaps: None }))
    _ => ()
  }
  t.repeat.x = 5.0
  t.offset.y = 5.0
  ignore(
    match mode {
      0 => @extras.TextureUtils::contain(t, aspect)
      1 => @extras.TextureUtils::cover(t, aspect)
      _ => @extras.TextureUtils::fill(t)
    },
  )
  [t.repeat.x, t.repeat.y, t.offset.x, t.offset.y]
}

///|
pub fn srgb(image : JsValue) -> JsValue {
  @extras.ImageUtils::srgb_to_linear(image)
}

///|
pub fn half_to(x : Double) -> Double {
  @extras.DataUtils::to_half_float(x) + @extras.to_half_float(x) * 0.0
}

///|
pub fn half_from(x : Double) -> Double {
  @extras.DataUtils::from_half_float(x)
}

///|
pub fn interp(a : Array[Double]) -> Array[Double] {
  [
    @extras.catmull_rom(a[0], a[1], a[2], a[3], a[4]),
    @extras.quadratic_bezier(a[0], a[1], a[2], a[3]),
    @extras.cubic_bezier(a[0], a[1], a[2], a[3], a[4]),
  ]
}

///|
pub fn text_roundtrip2(c : Curve[Vector2], text : String, spec : JsValue) -> JsValue {
  ignore(c)
  let j = @json.parse(text) catch { _ => abort("parse") }
  json_to_js(build_default2(spec).from_json(j).to_json())
}

///|
pub fn text_roundtrip3(c : Curve[Vector3], text : String, spec : JsValue) -> JsValue {
  ignore(c)
  let j = @json.parse(text) catch { _ => abort("parse") }
  json_to_js(build_default3(spec).from_json(j).to_json())
}

///|
pub fn panic_probe() -> Unit {
  abort("probe")
}
