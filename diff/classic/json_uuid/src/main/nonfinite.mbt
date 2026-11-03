// The port side of loaders_diff/nonfinite_fixtures.mjs: the same scenes, built with
// the same calls in the same order.

///|
extern "js" fn inf() -> Double = "() => Infinity"

///|
extern "js" fn nan() -> Double = "() => NaN"

///|
fn mat_basic() -> @core.MaterialSlot {
  Single(@core.MeshBasicMaterial::new())
}

///|
fn nf_object() -> @core.Object3D {
  let (i, n, m) = (inf(), nan(), -inf())
  let s = @core.Scene::new()
  let o = @core.Object3D::new()
  ignore(o.position.set(i, n, m))
  ignore(o.scale.set(1.0, n, 1.0))
  o.render_order = i
  ignore(o.up.set(n, i, m))
  o.pivot = Some(@math.Vector3::new(i, n, 0.0))
  ignore(s.add(o))
  let fixed = @core.Object3D::new()
  fixed.matrix_auto_update = false
  fixed.matrix.elements[3] = n
  fixed.matrix.elements[12] = i
  fixed.matrix.elements[14] = m
  ignore(s.add(fixed))
  s
}

///|
fn nf_cameras() -> @core.Object3D {
  let (i, n, m) = (inf(), nan(), -inf())
  let s = @core.Scene::new()
  let p = @core.PerspectiveCamera::new(fov=i, aspect=n, near=m, far=i)
  let pd = p.as_perspective_camera()
  pd.focus = n
  pd.zoom = i
  pd.film_gauge = m
  pd.film_offset = n
  p.set_view_offset(i, n, m, i, n, 1.0)
  ignore(s.add(p))
  let o = @core.OrthographicCamera::new(
    left=m,
    right=i,
    top=n,
    bottom=m,
    near=i,
    far=n,
  )
  o.as_orthographic_camera().zoom = m
  o.set_view_offset(1.0, 2.0, i, n, m, i)
  ignore(s.add(o))
  s
}

///|
fn shadow_of(light : @core.Object3D) -> @core.LightShadow {
  light.as_light().shadow.unwrap()
}

///|
fn nf_lights() -> @core.Object3D {
  let (i, n, m) = (inf(), nan(), -inf())
  let s = @core.Scene::new()
  let d = @core.DirectionalLight::new(
    color=@math.Color::from_hex(0xffffff),
    intensity=i,
  )
  let ds = shadow_of(d)
  ds.bias = n
  ds.normal_bias = i
  ds.radius = m
  ds.intensity = n
  ignore(ds.map_size.set(i, n))
  let dc = ds.camera.as_orthographic_camera()
  dc.far = i
  dc.left = m
  dc.zoom = n
  ignore(s.add(d))
  guard d.as_light().kind is DirectionalLight(dl)
  ignore(s.add(dl.target))
  let p = @core.PointLight::new(
    color=@math.Color::from_hex(0xff0000),
    intensity=n,
    distance=i,
    decay=m,
  )
  let pc = shadow_of(p).camera.as_perspective_camera()
  pc.near = n
  pc.fov = i
  ignore(s.add(p))
  let sp = @core.SpotLight::new(
    color=@math.Color::from_hex(0x00ff00),
    intensity=1.0,
    distance=i,
    angle=n,
    penumbra=i,
    decay=m,
  )
  guard shadow_of(sp).kind is SpotLightShadow(sps)
  sps.focus = n
  ignore(s.add(sp))
  ignore(
    s.add(
      @core.RectAreaLight::new(
        color=@math.Color::from_hex(0x0000ff),
        intensity=1.0,
        width=i,
        height=n,
      ),
    ),
  )
  ignore(
    s.add(
      @core.HemisphereLight::new(
        sky_color=@math.Color::from_hex(0xffffff),
        ground_color=@math.Color::from_hex(0x000000),
        intensity=m,
      ),
    ),
  )
  ignore(
    s.add(
      @core.AmbientLight::new(color=@math.Color::from_hex(0xffffff), intensity=i),
    ),
  )
  let lp = @core.LightProbe::new(intensity=n)
  guard lp.as_light().kind is LightProbe(probe)
  ignore(probe.sh.coefficients[0].set(i, n, m))
  ignore(s.add(lp))
  s
}

///|
fn nf_scene() -> @core.Object3D {
  let (i, n, m) = (inf(), nan(), -inf())
  let s = @core.Scene::new()
  let sc = s.as_scene()
  sc.fog = Some(Fog(@core.Fog::new(color=@math.Color::from_hex(0x123456), near=m, far=i)))
  sc.background_blurriness = i
  sc.background_intensity = n
  sc.environment_intensity = m
  ignore(sc.background_rotation.set(i, n, m))
  ignore(sc.environment_rotation.set(n, 0.0, i))
  s
}

///|
fn nf_fog_exp2() -> @core.Object3D {
  let s = @core.Scene::new()
  s.as_scene().fog = Some(
    FogExp2(
      @core.FogExp2::new(color=@math.Color::from_hex(0x654321), density=nan()),
    ),
  )
  s
}

///|
fn nf_lod() -> @core.Object3D {
  let (i, n) = (inf(), nan())
  let s = @core.Scene::new()
  let l = @core.LOD::new()
  ignore(l.add_level(@core.Object3D::new(), distance=i, hysteresis=n))
  ignore(l.add_level(@core.Object3D::new(), distance=2.0, hysteresis=i))
  ignore(s.add(l))
  s
}

///|
fn nf_materials() -> @core.Object3D {
  let (i, n, m) = (inf(), nan(), -inf())
  let s = @core.Scene::new()
  let box = @geometries.BoxGeometry::new()
  let phys = @core.MeshPhysicalMaterial::new()
  phys.opacity = n
  phys.emissive_intensity = Some(m)
  phys.thickness = Some(i)
  phys.sheen_roughness = Some(n)
  ignore(phys.env_map_rotation.unwrap().set(i, n, 0.0))
  phys.clipping_planes = Some([@math.Plane::new(normal=@math.Vector3::new(n, 0.0, 1.0), constant=i)])
  let sprite = @core.SpriteMaterial::new()
  sprite.rotation = Some(i)
  let points = @core.PointsMaterial::new()
  points.size = Some(n)
  let dashed = @core.LineDashedMaterial::new()
  dashed.dash_size = Some(i)
  dashed.gap_size = Some(n)
  dashed.scale = Some(m)
  dashed.linewidth = Some(i)
  let shader = @core.ShaderMaterial::new()
  shader.uniforms = Some(
    Map([
      ("a", @core.Uniform::new(Number(i))),
      ("v", @core.Uniform::new(Vector3(@math.Vector3::new(n, 1.0, i)))),
      (
        "p",
        @core.Uniform::new(
          Plane(@math.Plane::new(normal=@math.Vector3::new(0.0, n, 0.0), constant=m)),
        ),
      ),
      ("arr", @core.Uniform::new(Numbers([1.0, i, n]))),
    ]),
  )
  ignore(s.add(@core.Mesh::new(geometry=box, material=Single(phys))))
  ignore(s.add(@core.Sprite::new(material=sprite)))
  ignore(s.add(@core.Points::new(geometry=box, material=Single(points))))
  ignore(s.add(@core.LineSegments::new(geometry=box, material=Single(dashed))))
  ignore(s.add(@core.Mesh::new(geometry=box, material=Single(shader))))
  s
}

///|
fn nf_textures() -> @core.Object3D {
  let (i, n, m) = (inf(), nan(), -inf())
  let s = @core.Scene::new()
  let t = @core.DataTexture::new(
    data=@core.TypedArray::new_by_name("Uint8Array", [1, 2, 3, 4]),
    width=1,
    height=1,
  )
  ignore(t.offset.set(i, n))
  ignore(t.repeat.set(m, 1.0))
  ignore(t.center.set(0.0, i))
  t.rotation = n
  let mat = @core.MeshBasicMaterial::new()
  mat.map = Some(t)
  ignore(
    s.add(
      @core.Mesh::new(
        geometry=@geometries.BoxGeometry::new(),
        material=Single(mat),
      ),
    ),
  )
  s
}

///|
fn nf_buffer_geometry() -> @core.Object3D {
  let (i, n, m) = (inf(), nan(), -inf())
  let s = @core.Scene::new()
  let g = @core.BufferGeometry::new()
  ignore(
    g.set_attribute(
      "position",
      @core.Float32BufferAttribute::new([i, n, m, 0, 1, 2, 3, 4, 5], 3),
    ),
  )
  g.morph_attributes["position"] = [
    Buffer(@core.Float32BufferAttribute::new([n, 0, 0, i, 0, 0, m, 0, 0], 3)),
  ]
  g.add_group(0, i)
  g.compute_bounding_sphere()
  ignore(s.add(@core.Mesh::new(geometry=g, material=mat_basic())))
  let ig = @core.InstancedBufferGeometry::new()
  ignore(
    ig.set_attribute(
      "offset",
      @core.InstancedBufferAttribute::new(@core.TypedArray::float32([n, i]), 1),
    ),
  )
  ignore(s.add(@core.Mesh::new(geometry=ig, material=mat_basic())))
  s
}

///|
fn nf_instanced() -> @core.Object3D {
  let (i, n, m) = (inf(), nan(), -inf())
  let s = @core.Scene::new()
  let mesh = @core.InstancedMesh::new(
    geometry=@geometries.BoxGeometry::new(),
    material=mat_basic(),
    2,
  )
  ignore(mesh.set_matrix_at(1, @math.Matrix4::new().make_translation(i, n, m)))
  ignore(mesh.set_color_at(0, @math.Color::new(n, i, m)))
  mesh.compute_bounding_sphere()
  mesh.compute_bounding_box()
  ignore(s.add(mesh))
  s
}

///|
fn nf_batched() -> @core.Object3D {
  let s = @core.Scene::new()
  let b = @core.BatchedMesh::new(2, 8, max_index_count=8, material=mat_basic())
  b.compute_bounding_box()
  b.compute_bounding_sphere()
  ignore(s.add(b))
  s
}

///|
fn nf_skinned() -> @core.Object3D {
  let (i, n, m) = (inf(), nan(), -inf())
  let s = @core.Scene::new()
  let bone = @core.Bone::new()
  let inv = @math.Matrix4::new()
  inv.elements[0] = n
  inv.elements[13] = i
  let skeleton = @core.Skeleton::new(bones=[bone], bone_inverses=[inv])
  let mesh = @core.SkinnedMesh::new(
    geometry=@geometries.BoxGeometry::new(),
    material=mat_basic(),
  )
  ignore(mesh.add(bone))
  let bind = @math.Matrix4::new()
  bind.elements[5] = m
  bind.elements[12] = n
  mesh.bind(skeleton, bind_matrix=bind)
  ignore(s.add(mesh))
  s
}

///|
fn nf_animation() -> @core.Object3D {
  let (i, n, m) = (inf(), nan(), -inf())
  let o = @core.Object3D::new()
  let times : Array[Double] = [0, n, 2]
  let values : Array[Double] = [i, 0, m]
  let track = @animation.NumberKeyframeTrack::new(".position[x]", times, values)
  let clip = @animation.AnimationClip::new(name="nf", duration=i, tracks=[track])
  o.animations = [clip.as_resource()]
  o
}

///|
fn nf_geometries() -> @core.Object3D {
  let (i, n, m) = (inf(), nan(), -inf())
  let s = @core.Scene::new()
  let mat : @core.MaterialSlot = Single(@core.MeshBasicMaterial::new())
  let gs = [
    @geometries.BoxGeometry::new(width=i, height=n, depth=m),
    @geometries.PlaneGeometry::new(width=i, height=n),
    @geometries.CircleGeometry::new(
      radius=i,
      segments=8,
      theta_start=n,
      theta_length=i,
    ),
    @geometries.RingGeometry::new(
      inner_radius=n,
      outer_radius=i,
      theta_segments=8,
      phi_segments=1,
      theta_start=m,
      theta_length=i,
    ),
    @geometries.SphereGeometry::new(
      radius=i,
      width_segments=8,
      height_segments=6,
      phi_start=n,
      phi_length=i,
      theta_start=m,
      theta_length=n,
    ),
    @geometries.CylinderGeometry::new(
      radius_top=i,
      radius_bottom=n,
      height=m,
      radial_segments=8,
      height_segments=1,
      open_ended=false,
      theta_start=i,
      theta_length=n,
    ),
    @geometries.ConeGeometry::new(
      radius=n,
      height=i,
      radial_segments=8,
      height_segments=1,
      open_ended=true,
      theta_start=m,
      theta_length=i,
    ),
    @geometries.TorusGeometry::new(
      radius=i,
      tube=n,
      radial_segments=6,
      tubular_segments=8,
      arc=m,
      theta_start=i,
      theta_length=n,
    ),
    @geometries.TorusKnotGeometry::new(
      radius=n,
      tube=i,
      tubular_segments=8,
      radial_segments=4,
      p=i,
      q=n,
    ),
    @geometries.CapsuleGeometry::new(
      radius=i,
      height=n,
      cap_segments=2,
      radial_segments=4,
      height_segments=1,
    ),
    @geometries.PolyhedronGeometry::new(
      vertices=[i, 0, 0, 0, n, 0, 0, 0, m],
      indices=[0, 1, 2],
      radius=i,
      detail=0,
    ),
    @geometries.IcosahedronGeometry::new(radius=n, detail=0),
    @geometries.LatheGeometry::new(
      points=[
        @math.Vector2::new(i, 0),
        @math.Vector2::new(n, 1),
        @math.Vector2::new(1, m),
      ],
      segments=6,
      phi_start=n,
      phi_length=i,
    ),
    @geometries.TubeGeometry::new(
      path=@extras.LineCurve3::new(
        v1=@math.Vector3::new(0, 0, 0),
        v2=@math.Vector3::new(i, n, 1),
      ),
      tubular_segments=4,
      radius=i,
      radial_segments=4,
      closed=false,
    ),
  ]
  for g in gs {
    ignore(s.add(@core.Mesh::new(geometry=g, material=mat)))
  }
  s
}

///|
fn nf_edges() -> @core.Object3D {
  let s = @core.Scene::new()
  ignore(
    s.add(
      @core.LineSegments::new(
        geometry=@geometries.EdgesGeometry::new(
          geometry=@geometries.BoxGeometry::new(),
          threshold_angle=inf(),
        ),
        material=Single(@core.LineBasicMaterial::new()),
      ),
    ),
  )
  ignore(
    s.add(
      @core.LineSegments::new(
        geometry=@geometries.EdgesGeometry::new(
          geometry=@geometries.BoxGeometry::new(),
          threshold_angle=nan(),
        ),
        material=Single(@core.LineBasicMaterial::new()),
      ),
    ),
  )
  s
}

///|
fn sane_shape() -> @extras.Shape {
  let sh = @extras.Shape::new()
  ignore(sh.move_to(0, 0))
  ignore(sh.line_to(1, 0))
  ignore(sh.line_to(1, 1))
  ignore(sh.line_to(0, 0))
  sh
}

///|
fn nf_shapes() -> @core.Object3D {
  let (i, n, m) = (inf(), nan(), -inf())
  let s = @core.Scene::new()
  let mat : @core.MaterialSlot = Single(@core.MeshBasicMaterial::new())
  let a = sane_shape()
  let shape_geometry = @geometries.ShapeGeometry::new(shapes=a, curve_segments=4)
  guard a.curve.kind is Shape(path_data, current, _)
  path_data.curves.push(
    @extras.EllipseCurve::new(
      a_x=n,
      a_y=i,
      x_radius=m,
      y_radius=1,
      a_start_angle=0,
      a_end_angle=i,
      a_clockwise=false,
      a_rotation=n,
    ),
  )
  path_data.curves.push(
    @extras.SplineCurve::new(points=[
      @math.Vector2::new(i, n),
      @math.Vector2::new(0, m),
    ]),
  )
  path_data.curves.push(
    @extras.CubicBezierCurve::new(
      v0=@math.Vector2::new(n, 0),
      v1=@math.Vector2::new(0, i),
      v2=@math.Vector2::new(m, 0),
      v3=@math.Vector2::new(0, 0),
    ),
  )
  path_data.curves.push(
    @extras.QuadraticBezierCurve::new(
      v0=@math.Vector2::new(i, 0),
      v1=@math.Vector2::new(0, n),
      v2=@math.Vector2::new(0, 0),
    ),
  )
  ignore(current.current_point.set(n, i))
  let hole = @extras.Path::new()
  guard hole.curve.kind is Path(hole_data, _)
  hole_data.curves.push(
    @extras.LineCurve::new(
      v1=@math.Vector2::new(n, 0),
      v2=@math.Vector2::new(i, m),
    ),
  )
  a.holes().push(hole)
  ignore(s.add(@core.Mesh::new(geometry=shape_geometry, material=mat)))
  let b = sane_shape()
  let extrude = @geometries.ExtrudeGeometry::new(
    shapes=[b],
    depth=i,
    bevel_thickness=n,
    bevel_size=m,
    bevel_offset=n,
    bevel_segments=1,
    steps=1,
    curve_segments=4,
  )
  ignore(s.add(@core.Mesh::new(geometry=extrude, material=mat)))
  let path3 = @extras.CubicBezierCurve3::new(
    v0=@math.Vector3::new(1, 0, 0),
    v1=@math.Vector3::new(0, 1, 0),
    v2=@math.Vector3::new(0, 0, 1),
    v3=@math.Vector3::new(1, 1, 1),
  )
  ignore(
    s.add(
      @core.Mesh::new(
        geometry=@geometries.TubeGeometry::new(
          path=path3,
          tubular_segments=3,
          radius=1,
          radial_segments=3,
          closed=false,
        ),
        material=mat,
      ),
    ),
  )
  guard path3.kind is CubicBezier(cb)
  cb.v0.x = n
  cb.v1.y = i
  cb.v2.z = m
  let path4 = @extras.QuadraticBezierCurve3::new(
    v0=@math.Vector3::new(1, 0, 0),
    v1=@math.Vector3::new(0, 1, 0),
    v2=@math.Vector3::new(0, 0, 1),
  )
  ignore(
    s.add(
      @core.Mesh::new(
        geometry=@geometries.TubeGeometry::new(
          path=path4,
          tubular_segments=3,
          radius=1,
          radial_segments=3,
          closed=false,
        ),
        material=mat,
      ),
    ),
  )
  guard path4.kind is QuadraticBezier(qb)
  qb.v0.x = n
  qb.v1.y = i
  qb.v2.z = m
  s
}

///|
fn nf_catmull() -> @core.Object3D {
  let (i, n) = (inf(), nan())
  let s = @core.Scene::new()
  let path = @extras.CatmullRomCurve3::new(
    points=[
      @math.Vector3::new(1, 0, 0),
      @math.Vector3::new(0, 1, 0),
      @math.Vector3::new(0, 0, 1),
    ],
    closed=false,
    curve_type="catmullrom",
    tension=0.5,
  )
  ignore(
    s.add(
      @core.Mesh::new(
        geometry=@geometries.TubeGeometry::new(
          path~,
          tubular_segments=4,
          radius=1,
          radial_segments=3,
          closed=false,
        ),
        material=Single(@core.MeshBasicMaterial::new()),
      ),
    ),
  )
  guard path.kind is CatmullRom(cr)
  ignore(cr.points[0].set(i, 0, 0))
  cr.points[1].y = n
  cr.tension = n
  s
}

///|
/// `JSON.stringify( builder().toJSON() )` after `updateMatrixWorld( true )`.
pub fn nonfinite(name : String) -> String {
  let object = match name {
    "nf_object" => nf_object()
    "nf_cameras" => nf_cameras()
    "nf_lights" => nf_lights()
    "nf_scene" => nf_scene()
    "nf_fog_exp2" => nf_fog_exp2()
    "nf_lod" => nf_lod()
    "nf_materials" => nf_materials()
    "nf_textures" => nf_textures()
    "nf_buffer_geometry" => nf_buffer_geometry()
    "nf_instanced" => nf_instanced()
    "nf_batched" => nf_batched()
    "nf_skinned" => nf_skinned()
    "nf_animation" => nf_animation()
    "nf_geometries" => nf_geometries()
    "nf_edges" => nf_edges()
    "nf_shapes" => nf_shapes()
    "nf_catmull" => nf_catmull()
    _ => abort("unknown nonfinite scenario " + name)
  }
  object.update_matrix_world(force=true)
  object.to_json().stringify()
}

///|
/// `JSON.stringify( new ObjectLoader().parse( JSON.parse( text ) ).toJSON() )`.
pub fn roundtrip(text : String) -> String {
  let json = @json.parse(text) catch { e => abort("bad JSON: \{e}") }
  @loaders.ObjectLoader::new().parse(json).to_json().stringify()
}
