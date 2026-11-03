// WebGLTextures: texture units, 2D data / image textures, parameters, cache keys,
// update ranges, mipmaps, internal formats and disposal (group 1).
export async function run({ src, createMockGL }) {
  const { WebGLExtensions } = await import(src + '/renderers/webgl/WebGLExtensions.js');
  const { WebGLUtils } = await import(src + '/renderers/webgl/WebGLUtils.js');
  const { WebGLCapabilities } = await import(src + '/renderers/webgl/WebGLCapabilities.js');
  const { WebGLState } = await import(src + '/renderers/webgl/WebGLState.js');
  const { WebGLProperties } = await import(src + '/renderers/webgl/WebGLProperties.js');
  const { WebGLInfo } = await import(src + '/renderers/webgl/WebGLInfo.js');
  const { WebGLTextures } = await import(src + '/renderers/webgl/WebGLTextures.js');
  const T = await import(src + '/Three.Core.js');
  const gl = createMockGL({});
  const extensions = new WebGLExtensions(gl);
  const utils = new WebGLUtils(gl, extensions);
  const capabilities = new WebGLCapabilities(gl, extensions, {}, utils);
  const state = new WebGLState(gl, extensions);
  const properties = new WebGLProperties();
  const info = new WebGLInfo(gl);
  const textures = new WebGLTextures(gl, extensions, state, properties, capabilities, utils, info);
  gl.__clear();
  const mem = (label) => gl.__note(label, info.memory.textures);

  // texture units
  gl.__note('unit', textures.allocateTextureUnit());
  gl.__note('unit', textures.allocateTextureUnit());
  gl.__note('units', textures.getTextureUnits());
  textures.setTextureUnits(5);
  gl.__note('unit', textures.allocateTextureUnit());
  textures.resetTextureUnits();
  gl.__note('units', textures.getTextureUnits());

  // data texture: upload, rebind, reupload
  const data = new Uint8Array(64);
  for (let i = 0; i < 64; i++) data[i] = i;
  const t1 = new T.DataTexture(data, 4, 4);
  textures.setTexture2D(t1, 0);
  gl.__note('version 0', 'no upload');
  t1.needsUpdate = true;
  textures.setTexture2D(t1, 0);
  mem('memory');
  textures.setTexture2D(t1, 0);
  textures.setTexture2D(t1, 1);
  t1.needsUpdate = true;
  textures.setTexture2D(t1, 0);

  // parameters change the cache key: new GL texture, old one deleted
  t1.minFilter = T.LinearMipmapLinearFilter;
  t1.magFilter = T.LinearFilter;
  t1.anisotropy = 8;
  t1.generateMipmaps = true;
  t1.wrapS = T.RepeatWrapping;
  t1.wrapT = T.MirroredRepeatWrapping;
  t1.needsUpdate = true;
  textures.setTexture2D(t1, 0);
  mem('memory');

  // update ranges are merged
  t1.addUpdateRange(8, 4);
  t1.addUpdateRange(0, 8);
  t1.addUpdateRange(32, 4);
  t1.addUpdateRange(13, 6);
  t1.needsUpdate = true;
  textures.setTexture2D(t1, 0);
  gl.__note('ranges', t1.updateRanges.length);
  t1.addUpdateRange(5, 3);
  t1.addUpdateRange(0, 4);
  t1.addUpdateRange(40, 8);
  t1.addUpdateRange(48, 8);
  t1.needsUpdate = true;
  textures.setTexture2D(t1, 0);

  // clone shares the source
  const t2 = t1.clone();
  textures.setTexture2D(t2, 2);
  mem('memory');
  textures.setTexture2D(t1, 0);

  // float, red, sRGB, named and normalized internal formats
  const t3 = new T.DataTexture(new Float32Array(4), 1, 1, T.RGBAFormat, T.FloatType);
  t3.needsUpdate = true;
  textures.setTexture2D(t3, 3);
  const t4 = new T.DataTexture(new Uint8Array(4), 2, 2, T.RedFormat);
  t4.needsUpdate = true;
  textures.setTexture2D(t4, 3);
  const t5 = new T.DataTexture(new Uint8Array(4), 1, 1);
  t5.colorSpace = T.SRGBColorSpace;
  t5.flipY = true;
  t5.premultiplyAlpha = true;
  t5.unpackAlignment = 1;
  t5.needsUpdate = true;
  textures.setTexture2D(t5, 3);
  const t6 = new T.DataTexture(new Float32Array(4), 1, 1, T.RGBAFormat, T.HalfFloatType);
  t6.internalFormat = 'RGBA16F';
  t6.needsUpdate = true;
  textures.setTexture2D(t6, 3);
  const t7 = new T.DataTexture(new Uint8Array(4), 1, 1);
  t7.internalFormat = 'NOT_A_FORMAT';
  t7.needsUpdate = true;
  textures.setTexture2D(t7, 3);
  const t8 = new T.DataTexture(new Uint16Array(4), 1, 1, T.RGBAFormat, T.UnsignedShortType);
  t8.normalized = true;
  t8.needsUpdate = true;
  textures.setTexture2D(t8, 3);
  const t9 = new T.DataTexture(new Uint8Array(8), 2, 1, T.RGFormat);
  t9.compareFunction = T.LessEqualCompare;
  t9.needsUpdate = true;
  textures.setTexture2D(t9, 3);

  // data texture mipmaps
  const t10 = new T.DataTexture(null, 4, 4);
  t10.mipmaps = [
    { data: new Uint8Array(64), width: 4, height: 4 },
    { data: new Uint8Array(16), width: 2, height: 2 },
    { data: new Uint8Array(4), width: 1, height: 1 },
  ];
  t10.generateMipmaps = true;
  t10.minFilter = T.LinearMipmapLinearFilter;
  t10.needsUpdate = true;
  textures.setTexture2D(t10, 4);
  gl.__note('generateMipmaps', t10.generateMipmaps);

  // non-power-of-two mip chain: fractional level count, as upstream
  const t11 = new T.DataTexture(new Uint8Array(72), 6, 3);
  t11.generateMipmaps = true;
  t11.minFilter = T.LinearMipmapNearestFilter;
  t11.needsUpdate = true;
  textures.setTexture2D(t11, 4);

  // image textures
  const t12 = new T.Texture({ width: 8, height: 8 });
  t12.needsUpdate = true;
  textures.setTexture2D(t12, 5);
  const t13 = new T.Texture({ width: 8, height: 8, complete: false });
  t13.needsUpdate = true;
  textures.setTexture2D(t13, 5);
  const t14 = new T.Texture();
  t14.needsUpdate = true;
  textures.setTexture2D(t14, 5);
  const t15 = new T.Texture({ width: 4, height: 2 });
  t15.mipmaps = [{ width: 4, height: 2 }, { width: 2, height: 1 }];
  t15.needsUpdate = true;
  textures.setTexture2D(t15, 5);
  gl.__note('generateMipmaps', t15.generateMipmaps);

  // data not ready, onUpdate
  const t16 = new T.DataTexture(new Uint8Array(4), 1, 1);
  t16.source.dataReady = false;
  let updates = 0;
  t16.onUpdate = () => { updates++; };
  t16.needsUpdate = true;
  textures.setTexture2D(t16, 6);
  gl.__note('onUpdate', updates);
  t16.source.dataReady = true;
  t16.needsUpdate = true;
  textures.setTexture2D(t16, 6);
  gl.__note('onUpdate', updates);

  // disposal: shared GL texture survives until the last user goes
  t1.dispose();
  mem('memory');
  t2.dispose();
  mem('memory');
  t1.dispose();
  t3.dispose();
  mem('memory');
  textures.setTexture2D(t2, 2);
  gl.__note('t2 after dispose', 'bound');
  t2.needsUpdate = true;
  textures.setTexture2D(t2, 2);
  mem('memory');
  return gl.__log;
}
