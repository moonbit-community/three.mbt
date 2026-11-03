// WebXR differential scenarios (xr_layers, xr_webgl_layer, xr_no_binding, xr_additive,
// xr_alpha_blend): WebXRManager,
// WebXRController and WebXRDepthSensing driven through a recording mock XR runtime, step
// for step as harness/xr_util.mjs in the diff/core/webgl harness. The mock is
// harness/mock_xr.cjs, embedded below verbatim (`node harness/mock_xr.cjs --print-moonbit`).

///|
extern "js" fn ffi_xr_mock_module() -> @core.JsValue =
  #|() =>
  #|(function () {
  #|  const JOINTS = ['wrist', 'thumb-tip', 'index-finger-tip'];
  #|  // index-tip to thumb-tip distance per frame: pinch starts at 1, holds at 2 (between the
  #|  // start and end thresholds), ends at 3, restarts at 4, ends at 5, restarts at 6
  #|  const PINCH = [0.05, 0.01, 0.02, 0.03, 0.008, 0.04, 0.012, 0.01];
  #|
  #|  function norm(v) {
  #|    if (v === null) return null;
  #|    if (v === undefined) return 'undefined';
  #|    if (typeof v === 'number' || typeof v === 'boolean' || typeof v === 'string') return v;
  #|    if (typeof v === 'function') return 'function';
  #|    if (v.__mock) return v.__mock + '#' + v.__id;
  #|    if (typeof v.getContextAttributes === 'function') return 'gl';
  #|    if (ArrayBuffer.isView(v)) return { [v.constructor.name]: Array.from(v) };
  #|    if (Array.isArray(v)) return v.map(norm);
  #|    const o = {};
  #|    for (const k of Object.keys(v).sort()) o[k] = norm(v[k]);
  #|    return o;
  #|  }
  #|
  #|  function translation(x, y, z, angle) {
  #|    const c = Math.cos(angle || 0);
  #|    const s = Math.sin(angle || 0);
  #|    return new Float32Array([c, 0, -s, 0, 0, 1, 0, 0, s, 0, c, 0, x, y, z, 1]);
  #|  }
  #|
  #|  function createMockXR(gl, options) {
  #|    options = options || {};
  #|    const log = gl.__log;
  #|    const counters = {};
  #|    function handle(kind, extra) {
  #|      counters[kind] = (counters[kind] || 0) + 1;
  #|      return Object.assign({ __mock: kind, __id: counters[kind] }, extra || {});
  #|    }
  #|    function rec(name, args) {
  #|      log.push('xr.' + name + '(' + Array.from(args).map((a) => JSON.stringify(norm(a))).join(', ') + ')');
  #|    }
  #|    const has = (list, f) => (list || []).indexOf(f) !== -1;
  #|
  #|    gl.makeXRCompatible = function () { log.push('gl.makeXRCompatible()'); return Promise.resolve(); };
  #|
  #|    // session
  #|    const listeners = {};
  #|    let nextFrameId = 1;
  #|    let pending = [];
  #|    let frameIndex = -1;
  #|    const renderState = { depthNear: 0.1, depthFar: 1000, inlineVerticalFieldOfView: null, baseLayer: null, layers: [] };
  #|    const session = {
  #|      __mock: 'XRSession', __id: 1,
  #|      environmentBlendMode: options.environmentBlendMode || 'opaque',
  #|      enabledFeatures: options.enabledFeatures,
  #|      depthUsage: options.depthUsage,
  #|      visibilityState: 'visible',
  #|      renderState,
  #|      addEventListener(type, l) { rec('session.addEventListener', [type]); (listeners[type] = listeners[type] || []).push(l); },
  #|      removeEventListener(type, l) {
  #|        const a = listeners[type] || [];
  #|        const i = a.indexOf(l);
  #|        if (i !== -1) a.splice(i, 1);
  #|        rec('session.removeEventListener', [type, i !== -1]);
  #|      },
  #|      updateRenderState(init) { rec('session.updateRenderState', [init]); Object.assign(renderState, init); },
  #|      requestReferenceSpace(type) { rec('session.requestReferenceSpace', [type]); return Promise.resolve(handle('XRReferenceSpace', { type })); },
  #|      requestAnimationFrame(callback) { const id = nextFrameId++; pending.push({ id, callback }); log.push('xr.session.requestAnimationFrame() -> ' + id); return id; },
  #|      cancelAnimationFrame(id) { rec('session.cancelAnimationFrame', [id]); pending = pending.filter((p) => p.id !== id); },
  #|      end() { rec('session.end', []); dispatch('end', { type: 'end', session }); },
  #|    };
  #|    function dispatch(type, event) {
  #|      for (const l of (listeners[type] || []).slice()) l(event);
  #|    }
  #|
  #|    // input sources
  #|    const inputSources = (options.inputSources || []).map((spec, n) => {
  #|      const source = handle('XRInputSource', { handedness: spec.handedness || 'none', targetRaySpace: handle('XRSpace', { __role: 'ray' + n }) });
  #|      if (spec.grip) source.gripSpace = handle('XRSpace', { __role: 'grip' + n });
  #|      if (spec.hand) {
  #|        const hand = new Map();
  #|        for (const name of JOINTS) hand.set(name, handle('XRJointSpace', { jointName: name }));
  #|        hand.__mock = 'XRHand';
  #|        hand.__id = n;
  #|        source.hand = hand;
  #|      }
  #|      source.__index = n;
  #|      return source;
  #|    });
  #|
  #|    // views, rebuilt per frame
  #|    const cameras = [handle('XRCamera'), handle('XRCamera')];
  #|    const fb = options.framebuffer || { width: 128, height: 64 };
  #|    const tex = options.texture || { width: 128, height: 64 };
  #|    function makeViews(f) {
  #|      const count = (options.viewCounts && options.viewCounts[f] !== undefined) ? options.viewCounts[f] : 2;
  #|      const views = [];
  #|      for (let i = 0; i < count; i++) {
  #|        const near = 0.1;
  #|        const projectionMatrix = new Float32Array([1.2 + 0.01 * i, 0, 0, 0, 0, 2.4, 0, 0, 0.05 * (i ? -1 : 1), 0, -1.0002, -1, 0, 0, -0.20002 * near * 10, 0]);
  #|        const view = handle('XRView', {
  #|          eye: count === 1 ? 'none' : (i === 0 ? 'left' : 'right'),
  #|          projectionMatrix,
  #|          transform: { matrix: translation(-0.032 + 0.064 * i + 0.01 * f, 1.6, 0.25 - 0.02 * f, 0.05 * f) },
  #|        });
  #|        view.__viewport = { x: (i * fb.width) / count, y: 0, width: fb.width / count, height: fb.height };
  #|        view.__subViewport = { x: (i * tex.width) / count, y: 0, width: tex.width / count, height: tex.height };
  #|        if (options.cameraAccess) view.camera = cameras[i];
  #|        views.push(view);
  #|      }
  #|      return views;
  #|    }
  #|
  #|    function makeFrame(f, label) {
  #|      const blurred = has(options.blurredFrames, f);
  #|      const frameSession = blurred ? Object.assign(Object.create(session), { visibilityState: 'visible-blurred' }) : session;
  #|      const views = makeViews(f);
  #|      const frame = handle('XRFrame', {
  #|        session: frameSession,
  #|        getViewerPose(space) {
  #|          rec('frame.getViewerPose', [space]);
  #|          if (has(options.nullPoseFrames, f)) return null;
  #|          return { transform: { matrix: translation(0.01 * f, 1.6, 0.25 - 0.02 * f, 0.05 * f) }, views };
  #|        },
  #|        getPose(space, base) {
  #|          rec('frame.getPose', [space, base]);
  #|          const role = space.__role;
  #|          const n = Number(role.slice(-1));
  #|          const isRay = role.startsWith('ray');
  #|          if (isRay && n === 0 && f === 2) return null; // ray pose missing: falls back to grip
  #|          if (!isRay && f === 3) return null; // grip pose missing
  #|          const pose = { transform: { matrix: translation(0.2 * (n ? 1 : -1) + 0.005 * f, 1.1 + (isRay ? 0.02 : 0), -0.3 - 0.01 * f, 0.1 * f + n) } };
  #|          if (f % 2 === 1) pose.linearVelocity = { x: 0.1 * f, y: -0.2, z: 0.05, w: 0 };
  #|          if (f % 2 === 0) pose.angularVelocity = { x: 0, y: 0.3 * f, z: -0.1, w: 0 };
  #|          return pose;
  #|        },
  #|        getJointPose(joint, base) {
  #|          rec('frame.getJointPose', [joint, base]);
  #|          const name = joint.jointName;
  #|          if (name === 'wrist' && f === 5) return null;
  #|          const d = PINCH[f % PINCH.length];
  #|          const x = name === 'index-finger-tip' ? 0.3 + d : (name === 'thumb-tip' ? 0.3 : 0.25);
  #|          return { transform: { matrix: translation(x, 1.2, -0.25, 0) }, radius: name === 'wrist' ? 0.02 : 0.008 };
  #|        },
  #|      });
  #|      if (has(options.planeFrames, f)) frame.detectedPlanes = new Set();
  #|      frame.__label = label;
  #|      return frame;
  #|    }
  #|
  #|    // layers and binding
  #|    function projectionLayer(init) {
  #|      const layer = handle('XRProjectionLayer', { textureWidth: tex.width, textureHeight: tex.height, ignoreDepthValues: options.ignoreDepthValues === true });
  #|      Object.defineProperty(layer, 'fixedFoveation', { get() { return this.__foveation; }, set(v) { this.__foveation = v; log.push('xr.' + norm(layer) + '.fixedFoveation = ' + JSON.stringify(v)); } });
  #|      return layer;
  #|    }
  #|    class XRWebGLLayer {
  #|      constructor(s, context, init) {
  #|        rec('new XRWebGLLayer', [s, context, init]);
  #|        Object.assign(this, handle('XRWebGLLayer'));
  #|        this.framebufferWidth = fb.width;
  #|        this.framebufferHeight = fb.height;
  #|        this.framebuffer = handle('XRFramebuffer');
  #|        this.ignoreDepthValues = options.ignoreDepthValues === true;
  #|        if (options.baseLayerFoveation) {
  #|          const self = this;
  #|          Object.defineProperty(this, 'fixedFoveation', { get() { return self.__foveation === undefined ? 0 : self.__foveation; }, set(v) { self.__foveation = v; log.push('xr.' + norm(self) + '.fixedFoveation = ' + JSON.stringify(v)); } });
  #|        }
  #|      }
  #|      getViewport(view) { rec(norm(this) + '.getViewport', [view]); return view.__viewport; }
  #|    }
  #|    const depthTexture = handle('XRDepthTexture');
  #|    class XRWebGLBinding {
  #|      constructor(s, context) { rec('new XRWebGLBinding', [s, context]); Object.assign(this, handle('XRWebGLBinding')); }
  #|      getViewSubImage(layer, view) {
  #|        rec('binding.getViewSubImage', [layer, view]);
  #|        return { viewport: view.__subViewport, colorTexture: handle('XRColorTexture'), depthStencilTexture: handle('XRDepthStencilTexture') };
  #|      }
  #|      getDepthInformation(view) {
  #|        rec('binding.getDepthInformation', [view]);
  #|        const d = options.depth;
  #|        if (!d || frameIndex < (d.from || 0)) return null;
  #|        return { isValid: true, texture: depthTexture, depthNear: d.near, depthFar: d.far, width: 4, height: 4 };
  #|      }
  #|      getCameraImage(camera) { rec('binding.getCameraImage', [camera]); return handle('XRCameraImage'); }
  #|    }
  #|    if (options.layers) {
  #|      XRWebGLBinding.prototype.createProjectionLayer = function (init) { rec('binding.createProjectionLayer', [init]); return projectionLayer(init); };
  #|    }
  #|
  #|    const saved = {};
  #|    return {
  #|      session,
  #|      inputSources,
  #|      cameras,
  #|      customSpace: handle('XRReferenceSpace', { type: 'custom' }),
  #|      install() {
  #|        for (const k of ['XRWebGLBinding', 'XRWebGLLayer']) saved[k] = Object.getOwnPropertyDescriptor(globalThis, k);
  #|        globalThis.XRWebGLLayer = XRWebGLLayer;
  #|        if (options.binding !== false) globalThis.XRWebGLBinding = XRWebGLBinding;
  #|        else delete globalThis.XRWebGLBinding;
  #|      },
  #|      uninstall() {
  #|        for (const k of ['XRWebGLBinding', 'XRWebGLLayer']) {
  #|          if (saved[k]) Object.defineProperty(globalThis, k, saved[k]);
  #|          else delete globalThis[k];
  #|        }
  #|      },
  #|      // runs the pending XR animation frames with the next frame index
  #|      tick(time) {
  #|        frameIndex++;
  #|        const frame = makeFrame(frameIndex, 'raf');
  #|        log.push('## xr tick ' + frameIndex);
  #|        const run = pending;
  #|        pending = [];
  #|        for (const p of run) p.callback(time, frame);
  #|      },
  #|      // a select/squeeze event of input source `n`, with its own frame
  #|      fire(type, n) {
  #|        log.push('## xr event ' + type + ' ' + n);
  #|        dispatch(type, { type, inputSource: inputSources[n], frame: makeFrame(Math.max(frameIndex, 0), 'event') });
  #|      },
  #|      changeInputSources(added, removed) {
  #|        log.push('## xr inputsourceschange +' + JSON.stringify(added) + ' -' + JSON.stringify(removed));
  #|        dispatch('inputsourceschange', { type: 'inputsourceschange', session, added: added.map((n) => inputSources[n]), removed: removed.map((n) => inputSources[n]) });
  #|      },
  #|      end() { session.end(); },
  #|      norm,
  #|    };
  #|  }
  #|  return { createMockXR };
  #|})()

///|
let xr_mock_module : @core.JsValue = ffi_xr_mock_module()

///|
extern "js" fn ffi_xr_create(
  module_ : @core.JsValue,
  gl : @webgl.WebGL2RenderingContext,
  options : String,
) -> @core.JsValue = "(m, gl, o) => m.createMockXR(gl, JSON.parse(o))"

///|
extern "js" fn xr_mock_install(xr : @core.JsValue) -> Unit = "(x) => x.install()"

///|
extern "js" fn xr_mock_uninstall(xr : @core.JsValue) -> Unit = "(x) => x.uninstall()"

///|
extern "js" fn xr_mock_tick(xr : @core.JsValue, time : Double) -> Unit = "(x, t) => x.tick(t)"

///|
extern "js" fn xr_mock_fire(
  xr : @core.JsValue,
  type_ : String,
  n : Int32,
) -> Unit = "(x, t, n) => x.fire(t, n)"

///|
extern "js" fn xr_mock_change(
  xr : @core.JsValue,
  added : FixedArray[Int32],
  removed : FixedArray[Int32],
) -> Unit = "(x, a, r) => x.changeInputSources(Array.from(a), Array.from(r))"

///|
extern "js" fn xr_mock_end(xr : @core.JsValue) -> Unit = "(x) => x.end()"

///|
extern "js" fn xr_mock_camera(xr : @core.JsValue, i : Int32) -> @webgl.XRCamera = "(x, i) => x.cameras[i]"

///|
extern "js" fn xr_norm(
  xr : @core.JsValue,
  value : @core.JsValue,
) -> @core.JsValue = "(x, v) => x.norm(v)"

///|
/// renderer_common's mock options plus the depth sensing material's uniforms
/// (harness/xr_util.mjs `XR_UNIFORMS`).
extern "js" fn ffi_xr_gl_options(
  common : @core.JsValue,
  extra : String,
) -> String = "(c, e) => { const o = JSON.parse(c.mockOptions(JSON.parse(e))); const u = [{ name: 'depthColor', type: 0x8DC1 }, { name: 'depthWidth', type: 0x1406 }, { name: 'depthHeight', type: 0x1406 }]; o.programs = o.programs.map((p) => ({ attributes: p.attributes, uniforms: p.uniforms.concat(u) })); return JSON.stringify(o); }"

///|
fn xj(value : Double) -> @core.JsValue {
  @core.JsValue::of(value)
}

///|
fn xj_int(value : Int32) -> @core.JsValue {
  @core.JsValue::of(value)
}

///|
fn xj_bool(value : Bool) -> @core.JsValue {
  @core.JsValue::of(value)
}

///|
fn xj_str(value : String) -> @core.JsValue {
  @core.JsValue::of(value)
}

///|
fn xj_list(values : Array[@core.JsValue]) -> @core.JsValue {
  @core.JsValue::of(FixedArray::from_array(values[:]))
}

///|
fn xj_nums(values : Array[Double]) -> @core.JsValue {
  @core.JsValue::of(FixedArray::from_array(values[:]))
}

///|
fn xj_v3(v : @math.Vector3) -> Array[@core.JsValue] {
  [xj(v.x), xj(v.y), xj(v.z)]
}

///|
fn xj_opt_num(value : Double?) -> @core.JsValue {
  match value {
    Some(v) => xj(v)
    None => @core.JsValue::undefined()
  }
}

///|
fn xj_opt_str(value : String?) -> @core.JsValue {
  match value {
    Some(v) => xj_str(v)
    None => @core.JsValue::undefined()
  }
}

///|
fn[T] xj_opt(value : T?) -> @core.JsValue {
  match value {
    Some(v) => @core.JsValue::of(v)
    None => @core.JsValue::null()
  }
}

///|
/// One xr_* scenario's settings, as in its harness/scenarios/xr_*.mjs.
struct XRScenario {
  name : String
  gl : String
  xr : String
  rig : Bool
  scale : Double?
  reference_space_type : String?
  foveation : Double?
  /// `scene.background = new Color( hex )`
  background : Int32?
}

///|
let xr_events : Array[String] = [
  "connected", "disconnected", "move", "select", "selectstart", "selectend", "squeeze",
  "squeezestart", "squeezeend", "pinchstart", "pinchend", "gripUpdated",
]

///|
/// `runXR` of harness/xr_util.mjs, step for step; `on_done` runs after the log is out.
fn xr_run(config : XRScenario, on_done : () -> Unit) -> Unit {
  let gl = mock_gl(options=ffi_xr_gl_options(renderer_common, config.gl))
  let xr = ffi_xr_create(xr_mock_module, gl, config.xr)
  let norm = (v : @core.JsValue) => xr_norm(xr, v)
  xr_mock_install(xr)
  let canvas = renderer_mock_canvas(gl, 64, 32)
  let renderer = @webgl.WebGLRenderer::new(canvas~, context=gl)
  let manager = renderer.xr
  manager.set_enabled(true)
  if config.scale is Some(scale) {
    manager.set_framebuffer_scale_factor(scale)
  }
  if config.reference_space_type is Some(type_) {
    manager.set_reference_space_type(type_)
  }
  if config.foveation is Some(foveation) {
    manager.set_foveation(foveation)
  }
  let size = () => {
    let s = renderer.get_size(@math.Vector2::new(0, 0))
    [xj(s.x), xj(s.y), xj(renderer.get_pixel_ratio())]
  }
  let status_of = () => {
    let values = [
      xj_bool(manager.is_presenting),
      xj_opt_num(manager.get_foveation()),
      xj_opt_str(manager.get_environment_blend_mode()),
      norm(xj_opt(manager.get_session())),
      norm(
        match manager.get_base_layer() {
          Some(ProjectionLayer(layer)) => @core.JsValue::of(layer)
          Some(WebGLLayer(layer)) => @core.JsValue::of(layer)
          None => @core.JsValue::null()
        },
      ),
      norm(xj_opt(manager.get_reference_space())),
      norm(xj_opt(manager.get_frame())),
      xj_bool(manager.has_depth_sensing()),
      xj_bool(manager.get_depth_texture() is None),
      xj_bool(manager.get_depth_sensing_mesh() is None),
    ]
    xj_list(values + size())
  }
  let status = (label : String) => mock_note(gl, label, status_of())
  let before = status_of()
  let scene = @core.Scene::new()
  if config.background is Some(hex) {
    scene.as_scene().background = Some(Color(@math.Color::from_hex(hex)))
  }
  let box = renderer_mesh(
    @geometries.BoxGeometry::new(),
    @core.MeshBasicMaterial::new(),
  )
  ignore(box.position.set(0, 1.5, -1))
  ignore(scene.add(box))
  let camera = @core.PerspectiveCamera::new(fov=50, aspect=2, near=0.1, far=100)
  ignore(camera.position.set(0, 1.6, 3))
  if config.rig {
    let rig = @core.Group::new()
    ignore(rig.position.set(1, 0, 2))
    rig.rotation.set_y(0.3)
    ignore(rig.add(camera))
    ignore(scene.add(rig))
  }
  let spaces = [
    ("ray0", manager.get_controller(0)),
    ("grip0", manager.get_controller_grip(0)),
    ("hand1", manager.get_hand(1)),
    ("ray1", manager.get_controller(1)),
    ("grip1", manager.get_controller_grip(1)),
  ]
  @webgl.xr_controller_space(spaces[1].1).unwrap().events_enabled = true
  let watch = (name : String, group : @core.Object3D) => {
    ignore(scene.add(group))
    for type_ in xr_events {
      group.add_event_listener(type_, e => {
        let data = match e.data {
          Some(data) => data
          None => @core.JsValue::undefined()
        }
        mock_note(gl, "event " + name + " " + e.type_, norm(data))
      })
    }
  }
  for space in spaces {
    watch(space.0, space.1)
  }
  manager.add_event_listener("sessionstart", _ => {
    mock_note(
      gl,
      "sessionstart",
      xj_list([xj_bool(manager.is_presenting)] + size()),
    )
  })
  manager.add_event_listener("sessionend", _ => {
    mock_note(
      gl,
      "sessionend",
      xj_list([xj_bool(manager.is_presenting)] + size()),
    )
  })
  manager.add_event_listener("planesdetected", e => {
    mock_note(gl, "planesdetected", norm(e.data.unwrap()))
  })
  let note_rig = (label : String) => {
    let camera_xr = manager.get_camera()
    let xr_perspective = camera_xr.as_perspective_camera()
    let sub_cameras = xr_perspective.array_camera.unwrap().cameras
    mock_note(
      gl,
      label + " cameraXR",
      xj_list([
        xj_int(sub_cameras.length()),
        xj(camera_xr.layers.mask),
        xj(xr_perspective.near),
        xj(xr_perspective.far),
        xj_nums(camera_xr.matrix_world.elements),
        xj_nums(camera_xr.as_camera().projection_matrix.elements),
      ]),
    )
    for i, c in sub_cameras {
      let viewport = @webgl.camera_viewport(c).unwrap()
      mock_note(
        gl,
        label + " view " + i.to_string(),
        xj_list([
          xj(c.layers.mask),
          xj(c.as_perspective_camera().near),
          xj(c.as_perspective_camera().far),
          xj_nums(c.matrix_world.elements),
          xj_nums(c.as_camera().matrix_world_inverse.elements),
          xj_nums(c.as_camera().projection_matrix.elements),
          xj_nums([viewport.x, viewport.y, viewport.z, viewport.w]),
        ]),
      )
    }
    let user = camera.as_perspective_camera()
    let q = camera.quaternion
    mock_note(
      gl,
      label + " user camera",
      xj_list(
        xj_v3(camera.position) +
        [xj(q.x), xj(q.y), xj(q.z), xj(q.w), xj(user.fov), xj(user.zoom)] +
        camera.matrix_world.elements.map(xj) +
        camera.as_camera().projection_matrix.elements.map(xj),
      ),
    )
    for space in spaces {
      let (name, group) = space
      match @webgl.xr_hand_space(group) {
        Some(hand) => {
          let values = [
            xj_bool(group.visible),
            xj_bool(hand.input_state.pinching),
          ]
          for joint_name, joint in hand.joints {
            values.push(
              xj_list(
                [
                  xj_str(joint_name),
                  xj_bool(joint.visible),
                  xj_opt_num(@webgl.xr_joint_radius(joint)),
                ] +
                xj_v3(joint.position),
              ),
            )
          }
          mock_note(gl, label + " " + name, xj_list(values))
        }
        None => {
          let state = @webgl.xr_controller_space(group).unwrap()
          mock_note(
            gl,
            label + " " + name,
            xj_list([
              xj_bool(group.visible),
              xj_bool(state.has_linear_velocity),
              xj_list(xj_v3(state.linear_velocity)),
              xj_bool(state.has_angular_velocity),
              xj_list(xj_v3(state.angular_velocity)),
              xj_nums(group.matrix.elements),
            ]),
          )
        }
      }
    }
    let depth = match manager.get_depth_texture() {
      Some(texture) =>
        norm(
          match texture.external_source {
            Some(source) => source
            None => @core.JsValue::null()
          },
        )
      None => @core.JsValue::null()
    }
    mock_note(
      gl,
      label + " depth",
      xj_list([
        xj_bool(manager.has_depth_sensing()),
        depth,
        xj_bool(manager.get_depth_sensing_mesh() is None),
      ]),
    )
    let camera_texture = match
      manager.get_camera_texture(xr_mock_camera(xr, 0)) {
      Some(texture) =>
        norm(
          match texture.external_source {
            Some(source) => source
            None => @core.JsValue::null()
          },
        )
      None => xj_str("undefined")
    }
    mock_note(gl, label + " camera texture", camera_texture)
    let target = match renderer.get_render_target() {
      Some(target) =>
        xj_list([
          xj_int(target.width),
          xj_int(target.height),
          xj_int(target.samples),
          xj_bool(target.stencil_buffer),
          xj_bool(target.resolve_depth_buffer),
          xj_bool(target.resolve_stencil_buffer),
          xj_bool(target.store_multisampled_depth_buffer),
          xj_bool(target.has_extension_flag("isXRRenderTarget")),
          xj_str(target.texture().color_space),
          match target.depth_texture() {
            Some(depth) => xj_list([xj_int(depth.format), xj_int(depth.type_)])
            None => @core.JsValue::null()
          },
        ])
      None => @core.JsValue::null()
    }
    mock_note(gl, label + " target", target)
  }
  renderer.set_animation_loop(
    Some((time, frame) => {
      mock_log_push(gl, "## loop " + js_number_string(time))
      let same = match manager.get_frame() {
        Some(current) => @core.JsValue::of(current).strict_equal(frame)
        None => false
      }
      mock_note(gl, "loop frame", xj_list([norm(frame), xj_bool(same)]))
      renderer.render(scene, camera)
      note_rig("frame " + js_number_string(time))
    }),
  )
  manager.set_session(Some(xr_mock_session(xr)), on_done=() => {
    mock_note(gl, "before", before)
    status("after setSession")
    mock_note(gl, "binding", norm(xj_opt(manager.get_binding())))
    xr_mock_change(xr, [0, 1, 2], [])
    xr_mock_change(xr, [2, 1], []) // no free controller for 2: stops before re-adding 1
    // a controller created after the input sources: its slot stays `undefined`
    spaces.push(("ray2", manager.get_controller(2)))
    watch("ray2", spaces[5].1)
    xr_mock_tick(xr, 1000)
    xr_mock_fire(xr, "selectstart", 0)
    xr_mock_fire(xr, "select", 0)
    xr_mock_fire(xr, "selectend", 0)
    xr_mock_fire(xr, "squeezestart", 1)
    xr_mock_fire(xr, "squeeze", 1)
    xr_mock_fire(xr, "squeezeend", 1)
    xr_mock_fire(xr, "select", 2) // not assigned to a controller
    xr_mock_tick(xr, 1016)
    xr_mock_tick(xr, 1033)
    xr_mock_change(xr, [], [0])
    xr_mock_tick(xr, 1050)
    xr_mock_change(xr, [2], []) // takes the free controller 0
    xr_mock_tick(xr, 1066)
    xr_mock_tick(xr, 1083)
    manager.set_foveation(0.5)
    mock_note(gl, "foveation", xj_opt_num(manager.get_foveation()))
    manager.set_reference_space(Some(xr_mock_custom_space(xr)))
    xr_mock_tick(xr, 1100)
    manager.set_camera_auto_update(false)
    xr_mock_tick(xr, 1116)
    manager.update_camera(camera)
    note_rig("manual")
    manager.set_camera_auto_update(true)
    renderer.set_animation_loop(None)
    xr_mock_tick(xr, 1133)
    xr_mock_end(xr)
    status("after end")
    note_rig("after end")
    renderer.render(scene, camera)
    manager.set_session(None)
    xr_mock_uninstall(xr)
    renderer.dispose()
    let log = emit_log(config.name, gl)
    if log.length() < 500 {
      abort(config.name + ": log too short")
    }
    on_done()
  })
}

///|
extern "js" fn xr_mock_session(xr : @core.JsValue) -> @webgl.XRSession = "(x) => x.session"

///|
extern "js" fn xr_mock_custom_space(
  xr : @core.JsValue,
) -> @webgl.XRReferenceSpace = "(x) => x.customSpace"

///|
extern "js" fn mock_log_push(
  gl : @webgl.WebGL2RenderingContext,
  line : String,
) -> Unit = "(gl, l) => { gl.__log.push(l); }"

///|
extern "js" fn js_number_string(value : Double) -> String = "(v) => String(v)"

///|
let xr_scenarios : Array[XRScenario] = [
  {
    name: "xr_layers",
    gl: "{\"contextAttributes\":{\"antialias\":true,\"stencil\":true}}",
    xr: "{\"layers\":true,\"texture\":{\"width\":160,\"height\":64},\"environmentBlendMode\":\"opaque\",\"enabledFeatures\":[\"local-floor\",\"depth-sensing\",\"camera-access\",\"hand-tracking\"],\"depthUsage\":\"gpu-optimized\",\"depth\":{\"near\":0.2,\"far\":20,\"from\":1},\"cameraAccess\":true,\"inputSources\":[{\"handedness\":\"left\",\"grip\":true},{\"handedness\":\"right\",\"hand\":true},{\"handedness\":\"none\",\"grip\":true}]}",
    rig: true,
    scale: None,
    reference_space_type: None,
    foveation: None,
    background: None,
  },
  {
    name: "xr_webgl_layer",
    gl: "{\"contextAttributes\":{\"xrCompatible\":true}}",
    xr: "{\"layers\":false,\"baseLayerFoveation\":true,\"ignoreDepthValues\":true,\"framebuffer\":{\"width\":96,\"height\":48},\"environmentBlendMode\":\"opaque\",\"enabledFeatures\":[\"depth-sensing\"],\"depthUsage\":\"gpu-optimized\",\"depth\":{\"near\":0.1,\"far\":1000,\"from\":0},\"viewCounts\":[2,3,1,2],\"nullPoseFrames\":[4],\"planeFrames\":[2],\"blurredFrames\":[3],\"inputSources\":[{\"handedness\":\"left\",\"grip\":true},{\"handedness\":\"right\",\"hand\":true},{\"handedness\":\"none\"}]}",
    rig: false,
    scale: Some(0.5),
    reference_space_type: Some("local"),
    foveation: Some(0.25),
    background: None,
  },
  {
    name: "xr_no_binding",
    gl: "{}",
    xr: "{\"binding\":false,\"environmentBlendMode\":\"opaque\",\"cameraAccess\":true,\"inputSources\":[{\"handedness\":\"left\",\"grip\":true},{\"handedness\":\"right\",\"hand\":true,\"grip\":true},{\"handedness\":\"none\",\"grip\":true}]}",
    rig: false,
    scale: None,
    reference_space_type: None,
    foveation: None,
    background: None,
  },
  {
    name: "xr_additive",
    gl: "{}",
    xr: "{\"binding\":false,\"environmentBlendMode\":\"additive\",\"inputSources\":[{\"handedness\":\"left\",\"grip\":true},{\"handedness\":\"right\",\"hand\":true},{\"handedness\":\"none\"}]}",
    rig: false,
    scale: None,
    reference_space_type: None,
    foveation: None,
    background: Some(0x336699),
  },
  {
    name: "xr_alpha_blend",
    gl: "{\"contextAttributes\":{\"antialias\":true}}",
    xr: "{\"layers\":true,\"texture\":{\"width\":160,\"height\":64},\"environmentBlendMode\":\"alpha-blend\",\"enabledFeatures\":[\"local-floor\"],\"inputSources\":[{\"handedness\":\"left\",\"grip\":true},{\"handedness\":\"right\",\"hand\":true,\"grip\":true},{\"handedness\":\"none\",\"grip\":true}]}",
    rig: true,
    scale: None,
    reference_space_type: None,
    foveation: None,
    background: Some(0x804020),
  },
]

///|
fn xr_run_from(index : Int32) -> Unit {
  if index < xr_scenarios.length() {
    xr_run(xr_scenarios[index], () => xr_run_from(index + 1))
  }
}

///|
test "diff xr_layers xr_webgl_layer xr_no_binding xr_additive xr_alpha_blend" {
  // The scenarios are async (setSession awaits) and install the mock's XR globals, so
  // they run one after another, after the synchronous tests.
  @webgl.set_timeout(() => xr_run_from(0), 0)
}

///|
test "WebXRManager without a session keeps the stand-in's values" {
  let gl = mock_gl(options=renderer_mock_options("{}"))
  let renderer = @webgl.WebGLRenderer::new(
    canvas=renderer_mock_canvas(gl, 64, 32),
    context=gl,
  )
  let xr = renderer.xr
  inspect(xr.enabled, content="false")
  inspect(xr.is_presenting, content="false")
  inspect(xr.camera_auto_update, content="true")
  inspect(xr.has_depth_sensing(), content="false")
  inspect(xr.get_depth_sensing_mesh() is None, content="true")
  inspect(xr.get_environment_blend_mode() is None, content="true")
  inspect(xr.get_foveation() is None, content="true")
  inspect(xr.get_session() is None, content="true")
  inspect(xr.get_base_layer() is None, content="true")
  inspect(xr.get_frame() is None, content="true")
  inspect(xr.get_binding() is None, content="true")
  inspect(xr.get_depth_texture() is None, content="true")
  // the XR camera rig exists before any session, as upstream
  let camera_xr = xr.get_camera()
  inspect(camera_xr.is_array_camera(), content="true")
  // `updateCamera` returns early without a session
  let camera = @core.PerspectiveCamera::new()
  ignore(camera.position.set(1, 2, 3))
  xr.update_camera(camera)
  inspect(camera.position.x, content="1")
  // controllers are created on demand and shared by the three spaces
  let ray = xr.get_controller(1)
  inspect(physical_equal(ray, xr.get_controller(1)), content="true")
  inspect(ray.visible, content="false")
  inspect(ray.matrix_auto_update, content="false")
  inspect(
    @webgl.xr_controller_space(xr.get_controller_grip(1)).unwrap().events_enabled,
    content="false",
  )
  inspect(
    @webgl.xr_hand_space(xr.get_hand(0)).unwrap().joints.length(),
    content="0",
  )
  // the context attributes are read by the renderer (for `alpha`) and, as upstream, by
  // the WebXRManager constructor
  let log = mock_log(gl)
  inspect(log.filter(l => l == "getContextAttributes()").length(), content="2")
}
