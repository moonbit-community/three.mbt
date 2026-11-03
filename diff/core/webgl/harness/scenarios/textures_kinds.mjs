// WebGLTextures: array, 3D, compressed, compressed array, depth, framebuffer, external
// and video textures, including layer updates (group 1).
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

  // DataArrayTexture, whole and per layer
  const a1 = new T.DataArrayTexture(seq(32), 2, 2, 2);
  a1.needsUpdate = true;
  textures.setTexture2DArray(a1, 0);
  a1.addLayerUpdate(1);
  a1.needsUpdate = true;
  textures.setTexture2DArray(a1, 0);
  gl.__note('layerUpdates', a1.layerUpdates.size);
  textures.setTexture2DArray(a1, 1);

  // Data3DTexture
  const d1 = new T.Data3DTexture(seq(32), 2, 2, 2);
  d1.wrapR = T.RepeatWrapping;
  d1.needsUpdate = true;
  textures.setTexture3D(d1, 2);
  textures.setTexture3D(d1, 2);

  // CompressedTexture: supported, RGBA and unsupported formats
  const c1 = new T.CompressedTexture([{ data: seq(8), width: 4, height: 4 }, { data: seq(8), width: 2, height: 2 }], 4, 4, T.RGBA_S3TC_DXT1_Format);
  c1.needsUpdate = true;
  textures.setTexture2D(c1, 3);
  const c2 = new T.CompressedTexture([{ data: seq(16), width: 2, height: 2 }], 2, 2, T.RGBAFormat);
  c2.needsUpdate = true;
  textures.setTexture2D(c2, 3);
  const c3 = new T.CompressedTexture([{ data: seq(8), width: 4, height: 4 }], 4, 4, T.RGB_PVRTC_4BPPV1_Format);
  c3.needsUpdate = true;
  textures.setTexture2D(c3, 3);
  const c4 = new T.CompressedTexture([{ data: seq(16), width: 4, height: 4 }], 4, 4, T.RGBA_ASTC_4x4_Format);
  c4.colorSpace = T.SRGBColorSpace;
  c4.needsUpdate = true;
  textures.setTexture2D(c4, 3);

  // CompressedArrayTexture, whole and per layer
  const ca = new T.CompressedArrayTexture([{ data: seq(24), width: 4, height: 4 }], 4, 4, 3, T.RGBA_S3TC_DXT1_Format);
  ca.needsUpdate = true;
  textures.setTexture2DArray(ca, 4);
  ca.addLayerUpdate(2);
  ca.addLayerUpdate(0);
  ca.needsUpdate = true;
  textures.setTexture2DArray(ca, 4);
  gl.__note('layerUpdates', ca.layerUpdates.size);
  const cb = new T.CompressedArrayTexture([{ data: seq(32), width: 2, height: 2 }], 2, 2, 2, T.RGBAFormat);
  cb.needsUpdate = true;
  textures.setTexture2DArray(cb, 4);

  // DepthTexture formats and compare functions
  const z1 = new T.DepthTexture(4, 4);
  z1.needsUpdate = true;
  textures.setTexture2D(z1, 5);
  const z2 = new T.DepthTexture(4, 4, T.UnsignedInt248Type);
  z2.format = T.DepthStencilFormat;
  z2.compareFunction = T.LessCompare;
  z2.needsUpdate = true;
  textures.setTexture2D(z2, 5);
  const z3 = new T.DepthTexture(4, 4, T.FloatType);
  z3.needsUpdate = true;
  textures.setTexture2D(z3, 5);
  const z4 = new T.DepthTexture(4, 4, T.UnsignedShortType);
  z4.format = T.DepthStencilFormat;
  z4.needsUpdate = true;
  textures.setTexture2D(z4, 5);
  const z5 = new T.DepthTexture(4, 4, T.UnsignedShortType);
  z5.needsUpdate = true;
  textures.setTexture2D(z5, 5);

  // FramebufferTexture: base level, then a mip chain from minFilter
  const f1 = new T.FramebufferTexture(8, 8);
  textures.setTexture2D(f1, 6);
  const f2 = new T.FramebufferTexture(8, 8);
  f2.minFilter = T.LinearMipmapLinearFilter;
  textures.setTexture2D(f2, 6);

  // ExternalTexture
  const handle = gl.createTexture();
  const e1 = new T.ExternalTexture(handle);
  textures.setTexture2D(e1, 7);
  textures.setTexture2DArray(e1, 8);
  const e2 = new T.ExternalTexture();
  textures.setTexture2D(e2, 9);

  // VideoTexture: no texStorage, linear transfer, once per frame
  const video = { width: 4, height: 4, readyState: 4, HAVE_CURRENT_DATA: 2 };
  const v1 = new T.VideoTexture(video);
  v1.colorSpace = T.SRGBColorSpace;
  textures.setTexture2D(v1, 10);
  gl.__note('video version', v1.version);
  textures.setTexture2D(v1, 10);
  gl.__note('video version', v1.version);
  info.render.frame = 1;
  textures.setTexture2D(v1, 10);
  gl.__note('video version', v1.version);
  v1.dispose();
  gl.__note('memory', info.memory.textures);
  return gl.__log;
}
