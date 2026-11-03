// a6 (objects add-ons): Lensflare on WebGLRenderer: framebuffer copies around the light,
// the occlusion quad, the restore quad and additive elements (renderBufferDirect), to the
// canvas and to a half-float render target (the maps' type follows the target).
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { createMockCanvas, mockOptions } = require('./renderer_common.cjs');
const { a6Register, A6_EXTRA_UNIFORMS, a6Options, A6_DROP } = require('./a6_common.cjs');

export async function run({ src, createMockGL }) {
  a6Register(src);
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const { WebGLRenderTarget } = await import(src + '/renderers/WebGLRenderTarget.js');
  const { Lensflare, LensflareElement } = await import('three/addons/objects/Lensflare.js');
  const extra = JSON.stringify(JSON.parse(A6_EXTRA_UNIFORMS).concat([{ name: 'scale', type: 0x8B50 }]));
  const gl = createMockGL(JSON.parse(a6Options(mockOptions({}, A6_DROP.concat(['scale'])), extra)));
  // WebGL converts GLint arguments with ToInt32 (WebIDL `long`); the port's binding takes
  // Int32 and converts before the call (`| 0`), so record upstream's fractional copy
  // offsets after the same conversion.
  const copyTexSubImage2D = gl.copyTexSubImage2D;
  gl.copyTexSubImage2D = function (...a) { return copyTexSubImage2D.apply(this, a.map((v) => v | 0)); };
  const canvas = createMockCanvas(gl, 64, 32);
  const renderer = new WebGLRenderer({ canvas, context: gl });
  const scene = new T.Scene();
  const camera = new T.PerspectiveCamera(50, 2, 0.1, 100);
  camera.position.set(0, 0, 5);
  scene.add(new T.DirectionalLight(0xffffff, 1));
  const box = new T.Mesh(new T.BoxGeometry(1, 1, 1), new T.MeshStandardMaterial({ color: 0x228822 }));
  box.position.set(1, 0, 0);
  scene.add(box);
  const tex = (seed) => {
    const data = new Uint8Array(2 * 2 * 4);
    for (let i = 0; i < data.length; i++) data[i] = (i * seed + 5) % 256;
    const t = new T.DataTexture(data, 2, 2);
    t.needsUpdate = true;
    return t;
  };
  const light = new T.Object3D();
  light.position.set(- 0.5, 0.3, - 3);
  scene.add(light);
  const flare = new Lensflare();
  flare.addElement(new LensflareElement(tex(3), 32, 0, new T.Color(0xffccaa)));
  flare.addElement(new LensflareElement(tex(5), 12, 0.6));
  flare.addElement(new LensflareElement(tex(7), 20, 1.0, new T.Color(0x3366ff)));
  light.add(flare);
  gl.__note('lensflare', [flare.type, flare.isLensflare === true, flare.frustumCulled, flare.renderOrder, flare.material.opacity, flare.material.transparent, flare.geometry === Lensflare.Geometry]);
  renderer.render(scene, camera);
  renderer.render(scene, camera);
  // behind the camera: nothing
  light.position.set(0, 0, 8);
  renderer.render(scene, camera);
  // off screen: culled
  light.position.set(30, 0, - 3);
  renderer.render(scene, camera);
  // into a half-float target
  light.position.set(0.2, - 0.1, - 2);
  const target = new WebGLRenderTarget(48, 24, { type: T.HalfFloatType });
  renderer.setRenderTarget(target);
  renderer.render(scene, camera);
  renderer.setRenderTarget(null);
  renderer.render(scene, camera);
  flare.dispose();
  return gl.__log;
}
