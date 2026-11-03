// Group 2: WebGLUniforms — parsing active uniforms (structs, arrays, struct arrays,
// shadow samplers first), every singular and pure-array setter, texture units through
// WebGLTextures, setValue / setOptional / upload / seqWithValue.
const F = 0x1406, V2 = 0x8B50, V3 = 0x8B51, V4 = 0x8B52, M2 = 0x8B5A, M3 = 0x8B5B, M4 = 0x8B5C;
const I = 0x1404, B = 0x8B56, IV2 = 0x8B53, IV3 = 0x8B54, IV4 = 0x8B55, BV2 = 0x8B57;
const U = 0x1405, UV2 = 0x8DC6, UV3 = 0x8DC7, UV4 = 0x8DC8;
const S2D = 0x8B5E, SCUBE = 0x8B60, S3D = 0x8B5F, S2DA = 0x8DC1, S2DSH = 0x8B62, SCUBESH = 0x8DC5, S2DASH = 0x8DC4, IS2D = 0x8DCA;
export const UNIFORMS = [
  { name: 'f', type: F }, { name: 'v2', type: V2 }, { name: 'v3', type: V3 }, { name: 'c3', type: V3 },
  { name: 'a3', type: V3 }, { name: 'v4', type: V4 }, { name: 'q4', type: V4 }, { name: 'm2', type: M2 },
  { name: 'm3', type: M3 }, { name: 'm4', type: M4 }, { name: 'm4a', type: M4 }, { name: 'i', type: I },
  { name: 'b', type: B }, { name: 'iv2', type: IV2 }, { name: 'iv3', type: IV3 }, { name: 'iv4', type: IV4 },
  { name: 'bv2', type: BV2 }, { name: 'u', type: U }, { name: 'uv2', type: UV2 }, { name: 'uv3', type: UV3 },
  { name: 'uv4', type: UV4 },
  { name: 's2d', type: S2D }, { name: 'scube', type: SCUBE }, { name: 's3d', type: S3D }, { name: 's2da', type: S2DA },
  { name: 'sshadow', type: S2DSH }, { name: 'scubeshadow', type: SCUBESH }, { name: 's2dashadow', type: S2DASH },
  { name: 'is2d', type: IS2D },
  { name: 'fa[0]', type: F, size: 3 }, { name: 'v2a[0]', type: V2, size: 2 }, { name: 'v3a[0]', type: V3, size: 2 },
  { name: 'v4a[0]', type: V4, size: 2 }, { name: 'm2a[0]', type: M2, size: 2 }, { name: 'm3a[0]', type: M3, size: 2 },
  { name: 'm4a2[0]', type: M4, size: 2 }, { name: 'ia[0]', type: I, size: 2 }, { name: 'iv2a[0]', type: IV2, size: 2 },
  { name: 'iv3a[0]', type: IV3, size: 1 }, { name: 'iv4a[0]', type: IV4, size: 1 }, { name: 'ua[0]', type: U, size: 2 },
  { name: 'uv2a[0]', type: UV2, size: 1 }, { name: 'uv3a[0]', type: UV3, size: 1 }, { name: 'uv4a[0]', type: UV4, size: 1 },
  { name: 'texa[0]', type: S2D, size: 3 }, { name: 'shadowa[0]', type: S2DSH, size: 2 }, { name: 'cubea[0]', type: SCUBE, size: 2 },
  { name: 's3da[0]', type: S3D, size: 1 }, { name: 's2daa[0]', type: S2DA, size: 2 }, { name: 'cubesha[0]', type: SCUBESH, size: 1 },
  { name: 'light.position', type: V3 }, { name: 'light.color', type: V3 }, { name: 'light.intensity', type: F },
  { name: 'lights[0].dir', type: V3 }, { name: 'lights[0].col', type: V3 }, { name: 'lights[1].dir', type: V3 },
  { name: 'lights[1].col', type: V3 }, { name: 's.inner.x', type: F }, { name: 's.arr[0]', type: F, size: 2 },
  { name: 'ps[0].bias', type: F }, { name: 'ps[0].map', type: S2DSH }, { name: 'ps[1].bias', type: F }, { name: 'ps[1].map', type: S2DSH },
  { name: 'bindMatrix', type: M4 }, { name: 'bindMatrixInverse', type: M4 },
];

export async function run({ src, createMockGL }) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLExtensions } = await import(src + '/renderers/webgl/WebGLExtensions.js');
  const { WebGLCapabilities } = await import(src + '/renderers/webgl/WebGLCapabilities.js');
  const { WebGLUtils } = await import(src + '/renderers/webgl/WebGLUtils.js');
  const { WebGLState } = await import(src + '/renderers/webgl/WebGLState.js');
  const { WebGLProperties } = await import(src + '/renderers/webgl/WebGLProperties.js');
  const { WebGLInfo } = await import(src + '/renderers/webgl/WebGLInfo.js');
  const { WebGLTextures } = await import(src + '/renderers/webgl/WebGLTextures.js');
  const { WebGLUniforms } = await import(src + '/renderers/webgl/WebGLUniforms.js');
  const gl = createMockGL({ programs: [{ attributes: [], uniforms: UNIFORMS }], canvas: { width: 64, height: 32 } });
  const extensions = new WebGLExtensions(gl);
  const utils = new WebGLUtils(gl, extensions);
  const capabilities = new WebGLCapabilities(gl, extensions, {}, utils);
  const state = new WebGLState(gl, extensions);
  const properties = new WebGLProperties();
  const info = new WebGLInfo(gl);
  const textures = new WebGLTextures(gl, extensions, state, properties, capabilities, utils, info);
  gl.__clear();
  const program = gl.createProgram();
  const uniforms = new WebGLUniforms(gl, program);
  const describe = (seq) => seq.map((u) => u.seq ? u.id + '{' + describe(u.seq) + '}' : u.id + ':' + u.type + (u.size !== undefined ? '[' + u.size + ']' : '')).join(' ');
  gl.__note('seq', describe(uniforms.seq));
  gl.__note('map', Object.keys(uniforms.map).join(' '));
  gl.__note('lights.map', Object.keys(uniforms.map.lights.map).join(' '));
  const tex = new T.Texture();
  const cube = new T.CubeTexture();
  const t3d = new T.Data3DTexture();
  const t2da = new T.DataArrayTexture();
  const values = {
    f: { value: 0.5 }, v2: { value: new T.Vector2(1, 2) }, v3: { value: new T.Vector3(1, 2, 3) },
    c3: { value: new T.Color(0.25, 0.5, 0.75) }, a3: { value: [4, 5, 6] }, v4: { value: new T.Vector4(1, 2, 3, 4) },
    q4: { value: new T.Quaternion(0, 0, 0, 1) }, m2: { value: [1, 0, 0, 1] }, m3: { value: new T.Matrix3().set(1, 2, 3, 4, 5, 6, 7, 8, 9) },
    m4: { value: new T.Matrix4().makeTranslation(1, 2, 3) }, m4a: { value: new Float32Array(16).fill(0.1) },
    i: { value: 3 }, b: { value: true }, iv2: { value: new T.Vector2(1, 2) }, iv3: { value: [1, 2, 3] },
    iv4: { value: new T.Vector4(1, 2, 3, 4) }, bv2: { value: [1, 0] }, u: { value: 7 }, uv2: { value: [1, 2] },
    uv3: { value: new T.Vector3(1, 2, 3) }, uv4: { value: new Int32Array([1, 2, 3, 4]) },
    s2d: { value: tex }, scube: { value: null }, s3d: { value: t3d }, s2da: { value: null },
    sshadow: { value: null }, scubeshadow: { value: null }, s2dashadow: { value: t2da }, is2d: { value: tex },
    fa: { value: [1, 2, 3] }, v2a: { value: [new T.Vector2(1, 2), new T.Vector2(3, 4)] },
    v3a: { value: [new T.Vector3(1, 2, 3), new T.Color(0.5, 0.25, 1)] }, v4a: { value: new Float32Array(8).fill(2) },
    m2a: { value: [1, 0, 0, 1, 2, 0, 0, 2] }, m3a: { value: [new T.Matrix3(), new T.Matrix3().set(1, 2, 3, 4, 5, 6, 7, 8, 9)] },
    m4a2: { value: [new T.Matrix4(), new T.Matrix4().makeScale(2, 3, 4)] }, ia: { value: [1, 2] }, iv2a: { value: new Int32Array([1, 2, 3, 4]) },
    iv3a: { value: [1, 2, 3] }, iv4a: { value: [1, 2, 3, 4] }, ua: { value: [5, 6] }, uv2a: { value: [1, 2] },
    uv3a: { value: new Uint32Array([1, 2, 3]) }, uv4a: { value: [1, 2, 3, 4] },
    texa: { value: [tex, null, tex] }, shadowa: { value: [null, null] }, cubea: { value: [cube, null] },
    s3da: { value: [t3d] }, s2daa: { value: [null, t2da] }, cubesha: { value: [null] },
    light: { value: { position: new T.Vector3(1, 1, 1), color: new T.Color(1, 0, 0), intensity: 2 } },
    lights: { value: [{ dir: new T.Vector3(0, 1, 0), col: new T.Color(1, 1, 1) }, { dir: new T.Vector3(1, 0, 0), col: new T.Color(0, 1, 0) }] },
    s: { value: { inner: { x: 4 }, arr: [7, 8] } },
    ps: { value: [{ bias: 0.1, map: null }, { bias: 0.2, map: tex }] },
    bindMatrix: { value: new T.Matrix4() }, bindMatrixInverse: { value: new T.Matrix4() },
  };
  textures.resetTextureUnits();
  WebGLUniforms.upload(gl, uniforms.seq, values, textures);
  gl.__note('frame', 2);
  textures.resetTextureUnits();
  WebGLUniforms.upload(gl, uniforms.seq, values, textures);
  gl.__note('frame', 3);
  values.f.value = 0.75;
  values.v2.value.set(2, 2);
  values.c3.value.setRGB(1, 1, 1);
  values.a3.value = [4, 5, 7];
  values.m3.value.set(9, 8, 7, 6, 5, 4, 3, 2, 1);
  values.m4.value.makeRotationX(0.5);
  values.m2.value = [2, 0, 0, 2];
  values.b.value = false;
  values.iv3.value = [1, 2, 4];
  values.u.value = 8;
  values.light.value.intensity = 3;
  values.lights.value[1].col.setRGB(0, 0, 1);
  values.v3.needsUpdate = false;
  values.v3.value.set(9, 9, 9);
  textures.resetTextureUnits();
  textures.allocateTextureUnit();
  WebGLUniforms.upload(gl, uniforms.seq, values, textures);
  gl.__note('frame', 4);
  uniforms.setValue(gl, 'f', 0.75);
  uniforms.setValue(gl, 'f', 1);
  uniforms.setValue(gl, 'i', 4);
  uniforms.setValue(gl, 'b', true);
  uniforms.setValue(gl, 'missing', 1);
  uniforms.setValue(gl, 'v3', new T.Vector3(9, 9, 9));
  uniforms.setValue(gl, 'v4', [5, 6, 7, 8]);
  uniforms.setValue(gl, 'v4', [5, 6, 7, 8]);
  uniforms.setValue(gl, 'm4', new T.Matrix4().makeScale(1, 2, 3));
  uniforms.setValue(gl, 'm4', new Float32Array(16).fill(0.5));
  textures.resetTextureUnits();
  uniforms.setValue(gl, 's2d', tex, textures);
  uniforms.setValue(gl, 's2d', null, textures);
  uniforms.setValue(gl, 'texa', [tex, tex, tex], textures);
  const skinned = new T.SkinnedMesh(new T.BufferGeometry(), new T.MeshBasicMaterial());
  skinned.bindMatrix.makeTranslation(1, 0, 0);
  skinned.bindMatrixInverse.makeTranslation(-1, 0, 0);
  uniforms.setOptional(gl, skinned, 'bindMatrix');
  uniforms.setOptional(gl, skinned, 'bindMatrixInverse');
  uniforms.setOptional(gl, new T.Mesh(), 'bindMatrix');
  const subset = WebGLUniforms.seqWithValue(uniforms.seq, { f: { value: 1 }, light: { value: {} }, nothere: { value: 0 } });
  gl.__note('seqWithValue', subset.map((u) => u.id).join(' '));
  return gl.__log;
}
