// WebGLTextures: cube textures from images, data textures, compressed faces and depth,
// with mipmaps (group 1).
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
  const seq = (n) => { const a = new Uint8Array(n); for (let i = 0; i < n; i++) a[i] = i; return a; };
  const faces = (f) => [0, 1, 2, 3, 4, 5].map(f);

  // images, generated mipmaps
  const k1 = new T.CubeTexture(faces(() => ({ width: 4, height: 4 })));
  k1.needsUpdate = true;
  textures.setTextureCube(k1, 0);
  textures.setTextureCube(k1, 0);
  // fewer than six images: nothing happens
  const k2 = new T.CubeTexture([{ width: 4, height: 4 }]);
  k2.needsUpdate = true;
  textures.setTextureCube(k2, 1);
  gl.__note('k2', 'skipped');

  // images with user mipmaps (cube textures as mip levels)
  const k3 = new T.CubeTexture(faces(() => ({ width: 4, height: 4 })));
  k3.mipmaps = [new T.CubeTexture(faces(() => ({ width: 2, height: 2 }))), new T.CubeTexture(faces(() => ({ width: 1, height: 1 })))];
  k3.generateMipmaps = false;
  k3.minFilter = T.LinearMipmapLinearFilter;
  k3.colorSpace = T.SRGBColorSpace;
  k3.needsUpdate = true;
  textures.setTextureCube(k3, 2);

  // data texture faces with mipmaps
  const k4 = new T.CubeTexture(faces((i) => new T.DataTexture(seq(16), 2, 2)));
  k4.mipmaps = [new T.CubeTexture(faces((i) => new T.DataTexture(seq(4), 1, 1)))];
  k4.generateMipmaps = false;
  k4.minFilter = T.LinearFilter;
  k4.needsUpdate = true;
  textures.setTextureCube(k4, 3);
  k4.needsUpdate = true;
  textures.setTextureCube(k4, 3);

  // compressed cube
  const k5 = new T.CompressedCubeTexture(faces(() => ({ width: 4, height: 4, mipmaps: [{ data: seq(8), width: 4, height: 4 }, { data: seq(8), width: 2, height: 2 }] })), T.RGBA_S3TC_DXT1_Format);
  k5.mipmaps = [];
  k5.needsUpdate = true;
  textures.setTextureCube(k5, 4);
  const k6 = new T.CompressedCubeTexture(faces(() => ({ width: 2, height: 2, mipmaps: [{ data: seq(16), width: 2, height: 2 }] })), T.RGBAFormat);
  k6.mipmaps = [];
  k6.needsUpdate = true;
  textures.setTextureCube(k6, 4);

  // cube depth texture
  const k7 = new T.CubeDepthTexture(8);
  k7.needsUpdate = true;
  textures.setTextureCube(k7, 5);
  const k8 = new T.CubeDepthTexture(8, T.FloatType);
  k8.format = T.DepthStencilFormat;
  k8.needsUpdate = true;
  textures.setTextureCube(k8, 5);

  gl.__note('memory', info.memory.textures);
  k1.dispose();
  k4.dispose();
  gl.__note('memory', info.memory.textures);
  return gl.__log;
}
