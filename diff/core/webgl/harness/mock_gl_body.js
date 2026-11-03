// A recording mock of WebGL2RenderingContext. Every method in MOCK_GL_METHODS records
// `name(args)` in `gl.__log`; queries answer from `options`. The same source runs under
// upstream three.js (harness/run_diff.mjs) and under MoonBit (webgl_mock_gl_test.mbt).
//
// options = {
//   extensions: [ names ]          supported extensions (default: DEFAULT_EXTENSIONS)
//   parameters: { PNAME: value }    getParameter overrides, by constant name
//   precision: { HIGH_FLOAT: n }    getShaderPrecisionFormat().precision (default 23)
//   programs: [ { attributes: [ { name, type, size } ], uniforms: [ { name, type, size } ] } ]
//                                   active attributes / uniforms, by program creation order
//   canvas: { width, height }
//   linkStatus, compileStatus: booleans (default true)
//   programInfoLog, shaderInfoLog, shaderSource: strings the info-log / source queries
//                                   return (default ''; added by group 2)
//   logQueries: false to leave get* calls out of the log
//   queries: { available, result } answers of getQueryParameter (added by G10; default
//                                   every query reads 0)
// }

const DEFAULT_EXTENSIONS = [
  'EXT_color_buffer_float', 'EXT_color_buffer_half_float', 'OES_texture_float_linear',
  'EXT_texture_filter_anisotropic', 'WEBGL_multi_draw', 'KHR_parallel_shader_compile',
  'WEBGL_lose_context', 'EXT_clip_control', 'WEBGL_compressed_texture_s3tc',
  'WEBGL_compressed_texture_astc', 'WEBGL_compressed_texture_etc',
];

// Constants the renderer reads off extension objects.
const EXTENSION_CONSTANTS = {
  EXT_texture_filter_anisotropic: { MAX_TEXTURE_MAX_ANISOTROPY_EXT: 0x84FF, TEXTURE_MAX_ANISOTROPY_EXT: 0x84FE },
  EXT_clip_control: { LOWER_LEFT_EXT: 0x8CA1, UPPER_LEFT_EXT: 0x8CA2, NEGATIVE_ONE_TO_ONE_EXT: 0x935E, ZERO_TO_ONE_EXT: 0x935F },
  KHR_parallel_shader_compile: { COMPLETION_STATUS_KHR: 0x91B1 },
  WEBGL_compressed_texture_s3tc: { COMPRESSED_RGB_S3TC_DXT1_EXT: 0x83F0, COMPRESSED_RGBA_S3TC_DXT1_EXT: 0x83F1, COMPRESSED_RGBA_S3TC_DXT3_EXT: 0x83F2, COMPRESSED_RGBA_S3TC_DXT5_EXT: 0x83F3 },
  WEBGL_compressed_texture_s3tc_srgb: { COMPRESSED_SRGB_S3TC_DXT1_EXT: 0x8C4C, COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT: 0x8C4D, COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT: 0x8C4E, COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT: 0x8C4F },
  WEBGL_compressed_texture_pvrtc: { COMPRESSED_RGB_PVRTC_4BPPV1_IMG: 0x8C00, COMPRESSED_RGB_PVRTC_2BPPV1_IMG: 0x8C01, COMPRESSED_RGBA_PVRTC_4BPPV1_IMG: 0x8C02, COMPRESSED_RGBA_PVRTC_2BPPV1_IMG: 0x8C03 },
  WEBGL_compressed_texture_etc: { COMPRESSED_R11_EAC: 0x9270, COMPRESSED_SIGNED_R11_EAC: 0x9271, COMPRESSED_RG11_EAC: 0x9272, COMPRESSED_SIGNED_RG11_EAC: 0x9273, COMPRESSED_RGB8_ETC2: 0x9274, COMPRESSED_SRGB8_ETC2: 0x9275, COMPRESSED_RGBA8_ETC2_EAC: 0x9278, COMPRESSED_SRGB8_ALPHA8_ETC2_EAC: 0x9279 },
  EXT_texture_compression_bptc: { COMPRESSED_RGBA_BPTC_UNORM_EXT: 0x8E8C, COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT: 0x8E8D, COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT: 0x8E8E, COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT: 0x8E8F },
  EXT_texture_compression_rgtc: { COMPRESSED_RED_RGTC1_EXT: 0x8DBB, COMPRESSED_SIGNED_RED_RGTC1_EXT: 0x8DBC, COMPRESSED_RED_GREEN_RGTC2_EXT: 0x8DBD, COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT: 0x8DBE },
  EXT_disjoint_timer_query_webgl2: { QUERY_COUNTER_BITS_EXT: 0x8864, TIME_ELAPSED_EXT: 0x88BF, TIMESTAMP_EXT: 0x8E28, GPU_DISJOINT_EXT: 0x8FBB },
  EXT_texture_norm16: { R16_EXT: 0x822A, RG16_EXT: 0x822C, RGB16_EXT: 0x8054, RGBA16_EXT: 0x805B, R16_SNORM_EXT: 0x8F98, RG16_SNORM_EXT: 0x8F99, RGB16_SNORM_EXT: 0x8F9A, RGBA16_SNORM_EXT: 0x8F9B },
};
(function addAstc() {
  const table = {};
  const blocks = ['4x4', '5x4', '5x5', '6x5', '6x6', '8x5', '8x6', '8x8', '10x5', '10x6', '10x8', '10x10', '12x10', '12x12'];
  blocks.forEach((b, i) => { table[`COMPRESSED_RGBA_ASTC_${b}_KHR`] = 0x93B0 + i; table[`COMPRESSED_SRGB8_ALPHA8_ASTC_${b}_KHR`] = 0x93D0 + i; });
  EXTENSION_CONSTANTS.WEBGL_compressed_texture_astc = table;
})();

const EXTENSION_METHODS = {
  WEBGL_multi_draw: ['multiDrawArraysWEBGL', 'multiDrawElementsWEBGL', 'multiDrawArraysInstancedWEBGL', 'multiDrawElementsInstancedWEBGL'],
  WEBGL_lose_context: ['loseContext', 'restoreContext'],
  EXT_clip_control: ['clipControlEXT'],
  WEBGL_multisampled_render_to_texture: ['framebufferTexture2DMultisampleEXT', 'renderbufferStorageMultisampleEXT'],
  WEBGL_debug_shaders: ['getTranslatedShaderSource'],
  OVR_multiview2: ['framebufferTextureMultisampleMultiviewOVR'],
};

// Arguments that WebGL converts with ToUint32 (masks): logged as unsigned so 0xffffffff
// and -1 compare equal.
const UINT_ARGS = { stencilMask: [0], stencilFunc: [2], stencilMaskSeparate: [1], stencilFuncSeparate: [3] };

const QUERIES = new Set(['getParameter', 'getExtension', 'getShaderPrecisionFormat', 'getProgramParameter',
  'getShaderParameter', 'getProgramInfoLog', 'getShaderInfoLog', 'getShaderSource', 'getActiveAttrib',
  'getActiveUniform', 'getAttribLocation', 'getUniformLocation', 'getUniformBlockIndex', 'getError',
  'getContextAttributes', 'getQueryParameter', 'getSupportedExtensions']);

function createMockGL(options) {
  options = options || {};
  const log = [];
  const counters = {};
  const gl = {};
  for (const k in MOCK_GL_CONSTANTS) gl[k] = MOCK_GL_CONSTANTS[k];
  const C = MOCK_GL_CONSTANTS;
  const logQueries = options.logQueries !== false;

  function handle(kind, extra) {
    counters[kind] = (counters[kind] || 0) + 1;
    const h = { __mock: kind, __id: counters[kind] };
    Object.assign(h, extra || {});
    return h;
  }

  function norm(v) {
    if (v === null) return null;
    if (v === undefined) return 'undefined';
    if (typeof v === 'number' || typeof v === 'boolean' || typeof v === 'string') return v;
    if (typeof v === 'function') return 'function';
    if (v.__mock) return v.__mock + '#' + v.__id;
    if (ArrayBuffer.isView(v)) return { [v.constructor.name]: Array.from(v) };
    if (Array.isArray(v)) return v.map(norm);
    return 'object';
  }

  function record(name, args) {
    const a = Array.from(args).map(norm);
    const idx = UINT_ARGS[name];
    if (idx) for (const i of idx) if (typeof a[i] === 'number') a[i] = a[i] >>> 0;
    log.push(name + '(' + a.map((x) => JSON.stringify(x)).join(', ') + ')');
  }

  const parameters = {
    MAX_VERTEX_ATTRIBS: 16, MAX_TEXTURE_IMAGE_UNITS: 16, MAX_VERTEX_TEXTURE_IMAGE_UNITS: 16,
    MAX_COMBINED_TEXTURE_IMAGE_UNITS: 32, MAX_TEXTURE_SIZE: 4096, MAX_CUBE_MAP_TEXTURE_SIZE: 4096,
    MAX_VERTEX_UNIFORM_VECTORS: 1024, MAX_VARYING_VECTORS: 30, MAX_FRAGMENT_UNIFORM_VECTORS: 1024,
    MAX_SAMPLES: 4, SAMPLES: 4, VERSION: 'WebGL 2.0 (mock)',
    IMPLEMENTATION_COLOR_READ_FORMAT: C.RGBA, IMPLEMENTATION_COLOR_READ_TYPE: C.UNSIGNED_BYTE,
    MAX_TEXTURE_MAX_ANISOTROPY_EXT: 16,
  };
  Object.assign(parameters, options.parameters || {});
  const canvas = Object.assign({ width: 300, height: 150 }, options.canvas || {});
  const byValue = {};
  for (const k in parameters) {
    const v = C[k] !== undefined ? C[k] : (EXTENSION_CONSTANTS.EXT_texture_filter_anisotropic[k]);
    if (v !== undefined) byValue[v] = parameters[k];
  }
  const supported = options.extensions || DEFAULT_EXTENSIONS;
  const extensionObjects = {};
  const programSpecs = options.programs || [];
  let programCount = 0;

  const impl = {
    getParameter(p) {
      if (p === C.SCISSOR_BOX || p === C.VIEWPORT) return new Int32Array([0, 0, canvas.width, canvas.height]);
      return byValue[p] !== undefined ? byValue[p] : null;
    },
    getExtension(name) {
      if (supported.indexOf(name) === -1) return null;
      if (!extensionObjects[name]) {
        const ext = Object.assign({ __mock: 'Extension:' + name, __id: 1 }, EXTENSION_CONSTANTS[name] || {});
        for (const m of EXTENSION_METHODS[name] || []) {
          ext[m] = function () { record(name + '.' + m, arguments); return m === 'getTranslatedShaderSource' ? '' : undefined; };
        }
        extensionObjects[name] = ext;
      }
      return extensionObjects[name];
    },
    getShaderPrecisionFormat(shaderType, precisionType) {
      const name = Object.keys(C).find((k) => C[k] === precisionType && /_(FLOAT|INT)$/.test(k));
      const p = options.precision && options.precision[name] !== undefined ? options.precision[name] : 23;
      return { rangeMin: 127, rangeMax: 127, precision: p };
    },
    getContextAttributes() { return Object.assign({ alpha: true, depth: true, stencil: false, antialias: false, premultipliedAlpha: true, preserveDrawingBuffer: false }, options.contextAttributes || {}); },
    getError() { return 0; },
    getSupportedExtensions() { return supported.slice(); },
    createBuffer() { return handle('Buffer'); },
    createFramebuffer() { return handle('Framebuffer'); },
    createRenderbuffer() { return handle('Renderbuffer'); },
    createTexture() { return handle('Texture'); },
    createVertexArray() { return handle('VertexArray'); },
    createShader(type) { return handle('Shader', { __type: type }); },
    createQuery() { return handle('Query'); },
    createProgram() { return handle('Program', { __spec: programSpecs[programCount++] || { attributes: [], uniforms: [] } }); },
    fenceSync() { return handle('Sync'); },
    clientWaitSync() { return C.ALREADY_SIGNALED || 0x911A; },
    getProgramParameter(program, p) {
      if (p === C.ACTIVE_ATTRIBUTES) return program.__spec.attributes.length;
      if (p === C.ACTIVE_UNIFORMS) return program.__spec.uniforms.length;
      if (p === C.LINK_STATUS) return options.linkStatus !== false;
      if (p === C.VALIDATE_STATUS) return true;
      if (p === 0x91B1) return true;
      return null;
    },
    getShaderParameter(shader, p) { return p === C.COMPILE_STATUS ? options.compileStatus !== false : null; },
    getProgramInfoLog() { return options.programInfoLog || ''; },
    getShaderInfoLog() { return options.shaderInfoLog || ''; },
    getShaderSource() { return options.shaderSource || ''; },
    getActiveAttrib(program, i) { const a = program.__spec.attributes[i]; return { name: a.name, type: a.type, size: a.size || 1 }; },
    getActiveUniform(program, i) { const u = program.__spec.uniforms[i]; return { name: u.name, type: u.type, size: u.size || 1 }; },
    getAttribLocation(program, name) { return program.__spec.attributes.findIndex((a) => a.name === name); },
    getUniformLocation(program, name) { return { __mock: 'UniformLocation', __id: name }; },
    getUniformBlockIndex(program, name) { return 0; },
    getQueryParameter(query, p) {
      // options.queries (added by G10): { available, result, disjoint } answers for query
      // objects; without it every query reads 0 (never available).
      if (!options.queries) return 0;
      if (p === C.QUERY_RESULT_AVAILABLE) return options.queries.available !== false;
      if (p === C.QUERY_RESULT) return options.queries.result !== undefined ? options.queries.result : 0;
      return 0;
    },
  };

  for (const name of MOCK_GL_METHODS) {
    gl[name] = function () {
      if (!QUERIES.has(name) || logQueries) record(name, arguments);
      return impl[name] ? impl[name].apply(null, arguments) : undefined;
    };
  }
  gl.canvas = canvas;
  gl.__log = log;
  gl.__note = function (label, value) { log.push('# ' + label + ' ' + JSON.stringify(norm(value))); };
  gl.__clear = function () { log.length = 0; };
  return gl;
}

// A stand-in for `self` with requestAnimationFrame / cancelAnimationFrame that records
// calls into `gl.__log` and runs frames on `context.__tick( time )`.
function createMockAnimationContext(gl) {
  let next = 1;
  let pending = [];
  return {
    requestAnimationFrame(callback) { const id = next++; pending.push({ id, callback }); gl.__log.push('requestAnimationFrame() -> ' + id); return id; },
    cancelAnimationFrame(id) { gl.__log.push('cancelAnimationFrame(' + JSON.stringify(id === undefined ? 'undefined' : id) + ')'); pending = pending.filter((p) => p.id !== id); },
    __tick(time) { const run = pending; pending = []; for (const p of run) p.callback(time); },
  };
}
