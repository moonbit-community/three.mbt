export async function run({ src, createMockGL }) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLAttributes } = await import(src + '/renderers/webgl/WebGLAttributes.js');
  const { WebGLBindingStates } = await import(src + '/renderers/webgl/WebGLBindingStates.js');
  const gl = createMockGL({});
  const attributes = new WebGLAttributes(gl);
  const bs = new WebGLBindingStates(gl, attributes);
  const programAttributes = {
    position: { type: 0x8B51, location: 0, locationSize: 1 },
    normal: { type: 0x8B51, location: 1, locationSize: 1 },
    aInt: { type: 0x1404, location: 2, locationSize: 1 },
    color: { type: 0x8B51, location: 3, locationSize: 1 },
    instanceMatrix: { type: 0x8B5C, location: 4, locationSize: 4 },
    unused: { type: 0x1406, location: - 1, locationSize: 1 },
  };
  const program = { id: 7, getAttributes: () => programAttributes };
  const geometry = new T.BufferGeometry();
  geometry.setAttribute('position', new T.Float32BufferAttribute([0, 0, 0, 1, 0, 0, 0, 1, 0], 3));
  geometry.setAttribute('normal', new T.Float32BufferAttribute([0, 0, 1, 0, 0, 1, 0, 0, 1], 3));
  geometry.setAttribute('aInt', new T.Int32BufferAttribute([1, 2, 3], 1));
  geometry.setIndex([0, 1, 2]);
  const material = new T.ShaderMaterial();
  material.defaultAttributeValues = { color: [1, 0, 0] };
  const mesh = new T.Mesh(geometry, material);
  for (const name in geometry.attributes) attributes.update(geometry.attributes[name], gl.ARRAY_BUFFER);
  bs.setup(mesh, material, program, geometry, geometry.index);
  bs.setup(mesh, material, program, geometry, geometry.index);
  material.wireframe = true;
  bs.setup(mesh, material, program, geometry, geometry.index);
  material.wireframe = false;
  bs.setup(mesh, material, program, geometry, geometry.index);
  const geometry3 = new T.BufferGeometry();
  const ib = new T.InterleavedBuffer(new Float32Array(18), 6);
  geometry3.setAttribute('position', new T.InterleavedBufferAttribute(ib, 3, 0));
  geometry3.setAttribute('normal', new T.InterleavedBufferAttribute(ib, 3, 3));
  geometry3.setAttribute('color', new T.InstancedBufferAttribute(new Float32Array([1, 1, 1, 0, 0, 0]), 3, false, 2));
  const mesh3 = new T.Mesh(geometry3, material);
  for (const name in geometry3.attributes) attributes.update(geometry3.attributes[name], gl.ARRAY_BUFFER);
  bs.setup(mesh3, material, program, geometry3, null);
  gl.__note('maxInstanceCount', geometry3._maxInstanceCount === undefined ? 'undefined' : geometry3._maxInstanceCount);
  const im = new T.InstancedMesh(geometry, material, 2);
  attributes.update(im.instanceMatrix, gl.ARRAY_BUFFER);
  bs.setup(im, material, program, geometry, geometry.index);
  bs.reset();
  bs.reset();
  bs.setup(mesh, material, program, geometry, geometry.index);
  bs.releaseStatesOfObject(im);
  bs.releaseStatesOfGeometry(geometry3);
  bs.releaseStatesOfProgram(program);
  bs.setup(mesh, material, program, geometry, geometry.index);
  bs.dispose();
  return gl.__log;
}
