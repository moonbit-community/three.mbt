export async function run({ src, createMockGL }) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderList } = await import(src + '/renderers/webgl/WebGLRenderLists.js');
  const gl = createMockGL({});
  const camera = new T.PerspectiveCamera();
  const geometry = new T.BufferGeometry();
  const opaqueA = new T.MeshBasicMaterial();
  const opaqueB = new T.MeshBasicMaterial();
  const transparent = new T.MeshBasicMaterial();
  transparent.transparent = true;
  const transmissive = new T.MeshPhysicalMaterial();
  transmissive.transmission = 0.5;
  const objects = [];
  for (let i = 0; i < 8; i ++) {
    const o = i === 5 ? new T.InstancedMesh(geometry, opaqueA, 1) : new T.Mesh(geometry, opaqueA);
    o.name = 'o' + i;
    o.renderOrder = [0, 1, 0, 0, 1, 0, 0, 2][i];
    objects.push(o);
  }
  const list = new WebGLRenderList();
  const names = (items) => items.map((it) => it.object.name + '@' + it.z);
  const run = () => {
    list.init();
    list.push(objects[0], geometry, opaqueB, 0, 5, null, camera);
    list.push(objects[1], geometry, opaqueA, 0, 1, null, camera);
    list.push(objects[2], geometry, opaqueA, 0, 3, null, camera);
    list.push(objects[3], geometry, opaqueA, 1, 2, null, camera);
    list.push(objects[4], geometry, transparent, 0, 4, null, camera);
    list.push(objects[5], geometry, opaqueA, 0, 3, null, camera);
    list.push(objects[6], geometry, transparent, 0, 9, null, camera);
    list.push(objects[7], geometry, transmissive, 0, 1, null, camera);
    list.push(objects[6], geometry, transmissive, 0, 2, null, camera);
    list.unshift(objects[2], geometry, transparent, 0, 0.5, null);
    list.push(objects[0], geometry, opaqueA, 0, 3, null, camera);
  };
  run();
  list.sort(null, null);
  gl.__note('opaque', names(list.opaque));
  gl.__note('transparent', names(list.transparent));
  gl.__note('transmissive', names(list.transmissive));
  run();
  list.sort((a, b) => b.z - a.z, (a, b) => a.z - b.z);
  gl.__note('opaque custom', names(list.opaque));
  gl.__note('transparent custom', names(list.transparent));
  list.init();
  list.push(objects[1], geometry, opaqueA, 0, 1, null, camera);
  list.finish();
  gl.__note('opaque after finish', names(list.opaque));
  return gl.__log;
}
