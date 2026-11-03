// Rewrites the DWA chunks of a DWAA/DWAB file to use DEFLATE for the AC coefficients
// (OpenEXR's writers always use STATIC_HUFFMAN), so upstream's DEFLATE branch runs.
// The AC values come from an instrumented copy of upstream's EXRLoader.
//   node gen_dwa_deflate.mjs <in.exr> <out.exr>
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { pathToFileURL } from 'node:url';
import { EX, OUT_HDR } from './paths.mjs';
const src = EX + 'jsm/';
let code = fs.readFileSync(src + 'loaders/EXRLoader.js', 'utf8')
  .replace("from 'three'", `from '${pathToFileURL(EX + '../build/three.module.js').href}'`)
  .replace("from '../libs/fflate.module.js'", `from '${pathToFileURL(src + 'libs/fflate.module.js').href}'`)
  .replace('hufUncompress( info.array, inDataView, inOffset, dwaHeader.acCompressedSize, acBuffer, dwaHeader.totalAcUncompressedCount );',
    'const __s = inOffset.value; hufUncompress( info.array, inDataView, inOffset, dwaHeader.acCompressedSize, acBuffer, dwaHeader.totalAcUncompressedCount ); globalThis.__ac.push( { chunk: info.offset.value, start: __s, end: inOffset.value, values: acBuffer.slice() } );');
// the instrumented copy lives in OUT (generated, not committed)
const hook = path.join(OUT_HDR, 'EXRLoaderHook.mjs');
fs.writeFileSync(hook, code);
const { EXRLoader } = await import(pathToFileURL(hook).href);
const [inFile, outFile] = process.argv.slice(2);
const bytes = new Uint8Array(fs.readFileSync(inFile));
globalThis.__ac = [];
new EXRLoader().parse(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.length));
const dv = new DataView(bytes.buffer, bytes.byteOffset);
const exrHeaderEnd = (b) => { let o = 8; const z = () => { while (b[o] !== 0) o++; o++; }; for (;;) { if (b[o] === 0) return o + 1; z(); z(); o += 4 + dv.getUint32(o, true); } };
const he = exrHeaderEnd(bytes);
const count = (Number(dv.getBigInt64(he, true)) - he) / 8;
const out = [...bytes.slice(0, he)];
const table = out.length; for (let i = 0; i < count; i++) out.push(0, 0, 0, 0, 0, 0, 0, 0);
let rewritten = 0;
for (let i = 0; i < count; i++) {
  const co = Number(dv.getBigInt64(he + i * 8, true));
  const size = dv.getUint32(co + 4, true);
  let chunk = bytes.slice(co, co + 8 + size);
  const ac = globalThis.__ac.find((a) => a.chunk === co + 8);
  if (ac) {
    const total = ac.values.length;
    const z = zlib.deflateSync(new Uint8Array(ac.values.buffer));
    if (process.env.DEBUG) console.log("chunk", i, "acvalues", total, "zlib", z.length, ac.start - co, ac.end - co);
    if (z.length + 4 <= total) {
      const pad = new Uint8Array(total); pad.set(z);
      const rel0 = ac.start - co, rel1 = ac.end - co;
      const head = chunk.slice(0, rel0), tail = chunk.slice(rel1);
      const c = new Uint8Array(head.length + total + tail.length);
      c.set(head); c.set(pad, head.length); c.set(tail, head.length + total);
      const cv = new DataView(c.buffer);
      cv.setBigInt64(8 + 3 * 8, BigInt(total), true); // acCompressedSize
      cv.setBigInt64(8 + 10 * 8, 1n, true); // acCompression = DEFLATE
      cv.setUint32(4, c.length - 8, true);
      chunk = c; rewritten++;
    }
  }
  const off = out.length; const o = new DataView(new ArrayBuffer(8)); o.setBigInt64(0, BigInt(off), true);
  for (let k = 0; k < 8; k++) out[table + i * 8 + k] = o.getUint8(k);
  out.push(...chunk);
}
fs.writeFileSync(outFile, new Uint8Array(out));
console.log(`${outFile}: ${rewritten}/${count} chunks use DEFLATE AC`);
