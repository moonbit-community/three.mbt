// The steps shared by the xr_* scenarios: a WebGLRenderer with WebXR enabled, a session
// from mock_xr.cjs started, several frames with controllers, hands, input source
// changes and select/squeeze events, then the session ended. `config` picks the mock
// options and a few manager settings. The MoonBit side is `xr_run` in
// src/renderers/webgl/webxr_manager_test.mbt; keep the two step for step.
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { createMockCanvas, mockOptions } = require('./scenarios/renderer_common.cjs');
const { createMockXR } = require('./mock_xr.cjs');

// the depth sensing occlusion material's uniforms, on top of renderer_common's spec
export const XR_UNIFORMS = [
  { name: 'depthColor', type: 0x8DC1 }, { name: 'depthWidth', type: 0x1406 }, { name: 'depthHeight', type: 0x1406 },
];

const EVENTS = ['connected', 'disconnected', 'move', 'select', 'selectstart', 'selectend', 'squeeze',
  'squeezestart', 'squeezeend', 'pinchstart', 'pinchend', 'gripUpdated'];

const m16 = (m) => Array.from(m.elements);
const v3 = (v) => [v.x, v.y, v.z];

export async function runXR({ src, createMockGL }, config) {
  const T = await import(src + '/Three.Core.js');
  const { WebGLRenderer } = await import(src + '/renderers/WebGLRenderer.js');
  const options = JSON.parse(mockOptions(config.gl || {}));
  options.programs = options.programs.map((p) => ({ attributes: p.attributes, uniforms: p.uniforms.concat(XR_UNIFORMS) }));
  const gl = createMockGL(options);
  const xr = createMockXR(gl, config.xr);
  const norm = xr.norm;
  xr.install();
  const canvas = createMockCanvas(gl, 64, 32);
  const renderer = new WebGLRenderer({ canvas, context: gl });
  const manager = renderer.xr;
  manager.enabled = true;
  if (config.scale !== undefined) manager.setFramebufferScaleFactor(config.scale);
  if (config.referenceSpaceType !== undefined) manager.setReferenceSpaceType(config.referenceSpaceType);
  if (config.foveation !== undefined) manager.setFoveation(config.foveation);
  const size = () => { const s = renderer.getSize(new T.Vector2()); return [s.x, s.y, renderer.getPixelRatio()]; };
  const statusOf = () => ([manager.isPresenting, manager.getFoveation(), manager.getEnvironmentBlendMode(),
    norm(manager.getSession()), norm(manager.getBaseLayer()), norm(manager.getReferenceSpace()), norm(manager.getFrame()),
    manager.hasDepthSensing(), manager.getDepthTexture() === null, manager.getDepthSensingMesh() === null].concat(size()));
  const status = (label) => gl.__note(label, statusOf());
  // noted after setSession (both sides now read the context attributes in the
  // WebXRManager constructor; the note stays where it was so the logs keep their order)
  const before = statusOf();

  const scene = new T.Scene();
  if (config.background !== undefined) scene.background = new T.Color(config.background);
  const box = new T.Mesh(new T.BoxGeometry(), new T.MeshBasicMaterial());
  box.position.set(0, 1.5, -1);
  scene.add(box);
  const camera = new T.PerspectiveCamera(50, 2, 0.1, 100);
  camera.position.set(0, 1.6, 3);
  if (config.rig) {
    const rig = new T.Group();
    rig.position.set(1, 0, 2);
    rig.rotation.y = 0.3;
    rig.add(camera);
    scene.add(rig);
  }

  const spaces = [['ray0', manager.getController(0)], ['grip0', manager.getControllerGrip(0)], ['hand1', manager.getHand(1)],
    ['ray1', manager.getController(1)], ['grip1', manager.getControllerGrip(1)]];
  spaces[1][1].eventsEnabled = true;
  const watch = (name, group) => {
    scene.add(group);
    for (const type of EVENTS) {
      group.addEventListener(type, (e) => gl.__note('event ' + name + ' ' + e.type, e.handedness !== undefined ? e.handedness : norm(e.data)));
    }
  };
  for (const [name, group] of spaces) watch(name, group);
  manager.addEventListener('sessionstart', () => gl.__note('sessionstart', [manager.isPresenting].concat(size())));
  manager.addEventListener('sessionend', () => gl.__note('sessionend', [manager.isPresenting].concat(size())));
  manager.addEventListener('planesdetected', (e) => gl.__note('planesdetected', norm(e.data)));

  const noteRig = (label) => {
    const xrCamera = manager.getCamera();
    gl.__note(label + ' cameraXR', [xrCamera.cameras.length, xrCamera.layers.mask, xrCamera.near, xrCamera.far, m16(xrCamera.matrixWorld), m16(xrCamera.projectionMatrix)]);
    xrCamera.cameras.forEach((c, i) => gl.__note(label + ' view ' + i, [c.layers.mask, c.near, c.far, m16(c.matrixWorld), m16(c.matrixWorldInverse), m16(c.projectionMatrix), [c.viewport.x, c.viewport.y, c.viewport.z, c.viewport.w]]));
    gl.__note(label + ' user camera', v3(camera.position).concat([camera.quaternion.x, camera.quaternion.y, camera.quaternion.z, camera.quaternion.w, camera.fov, camera.zoom], m16(camera.matrixWorld), m16(camera.projectionMatrix)));
    for (const [name, group] of spaces) {
      if (group.joints !== undefined) {
        gl.__note(label + ' ' + name, [group.visible, group.inputState.pinching].concat(Object.keys(group.joints).map((k) => {
          const j = group.joints[k];
          return [k, j.visible, j.jointRadius].concat(v3(j.position));
        })));
      } else {
        gl.__note(label + ' ' + name, [group.visible, group.hasLinearVelocity, v3(group.linearVelocity), group.hasAngularVelocity, v3(group.angularVelocity), m16(group.matrix)]);
      }
    }
    const depth = manager.getDepthTexture();
    gl.__note(label + ' depth', [manager.hasDepthSensing(), depth === null ? null : norm(depth.sourceTexture), manager.getDepthSensingMesh() === null]);
    const cameraTexture = manager.getCameraTexture(xr.cameras[0]);
    gl.__note(label + ' camera texture', cameraTexture === undefined ? 'undefined' : norm(cameraTexture.sourceTexture));
    const target = renderer.getRenderTarget();
    gl.__note(label + ' target', target === null ? null : [target.width, target.height, target.samples, target.stencilBuffer,
      target.resolveDepthBuffer, target.resolveStencilBuffer, target.storeMultisampledDepthBuffer, target.isXRRenderTarget === true,
      target.texture.colorSpace, target.depthTexture === null ? null : [target.depthTexture.format, target.depthTexture.type]]);
  };

  renderer.setAnimationLoop((time, frame) => {
    gl.__log.push('## loop ' + time);
    gl.__note('loop frame', [norm(frame), manager.getFrame() === frame]);
    renderer.render(scene, camera);
    noteRig('frame ' + time);
  });

  await manager.setSession(xr.session);
  gl.__note('before', before);
  status('after setSession');
  gl.__note('binding', norm(manager.getBinding()));

  xr.changeInputSources([0, 1, 2], []);
  xr.changeInputSources([2, 1], []); // no free controller for 2: stops before re-adding 1
  // a controller created after the input sources: its slot stays `undefined`, so frames
  // update it without a source and the session end disconnects `undefined`
  spaces.push(['ray2', manager.getController(2)]);
  watch('ray2', spaces[5][1]);
  xr.tick(1000);
  xr.fire('selectstart', 0);
  xr.fire('select', 0);
  xr.fire('selectend', 0);
  xr.fire('squeezestart', 1);
  xr.fire('squeeze', 1);
  xr.fire('squeezeend', 1);
  xr.fire('select', 2); // not assigned to a controller
  xr.tick(1016);
  xr.tick(1033);
  xr.changeInputSources([], [0]);
  xr.tick(1050);
  xr.changeInputSources([2], []); // takes the free controller 0
  xr.tick(1066);
  xr.tick(1083);
  manager.setFoveation(0.5);
  gl.__note('foveation', manager.getFoveation());
  manager.setReferenceSpace(xr.customSpace);
  xr.tick(1100);
  manager.cameraAutoUpdate = false;
  xr.tick(1116);
  manager.updateCamera(camera);
  noteRig('manual');
  manager.cameraAutoUpdate = true;
  renderer.setAnimationLoop(null);
  xr.tick(1133);
  xr.end();
  status('after end');
  noteRig('after end');
  renderer.render(scene, camera);
  manager.setSession(null);
  xr.uninstall();
  renderer.dispose();
  return gl.__log;
}
