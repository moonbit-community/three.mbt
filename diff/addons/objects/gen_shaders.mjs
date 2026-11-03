// Prints MoonBit lets for the /* glsl */ template literals of an upstream file, in order.
// (used for the WebGL objects: Sky, Water, Water2, Reflector, Refractor, Lensflare)
// node gen_shaders.mjs <file.js> name1 name2 ...
import fs from 'node:fs';
const [file, ...names] = process.argv.slice(2);
const src = fs.readFileSync(file, 'utf8');
const re = /\/\* glsl \*\/`([^`]*)`/g;
let m, i = 0;
const out = [];
while ((m = re.exec(src))) {
  const text = m[1];
  if (text.includes('${') || text.includes('\\')) throw new Error('interpolation or backslash in shader ' + i);
  const name = names[i] ?? `shader_${i}`;
  i++;
  const lines = text.split('\n');
  const segs = [];
  let block = [];
  const flush = () => { if (block.length) { segs.push({ raw: block }); block = []; } };
  for (const line of lines) {
    if (/[ \t]$/.test(line)) { flush(); segs.push({ lit: line }); } else block.push(line);
  }
  flush();
  let body;
  if (segs.length === 1 && segs[0].raw) body = segs[0].raw.map((l) => '  #|' + l).join('\n');
  else body = segs.map((s) => s.raw ? '(\n' + s.raw.map((l) => '    #|' + l).join('\n') + '\n  )' : JSON.stringify(s.lit).replace(/\\u0009/g, '\\t')).join(' +\n  "\\n" +\n  ');
  out.push(`///|\nlet ${name} : String =${body.startsWith('(') || body.startsWith('"') ? ' ' : '\n'}${body}\n`);
}
console.log(out.join('\n'));
