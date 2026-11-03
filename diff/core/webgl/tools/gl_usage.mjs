// Scans upstream sources for `gl.foo(` / `_gl.foo(` / `state.foo(` calls and `gl.FOO` constants.
// Usage: node gl_usage.mjs <three.js/src>  -> prints JSON {methods:{name:[arities]}, constants:[...], state:{...}}
import fs from 'node:fs';
import path from 'node:path';
const src = process.argv[2];
const files = [path.join(src, 'renderers/WebGLRenderer.js'), path.join(src, 'extras/PMREMGenerator.js'),
  ...fs.readdirSync(path.join(src, 'renderers/webgl')).filter(f => f.endsWith('.js')).map(f => path.join(src, 'renderers/webgl', f))];
const methods = {}, constants = new Set(), state = {}, props = new Set();
function argCount(text, start) {
  // text[start] === '(' ; count top-level commas
  let depth = 0, n = 0, any = false;
  for (let i = start; i < text.length; i++) {
    const c = text[i];
    if (c === '(' || c === '[' || c === '{') { depth++; continue; }
    if (c === ')' || c === ']' || c === '}') { depth--; if (depth === 0) return any ? n + 1 : 0; continue; }
    if (depth === 1 && c === ',') n++;
    else if (depth === 1 && !/\s/.test(c)) any = true;
  }
  return -1;
}
for (const f of files) {
  const text = fs.readFileSync(f, 'utf8');
  const re = /\b(_?gl|state)\.([A-Za-z_0-9]+)(\s*\()?/g;
  let m;
  while ((m = re.exec(text))) {
    const [, obj, name, call] = m;
    if (obj === 'state') { if (call) { (state[name] ??= new Set()).add(argCount(text, m.index + m[0].length - 1)); } continue; }
    if (/^[A-Z0-9_]+$/.test(name)) constants.add(name);
    else if (call) (methods[name] ??= new Set()).add(argCount(text, m.index + m[0].length - 1) + ' @' + path.basename(f));
    else props.add(name);
  }
}
const out = { methods: Object.fromEntries(Object.entries(methods).sort().map(([k, v]) => [k, [...v]])),
  props: [...props].sort(), constants: [...constants].sort(),
  state: Object.fromEntries(Object.entries(state).sort().map(([k, v]) => [k, [...v]])) };
console.log(JSON.stringify(out, null, 1));
