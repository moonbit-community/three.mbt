// WebGLTextures: render targets with WEBGL_multisampled_render_to_texture (group 1).
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
  const gl = createMockGL({ extensions: DEFAULTS.concat(['WEBGL_multisampled_render_to_texture']) });
  const extensions = new WebGLExtensions(gl);
  const utils = new WebGLUtils(gl, extensions);
  const capabilities = new WebGLCapabilities(gl, extensions, {}, utils);
  const state = new WebGLState(gl, extensions);
  const properties = new WebGLProperties();
  const info = new WebGLInfo(gl);
  const textures = new WebGLTextures(gl, extensions, state, properties, capabilities, utils, info);
  gl.__clear();
  const r1 = new T.WebGLRenderTarget(4, 4, { samples: 4, stencilBuffer: true });
  textures.setupRenderTarget(r1);
  gl.__note('useMultisampledRTT', textures.useMultisampledRTT(r1));
  textures.updateMultisampleRenderTarget(r1);
  r1.storeMultisampledDepthBuffer = false;
  textures.updateMultisampleRenderTarget(r1);
  const r2 = new T.WebGLRenderTarget(4, 4, { samples: 2, depthTexture: new T.DepthTexture(4, 4) });
  textures.setupRenderTarget(r2);
  const z = new T.DepthTexture(4, 4);
  z.format = T.DepthStencilFormat;
  const r3 = new T.WebGLRenderTarget(4, 4, { samples: 2, depthTexture: z });
  textures.setupRenderTarget(r3);
  const r4 = new T.WebGLRenderTarget(4, 4, { samples: 4 });
  properties.get(r4).__useRenderToTexture = false;
  gl.__note('useMultisampledRTT', textures.useMultisampledRTT(r4));
  textures.setupRenderTarget(r4);
  textures.updateMultisampleRenderTarget(r4);
  const r5 = new T.WebGLRenderTarget(4, 4, { samples: 4, depthBuffer: false });
  textures.setupRenderTarget(r5);
  r1.dispose();
  r2.dispose();
  r4.dispose();
  gl.__note('memory', info.memory.textures);
  return gl.__log;
}
