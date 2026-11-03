// Shared by programs_grid.mjs and webgl_programs_test.mbt (embedded there verbatim:
// `node programs_common.cjs --print-moonbit`). CASES is the material/object/renderer grid
// that both sides interpret: each case builds a material, an object and a scene, sets
// renderer state, then runs getParameters / getProgramCacheKey / getUniforms /
// acquireProgram, so the log holds the full GLSL (shaderSource), the cache key and a
// digest of the parameters.
const G = ['position', 'normal', 'uv'];
const CUSTOM_VERTEX = [
  '#include <common>',
  'uniform float time;',
  'varying vec2 vUv;',
  'void main() {',
  '\tvUv = uv;',
  '\tvec3 p = position;',
  '\t#pragma unroll_loop_start',
  '\tfor ( int i = 0; i < 3; i ++ ) {',
  '\t\tp.x += float( UNROLLED_LOOP_INDEX ) * offsets[ i ];',
  '\t}',
  '\t#pragma unroll_loop_end',
  '\tgl_Position = projectionMatrix * modelViewMatrix * vec4( p, 1.0 );',
  '}',
].join('\n');
const CUSTOM_FRAGMENT = [
  '#include <common>',
  '#include <clipping_planes_pars_fragment>',
  'varying vec2 vUv;',
  'void main() {',
  '\t#include <clipping_planes_fragment>',
  '\tgl_FragColor = vec4( vUv, float( NUM_DIR_LIGHTS ), 1.0 );',
  '}',
].join('\n');
const RAW_VERTEX = 'precision highp float;\nattribute vec3 position;\nvoid main() { gl_Position = vec4( position, 1.0 ); }';
const RAW_FRAGMENT = 'precision highp float;\nvoid main() { gl_FragColor = vec4( 1.0 ); }';
const LIGHTS = { directional: 2, point: 1, spot: 2, spotLightMap: 1, rectArea: 1, hemi: 1, directionalShadowMap: 1, pointShadowMap: 1, spotShadowMap: 2, numSpotLightShadowsWithMaps: 1, numLightProbes: 1 };
const PHYS_MAPS = {
  map: {}, normalMap: {}, roughnessMap: {}, metalnessMap: {}, clearcoatMap: {}, clearcoatNormalMap: {}, clearcoatRoughnessMap: { channel: 1 },
  iridescenceMap: {}, iridescenceThicknessMap: {}, sheenColorMap: {}, sheenRoughnessMap: { channel: 2 }, transmissionMap: {}, thicknessMap: {},
  specularIntensityMap: {}, specularColorMap: {}, anisotropyMap: {}, diffuseRoughnessMap: {}, emissiveMap: {}, aoMap: {}, lightMap: {}, alphaMap: {},
};

const CASES = [
  { label: 'basic' , material: 'MeshBasicMaterial' },
  { label: 'basic-maps', material: 'MeshBasicMaterial', maps: { map: {}, alphaMap: {}, aoMap: {}, lightMap: { channel: 1 }, specularMap: { channel: 2 } }, env: 'cube' },
  { label: 'basic-env-refraction-mix', material: 'MeshBasicMaterial', set: { combine: 1 }, env: 'cubeRefraction' },
  { label: 'basic-env-add', material: 'MeshBasicMaterial', set: { combine: 2 }, env: 'cube', maps: { map: { channel: 3 } } },
  { label: 'basic-vertex-colors4', material: 'MeshBasicMaterial', set: { vertexColors: true }, geometry: { attributes: ['position', 'normal', 'uv', 'color4'] } },
  { label: 'basic-alpha', material: 'MeshBasicMaterial', set: { vertexColors: true, alphaTest: 0.5, alphaHash: true, alphaToCoverage: true, transparent: true }, geometry: { attributes: ['position', 'normal', 'uv', 'color3'] } },
  { label: 'basic-fog', material: 'MeshBasicMaterial', fog: 'linear' },
  { label: 'basic-fog-exp2', material: 'MeshBasicMaterial', fog: 'exp2' },
  { label: 'basic-no-fog', material: 'MeshBasicMaterial', set: { fog: false }, fog: 'exp2' },
  { label: 'basic-no-normals-morph-normals', material: 'MeshBasicMaterial', geometry: { attributes: ['position'], morph: ['position', 'normal'], morphCount: 2 } },
  { label: 'basic-morph-colors', material: 'MeshBasicMaterial', geometry: { attributes: G, morph: ['color'], morphCount: 3 } },
  { label: 'basic-skinned', material: 'MeshBasicMaterial', object: 'skinned' },
  { label: 'basic-instanced', material: 'MeshBasicMaterial', object: 'instanced' },
  { label: 'basic-instanced-color-morph', material: 'MeshBasicMaterial', object: 'instancedColorMorph' },
  { label: 'basic-batched', material: 'MeshBasicMaterial', object: 'batched' },
  { label: 'basic-batched-color', material: 'MeshBasicMaterial', object: 'batchedColor' },
  { label: 'basic-sides', material: 'MeshBasicMaterial', set: { side: 2, premultipliedAlpha: true, dithering: true } },
  { label: 'basic-back', material: 'MeshBasicMaterial', set: { side: 1, name: 'named' } },
  { label: 'basic-tone-aces', material: 'MeshBasicMaterial', renderer: { toneMapping: 4 } },
  { label: 'basic-tone-agx-untoned', material: 'MeshBasicMaterial', set: { toneMapped: false }, renderer: { toneMapping: 6 } },
  { label: 'basic-tone-custom', material: 'MeshBasicMaterial', renderer: { toneMapping: 5 } },
  { label: 'basic-tone-neutral', material: 'MeshBasicMaterial', renderer: { toneMapping: 7 } },
  { label: 'basic-tone-reinhard-cineon', material: 'MeshBasicMaterial', renderer: { toneMapping: 2 } },
  { label: 'basic-tone-cineon', material: 'MeshBasicMaterial', renderer: { toneMapping: 3 } },
  { label: 'basic-tone-linear', material: 'MeshBasicMaterial', renderer: { toneMapping: 1 } },
  { label: 'basic-linear-output', material: 'MeshBasicMaterial', renderer: { outputColorSpace: 'srgb-linear', toneMapping: 4 } },
  { label: 'basic-render-target', material: 'MeshBasicMaterial', renderer: { renderTarget: true, toneMapping: 4 } },
  { label: 'basic-lowp', material: 'MeshBasicMaterial', set: { precision: 'lowp' } },
  { label: 'basic-mediump', material: 'MeshBasicMaterial', set: { precision: 'mediump' } },
  { label: 'basic-video', material: 'MeshBasicMaterial', maps: { map: { video: true, colorSpace: 'srgb' } } },
  { label: 'basic-video-linear', material: 'MeshBasicMaterial', maps: { map: { video: true } } },
  { label: 'basic-reversed', material: 'MeshBasicMaterial', renderer: { reversed: true } },
  { label: 'basic-clipping', material: 'MeshBasicMaterial', clipping: { global: 2 } },
  { label: 'basic-clipping-local', material: 'MeshBasicMaterial', clipping: { global: 1, local: 3, intersection: true } },
  { label: 'basic-custom-key', material: 'MeshBasicMaterial', customKey: 'my-key' },
  { label: 'lambert', material: 'MeshLambertMaterial', lights: LIGHTS },
  { label: 'lambert-no-normals', material: 'MeshLambertMaterial', geometry: { attributes: ['position', 'uv'] } },
  { label: 'lambert-maps', material: 'MeshLambertMaterial', maps: { map: {}, emissiveMap: { video: true, colorSpace: 'srgb' }, bumpMap: {}, normalMap: {}, displacementMap: {}, specularMap: {} }, env: 'cube', fog: 'linear' },
  { label: 'lambert-scene-env', material: 'MeshLambertMaterial', sceneEnv: 'cube' },
  { label: 'lambert-scene-pmrem', material: 'MeshLambertMaterial', sceneEnv: 'pmrem' },
  { label: 'lambert-flat', material: 'MeshLambertMaterial', set: { flatShading: true }, geometry: { attributes: ['position', 'normal', 'uv', 'tangent'], morph: ['normal'], morphCount: 1 }, maps: { normalMap: {} } },
  { label: 'phong', material: 'MeshPhongMaterial', maps: { specularMap: {}, normalMap: {} }, set: { normalMapType: 1 }, lights: LIGHTS, shadows: 2, renderer: { shadowMapEnabled: true, shadowMapType: 1 } },
  { label: 'phong-vsm', material: 'MeshPhongMaterial', lights: { directional: 1, directionalShadowMap: 1 }, shadows: 1, renderer: { shadowMapEnabled: true, shadowMapType: 3 } },
  { label: 'phong-basic-shadow', material: 'MeshPhongMaterial', lights: { point: 1, pointShadowMap: 1 }, shadows: 1, renderer: { shadowMapEnabled: true, shadowMapType: 0 } },
  { label: 'phong-shadow-no-casters', material: 'MeshPhongMaterial', lights: { spot: 1 }, renderer: { shadowMapEnabled: true, shadowMapType: 1 } },
  { label: 'phong-env-pmrem-scene', material: 'MeshPhongMaterial', sceneEnv: 'pmrem', set: { combine: 1 } },
  { label: 'toon', material: 'MeshToonMaterial', maps: { gradientMap: {}, map: {} }, lights: { hemi: 2 } },
  { label: 'standard', material: 'MeshStandardMaterial' },
  { label: 'standard-maps', material: 'MeshStandardMaterial', maps: { map: {}, roughnessMap: {}, metalnessMap: { channel: 1 }, normalMap: {}, aoMap: { channel: 3 }, lightMap: {}, emissiveMap: {}, displacementMap: {}, bumpMap: {}, alphaMap: {} }, geometry: { attributes: ['position', 'normal', 'uv', 'tangent'] } },
  { label: 'standard-packed-normal', material: 'MeshStandardMaterial', maps: { normalMap: { format: 1030 } } },
  { label: 'standard-packed-normal-eac', material: 'MeshStandardMaterial', maps: { normalMap: { format: 37490 } } },
  { label: 'standard-object-normal', material: 'MeshStandardMaterial', maps: { normalMap: {} }, set: { normalMapType: 1 } },
  { label: 'standard-pmrem', material: 'MeshStandardMaterial', env: 'pmrem' },
  { label: 'standard-scene-pmrem', material: 'MeshStandardMaterial', sceneEnv: 'pmrem', lights: LIGHTS },
  { label: 'standard-cube-incomplete', material: 'MeshStandardMaterial', env: 'cube' },
  { label: 'standard-wireframe-bump', material: 'MeshStandardMaterial', set: { wireframe: true }, maps: { bumpMap: {} }, geometry: { attributes: ['position', 'uv'] } },
  { label: 'standard-no-normals', material: 'MeshStandardMaterial', geometry: { attributes: ['position', 'uv'] } },
  { label: 'standard-flat', material: 'MeshStandardMaterial', set: { flatShading: true } },
  { label: 'standard-defines', material: 'MeshStandardMaterial', defines: { USE_THING: '', '1': 'one', COUNT: 3, OFF: false, ON: true } },
  { label: 'physical', material: 'MeshPhysicalMaterial' },
  { label: 'physical-all', material: 'MeshPhysicalMaterial', set: { clearcoat: 1, iridescence: 1, sheen: 1, transmission: 1, anisotropy: 0.5, dispersion: 1, diffuseRoughness: 0.5, retroreflectivity: 0.5, transparent: true }, maps: PHYS_MAPS, geometry: { attributes: ['position', 'normal', 'uv', 'tangent'] }, env: 'pmrem', fog: 'exp2', lights: LIGHTS, shadows: 1, renderer: { shadowMapEnabled: true, shadowMapType: 1, toneMapping: 4 } },
  { label: 'physical-maps-without-features', material: 'MeshPhysicalMaterial', maps: PHYS_MAPS },
  { label: 'physical-anisotropy-tangent-flat', material: 'MeshPhysicalMaterial', set: { anisotropy: 1, flatShading: true }, geometry: { attributes: ['position', 'normal', 'uv', 'tangent'] } },
  { label: 'matcap', material: 'MeshMatcapMaterial', maps: { matcap: {}, normalMap: {}, bumpMap: {} } },
  { label: 'matcap-plain', material: 'MeshMatcapMaterial', fog: 'linear' },
  { label: 'normal', material: 'MeshNormalMaterial', maps: { normalMap: {}, bumpMap: {}, displacementMap: {} }, set: { flatShading: true } },
  { label: 'depth', material: 'MeshDepthMaterial', set: { depthPacking: 3201 }, maps: { map: {}, alphaMap: {}, displacementMap: {} } },
  { label: 'depth-basic', material: 'MeshDepthMaterial', set: { depthPacking: 3200 } },
  { label: 'distance', material: 'MeshDistanceMaterial', maps: { alphaMap: {} } },
  { label: 'line', material: 'LineBasicMaterial', set: { vertexColors: true }, geometry: { attributes: ['position', 'color3'] }, object: 'line', fog: 'linear' },
  { label: 'line-dashed', material: 'LineDashedMaterial', object: 'line', maps: { map: {} } },
  { label: 'points', material: 'PointsMaterial', maps: { map: {} }, object: 'points', fog: 'exp2' },
  { label: 'points-no-attenuation', material: 'PointsMaterial', set: { sizeAttenuation: false }, maps: { alphaMap: {} }, geometry: { attributes: ['position'] }, object: 'points' },
  // a Sprite's shared geometry (position, uv) on a Mesh: constructing a Sprite would create
  // the module-level sprite geometry here and shift geometry ids in later renderer scenarios
  { label: 'sprite', material: 'SpriteMaterial', maps: { map: {}, alphaMap: {} }, geometry: { attributes: ['position', 'uv'] }, fog: 'linear' },
  { label: 'shadow', material: 'ShadowMaterial', lights: { directional: 1, directionalShadowMap: 1 }, shadows: 1, renderer: { shadowMapEnabled: true, shadowMapType: 1 }, fog: 'linear' },
  { label: 'shader', material: 'ShaderMaterial', shader: { vertexShader: CUSTOM_VERTEX, fragmentShader: CUSTOM_FRAGMENT, uniforms: ['time', 'offsets'] }, defines: { A: 1, B: false, C: '', '2': 'x', D: 1.5 }, lights: LIGHTS, clipping: { global: 2 } },
  { label: 'shader-glsl3-ext', material: 'ShaderMaterial', shader: { vertexShader: CUSTOM_VERTEX, fragmentShader: CUSTOM_FRAGMENT, glslVersion: '300 es', clipCullDistance: true, multiDraw: true, index0AttributeName: 'uv' }, set: { name: 'MyShader', fog: true, flatShading: true }, fog: 'exp2', customKey: 'k2' },
  { label: 'shader-same-source', material: 'ShaderMaterial', shader: { vertexShader: CUSTOM_VERTEX, fragmentShader: CUSTOM_FRAGMENT, uniforms: ['time'] }, defines: { A: 1, B: false, C: '', '2': 'x', D: 1.5 }, lights: LIGHTS, clipping: { global: 2 } },
  { label: 'shader-default', material: 'ShaderMaterial', object: 'batched' },
  { label: 'raw', material: 'RawShaderMaterial', shader: { vertexShader: RAW_VERTEX, fragmentShader: RAW_FRAGMENT }, defines: { X: 2 } },
  { label: 'raw-glsl3', material: 'RawShaderMaterial', shader: { vertexShader: RAW_VERTEX, fragmentShader: RAW_FRAGMENT, glslVersion: '300 es' }, set: { name: 'raw' } },
  { label: 'grids', material: 'MeshStandardMaterial', grids: [true, false, true] },
  { label: 'log2', material: 'MeshStandardMaterial', r: 2, lights: { directional: 1 } },
  { label: 'log2-basic', material: 'MeshBasicMaterial', r: 2, set: { precision: 'highp' } },
];

// A canvas stand-in for `new WebGLRenderer( { canvas, context } )`.
function createCanvas(gl, width, height) {
  return {
    width, height, style: {},
    setAttribute() {}, addEventListener() {}, removeEventListener() {},
    getContext() { return gl; },
  };
}

module.exports = { CASES, createCanvas };

if (require.main === module && process.argv.includes('--print-moonbit')) {
  const lines = ['  #|['];
  CASES.forEach((c, i) => lines.push('  #|' + JSON.stringify(c) + (i + 1 < CASES.length ? ',' : '')));
  lines.push('  #|]');
  console.log('///|\n/// CASES of harness/scenarios/programs_common.cjs, verbatim.\nlet programs_cases_json : String =\n' + lines.join('\n'));
}
