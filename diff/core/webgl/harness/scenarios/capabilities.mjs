export async function run({ src, createMockGL }) {
  const { WebGLExtensions } = await import(src + '/renderers/webgl/WebGLExtensions.js');
  const { WebGLUtils } = await import(src + '/renderers/webgl/WebGLUtils.js');
  const { WebGLCapabilities } = await import(src + '/renderers/webgl/WebGLCapabilities.js');
  const gl = createMockGL({ precision: { HIGH_FLOAT: 0 }, extensions: ['EXT_texture_filter_anisotropic', 'EXT_color_buffer_float'], parameters: { IMPLEMENTATION_COLOR_READ_TYPE: 0x1403 } });
  const extensions = new WebGLExtensions(gl);
  const utils = new WebGLUtils(gl, extensions);
  const c = new WebGLCapabilities(gl, extensions, { precision: 'highp', logarithmicDepthBuffer: true, reversedDepthBuffer: true }, utils);
  for (const k of ['precision', 'logarithmicDepthBuffer', 'reversedDepthBuffer', 'maxTextures', 'maxVertexTextures', 'maxTextureSize', 'maxCubemapSize', 'maxAttributes', 'maxVertexUniforms', 'maxVaryings', 'maxFragmentUniforms', 'maxSamples', 'samples', 'isWebGL2']) gl.__note(k, c[k]);
  gl.__note('getMaxAnisotropy', c.getMaxAnisotropy());
  gl.__note('getMaxAnisotropy', c.getMaxAnisotropy());
  gl.__note('getMaxPrecision lowp', c.getMaxPrecision('lowp'));
  gl.__note('formatReadable RGBA', c.textureFormatReadable(1023));
  gl.__note('formatReadable Red', c.textureFormatReadable(1028));
  gl.__note('typeReadable HalfFloat', c.textureTypeReadable(1016));
  gl.__note('typeReadable UnsignedShort', c.textureTypeReadable(1012));
  gl.__note('typeReadable Int', c.textureTypeReadable(1013));
  const c2 = new WebGLCapabilities(gl, extensions, {}, utils);
  gl.__note('default precision', c2.precision);
  return gl.__log;
}
