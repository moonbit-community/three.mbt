// Helpers shared by the group 3 scenarios (lights_, materials_, shadow_, morph_,
// background_, env_, output_, pmrem_). Values are flattened to arrays so `gl.__note`
// keeps them (the mock notes plain objects as 'object'). The MoonBit side
// (webgl_group3_test.mbt) produces the same shapes.

export function ser(v) {
  if (v === null) return null;
  if (v === undefined) return 'undefined';
  if (typeof v === 'number' || typeof v === 'boolean' || typeof v === 'string') return v;
  if (v.isVector2) return [v.x, v.y];
  if (v.isVector3) return [v.x, v.y, v.z];
  if (v.isVector4) return [v.x, v.y, v.z, v.w];
  if (v.isColor) return [v.r, v.g, v.b];
  if (v.isMatrix3 || v.isMatrix4) return Array.from(v.elements);
  if (v.isTexture) return 'tex:' + v.name;
  if (ArrayBuffer.isView(v)) return Array.from(v);
  if (Array.isArray(v)) return v.map(ser);
  return Object.keys(v).map((k) => [k, ser(v[k])]);
}

export const LIGHT_STATE_KEYS = ['ambient', 'probe', 'sun', 'sunShadow', 'sunShadowMap', 'sunShadowMatrix',
  'sunShadowCascade', 'directional', 'directionalShadow', 'directionalShadowMap', 'directionalShadowMatrix',
  'spot', 'spotLightMap', 'spotShadow', 'spotShadowMap', 'spotLightMatrix', 'rectArea', 'rectAreaLTC1',
  'rectAreaLTC2', 'point', 'pointShadow', 'pointShadowMap', 'pointShadowMatrix', 'hemi',
  'numSpotLightShadowsWithMaps', 'numLightProbes'];

export const LIGHT_HASH_KEYS = ['sunLength', 'directionalLength', 'pointLength', 'spotLength', 'rectAreaLength',
  'hemiLength', 'numSunShadows', 'numDirectionalShadows', 'numPointShadows', 'numSpotShadows', 'numSpotMaps',
  'numLightProbes'];

// Notes every field of `lights.state`; `v0` is the version before the first setup.
export function noteLightState(gl, label, state, v0) {
  gl.__note(label + ' version', state.version - v0);
  gl.__note(label + ' hash', LIGHT_HASH_KEYS.map((k) => state.hash[k]));
  for (const k of LIGHT_STATE_KEYS) gl.__note(label + ' ' + k, ser(state[k]));
}

// Notes `uniforms[ name ].value` for every name, in sorted order.
export function noteUniforms(gl, label, uniforms) {
  for (const k of Object.keys(uniforms).sort()) gl.__note(label + ' ' + k, ser(uniforms[k].value));
}

// Uniforms added to renderer_common.cjs's program spec so the group 3 materials' uploads
// show up in the log. Types: FLOAT 0x1406, INT 0x1404, VEC2 0x8B50, VEC3 0x8B51, MAT3 0x8B5B,
// SAMPLER_2D 0x8B5E, SAMPLER_CUBE 0x8B60, SAMPLER_2D_SHADOW 0x8B62, SAMPLER_CUBE_SHADOW 0x8DC5.
export const G3_EXTRA_UNIFORMS = [
  { name: 'envMap', type: 0x8B60 }, { name: 'flipEnvMap', type: 0x1406 },
  { name: 'backgroundBlurriness', type: 0x1406 }, { name: 'backgroundIntensity', type: 0x1406 },
  { name: 'backgroundRotation', type: 0x8B5B }, { name: 't2D', type: 0x8B5E }, { name: 'uvTransform', type: 0x8B5B },
  { name: 'lodBias', type: 0x1406 }, { name: 'sourceLod', type: 0x1406 }, { name: 'sourceSize', type: 0x1404 },
  { name: 'sigma', type: 0x1406 }, { name: 'tDiffuse', type: 0x8B5E }, { name: 'shadow_pass', type: 0x8B5E },
  { name: 'resolution', type: 0x8B50 }, { name: 'radius', type: 0x1406 }, { name: 'referencePosition', type: 0x8B51 },
  { name: 'nearDistance', type: 0x1406 }, { name: 'farDistance', type: 0x1406 },
  { name: 'spotShadowMap[0]', type: 0x8B62 }, { name: 'pointShadowMap[0]', type: 0x8DC5 },
  { name: 'spotLightMatrix[0]', type: 0x8B5C }, { name: 'pointShadowMatrix[0]', type: 0x8B5C },
  { name: 'alphaTest', type: 0x1406 }, { name: 'envMapIntensity', type: 0x1406 },
];

// renderer_common's mock options with G3_EXTRA_UNIFORMS added to every program; `unlit`
// drops the light and shadow uniforms (for scenes without every light type).
export function g3Options(mockOptions, extra, unlit) {
  const o = JSON.parse(mockOptions(extra || {}));
  const keep = (u) => !unlit || !/Light|Shadow/.test(u.name);
  o.programs = o.programs.map((p) => ({ attributes: p.attributes, uniforms: p.uniforms.concat(G3_EXTRA_UNIFORMS).filter(keep) }));
  return o;
}
