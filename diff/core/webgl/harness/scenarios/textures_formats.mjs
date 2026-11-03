// WebGLTextures: internal formats for every format/type pair, with and without
// EXT_texture_norm16, anisotropy and float filtering without extensions (group 1).
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
  const env = (extensionList) => {
    const gl = createMockGL({ extensions: extensionList });
    const extensions = new WebGLExtensions(gl);
    const utils = new WebGLUtils(gl, extensions);
    const capabilities = new WebGLCapabilities(gl, extensions, {}, utils);
    const state = new WebGLState(gl, extensions);
    const properties = new WebGLProperties();
    const info = new WebGLInfo(gl);
    const textures = new WebGLTextures(gl, extensions, state, properties, capabilities, utils, info);
    gl.__clear();
    return { gl, textures, properties };
  };
  const formats = [T.RedFormat, T.RedIntegerFormat, T.RGFormat, T.RGIntegerFormat, T.RGBAIntegerFormat, T.RGBFormat, T.RGBAFormat, T.AlphaFormat];
  const types = [T.UnsignedByteType, T.ByteType, T.ShortType, T.UnsignedShortType, T.IntType, T.UnsignedIntType, T.FloatType, T.HalfFloatType,
    T.UnsignedShort4444Type, T.UnsignedShort5551Type, T.UnsignedInt5999Type, T.UnsignedInt101111Type];
  const logs = [];
  for (const [label, list] of [['default', DEFAULTS], ['norm16', DEFAULTS.concat(['EXT_texture_norm16'])]]) {
    const { gl, textures } = env(list);
    gl.__note('extensions', label);
    for (const format of formats) {
      for (const type of types) {
        for (const normalized of [false, true]) {
          const t = new T.DataTexture(new Uint8Array(4), 1, 1, format, type);
          t.normalized = normalized;
          t.needsUpdate = true;
          textures.setTexture2D(t, 0);
        }
      }
    }
    const rt = new T.WebGLRenderTarget(2, 2, { depthBuffer: false, format: T.RGFormat, type: T.ShortType });
    rt.texture.normalized = true;
    textures.setupRenderTarget(rt);
    logs.push(...gl.__log);
  }
  // no anisotropic filtering and no float linear filtering
  {
    const { gl, textures, properties } = env(['EXT_color_buffer_float']);
    const t = new T.DataTexture(new Float32Array(4), 1, 1, T.RGBAFormat, T.FloatType);
    t.anisotropy = 4;
    t.magFilter = T.LinearFilter;
    t.minFilter = T.LinearMipmapLinearFilter;
    t.needsUpdate = true;
    textures.setTexture2D(t, 0);
    logs.push(...gl.__log);
  }
  {
    const { gl, textures, properties } = env(['EXT_texture_filter_anisotropic']);
    const t = new T.DataTexture(new Float32Array(4), 1, 1, T.RGBAFormat, T.FloatType);
    t.anisotropy = 4;
    t.magFilter = T.LinearFilter;
    t.minFilter = T.LinearMipmapLinearFilter;
    t.needsUpdate = true;
    textures.setTexture2D(t, 0);
    const u = new T.DataTexture(new Uint8Array(4), 1, 1);
    u.anisotropy = 32;
    u.magFilter = T.LinearFilter;
    u.minFilter = T.NearestMipmapLinearFilter;
    u.needsUpdate = true;
    textures.setTexture2D(u, 1);
    gl.__note('currentAnisotropy', properties.get(u).__currentAnisotropy);
    u.anisotropy = 1;
    u.needsUpdate = true;
    textures.setTexture2D(u, 1);
    u.minFilter = T.LinearMipmapNearestFilter;
    u.anisotropy = 2;
    u.needsUpdate = true;
    textures.setTexture2D(u, 1);
    u.minFilter = T.LinearMipmapLinearFilter;
    u.magFilter = T.NearestFilter;
    u.needsUpdate = true;
    textures.setTexture2D(u, 1);
    logs.push(...gl.__log);
  }
  return logs;
}
