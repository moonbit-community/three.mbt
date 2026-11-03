// WebXR: XRWebGLBinding without createProjectionLayer, so the XRWebGLLayer path with a
// foveation-capable base layer; xrCompatible skips makeXRCompatible; 2, 3, 1, 2 views
// (camera list rebuilds and an extra eye camera), a frame without viewer pose, detected
// planes, a blurred frame, GPU depth sensing through the binding whose depth range equals
// the render state's (so the camera's is kept), framebuffer scale and
// reference space type set before the session. See harness/xr_util.mjs.
import { runXR } from '../xr_util.mjs';

export async function run(ctx) {
  return runXR(ctx, {
    gl: { contextAttributes: { xrCompatible: true } },
    xr: {
      layers: false,
      baseLayerFoveation: true,
      ignoreDepthValues: true,
      framebuffer: { width: 96, height: 48 },
      environmentBlendMode: 'opaque',
      enabledFeatures: ['depth-sensing'],
      depthUsage: 'gpu-optimized',
      depth: { near: 0.1, far: 1000, from: 0 },
      viewCounts: [2, 3, 1, 2],
      nullPoseFrames: [4],
      planeFrames: [2],
      blurredFrames: [3],
      inputSources: [{ handedness: 'left', grip: true }, { handedness: 'right', hand: true }, { handedness: 'none' }],
    },
    scale: 0.5,
    referenceSpaceType: 'local',
    foveation: 0.25,
  });
}
