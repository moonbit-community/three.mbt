// Shared pieces of the a6_* scenarios (examples/jsm/objects add-ons on WebGLRenderer). Not
// a scenario itself (run_diff.mjs only runs *.mjs). The MoonBit side is
// src/addons/objects/a6_objects_webgl_diff_test.mbt, which embeds A6_EXTRA_UNIFORMS and
// a6Options verbatim.
const { register } = require('node:module');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

let registered = false;
// Installs the resolve hook (bare 'three' imports of the add-ons) once.
function a6Register(src) {
  if (registered) return;
  registered = true;
  register(pathToFileURL(path.join(__dirname, '..', 'a6_three_resolve.mjs')).href, { data: { src } });
}

// The uniforms of the add-on shaders, added to every program spec so their uploads are logged.
const A6_EXTRA_UNIFORMS = '[{"name":"textureMatrix","type":35676},{"name":"tDiffuse","type":35678},{"name":"color","type":35665},{"name":"sunPosition","type":35665},{"name":"rayleigh","type":5126},{"name":"turbidity","type":5126},{"name":"mieCoefficient","type":5126},{"name":"mieDirectionalG","type":5126},{"name":"cloudScale","type":5126},{"name":"cloudSpeed","type":5126},{"name":"cloudCoverage","type":5126},{"name":"cloudDensity","type":5126},{"name":"cloudElevation","type":5126},{"name":"showSunDisc","type":5126},{"name":"time","type":5126},{"name":"mirrorSampler","type":35678},{"name":"alpha","type":5126},{"name":"distortionScale","type":5126},{"name":"normalSampler","type":35678},{"name":"sunColor","type":35665},{"name":"sunDirection","type":35665},{"name":"eye","type":35665},{"name":"waterColor","type":35665},{"name":"reflectivity","type":5126},{"name":"tReflectionMap","type":35678},{"name":"tRefractionMap","type":35678},{"name":"tNormalMap0","type":35678},{"name":"tNormalMap1","type":35678},{"name":"tFlowMap","type":35678},{"name":"config","type":35666},{"name":"flowDirection","type":35664},{"name":"screenPosition","type":35665},{"name":"occlusionMap","type":35678}]';

// `base` (mockOptions output) with `extra` appended to every program's uniforms.
const a6Options = (base, extra) => { const o = JSON.parse(base); for (const p of o.programs) p.uniforms = p.uniforms.concat(JSON.parse(extra)); return JSON.stringify(o); };

// Light structs these scenes do not have (as renderer_frame_rtt drops them).
const A6_DROP = ['pointLights', 'spotLights', 'hemisphereLights', 'directionalShadowMap', 'directionalShadowMatrix', 'directionalLightShadows'];

// A deterministic performance.now (Timer in Water2): starts at 1000, +16 per call.
function a6StubNow() { const saved = performance.now; let t = 1000; performance.now = () => (t += 16); return () => { performance.now = saved; }; }

module.exports = { a6Register, A6_EXTRA_UNIFORMS, a6Options, A6_DROP, a6StubNow };
