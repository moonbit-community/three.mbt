// Prints DRACOWorker's body (as upstream's _initDecoder computes it) as MoonBit `#|` lines,
// the embed in src/addons/loaders/draco_loader.mbt (`draco_worker_body`).
//   node gen_worker.mjs [--check]   (--check: exit 1 unless the port embeds it verbatim)
import fs from 'node:fs';
import path from 'node:path';
import { upstreamPath, repoPath, outDir } from '../../../lib/env.mjs';
const src = fs.readFileSync(upstreamPath('examples/jsm/loaders/DRACOLoader.js'), 'utf8');
const start = src.indexOf('function DRACOWorker() {');
const end = src.indexOf('\nexport { DRACOLoader');
const fnText = src.slice(start, end).trimEnd(); // function source up to its closing brace
const fn = new Function('return ' + fnText)().toString();
if (fn !== fnText) throw new Error('toString mismatch');
const body = fn.substring(fn.indexOf('{') + 1, fn.lastIndexOf('}'));
if (/[\\]/.test(body)) console.error('note: backslash present');
const lines = body.split('\n');
const embed = lines.map((l) => '  #|' + l).join('\n');
if (process.argv.includes('--check')) {
  const ok = fs.readFileSync(repoPath('src/addons/loaders/draco_loader.mbt'), 'utf8').includes(embed);
  console.log(ok ? 'src/addons/loaders/draco_loader.mbt embeds the DRACOWorker body verbatim' : 'src/addons/loaders/draco_loader.mbt: DRACOWorker body differs from upstream');
  process.exit(ok ? 0 : 1);
}
process.stdout.write(embed + '\n');
fs.writeFileSync(path.join(outDir('addons_draco'), 'worker_body.txt'), body);
