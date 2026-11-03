// a6 (objects add-ons): GroundedSkybox, ShadowMesh (stencil, update) and MarchingCubes
// (balls, planes, colors, uvs, blur, flat shading) on WebGLRenderer.
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { createMockCanvas, mockOptions } = require('./renderer_common.cjs');
const { a6Register, A6_EXTRA_UNIFORMS, a6Options, A6_DROP } = require('./a6_common.cjs');

const sum = (a, n) => { let s = 0; for (let i = 0; i < n; i++) s += a[i] * ((i % 7) + 1); return s; };

export async function run({ src, createMockGL }) {
  a6Register(src);
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const { GroundedSkybox } = await import('three/addons/objects/GroundedSkybox.js');
  const { ShadowMesh } = await import('three/addons/objects/ShadowMesh.js');
  const { MarchingCubes } = await import('three/addons/objects/MarchingCubes.js');
  const gl = createMockGL(JSON.parse(a6Options(mockOptions({ contextAttributes: { stencil: true } }, A6_DROP), A6_EXTRA_UNIFORMS)));
  const canvas = createMockCanvas(gl, 64, 32);
  const renderer = new WebGLRenderer({ canvas, context: gl, stencil: true });
  const scene = new T.Scene();
  const camera = new T.PerspectiveCamera(60, 2, 0.1, 100);
  camera.position.set(2, 3, 6);
  camera.lookAt(0, 0, 0);
  scene.add(new T.DirectionalLight(0xffffff, 1));
  const envData = new Uint8Array(8 * 4 * 4);
  for (let i = 0; i < envData.length; i++) envData[i] = (i * 13) % 256;
  const env = new T.DataTexture(envData, 8, 4);
  env.mapping = T.EquirectangularReflectionMapping;
  env.needsUpdate = true;
  const skybox = new GroundedSkybox(env, 10, 20, 8);
  skybox.position.y = 1.9;
  scene.add(skybox);
  const pos = skybox.geometry.attributes.position;
  gl.__note('skybox', [skybox.type, pos.count, pos.version, sum(pos.array, pos.array.length), skybox.material.depthWrite, skybox.material.map === env]);
  let threw = null;
  try { new GroundedSkybox(env, 0, 1); } catch (e) { threw = e.message; }
  gl.__note('skybox throws', threw);
  const caster = new T.Mesh(new T.BoxGeometry(0.5, 1, 0.5), new T.MeshStandardMaterial({ color: 0xaa4444 }));
  caster.position.set(0, 1, 0);
  scene.add(caster);
  const shadow = new ShadowMesh(caster);
  scene.add(shadow);
  const plane = new T.Plane(new T.Vector3(0, 1, 0), 0.01);
  const light4 = new T.Vector4(2, 5, 1, 0.001);
  caster.updateMatrixWorld();
  shadow.update(plane, light4);
  gl.__note('shadow mesh', [shadow.isShadowMesh === true, shadow.frustumCulled, shadow.matrixAutoUpdate, shadow.material.stencilWrite, shadow.material.stencilFunc, shadow.material.stencilZPass, shadow.material.opacity, Array.from(shadow.matrix.elements)]);
  const mc = new MarchingCubes(16, new T.MeshStandardMaterial({ vertexColors: true }), true, true, 3000);
  mc.position.set(- 1, 0.5, 0);
  mc.isolation = 60;
  mc.addBall(0.5, 0.5, 0.5, 0.5, 12);
  mc.addBall(0.3, 0.6, 0.45, 0.4, 12, new T.Color(0xff0000));
  mc.addBall(0.7, 0.4, 0.55, - 0.2, 12, [ 0.2, - 2, 0.5 ]);
  mc.addBall(0.6, 0.65, 0.4, 0.3, 12, 0x00ff00);
  mc.addPlaneY(2, 12);
  mc.addPlaneX(1, 12);
  mc.addPlaneZ(1, 14);
  mc.blur(0.5);
  mc.setCell(5, 5, 5, mc.getCell(5, 5, 6) + 3);
  mc.update();
  scene.add(mc);
  const g = mc.geometry;
  gl.__note('marching cubes', [mc.count, g.drawRange.count, sum(mc.positionArray, mc.count * 3), sum(mc.normalArray, mc.count * 3), sum(mc.uvArray, mc.count * 2), sum(mc.colorArray, mc.count * 3), sum(mc.field, mc.size3), sum(mc.palette, mc.size3 * 3), g.boundingSphere.radius]);
  renderer.render(scene, camera);
  shadow.update(plane, new T.Vector4(- 3, 4, 2, 1));
  mc.material.flatShading = true;
  mc.reset();
  mc.addBall(0.5, 0.5, 0.5, 0.7, 10);
  mc.update();
  gl.__note('marching cubes 2', [mc.count, sum(mc.normalArray, mc.count * 3), sum(mc.palette, mc.size3 * 3), Array.from(shadow.matrix.elements)]);
  renderer.render(scene, camera);
  return gl.__log;
}
