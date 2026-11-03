// Checks that every gl.* method and constant the upstream renderer uses is bound.
// Usage: node tools/check_coverage.mjs <three.js/src> <repo>/src/renderers/webgl
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { methods, extensionMethods, constants } from './gl_spec.mjs';
import { parse } from './gen_bindings_lib.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const [src, pkg] = process.argv.slice(2);
const usage = JSON.parse(spawnSync('node', [path.join(here, 'gl_usage.mjs'), src], { encoding: 'utf8' }).stdout);
const bound = new Set(methods.map((m) => parse(m).js));
const boundExt = new Set(extensionMethods.map((m) => parse(m).js));
const mbt = fs.readdirSync(pkg).filter((f) => f.endsWith('.mbt')).map((f) => fs.readFileSync(path.join(pkg, f), 'utf8')).join('\n');
let missing = 0;
for (const m of Object.keys(usage.methods)) if (!bound.has(m)) { console.log('missing method', m); missing++; }
for (const c of usage.constants) if (!(c in constants) || !mbt.includes(`pub const GL_${c} `)) { console.log('missing constant', c); missing++; }
// properties read or written on gl
const props = { canvas: 'WebGL2RenderingContext::canvas', drawingBufferColorSpace: 'set_drawing_buffer_color_space', unpackColorSpace: 'set_unpack_color_space', texElementImage2D: 'has_tex_element_image2d' };
for (const p of usage.props) if (props[p] && !mbt.includes(props[p])) { console.log('missing property', p); missing++; }
// extension methods called anywhere: `<something>.fooEXT(` / `fooWEBGL(` / loseContext ...
const files = [path.join(src, 'renderers/WebGLRenderer.js'), path.join(src, 'extras/PMREMGenerator.js'),
  ...fs.readdirSync(path.join(src, 'renderers/webgl')).filter((f) => f.endsWith('.js')).map((f) => path.join(src, 'renderers/webgl', f))];
const extCalls = new Set();
for (const f of files) for (const m of fs.readFileSync(f, 'utf8').matchAll(/\.([a-zA-Z0-9]+(?:EXT|WEBGL|OVR)|loseContext|restoreContext)\(/g)) extCalls.add(m[1]);
for (const m of extCalls) if (!boundExt.has(m)) { console.log('missing extension method', m); missing++; }
console.log(`${Object.keys(usage.methods).length} gl methods used (${bound.size} bound), ${usage.constants.length} constants used (${Object.keys(constants).length} bound), extension methods used: ${[...extCalls].sort().join(', ')}`);
process.exit(missing ? 1 : 0);
