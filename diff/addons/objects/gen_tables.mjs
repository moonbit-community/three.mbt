// Prints the MoonBit tables of src/addons/objects/marching_cubes.mbt from upstream's
// MarchingCubes.js.   node gen_tables.mjs
import fs from 'node:fs';
import path from 'node:path';
import { UPSTREAM } from '../../lib/env.mjs';
const src = fs.readFileSync(path.join(UPSTREAM, 'examples/jsm/objects/MarchingCubes.js'), 'utf8');
function table(name) {
  const m = new RegExp('const ' + name + ' = new Int32Array\\( \\[([^\\]]*)\\] \\);').exec(src);
  const nums = m[1].replace(/\/\/[^\n]*/g, '').split(',').map((s) => s.replace(/\s+/g, '')).filter((s) => s.length).map((s) => Number(s));
  return nums;
}
for (const [name, mb] of [['edgeTable', 'edge_table'], ['triTable', 'tri_table']]) {
  const nums = table(name);
  const lines = [];
  for (let i = 0; i < nums.length; i += 16) lines.push('  ' + nums.slice(i, i + 16).join(', ') + ',');
  console.log(`///|\n/// \`${name}\` (${nums.length} entries).\npub let ${mb} : FixedArray[Int] = [\n${lines.join('\n')}\n]\n`);
}
