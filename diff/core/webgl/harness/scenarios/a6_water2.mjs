// a6 (objects add-ons): Water2.js's Water (a Reflector and a Refractor rendered from its
// onBeforeRender, flow uniforms advanced by a Timer) with a flow direction and with a flow
// map, on WebGLRenderer. performance.now is stubbed (a6StubNow) on both sides.
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { createMockCanvas, mockOptions } = require('./renderer_common.cjs');
const { a6Register, A6_EXTRA_UNIFORMS, a6Options, A6_DROP, a6StubNow } = require('./a6_common.cjs');

export async function run({ src, createMockGL }) {
  a6Register(src);
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const { Water } = await import('three/addons/objects/Water2.js');
  const restore = a6StubNow();
  const gl = createMockGL(JSON.parse(a6Options(mockOptions({}, A6_DROP), A6_EXTRA_UNIFORMS)));
  const canvas = createMockCanvas(gl, 64, 32);
  const renderer = new WebGLRenderer({ canvas, context: gl });
  const scene = new T.Scene();
  const camera = new T.PerspectiveCamera(45, 2, 0.1, 200);
  camera.position.set(-4, 5, 8);
  camera.lookAt(0, 0, 0);
  scene.add(new T.DirectionalLight(0xffffff, 1));
  const ground = new T.Mesh(new T.PlaneGeometry(20, 20), new T.MeshStandardMaterial({ color: 0x777777 }));
  ground.rotation.x = - Math.PI / 2;
  ground.position.y = - 1;
  scene.add(ground);
  const tex = (seed) => {
    const data = new Uint8Array(2 * 2 * 4);
    for (let i = 0; i < data.length; i++) data[i] = (i * seed + 11) % 256;
    const t = new T.DataTexture(data, 2, 2);
    t.needsUpdate = true;
    return t;
  };
  const water = new Water(new T.PlaneGeometry(10, 10), { color: 0xaaccff, scale: 4, flowDirection: new T.Vector2(1, 1), textureWidth: 16, textureHeight: 16, normalMap0: tex(3), normalMap1: tex(5) });
  water.rotation.x = - Math.PI / 2;
  scene.add(water);
  const flowing = new Water(new T.PlaneGeometry(4, 4), { flowMap: tex(7), flowSpeed: 2.5, reflectivity: 0.3, textureWidth: 8, textureHeight: 8, normalMap0: tex(9), normalMap1: tex(13) });
  flowing.rotation.x = - Math.PI / 2;
  flowing.position.set(6, 0.5, 0);
  scene.add(flowing);
  gl.__note('water2', [water.type, water.isWater === true, water.material.name, water.material.transparent, water.material.fog, Object.keys(water.material.uniforms), Object.keys(flowing.material.uniforms), flowing.material.defines]);
  for (let frame = 0; frame < 3; frame++) {
    renderer.render(scene, camera);
    gl.__note('config', [water.material.uniforms.config.value.toArray(), flowing.material.uniforms.config.value.toArray()]);
  }
  restore();
  return gl.__log;
}
