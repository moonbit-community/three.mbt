// Group 4: scene environment (PMREM) and background, an ArrayCamera with sub-viewports, a
// render nested in another, 3D and array targets, externally managed target textures and
// framebuffers, a BatchedMesh, and a HalfFloat output buffer with tone mapping.
import { createRequire } from 'node:module';
const { createMockCanvas, mockOptions } = createRequire(import.meta.url)('./renderer_common.cjs');

// light structs this scene does not have
const EXTRA_DROP = ['pointLights', 'spotLights', 'hemisphereLights', 'directionalShadowMap', 'directionalShadowMatrix', 'directionalLightShadows'];

export async function run({ src, createMockGL }) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const { WebGLRenderTarget } = await import(src + '/renderers/WebGLRenderTarget.js');
  const { WebGL3DRenderTarget } = await import(src + '/renderers/WebGL3DRenderTarget.js');
  const { WebGLArrayRenderTarget } = await import(src + '/renderers/WebGLArrayRenderTarget.js');
  const gl = createMockGL(JSON.parse(mockOptions({}, EXTRA_DROP)));
  const canvas = createMockCanvas(gl, 64, 32);
  const renderer = new WebGLRenderer({ canvas, context: gl });
  const scene = new T.Scene();
  scene.background = new T.Color(0x112233);
  scene.add(new T.DirectionalLight(0xffffff, 1));
  const equirect = new T.DataTexture(new Uint8Array(8 * 4 * 4).fill(200), 8, 4);
  equirect.mapping = T.EquirectangularReflectionMapping;
  equirect.needsUpdate = true;
  scene.environment = equirect;
  scene.environmentIntensity = 0.5;
  const sphere = new T.Mesh(new T.SphereGeometry(0.5, 6, 4), new T.MeshStandardMaterial({ roughness: 0.4 }));
  scene.add(sphere);
  const lambert = new T.Mesh(new T.SphereGeometry(0.3, 6, 4), new T.MeshLambertMaterial({ color: 0x00ff00 }));
  lambert.position.set(1, 0, 0);
  scene.add(lambert);
  const camera = new T.PerspectiveCamera(50, 2, 0.1, 10);
  camera.position.set(0, 0, 3);
  renderer.render(scene, camera);
  // array camera with two viewports
  const left = new T.PerspectiveCamera(50, 1, 0.1, 10);
  left.position.set(-0.5, 0, 3);
  left.viewport = new T.Vector4(0, 0, 32, 32);
  left.updateMatrixWorld();
  const right = new T.PerspectiveCamera(50, 1, 0.1, 10);
  right.position.set(0.5, 0, 3);
  right.viewport = new T.Vector4(32, 0, 32, 32);
  right.updateMatrixWorld();
  const array = new T.ArrayCamera([left, right]);
  array.position.set(0, 0, 3);
  renderer.render(scene, array);
  // a render nested in another frame
  const inner = new T.Scene();
  inner.add(new T.Mesh(new T.BoxGeometry(0.2, 0.2, 0.2), new T.MeshBasicMaterial({ color: 0xff0000 })));
  const innerTarget = new WebGLRenderTarget(8, 8);
  lambert.onAfterRender = (r) => {
    lambert.onAfterRender = () => {};
    const previous = r.getRenderTarget();
    r.setRenderTarget(innerTarget);
    r.render(inner, camera);
    r.setRenderTarget(previous);
  };
  renderer.render(scene, camera);
  // 3D and array targets
  const target3d = new WebGL3DRenderTarget(4, 4, 3);
  renderer.setRenderTarget(target3d, 2);
  renderer.clear();
  const targetArray = new WebGLArrayRenderTarget(4, 4, 2);
  renderer.setRenderTarget(targetArray, 1);
  renderer.render(inner, camera);
  renderer.setRenderTarget(null);
  // externally managed textures and framebuffers
  const external = new WebGLRenderTarget(8, 8, { depthTexture: new T.DepthTexture(8, 8) });
  renderer.setRenderTargetTextures(external, gl.createTexture(), gl.createTexture());
  renderer.setRenderTarget(external);
  renderer.setRenderTarget(external);
  renderer.setRenderTarget(null);
  const framebuffer = new WebGLRenderTarget(8, 8);
  renderer.setRenderTargetFramebuffer(framebuffer, gl.createFramebuffer());
  renderer.setRenderTarget(framebuffer);
  renderer.clear();
  renderer.setRenderTarget(null);
  // batched mesh
  const batched = new T.BatchedMesh(3, 100, 300, new T.MeshBasicMaterial());
  const id = batched.addGeometry(new T.BoxGeometry(0.3, 0.3, 0.3));
  const i0 = batched.addInstance(id);
  batched.setMatrixAt(i0, new T.Matrix4().makeTranslation(-1, 1, 0));
  batched.addInstance(id);
  const batchedScene = new T.Scene();
  batchedScene.add(batched);
  renderer.render(batchedScene, camera);
  renderer.dispose();
  // half float output with tone mapping
  const hdr = new WebGLRenderer({ canvas, context: gl, outputBufferType: T.HalfFloatType });
  hdr.toneMapping = T.ACESFilmicToneMapping;
  hdr.setSize(32, 16);
  hdr.render(inner, camera);
  hdr.setEffects(null);
  hdr.render(inner, camera);
  hdr.dispose();
  return gl.__log;
}
