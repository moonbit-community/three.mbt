// a6 (objects add-ons): Reflector on WebGLRenderer. Its onBeforeRender renders the scene
// from a mirrored camera into its render target: perspective and orthographic cameras,
// the cached reflection camera, facing away with and without forceUpdate, autoClear off.
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { createMockCanvas, mockOptions } = require('./renderer_common.cjs');
const { a6Register, A6_EXTRA_UNIFORMS, a6Options, A6_DROP } = require('./a6_common.cjs');

export async function run({ src, createMockGL }) {
  a6Register(src);
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const { Reflector } = await import('three/addons/objects/Reflector.js');
  const gl = createMockGL(JSON.parse(a6Options(mockOptions({}, A6_DROP), A6_EXTRA_UNIFORMS)));
  const canvas = createMockCanvas(gl, 64, 32);
  const renderer = new WebGLRenderer({ canvas, context: gl });
  const scene = new T.Scene();
  const camera = new T.PerspectiveCamera(50, 2, 0.1, 100);
  camera.position.set(0, 2, 5);
  camera.lookAt(0, 0, 0);
  scene.add(new T.DirectionalLight(0xffffff, 1));
  const box = new T.Mesh(new T.BoxGeometry(1, 1, 1), new T.MeshStandardMaterial({ color: 0x3366ff }));
  box.position.set(0, 1, 0);
  scene.add(box);
  const mirror = new Reflector(new T.PlaneGeometry(4, 4), { clipBias: 0.003, textureWidth: 32, textureHeight: 16, color: 0xc1cbcb });
  mirror.rotation.x = - Math.PI / 2;
  scene.add(mirror);
  const target = mirror.getRenderTarget();
  gl.__note('reflector', [mirror.type, mirror.isReflector === true, target.width, target.height, target.samples, target.texture.type, mirror.material.name, mirror.material.type]);
  renderer.render(scene, camera);
  const reflectionCamera = mirror.getReflectionCamera(camera);
  gl.__note('reflection camera', [reflectionCamera !== camera, reflectionCamera.position.toArray(), reflectionCamera.up.toArray(), reflectionCamera.far, Array.from(reflectionCamera.projectionMatrix.elements)]);
  gl.__note('texture matrix', Array.from(mirror.material.uniforms.textureMatrix.value.elements));
  renderer.render(scene, camera);
  gl.__note('same camera', mirror.getReflectionCamera(camera) === reflectionCamera);
  // from below: facing away, skipped unless forced
  camera.position.set(0, - 2, 5);
  camera.lookAt(0, 0, 0);
  renderer.render(scene, camera);
  mirror.forceUpdate = true;
  renderer.render(scene, camera);
  gl.__note('force update reset', mirror.forceUpdate);
  // orthographic camera
  const ortho = new T.OrthographicCamera(- 2, 2, 1, - 1, 0.1, 50);
  ortho.position.set(0, 3, 3);
  ortho.lookAt(0, 0, 0);
  renderer.render(scene, ortho);
  gl.__note('ortho reflection', Array.from(mirror.getReflectionCamera(ortho).projectionMatrix.elements));
  // autoClear off: the reflector clears its target itself
  renderer.autoClear = false;
  camera.position.set(1, 3, 4);
  camera.lookAt(0, 0, 0);
  renderer.render(scene, camera);
  // a view offset (mirrored into the reflection camera's projection)
  const offsetCamera = new T.PerspectiveCamera(50, 2, 0.1, 100);
  offsetCamera.position.set(0.5, 2.5, 4);
  offsetCamera.lookAt(0, 0, 0);
  offsetCamera.setViewOffset(128, 64, 20, 10, 64, 32);
  renderer.render(scene, offsetCamera);
  gl.__note('offset reflection', Array.from(mirror.getReflectionCamera(offsetCamera).projectionMatrix.elements));
  mirror.dispose();
  return gl.__log;
}
