// Group 4: full frames of unlit objects through WebGLRenderer: meshes, a DataTexture map,
// lines, points, a sprite, instancing, multi-material groups, wireframe, sorting,
// render callbacks, compile and renderBufferDirect.
import { createRequire } from 'node:module';
const { createMockCanvas, mockOptions } = createRequire(import.meta.url)('./renderer_common.cjs');

export async function run({ src, createMockGL }) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const gl = createMockGL(JSON.parse(mockOptions({})));
  const canvas = createMockCanvas(gl, 64, 32);
  const renderer = new WebGLRenderer({ canvas, context: gl });
  const scene = new T.Scene();
  const camera = new T.PerspectiveCamera(50, 2, 0.1, 100);
  camera.position.set(0, 0, 5);
  const box = new T.Mesh(new T.BoxGeometry(1, 1, 1), new T.MeshBasicMaterial({ color: 0xff0000 }));
  box.position.set(-1, 0, 0);
  box.rotation.set(0.3, 0.4, 0);
  scene.add(box);
  const data = new Uint8Array([255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255]);
  const texture = new T.DataTexture(data, 2, 2);
  texture.needsUpdate = true;
  const plane = new T.Mesh(new T.PlaneGeometry(1, 1), new T.MeshBasicMaterial({ map: texture }));
  plane.position.set(1, 0, -1);
  scene.add(plane);
  const lineGeometry = new T.BufferGeometry().setFromPoints([new T.Vector3(0, 0, 0), new T.Vector3(1, 1, 0), new T.Vector3(1, 0, 0)]);
  const lineMaterial = new T.LineBasicMaterial({ color: 0x00ff00 });
  scene.add(new T.Line(lineGeometry, lineMaterial));
  scene.add(new T.LineSegments(lineGeometry, lineMaterial));
  scene.add(new T.LineLoop(lineGeometry, lineMaterial));
  const points = new T.Points(lineGeometry, new T.PointsMaterial({ size: 3, sizeAttenuation: false }));
  scene.add(points);
  const sprite = new T.Sprite(new T.SpriteMaterial({ color: 0x0000ff }));
  sprite.position.set(0, 1, 0);
  scene.add(sprite);
  const group = new T.Group();
  group.renderOrder = 2;
  const instanced = new T.InstancedMesh(new T.BoxGeometry(0.2, 0.2, 0.2), new T.MeshBasicMaterial(), 3);
  const m = new T.Matrix4();
  for (let i = 0; i < 3; i++) {
    instanced.setMatrixAt(i, m.makeTranslation(i * 0.3, -1, 0));
    instanced.setColorAt(i, new T.Color(i / 3, 0.5, 1));
  }
  group.add(instanced);
  scene.add(group);
  const multi = new T.Mesh(new T.BoxGeometry(0.5, 0.5, 0.5), [
    new T.MeshBasicMaterial({ color: 0x111111 }), new T.MeshBasicMaterial({ color: 0x222222 }),
    new T.MeshBasicMaterial({ color: 0x333333, visible: false }),
  ]);
  multi.position.set(0, -1, 1);
  scene.add(multi);
  const wire = new T.Mesh(new T.SphereGeometry(0.3, 4, 3), new T.MeshBasicMaterial({ wireframe: true }));
  wire.position.set(0, 0.5, 1);
  scene.add(wire);
  const hidden = new T.Mesh(new T.BoxGeometry(), new T.MeshBasicMaterial());
  hidden.visible = false;
  scene.add(hidden);
  const layered = new T.Mesh(new T.BoxGeometry(), new T.MeshBasicMaterial());
  layered.layers.set(3);
  scene.add(layered);
  scene.onBeforeRender = (r, s, c, target) => gl.__note('scene.onBeforeRender', [r === renderer, s === scene, c === camera, target]);
  scene.onAfterRender = (r, s, c) => gl.__note('scene.onAfterRender', [r === renderer, s === scene, c === camera]);
  box.onBeforeRender = (r, s, c, g, mat, grp) => gl.__note('box.onBeforeRender', [g === box.geometry, mat === box.material, grp]);
  box.onAfterRender = () => gl.__note('box.onAfterRender', 1);
  box.material.onBeforeRender = (r, s, c, g, o) => gl.__note('material.onBeforeRender', o === box);
  const materials = renderer.compile(scene, camera);
  gl.__note('compiled', materials.size);
  renderer.render(scene, camera);
  gl.__note('info.render', [renderer.info.render.frame, renderer.info.render.calls, renderer.info.render.triangles, renderer.info.render.points, renderer.info.render.lines]);
  gl.__note('info.memory', [renderer.info.memory.geometries, renderer.info.memory.textures]);
  gl.__note('programs', renderer.info.programs.length);
  // second frame: cached programs, moved camera, custom sort, no sorting
  camera.position.set(0.5, 0, 6);
  box.material.color.set(0x00ffff);
  renderer.setOpaqueSort((a, b) => b.id - a.id);
  renderer.render(scene, camera);
  renderer.sortObjects = false;
  renderer.setOpaqueSort(null);
  box.material.needsUpdate = true;
  renderer.render(scene, camera);
  gl.__note('info.render', [renderer.info.render.frame, renderer.info.render.calls, renderer.info.render.triangles]);
  // orthographic camera, scissor, autoClear off, tone mapping variant
  renderer.sortObjects = true;
  renderer.autoClear = false;
  renderer.toneMapping = T.ACESFilmicToneMapping;
  renderer.setScissorTest(true);
  renderer.setScissor(0, 0, 32, 16);
  const ortho = new T.OrthographicCamera(-2, 2, 1, -1, 0.1, 50);
  ortho.position.set(0, 0, 10);
  renderer.render(scene, ortho);
  renderer.setScissorTest(false);
  // renderBufferDirect without a scene, from inside a frame (it needs the render state)
  sprite.onBeforeRender = (r, s, c) => { sprite.onBeforeRender = () => {}; r.renderBufferDirect(c, null, box.geometry, box.material, box, null); };
  // a camera with layers
  camera.layers.enable(3);
  renderer.render(scene, camera);
  // material disposal releases programs
  plane.material.dispose();
  gl.__note('programs after dispose', renderer.info.programs.length);
  renderer.render(scene, camera);
  renderer.dispose();
  return gl.__log;
}
