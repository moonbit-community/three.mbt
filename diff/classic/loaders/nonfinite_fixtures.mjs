// Scenes whose numeric fields hold Infinity, -Infinity and NaN, built with upstream
// three.js. `JSON.stringify` writes those as null, so these exercise every JSON number
// writer (json_uuid_diff compares `toJSON()` text with the port building the same
// scenes) and, as loaders fixtures, every reader that must accept null.
// Each builder returns an Object3D; the port mirrors them in json_uuid_diff/src/main.
export function nonfiniteBuilders(T) {
  const I = Infinity, N = NaN, M = -Infinity;
  const B = {};

  B.nf_object = () => {
    const s = new T.Scene();
    const o = new T.Object3D();
    o.position.set(I, N, M);
    o.scale.set(1, N, 1);
    o.renderOrder = I;
    o.up.set(N, I, M);
    o.pivot = new T.Vector3(I, N, 0);
    s.add(o);
    const fixed = new T.Object3D();
    fixed.matrixAutoUpdate = false;
    fixed.matrix.elements[3] = N;
    fixed.matrix.elements[12] = I;
    fixed.matrix.elements[14] = M;
    s.add(fixed);
    return s;
  };

  B.nf_cameras = () => {
    const s = new T.Scene();
    const p = new T.PerspectiveCamera(I, N, M, I);
    p.focus = N; p.zoom = I; p.filmGauge = M; p.filmOffset = N;
    p.setViewOffset(I, N, M, I, N, 1);
    s.add(p);
    const o = new T.OrthographicCamera(M, I, N, M, I, N);
    o.zoom = M;
    o.setViewOffset(1, 2, I, N, M, I);
    s.add(o);
    return s;
  };

  B.nf_lights = () => {
    const s = new T.Scene();
    const d = new T.DirectionalLight(0xffffff, I);
    d.shadow.bias = N; d.shadow.normalBias = I; d.shadow.radius = M; d.shadow.intensity = N;
    d.shadow.mapSize.set(I, N);
    d.shadow.camera.far = I; d.shadow.camera.left = M; d.shadow.camera.zoom = N;
    s.add(d); s.add(d.target);
    const p = new T.PointLight(0xff0000, N, I, M);
    p.shadow.camera.near = N; p.shadow.camera.fov = I;
    s.add(p);
    const sp = new T.SpotLight(0x00ff00, 1, I, N, I, M);
    sp.shadow.focus = N;
    s.add(sp);
    s.add(new T.RectAreaLight(0x0000ff, 1, I, N));
    s.add(new T.HemisphereLight(0xffffff, 0x000000, M));
    s.add(new T.AmbientLight(0xffffff, I));
    const lp = new T.LightProbe(undefined, N);
    lp.sh.coefficients[0].set(I, N, M);
    s.add(lp);
    return s;
  };

  B.nf_scene = () => {
    const s = new T.Scene();
    s.fog = new T.Fog(0x123456, M, I);
    s.backgroundBlurriness = I; s.backgroundIntensity = N; s.environmentIntensity = M;
    s.backgroundRotation.set(I, N, M);
    s.environmentRotation.set(N, 0, I);
    return s;
  };

  B.nf_fog_exp2 = () => {
    const s = new T.Scene();
    s.fog = new T.FogExp2(0x654321, N);
    return s;
  };

  B.nf_lod = () => {
    const s = new T.Scene();
    const l = new T.LOD();
    l.addLevel(new T.Object3D(), I, N);
    l.addLevel(new T.Object3D(), 2, I);
    s.add(l);
    return s;
  };

  B.nf_materials = () => {
    const s = new T.Scene();
    const box = new T.BoxGeometry();
    const phys = new T.MeshPhysicalMaterial();
    phys.opacity = N; phys.emissiveIntensity = M; phys.thickness = I; phys.sheenRoughness = N;
    phys.envMapRotation.set(I, N, 0);
    phys.clippingPlanes = [new T.Plane(new T.Vector3(N, 0, 1), I)];
    const sprite = new T.SpriteMaterial();
    sprite.rotation = I;
    const points = new T.PointsMaterial();
    points.size = N;
    const dashed = new T.LineDashedMaterial();
    dashed.dashSize = I; dashed.gapSize = N; dashed.scale = M; dashed.linewidth = I;
    const shader = new T.ShaderMaterial({
      uniforms: {
        a: { value: I },
        v: { value: new T.Vector3(N, 1, I) },
        p: { value: new T.Plane(new T.Vector3(0, N, 0), M) },
        arr: { value: [1, I, N] },
      },
    });
    s.add(new T.Mesh(box, phys));
    s.add(new T.Sprite(sprite));
    s.add(new T.Points(box, points));
    s.add(new T.LineSegments(box, dashed));
    s.add(new T.Mesh(box, shader));
    return s;
  };

  B.nf_textures = () => {
    const s = new T.Scene();
    const t = new T.DataTexture(new Uint8Array([1, 2, 3, 4]), 1, 1);
    t.offset.set(I, N); t.repeat.set(M, 1); t.center.set(0, I); t.rotation = N;
    const m = new T.MeshBasicMaterial();
    m.map = t;
    s.add(new T.Mesh(new T.BoxGeometry(), m));
    return s;
  };

  B.nf_buffer_geometry = () => {
    const s = new T.Scene();
    const g = new T.BufferGeometry();
    g.setAttribute('position', new T.Float32BufferAttribute([I, N, M, 0, 1, 2, 3, 4, 5], 3));
    g.morphAttributes.position = [new T.Float32BufferAttribute([N, 0, 0, I, 0, 0, M, 0, 0], 3)];
    g.addGroup(0, I, 0);
    g.computeBoundingSphere();
    s.add(new T.Mesh(g, new T.MeshBasicMaterial()));
    const ig = new T.InstancedBufferGeometry();
    ig.setAttribute('offset', new T.InstancedBufferAttribute(new Float32Array([N, I]), 1));
    s.add(new T.Mesh(ig, new T.MeshBasicMaterial()));
    return s;
  };

  B.nf_instanced = () => {
    const s = new T.Scene();
    const m = new T.InstancedMesh(new T.BoxGeometry(), new T.MeshBasicMaterial(), 2);
    m.setMatrixAt(1, new T.Matrix4().makeTranslation(I, N, M));
    m.setColorAt(0, new T.Color(N, I, M));
    m.computeBoundingSphere();
    m.computeBoundingBox();
    s.add(m);
    return s;
  };

  B.nf_batched = () => {
    const s = new T.Scene();
    const b = new T.BatchedMesh(2, 8, 8, new T.MeshBasicMaterial());
    b.computeBoundingBox();
    b.computeBoundingSphere();
    s.add(b);
    return s;
  };

  B.nf_skinned = () => {
    const s = new T.Scene();
    const bone = new T.Bone();
    const inv = new T.Matrix4();
    inv.elements[0] = N; inv.elements[13] = I;
    const skeleton = new T.Skeleton([bone], [inv]);
    const mesh = new T.SkinnedMesh(new T.BoxGeometry(), new T.MeshBasicMaterial());
    mesh.add(bone);
    const bind = new T.Matrix4();
    bind.elements[5] = M; bind.elements[12] = N;
    mesh.bind(skeleton, bind);
    s.add(mesh);
    return s;
  };

  B.nf_animation = () => {
    const o = new T.Object3D();
    o.animations = [new T.AnimationClip('nf', I, [new T.NumberKeyframeTrack('.position[x]', [0, N, 2], [I, 0, M])])];
    return o;
  };

  B.nf_geometries = () => {
    const s = new T.Scene();
    const mat = new T.MeshBasicMaterial();
    const gs = [
      new T.BoxGeometry(I, N, M),
      new T.PlaneGeometry(I, N),
      new T.CircleGeometry(I, 8, N, I),
      new T.RingGeometry(N, I, 8, 1, M, I),
      new T.SphereGeometry(I, 8, 6, N, I, M, N),
      new T.CylinderGeometry(I, N, M, 8, 1, false, I, N),
      new T.ConeGeometry(N, I, 8, 1, true, M, I),
      new T.TorusGeometry(I, N, 6, 8, M, I, N),
      new T.TorusKnotGeometry(N, I, 8, 4, I, N),
      new T.CapsuleGeometry(I, N, 2, 4, 1),
      new T.PolyhedronGeometry([I, 0, 0, 0, N, 0, 0, 0, M], [0, 1, 2], I, 0),
      new T.IcosahedronGeometry(N, 0),
      new T.LatheGeometry([new T.Vector2(I, 0), new T.Vector2(N, 1), new T.Vector2(1, M)], 6, N, I),
      new T.TubeGeometry(new T.LineCurve3(new T.Vector3(0, 0, 0), new T.Vector3(I, N, 1)), 4, I, 4, false),
    ];
    for (const g of gs) s.add(new T.Mesh(g, mat));
    return s;
  };

  // EdgesGeometry has no fromJSON upstream, so ObjectLoader cannot read it back: writer only.
  B.nf_edges = () => {
    const s = new T.Scene();
    s.add(new T.LineSegments(new T.EdgesGeometry(new T.BoxGeometry(), I), new T.LineBasicMaterial()));
    s.add(new T.LineSegments(new T.EdgesGeometry(new T.BoxGeometry(), N), new T.LineBasicMaterial()));
    return s;
  };
  B.nf_edges.writerOnly = true;

  B.nf_shapes = () => {
    const s = new T.Scene();
    const mat = new T.MeshBasicMaterial();
    const sane = () => {
      const sh = new T.Shape();
      sh.moveTo(0, 0); sh.lineTo(1, 0); sh.lineTo(1, 1); sh.lineTo(0, 0);
      return sh;
    };
    // The shapes are serialized when toJSON runs, so they are made non-finite after
    // the geometry is built from the finite outline.
    const a = sane();
    const shapeGeometry = new T.ShapeGeometry(a, 4);
    a.curves.push(new T.EllipseCurve(N, I, M, 1, 0, I, false, N));
    a.curves.push(new T.SplineCurve([new T.Vector2(I, N), new T.Vector2(0, M)]));
    a.curves.push(new T.CubicBezierCurve(new T.Vector2(N, 0), new T.Vector2(0, I), new T.Vector2(M, 0), new T.Vector2(0, 0)));
    a.curves.push(new T.QuadraticBezierCurve(new T.Vector2(I, 0), new T.Vector2(0, N), new T.Vector2(0, 0)));
    a.currentPoint.set(N, I);
    const hole = new T.Path();
    hole.curves.push(new T.LineCurve(new T.Vector2(N, 0), new T.Vector2(I, M)));
    a.holes.push(hole);
    s.add(new T.Mesh(shapeGeometry, mat));
    const b = sane();
    const extrude = new T.ExtrudeGeometry(b, { curveSegments: 4, steps: 1, depth: I, bevelThickness: N, bevelSize: M, bevelOffset: N, bevelSegments: 1 });
    s.add(new T.Mesh(extrude, mat));
    const path3 = new T.CubicBezierCurve3(new T.Vector3(1, 0, 0), new T.Vector3(0, 1, 0), new T.Vector3(0, 0, 1), new T.Vector3(1, 1, 1));
    s.add(new T.Mesh(new T.TubeGeometry(path3, 3, 1, 3, false), mat));
    path3.v0.x = N; path3.v1.y = I; path3.v2.z = M;
    const path4 = new T.QuadraticBezierCurve3(new T.Vector3(1, 0, 0), new T.Vector3(0, 1, 0), new T.Vector3(0, 0, 1));
    s.add(new T.Mesh(new T.TubeGeometry(path4, 3, 1, 3, false), mat));
    path4.v0.x = N; path4.v1.y = I; path4.v2.z = M;
    return s;
  };

  // ObjectLoader rebuilds the tube from a path whose JSON holds null: arithmetic treats it
  // as 0 on both sides (the port remembers the nulls for toJSON, extras/curve_json_nulls.mbt).
  B.nf_catmull = () => {
    const s = new T.Scene();
    const path = new T.CatmullRomCurve3([new T.Vector3(1, 0, 0), new T.Vector3(0, 1, 0), new T.Vector3(0, 0, 1)], false, 'catmullrom', 0.5);
    s.add(new T.Mesh(new T.TubeGeometry(path, 4, 1, 3, false), new T.MeshBasicMaterial()));
    path.points[0].set(I, 0, 0); path.points[1].y = N; path.tension = N;
    return s;
  };

  return B;
}
