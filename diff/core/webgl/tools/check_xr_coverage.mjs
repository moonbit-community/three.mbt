// Lists every member upstream src/renderers/webxr reads or calls on a WebXR object and
// checks that src/renderers/webgl/webxr_bindings.mbt binds it (the member appears in a
// binding's JS: `.name`, `name:` or `'name'`).
// Usage: node tools/check_xr_coverage.mjs <three.js/src> <webgl dir>
import fs from 'node:fs';
import path from 'node:path';

const [src, webgl] = process.argv.slice(2);
const files = ['WebXRManager.js', 'WebXRController.js', 'WebXRDepthSensing.js'].map((f) => path.join(src, 'renderers/webxr', f));
// receivers holding WebXR objects in those files (the variable names upstream uses)
const receivers = ['session', 'frame', 'pose', 'view', 'views\\[ i \\]', 'views\\[ 0 \\]', 'glBinding', 'glBaseLayer', 'glProjLayer',
  'glSubImage', 'depthData', 'renderState', 'session\\.renderState', 'frame\\.session', 'inputSource', 'inputSource\\.hand',
  'inputjoint', 'jointPose', 'gripPose', 'inputPose', 'event', 'viewport', 'view\\.transform', 'jointPose\\.transform',
  'gripPose\\.transform', 'inputPose\\.transform', 'XRWebGLBinding', 'XRWebGLBinding\\.prototype', 'gl', 'attributes'];
// members of three.js objects that share a receiver name, and gl.* calls bound elsewhere
const notXR = new Set(['getContextAttributes', 'DEPTH24_STENCIL8', 'DEPTH_COMPONENT24', 'RGBA8', 'type', 'length', 'x', 'y', 'z', 'w', 'set']);
const used = new Map();
for (const file of files) {
  const text = fs.readFileSync(file, 'utf8').replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
  for (const r of receivers) {
    const re = new RegExp('(?<![\\w.])' + r + '\\.(\\w+)', 'g');
    for (const m of text.matchAll(re)) {
      if (notXR.has(m[1])) continue;
      const key = r.replace(/\\/g, '') + '.' + m[1];
      used.set(key, m[1]);
    }
  }
  for (const m of text.matchAll(/'(\w+)' in XRWebGLBinding\.prototype/g)) used.set('XRWebGLBinding.prototype.' + m[1], m[1]);
  for (const m of text.matchAll(/new (XR\w+)\(/g)) used.set('new ' + m[1], m[1]);
  for (const m of text.matchAll(/typeof (XR\w+)/g)) used.set('typeof ' + m[1], m[1]);
}
const bindings = fs.readFileSync(path.join(webgl, 'webxr_bindings.mbt'), 'utf8');
const js = [...bindings.matchAll(/= "([^"]*)"/g)].map((m) => m[1]).join('\n');
let missing = 0;
for (const [key, member] of [...used].sort()) {
  const bound = js.includes('.' + member) || js.includes(member + ':') || js.includes("'" + member + "'") || js.includes('new ' + member) || js.includes(member + ' ');
  console.log((bound ? 'bound    ' : 'MISSING  ') + key);
  if (!bound) missing++;
}
console.log(`${used.size} members, ${missing} missing`);
process.exit(missing ? 1 : 0);
