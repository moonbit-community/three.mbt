import { noteLightState, ser } from '../group3_util.mjs';

export async function run({ src, createMockGL }) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLExtensions } = await import(src + '/renderers/webgl/WebGLExtensions.js');
  const { WebGLLights } = await import(src + '/renderers/webgl/WebGLLights.js');
  const { UniformsLib } = await import(src + '/renderers/shaders/UniformsLib.js');
  const ltc = (name) => { const t = new T.Texture(); t.name = name; return t; };
  UniformsLib.LTC_FLOAT_1 = ltc('ltc_float_1');
  UniformsLib.LTC_FLOAT_2 = ltc('ltc_float_2');
  UniformsLib.LTC_HALF_1 = ltc('ltc_half_1');
  UniformsLib.LTC_HALF_2 = ltc('ltc_half_2');
  const gl = createMockGL({});
  const lights = new WebGLLights(new WebGLExtensions(gl));
  const camera = new T.PerspectiveCamera(60, 1.5, 0.5, 50);
  camera.position.set(3, 4, 5);
  camera.lookAt(0, 1, 0);
  camera.updateMatrixWorld();
  const place = (light, x, y, z, tx, ty, tz) => {
    light.position.set(x, y, z);
    light.updateMatrixWorld();
    if (light.target) { light.target.position.set(tx, ty, tz); light.target.updateMatrixWorld(); }
    return light;
  };
  const named = (light, name) => { light.name = name; return light; };
  const ambient1 = named(new T.AmbientLight(new T.Color(0.2, 0.3, 0.4), 0.5), 'ambient1');
  const ambient2 = named(new T.AmbientLight(new T.Color(1, 0.5, 0.25), 2), 'ambient2');
  const sh = new T.SphericalHarmonics3();
  for (let i = 0; i < 9; i ++) sh.coefficients[i].set(i * 0.1, - i * 0.05, 0.3 + i);
  const probe = named(new T.LightProbe(sh, 0.7), 'probe');
  const hemi = named(place(new T.HemisphereLight(new T.Color(0.9, 0.8, 0.7), new T.Color(0.1, 0.2, 0.3), 1.3), 0, 10, 2), 'hemi');
  const dir1 = named(place(new T.DirectionalLight(new T.Color(1, 0.9, 0.8), 1.5), 5, 10, 7, 1, 0, - 1), 'dir1');
  dir1.castShadow = true;
  dir1.shadow.bias = - 0.001; dir1.shadow.normalBias = 0.02; dir1.shadow.radius = 3; dir1.shadow.intensity = 0.8;
  dir1.shadow.mapSize.set(1024, 512);
  dir1.shadow.map = new T.RenderTarget(16, 16);
  dir1.shadow.map.texture.name = 'dir1.color';
  dir1.shadow.map.depthTexture = new T.DepthTexture(16, 16);
  dir1.shadow.map.depthTexture.name = 'dir1.depth';
  const dir2 = named(place(new T.DirectionalLight(0xff8800, 0.25), - 3, 2, 1, 0, 0, 0), 'dir2');
  const point1 = named(place(new T.PointLight(new T.Color(0.5, 1, 0.5), 3, 20, 1.5), 1, 2, 3), 'point1');
  point1.castShadow = true;
  point1.shadow.camera.near = 0.25; point1.shadow.camera.far = 30;
  point1.shadow.map = new T.RenderTarget(8, 8);
  point1.shadow.map.texture.name = 'point1.vsm';
  point1.shadow.map.texture.format = T.RGFormat;
  const point2 = named(place(new T.PointLight(0x2244ff, 1), - 1, 0.5, - 2), 'point2');
  const spotMap = new T.Texture(); spotMap.name = 'spotMap';
  const spot1 = named(place(new T.SpotLight(0xffffff, 2, 15, Math.PI / 5, 0.3, 2), 0, 6, 0, 0, 0, 0.5), 'spot1');
  spot1.map = spotMap; spot1.castShadow = true;
  spot1.shadow.map = new T.RenderTarget(4, 4);
  spot1.shadow.map.texture.name = 'spot1.color';
  const spot2 = named(place(new T.SpotLight(0xff0000, 1, 0, Math.PI / 3, 0.5, 1), 2, 3, - 4, 1, 0, 0), 'spot2');
  spot2.map = spotMap;
  const spot3 = named(place(new T.SpotLight(0x00ff00, 1.2, 8, 0.4, 0, 2), - 2, 5, 1, 0, 1, 0), 'spot3');
  spot3.castShadow = true;
  const spot4 = named(place(new T.SpotLight(0x0000ff, 0.6), 4, 4, 4, - 1, - 1, - 1), 'spot4');
  const rect1 = named(place(new T.RectAreaLight(0xffeedd, 4, 3, 2), 0, 3, - 5), 'rect1');
  rect1.rotation.set(0.3, - 0.4, 0.2); rect1.updateMatrixWorld();
  const rect2 = named(place(new T.RectAreaLight(0x88ccff, 1, 1, 6), 2, 1, 0), 'rect2');
  const sun = named(place(new T.DirectionalLight(new T.Color(1, 1, 0.9), 2.5), 30, 50, 20, 0, 0, 0), 'sun');
  sun.type = 'SunLight';
  sun.isSunLight = true;
  sun.castShadow = true;
  sun.shadow._viewportCount = 2;
  sun.shadow._frameExtents = new T.Vector2(2, 1);
  sun.shadow.mapSize.set(256, 256);
  const sunMatrices = [new T.Matrix4().makeTranslation(1, 2, 3), new T.Matrix4().makeScale(2, 3, 4)];
  const sunCascades = [new T.Vector4(0, 10, 0, 0), new T.Vector4(10, 40, 0, 0)];
  sun.shadow.getMatrix = (j) => sunMatrices[j];
  sun.shadow._cascadeData = sunCascades;
  const all = [ambient1, spot4, dir2, probe, hemi, point2, spot3, rect1, dir1, spot2, point1, spot1, rect2, ambient2, sun];
  const names = (arr) => arr.map((l) => l.name);

  lights.setup(all);
  const v0 = lights.state.version;
  gl.__note('sorted', names(all));
  noteLightState(gl, 'setup', lights.state, v0);
  lights.setupView(all, camera);
  noteLightState(gl, 'view', lights.state, v0);
  const directionalArray = lights.state.directional;
  const firstDirectional = lights.state.directional[0];

  // same lights again: no hash change
  dir1.intensity = 0.5; hemi.color.setRGB(0.1, 0.1, 0.1); spot1.angle = 0.2; point1.distance = 0;
  dir1.shadow.mapSize.set(64, 64); sun.shadow._frameExtents.set(1, 3);
  lights.setup(all);
  noteLightState(gl, 'again', lights.state, v0);
  gl.__note('shared', [lights.state.directional === directionalArray, lights.state.directional[0] === firstDirectional]);

  // fewer lights: the hash changes and the arrays shrink in place
  const fewer = [spot2, rect1, dir2, point1, probe];
  point1.castShadow = false;
  lights.setup(fewer);
  gl.__note('sorted fewer', names(fewer));
  noteLightState(gl, 'fewer', lights.state, v0);
  lights.setupView(fewer, camera);
  noteLightState(gl, 'fewer view', lights.state, v0);
  gl.__note('shared fewer', [lights.state.directional === directionalArray]);
  lights.setup(fewer);
  gl.__note('version same', lights.state.version - v0);

  // no lights
  lights.setup([]);
  noteLightState(gl, 'none', lights.state, v0);

  // half-float LTC without OES_texture_float_linear
  const gl2 = createMockGL({ extensions: ['EXT_color_buffer_float'] });
  const lights2 = new WebGLLights(new WebGLExtensions(gl2));
  lights2.setup([rect2, ambient1]);
  noteLightState(gl, 'half', lights2.state, v0);
  for (const entry of gl2.__log) gl.__log.push('gl2 ' + entry);
  gl.__note('ser check', ser(lights2.state.hemi));
  return gl.__log;
}
