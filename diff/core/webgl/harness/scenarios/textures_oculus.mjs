// WebGLTextures: invalidateFramebuffer after multisample resolves, which upstream only
// does in the Oculus browser (navigator.userAgent), with and without
// WEBGL_multisampled_render_to_texture (group 1).
const DEFAULTS = ['EXT_color_buffer_float', 'EXT_color_buffer_half_float', 'OES_texture_float_linear',
  'EXT_texture_filter_anisotropic', 'WEBGL_multi_draw', 'KHR_parallel_shader_compile',
  'WEBGL_lose_context', 'EXT_clip_control', 'WEBGL_compressed_texture_s3tc',
  'WEBGL_compressed_texture_astc', 'WEBGL_compressed_texture_etc'];
export async function run({ src, createMockGL }) {
  const { WebGLExtensions } = await import(src + '/renderers/webgl/WebGLExtensions.js');
  const { WebGLUtils } = await import(src + '/renderers/webgl/WebGLUtils.js');
  const { WebGLCapabilities } = await import(src + '/renderers/webgl/WebGLCapabilities.js');
  const { WebGLState } = await import(src + '/renderers/webgl/WebGLState.js');
  const { WebGLProperties } = await import(src + '/renderers/webgl/WebGLProperties.js');
  const { WebGLInfo } = await import(src + '/renderers/webgl/WebGLInfo.js');
  const { WebGLTextures } = await import(src + '/renderers/webgl/WebGLTextures.js');
  const T = await import(src + '/Three.Core.js');
  const logs = [];
  for (const list of [DEFAULTS, DEFAULTS.concat(['WEBGL_multisampled_render_to_texture'])]) {
    const gl = createMockGL({ extensions: list });
    const extensions = new WebGLExtensions(gl);
    const utils = new WebGLUtils(gl, extensions);
    const capabilities = new WebGLCapabilities(gl, extensions, {}, utils);
    const state = new WebGLState(gl, extensions);
    const properties = new WebGLProperties();
    const info = new WebGLInfo(gl);
    const saved = Object.getOwnPropertyDescriptor(globalThis, 'navigator');
    Object.defineProperty(globalThis, 'navigator', { value: { userAgent: 'Mozilla/5.0 OculusBrowser/30.0' }, configurable: true, writable: true });
    const textures = new WebGLTextures(gl, extensions, state, properties, capabilities, utils, info);
    if (saved) Object.defineProperty(globalThis, 'navigator', saved); else delete globalThis.navigator;
    gl.__clear();
    const r1 = new T.WebGLRenderTarget(4, 4, { samples: 4, stencilBuffer: true });
    textures.setupRenderTarget(r1);
    textures.updateMultisampleRenderTarget(r1);
    r1.storeMultisampledDepthBuffer = false;
    textures.updateMultisampleRenderTarget(r1);
    const r2 = new T.WebGLRenderTarget(4, 4, { samples: 4, count: 2, depthBuffer: false });
    textures.setupRenderTarget(r2);
    textures.updateMultisampleRenderTarget(r2);
    logs.push(...gl.__log);
  }
  return logs;
}
