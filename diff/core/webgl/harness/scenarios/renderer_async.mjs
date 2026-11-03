// Group 4: readRenderTargetPixelsAsync (resolve and reject paths) and compileAsync without
// KHR_parallel_shader_compile (the setTimeout path).
import { createRequire } from 'node:module';
const { createMockCanvas, mockOptions } = createRequire(import.meta.url)('./renderer_common.cjs');

export async function run({ src, createMockGL }) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const { WebGLRenderTarget } = await import(src + '/renderers/WebGLRenderTarget.js');
  const extensions = ['EXT_color_buffer_float', 'EXT_color_buffer_half_float', 'OES_texture_float_linear', 'WEBGL_multi_draw'];
  const gl = createMockGL(JSON.parse(mockOptions({ extensions })));
  const canvas = createMockCanvas(gl, 64, 32);
  const renderer = new WebGLRenderer({ canvas, context: gl });
  const target = new WebGLRenderTarget(8, 8);
  renderer.setRenderTarget(target);
  renderer.clear();
  renderer.setRenderTarget(null);
  const buffer = new Uint8Array(4 * 4 * 4);
  const result = await renderer.readRenderTargetPixelsAsync(target, 0, 0, 4, 4, buffer);
  gl.__note('resolved', result === buffer);
  try {
    await renderer.readRenderTargetPixelsAsync(target, 6, 6, 4, 4, buffer);
  } catch (e) {
    gl.__note('rejected', true);
  }
  const scene = new T.Scene();
  scene.add(new T.Mesh(new T.BoxGeometry(), new T.MeshBasicMaterial()));
  const camera = new T.PerspectiveCamera();
  const done = await renderer.compileAsync(scene, camera);
  gl.__note('compileAsync', done === scene);
  renderer.dispose();
  return gl.__log;
}
