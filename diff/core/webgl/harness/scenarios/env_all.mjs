// Group 3: WebGLEnvironments through WebGLRenderer: equirectangular maps converted to cube
// maps (basic materials) and to PMREMs (standard materials, scene.environment), cube maps
// to PMREMs, render-target textures regenerated on pmremVersion changes, images that are
// not ready, PMREM textures passed through, and disposal.
import { createRequire } from 'node:module';
import { g3Options } from '../group3_util.mjs';
const { createMockCanvas, mockOptions } = createRequire(import.meta.url)('./renderer_common.cjs');

export async function run({ src, createMockGL }) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const { WebGLCubeRenderTarget } = await import(src + '/renderers/WebGLCubeRenderTarget.js');
  const gl = createMockGL(g3Options(mockOptions, {}, true));
  const canvas = createMockCanvas(gl, 64, 32);
  const renderer = new WebGLRenderer({ canvas, context: gl });
  const scene = new T.Scene();
  const camera = new T.PerspectiveCamera(50, 2, 0.1, 100);
  camera.position.set(0, 0, 5);
  const frame = (label) => { gl.__log.push('## ' + label); renderer.render(scene, camera); };
  const equirect = (w, h) => { const t = new T.Texture(w ? { width: w, height: h } : undefined); t.mapping = T.EquirectangularReflectionMapping; if (w) t.needsUpdate = true; return t; };
  const cube = (n) => { const t = new T.CubeTexture([0, 1, 2, 3, 4, 5].slice(0, n).map(() => ({ width: 4, height: 4 }))); t.needsUpdate = true; return t; };
  const mesh = (material) => { const m = new T.Mesh(new T.BoxGeometry(), material); scene.add(m); return m; };

  const e1 = equirect(16, 8);
  const basic = mesh(new T.MeshBasicMaterial({ envMap: e1 }));
  frame('basic equirect');
  gl.__note('e1 mapping', e1.mapping);
  frame('basic equirect again');
  const e3 = equirect(8, 4);
  e3.mapping = T.EquirectangularRefractionMapping;
  const refract = mesh(new T.MeshBasicMaterial({ envMap: e3 }));
  frame('basic equirect refraction');
  gl.__note('e3 mapping', e3.mapping);
  const e2 = equirect(1024, 512);
  e2.mapping = T.EquirectangularRefractionMapping;
  const standard = mesh(new T.MeshStandardMaterial({ envMap: e2 }));
  frame('standard equirect');
  const c1 = cube(6);
  scene.environment = c1;
  const standard2 = mesh(new T.MeshStandardMaterial());
  frame('environment cube');
  basic.material.envMap = equirect();
  standard.material.envMap = cube(5);
  frame('not ready');
  const rt = new WebGLCubeRenderTarget(8);
  rt.texture.name = 'rtCube';
  standard.material.envMap = rt.texture;
  frame('render target texture');
  rt.texture.needsPMREMUpdate = true;
  frame('render target texture updated');
  frame('render target texture again');
  const pm = new WebGLCubeRenderTarget(4);
  pm.texture.isPMREMTexture = true;
  pm.texture.mipmaps.push({ width: 4, height: 4 }, { width: 2, height: 2 });
  standard2.material.envMap = pm.texture;
  frame('pmrem texture');
  gl.__log.push('## dispose e2');
  e2.dispose();
  gl.__log.push('## dispose e1');
  e1.dispose();
  gl.__log.push('## dispose c1');
  c1.dispose();
  scene.environment = null;
  standard.material.envMap = e2;
  frame('after dispose');
  gl.__log.push('## renderer dispose');
  renderer.dispose();
  return gl.__log;
}
