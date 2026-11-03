// node one.mjs <side: up|port> <file> [type] [format] [part]
import fs from 'node:fs';
import * as env from './env.mjs';
import { EX, HARNESS_URL } from './paths.mjs';
env.install();
const [side, file, type = 1016, format = 1023, part = 0] = process.argv.slice(2);
const ex = EX;
const t0 = Date.now();
if (side === 'up') {
  const { EXRLoader } = await import(ex + 'jsm/loaders/EXRLoader.js');
  const l = new EXRLoader().setDataType(+type).setOutputFormat(+format).setPart(+part);
  try { const buf = fs.readFileSync(file); const d = l.parse(buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength)); console.log('ok', env.hashData(d.data), JSON.stringify(d.header).slice(0, 300)); } catch (e) { console.log('err', e.message); }
} else {
  const M = await import(HARNESS_URL);
  const buf = fs.readFileSync(file); const ab = buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength);
  try { const d = M.exr_parse(ab, +type, +format, +part); console.log('ok', env.hashData(d.data), JSON.stringify(d.header).slice(0, 300)); } catch (e) { console.log('err', e.message); }
}
console.log('ms', Date.now() - t0);
