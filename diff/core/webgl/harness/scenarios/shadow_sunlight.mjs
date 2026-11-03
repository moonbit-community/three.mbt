// The SunLight addon (examples/jsm/lights/SunLight.js, SunLightShadow.js) through
// WebGLRenderer: two cascades rendered into one atlas, each with its own shadow camera,
// frustum and viewport from SunLightShadow.updateMatrices( light, camera ); a moving
// view camera, a larger filter radius (viewport inset), VSM, and an orthographic view
// camera. The addon imports 'three'; it is loaded with that specifier pointed at src.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import { G3_EXTRA_UNIFORMS } from '../group3_util.mjs';
const { createMockCanvas, mockOptions } = createRequire(import.meta.url)('./renderer_common.cjs');

// the sun light uniforms, on top of group 3's spec. Types: VEC3 0x8B51, FLOAT 0x1406,
// VEC2 0x8B50, VEC4 0x8B52, MAT4 0x8B5C, SAMPLER_2D_SHADOW 0x8B62, SAMPLER_2D 0x8B5E.
export const SUN_UNIFORMS = [
  { name: 'sunLights[0].direction', type: 0x8B51 }, { name: 'sunLights[0].color', type: 0x8B51 },
  { name: 'sunShadowMap[0]', type: 0x8B62 }, { name: 'sunShadowMatrix[0]', type: 0x8B5C, size: 2 },
  { name: 'sunShadowCascade[0]', type: 0x8B52, size: 2 },
  { name: 'sunLightShadows[0].shadowBias', type: 0x1406 }, { name: 'sunLightShadows[0].shadowMapSize', type: 0x8B50 },
];

// uniform prefixes of the lights this scene does not have (a real shader declares only
// the light structs the scene has)
export const SUN_DROP = ['directionalLights', 'directionalShadow', 'directionalLightShadows', 'pointLights', 'pointShadow',
  'spotLights', 'spotShadow', 'spotLightMatrix', 'hemisphereLights'];

async function importSunLight(src) {
  const dir = path.join(path.dirname(fileURLToPath(src)), 'examples/jsm/lights');
  const rewrite = (code) => code.replace(/from 'three'/g, `from '${src}/Three.Core.js'`);
  const dataUrl = (code) => 'data:text/javascript,' + encodeURIComponent(code).replace(/'/g, '%27');
  const shadowUrl = dataUrl(rewrite(fs.readFileSync(path.join(dir, 'SunLightShadow.js'), 'utf8')));
  const light = rewrite(fs.readFileSync(path.join(dir, 'SunLight.js'), 'utf8')).replace(`from './SunLightShadow.js'`, `from '${shadowUrl}'`);
  return (await import(dataUrl(light))).SunLight;
}

export async function run({ src, createMockGL }) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const SunLight = await importSunLight(src);
  const options = JSON.parse(mockOptions({}, SUN_DROP));
  const extra = G3_EXTRA_UNIFORMS.filter((u) => !SUN_DROP.some((d) => u.name.startsWith(d))).concat(SUN_UNIFORMS);
  options.programs = options.programs.map((p) => ({ attributes: p.attributes, uniforms: p.uniforms.concat(extra) }));
  const gl = createMockGL(options);
  const canvas = createMockCanvas(gl, 64, 32);
  const renderer = new WebGLRenderer({ canvas, context: gl });
  renderer.shadowMap.enabled = true;
  const scene = new T.Scene();
  const camera = new T.PerspectiveCamera(50, 2, 0.5, 60);
  camera.position.set(2, 5, 12);
  camera.lookAt(0, 0, 0);

  const sun = new SunLight(0xfff2e3, 3);
  sun.name = 'sun';
  sun.position.set(3, 8, 2);
  sun.castShadow = true;
  sun.shadow.mapSize.set(256, 256);
  sun.shadow.radius = 2;
  sun.shadow.camera.far = 80;
  scene.add(sun);

  const floor = new T.Mesh(new T.PlaneGeometry(80, 80), new T.MeshPhongMaterial());
  floor.rotation.x = - Math.PI / 2;
  floor.receiveShadow = true;
  scene.add(floor);
  const near = new T.Mesh(new T.BoxGeometry(1, 1, 1), new T.MeshPhongMaterial());
  near.position.set(0, 0.5, 0);
  near.castShadow = true;
  scene.add(near);
  const mid = new T.Mesh(new T.BoxGeometry(2, 2, 2), new T.MeshPhongMaterial());
  mid.position.set(6, 1, -20);
  mid.castShadow = true;
  scene.add(mid);
  const far = new T.Mesh(new T.BoxGeometry(3, 3, 3), new T.MeshPhongMaterial());
  far.position.set(-4, 1.5, -40);
  far.castShadow = true;
  scene.add(far);
  const away = new T.Mesh(new T.BoxGeometry(), new T.MeshPhongMaterial());
  away.position.set(500, 0, 0);
  away.castShadow = true;
  scene.add(away);

  const m16 = (m) => Array.from(m.elements);
  const v4 = (v) => [v.x, v.y, v.z, v.w];
  const noteSun = (label) => {
    const s = sun.shadow;
    for (let j = 0; j < 2; j++) {
      const c = s.getCamera(j);
      gl.__note(label + ' cascade ' + j, [m16(s.getMatrix(j)), v4(s._cascadeData[j]), v4(s.getViewport(j)),
        [c.left, c.right, c.top, c.bottom, c.near, c.far, c.coordinateSystem, c.reversedDepth],
        [c.position.x, c.position.y, c.position.z], [c.quaternion.x, c.quaternion.y, c.quaternion.z, c.quaternion.w]]);
    }
    gl.__note(label + ' map', s.map === null ? null : [s.map.width, s.map.height, s.mapPass === null ? null : [s.mapPass.width, s.mapPass.height]]);
  };
  const frame = (label, view) => { gl.__log.push('## ' + label); renderer.render(scene, view || camera); noteSun(label); };

  frame('first');
  camera.position.set(-3, 4, 10);
  camera.lookAt(0, 0, -5);
  frame('moved');
  sun.shadow.radius = 5;
  sun.position.set(0, 10, 0.1); // straight down: the up vector switches to +z
  frame('radius');
  renderer.shadowMap.type = T.VSMShadowMap;
  frame('vsm');
  renderer.shadowMap.type = T.PCFShadowMap;
  const ortho = new T.OrthographicCamera(-10, 10, 5, -5, 1, 50);
  ortho.position.set(0, 6, 15);
  ortho.lookAt(0, 0, 0);
  frame('ortho', ortho);
  renderer.dispose();
  return gl.__log;
}
