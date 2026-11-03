// Group 4: render-to-texture, multisampled targets, pixel reads, framebuffer and texture
// copies, initTexture, the transmission pass, cube targets from an equirectangular
// texture, compileAsync and the animation loop.
import { createRequire } from 'node:module';
const { createMockCanvas, mockOptions } = createRequire(import.meta.url)('./renderer_common.cjs');

// light structs this scene does not have
const RTT_DROP = ['pointLights', 'spotLights', 'hemisphereLights', 'directionalShadowMap', 'directionalShadowMatrix', 'directionalLightShadows'];

// a real context answers the UNPACK_* queries copyTextureToTexture saves and restores
const RTT_PARAMETERS = { parameters: { UNPACK_ROW_LENGTH: 0, UNPACK_IMAGE_HEIGHT: 0, UNPACK_SKIP_PIXELS: 0, UNPACK_SKIP_ROWS: 0, UNPACK_SKIP_IMAGES: 0 } };

export async function run({ src, createMockGL, createMockAnimationContext }) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const { WebGLRenderTarget } = await import(src + '/renderers/WebGLRenderTarget.js');
  const { WebGLCubeRenderTarget } = await import(src + '/renderers/WebGLCubeRenderTarget.js');
  const gl = createMockGL(JSON.parse(mockOptions(RTT_PARAMETERS, RTT_DROP)));
  const canvas = createMockCanvas(gl, 64, 32);
  const frames = createMockAnimationContext(gl);
  globalThis.self = frames;
  const renderer = new WebGLRenderer({ canvas, context: gl });
  delete globalThis.self;
  const scene = new T.Scene();
  const camera = new T.PerspectiveCamera(60, 2, 0.1, 20);
  camera.position.set(0, 0, 4);
  scene.add(new T.DirectionalLight(0xffffff, 1));
  const box = new T.Mesh(new T.BoxGeometry(1, 1, 1), new T.MeshStandardMaterial({ color: 0x3366ff }));
  box.rotation.set(0.5, 0.5, 0);
  scene.add(box);
  // render to a texture, then show it on a plane
  const target = new WebGLRenderTarget(32, 16, { depthBuffer: true });
  renderer.setRenderTarget(target);
  renderer.render(scene, camera);
  renderer.setRenderTarget(null);
  const pixels = new Uint8Array(4 * 4 * 4);
  renderer.readRenderTargetPixels(target, 2, 2, 4, 4, pixels);
  const screen = new T.Scene();
  screen.add(new T.Mesh(new T.PlaneGeometry(2, 1), new T.MeshBasicMaterial({ map: target.texture })));
  renderer.render(screen, camera);
  // multisampled target with mipmaps
  const msaa = new WebGLRenderTarget(16, 16, { samples: 4, generateMipmaps: true, minFilter: T.LinearMipmapLinearFilter });
  renderer.setRenderTarget(msaa);
  renderer.render(scene, camera);
  renderer.setRenderTarget(null);
  // copies
  const fbTexture = new T.FramebufferTexture(16, 16);
  renderer.copyFramebufferToTexture(fbTexture, new T.Vector2(2, 3));
  renderer.copyFramebufferToTexture(fbTexture, null, 1);
  const srcData = new T.DataTexture(new Uint8Array(4 * 4 * 4).fill(7), 4, 4);
  srcData.needsUpdate = true;
  const dstData = new T.DataTexture(new Uint8Array(8 * 8 * 4), 8, 8);
  dstData.needsUpdate = true;
  renderer.initTexture(dstData);
  renderer.copyTextureToTexture(srcData, dstData, new T.Box2(new T.Vector2(0, 0), new T.Vector2(2, 2)), new T.Vector2(1, 1));
  renderer.initTexture(srcData);
  renderer.copyTextureToTexture(srcData, dstData);
  // transmission
  const glass = new T.Mesh(new T.SphereGeometry(0.4, 6, 4), new T.MeshPhysicalMaterial({ transmission: 0.8, thickness: 0.2, side: T.DoubleSide }));
  glass.position.set(0, 0, 1);
  scene.add(glass);
  renderer.render(scene, camera);
  renderer.transmissionResolutionScale = 0.5;
  renderer.setClearAlpha(0.5);
  renderer.render(scene, camera);
  // cube target from an equirectangular texture
  const equirect = new T.DataTexture(new Uint8Array(8 * 4 * 4).fill(128), 8, 4);
  equirect.mapping = T.EquirectangularReflectionMapping;
  equirect.needsUpdate = true;
  const cube = new WebGLCubeRenderTarget(8);
  cube.fromEquirectangularTexture(renderer, equirect);
  gl.__note('cube texture', [cube.texture.type, cube.texture.colorSpace, cube.texture.minFilter, equirect.minFilter]);
  // compileAsync
  const extra = new T.Mesh(new T.BoxGeometry(), new T.MeshPhongMaterial());
  const done = await renderer.compileAsync(extra, camera, scene);
  gl.__note('compileAsync', done === extra);
  // animation loop
  renderer.setAnimationLoop((time) => { gl.__note('frame', time); renderer.render(scene, camera); });
  frames.__tick(16);
  frames.__tick(32);
  renderer.setAnimationLoop(null);
  frames.__tick(48);
  renderer.dispose();
  return gl.__log;
}
