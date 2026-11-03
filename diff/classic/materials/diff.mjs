// Differential check of the material port against upstream r187 sources under Node.
// node diff.mjs [<path to the harness cjs build>] [failures to print]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { upstreamURL } from '../../lib/env.mjs';
const THREE = await import(upstreamURL('src/Three.Core.js'));
const { cloneUniforms, mergeUniforms } = await import(upstreamURL('src/renderers/shaders/UniformsUtils.js'));
const require = createRequire(import.meta.url);
const realLog = console.log;
const silent = (f) => { const l=console.log, w=console.warn, e=console.error; console.log=console.warn=console.error=()=>{}; try { return f(); } finally { console.log=l; console.warn=w; console.error=e; } };
const { run } = require(path.resolve(process.argv[2] || fileURLToPath(new URL('./mbt/_build/js/debug/build/bobzhang/three-diff-materials/harness/harness.js', import.meta.url))));
const KEYS = JSON.parse(fs.readFileSync(new URL('./keys.json', import.meta.url)));
const CLASSES = ['Material','LineBasicMaterial','LineDashedMaterial','MeshBasicMaterial','MeshDepthMaterial','MeshDistanceMaterial','MeshLambertMaterial','MeshMatcapMaterial','MeshNormalMaterial','MeshPhongMaterial','MeshPhysicalMaterial','MeshStandardMaterial','MeshToonMaterial','PointsMaterial','RawShaderMaterial','ShaderMaterial','ShadowMaterial','SpriteMaterial'];

// ---- encoding of upstream state, same shape as dump() in harness.mbt
const jnum = v => Number.isNaN(v) ? 'NaN' : v === Infinity ? 'Infinity' : v === -Infinity ? '-Infinity' : v;
const uniformEnc = v => {
  if (v === null || v === undefined) return null;
  if (typeof v === 'number') return jnum(v);
  if (typeof v === 'boolean') return v;
  if (Array.isArray(v)) return v.map(uniformEnc);
  if (v.isVector2) return { v2: v.toArray() };
  if (v.isVector3) return { v3: v.toArray() };
  if (v.isVector4) return { v4: v.toArray() };
  if (v.isColor) return { c: [v.r, v.g, v.b] };
  if (v.isQuaternion) return { q: v.toArray() };
  if (v.isMatrix3) return { m3: v.toArray() };
  if (v.isMatrix4) return { m4: v.toArray() };
  if (v.isPlane) return { p: [[v.normal.x, v.normal.y, v.normal.z, v.constant]] };
  if (v.isTexture) return { t: v.name };
  if (ArrayBuffer.isView(v)) return { typed: true };
  const o = {}; for (const k in v) o[k] = uniformEnc(v[k]); return { s: o };
};
const enc = (k, v) => {
  if (v === undefined || v === null) return null;
  if (typeof v === 'number') return jnum(v);
  if (typeof v !== 'object') return v;
  if (v.isColor) return [jnum(v.r), jnum(v.g), jnum(v.b)];
  if (v.isVector2) return [v.x, v.y];
  if (v.isEuler) return [v.x, v.y, v.z, v.order];
  if (v.isTexture) return v.uuid;
  if (k === 'clippingPlanes') return v.map(p => [p.normal.x, p.normal.y, p.normal.z, p.constant]);
  if (k === 'uniforms') { const o = {}; for (const n in v) o[n] = uniformEnc(v[n].value); return o; }
  if (k === 'uniformsGroups') return v.map(g => ({ name: g.name, usage: g.usage }));
  if (k === 'extensions') return { clipCullDistance: !!v.clipCullDistance, multiDraw: !!v.multiDraw };
  return v;
};
const dump = (m) => {
  const o = { uuid_set: m.uuid !== '' };
  for (const k of KEYS) o[k] = enc(k, k === 'alphaTest' ? m.alphaTest : m[k]);
  return o;
};

// ---- decoding of request params to upstream objects
const texCache = new Map();
const tex = (n) => { if (!texCache.has(n)) { const t = new THREE.Texture(); t.uuid = 'tex-' + n; t.source.uuid = 'src-' + n; t.name = n; texCache.set(n, t); } return texCache.get(n); };
const plane = a => new THREE.Plane(new THREE.Vector3(a[0], a[1], a[2]), a[3]);
const uniformDec = j => {
  if (j === null || typeof j !== 'object') return j;
  if ('int' in j) return j.int;
  if ('numbers' in j) return j.numbers.slice();
  if ('v2' in j) return new THREE.Vector2().fromArray(j.v2);
  if ('v3' in j) return new THREE.Vector3().fromArray(j.v3);
  if ('v4' in j) return new THREE.Vector4().fromArray(j.v4);
  if ('c' in j) return new THREE.Color(j.c);
  if ('q' in j) return new THREE.Quaternion(...j.q);
  if ('m3' in j) return new THREE.Matrix3().fromArray(j.m3);
  if ('m4' in j) return new THREE.Matrix4().fromArray(j.m4);
  if ('p' in j) return plane(j.p);
  if ('t' in j) return tex(j.t);
  if ('rtt' in j) { const t = tex(j.rtt); t.isRenderTargetTexture = true; return t; }
  if ('array' in j) return j.array.map(uniformDec);
  if ('s' in j) { const o = {}; for (const k in j.s) o[k] = uniformDec(j.s[k]); return o; }
  throw new Error('uniformDec');
};
const param = j => {
  if (j === null || typeof j !== 'object') return j;
  if ('$undefined' in j) return undefined;
  if ('$color' in j) return new THREE.Color(j.$color[0], j.$color[1], j.$color[2]);
  if ('$v2' in j) return new THREE.Vector2(...j.$v2);
  if ('$euler' in j) return new THREE.Euler().fromArray(j.$euler);
  if ('$texture' in j) return tex(j.$texture);
  if ('$planes' in j) return j.$planes.map(plane);
  if ('$uniforms' in j) { const o = {}; for (const k in j.$uniforms) o[k] = { value: uniformDec(j.$uniforms[k]) }; return o; }
  if ('$groups' in j) return j.$groups.map(n => new THREE.UniformsGroup().setName(n));
  if ('$defines' in j) return j.$defines;
  if ('$ext' in j) return { ...j.$ext };
  if ('$attrs' in j) return j.$attrs;
  if ('$user' in j) return j.$user;
  throw new Error('param');
};
const params = p => { const o = {}; for (const k in p) o[k] = param(p[k]); return o; };

const sharedOf = (a, b) => {
  const r = {}; for (const k in a) { const x = a[k].value, y = b[k].value; r[k] = (x !== null && typeof x === 'object') ? x === y : true; } return r;
};

// ---- sample values
const S = {
  name: 'sample', type: 'Custom', uuid: 'u', version: 9, blending: 5, side: 2, vertexColors: true, opacity: 0.25, transparent: true, alphaHash: true,
  blendSrc: 201, blendDst: 200, blendEquation: 101, blendSrcAlpha: 202, blendDstAlpha: 203, blendEquationAlpha: 102,
  blendColor: 0x123456, blendAlpha: 0.75, depthFunc: 6, depthTest: false, depthWrite: false, stencilWriteMask: 0x0f, stencilFunc: 513, stencilRef: 7,
  stencilFuncMask: 0xf0, stencilFail: 0, stencilZFail: 7681, stencilZPass: 7682, stencilWrite: true,
  clippingPlanes: { $planes: [[0, 1, 0, 2], [1, 0, 0, -3]] }, clipIntersection: true, clipShadows: true, shadowSide: 1, colorWrite: false,
  precision: 'lowp', polygonOffset: true, polygonOffsetFactor: 1.5, polygonOffsetUnits: 2.5, dithering: true, alphaToCoverage: true,
  premultipliedAlpha: true, forceSinglePass: false, allowOverride: false, visible: false, toneMapped: false, userData: { $user: { a: 1, b: [2, { c: 3 }] } },
  alphaTest: 0.5,
  // subclass
  color: 0x112233, map: { $texture: 'map' }, linewidth: 3, linecap: 'butt', linejoin: 'bevel', fog: false, scale: 2, dashSize: 4, gapSize: 5,
  lightMap: { $texture: 'light' }, lightMapIntensity: 0.5, aoMap: { $texture: 'ao' }, aoMapIntensity: 0.25, specularMap: { $texture: 'spec' },
  alphaMap: { $texture: 'alpha' }, envMap: { $texture: 'env' }, envMapRotation: { $euler: [0.1, 0.2, 0.3, 'ZYX'] }, envMapIntensity: 2.5, combine: 1,
  reflectivity: 0.75, refractionRatio: 0.5, wireframe: true, wireframeLinewidth: 2, wireframeLinecap: 'butt', wireframeLinejoin: 'miter',
  depthPacking: 3201, displacementMap: { $texture: 'disp' }, displacementScale: 2, displacementBias: 0.5, emissive: 0x332211, emissiveIntensity: 0.5,
  emissiveMap: { $texture: 'emis' }, bumpMap: { $texture: 'bump' }, bumpScale: 0.5, normalMap: { $texture: 'norm' }, normalMapType: 1,
  normalScale: { $v2: [2, 3] }, flatShading: true, matcap: { $texture: 'matcap' }, gradientMap: { $texture: 'grad' }, specular: 0x445566, shininess: 12,
  roughness: 0.25, metalness: 0.75, roughnessMap: { $texture: 'rough' }, metalnessMap: { $texture: 'metal' }, size: 3, sizeAttenuation: false, rotation: 1.25,
  defines: { $defines: { A: 1, B: 'x' } }, uniforms: { $uniforms: { n: 1.5 } }, uniformsGroups: { $groups: ['g1', 'g2'] }, vertexShader: 'vs', fragmentShader: 'fs',
  lights: true, clipping: true, extensions: { $ext: { clipCullDistance: true, multiDraw: false } }, defaultAttributeValues: { $attrs: { color: [0, 0, 0] } },
  index0AttributeName: 'position', uniformsNeedUpdate: true, glslVersion: '300 es',
  anisotropyRotation: 0.5, anisotropyMap: { $texture: 'aniso' }, clearcoatMap: { $texture: 'cc' }, clearcoatRoughness: 0.5, clearcoatRoughnessMap: { $texture: 'ccr' },
  clearcoatNormalScale: { $v2: [4, 5] }, clearcoatNormalMap: { $texture: 'ccn' }, diffuseRoughnessMap: { $texture: 'dr' }, ior: 1.75, iridescenceMap: { $texture: 'ir' },
  iridescenceIOR: 1.5, iridescenceThicknessMinimum: 50, iridescenceThicknessMaximum: 500, iridescenceThicknessMap: { $texture: 'irt' }, sheenColor: 0x556677,
  sheenColorMap: { $texture: 'shc' }, sheenRoughness: 0.5, sheenRoughnessMap: { $texture: 'shr' }, transmissionMap: { $texture: 'tr' }, thickness: 2, thicknessMap: { $texture: 'th' },
  attenuationDistance: 10, attenuationColor: 0x667788, specularIntensity: 0.5, specularIntensityMap: { $texture: 'si' }, specularColor: 0x778899,
  specularColorMap: { $texture: 'sc' },
  anisotropy: 0.5, clearcoat: 0.5, diffuseRoughness: 0.5, dispersion: 0.5, iridescence: 0.5, retroreflectivity: 0.5, sheen: 0.5, transmission: 0.5,
};
const missing = KEYS.filter(k => !(k in S) && k !== 'type' && k !== 'version');
if (missing.length) { realLog('sample table lacks', missing); }
const UNKNOWN = ['notAProperty', 'needsUpdate', 'id'];

// ---- comparison
let checks = 0, failures = 0; const failed = [];
const norm = v => JSON.parse(JSON.stringify(v));
const eq = (a, b) => {
  if (a === b) return true;
  if (typeof a === 'number' && typeof b === 'number') return a === b;
  if (Array.isArray(a) !== Array.isArray(b)) return false;
  if (a && b && typeof a === 'object' && typeof b === 'object') {
    const ka = Object.keys(a), kb = Object.keys(b);
    if (ka.length !== kb.length) return false;
    for (const k of ka) if (!(k in b) || !eq(a[k], b[k])) return false;
    return true;
  }
  return false;
};
const orderEq = (a, b) => { // key order too, since toJSON output order is observable
  if (a && b && typeof a === 'object' && !Array.isArray(a)) { const ka = Object.keys(a), kb = Object.keys(b); if (ka.join() !== kb.join()) return false; return ka.every(k => orderEq(a[k], b[k])); }
  return true;
};
const firstDiff = (a, b, path = '') => {
  if (eq(a, b)) return null;
  if (a && b && typeof a === 'object' && typeof b === 'object') {
    for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) { const d = firstDiff(a[k], b[k], path + '.' + k); if (d) return d; }
  }
  return `${path}: upstream ${JSON.stringify(a)} port ${JSON.stringify(b)}`;
};
const check = (label, up, port, opts = {}) => {
  checks++;
  const u = norm(up), p = norm(port);
  let ok = eq(u, p);
  if (ok && opts.order && !orderEq(u, p)) { ok = false; failed.push(label + ': key order: upstream ' + Object.keys(u).join() + ' port ' + Object.keys(p).join()); failures++; return; }
  if (!ok) { failures++; failed.push(label + ' ' + firstDiff(u, p)); }
};
const mbt = (req) => {
  try { return { v: JSON.parse(silent(() => run(JSON.stringify(req)))) }; } catch (e) { if (e instanceof SyntaxError) throw e; return { threw: true, e }; }
};
const js = (f) => { try { return { v: silent(f) }; } catch (e) { return { threw: true, e }; } };
// After fromJSON, upstream holds the `null` that JSON.stringify wrote for a non-finite
// number; the port's Double holds NaN, which toJSON writes back as null (the loaders
// harness compares that text). Only that pair is equated, only for fromjson, and counted.
let nullAsNaN = 0;
const nullToNaN = (u, p) => {
  if (u === null && p === 'NaN') { nullAsNaN++; return 'NaN'; }
  if (u && p && typeof u === 'object' && typeof p === 'object') {
    const r = Array.isArray(u) ? [] : {};
    for (const k in u) r[k] = k in p ? nullToNaN(u[k], p[k]) : u[k];
    return r;
  }
  return u;
};
const both = (label, up, req, opts) => {
  const u = js(up), p = mbt(req);
  checks++;
  if (!!u.threw !== !!p.threw) { failures++; failed.push(`${label}: upstream ${u.threw ? 'threw ' + u.e.message : 'ok'}, port ${p.threw ? 'threw ' + p.e : 'ok'}`); return; }
  checks--;
  if (u.threw) { checks++; return; }
  check(label, req && req.op === 'fromjson' ? nullToNaN(norm(u.v), norm(p.v)) : u.v, p.v, opts);
};
const make = (c, p) => { const m = new THREE[c](); if (p) m.setValues(params(p)); return m; };
const validFor = (c) => { const m = new THREE[c](); const p = {}; for (const k in S) if (m[k] !== undefined || (m[k] === null)) p[k] = S[k]; return p; };

// 1. constructor defaults, and that the key table covers every upstream property
for (const c of CLASSES) {
  both(`defaults ${c}`, () => dump(new THREE[c]()), { op: 'construct', cls: c });
  const m = new THREE[c]();
  for (const k of Object.keys(m)) {
    if (k.startsWith('is') || k === 'uuid') continue;
    const key = k.replace(/^_/, '');
    checks++;
    if (!KEYS.includes(key)) { failures++; failed.push(`property ${c}.${k} has no field in the port`); }
  }
  both(`cachekey ${c}`, () => new THREE[c]().customProgramCacheKey(), { op: 'cachekey', cls: c });
  both(`ids ${c}`, () => { const a = new THREE[c](), b = new THREE[c](); return b.id - a.id; }, { op: 'ids', cls: c });
}

// 2. setValues, key by key on every class, which separates null from undefined properties
for (const c of CLASSES) {
  for (const k of [...Object.keys(S), ...UNKNOWN]) {
    const v = S[k] === undefined ? 1 : S[k];
    both(`setValues ${c}.${k}`, () => dump(make(c, { [k]: v })), { op: 'setvalues', cls: c, params: { [k]: v } });
    both(`setValues ${c}.${k} undefined`, () => dump(make(c, { [k]: { $undefined: true } })), { op: 'setvalues', cls: c, params: { [k]: { $undefined: true } } });
  }
  // the forms Color.set takes
  for (const key of ['color', 'blendColor', 'emissive', 'specular', 'sheenColor', 'attenuationColor', 'specularColor']) {
    for (const value of [0xff8000, '#102030', 'rgb(1,2,3)', 'skyblue', { $color: [0.1, 0.2, 0.3] }, null]) {
      both(`setValues ${c}.${key}=${JSON.stringify(value)}`, () => dump(make(c, { [key]: value })), { op: 'setvalues', cls: c, params: { [key]: value } });
    }
  }
  for (const key of ['map', 'shadowSide', 'precision', 'glslVersion', 'normalScale', 'envMapRotation', 'clippingPlanes']) {
    both(`setValues ${c}.${key}=null`, () => dump(make(c, { [key]: null })), { op: 'setvalues', cls: c, params: { [key]: null } });
  }
  both(`setValues ${c} everything`, () => dump(make(c, validFor(c))), { op: 'setvalues', cls: c, params: validFor(c) });
}

// 3. copy and clone on a fully non-default source, and the throw matrix across classes
for (const c of CLASSES) {
  const p = validFor(c);
  both(`copy ${c}`, () => {
    const t = new THREE[c]();
    const s = make(c, p);
    if (s.uniforms) s.index0AttributeName = 'position';
    t.copy(s);
    return { dump: dump(t), ...(t.uniforms ? { shared: sharedOf(s.uniforms, t.uniforms) } : {}) };
  }, { op: 'copy', target: c, source: c, params: p, index0: 'position' });
  both(`copy ${c} dirty target`, () => {
    const t = make(c, p), s = new THREE[c]();
    t.copy(s);
    return { dump: dump(t), ...(t.uniforms ? { shared: sharedOf(s.uniforms, t.uniforms) } : {}) };
  }, { op: 'copy', target: c, source: c, targetParams: p });
  both(`clone ${c}`, () => {
    const s = make(c, p); const m = s.clone();
    let n = false; m.addEventListener('dispose', () => n = true); m.dispose();
    return { dump: dump(m), sameUuid: m.uuid === s.uuid, dispose: n };
  }, { op: 'clone', cls: c, params: p });
  for (const d of CLASSES) {
    const q = validFor(d);
    both(`copy ${c} <- ${d}`, () => {
      const s = make(d, q), t = new THREE[c]();
      t.copy(s);
      const r = { dump: dump(t) };
      if (t.uniforms && s.uniforms) r.shared = sharedOf(s.uniforms, t.uniforms);
      return r;
    }, { op: 'copy', target: c, source: d, params: q });
  }
}

// 4. toJSON: defaults and full, root and with a meta, including key order
const texLike = v => v;
for (const c of CLASSES) {
  const p = validFor(c);
  for (const [label, q] of [['default', {}], ['full', p]]) {
    both(`toJSON ${label} ${c}`, () => { const m = make(c, q); m.uuid = 'mat'; return { json: m.toJSON() }; },
      { op: 'tojson', cls: c, params: q }, { order: true });
    both(`toJSON meta ${label} ${c}`, () => {
      const m = make(c, q); m.uuid = 'mat';
      const meta = { textures: {}, images: {} };
      const json = m.toJSON(meta);
      return { json, textures: Object.keys(meta.textures), images: Object.keys(meta.images) };
    }, { op: 'tojson', cls: c, params: q, meta: true }, { order: true });
  }
  // 5. fromJSON, on what toJSON wrote and on a fresh instance of the same class
  const names = [...new Set(Object.values(p).filter(v => v && v.$texture).map(v => v.$texture))];
  const json = JSON.parse(JSON.stringify(silent(() => { const m = make(c, p); m.uuid = 'mat'; return m.toJSON(); })));
  both(`fromJSON full ${c}`, () => {
    const lib = {}; for (const n of names) lib['tex-' + n] = tex(n);
    return dump(new THREE[c]().fromJSON(json, lib));
  }, { op: 'fromjson', cls: c, json, textures: names });
  both(`fromJSON missing textures ${c}`, () => dump(new THREE[c]().fromJSON(json, {})), { op: 'fromjson', cls: c, json, textures: [] });
  both(`fromJSON undefined textures ${c}`, () => dump(new THREE[c]().fromJSON(json)), { op: 'fromjson', cls: c, json, noTextures: true });
  const jsonDefault = JSON.parse(JSON.stringify(silent(() => new THREE[c]().toJSON())));
  both(`fromJSON default ${c}`, () => dump(new THREE[c]().fromJSON(jsonDefault, {})), { op: 'fromjson', cls: c, json: jsonDefault, textures: [] });
  for (const d of ['MeshBasicMaterial', 'MeshPhysicalMaterial', 'ShaderMaterial', 'SpriteMaterial']) {
    const other = JSON.parse(JSON.stringify(silent(() => make(d, validFor(d)).toJSON())));
    both(`fromJSON ${d} json on ${c}`, () => dump(new THREE[c]().fromJSON(other, new Proxy({}, { get: (_, k) => undefined }))), { op: 'fromjson', cls: c, json: other, textures: [] });
  }
  for (const legacy of [{ vertexColors: 2 }, { vertexColors: 0 }, { normalScale: 3 }, { iridescenceThicknessRange: [1, 2] }, { blendSrcAlpha: null }, { shadowSide: null }, { sheenColor: 0x102030 }]) {
    both(`fromJSON legacy ${JSON.stringify(legacy)} ${c}`, () => dump(new THREE[c]().fromJSON(legacy, {})), { op: 'fromjson', cls: c, json: legacy, textures: [] });
  }
}

// 6. ShaderMaterial uniforms of every kind
const UNIFORMS = {
  f: 1.5, zero: 0, b: true, nul: null, i: { int: 3 }, nums: { numbers: [1, 2, 3] }, v2: { v2: [1, 2] }, v3: { v3: [1, 2, 3] }, v4: { v4: [1, 2, 3, 4] },
  c: { c: 0x102030 }, q: { q: [0, 0, 0, 1] }, m3: { m3: [1, 2, 3, 4, 5, 6, 7, 8, 9] }, m4: { m4: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16] },
  p: { p: [0, 1, 0, 2] }, t: { t: 'utex' }, rtt: { rtt: 'urtt' },
  av: { array: [{ v3: [1, 2, 3] }, { v3: [4, 5, 6] }] }, an: { array: [1.5, { v3: [1, 2, 3] }] }, ae: { array: [] }, s: { s: { a: 1, b: { v2: [1, 2] } } },
};
const noRtt = { ...UNIFORMS }; delete noRtt.rtt;
for (const c of ['ShaderMaterial', 'RawShaderMaterial']) {
  const q = { uniforms: { $uniforms: UNIFORMS } };
  both(`shader copy uniforms ${c}`, () => {
    const s = make(c, q), t = new THREE[c]().copy(s);
    return { dump: dump(t), shared: sharedOf(s.uniforms, t.uniforms) };
  }, { op: 'copy', target: c, source: c, params: q });
  const q2 = { uniforms: { $uniforms: noRtt } };
  both(`shader toJSON uniforms ${c}`, () => { const m = make(c, q2); m.uuid = 'mat'; return { json: m.toJSON() }; }, { op: 'tojson', cls: c, params: q2 }, { order: true });
  both(`shader toJSON meta uniforms ${c}`, () => {
    const m = make(c, q2); m.uuid = 'mat'; const meta = { textures: {}, images: {} }; const json = m.toJSON(meta);
    return { json, textures: Object.keys(meta.textures), images: Object.keys(meta.images) };
  }, { op: 'tojson', cls: c, params: q2, meta: true }, { order: true });
  const json = JSON.parse(JSON.stringify(silent(() => make(c, q2).toJSON())));
  both(`shader fromJSON uniforms ${c}`, () => dump(new THREE[c]().fromJSON(json, { 'tex-utex': tex('utex') })), { op: 'fromjson', cls: c, json, textures: ['utex'] });
  both(`shader fromJSON undefined textures ${c}`, () => dump(new THREE[c]().fromJSON(json)), { op: 'fromjson', cls: c, json, noTextures: true });
}

// 7. NaN and Infinity through the crossing-zero setters
both('numeric edges', () => {
  const m = new THREE.MeshPhysicalMaterial();
  m.alphaTest = NaN; m.sheen = NaN; m.clearcoat = Infinity; m.clearcoat = NaN; m.alphaTest = -1;
  return dump(m);
}, { op: 'numericEdges' });

realLog(`${checks} checks, ${failures} failures (fromJSON: ${nullAsNaN} upstream null held as NaN by the port)`);
const groups = {};
for (const f of failed) { const k = f.split(' ').slice(0, 2).join(' '); (groups[k] ||= []).push(f); }
realLog(failed.slice(0, Number(process.argv[3] || 40)).join('\n'));
