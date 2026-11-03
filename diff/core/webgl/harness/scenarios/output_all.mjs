// Group 3: WebGLOutput through a WebGLRenderer with a HalfFloat output buffer: tone
// mapping and color space defines, post-processing effects (disabled, no swap, depth
// texture, render pass), resizing, and rendering into a render target (no output pass).
import { createRequire } from 'node:module';
import { g3Options } from '../group3_util.mjs';
const { createMockCanvas, mockOptions } = createRequire(import.meta.url)('./renderer_common.cjs');

export async function run({ src, createMockGL }) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const { WebGLRenderTarget } = await import(src + '/renderers/WebGLRenderTarget.js');
  const gl = createMockGL(g3Options(mockOptions, {}, true));
  const canvas = createMockCanvas(gl, 64, 32);
  const renderer = new WebGLRenderer({ canvas, context: gl, outputBufferType: T.HalfFloatType });
  const scene = new T.Scene();
  const camera = new T.PerspectiveCamera(50, 2, 0.1, 100);
  camera.position.set(0, 0, 5);
  scene.add(new T.Mesh(new T.BoxGeometry(), new T.MeshBasicMaterial({ color: 0x408020 })));
  const frame = (label) => { gl.__log.push('## ' + label); renderer.render(scene, camera); };
  const ids = [];
  const tid = (t) => { if (t === null) return null; let i = ids.indexOf(t); if (i === -1) { ids.push(t); i = ids.length - 1; } return [i, t.width, t.height, t.texture.type, t.depthTexture !== null, t.samples]; };
  const effect = (name, props) => Object.assign({
    render(r, write, read, dt) { gl.__note(name + ' render', [tid(write), tid(read), dt === undefined ? 'undefined' : dt, r.toneMapping]); },
    setSize(w, h) { gl.__note(name + ' setSize', [w, h]); },
  }, props);

  renderer.toneMapping = T.ACESFilmicToneMapping;
  frame('aces');
  frame('aces again');
  renderer.toneMapping = T.NeutralToneMapping;
  frame('neutral');
  renderer.outputColorSpace = T.LinearSRGBColorSpace;
  frame('linear');
  renderer.outputColorSpace = T.SRGBColorSpace;
  const depthEffect = effect('depth', { needsDepthTexture: true, setDepthTexture(t) { gl.__note('depth setDepthTexture', [t.format, t.type, t.image.width, t.image.height]); } });
  const disabled = effect('disabled', { enabled: false });
  const noSwap = effect('noSwap', { needsSwap: false });
  const plain = effect('plain', {});
  gl.__log.push('## setEffects');
  renderer.setEffects([depthEffect, disabled, noSwap, plain, effect('last', {})]);
  frame('effects');
  gl.__log.push('## setSize');
  renderer.setSize(80, 40);
  frame('effects resized');
  const renderPass = { isRenderPass: true, render(r, write, read) { gl.__note('renderPass', [tid(write), tid(read)]); r.setRenderTarget(write); r.render(scene, camera); } };
  gl.__log.push('## render pass');
  renderer.setEffects([renderPass, plain]);
  frame('render pass');
  gl.__log.push('## no effects');
  renderer.setEffects(null);
  frame('no effects');
  renderer.toneMapping = T.NoToneMapping;
  frame('no tone mapping');
  renderer.toneMapping = T.ReinhardToneMapping;
  const rt = new WebGLRenderTarget(16, 8);
  renderer.setRenderTarget(rt);
  frame('render target');
  renderer.setRenderTarget(null);
  frame('back to canvas');
  gl.__log.push('## dispose');
  renderer.dispose();
  return gl.__log;
}
