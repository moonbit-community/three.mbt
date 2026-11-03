///|
#external
type Any

///|
fn[T] any(x : T) -> Any = "%identity"

///|
fn[T] from_any(x : Any) -> T = "%identity"

///|
extern "js" fn obj_new() -> Any = "() => ({})"

///|
extern "js" fn obj_set(o : Any, k : String, v : Any) -> Unit = "(o, k, v) => { o[k] = v; }"

///|
extern "js" fn obj_get(o : Any, k : String) -> Any = "(o, k) => o[k]"

///|
extern "js" fn is_undefined(o : Any) -> Bool = "(o) => o === undefined"

///|
extern "js" fn arr_new() -> Any = "() => []"

///|
extern "js" fn arr_push(a : Any, v : Any) -> Unit = "(a, v) => { a.push(v); }"

///|
fn Any::num(self : Any, k : String) -> Double? {
  let v = obj_get(self, k)
  if is_undefined(v) { None } else { Some(from_any(v)) }
}

///|
fn Any::bool(self : Any, k : String) -> Bool? {
  let v = obj_get(self, k)
  if is_undefined(v) { None } else { Some(from_any(v)) }
}

///|
fn Any::numbers(self : Any, k : String) -> Array[Double]? {
  let v = obj_get(self, k)
  if is_undefined(v) { None } else { Some(from_any(v)) }
}

///|
fn Any::points2(self : Any, k : String) -> Array[@math.Vector2]? {
  let v = obj_get(self, k)
  if is_undefined(v) {
    None
  } else {
    let points : Array[Array[Double]] = from_any(v)
    Some(points.map(p => @math.Vector2::new(p[0], p[1])))
  }
}

///|
fn Any::points3(self : Any, k : String) -> Array[@math.Vector3] {
  let points : Array[Array[Double]] = from_any(obj_get(self, k))
  points.map(p => @math.Vector3::new(p[0], p[1], p[2]))
}

///|
fn Any::geometry(self : Any, k : String) -> @core.BufferGeometry? {
  let v = obj_get(self, k)
  if is_undefined(v) {
    None
  } else {
    Some(build_spec(v))
  }
}

///|
/// A spec is `{ name, args, nonIndexed?, translate? }`, or `{ custom: { position, index, groups } }`.
fn build_spec(spec : Any) -> @core.BufferGeometry {
  let custom = obj_get(spec, "custom")
  let g = if is_undefined(custom) {
    build(from_any(obj_get(spec, "name")), obj_get(spec, "args"))
  } else {
    let g = @core.BufferGeometry::new()
    let position : Array[Double] = custom.numbers("position").unwrap()
    g.set_attribute("position", @core.Float32BufferAttribute::new(position, 3))
    |> ignore
    if custom.numbers("index") is Some(index) {
      g.set_index(index) |> ignore
    }
    if custom.numbers("groups") is Some(groups) {
      for i = 0; i < groups.length(); i = i + 3 {
        g.add_group(
          groups[i].to_int(),
          groups[i + 1],
          material_index=groups[i + 2].to_int(),
        )
      }
    }
    g
  }
  let g = if spec.bool("nonIndexed") == Some(true) {
    g.to_non_indexed()
  } else {
    g
  }
  if spec.bool("translate") == Some(true) {
    g.translate(0.5, 0.25, -0.125) |> ignore
  }
  g
}

///|
extern "js" fn arr_len(a : Any) -> Int = "(a) => a.length"

///|
extern "js" fn arr_at(a : Any, i : Int) -> Any = "(a, i) => a[i]"

///|
fn Any::at_num(self : Any, i : Int) -> Double {
  from_any(arr_at(self, i))
}

///|
fn points_of(a : Any) -> Array[@math.Vector2] {
  let points : Array[Array[Double]] = from_any(a)
  points.map(p => @math.Vector2::new(p[0], p[1]))
}

///|
fn[T : @extras.PathLike] apply_ops(
  target : T,
  ops : Any,
  absarc : (Double, Double, Double, Double, Double, Bool) -> Unit,
  absellipse : (Double, Double, Double, Double, Double, Double, Bool, Double) -> Unit,
) -> Unit {
  for i = 0; i < arr_len(ops); i = i + 1 {
    let op = arr_at(ops, i)
    let name : String = from_any(arr_at(op, 0))
    let n = (k : Int) => op.at_num(k)
    match name {
      "moveTo" => target.move_to(n(1), n(2)) |> ignore
      "lineTo" => target.line_to(n(1), n(2)) |> ignore
      "quadraticCurveTo" =>
        target.quadratic_curve_to(n(1), n(2), n(3), n(4)) |> ignore
      "bezierCurveTo" =>
        target.bezier_curve_to(n(1), n(2), n(3), n(4), n(5), n(6)) |> ignore
      "splineThru" => target.spline_thru(points_of(arr_at(op, 1))) |> ignore
      "closePath" => target.close_path() |> ignore
      "absarc" => absarc(n(1), n(2), n(3), n(4), n(5), from_any(arr_at(op, 6)))
      "absellipse" =>
        absellipse(
          n(1),
          n(2),
          n(3),
          n(4),
          n(5),
          n(6),
          from_any(arr_at(op, 7)),
          n(8),
        )
      _ => abort("unknown op \{name}")
    }
  }
}

///|
fn build_path(spec : Any) -> @extras.Path {
  let points = obj_get(spec, "points")
  if !is_undefined(points) {
    return @extras.Path::new(points=points_of(points))
  }
  let path = @extras.Path::new()
  apply_ops(
    path,
    obj_get(spec, "ops"),
    (x, y, r, s, e, c) => path.absarc(x, y, r, s, e, a_clockwise=c) |> ignore,
    (x, y, xr, yr, s, e, c, rot) => {
      path.absellipse(x, y, xr, yr, s, e, a_clockwise=c, a_rotation=rot)
      |> ignore
    },
  )
  path
}

///|
let last_shapes : Map[String, @extras.Shape] = Map([])

///|
fn build_shape(spec : Any) -> @extras.Shape {
  let points = obj_get(spec, "points")
  let shape = if !is_undefined(points) {
    @extras.Shape::new(points=points_of(points))
  } else {
    let shape = @extras.Shape::new()
    apply_ops(
      shape,
      obj_get(spec, "ops"),
      (x, y, r, s, e, c) => shape.absarc(x, y, r, s, e, a_clockwise=c) |> ignore,
      (x, y, xr, yr, s, e, c, rot) => {
        shape.absellipse(x, y, xr, yr, s, e, a_clockwise=c, a_rotation=rot)
        |> ignore
      },
    )
    shape
  }
  let holes = obj_get(spec, "holes")
  if !is_undefined(holes) {
    let list = []
    for i = 0; i < arr_len(holes); i = i + 1 {
      list.push(build_path(arr_at(holes, i)))
    }
    shape.set_holes(list)
  }
  last_shapes[shape.uuid()] = shape
  shape
}

///|
fn shape_arg(a : Any) -> @extras.Shape? {
  let v = obj_get(a, "shape")
  if is_undefined(v) {
    None
  } else {
    Some(build_shape(v))
  }
}

///|
fn shapes_arg(a : Any) -> Array[@extras.Shape]? {
  let v = obj_get(a, "shapes")
  if is_undefined(v) {
    None
  } else {
    let list = []
    for i = 0; i < arr_len(v); i = i + 1 {
      list.push(build_shape(arr_at(v, i)))
    }
    Some(list)
  }
}

///|
fn vector3s(a : Any) -> Array[@math.Vector3] {
  let points : Array[Array[Double]] = from_any(a)
  points.map(p => @math.Vector3::new(p[0], p[1], p[2]))
}

///|
fn curve_arg(a : Any, key : String) -> @extras.Curve[@math.Vector3]? {
  let spec = obj_get(a, key)
  if is_undefined(spec) {
    return None
  }
  let type_ : String = from_any(obj_get(spec, "type"))
  let p = vector3s(obj_get(spec, "points"))
  Some(
    match type_ {
      "LineCurve3" => @extras.LineCurve3::new(v1=p[0], v2=p[1])
      "QuadraticBezierCurve3" =>
        @extras.QuadraticBezierCurve3::new(v0=p[0], v1=p[1], v2=p[2])
      "CubicBezierCurve3" =>
        @extras.CubicBezierCurve3::new(v0=p[0], v1=p[1], v2=p[2], v3=p[3])
      "CatmullRomCurve3" =>
        @extras.CatmullRomCurve3::new(
          points=p,
          closed?=spec.bool("closed"),
          curve_type?={
            let v = obj_get(spec, "curveType")
            if is_undefined(v) {
              None
            } else {
              Some(from_any(v))
            }
          },
          tension?=spec.num("tension"),
        )
      _ => abort("unknown curve \{type_}")
    },
  )
}

///|
let custom_uv : @geometries.ExtrudeUVGenerator = {
  generate_top_uv: (_, v, a, b, c) => {
    [a, b, c].map(i => @math.Vector2::new(v[i * 3] * 2.0, v[i * 3 + 1]))
  },
  generate_side_wall_uv: (_, v, a, b, c, d) => {
    [a, b, c, d].map(i => @math.Vector2::new(v[i * 3 + 2], v[i * 3] + 0.25))
  },
}

///|
fn flatten(vectors : Array[@math.Vector3]) -> Array[Double] {
  let out = []
  for v in vectors {
    out.push(v.x)
    out.push(v.y)
    out.push(v.z)
  }
  out
}

///|
fn frames_snapshot(g : @core.BufferGeometry) -> Any {
  match @geometries.TubeGeometry::frames(g) {
    None => any(())
    Some(f) => {
      let o = obj_new()
      obj_set(o, "tangents", any(flatten(f.tangents)))
      obj_set(o, "normals", any(flatten(f.normals)))
      obj_set(o, "binormals", any(flatten(f.binormals)))
      o
    }
  }
}

///|
fn build(name : String, a : Any) -> @core.BufferGeometry {
  match name {
    "Box" =>
      @geometries.BoxGeometry::new(
        width?=a.num("width"),
        height?=a.num("height"),
        depth?=a.num("depth"),
        width_segments?=a.num("widthSegments"),
        height_segments?=a.num("heightSegments"),
        depth_segments?=a.num("depthSegments"),
      )
    "Plane" =>
      @geometries.PlaneGeometry::new(
        width?=a.num("width"),
        height?=a.num("height"),
        width_segments?=a.num("widthSegments"),
        height_segments?=a.num("heightSegments"),
      )
    "Circle" =>
      @geometries.CircleGeometry::new(
        radius?=a.num("radius"),
        segments?=a.num("segments"),
        theta_start?=a.num("thetaStart"),
        theta_length?=a.num("thetaLength"),
      )
    "Ring" =>
      @geometries.RingGeometry::new(
        inner_radius?=a.num("innerRadius"),
        outer_radius?=a.num("outerRadius"),
        theta_segments?=a.num("thetaSegments"),
        phi_segments?=a.num("phiSegments"),
        theta_start?=a.num("thetaStart"),
        theta_length?=a.num("thetaLength"),
      )
    "Sphere" =>
      @geometries.SphereGeometry::new(
        radius?=a.num("radius"),
        width_segments?=a.num("widthSegments"),
        height_segments?=a.num("heightSegments"),
        phi_start?=a.num("phiStart"),
        phi_length?=a.num("phiLength"),
        theta_start?=a.num("thetaStart"),
        theta_length?=a.num("thetaLength"),
      )
    "Cylinder" =>
      @geometries.CylinderGeometry::new(
        radius_top?=a.num("radiusTop"),
        radius_bottom?=a.num("radiusBottom"),
        height?=a.num("height"),
        radial_segments?=a.num("radialSegments"),
        height_segments?=a.num("heightSegments"),
        open_ended?=a.bool("openEnded"),
        theta_start?=a.num("thetaStart"),
        theta_length?=a.num("thetaLength"),
      )
    "Cone" =>
      @geometries.ConeGeometry::new(
        radius?=a.num("radius"),
        height?=a.num("height"),
        radial_segments?=a.num("radialSegments"),
        height_segments?=a.num("heightSegments"),
        open_ended?=a.bool("openEnded"),
        theta_start?=a.num("thetaStart"),
        theta_length?=a.num("thetaLength"),
      )
    "Capsule" =>
      @geometries.CapsuleGeometry::new(
        radius?=a.num("radius"),
        height?=a.num("height"),
        cap_segments?=a.num("capSegments"),
        radial_segments?=a.num("radialSegments"),
        height_segments?=a.num("heightSegments"),
      )
    "Torus" =>
      @geometries.TorusGeometry::new(
        radius?=a.num("radius"),
        tube?=a.num("tube"),
        radial_segments?=a.num("radialSegments"),
        tubular_segments?=a.num("tubularSegments"),
        arc?=a.num("arc"),
        theta_start?=a.num("thetaStart"),
        theta_length?=a.num("thetaLength"),
      )
    "TorusKnot" =>
      @geometries.TorusKnotGeometry::new(
        radius?=a.num("radius"),
        tube?=a.num("tube"),
        tubular_segments?=a.num("tubularSegments"),
        radial_segments?=a.num("radialSegments"),
        p?=a.num("p"),
        q?=a.num("q"),
      )
    "Polyhedron" =>
      @geometries.PolyhedronGeometry::new(
        vertices?=a.numbers("vertices"),
        indices?=a.numbers("indices"),
        radius?=a.num("radius"),
        detail?=a.num("detail"),
      )
    "Tetrahedron" =>
      @geometries.TetrahedronGeometry::new(
        radius?=a.num("radius"),
        detail?=a.num("detail"),
      )
    "Octahedron" =>
      @geometries.OctahedronGeometry::new(
        radius?=a.num("radius"),
        detail?=a.num("detail"),
      )
    "Icosahedron" =>
      @geometries.IcosahedronGeometry::new(
        radius?=a.num("radius"),
        detail?=a.num("detail"),
      )
    "Dodecahedron" =>
      @geometries.DodecahedronGeometry::new(
        radius?=a.num("radius"),
        detail?=a.num("detail"),
      )
    "Lathe" =>
      if a.bool("vector3") == Some(true) {
        @geometries.LatheGeometry::new_vector3(
          a.points3("points"),
          segments?=a.num("segments"),
          phi_start?=a.num("phiStart"),
          phi_length?=a.num("phiLength"),
        )
      } else {
        @geometries.LatheGeometry::new(
          points?=a.points2("points"),
          segments?=a.num("segments"),
          phi_start?=a.num("phiStart"),
          phi_length?=a.num("phiLength"),
        )
      }
    "Shape" =>
      if is_undefined(obj_get(a, "shapes")) {
        @geometries.ShapeGeometry::new(
          shapes?=shape_arg(a),
          curve_segments?=a.num("curveSegments").map(x => x.to_int()),
        )
      } else {
        @geometries.ShapeGeometry::new_shapes(
          shapes_arg(a).unwrap(),
          curve_segments?=a.num("curveSegments").map(x => x.to_int()),
        )
      }
    "Extrude" => {
      let o = obj_get(a, "options")
      let o = if is_undefined(o) { obj_new() } else { o }
      @geometries.ExtrudeGeometry::new(
        shapes?=shapes_arg(a),
        curve_segments?=o.num("curveSegments").map(x => x.to_int()),
        steps?=o.num("steps"),
        depth?=o.num("depth"),
        bevel_enabled?=o.bool("bevelEnabled"),
        bevel_thickness?=o.num("bevelThickness"),
        bevel_size?=o.num("bevelSize"),
        bevel_offset?=o.num("bevelOffset"),
        bevel_segments?=o.num("bevelSegments"),
        extrude_path?=curve_arg(o, "extrudePath"),
        uv_generator?=if o.bool("customUV") == Some(true) {
          Some(custom_uv)
        } else {
          None
        },
      )
    }
    "Tube" =>
      @geometries.TubeGeometry::new(
        path?=curve_arg(a, "path"),
        tubular_segments?=a.num("tubularSegments"),
        radius?=a.num("radius"),
        radial_segments?=a.num("radialSegments"),
        closed?=a.bool("closed"),
      )
    "Edges" =>
      @geometries.EdgesGeometry::new(
        geometry?=a.geometry("geometry"),
        threshold_angle?=a.num("thresholdAngle"),
      )
    "Wireframe" =>
      @geometries.WireframeGeometry::new(geometry?=a.geometry("geometry"))
    _ => abort("unknown geometry \{name}")
  }
}

///|
fn from_json(name : String, data : Json) -> @core.BufferGeometry? {
  match name {
    "Box" => Some(@geometries.BoxGeometry::from_json(data))
    "Plane" => Some(@geometries.PlaneGeometry::from_json(data))
    "Circle" => Some(@geometries.CircleGeometry::from_json(data))
    "Ring" => Some(@geometries.RingGeometry::from_json(data))
    "Sphere" => Some(@geometries.SphereGeometry::from_json(data))
    "Cylinder" => Some(@geometries.CylinderGeometry::from_json(data))
    "Cone" => Some(@geometries.ConeGeometry::from_json(data))
    "Capsule" => Some(@geometries.CapsuleGeometry::from_json(data))
    "Torus" => Some(@geometries.TorusGeometry::from_json(data))
    "TorusKnot" => Some(@geometries.TorusKnotGeometry::from_json(data))
    "Polyhedron" => Some(@geometries.PolyhedronGeometry::from_json(data))
    "Tetrahedron" => Some(@geometries.TetrahedronGeometry::from_json(data))
    "Octahedron" => Some(@geometries.OctahedronGeometry::from_json(data))
    "Icosahedron" => Some(@geometries.IcosahedronGeometry::from_json(data))
    "Dodecahedron" => Some(@geometries.DodecahedronGeometry::from_json(data))
    "Lathe" => Some(@geometries.LatheGeometry::from_json(data))
    "Tube" => Some(@geometries.TubeGeometry::from_json(data))
    "Shape" => Some(@geometries.ShapeGeometry::from_json(data, last_shapes))
    "Extrude" => Some(@geometries.ExtrudeGeometry::from_json(data, last_shapes))
    _ => None
  }
}

///|
fn sphere_snapshot(s : @math.Sphere?) -> Any {
  match s {
    None => any(())
    Some(s) => {
      let o = obj_new()
      obj_set(o, "center", any([s.center.x, s.center.y, s.center.z]))
      obj_set(o, "radius", any(s.radius))
      o
    }
  }
}

///|
fn box_snapshot(b : @math.Box3?) -> Any {
  match b {
    None => any(())
    Some(b) => {
      let o = obj_new()
      obj_set(o, "min", any([b.min.x, b.min.y, b.min.z]))
      obj_set(o, "max", any([b.max.x, b.max.y, b.max.z]))
      o
    }
  }
}

///|
fn attribute_snapshot(a : @core.GeometryAttribute) -> Any {
  let o = obj_new()
  obj_set(o, "array", any(a.array()))
  obj_set(o, "itemSize", any(a.item_size()))
  obj_set(o, "count", any(a.count()))
  obj_set(o, "normalized", any(a.normalized()))
  o
}

///|
fn snapshot(g : @core.BufferGeometry) -> Any {
  let o = obj_new()
  obj_set(o, "type", any(g.type_))
  obj_set(o, "name", any(g.name))
  let attributes = obj_new()
  for k, a in g.attributes {
    obj_set(attributes, k, attribute_snapshot(a))
  }
  obj_set(o, "attributes", attributes)
  match g.index {
    Some(index) => obj_set(o, "index", attribute_snapshot(index))
    None => obj_set(o, "index", any(()))
  }
  let groups = arr_new()
  for group in g.groups {
    arr_push(groups, any([group.start.to_double(), group.count, group.material_index.to_double()]))
  }
  obj_set(o, "groups", groups)
  obj_set(o, "drawRange", any([g.draw_range.start.to_double(), g.draw_range.count]))
  match g.parameters {
    Some(p) => {
      obj_set(o, "parameters", any(Json::object(p.resolved_values()).stringify()))
      obj_set(o, "parameterKeys", any(p.values.keys().collect()))
      obj_set(o, "shapes", any(p.shapes.map(s => s.to_json().stringify())))
    }
    None => obj_set(o, "parameters", any(()))
  }
  obj_set(o, "toJSON", any(g.to_json().stringify()))
  o
}

///|
/// Everything measured about one case. Mutates nothing shared between the steps.
pub fn snapshot_case(spec : Any) -> Any {
  last_shapes.clear()
  let name : String = from_any(obj_get(spec, "name"))
  let result = obj_new()
  let g = build_spec(spec)
  let plain = snapshot(g)
  obj_set(result, "plain", plain)
  // bounds, computed on a separate clone so `toJSON` above stays free of them
  let bounds = g.clone()
  bounds.compute_bounding_sphere()
  bounds.compute_bounding_box()
  obj_set(result, "boundingSphere", sphere_snapshot(bounds.bounding_sphere))
  obj_set(result, "boundingBox", box_snapshot(bounds.bounding_box))
  obj_set(result, "boundedJSON", any(bounds.to_json().stringify()))
  // clone
  let clone = g.clone()
  obj_set(result, "clone", snapshot(clone))
  obj_set(result, "cloneIdentity", any(clone.uuid != g.uuid && clone.id != g.id))
  // copy onto another class
  let target = @geometries.BoxGeometry::new()
  target.copy(g) |> ignore
  obj_set(result, "copyOntoBox", snapshot(target))
  // transformed
  let transformed = g.clone()
  transformed.rotate_x(0.5) |> ignore
  obj_set(result, "transformed", snapshot(transformed))
  // fromJSON from upstream's JSON
  if name == "Tube" {
    obj_set(result, "frames", frames_snapshot(g))
    obj_set(result, "cloneFrames", frames_snapshot(clone))
  }
  // the JSON of the classes holding shapes names this side's uuids
  if name is ("Shape" | "Extrude" | "Tube") {
    obj_set(result, "ownJSON", any(g.to_json().stringify()))
  }
  result
}

///|
/// Separate from `snapshot_case`, so a throw here cannot hide the other comparisons.
pub fn from_json_case(name : String, json_text : String) -> Any {
  match from_json(name, try! @json.parse(json_text)) {
    Some(restored) => snapshot(restored)
    None => abort("no fromJSON for \{name}")
  }
}
