// Compares src/renderers/shaders (ShaderChunk, ShaderLib, UniformsLib, vsm, the DFG LUT) with
// upstream: every string byte for byte, every uniform value, key order and aliasing.
// usage: node compare.mjs [<built dump.js>]   Exit 1 on any difference. The default is this
// module's own build (moon build --target js here); inject.sh passes a sandbox build.
import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { upstreamPath } from '../../lib/env.mjs';
const up = upstreamPath('src/renderers/shaders');
const imp = (p) => import(pathToFileURL(p).href);
const dumpJs = process.argv[2] ?? path.join(path.dirname(fileURLToPath(import.meta.url)), '_build/js/debug/build/bobzhang/three-diff-shaders/dump/dump.js');
if (!fs.existsSync(dumpJs)) { console.log(`missing ${dumpJs}; build first (moon build --target js)`); process.exit(2); }
const { ShaderChunk } = await imp(up + '/ShaderChunk.js');
const { ShaderLib } = await imp(up + '/ShaderLib.js');
const { UniformsLib } = await imp(up + '/UniformsLib.js');
const { getDFGLUT } = await imp(up + '/DFGLUTData.js');
const vsm = await imp(up + '/ShaderLib/vsm.glsl.js');
const defV = (await imp(up + '/ShaderChunk/default_vertex.glsl.js')).default;
const defF = (await imp(up + '/ShaderChunk/default_fragment.glsl.js')).default;
const port = (await imp(dumpJs)).dump();

let diffs = 0; const counts = {};
const count = (k, n = 1) => { counts[k] = (counts[k] ?? 0) + n; };
const bad = (msg) => { diffs++; if (diffs <= 25) console.log('DIFF', msg); };
function strEq(where, a, b) {
  count('strings compared'); count('code units compared', b.length);
  if (a === b && crypto.createHash('sha256').update(a).digest('hex') === crypto.createHash('sha256').update(b).digest('hex')) return;
  let i = 0; while (i < a.length && a.charCodeAt(i) === b.charCodeAt(i)) i++;
  bad(`${where}: differs at ${i}: port ${JSON.stringify(a.slice(Math.max(0, i - 10), i + 10))} upstream ${JSON.stringify(b.slice(Math.max(0, i - 10), i + 10))}`);
}
function numEq(where, a, b) { count('numbers compared'); if (!Object.is(a, b)) bad(`${where}: port ${a} upstream ${b}`); }
function keysEq(where, a, b) { count('key lists compared'); if (JSON.stringify(a) !== JSON.stringify(b)) bad(`${where}: port keys ${a} upstream ${b}`); }

// Canonical form of an upstream value, same shape as ser() in dump.mbt.
function canon(v) {
  if (v === null) return { t: 'null' };
  if (typeof v === 'number') return { t: 'number', v };
  if (v.isColor) return { t: 'color', r: v.r, g: v.g, b: v.b, ref: v };
  if (v.isVector2) return { t: 'vector2', x: v.x, y: v.y, ref: v };
  if (v.isVector3) return { t: 'vector3', x: v.x, y: v.y, z: v.z, ref: v };
  if (v.isMatrix3) return { t: 'matrix3', e: v.elements, ref: v };
  if (Array.isArray(v)) return { t: 'array', items: v.map(canon), ref: v };
  throw new Error('unhandled upstream value ' + v);
}
function valEq(where, p, u) {
  count('uniform values compared');
  if (p.t !== u.t) return bad(`${where}: type port ${p.t} upstream ${u.t}`);
  count('value type:' + u.t);
  for (const k of ['v', 'r', 'g', 'b', 'x', 'y', 'z']) if (k in u) numEq(`${where}.${k}`, p[k], u[k]);
  if (u.t === 'matrix3') { keysEq(where, [p.e.length], [u.e.length]); u.e.forEach((x, i) => numEq(`${where}.e${i}`, p.e[i], x)); }
  if (u.t === 'array') { keysEq(where, [p.items.length], [u.items.length]); }
}
// Aliasing: two slots share an object in the port iff they do upstream.
const aliasP = new Map(), aliasU = new Map(), slots = [];
function slot(where, p, u) { if (u.ref === undefined) return; slots.push(where);
  const id = (m, o) => { if (!m.has(o)) m.set(o, m.size); return m.get(o); };
  count('aliasing slots compared');
  if (id(aliasP, p.ref) !== id(aliasU, u.ref)) bad(`${where}: aliasing differs from upstream`); }

function uniformsEq(where, pList, uObj) {
  keysEq(where, pList.map((e) => e[0]), Object.keys(uObj));
  for (const [name, val] of pList) {
    const uu = uObj[name]; if (!uu) continue;
    const c = canon(uu.value); valEq(`${where}.${name}`, val, c); slot(`${where}.${name}`, val, c);
    const extra = Object.keys(uu).filter((k) => k !== 'value' && k !== 'properties');
    if (extra.length) bad(`${where}.${name}: unmodelled uniform fields ${extra}`);
    const prop = port.properties.find((e) => e[0] === name);
    if ((uu.properties === undefined) !== (prop === undefined)) bad(`${where}.${name}: properties presence differs`);
    if (uu.properties !== undefined && prop !== undefined) {
      count('properties compared');
      strEq(`${where}.${name}.properties`, prop[1], JSON.stringify(uu.properties));
      if (uu.properties !== UniformsLib.lights[name].properties) bad(`${where}.${name}: upstream properties not shared by reference`);
    }
  }
}

keysEq('ShaderChunk', port.chunks.map((e) => e[0]), Object.keys(ShaderChunk));
for (const [k, v] of port.chunks) if (k in ShaderChunk) strEq(`ShaderChunk.${k}`, v, ShaderChunk[k]);
strEq('vsm.vertex', port.vsm[0], vsm.vertex); strEq('vsm.fragment', port.vsm[1], vsm.fragment);
strEq('core default_vertex', port.defaults[0], defV); strEq('core default_fragment', port.defaults[1], defF);

keysEq('UniformsLib', port.groups.map((e) => e[0]), Object.keys(UniformsLib));
for (const [g, list] of port.groups) if (g in UniformsLib) uniformsEq(`UniformsLib.${g}`, list, UniformsLib[g]);

keysEq('ShaderLib', port.lib.map((e) => e[0]), Object.keys(ShaderLib));
for (const [k, list, vs, fs_] of port.lib) {
  const e = ShaderLib[k]; if (!e) continue;
  keysEq(`ShaderLib.${k} fields`, Object.keys(e), ['uniforms', 'vertexShader', 'fragmentShader']);
  uniformsEq(`ShaderLib.${k}`, list, e.uniforms);
  strEq(`ShaderLib.${k}.vertexShader`, vs, e.vertexShader);
  strEq(`ShaderLib.${k}.fragmentShader`, fs_, e.fragmentShader);
}

// Every properties entry upstream, and none extra.
const upProps = Object.entries(UniformsLib.lights).filter(([, u]) => u.properties).map(([k]) => k);
keysEq('properties', port.properties.map((e) => e[0]), upProps);

const u = getDFGLUT(), p = port.dfg;
const same = (k, a, b) => { count('DFG fields compared'); if (!Object.is(a, b)) bad(`DFG ${k}: port ${a} upstream ${b}`); };
if (u !== getDFGLUT()) bad('upstream not memoized'); if (port.dfgSame !== true) bad('DFG not memoized');
for (const k of ['name', 'format', 'type', 'magFilter', 'minFilter', 'wrapS', 'wrapT', 'mapping', 'channel', 'anisotropy',
  'colorSpace', 'generateMipmaps', 'mipmapsAutoUpdate', 'premultiplyAlpha', 'flipY', 'unpackAlignment', 'matrixAutoUpdate', 'rotation', 'version'])
  same(k, p[k], u[k]);
same('internalFormat', p.internalFormat ?? null, u.internalFormat);
same('width', p.width, u.image.width); same('height', p.height, u.image.height);
same('sourceVersion', p.sourceVersion, u.source.version); same('isDataTexture', p.isDataTexture, u.isDataTexture);
same('mipmapsLength', p.mipmapsLength, u.mipmaps.length);
same('offset', JSON.stringify(p.offset), JSON.stringify(u.offset.toArray()));
same('repeat', JSON.stringify(p.repeat), JSON.stringify(u.repeat.toArray()));
same('center', JSON.stringify(p.center), JSON.stringify(u.center.toArray()));
same('matrix', JSON.stringify(p.matrix), JSON.stringify(u.matrix.elements));
same('data class', p.data.constructor.name, u.image.data.constructor.name);
same('data length', p.data.length, u.image.data.length);
for (let i = 0; i < u.image.data.length; i++) numEq(`DFG data[${i}]`, p.data[i], u.image.data[i]);

console.log(counts);
console.log(diffs === 0 ? 'NO DIFFERENCES' : `${diffs} DIFFERENCES`);
console.log(`shaders: ${counts['strings compared']} strings (${counts['code units compared']} code units), ${counts['uniform values compared']} uniform values, ${counts['numbers compared']} numbers, ${diffs} differences`);
process.exit(diffs === 0 ? 0 : 1);
