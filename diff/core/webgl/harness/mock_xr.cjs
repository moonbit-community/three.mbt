// A recording mock of the WebXR Device API and WebXR Layers, for the xr_* scenarios.
// Every method call on a session, frame, binding or layer, every `fixedFoveation` write
// and `gl.makeXRCompatible()` are pushed onto `gl.__log`. Poses are fixed functions of
// the frame index, built as Float32Arrays like a real runtime's. The same source runs
// under upstream (harness/scenarios/xr_*.mjs) and under MoonBit
// (src/renderers/webgl/webxr_manager_test.mbt embeds it: `node mock_xr.cjs --print-moonbit`).
//
// options = {
//   binding: false            no global XRWebGLBinding (default: installed)
//   layers: true              XRWebGLBinding.prototype.createProjectionLayer exists
//   baseLayerFoveation: true  XRWebGLLayer has `fixedFoveation`
//   framebuffer: { width, height }   XRWebGLLayer size (default 128x64)
//   texture: { width, height }       XRProjectionLayer size (default 128x64)
//   ignoreDepthValues: bool   on both layer kinds (default false)
//   environmentBlendMode, enabledFeatures, depthUsage: the session's values
//   depth: { near, far, from }       getDepthInformation is valid from frame `from`
//   cameraAccess: true        views carry an XRCamera
//   viewCounts: [ n per frame ]      views per frame (default 2)
//   nullPoseFrames, planeFrames, blurredFrames: frame indices with no viewer pose,
//                             with detectedPlanes, with visibilityState 'visible-blurred'
//   inputSources: [ { handedness, grip, hand } ]
// }
const MOCK_XR = function () {
  const JOINTS = ['wrist', 'thumb-tip', 'index-finger-tip'];
  // index-tip to thumb-tip distance per frame: pinch starts at 1, holds at 2 (between the
  // start and end thresholds), ends at 3, restarts at 4, ends at 5, restarts at 6
  const PINCH = [0.05, 0.01, 0.02, 0.03, 0.008, 0.04, 0.012, 0.01];

  function norm(v) {
    if (v === null) return null;
    if (v === undefined) return 'undefined';
    if (typeof v === 'number' || typeof v === 'boolean' || typeof v === 'string') return v;
    if (typeof v === 'function') return 'function';
    if (v.__mock) return v.__mock + '#' + v.__id;
    if (typeof v.getContextAttributes === 'function') return 'gl';
    if (ArrayBuffer.isView(v)) return { [v.constructor.name]: Array.from(v) };
    if (Array.isArray(v)) return v.map(norm);
    const o = {};
    for (const k of Object.keys(v).sort()) o[k] = norm(v[k]);
    return o;
  }

  function translation(x, y, z, angle) {
    const c = Math.cos(angle || 0);
    const s = Math.sin(angle || 0);
    return new Float32Array([c, 0, -s, 0, 0, 1, 0, 0, s, 0, c, 0, x, y, z, 1]);
  }

  function createMockXR(gl, options) {
    options = options || {};
    const log = gl.__log;
    const counters = {};
    function handle(kind, extra) {
      counters[kind] = (counters[kind] || 0) + 1;
      return Object.assign({ __mock: kind, __id: counters[kind] }, extra || {});
    }
    function rec(name, args) {
      log.push('xr.' + name + '(' + Array.from(args).map((a) => JSON.stringify(norm(a))).join(', ') + ')');
    }
    const has = (list, f) => (list || []).indexOf(f) !== -1;

    gl.makeXRCompatible = function () { log.push('gl.makeXRCompatible()'); return Promise.resolve(); };

    // session
    const listeners = {};
    let nextFrameId = 1;
    let pending = [];
    let frameIndex = -1;
    const renderState = { depthNear: 0.1, depthFar: 1000, inlineVerticalFieldOfView: null, baseLayer: null, layers: [] };
    const session = {
      __mock: 'XRSession', __id: 1,
      environmentBlendMode: options.environmentBlendMode || 'opaque',
      enabledFeatures: options.enabledFeatures,
      depthUsage: options.depthUsage,
      visibilityState: 'visible',
      renderState,
      addEventListener(type, l) { rec('session.addEventListener', [type]); (listeners[type] = listeners[type] || []).push(l); },
      removeEventListener(type, l) {
        const a = listeners[type] || [];
        const i = a.indexOf(l);
        if (i !== -1) a.splice(i, 1);
        rec('session.removeEventListener', [type, i !== -1]);
      },
      updateRenderState(init) { rec('session.updateRenderState', [init]); Object.assign(renderState, init); },
      requestReferenceSpace(type) { rec('session.requestReferenceSpace', [type]); return Promise.resolve(handle('XRReferenceSpace', { type })); },
      requestAnimationFrame(callback) { const id = nextFrameId++; pending.push({ id, callback }); log.push('xr.session.requestAnimationFrame() -> ' + id); return id; },
      cancelAnimationFrame(id) { rec('session.cancelAnimationFrame', [id]); pending = pending.filter((p) => p.id !== id); },
      end() { rec('session.end', []); dispatch('end', { type: 'end', session }); },
    };
    function dispatch(type, event) {
      for (const l of (listeners[type] || []).slice()) l(event);
    }

    // input sources
    const inputSources = (options.inputSources || []).map((spec, n) => {
      const source = handle('XRInputSource', { handedness: spec.handedness || 'none', targetRaySpace: handle('XRSpace', { __role: 'ray' + n }) });
      if (spec.grip) source.gripSpace = handle('XRSpace', { __role: 'grip' + n });
      if (spec.hand) {
        const hand = new Map();
        for (const name of JOINTS) hand.set(name, handle('XRJointSpace', { jointName: name }));
        hand.__mock = 'XRHand';
        hand.__id = n;
        source.hand = hand;
      }
      source.__index = n;
      return source;
    });

    // views, rebuilt per frame
    const cameras = [handle('XRCamera'), handle('XRCamera')];
    const fb = options.framebuffer || { width: 128, height: 64 };
    const tex = options.texture || { width: 128, height: 64 };
    function makeViews(f) {
      const count = (options.viewCounts && options.viewCounts[f] !== undefined) ? options.viewCounts[f] : 2;
      const views = [];
      for (let i = 0; i < count; i++) {
        const near = 0.1;
        const projectionMatrix = new Float32Array([1.2 + 0.01 * i, 0, 0, 0, 0, 2.4, 0, 0, 0.05 * (i ? -1 : 1), 0, -1.0002, -1, 0, 0, -0.20002 * near * 10, 0]);
        const view = handle('XRView', {
          eye: count === 1 ? 'none' : (i === 0 ? 'left' : 'right'),
          projectionMatrix,
          transform: { matrix: translation(-0.032 + 0.064 * i + 0.01 * f, 1.6, 0.25 - 0.02 * f, 0.05 * f) },
        });
        view.__viewport = { x: (i * fb.width) / count, y: 0, width: fb.width / count, height: fb.height };
        view.__subViewport = { x: (i * tex.width) / count, y: 0, width: tex.width / count, height: tex.height };
        if (options.cameraAccess) view.camera = cameras[i];
        views.push(view);
      }
      return views;
    }

    function makeFrame(f, label) {
      const blurred = has(options.blurredFrames, f);
      const frameSession = blurred ? Object.assign(Object.create(session), { visibilityState: 'visible-blurred' }) : session;
      const views = makeViews(f);
      const frame = handle('XRFrame', {
        session: frameSession,
        getViewerPose(space) {
          rec('frame.getViewerPose', [space]);
          if (has(options.nullPoseFrames, f)) return null;
          return { transform: { matrix: translation(0.01 * f, 1.6, 0.25 - 0.02 * f, 0.05 * f) }, views };
        },
        getPose(space, base) {
          rec('frame.getPose', [space, base]);
          const role = space.__role;
          const n = Number(role.slice(-1));
          const isRay = role.startsWith('ray');
          if (isRay && n === 0 && f === 2) return null; // ray pose missing: falls back to grip
          if (!isRay && f === 3) return null; // grip pose missing
          const pose = { transform: { matrix: translation(0.2 * (n ? 1 : -1) + 0.005 * f, 1.1 + (isRay ? 0.02 : 0), -0.3 - 0.01 * f, 0.1 * f + n) } };
          if (f % 2 === 1) pose.linearVelocity = { x: 0.1 * f, y: -0.2, z: 0.05, w: 0 };
          if (f % 2 === 0) pose.angularVelocity = { x: 0, y: 0.3 * f, z: -0.1, w: 0 };
          return pose;
        },
        getJointPose(joint, base) {
          rec('frame.getJointPose', [joint, base]);
          const name = joint.jointName;
          if (name === 'wrist' && f === 5) return null;
          const d = PINCH[f % PINCH.length];
          const x = name === 'index-finger-tip' ? 0.3 + d : (name === 'thumb-tip' ? 0.3 : 0.25);
          return { transform: { matrix: translation(x, 1.2, -0.25, 0) }, radius: name === 'wrist' ? 0.02 : 0.008 };
        },
      });
      if (has(options.planeFrames, f)) frame.detectedPlanes = new Set();
      frame.__label = label;
      return frame;
    }

    // layers and binding
    function projectionLayer(init) {
      const layer = handle('XRProjectionLayer', { textureWidth: tex.width, textureHeight: tex.height, ignoreDepthValues: options.ignoreDepthValues === true });
      Object.defineProperty(layer, 'fixedFoveation', { get() { return this.__foveation; }, set(v) { this.__foveation = v; log.push('xr.' + norm(layer) + '.fixedFoveation = ' + JSON.stringify(v)); } });
      return layer;
    }
    class XRWebGLLayer {
      constructor(s, context, init) {
        rec('new XRWebGLLayer', [s, context, init]);
        Object.assign(this, handle('XRWebGLLayer'));
        this.framebufferWidth = fb.width;
        this.framebufferHeight = fb.height;
        this.framebuffer = handle('XRFramebuffer');
        this.ignoreDepthValues = options.ignoreDepthValues === true;
        if (options.baseLayerFoveation) {
          const self = this;
          Object.defineProperty(this, 'fixedFoveation', { get() { return self.__foveation === undefined ? 0 : self.__foveation; }, set(v) { self.__foveation = v; log.push('xr.' + norm(self) + '.fixedFoveation = ' + JSON.stringify(v)); } });
        }
      }
      getViewport(view) { rec(norm(this) + '.getViewport', [view]); return view.__viewport; }
    }
    const depthTexture = handle('XRDepthTexture');
    class XRWebGLBinding {
      constructor(s, context) { rec('new XRWebGLBinding', [s, context]); Object.assign(this, handle('XRWebGLBinding')); }
      getViewSubImage(layer, view) {
        rec('binding.getViewSubImage', [layer, view]);
        return { viewport: view.__subViewport, colorTexture: handle('XRColorTexture'), depthStencilTexture: handle('XRDepthStencilTexture') };
      }
      getDepthInformation(view) {
        rec('binding.getDepthInformation', [view]);
        const d = options.depth;
        if (!d || frameIndex < (d.from || 0)) return null;
        return { isValid: true, texture: depthTexture, depthNear: d.near, depthFar: d.far, width: 4, height: 4 };
      }
      getCameraImage(camera) { rec('binding.getCameraImage', [camera]); return handle('XRCameraImage'); }
    }
    if (options.layers) {
      XRWebGLBinding.prototype.createProjectionLayer = function (init) { rec('binding.createProjectionLayer', [init]); return projectionLayer(init); };
    }

    const saved = {};
    return {
      session,
      inputSources,
      cameras,
      customSpace: handle('XRReferenceSpace', { type: 'custom' }),
      install() {
        for (const k of ['XRWebGLBinding', 'XRWebGLLayer']) saved[k] = Object.getOwnPropertyDescriptor(globalThis, k);
        globalThis.XRWebGLLayer = XRWebGLLayer;
        if (options.binding !== false) globalThis.XRWebGLBinding = XRWebGLBinding;
        else delete globalThis.XRWebGLBinding;
      },
      uninstall() {
        for (const k of ['XRWebGLBinding', 'XRWebGLLayer']) {
          if (saved[k]) Object.defineProperty(globalThis, k, saved[k]);
          else delete globalThis[k];
        }
      },
      // runs the pending XR animation frames with the next frame index
      tick(time) {
        frameIndex++;
        const frame = makeFrame(frameIndex, 'raf');
        log.push('## xr tick ' + frameIndex);
        const run = pending;
        pending = [];
        for (const p of run) p.callback(time, frame);
      },
      // a select/squeeze event of input source `n`, with its own frame
      fire(type, n) {
        log.push('## xr event ' + type + ' ' + n);
        dispatch(type, { type, inputSource: inputSources[n], frame: makeFrame(Math.max(frameIndex, 0), 'event') });
      },
      changeInputSources(added, removed) {
        log.push('## xr inputsourceschange +' + JSON.stringify(added) + ' -' + JSON.stringify(removed));
        dispatch('inputsourceschange', { type: 'inputsourceschange', session, added: added.map((n) => inputSources[n]), removed: removed.map((n) => inputSources[n]) });
      },
      end() { session.end(); },
      norm,
    };
  }
  return { createMockXR };
};

if (typeof module !== 'undefined') {
  module.exports = MOCK_XR();
  if (require.main === module && process.argv.includes('--print-moonbit')) {
    for (const line of ('(' + MOCK_XR.toString() + ')()').split('\n')) console.log('  #|' + line);
  }
}
