// Group 3: WebGLBackground through WebGLRenderer: clear color, color, 2D texture, cube
// texture and equirectangular backgrounds, tone mapping changes, dispose.
import { createRequire } from 'node:module';
import { g3Options } from '../group3_util.mjs';
const { createMockCanvas, mockOptions } = createRequire(import.meta.url)('./renderer_common.cjs');

export async function run({ src, createMockGL }) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const gl = createMockGL(g3Options(mockOptions));
  const canvas = createMockCanvas(gl, 64, 32);
  const renderer = new WebGLRenderer({ canvas, context: gl });
  const scene = new T.Scene();
  const camera = new T.PerspectiveCamera(50, 2, 0.1, 100);
  camera.position.set(0, 0, 5);
  scene.add(new T.Mesh(new T.BoxGeometry(), new T.MeshBasicMaterial({ color: 0x00ff00 })));
  const frame = (label) => { gl.__log.push('## ' + label); renderer.render(scene, camera); };

  renderer.setClearColor(0x336699, 0.5);
  frame('clear color');
  renderer.setClearAlpha(0.25);
  frame('clear alpha');
  scene.background = new T.Color(0.2, 0.4, 0.8);
  frame('color');
  renderer.autoClear = false;
  frame('color without autoClear');
  scene.background = null;
  frame('no background without autoClear');
  renderer.autoClear = true;

  const tex = new T.DataTexture(new Uint8Array(16), 2, 2);
  tex.needsUpdate = true;
  tex.colorSpace = T.SRGBColorSpace;
  tex.offset.set(0.1, 0.2);
  tex.name = 'bg2d';
  scene.background = tex;
  scene.backgroundIntensity = 0.7;
  frame('texture');
  frame('texture again');
  renderer.toneMapping = T.ACESFilmicToneMapping;
  frame('texture tone mapped');
  tex.colorSpace = T.LinearSRGBColorSpace;
  tex.needsUpdate = true;
  frame('texture version');

  const faces = [0, 1, 2, 3, 4, 5].map(() => ({ width: 4, height: 4 }));
  const cube = new T.CubeTexture(faces);
  cube.needsUpdate = true;
  scene.background = cube;
  scene.backgroundRotation.set(0.1, 0.2, 0.3);
  scene.backgroundIntensity = 1.5;
  frame('cube');
  frame('cube again');

  const equirect = new T.Texture({ width: 8, height: 4 });
  equirect.mapping = T.EquirectangularReflectionMapping;
  equirect.needsUpdate = true;
  scene.background = equirect;
  frame('equirect');
  frame('equirect again');
  gl.__note('equirect mapping', equirect.mapping);

  const pending = new T.Texture();
  pending.mapping = T.EquirectangularReflectionMapping;
  scene.background = pending;
  frame('equirect pending');

  equirect.dispose();
  gl.__log.push('## dispose');
  renderer.dispose();
  return gl.__log;
}
