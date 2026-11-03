// WebGLTextures: render target setup (2D, mip levels, depth/stencil renderbuffers, depth
// textures, cube, 3D, array, MRT, multisample), mipmap and multisample updates,
// rebinding and disposal (group 1).
export async function run({ src, createMockGL }) {
  const { WebGLExtensions } = await import(src + '/renderers/webgl/WebGLExtensions.js');
  const { WebGLUtils } = await import(src + '/renderers/webgl/WebGLUtils.js');
  const { WebGLCapabilities } = await import(src + '/renderers/webgl/WebGLCapabilities.js');
  const { WebGLState } = await import(src + '/renderers/webgl/WebGLState.js');
  const { WebGLProperties } = await import(src + '/renderers/webgl/WebGLProperties.js');
  const { WebGLInfo } = await import(src + '/renderers/webgl/WebGLInfo.js');
  const { WebGLTextures } = await import(src + '/renderers/webgl/WebGLTextures.js');
  const { WebGLCubeRenderTarget } = await import(src + '/renderers/WebGLCubeRenderTarget.js');
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
  const step = (label) => gl.__note('step', label);

  step('plain');
  const r1 = new T.WebGLRenderTarget(4, 4);
  textures.setupRenderTarget(r1);
  gl.__note('useMultisampledRTT', textures.useMultisampledRTT(r1));
  textures.setupDepthRenderbuffer(r1);
  textures.rebindTextures(r1, properties.get(r1.texture).__webglTexture, undefined);
  mem('memory');

  step('stencil + depth texture');
  const r2 = new T.WebGLRenderTarget(4, 4, { stencilBuffer: true, depthTexture: new T.DepthTexture(4, 4) });
  textures.setupRenderTarget(r2);
  textures.rebindTextures(r2, undefined, properties.get(r2.depthTexture).__webglTexture);
  step('swap depth texture');
  const z2 = new T.DepthTexture(4, 4, T.UnsignedInt248Type);
  z2.format = T.DepthStencilFormat;
  r2.depthTexture = z2;
  textures.setupDepthRenderbuffer(r2);
  step('resize depth texture');
  r2.width = 8; r2.height = 8;
  textures.setupDepthRenderbuffer(r2);
  gl.__note('depth size', [z2.image.width, z2.image.height]);
  step('dispose bound depth texture');
  z2.dispose();
  textures.setupDepthRenderbuffer(r2);

  step('auto allocated depth buffer');
  const r2b = new T.WebGLRenderTarget(4, 4, { depthTexture: new T.DepthTexture(4, 4) });
  properties.get(r2b).__autoAllocateDepthBuffer = true;
  textures.setupRenderTarget(r2b);

  step('generated mipmaps');
  const r3 = new T.WebGLRenderTarget(8, 8, { generateMipmaps: true, minFilter: T.LinearMipmapLinearFilter, depthBuffer: false, type: T.HalfFloatType });
  textures.setupRenderTarget(r3);
  textures.updateRenderTargetMipmap(r3);
  r3.texture.mipmapsAutoUpdate = false;
  textures.updateRenderTargetMipmap(r3);

  step('mip level framebuffers');
  const r4 = new T.WebGLRenderTarget(8, 8, { stencilBuffer: true });
  r4.texture.mipmaps = [{}, {}, {}];
  textures.setupRenderTarget(r4);

  step('cube');
  const r5 = new WebGLCubeRenderTarget(4);
  textures.setupRenderTarget(r5);
  textures.updateRenderTargetMipmap(r5);
  step('cube with mip levels');
  const r5b = new WebGLCubeRenderTarget(4, { depthBuffer: false });
  r5b.texture.mipmaps = [{}, {}];
  textures.setupRenderTarget(r5b);
  step('cube with generated mipmaps');
  const r5c = new WebGLCubeRenderTarget(4, { depthBuffer: false, generateMipmaps: true, minFilter: T.LinearMipmapLinearFilter });
  textures.setupRenderTarget(r5c);
  textures.updateRenderTargetMipmap(r5c);

  step('cube with depth texture');
  const r6 = new WebGLCubeRenderTarget(4, { depthTexture: new T.CubeDepthTexture(4) });
  textures.setupRenderTarget(r6);

  step('3D');
  const r7 = new T.WebGL3DRenderTarget(2, 2, 3);
  textures.setupRenderTarget(r7);
  step('array');
  const r8 = new T.WebGLArrayRenderTarget(2, 2, 3, { depthBuffer: false, generateMipmaps: true });
  textures.setupRenderTarget(r8);
  textures.updateRenderTargetMipmap(r8);

  step('MRT');
  const r9 = new T.WebGLRenderTarget(4, 4, { count: 2, depthBuffer: false });
  r9.textures[1].type = T.FloatType;
  r9.textures[1].format = T.RedFormat;
  textures.setupRenderTarget(r9);
  mem('memory');
  step('MRT array');
  const r9b = new T.WebGLArrayRenderTarget(2, 2, 2, { count: 2, depthBuffer: false });
  r9b.textures[1].generateMipmaps = true;
  textures.setupRenderTarget(r9b);

  step('multisample');
  const r10 = new T.WebGLRenderTarget(4, 4, { samples: 4 });
  textures.setupRenderTarget(r10);
  textures.updateMultisampleRenderTarget(r10);
  r10.resolveDepthBuffer = false;
  textures.updateMultisampleRenderTarget(r10);
  step('multisample MRT with stencil');
  const r11 = new T.WebGLRenderTarget(4, 4, { samples: 8, count: 2, stencilBuffer: true });
  textures.setupRenderTarget(r11);
  textures.updateMultisampleRenderTarget(r11);
  r11.resolveStencilBuffer = false;
  textures.updateMultisampleRenderTarget(r11);
  step('multisample mip levels');
  const r12 = new T.WebGLRenderTarget(4, 4, { samples: 2, depthBuffer: false });
  r12.texture.mipmaps = [{}, {}];
  textures.setupRenderTarget(r12);
  textures.updateMultisampleRenderTarget(r12);
  textures.updateMultisampleRenderTarget(r1);

  step('external textures');
  const r13 = new T.WebGLRenderTarget(4, 4, { depthBuffer: false });
  properties.get(r13).__hasExternalTextures = true;
  textures.setupRenderTarget(r13);

  step('dispose');
  mem('memory');
  r1.dispose();
  r2.dispose();
  r5.dispose();
  r5b.dispose();
  r6.dispose();
  r9.dispose();
  r10.dispose();
  r11.dispose();
  r12.dispose();
  mem('memory');
  r1.dispose();
  step('reuse after dispose');
  textures.setupRenderTarget(r1);
  mem('memory');
  return gl.__log;
}
