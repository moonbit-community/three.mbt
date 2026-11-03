// Tiny fixtures for the MoonBit unit tests (src/addons/loaders/*_wbtest.mbt): prints
// MoonBit byte-array literals and upstream's decoded values; files go to
// OUT/addons_hdr/gen. Needs OpenEXR's exrmetrics. Run when changing those tests:
//   node tiny.mjs
import fs from 'node:fs';
import zlib from 'node:zlib';
import { execFileSync } from 'node:child_process';
import { EX, OUT_HDR } from './paths.mjs';
const ex = EX;
process.chdir(OUT_HDR);
fs.mkdirSync('gen', { recursive: true });
const { EXRLoader } = await import(ex + 'jsm/loaders/EXRLoader.js');
const { HDRLoader } = await import(ex + 'jsm/loaders/HDRLoader.js');
const F = await import(ex + 'jsm/libs/fflate.module.js');
// 3x2 RGB half, NO_COMPRESSION, written by hand
const halfs = [0x3c00, 0x4000, 0x3800, 0x0001, 0x7bff, 0xbc00, 0x3555, 0x0000, 0x4400];
function build(width, height) {
  const b = [];
  const u8 = (v) => b.push(v & 255), u32 = (v) => { u8(v); u8(v >> 8); u8(v >> 16); u8(v >>> 24); }, i64 = (v) => { u32(v); u32(0); };
  const str = (s) => { for (const c of s) u8(c.charCodeAt(0)); u8(0); };
  const attr = (n, t, bytes) => { str(n); str(t); u32(bytes.length); for (const x of bytes) u8(x); };
  const le32 = (v) => [v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >>> 24) & 255];
  u32(20000630); u8(2); u8(0); u8(0); u8(0);
  const ch = []; for (const n of ['B', 'G', 'R']) { for (const c of n) ch.push(c.charCodeAt(0)); ch.push(0, ...le32(1), 0, 0, 0, 0, ...le32(1), ...le32(1)); } ch.push(0);
  attr('channels', 'chlist', ch);
  attr('compression', 'compression', [0]);
  attr('dataWindow', 'box2i', [...le32(0), ...le32(0), ...le32(width - 1), ...le32(height - 1)]);
  attr('displayWindow', 'box2i', [...le32(0), ...le32(0), ...le32(width - 1), ...le32(height - 1)]);
  attr('lineOrder', 'lineOrder', [0]);
  u8(0);
  const table = b.length; for (let y = 0; y < height; y++) i64(0);
  for (let y = 0; y < height; y++) {
    const off = b.length; const o = le32(off); for (let k = 0; k < 4; k++) b[table + y * 8 + k] = o[k];
    u32(y); u32(width * 3 * 2);
    for (let c = 0; c < 3; c++) for (let x = 0; x < width; x++) { const h = halfs[(y * width + x + c * 2) % halfs.length]; u8(h); u8(h >> 8); }
  }
  return new Uint8Array(b);
}
const none = build(3, 2);
fs.writeFileSync('gen/tiny_none.exr', none);
for (const z of ['zips', 'piz', 'b44']) execFileSync('exrmetrics', ['--convert', '-z', z, 'gen/tiny_none.exr', '-o', `gen/tiny_${z}.exr`]);
const lit = (a) => '[\n' + Array.from(a).map((v) => v).join(', ').replace(/(.{1,78})(, |$)/g, '  $1,\n') + ']';
for (const z of ['none', 'zips', 'piz', 'b44']) {
  const bytes = new Uint8Array(fs.readFileSync(`gen/tiny_${z}.exr`));
  console.log(`// ${z} ${bytes.length}`);
  const d = new EXRLoader().parse(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.length));
  console.log(`// half ${z}:`, JSON.stringify(Array.from(d.data)));
  const f = new EXRLoader().setDataType(1015).setOutputFormat(1030).parse(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.length));
  console.log(`// float rg ${z}:`, JSON.stringify(Array.from(f.data)));
  fs.writeFileSync(`gen/tiny_${z}.lit`, lit(bytes));
}
// RGBE: 8x2 flat + 8x1 RLE scanline
const hdrText = '#?RADIANCE\nFORMAT=32-bit_rle_rgbe\nGAMMA=2.2\n\n-Y 2 +X 8\n';
const px = []; for (let i = 0; i < 16; i++) px.push(10 * i, 255 - i, i * 3, 120 + i);
const hdr = new Uint8Array([...new TextEncoder().encode(hdrText), ...px]);
fs.writeFileSync('gen/tiny.hdr', hdr);
const hh = new HDRLoader().parse(hdr.buffer); console.log('// hdr half:', JSON.stringify(Array.from(hh.data)), hh.gamma, JSON.stringify(hh.header));
const hf = new HDRLoader().setDataType(1015).parse(hdr.buffer); console.log('// hdr float:', JSON.stringify(Array.from(hf.data)));
// RLE scanline
const rleText = '#?RGBE\nFORMAT=32-bit_rle_rgbe\n\n-Y 1 +X 8\n';
const rle = [2, 2, 0, 8, 128 + 8, 50, 4, 1, 2, 3, 4, 128 + 4, 9, 8, 0, 1, 2, 3, 4, 5, 6, 7, 128 + 8, 130];
const hdr2 = new Uint8Array([...new TextEncoder().encode(rleText), ...rle]);
fs.writeFileSync('gen/tiny_rle.hdr', hdr2);
const h2 = new HDRLoader().setDataType(1015).parse(hdr2.buffer); console.log('// hdr rle float:', JSON.stringify(Array.from(h2.data)));
console.log('// hdr lit', lit(hdr));
console.log('// hdr rle lit', lit(hdr2));
// fflate
const z = new Uint8Array(zlib.deflateSync(new TextEncoder().encode('hello hello hello hello zlib')));
console.log('// zlib lit', lit(z), new TextDecoder().decode(F.unzlibSync(z)));
