// Fuzz cases for tools/gen_shaders.mjs's MoonBit string literals: writes a small module
// (moon.mod, src/main/{moon.pkg,f.mbt}) holding every case as a `#|` literal, and
// expected.json, into <dir> (default $THREE_DIFF_OUT/classic_shaders/fuzz); checks that the
// strings it cannot encode are refused. run.mjs builds it and compares (check.mjs).
//   node gen.mjs [<dir>] [fmt]
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { repoPath, outDir } from '../../../lib/env.mjs';
const { mbtStringLet, mbtStringLines } = await import(pathToFileURL(repoPath('tools/gen_shaders.mjs')).href);
const dir = process.argv[2] && process.argv[2] !== 'fmt' ? path.resolve(process.argv[2]) : outDir('classic_shaders', 'fuzz');
fs.mkdirSync(path.join(dir, 'src/main'), { recursive: true });
fs.writeFileSync(path.join(dir, 'moon.mod'), 'name = "fuzz/fuzz"\n\nversion = "0.0.1"\n\nsource = "src"\n\npreferred_target = "js"\n');
fs.writeFileSync(path.join(dir, 'src/main/moon.pkg'), 'options(\n  link: { "js": { "exports": [ "all" ], "format": "esm" } },\n)\n');
const fixed = ['', '\n', '\n\n', '\n\n\n', 'a', 'a\n', '\na', '\na\n', 'a\n\nb', 'a\n\n\nb\n\n', ' ', '  ', '\t', 'x  \n', 'x\t\n\t\ny \n',
  '\\', '\\\\', '\\n', '\\t', '\\{x}', '\\{', '\\u{41}', '\\x41', '${x}', '$', '$|', '$|\\{a}', '#|', '#|#|', '  #|x', '"', '""', '"""', "'", '`', '//', '///|', '/* x', '{', '}',
  'α∞😀’ü', '\u00a0', '\u2028x', '\ufeff', 'é\n\\{x}  \n'];
const atoms = ['\n', '\n\n', ' ', '\t', '\\', '{', '}', '$', '#|', '|', '"', 'a', '#include <x>', 'α', '😀', '\\{', '\\n'];
let seed = 12345; const rnd = (n) => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) % n;
const cases = [...fixed];
for (let i = 0; i < 400; i++) { let s = ''; for (let j = rnd(12); j >= 0; j--) s += atoms[rnd(atoms.length)]; cases.push(s); }
const trailing = cases.filter((c) => /[ \t]$/.test(c));
const kept = cases.filter((c) => !/[ \t]$/.test(c));
cases.length = 0; cases.push(...kept);
let out = '';
cases.forEach((c, i) => { out += mbtStringLet(`s${i}`, c) + '\n'; });
out += `///|\npub fn all() -> Array[String] {\n  [${cases.map((_, i) => `s${i}`).join(', ')}]\n}\n`;
fs.writeFileSync(path.join(dir, 'src/main/f.mbt'), out);
fs.writeFileSync(path.join(dir, 'expected.json'), JSON.stringify(cases));
if (process.argv.includes('fmt')) execFileSync('moonfmt', ['-w', path.join(dir, 'src/main/f.mbt')]);
// Refusals.
for (const c of ['a\rb', 'a\u0000', 'a\u001b', '\ud800', ...trailing]) { let threw = false; try { mbtStringLines(c); } catch { threw = true; } if (!threw) { console.log('NOT REFUSED', JSON.stringify(c)); process.exit(1); } }
console.log('refusals ok,', cases.length, 'cases');
