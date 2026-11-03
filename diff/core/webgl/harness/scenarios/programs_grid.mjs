// Group 2: WebGLPrograms / WebGLProgram over the material grid of programs_common.cjs.
// Per case the log holds the parameter digest, the program cache key, the uniform names,
// and (through shaderSource) the full vertex and fragment GLSL after prefix, include
// resolution and loop unrolling; then program bookkeeping (cache hits, ready state,
// first-use diagnostics, release).
import { createRequire } from 'node:module';
const { CASES, createCanvas } = createRequire(import.meta.url)('./programs_common.cjs');

export async function run({ src, createMockGL }) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const { WebGLAttributes } = await import(src + '/renderers/webgl/WebGLAttributes.js');
  const { WebGLBindingStates } = await import(src + '/renderers/webgl/WebGLBindingStates.js');
  const { WebGLEnvironments } = await import(src + '/renderers/webgl/WebGLEnvironments.js');
  const { WebGLClipping } = await import(src + '/renderers/webgl/WebGLClipping.js');
  const { WebGLPrograms } = await import(src + '/renderers/webgl/WebGLPrograms.js');

  const gl = createMockGL({ extensions: ['EXT_color_buffer_float', 'WEBGL_multi_draw', 'KHR_parallel_shader_compile', 'EXT_clip_control', 'WEBGL_clip_cull_distance'], canvas: { width: 64, height: 32 } });
  const gl2 = createMockGL({ extensions: [], canvas: { width: 64, height: 32 } });
  function setup(g, options) {
    const renderer = new WebGLRenderer(Object.assign({ canvas: createCanvas(g, 64, 32), context: g }, options));
    const bindingStates = new WebGLBindingStates(g, new WebGLAttributes(g));
    const environments = new WebGLEnvironments(renderer);
    const clipping = new WebGLClipping(renderer.properties);
    const programs = new WebGLPrograms(renderer, environments, renderer.extensions, renderer.capabilities, bindingStates, clipping);
    return { gl: g, renderer, clipping, programs };
  }
  const R1 = setup(gl, {});
  const R2 = setup(gl2, { logarithmicDepthBuffer: true, precision: 'mediump' });
  gl.__clear();
  gl2.__clear();
  const renderTarget = new T.WebGLRenderTarget(4, 4);
  const camera = new T.PerspectiveCamera();
  let stageBase, programBase;

  function texture(spec) {
    const t = spec.video ? new T.VideoTexture({}) : new T.Texture();
    if (spec.channel !== undefined) t.channel = spec.channel;
    if (spec.format !== undefined) t.format = spec.format;
    if (spec.colorSpace !== undefined) t.colorSpace = spec.colorSpace;
    return t;
  }
  function envTexture(kind) {
    if (kind === 'pmrem') {
      const t = new T.Texture();
      t.isPMREMTexture = true;
      for (let i = 0; i < 9; i++) t.mipmaps.push({ width: 256 >> i, height: 256 >> i });
      return t;
    }
    const t = new T.CubeTexture();
    if (kind === 'cubeRefraction') t.mapping = T.CubeRefractionMapping;
    return t;
  }
  function geometry(spec) {
    const g = new T.BufferGeometry();
    const sizes = { position: 3, normal: 3, uv: 2, tangent: 4, color3: 3, color4: 4 };
    for (const name of spec.attributes || ['position', 'normal', 'uv']) {
      const size = sizes[name];
      g.setAttribute(name.startsWith('color') ? 'color' : name, new T.Float32BufferAttribute(new Float32Array(3 * size), size));
    }
    for (const name of spec.morph || []) {
      g.morphAttributes[name] = [];
      for (let i = 0; i < spec.morphCount; i++) g.morphAttributes[name].push(new T.Float32BufferAttribute(new Float32Array(9), 3));
    }
    return g;
  }
  function object(kind, g, material) {
    switch (kind) {
      case 'skinned': return new T.SkinnedMesh(g, material);
      case 'instanced': return new T.InstancedMesh(g, material, 2);
      case 'instancedColorMorph': {
        const o = new T.InstancedMesh(g, material, 2);
        o.setColorAt(0, new T.Color(1, 0, 0));
        o.morphTexture = new T.DataTexture();
        return o;
      }
      case 'batched': return new T.BatchedMesh(2, 6, 6, material);
      case 'batchedColor': {
        const o = new T.BatchedMesh(2, 6, 6, material);
        o._colorsTexture = new T.DataTexture();
        return o;
      }
      case 'points': return new T.Points(g, material);
      case 'line': return new T.Line(g, material);
      default: return new T.Mesh(g, material);
    }
  }
  function lightsState(spec) {
    const s = { numSpotLightShadowsWithMaps: 0, numLightProbes: 0 };
    for (const k of ['sun', 'directional', 'point', 'spot', 'spotLightMap', 'rectArea', 'hemi', 'sunShadowMap', 'directionalShadowMap', 'pointShadowMap', 'spotShadowMap']) {
      s[k] = new Array((spec && spec[k]) || 0).fill(null);
    }
    if (spec && spec.numSpotLightShadowsWithMaps) s.numSpotLightShadowsWithMaps = spec.numSpotLightShadowsWithMaps;
    if (spec && spec.numLightProbes) s.numLightProbes = spec.numLightProbes;
    return s;
  }
  function digest(p) {
    return Object.keys(p).sort().map((k) => {
      const v = p[k];
      if (k === 'vertexShader' || k === 'fragmentShader' || k === 'uniforms') return null;
      if (k === 'customVertexShaderID' || k === 'customFragmentShaderID') return k + '=' + (v === undefined ? 'undefined' : v - stageBase);
      if (k === 'glslVersion') return k + '=' + (v == null ? 'none' : v);
      if (k === 'fogExp2' || k === 'flatShading') return k + '=' + !!v;
      if (k === 'defines') return k + '=' + (v === undefined ? 'undefined' : '{' + Object.keys(v).map((n) => n + ':' + String(v[n])).join('|') + '}');
      return k + '=' + (v === undefined ? 'undefined' : v === null ? 'null' : String(v));
    }).filter((x) => x !== null).join(';');
  }
  function normalizeKey(key, p) {
    if (p.shaderID) return key;
    const parts = key.split(',');
    parts[0] = String(Number(parts[0]) - stageBase);
    parts[1] = String(Number(parts[1]) - stageBase);
    return parts.join(',');
  }

  const acquired = [];
  for (const c of CASES) {
    const R = c.r === 2 ? R2 : R1;
    const g = R.gl;
    const renderer = R.renderer;
    const rs = c.renderer || {};
    renderer.toneMapping = rs.toneMapping || 0;
    renderer.outputColorSpace = rs.outputColorSpace || 'srgb';
    renderer.shadowMap.enabled = !!rs.shadowMapEnabled;
    renderer.shadowMap.type = rs.shadowMapType !== undefined ? rs.shadowMapType : 1;
    if (rs.renderTarget) renderer.setRenderTarget(renderTarget);
    if (rs.reversed) renderer.state.buffers.depth.setReversed(true);
    const material = new T[c.material]();
    for (const k in c.set || {}) material[k] = c.set[k];
    for (const k in c.maps || {}) material[k] = texture(c.maps[k]);
    if (c.env) material.envMap = envTexture(c.env);
    if (c.defines) material.defines = Object.assign(material.defines || {}, c.defines);
    if (c.customKey) material.customProgramCacheKey = () => c.customKey;
    if (c.shader) {
      if (c.shader.vertexShader) material.vertexShader = c.shader.vertexShader;
      if (c.shader.fragmentShader) material.fragmentShader = c.shader.fragmentShader;
      if (c.shader.glslVersion) material.glslVersion = c.shader.glslVersion;
      if (c.shader.clipCullDistance) material.extensions.clipCullDistance = true;
      if (c.shader.multiDraw) material.extensions.multiDraw = true;
      if (c.shader.index0AttributeName) material.index0AttributeName = c.shader.index0AttributeName;
      for (const u of c.shader.uniforms || []) material.uniforms[u] = new T.Uniform(0);
    }
    const scene = new T.Scene();
    if (c.fog === 'linear') scene.fog = new T.Fog(0xffffff, 1, 10);
    if (c.fog === 'exp2') scene.fog = new T.FogExp2(0xffffff, 0.1);
    if (c.sceneEnv) scene.environment = envTexture(c.sceneEnv);
    const obj = object(c.object, geometry(c.geometry || {}), material);
    const shadows = [];
    for (let i = 0; i < (c.shadows || 0); i++) shadows.push(new T.Object3D());
    const grids = (c.grids || []).map((hasTexture) => ({ texture: hasTexture ? new T.Texture() : null }));
    const clip = c.clipping || {};
    const globalPlanes = [];
    for (let i = 0; i < (clip.global || 0); i++) globalPlanes.push(new T.Plane(new T.Vector3(1, 0, 0), i));
    if (clip.local) {
      material.clippingPlanes = [];
      for (let i = 0; i < clip.local; i++) material.clippingPlanes.push(new T.Plane(new T.Vector3(0, 1, 0), i));
      material.clipIntersection = !!clip.intersection;
    }
    R.clipping.init(globalPlanes, !!clip.local);
    R.clipping.setGlobalState(globalPlanes, camera);
    R.clipping.setState(material, camera, false);

    const params = R.programs.getParameters(material, lightsState(c.lights), shadows, scene, obj, grids);
    if (stageBase === undefined && params.customVertexShaderID !== undefined) stageBase = params.customVertexShaderID;
    g.__note(c.label + ' params', digest(params));
    const key = R.programs.getProgramCacheKey(params);
    g.__note(c.label + ' key', normalizeKey(key, params));
    params.uniforms = R.programs.getUniforms(material);
    g.__note(c.label + ' uniforms', Object.keys(params.uniforms).join(' '));
    const program = R.programs.acquireProgram(params, key);
    if (programBase === undefined) programBase = program.id;
    g.__note(c.label + ' program', [program.type, program.name, program.usedTimes, program.id - programBase, program.cacheKey === key].join(' '));
    acquired.push({ R, program, material });

    if (rs.renderTarget) renderer.setRenderTarget(null);
    if (rs.reversed) renderer.state.buffers.depth.setReversed(false);
  }
  // program bookkeeping
  gl.__note('programs', R1.programs.programs.length);
  gl2.__note('programs', R2.programs.programs.length);
  const first = acquired[0].program;
  gl.__note('ready', first.isReady());
  gl.__note('ready', first.isReady());
  gl2.__note('ready', acquired[acquired.length - 1].program.isReady());
  const attributes = first.getAttributes();
  gl.__note('attributes', Object.keys(attributes).join(' '));
  first.getUniforms();
  gl.__note('diagnostics', first.diagnostics === undefined ? 'undefined' : 'set');
  R1.renderer.debug.checkShaderErrors = false;
  acquired[1].program.getUniforms();
  R1.renderer.debug.checkShaderErrors = true;
  for (const { R, program, material } of acquired) {
    R.programs.releaseProgram(program);
    if (material.isShaderMaterial) R.programs.releaseShaderCache(material);
  }
  gl.__note('programs', R1.programs.programs.length);
  gl2.__note('programs', R2.programs.programs.length);
  R1.programs.dispose();
  R2.programs.dispose();
  gl.__note('gl2', gl2.__log);
  return gl.__log;
}
