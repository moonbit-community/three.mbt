// Port side of the geometry gaps check. `run(id)` returns `toJSON()` as text; run.mjs
// does the same with upstream. Only public API that exists before and after the change.

///|
fn v2(x : Double, y : Double) -> @math.Vector2 {
  @math.Vector2::new(x, y)
}

///|
fn v3(x : Double, y : Double, z : Double) -> @math.Vector3 {
  @math.Vector3::new(x, y, z)
}

///|
fn triangle() -> @extras.Shape {
  let s = @extras.Shape::new()
  s.move_to(0, -1) |> ignore
  s.line_to(1, 1) |> ignore
  s.line_to(-1, 1) |> ignore
  s
}

///|
fn square_with_hole() -> @extras.Shape {
  let s = @extras.Shape::new(points=[v2(-2, -2), v2(2, -2), v2(2, 2), v2(-2, 2)])
  s.set_holes([
    @extras.Path::new(points=[v2(-1, -1), v2(-1, 1), v2(1, 1), v2(1, -1)]),
  ])
  s
}

///|
fn catmull_points() -> Array[@math.Vector3] {
  [v3(0, 0, 0), v3(1, 2, 0), v3(2, 0, 1), v3(3, 1, 2)]
}

///|
fn plain() -> @core.BufferGeometry {
  let g = @core.BufferGeometry::new()
  g.set_attribute(
    "position",
    @core.Float32BufferAttribute::new([0.0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0], 3),
  )
  |> ignore
  g.set_index([0.0, 1, 2, 2, 1, 3]) |> ignore
  g
}

///|
fn make(name : String) -> @core.BufferGeometry {
  match name {
    "Plain" => plain()
    "Box" => @geometries.BoxGeometry::new(width=1, height=2, depth=3)
    "Sphere" =>
      @geometries.SphereGeometry::new(
        radius=1,
        width_segments=4,
        height_segments=3,
      )
    "Cone" =>
      @geometries.ConeGeometry::new(radius=1, height=2, radial_segments=5)
    "Tetra" => @geometries.TetrahedronGeometry::new(radius=1, detail=0)
    "Shape0" => @geometries.ShapeGeometry::new()
    "Shape1" => @geometries.ShapeGeometry::new(shapes=triangle())
    "ShapeN" =>
      @geometries.ShapeGeometry::new_shapes(
        [square_with_hole(), triangle()],
        curve_segments=4,
      )
    "Extrude0" => @geometries.ExtrudeGeometry::new()
    "ExtrudeN" =>
      @geometries.ExtrudeGeometry::new(
        shapes=[square_with_hole(), triangle()],
        steps=2,
        depth=2,
        bevel_enabled=false,
      )
    "ExtrudePath" =>
      @geometries.ExtrudeGeometry::new(
        shapes=[triangle()],
        steps=3,
        extrude_path=@extras.CatmullRomCurve3::new(points=catmull_points()),
      )
    "Tube0" => @geometries.TubeGeometry::new()
    "TubeC" =>
      @geometries.TubeGeometry::new(
        path=@extras.CatmullRomCurve3::new(
          points=catmull_points(),
          closed=true,
        ),
        tubular_segments=8,
        radius=0.5,
        radial_segments=4,
        closed=true,
      )
    "Edges" =>
      @geometries.EdgesGeometry::new(
        geometry=@geometries.BoxGeometry::new(),
        threshold_angle=10,
      )
    "Edges0" => @geometries.EdgesGeometry::new()
    "Wire" =>
      @geometries.WireframeGeometry::new(
        geometry=@geometries.SphereGeometry::new(
          radius=1,
          width_segments=4,
          height_segments=3,
        ),
      )
    "Wire0" => @geometries.WireframeGeometry::new()
    "Lathe" =>
      @geometries.LatheGeometry::new(
        points=[v2(0, -1), v2(0.5, 0), v2(0.25, 1)],
        segments=5,
      )
    "Lathe3" =>
      @geometries.LatheGeometry::new_vector3(
        [v3(0, -1, 7), v3(0.5, 0, 8), v3(0.25, 1, 9)],
        segments=3,
      )
    _ => abort("unknown geometry \{name}")
  }
}

///|
fn json(g : @core.BufferGeometry) -> String {
  g.to_json().stringify()
}

///|
/// Source geometries mutated after the geometry that holds them was built.
fn live(name : String) -> String {
  match name {
    "edges_src_name" => {
      let src = @geometries.BoxGeometry::new()
      let e = @geometries.EdgesGeometry::new(geometry=src)
      src.name = "renamed"
      json(e)
    }
    "edges_src_translate" => {
      let src = @geometries.BoxGeometry::new()
      let e = @geometries.EdgesGeometry::new(geometry=src)
      src.translate(1, 0, 0) |> ignore
      json(e)
    }
    "edges_src_attribute" => {
      let src = plain()
      let e = @geometries.EdgesGeometry::new(geometry=src)
      src.set_attribute(
        "color",
        @core.Float32BufferAttribute::new([1.0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 1], 3),
      )
      |> ignore
      json(e)
    }
    "edges_src_copy" => {
      let src = @geometries.BoxGeometry::new()
      let e = @geometries.EdgesGeometry::new(geometry=src)
      src.copy(make("Sphere")) |> ignore
      json(e)
    }
    "edges_copied_onto_box" => {
      let src = @geometries.BoxGeometry::new()
      let e = @geometries.EdgesGeometry::new(geometry=src)
      let b = @geometries.BoxGeometry::new().copy(e)
      src.name = "late"
      json(b)
    }
    "edges_clone" => {
      let src = @geometries.BoxGeometry::new()
      let e = @geometries.EdgesGeometry::new(geometry=src)
      let c = e.clone()
      src.name = "late"
      json(c)
    }
    "edges_of_lathe_points" => {
      let points = [v2(0, -1), v2(0.5, 0), v2(0.25, 1)]
      let src = @geometries.LatheGeometry::new(points~, segments=3)
      let e = @geometries.EdgesGeometry::new(geometry=src)
      points[0].x = 0.3
      json(e)
    }
    "wire_src_name" => {
      let src = make("Sphere")
      let w = @geometries.WireframeGeometry::new(geometry=src)
      src.name = "renamed"
      json(w)
    }
    "wire_src_translate" => {
      let src = make("Sphere")
      let w = @geometries.WireframeGeometry::new(geometry=src)
      src.translate(0, 1, 0) |> ignore
      json(w)
    }
    "wire_copied_onto_box" => {
      let src = make("Sphere")
      let w = @geometries.WireframeGeometry::new(geometry=src)
      let b = @geometries.BoxGeometry::new().copy(w)
      src.name = "late"
      json(b)
    }
    "lathe_points" => {
      let points = [v2(0, -1), v2(0.5, 0), v2(0.25, 1)]
      let l = @geometries.LatheGeometry::new(points~, segments=3)
      points[0].x = 0.75
      points.push(v2(0.1, 1.5))
      json(l)
    }
    "lathe_points_copy" => {
      let points = [v2(0, -1), v2(0.5, 0), v2(0.25, 1)]
      let l = @geometries.LatheGeometry::new(points~, segments=3)
      let b = @geometries.BoxGeometry::new().copy(l)
      let c = l.clone()
      points[1].y = 0.125
      json(b) + "\n" + json(c)
    }
    "lathe3_points" => {
      let points = [v3(0, -1, 7), v3(0.5, 0, 8), v3(0.25, 1, 9)]
      let l = @geometries.LatheGeometry::new_vector3(points, segments=3)
      points[2].z = -4
      json(l)
    }
    "tube_path" => {
      let p1 = v3(-1, 1, 0)
      let path = @extras.QuadraticBezierCurve3::new(
        v0=v3(-1, -1, 0),
        v1=p1,
        v2=v3(1, 1, 0),
      )
      let t = @geometries.TubeGeometry::new(
        path~,
        tubular_segments=4,
        radial_segments=3,
      )
      p1.x = 9
      json(t)
    }
    "tube_path_transformed" => {
      let p1 = v3(-1, 1, 0)
      let path = @extras.QuadraticBezierCurve3::new(
        v0=v3(-1, -1, 0),
        v1=p1,
        v2=v3(1, 1, 0),
      )
      let t = @geometries.TubeGeometry::new(
        path~,
        tubular_segments=4,
        radial_segments=3,
      )
      t.translate(1, 1, 1) |> ignore
      p1.x = 9
      json(t)
    }
    "tube_catmull_push" => {
      let points = catmull_points()
      let path = @extras.CatmullRomCurve3::new(points~)
      let t = @geometries.TubeGeometry::new(
        path~,
        tubular_segments=4,
        radial_segments=3,
      )
      let b = @geometries.BoxGeometry::new().copy(t)
      points.push(v3(5, 5, 5))
      json(t) + "\n" + json(b)
    }
    "extrude_path" => {
      let points = catmull_points()
      let e = @geometries.ExtrudeGeometry::new(
        shapes=[triangle()],
        steps=2,
        extrude_path=@extras.CatmullRomCurve3::new(points~),
      )
      points[1].x = 7
      json(e)
    }
    "extrude_path_transformed" => {
      let points = catmull_points()
      let e = @geometries.ExtrudeGeometry::new(
        shapes=[triangle()],
        steps=2,
        extrude_path=@extras.CatmullRomCurve3::new(points~),
      )
      e.rotate_x(0.5) |> ignore
      points[1].x = 7
      json(e)
    }
    "shape_hole_added" => {
      let shape = triangle()
      let s = @geometries.ShapeGeometry::new(shapes=shape)
      let b = @geometries.BoxGeometry::new().copy(s)
      shape.set_holes([
        @extras.Path::new(points=[v2(0, 0), v2(0.1, 0.5), v2(-0.1, 0.5)]),
      ])
      json(s) + "\n" + json(b)
    }
    _ => abort("unknown live case \{name}")
  }
}

///|
/// `op|a|b`: what to do with geometries `a` (the target of `copy`) and `b`.
pub fn run(id : String) -> String {
  let parts = id.split("|").map(s => s.to_string()).collect()
  let a = parts.get(1).unwrap_or("")
  let b = parts.get(2).unwrap_or("")
  match parts[0] {
    "json" => json(make(a))
    "translate" => json(make(a).translate(0.5, 0.25, -0.125))
    "rotate" => json(make(a).rotate_x(0.5))
    "matrix" =>
      json(
        make(a).apply_matrix4(@math.Matrix4::new().make_translation(1, 2, 3)),
      )
    "clone_translated" => json(make(a).translate(0.5, 0.25, -0.125).clone())
    "translated_clone_copy" => {
      let t = make(a).translate(1, 0, 0)
      json(make(a).copy(t))
    }
    "copy" => json(make(a).copy(make(b)))
    "copy_src_translated" => json(make(a).copy(make(b).translate(1, 0, 0)))
    "copy_tgt_translated" => json(make(a).translate(1, 0, 0).copy(make(b)))
    "copy_clone" => json(make(a).copy(make(b)).clone())
    "copy_then_translate" => json(make(a).copy(make(b)).translate(1, 0, 0))
    "copy_type" => make(a).copy(make(b)).type_
    "live" => live(a)
    _ => abort("unknown op \{id}")
  }
}
