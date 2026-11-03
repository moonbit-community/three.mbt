// Group 3: WebGLMorphtargets driven directly, with the real WebGLUniforms / WebGLTextures
// (the program is a stand-in that returns uniforms parsed from a mock program).
export const MORPH_OPTIONS = { parameters: { MAX_TEXTURE_SIZE: 8 }, programs: [{ attributes: [], uniforms: [
  { name: 'morphTargetBaseInfluence', type: 0x1406 }, { name: 'morphTargetInfluences[0]', type: 0x1406, size: 4 },
  { name: 'morphTargetsTexture', type: 0x8DC1 }, { name: 'morphTargetsTextureSize', type: 0x8B53 },
  { name: 'morphTexture', type: 0x8B5E },
] }] };

export async function run({ src, createMockGL }) {
  const T = await import(src + '/Three.Core.js');
  const W = (n) => import(src + '/renderers/webgl/' + n + '.js');
  const { WebGLExtensions } = await W('WebGLExtensions');
  const { WebGLUtils } = await W('WebGLUtils');
  const { WebGLCapabilities } = await W('WebGLCapabilities');
  const { WebGLState } = await W('WebGLState');
  const { WebGLProperties } = await W('WebGLProperties');
  const { WebGLInfo } = await W('WebGLInfo');
  const { WebGLTextures } = await W('WebGLTextures');
  const { WebGLUniforms } = await W('WebGLUniforms');
  const { WebGLMorphtargets } = await W('WebGLMorphtargets');
  const gl = createMockGL(MORPH_OPTIONS);
  const extensions = new WebGLExtensions(gl);
  const utils = new WebGLUtils(gl, extensions);
  const capabilities = new WebGLCapabilities(gl, extensions, {}, utils);
  const state = new WebGLState(gl, extensions);
  const properties = new WebGLProperties();
  const info = new WebGLInfo(gl);
  const textures = new WebGLTextures(gl, extensions, state, properties, capabilities, utils, info);
  const uniforms = new WebGLUniforms(gl, gl.createProgram());
  const program = { getUniforms: () => uniforms };
  const morph = new WebGLMorphtargets(gl, capabilities, textures);
  gl.__clear();

  const attr = (n, size, f) => { const a = new Float32Array(n * size); for (let i = 0; i < a.length; i ++) a[i] = f(i); return new T.BufferAttribute(a, size); };
  const geometry = new T.BufferGeometry();
  geometry.setAttribute('position', attr(2, 3, (i) => i));
  geometry.morphAttributes.position = [attr(2, 3, (i) => i * 0.5), attr(2, 3, (i) => - i)];
  geometry.morphAttributes.normal = [attr(2, 3, (i) => i * 0.25), attr(2, 3, (i) => 1 - i)];
  geometry.morphAttributes.color = [attr(2, 4, (i) => i * 0.125), attr(2, 3, (i) => 0.5)];
  const mesh = new T.Mesh(geometry, new T.MeshBasicMaterial());
  mesh.morphTargetInfluences = [0.25, 0.5];
  morph.update(mesh, geometry, program);
  gl.__note('info', info.memory.textures);
  mesh.morphTargetInfluences[1] = 0.125;
  morph.update(mesh, geometry, program);
  geometry.morphTargetsRelative = true;
  morph.update(mesh, geometry, program);

  // more targets: the texture is rebuilt
  geometry.morphAttributes.position.push(attr(2, 3, (i) => 2 * i));
  geometry.morphAttributes.normal.push(attr(2, 3, (i) => 3));
  geometry.morphAttributes.color.push(attr(2, 3, (i) => 0.75));
  mesh.morphTargetInfluences.push(1);
  morph.update(mesh, geometry, program);
  gl.__note('info', info.memory.textures);

  // wider than MAX_TEXTURE_SIZE, position only
  const wide = new T.BufferGeometry();
  wide.setAttribute('position', attr(5, 3, (i) => i));
  wide.morphAttributes.position = [attr(5, 3, (i) => i + 0.5)];
  const wideMesh = new T.Mesh(wide, new T.MeshBasicMaterial());
  wideMesh.morphTargetInfluences = [0.75];
  morph.update(wideMesh, wide, program);

  // instanced mesh with a morph texture
  const instanced = new T.InstancedMesh(wide, new T.MeshBasicMaterial(), 2);
  instanced.morphTargetInfluences = [0.5];
  instanced.morphTexture = new T.DataTexture(new Float32Array(8), 2, 1, T.RedFormat, T.FloatType);
  instanced.morphTexture.needsUpdate = true;
  morph.update(instanced, wide, program);
  gl.__note('info', info.memory.textures);

  geometry.dispose();
  gl.__note('info', info.memory.textures);
  morph.update(mesh, geometry, program);
  gl.__note('info', info.memory.textures);
  return gl.__log;
}
