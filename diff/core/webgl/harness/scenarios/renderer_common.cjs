// Shared pieces of the renderer_* scenarios (group 4). Not a scenario itself: run_diff.mjs
// only picks up *.mjs files. The MoonBit side embeds the same source
// (src/renderers/webgl/webgl_renderer_diff_test.mbt, `ffi_renderer_common`); keep the two
// identical (tools: node harness/scenarios/renderer_common.cjs --print-moonbit).
const RENDERER_COMMON = function () {
  // A canvas stand-in that records what the renderer does to it into gl.__log.
  function createMockCanvas(gl, width, height) {
    let w = width;
    let h = height;
    const listeners = {};
    const style = {};
    const canvas = { style };
    Object.defineProperty(canvas, 'width', { get() { return w; }, set(v) { w = v; gl.__log.push('canvas.width = ' + JSON.stringify(v)); } });
    Object.defineProperty(canvas, 'height', { get() { return h; }, set(v) { h = v; gl.__log.push('canvas.height = ' + JSON.stringify(v)); } });
    Object.defineProperty(style, 'width', { set(v) { gl.__log.push('canvas.style.width = ' + JSON.stringify(v)); } });
    Object.defineProperty(style, 'height', { set(v) { gl.__log.push('canvas.style.height = ' + JSON.stringify(v)); } });
    canvas.setAttribute = function (n, v) { gl.__log.push('canvas.setAttribute(' + JSON.stringify(n) + ', ' + JSON.stringify(v) + ')'); };
    canvas.addEventListener = function (t, l) { (listeners[t] = listeners[t] || []).push(l); gl.__log.push('canvas.addEventListener(' + JSON.stringify(t) + ')'); };
    canvas.removeEventListener = function (t, l) { const a = listeners[t] || []; const i = a.indexOf(l); if (i !== -1) a.splice(i, 1); gl.__log.push('canvas.removeEventListener(' + JSON.stringify(t) + ', ' + (i !== -1) + ')'); };
    canvas.getContext = function () { gl.__log.push('canvas.getContext()'); return gl; };
    // fires the listeners of `type` with a minimal event
    canvas.__dispatch = function (type) {
      const event = { type, statusMessage: 'mock', preventDefault() { gl.__log.push('event.preventDefault()'); } };
      for (const l of (listeners[type] || []).slice()) l(event);
    };
    canvas.__listenerCount = function (type) { return (listeners[type] || []).length; };
    return canvas;
  }

  // One active-uniform / attribute spec for every program the mock links, so uploads show
  // up in the log. Types: FLOAT 0x1406, VEC2 0x8B50, VEC3 0x8B51, VEC4 0x8B52, MAT3 0x8B5B,
  // MAT4 0x8B5C, BOOL 0x8B56, SAMPLER_2D 0x8B5E, SAMPLER_CUBE 0x8B60, SAMPLER_2D_SHADOW 0x8B62.
  const PROGRAM_SPEC = {
    attributes: [
      { name: 'position', type: 0x8B51 }, { name: 'normal', type: 0x8B51 }, { name: 'uv', type: 0x8B50 },
      { name: 'color', type: 0x8B51 }, { name: 'instanceMatrix', type: 0x8B5C },
      { name: 'skinIndex', type: 0x8B52 }, { name: 'skinWeight', type: 0x8B52 },
    ],
    uniforms: [
      { name: 'modelMatrix', type: 0x8B5C }, { name: 'modelViewMatrix', type: 0x8B5C },
      { name: 'projectionMatrix', type: 0x8B5C }, { name: 'viewMatrix', type: 0x8B5C },
      { name: 'normalMatrix', type: 0x8B5B }, { name: 'cameraPosition', type: 0x8B51 },
      { name: 'isOrthographic', type: 0x8B56 }, { name: 'toneMappingExposure', type: 0x1406 },
      { name: 'receiveShadow', type: 0x8B56 }, { name: 'diffuse', type: 0x8B51 },
      { name: 'opacity', type: 0x1406 }, { name: 'map', type: 0x8B5E }, { name: 'mapTransform', type: 0x8B5B },
      { name: 'emissive', type: 0x8B51 }, { name: 'specular', type: 0x8B51 }, { name: 'shininess', type: 0x1406 },
      { name: 'roughness', type: 0x1406 }, { name: 'metalness', type: 0x1406 },
      { name: 'ambientLightColor', type: 0x8B51 },
      { name: 'directionalLights[0].direction', type: 0x8B51 }, { name: 'directionalLights[0].color', type: 0x8B51 },
      { name: 'pointLights[0].position', type: 0x8B51 }, { name: 'pointLights[0].color', type: 0x8B51 },
      { name: 'pointLights[0].distance', type: 0x1406 }, { name: 'pointLights[0].decay', type: 0x1406 },
      { name: 'spotLights[0].position', type: 0x8B51 }, { name: 'spotLights[0].direction', type: 0x8B51 },
      { name: 'spotLights[0].color', type: 0x8B51 }, { name: 'spotLights[0].coneCos', type: 0x1406 },
      { name: 'hemisphereLights[0].direction', type: 0x8B51 }, { name: 'hemisphereLights[0].skyColor', type: 0x8B51 },
      { name: 'hemisphereLights[0].groundColor', type: 0x8B51 },
      { name: 'directionalShadowMap[0]', type: 0x8B62 }, { name: 'directionalShadowMatrix[0]', type: 0x8B5C },
      { name: 'directionalLightShadows[0].shadowBias', type: 0x1406 },
      { name: 'fogColor', type: 0x8B51 }, { name: 'fogNear', type: 0x1406 }, { name: 'fogFar', type: 0x1406 },
      { name: 'size', type: 0x1406 }, { name: 'scale', type: 0x1406 }, { name: 'center', type: 0x8B50 },
      { name: 'rotation', type: 0x1406 }, { name: 'boneTexture', type: 0x8B5E },
      { name: 'bindMatrix', type: 0x8B5C }, { name: 'bindMatrixInverse', type: 0x8B5C },
      { name: 'morphTargetBaseInfluence', type: 0x1406 }, { name: 'morphTargetsTexture', type: 0x8B5E },
      { name: 'tEquirect', type: 0x8B5E }, { name: 'transmission', type: 0x1406 },
      { name: 'transmissionSamplerMap', type: 0x8B5E },
    ],
  };
  // `drop`: uniform name prefixes to leave out, for scenes without those lights (a real
  // shader declares only the light structs the scene has).
  function mockOptions(extra, drop) {
    const spec = { attributes: PROGRAM_SPEC.attributes, uniforms: PROGRAM_SPEC.uniforms.filter((u) => !(drop || []).some((d) => u.name.startsWith(d))) };
    const programs = [];
    for (let i = 0; i < 64; i++) programs.push(spec);
    return JSON.stringify(Object.assign({ programs, canvas: { width: 64, height: 32 } }, extra || {}));
  }
  return { createMockCanvas, mockOptions };
};

if (typeof module !== 'undefined') {
  module.exports = RENDERER_COMMON();
  if (require.main === module && process.argv.includes('--print-moonbit')) {
    for (const line of ('(' + RENDERER_COMMON.toString() + ')()').split('\n')) console.log('  #|' + line);
  }
}
