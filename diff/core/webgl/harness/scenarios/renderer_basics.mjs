// Group 4: WebGLRenderer construction, sizing, viewport/scissor, clearing, render targets
// without drawing, context loss and restore, dispose.
import { createRequire } from 'node:module';
const { createMockCanvas, mockOptions } = createRequire(import.meta.url)('./renderer_common.cjs');

export async function run({ src, createMockGL }) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const gl = createMockGL(JSON.parse(mockOptions({})));
  const canvas = createMockCanvas(gl, 64, 32);
  const renderer = new WebGLRenderer({ canvas, context: gl, stencil: true });
  const v2 = new T.Vector2();
  const v4 = new T.Vector4();
  const c = new T.Color();
  gl.__note('size', renderer.getSize(v2).toArray());
  gl.__note('pixelRatio', renderer.getPixelRatio());
  renderer.setPixelRatio(2);
  renderer.setSize(40, 20.5);
  gl.__note('size', renderer.getSize(v2).toArray());
  gl.__note('drawingBufferSize', renderer.getDrawingBufferSize(v2).toArray());
  gl.__note('viewport', renderer.getViewport(v4).toArray());
  gl.__note('currentViewport', renderer.getCurrentViewport(v4).toArray());
  renderer.setViewport(1, 2, 30.3, 10);
  renderer.setViewport(new T.Vector4(0, 0, 40, 20));
  renderer.setScissor(2, 3, 4, 5);
  renderer.setScissor(new T.Vector4(1, 1, 7, 9));
  gl.__note('scissor', renderer.getScissor(v4).toArray());
  renderer.setScissorTest(true);
  gl.__note('scissorTest', renderer.getScissorTest());
  renderer.setScissorTest(false);
  renderer.setDrawingBufferSize(30, 10, 1.5);
  gl.__note('pixelRatio', renderer.getPixelRatio());
  renderer.setSize(64, 32, false);
  renderer.setPixelRatio(1);
  renderer.setSize(64, 32);
  // clearing
  gl.__note('clearColor', renderer.getClearColor(c).toArray());
  gl.__note('clearAlpha', renderer.getClearAlpha());
  renderer.setClearColor(0x336699, 0.5);
  gl.__note('clearColor', renderer.getClearColor(c).getHex());
  renderer.setClearColor(new T.Color(1, 0, 0));
  renderer.setClearAlpha(0.25);
  gl.__note('clearAlpha', renderer.getClearAlpha());
  renderer.clear();
  renderer.clearColor();
  renderer.clearDepth();
  renderer.clearStencil();
  renderer.clear(false, false, false);
  renderer.autoClear = false;
  // render targets
  const rt = new T.RenderTarget(16, 8);
  const { WebGLRenderTarget } = await import(src + '/renderers/WebGLRenderTarget.js');
  const target = new WebGLRenderTarget(16, 8, { depthBuffer: true });
  renderer.setRenderTarget(target);
  gl.__note('renderTarget is target', renderer.getRenderTarget() === target);
  gl.__note('currentViewport', renderer.getCurrentViewport(v4).toArray());
  renderer.clear();
  renderer.setRenderTarget(target, 0, 1);
  gl.__note('mip', [renderer.getActiveCubeFace(), renderer.getActiveMipmapLevel()]);
  renderer.setRenderTarget(null);
  renderer.initRenderTarget(target);
  const integer = new WebGLRenderTarget(4, 4, { format: T.RGBAIntegerFormat, type: T.UnsignedIntType });
  renderer.setRenderTarget(integer);
  renderer.setClearColor(new T.Color(1, 0.5, 0.25), 1);
  renderer.clear();
  const signed = new WebGLRenderTarget(4, 4, { format: T.RGIntegerFormat, type: T.IntType });
  renderer.setRenderTarget(signed);
  renderer.clear(true, false, false);
  renderer.setRenderTarget(null);
  gl.__note('isWebGLRenderTarget plain', rt.isWebGLRenderTarget === true);
  renderer.readRenderTargetPixels(rt, 0, 0, 1, 1, new Uint8Array(4));
  const pixels = new Uint8Array(16 * 4);
  renderer.readRenderTargetPixels(target, 0, 0, 4, 4, pixels);
  renderer.readRenderTargetPixels(target, 14, 0, 4, 4, pixels);
  renderer.setRenderTarget(target);
  renderer.readRenderTargetPixels(target, 1, 1, 2, 2, pixels);
  renderer.setRenderTarget(null);
  // cube render target
  const { WebGLCubeRenderTarget } = await import(src + '/renderers/WebGLCubeRenderTarget.js');
  const cube = new WebGLCubeRenderTarget(8);
  cube.clear(renderer, true, true, false);
  renderer.setRenderTarget(cube, 3);
  renderer.setRenderTarget(null);
  // read with the canvas current: with a cube target current, upstream's restore passes the
  // per-face array to gl.bindFramebuffer, which WebGL rejects (the port aborts there)
  renderer.readRenderTargetPixels(cube, 0, 0, 2, 2, pixels, 2);
  // state reset, colour space, context
  renderer.resetState();
  gl.__note('renderTarget after reset', renderer.getRenderTarget());
  gl.__note('coordinateSystem', renderer.coordinateSystem);
  gl.__note('outputColorSpace', renderer.outputColorSpace);
  renderer.outputColorSpace = T.LinearSRGBColorSpace;
  gl.__note('drawingBufferColorSpace', gl.drawingBufferColorSpace);
  gl.__note('unpackColorSpace', gl.unpackColorSpace);
  gl.__note('contextAttributes.alpha', renderer.getContextAttributes().alpha);
  gl.__note('getContext', renderer.getContext() === gl);
  // context loss and restore
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = T.VSMShadowMap;
  renderer.info.autoReset = false;
  renderer.forceContextLoss();
  canvas.__dispatch('webglcontextlost');
  const scene = new T.Scene();
  const camera = new T.PerspectiveCamera();
  renderer.render(scene, camera);
  renderer.forceContextRestore();
  canvas.__dispatch('webglcontextrestored');
  gl.__note('after restore', [renderer.shadowMap.enabled, renderer.shadowMap.type, renderer.info.autoReset]);
  canvas.__dispatch('webglcontextcreationerror');
  renderer.render(scene, new T.Object3D());
  renderer.dispose();
  gl.__note('listeners', [canvas.__listenerCount('webglcontextlost'), canvas.__listenerCount('webglcontextrestored')]);
  return gl.__log;
}
