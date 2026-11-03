// Group 4: full frames with lights, a shadow map, fog, transparency, skinning, morph
// targets, an override material and clipping planes.
import { createRequire } from 'node:module';
const { createMockCanvas, mockOptions } = createRequire(import.meta.url)('./renderer_common.cjs');

export async function run({ src, createMockGL }) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const gl = createMockGL(JSON.parse(mockOptions({})));
  const canvas = createMockCanvas(gl, 64, 32);
  const renderer = new WebGLRenderer({ canvas, context: gl, antialias: true });
  renderer.shadowMap.enabled = true;
  const scene = new T.Scene();
  scene.fog = new T.Fog(0x202020, 1, 20);
  const camera = new T.PerspectiveCamera(45, 2, 0.5, 50);
  camera.position.set(0, 1, 6);
  camera.lookAt(0, 0, 0);
  scene.add(new T.AmbientLight(0x404040, 0.5));
  const sun = new T.DirectionalLight(0xffffff, 2);
  sun.position.set(2, 4, 3);
  sun.castShadow = true;
  sun.shadow.mapSize.set(64, 64);
  scene.add(sun);
  const point = new T.PointLight(0xff8800, 3, 10, 2);
  point.position.set(-2, 1, 1);
  scene.add(point);
  const spot = new T.SpotLight(0x00ff88, 4, 12, Math.PI / 6, 0.2, 1);
  spot.position.set(2, 3, 2);
  scene.add(spot);
  scene.add(new T.HemisphereLight(0x8888ff, 0x442200, 0.7));
  const sphere = new T.SphereGeometry(0.5, 8, 6);
  const lambert = new T.Mesh(sphere, new T.MeshLambertMaterial({ color: 0xcc4444 }));
  lambert.position.set(-1.2, 0, 0);
  lambert.castShadow = true;
  scene.add(lambert);
  const phong = new T.Mesh(sphere, new T.MeshPhongMaterial({ color: 0x44cc44, shininess: 50 }));
  phong.castShadow = true;
  scene.add(phong);
  const standard = new T.Mesh(sphere, new T.MeshStandardMaterial({ color: 0x4444cc, roughness: 0.3, metalness: 0.2 }));
  standard.position.set(1.2, 0, 0);
  standard.castShadow = true;
  scene.add(standard);
  const ground = new T.Mesh(new T.PlaneGeometry(6, 6), new T.MeshStandardMaterial({ color: 0x888888 }));
  ground.rotation.x = - Math.PI / 2;
  ground.position.y = - 0.6;
  ground.receiveShadow = true;
  scene.add(ground);
  const glass = new T.Mesh(new T.BoxGeometry(0.6, 0.6, 0.6), new T.MeshLambertMaterial({ color: 0xffffff, transparent: true, opacity: 0.5, side: T.DoubleSide }));
  glass.position.set(0, 0.2, 1.5);
  scene.add(glass);
  // skinned mesh: two bones
  const skinGeometry = new T.BoxGeometry(0.3, 1, 0.3, 1, 2, 1);
  const count = skinGeometry.attributes.position.count;
  const skinIndex = [];
  const skinWeight = [];
  for (let i = 0; i < count; i++) {
    const y = skinGeometry.attributes.position.getY(i);
    skinIndex.push(y > 0 ? 1 : 0, 0, 0, 0);
    skinWeight.push(1, 0, 0, 0);
  }
  skinGeometry.setAttribute('skinIndex', new T.Uint16BufferAttribute(skinIndex, 4));
  skinGeometry.setAttribute('skinWeight', new T.Float32BufferAttribute(skinWeight, 4));
  const skinned = new T.SkinnedMesh(skinGeometry, new T.MeshPhongMaterial({ color: 0xaaaa00 }));
  const root = new T.Bone();
  const tip = new T.Bone();
  tip.position.y = 0.5;
  root.add(tip);
  skinned.add(root);
  skinned.bind(new T.Skeleton([root, tip]));
  tip.rotation.z = 0.4;
  skinned.position.set(-2, 0, 0);
  scene.add(skinned);
  // morph targets
  const morphGeometry = new T.BoxGeometry(0.4, 0.4, 0.4);
  const positions = morphGeometry.attributes.position;
  const target = [];
  for (let i = 0; i < positions.count; i++) target.push(positions.getX(i) * 2, positions.getY(i), positions.getZ(i));
  morphGeometry.morphAttributes.position = [new T.Float32BufferAttribute(target, 3)];
  const morph = new T.Mesh(morphGeometry, new T.MeshStandardMaterial({ color: 0xff00ff }));
  morph.morphTargetInfluences[0] = 0.5;
  morph.position.set(2, 0.5, 0);
  scene.add(morph);
  renderer.render(scene, camera);
  gl.__note('info.render', [renderer.info.render.calls, renderer.info.render.triangles]);
  gl.__note('programs', renderer.info.programs.length);
  // second frame with moved lights and shadow auto update off
  sun.position.set(-2, 4, 3);
  point.intensity = 1;
  renderer.shadowMap.autoUpdate = false;
  renderer.render(scene, camera);
  renderer.shadowMap.needsUpdate = true;
  renderer.render(scene, camera);
  // a light added: lights hash changes, programs change
  const second = new T.DirectionalLight(0xffffff, 0.5);
  scene.add(second);
  renderer.render(scene, camera);
  gl.__note('programs', renderer.info.programs.length);
  // override material
  scene.overrideMaterial = new T.MeshBasicMaterial({ color: 0x00ff00 });
  renderer.render(scene, camera);
  scene.overrideMaterial = null;
  // clipping planes
  renderer.clippingPlanes = [new T.Plane(new T.Vector3(0, -1, 0), 0.5)];
  renderer.localClippingEnabled = true;
  standard.material.clippingPlanes = [new T.Plane(new T.Vector3(1, 0, 0), 1)];
  standard.material.needsUpdate = true;
  renderer.render(scene, camera);
  renderer.render(scene, camera);
  renderer.clippingPlanes = [];
  scene.fog = new T.FogExp2(0x101010, 0.1);
  renderer.render(scene, camera);
  renderer.dispose();
  return gl.__log;
}
