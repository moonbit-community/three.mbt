const P = Math.PI;
function product(axes) {
  let out = [{}];
  for (const [k, vs] of Object.entries(axes)) {
    const next = [];
    for (const o of out) for (const v of vs) next.push(v === undefined ? o : { ...o, [k]: v });
    out = next;
  }
  return out;
}
const specs = (name, axes) => product(axes).map(args => ({ name, args }));
const V = undefined;
export function grid(T) {
  const out = [];
  const add = (name, axes) => out.push(...specs(name, axes));
  const seg = [V, 0, 1, 2, 3, 2.5, 7];
  const size = [V, 0, 1, 2.5, -1.25, 1e-3, 1e6 + 0.1];
  add('Box', { width: size, height: [V, 0, 3.3], depth: [V, 0, -2], widthSegments: seg, heightSegments: [V, 0, 2, 2.9], depthSegments: [V, 3] });
  add('Box', { widthSegments: [120], heightSegments: [120], depthSegments: [120] }); // Uint32 index
  add('Box', { widthSegments: [-1, -2.5] });
  add('Plane', { width: size, height: size, widthSegments: seg, heightSegments: seg });
  add('Plane', { widthSegments: [255, 256, 300], heightSegments: [254, 255, 256] }); // around 65535
  const arcs = [V, 0, P / 2, P, 2 * P, 3 * P, -P / 3, 0.1];
  const starts = [V, 0, 0.5, -1, P];
  add('Circle', { radius: size, segments: [V, 0, 1, 3, 3.5, 4, 5.5, 64], thetaStart: starts, thetaLength: arcs });
  add('Ring', { innerRadius: [V, 0, 0.25, 1, 2], outerRadius: [V, 0, 1, 3], thetaSegments: [V, 0, 3, 3.5, 8], phiSegments: [V, 0, 1, 1.5, 2, 4], thetaStart: [V, 0.5], thetaLength: [V, P, 0] });
  add('Sphere', { radius: [V, 0, 1, 2.5, -1], widthSegments: [V, 0, 3, 3.5, 8], heightSegments: [V, 0, 2, 2.5, 5], phiStart: [V, 0.3], phiLength: [V, P, 0], thetaStart: [V, 0, 0.4, P], thetaLength: [V, P / 2, 0, 2 * P, P - 0.4] });
  add('Cylinder', { radiusTop: [V, 0, 0.5, -1], radiusBottom: [V, 0, 2], height: [V, 0, 3, -1], radialSegments: [V, 0, 1, 3, 3.5, 8], heightSegments: [V, 0, 1, 2, 2.5], openEnded: [V, true, false], thetaStart: [V, 0.5], thetaLength: [V, P, 0] });
  add('Cone', { radius: [V, 0, 2, -1], height: [V, 0, 3], radialSegments: [V, 0, 3, 3.5, 8], heightSegments: [V, 0, 1, 2], openEnded: [V, true], thetaStart: [V, 0.5], thetaLength: [V, P] });
  add('Capsule', { radius: [V, 0, 2, -1], height: [V, 0, 3, -1], capSegments: [V, 0, 1, 1.5, 3], radialSegments: [V, 0, 3, 3.5, 12], heightSegments: [V, 0, 1, 2.5, 4] });
  add('Torus', { radius: [V, 0, 2], tube: [V, 0, 0.1, -0.2], radialSegments: [V, 0, 1, 3, 3.5], tubularSegments: [V, 0, 1, 3, 3.5], arc: [V, P, 0], thetaStart: [V, 0.5], thetaLength: [V, P, 0] });
  add('TorusKnot', { radius: [V, 0, 2], tube: [V, 0, 0.1], tubularSegments: [V, 0, 1, 3, 3.5], radialSegments: [V, 0, 1, 3, 3.5], p: [V, 0, 1, 3, 2.5], q: [V, 0, 2, 5, -1] });
  const tet = { vertices: [1, 1, 1, -1, -1, 1, -1, 1, -1, 1, -1, -1], indices: [2, 1, 0, 0, 3, 2, 1, 3, 0, 2, 3, 1] };
  add('Polyhedron', { vertices: [V, tet.vertices], indices: [V, tet.indices], radius: [V, 0, 2.5, -1], detail: [V, 0, 1, 2, -1, -2, 0.5, 1.5] });
  add('Polyhedron', { vertices: [[0, 1, 0, 0, 0, 1, 1, 0, 0, 0, -1, 0]], indices: [[0, 1, 2, 3, 2, 1]], detail: [0, 1, 3] }); // pole vertices on the axis
  for (const n of ['Tetrahedron', 'Octahedron', 'Icosahedron', 'Dodecahedron']) add(n, { radius: [V, 0, 1, 2.5, -1], detail: [V, 0, 1, 2, 3, 5, 0.5, -1] });
  const profiles = [V, [[0, 0], [1, 0]], [[0, -1], [1, 0], [0, 1]], [[1, 0], [1, 1], [2, 2], [0.5, 3]], [[0, 0], [0, 0], [1, 1]], [[1, 1], [1, 1]], [[1, 2]], []];
  add('Lathe', { points: profiles, segments: [V, 0, 1, 3, 3.5, 24], phiStart: [V, 0.5, -1], phiLength: [V, 0, P, 2 * P, 3 * P, -1] });
  add('Lathe', { points: [[[0, 0, 5], [1, 1, 6], [2, 0, 7]]], vector3: [true], segments: [V, 4] });
  // ---- src/extras dependent ----
  const sq = [[-1, -1], [1, -1], [1, 1], [-1, 1]];
  const sqCW = [...sq].reverse();
  const hole = { points: [[-0.5, -0.5], [-0.5, 0.5], [0.5, 0.5], [0.5, -0.5]] };
  const holeCCW = { points: [...hole.points].reverse() };
  const shapes = {
    tri: { points: [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] },
    square: { points: sq }, squareCW: { points: sqCW },
    concave: { points: [[0, 0], [3, 0], [3, 1], [1, 1], [1, 3], [0, 3]] },
    holed: { points: sq, holes: [hole] }, holedCW: { points: sqCW, holes: [holeCCW] },
    twoHoles: { points: [[-3, -1], [3, -1], [3, 1], [-3, 1]], holes: [{ points: [[-2, -0.5], [-2, 0.5], [-1, 0.5], [-1, -0.5]] }, { points: [[1, -0.5], [2, -0.5], [2, 0.5], [1, 0.5]] }] },
    circle: { ops: [['absarc', 0, 0, 1, 0, 2 * P, false]] },
    ring: { ops: [['absarc', 0, 0, 2, 0, 2 * P, false]], holes: [{ ops: [['absarc', 0, 0, 1, 0, 2 * P, true]] }] },
    ellipse: { ops: [['absellipse', 1, 0.5, 2, 1, 0, 2 * P, false, 0.3]] },
    curved: { ops: [['moveTo', 0, 0], ['quadraticCurveTo', 1, 2, 2, 0], ['bezierCurveTo', 3, -1, 1, -2, 0, -1], ['closePath']] },
    spline: { ops: [['moveTo', 0, 0], ['splineThru', [[1, 1], [2, 0], [3, 1]]], ['lineTo', 3, -1], ['lineTo', 0, -1]] },
    dupEnd: { points: [...sq, sq[0]] },
    overlapping: { points: [[0, 0], [0, 0], [1, 0], [1, 1], [1 + 1e-12, 1], [0, 1], [0, 0]] },
    collinear: { points: [[0, 0], [1, 0], [2, 0], [2, 2], [1, 2], [0, 2], [0, 1]] },
    spike: { points: [[0, 0], [2, 0], [1, 0], [1, 2]] },
    sharp: { points: [[0, 0], [10, 0.01], [0, 0.02]] },
    tiny: { points: sq.map(p => p.map(x => x * 1e-6)) }, huge: { points: sq.map(p => p.map(x => x * 1e6)) },
    empty: { ops: [] }, emptyHole: { points: sq, holes: [{ ops: [] }] }, one: { points: [[1, 1]] }, two: { points: [[0, 0], [1, 1]] },
    allSame: { points: [[1, 1], [1, 1], [1, 1]] },
  };
  const names = Object.keys(shapes);
  // deterministic sampling
  let seed = 12345; const rnd = (n) => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return (seed >>> 8) % n; };
  const pick = (a) => a[rnd(a.length)];
  out.push({ name: 'Shape', args: {} });
  for (const n of names) for (const curveSegments of [V, 1, 2, 5, 12]) {
    out.push({ name: 'Shape', args: { shape: shapes[n], curveSegments } });
    out.push({ name: 'Shape', args: { shapes: [shapes[n]], curveSegments } });
    out.push({ name: 'Shape', args: { shapes: [shapes[n], shapes.holed, shapes.tri], curveSegments } });
  }
  out.push({ name: 'Shape', args: { shapes: [] } });
  const curves = [
    { type: 'LineCurve3', points: [[0, 0, 0], [0, 1, 0]] }, { type: 'LineCurve3', points: [[0, 0, 0], [3, 0, 0]] }, { type: 'LineCurve3', points: [[0, 0, 0], [0, 0, -2]] },
    { type: 'LineCurve3', points: [[1, 2, 3], [-1, 0.5, 4]] }, { type: 'LineCurve3', points: [[1, 1, 1], [1, 1, 1]] },
    { type: 'QuadraticBezierCurve3', points: [[-1, -1, 0], [-1, 1, 0], [1, 1, 0]] },
    { type: 'CubicBezierCurve3', points: [[0, 0, 0], [1, 2, 0], [2, -1, 1], [3, 0, 2]] },
    { type: 'CatmullRomCurve3', points: [[0, 0, 0], [1, 1, 0], [2, 0, 1], [3, 1, 1]] },
    { type: 'CatmullRomCurve3', points: [[0, 0, 0], [1, 1, 0], [2, 0, 1], [3, 1, 1]], closed: true },
    { type: 'CatmullRomCurve3', points: [[0, 0, 0], [2, 0, 0], [2, 2, 0], [0, 2, 0]], closed: true, curveType: 'catmullrom', tension: 0.3 },
    { type: 'CatmullRomCurve3', points: [[0, 0, 0], [1, 2, 1], [3, 1, 2]], curveType: 'chordal' },
  ];
  // defaults, every single factor, then a deterministic random sample of combinations
  out.push({ name: 'Extrude', args: {} }, { name: 'Extrude', args: { options: {} } });
  const axes = {
    curveSegments: [V, 1, 3, 12], steps: [V, 0, 1, 2, 2.5, 4], depth: [V, 0, 2.5, -1], bevelEnabled: [V, true, false],
    bevelThickness: [V, 0, 0.5], bevelSize: [V, 0, 0.1, 0.3], bevelOffset: [V, 0, 0.05, -0.02], bevelSegments: [V, 0, 1, 1.5, 2, 5],
  };
  for (const n of names) {
    out.push({ name: 'Extrude', args: { shapes: [shapes[n]] } });
    for (const [k, vs] of Object.entries(axes)) for (const v of vs) if (v !== V) out.push({ name: 'Extrude', args: { shapes: [shapes[n]], options: { [k]: v } } });
  }
  for (let i = 0; i < 3000; i++) {
    const options = {};
    for (const [k, vs] of Object.entries(axes)) { const v = pick(vs); if (v !== V) options[k] = v; }
    if (rnd(10) === 0) options.customUV = true;
    out.push({ name: 'Extrude', args: { shapes: rnd(4) === 0 ? [shapes[pick(names)], shapes[pick(names)]] : [shapes[pick(names)]], options } });
  }
  for (const n of names) for (const c of curves) for (const steps of [V, 1, 2, 8]) {
    out.push({ name: 'Extrude', args: { shapes: [shapes[n]], options: { curveSegments: 4, ...(steps === V ? {} : { steps }), extrudePath: c } } });
  }
  out.push({ name: 'Extrude', args: { shapes: [shapes.holed], options: { steps: 3, bevelEnabled: true, bevelSegments: 2, extrudePath: curves[7], customUV: true } } });
  add('Tube', { path: [V, ...curves], tubularSegments: [V, 0, 1, 2, 3, 16, 2.5], radius: [V, 0, 0.25, -1], radialSegments: [V, 0, 1, 3, 2.5], closed: [V, true] });
  const bases = [
    { name: 'Box', args: {} },
    { name: 'Box', args: { widthSegments: 2, heightSegments: 2 } },
    { name: 'Box', args: {}, nonIndexed: true },
    { name: 'Box', args: {}, translate: true },
    { name: 'Sphere', args: { widthSegments: 8, heightSegments: 6 } },
    { name: 'Sphere', args: { widthSegments: 8, heightSegments: 6 }, nonIndexed: true },
    { name: 'Cylinder', args: { radialSegments: 8 } },
    { name: 'Icosahedron', args: { detail: 1 } },
    { name: 'Plane', args: { widthSegments: 3, heightSegments: 3 } },
    { name: 'TorusKnot', args: { tubularSegments: 16, radialSegments: 4 } },
    { custom: { position: [0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0] } },
    { custom: { position: [0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0], index: [0, 1, 2, 2, 1, 3] } },
    { custom: { position: [0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0], index: [0, 1, 2, 2, 1, 3], groups: [3, 3, 0] } },
    { custom: { position: [0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0], index: [0, 1, 2, 2, 1, 3], groups: [0, 3, 0, 0, 6, 1] } },
    { custom: { position: [0, 0, 0, 0, 0, 0, 1, 0, 0, 2, 0, 0, 0, 0, 0, 1, 1, 1] } },     // degenerate
    { custom: { position: [0, 0, 0, 1, 0, 0, 2, 0, 0, 0, 1, 0] } },                       // collinear, odd count
    { custom: { position: [-0, 0, 0, 1e-5, 0, 0, 0, 1e-5, 0, 1, 2, 3, -1, 0, 0, 0, -0, 1] } },
    { custom: { position: [1e20, 0, 0, 0, 1e20, 0, 0, 0, 1e20] } },
    { custom: { position: [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0] } },     // sibling in opposite winding
    { custom: { position: [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0] } }, // duplicate edges
    { name: 'Shape', args: { shape: shapes.holed } },
    { name: 'Extrude', args: { shapes: [shapes.tri] } },
    { name: 'Tube', args: { tubularSegments: 4, radialSegments: 3 } },
    { custom: { position: [] } },
    // shared edge whose ends differ only in the sign of zero
    { custom: { position: [0, 0, 0, 1, 0, 0, 0, 1, 0, -0, 0, 0, 0, 1, 0, 1, -1, 0] } },
    { custom: { position: [0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, -0, 0, -0, 1, 1, 1] } },
    { custom: { position: [0, 1, 0, 0, 0, 0, 1, 0, 0, -0, 0, -0, 0, 1, 0, -1, 0, 0] } },
    // rounds to -0 at four decimals
    { custom: { position: [0, 0, 0, 1, 0, 0, 0, 1, 0, -0.00001, 0, 0, 0, 1, 0, 1, 1, 1] } },
  ];
  add('Edges', { geometry: [V], thresholdAngle: [V, 10] });
  add('Wireframe', { geometry: [V] });
  for (const b of bases) {
    add('Edges', { geometry: [b], thresholdAngle: [V, 0, 1, 30, 90, 180, 0.5] });
    add('Wireframe', { geometry: [b] });
  }
  add('Wireframe', { geometry: [{ name: 'Edges', args: { geometry: { name: 'Box', args: {} } } }] });
  add('Wireframe', { geometry: [{ name: 'Wireframe', args: { geometry: { name: 'Box', args: {} } } }] });
  return out;
}
