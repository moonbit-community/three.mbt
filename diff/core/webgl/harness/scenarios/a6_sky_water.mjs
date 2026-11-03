// a6 (objects add-ons): Sky (SkyShader on a back-faced box) and Water (MirrorShader with
// lights and fog, a mirrored render in onBeforeRender) on WebGLRenderer.
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { createMockCanvas, mockOptions } = require('./renderer_common.cjs');
const { a6Register, A6_EXTRA_UNIFORMS, a6Options, A6_DROP } = require('./a6_common.cjs');

export async function run({ src, createMockGL }) {
  a6Register(src);
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const { Sky } = await import('three/addons/objects/Sky.js');
  const { Water } = await import('three/addons/objects/Water.js');
  const gl = createMockGL(JSON.parse(a6Options(mockOptions({}, A6_DROP), A6_EXTRA_UNIFORMS)));
  const canvas = createMockCanvas(gl, 64, 32);
  const renderer = new WebGLRenderer({ canvas, context: gl });
  renderer.toneMapping = T.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 0.5;
  const scene = new T.Scene();
  scene.fog = new T.Fog(0x8899aa, 1, 50);
  const camera = new T.PerspectiveCamera(55, 2, 1, 2000);
  camera.position.set(3, 3, 10);
  camera.lookAt(0, 0, 0);
  const sun = new T.DirectionalLight(0xffeedd, 2);
  sun.position.set(1, 1, 0);
  scene.add(sun);
  const sky = new Sky();
  sky.scale.setScalar(1000);
  const u = sky.material.uniforms;
  u.turbidity.value = 10;
  u.rayleigh.value = 2;
  u.sunPosition.value.setFromSphericalCoords(1, 1.3, 0.6);
  u.time.value = 12.5;
  scene.add(sky);
  gl.__note('sky', [sky.type, sky.isSky === true, sky.material.side, sky.material.depthWrite, sky.material.name, Object.keys(u)]);
  const data = new Uint8Array(4 * 4 * 4);
  for (let i = 0; i < data.length; i++) data[i] = (i * 37) % 256;
  const normals = new T.DataTexture(data, 4, 4);
  normals.wrapS = normals.wrapT = T.RepeatWrapping;
  normals.needsUpdate = true;
  const water = new Water(new T.PlaneGeometry(100, 100), { textureWidth: 32, textureHeight: 32, waterNormals: normals, sunDirection: new T.Vector3(0.6, 0.8, 0), sunColor: 0xffffff, waterColor: 0x001e0f, distortionScale: 3.7, fog: true, alpha: 0.9 });
  water.rotation.x = - Math.PI / 2;
  scene.add(water);
  gl.__note('water', [water.type, water.isWater === true, water.material.lights, water.material.fog, water.material.side, Object.keys(water.material.uniforms)]);
  renderer.render(scene, camera);
  gl.__note('eye', water.material.uniforms.eye.value.toArray());
  water.material.uniforms.time.value += 1 / 60;
  renderer.render(scene, camera);
  // below the surface: no mirror render
  camera.position.set(0, - 3, 10);
  camera.lookAt(0, 0, 0);
  renderer.render(scene, camera);
  return gl.__log;
}
