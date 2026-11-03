// Cross-checks gl_spec.mjs constant values against TypeScript's lib.dom.d.ts.
// Usage: node tools/check_constants.mjs <path to lib.dom.d.ts>
import fs from 'node:fs';
import { constants } from './gl_spec.mjs';
const dts = fs.readFileSync(process.argv[2], 'utf8');
const ref = {};
for (const m of dts.matchAll(/readonly ([A-Z0-9_]+): (0x[0-9A-Fa-f]+|\d+);/g)) ref[m[1]] ??= Number(m[2]);
let bad = 0, checked = 0;
for (const [k, v] of Object.entries(constants)) {
  if (ref[k] === undefined) { console.log('not in lib.dom.d.ts:', k); continue; }
  checked++;
  if (ref[k] !== v) { console.log('MISMATCH', k, v, ref[k]); bad++; }
}
console.log(`checked ${checked} constants, ${bad} mismatches`);
process.exit(bad ? 1 : 0);
