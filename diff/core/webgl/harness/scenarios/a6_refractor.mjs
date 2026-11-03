// a6 (objects add-ons): Refractor on WebGLRenderer. Its onBeforeRender renders what is
// behind it through an oblique-frustum virtual camera; skipped from behind and for its own
// virtual camera (userData.refractor).
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { createMockCanvas, mockOptions } = require('./renderer_common.cjs');
const { a6Register, A6_EXTRA_UNIFORMS, a6Options, A6_DROP } = require('./a6_common.cjs');

export async function run({ src, createMockGL }) {
  a6Register(src);
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const { Refractor } = await import('three/addons/objects/Refractor.js');
  const gl = createMockGL(JSON.parse(a6Options(mockOptions({}, A6_DROP), A6_EXTRA_UNIFORMS)));
  const canvas = createMockCanvas(gl, 64, 32);
  const renderer = new WebGLRenderer({ canvas, context: gl });
  const scene = new T.Scene();
  const camera = new T.PerspectiveCamera(50, 2, 0.1, 100);
  camera.position.set(0.5, 0.5, 4);
  camera.lookAt(0, 0, 0);
  scene.add(new T.DirectionalLight(0xffffff, 1));
  const box = new T.Mesh(new T.BoxGeometry(1, 1, 1), new T.MeshStandardMaterial({ color: 0xff8800 }));
  box.position.set(0, 0, - 2);
  scene.add(box);
  const glass = new Refractor(new T.PlaneGeometry(3, 2), { color: 0x999999, textureWidth: 16, textureHeight: 16, clipBias: 0.01, multisample: 0 });
  glass.position.set(0, 0, 0.5);
  glass.rotation.y = 0.2;
  scene.add(glass);
  gl.__note('refractor', [glass.type, glass.isRefractor === true, glass.camera.userData.refractor, glass.camera.matrixAutoUpdate, glass.getRenderTarget().samples, glass.material.transparent]);
  renderer.render(scene, camera);
  gl.__note('virtual camera', [Array.from(glass.camera.matrixWorld.elements), Array.from(glass.camera.projectionMatrix.elements), glass.camera.far]);
  gl.__note('texture matrix', Array.from(glass.material.uniforms.textureMatrix.value.elements));
  renderer.render(scene, camera);
  // from behind: skipped
  camera.position.set(0, 0, - 5);
  camera.lookAt(0, 0, 0);
  renderer.render(scene, camera);
  // its own virtual camera: skipped
  renderer.render(scene, glass.camera);
  glass.dispose();
  return gl.__log;
}
