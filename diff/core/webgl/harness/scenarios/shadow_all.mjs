// Group 3: WebGLShadowMap through WebGLRenderer: directional, spot and point light
// shadows with PCF, Basic, VSM and the removed PCFSoft type; custom depth/distance
// materials, the per-material depth material cache, autoUpdate / needsUpdate, the
// maximum texture size clamp and material disposal.
import { createRequire } from 'node:module';
import { g3Options } from '../group3_util.mjs';
const { createMockCanvas, mockOptions } = createRequire(import.meta.url)('./renderer_common.cjs');

export async function run({ src, createMockGL }) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const gl = createMockGL(g3Options(mockOptions, { parameters: { MAX_TEXTURE_SIZE: 2048 } }));
  const canvas = createMockCanvas(gl, 64, 32);
  const renderer = new WebGLRenderer({ canvas, context: gl });
  renderer.shadowMap.enabled = true;
  renderer.localClippingEnabled = true;
  const scene = new T.Scene();
  const camera = new T.PerspectiveCamera(50, 2, 0.1, 100);
  camera.position.set(0, 3, 8);
  camera.lookAt(0, 0, 0);

  const dir = new T.DirectionalLight(0xffffff, 1);
  dir.name = 'dir';
  dir.position.set(3, 6, 2);
  dir.castShadow = true;
  dir.shadow.mapSize.set(4096, 256);
  scene.add(dir);
  const spot = new T.SpotLight(0xffeedd, 2, 20, 0.6, 0.2);
  spot.name = 'spot';
  spot.position.set(-2, 5, 1);
  spot.castShadow = true;
  spot.shadow.mapSize.set(64, 64);
  spot.shadow.blurSamples = 4;
  spot.shadow.radius = 2;
  scene.add(spot);
  const point = new T.PointLight(0x88aaff, 3, 0);
  point.name = 'point';
  point.position.set(1, 2, -1);
  point.castShadow = true;
  point.shadow.mapSize.set(32, 32);
  scene.add(point);

  scene.add(new T.HemisphereLight(0xffffff, 0x444444, 0.5));
  const floor = new T.Mesh(new T.PlaneGeometry(10, 10), new T.MeshPhongMaterial());
  floor.rotation.x = - Math.PI / 2;
  floor.receiveShadow = true;
  scene.add(floor);
  const box = new T.Mesh(new T.BoxGeometry(1, 1, 1), new T.MeshBasicMaterial({ color: 0xff0000 }));
  box.castShadow = true;
  box.position.set(0, 0.5, 0);
  scene.add(box);
  const cutout = new T.Mesh(new T.PlaneGeometry(1, 1), new T.MeshBasicMaterial({ map: new T.Texture(), alphaTest: 0.5, side: T.DoubleSide }));
  cutout.castShadow = true;
  cutout.position.set(1.5, 0.5, 0);
  scene.add(cutout);
  const clipped = new T.Mesh(new T.BoxGeometry(0.5, 0.5, 0.5), new T.MeshBasicMaterial({ clippingPlanes: [new T.Plane(new T.Vector3(0, -1, 0), 0.8)], clipShadows: true, shadowSide: T.FrontSide }));
  clipped.castShadow = true;
  clipped.position.set(-1.5, 0.5, 0);
  scene.add(clipped);
  const custom = new T.Mesh(new T.BoxGeometry(0.3, 0.3, 0.3), new T.MeshBasicMaterial());
  custom.castShadow = true;
  custom.customDepthMaterial = new T.MeshDepthMaterial({ depthPacking: T.RGBADepthPacking });
  custom.customDistanceMaterial = new T.MeshDistanceMaterial();
  custom.position.set(0, 2, 0);
  scene.add(custom);
  const multi = new T.Mesh(new T.BoxGeometry(0.4, 0.4, 0.4), [new T.MeshBasicMaterial(), new T.MeshBasicMaterial({ visible: false }), new T.MeshBasicMaterial({ alphaToCoverage: true })]);
  multi.castShadow = true;
  multi.position.set(0.5, 1.5, 1);
  scene.add(multi);
  const line = new T.Line(new T.BufferGeometry().setFromPoints([new T.Vector3(0, 0, 0), new T.Vector3(1, 1, 1)]), new T.LineBasicMaterial());
  line.castShadow = true;
  scene.add(line);
  const far = new T.Mesh(new T.BoxGeometry(), new T.MeshBasicMaterial());
  far.castShadow = true;
  far.position.set(500, 0, 0);
  scene.add(far);

  const maps = () => [dir, spot, point].map((l) => [l.name, l.shadow.map === null ? null : [l.shadow.map.width, l.shadow.map.height, l.shadow.map.isWebGLCubeRenderTarget === true, l.shadow.map.texture.format, l.shadow.map.depthTexture ? [l.shadow.map.depthTexture.name, l.shadow.map.depthTexture.compareFunction, l.shadow.map.depthTexture.minFilter, l.shadow.map.depthTexture.type] : null], l.shadow.mapPass === null ? null : [l.shadow.mapPass.width, l.shadow.mapPass.height], [l.shadow.mapSize.x, l.shadow.mapSize.y], l.shadow.needsUpdate]);
  const frame = (label) => { gl.__log.push('## ' + label); renderer.render(scene, camera); gl.__note(label + ' maps', maps()); gl.__note(label + ' state', [renderer.shadowMap.type, renderer.shadowMap.needsUpdate]); };

  frame('pcf');
  frame('pcf again');
  renderer.shadowMap.autoUpdate = false;
  frame('no auto update');
  renderer.shadowMap.needsUpdate = true;
  dir.shadow.autoUpdate = false;
  frame('needs update');
  dir.shadow.autoUpdate = true;
  renderer.shadowMap.autoUpdate = true;
  renderer.shadowMap.type = T.BasicShadowMap;
  frame('basic');
  renderer.shadowMap.type = T.VSMShadowMap;
  frame('vsm');
  spot.shadow.blurSamples = 8;
  frame('vsm blur samples');
  renderer.shadowMap.type = T.PCFSoftShadowMap;
  frame('pcf soft');
  cutout.material.dispose();
  frame('after dispose');
  renderer.shadowMap.enabled = false;
  frame('disabled');
  return gl.__log;
}
