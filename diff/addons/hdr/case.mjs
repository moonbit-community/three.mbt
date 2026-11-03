// One load in a fresh process: node case.mjs <up|port> <hdr|exr> <file> <type> [format] [part]
// Prints the description JSON; run with --trace-sigint so a timeout shows the stack.
import * as env from './env.mjs';
import { EX, HARNESS_URL } from './paths.mjs';
env.install();
const [side, kind, file, type, format = 1023, part = 0] = process.argv.slice(2);
const ex = EX;
const errJs = (e) => ({ error: String(e && e.message), name: e && e.name });
const quietly = () => { console.warn = console.error = () => {}; };
let result;
if (side === 'up') {
  const { HDRLoader } = await import(ex + 'jsm/loaders/HDRLoader.js');
  const { EXRLoader } = await import(ex + 'jsm/loaders/EXRLoader.js');
  const l = kind === 'hdr' ? new HDRLoader().setDataType(+type) : new EXRLoader().setDataType(+type).setOutputFormat(+format).setPart(+part);
  quietly();
  result = await new Promise((r) => l.load(file, (t, d) => r(globalThis.__describe(t, d)), undefined, (e) => r(errJs(e))));
} else {
  const M = await import(HARNESS_URL);
  quietly();
  result = await new Promise((r) => (kind === 'hdr' ? M.hdr_load(file, +type, true, r) : M.exr_load(file, +type, +format, +part, r)));
}
process.stdout.write(JSON.stringify(result) + '\n');
