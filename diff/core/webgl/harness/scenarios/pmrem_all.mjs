// Group 3: PMREMGenerator driven directly on a WebGLRenderer: shader precompilation,
// equirectangular and cube map inputs, reusing a target, fromScene with and without
// blur, sizes and dispose.
import { createRequire } from 'node:module';
import { g3Options } from '../group3_util.mjs';
const { createMockCanvas, mockOptions } = createRequire(import.meta.url)('./renderer_common.cjs');

export async function run({ src, createMockGL }) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const { PMREMGenerator } = await import(src + '/extras/PMREMGenerator.js');
  const gl = createMockGL(g3Options(mockOptions, {}, true));
  const canvas = createMockCanvas(gl, 64, 32);
  const renderer = new WebGLRenderer({ canvas, context: gl });
  const describe = (t) => [t.width, t.height, t.texture.name, t.texture.isPMREMTexture === true, t.texture.mipmaps.map((m) => m.width), t.texture.type, t.texture.colorSpace, t.texture.minFilter, t.texture.generateMipmaps, t.depthBuffer];
  gl.__note('lodToRoughness', [PMREMGenerator.lodToRoughness(0, 5), PMREMGenerator.lodToRoughness(2, 5), PMREMGenerator.lodToRoughness(5, 5), PMREMGenerator.lodToRoughness(1, 0)]);
  const pmrem = new PMREMGenerator(renderer);
  gl.__log.push('## compile');
  pmrem.compileEquirectangularShader();
  pmrem.compileCubemapShader();
  pmrem.compileCubemapShader();
  const equirect = new T.Texture({ width: 2048, height: 1024 });
  equirect.mapping = T.EquirectangularReflectionMapping;
  equirect.needsUpdate = true;
  gl.__log.push('## equirect');
  const t1 = pmrem.fromEquirectangular(equirect);
  gl.__note('t1', describe(t1));
  const cube = new T.CubeTexture([0, 1, 2, 3, 4, 5].map(() => ({ width: 64, height: 64 })));
  cube.needsUpdate = true;
  gl.__log.push('## cube');
  const t2 = pmrem.fromCubemap(cube);
  gl.__note('t2', describe(t2));
  gl.__log.push('## cube reuse');
  const t3 = pmrem.fromCubemap(cube, t2);
  gl.__note('t3 same', t3 === t2);
  const scene = new T.Scene();
  scene.add(new T.Mesh(new T.BoxGeometry(), new T.MeshBasicMaterial({ color: 0x804020 })));
  renderer.setClearColor(0x102030);
  gl.__log.push('## scene blur');
  const t4 = pmrem.fromScene(scene, 0.04, 0.1, 100, { size: 128, position: new T.Vector3(1, 2, 3) });
  gl.__note('t4', describe(t4));
  gl.__note('scene background', scene.background);
  scene.background = new T.Color(0.5, 0.25, 0.125);
  gl.__log.push('## scene sharp');
  const t5 = pmrem.fromScene(scene, 0, 0.5, 50, { size: 300 });
  gl.__note('t5', describe(t5));
  gl.__note('autoClear', [renderer.autoClear, renderer.autoClearColor, renderer.autoClearDepth, renderer.autoClearStencil]);
  gl.__log.push('## dispose');
  pmrem.dispose();
  return gl.__log;
}
