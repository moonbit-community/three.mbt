// WebXR: a session with WebXR Layers (XRWebGLBinding + XRProjectionLayer), GPU depth
// sensing from frame 1, raw camera access, a camera inside a rig group, antialias and
// stencil context attributes. See harness/xr_util.mjs for the steps.
import { runXR } from '../xr_util.mjs';

export async function run(ctx) {
  return runXR(ctx, {
    gl: { contextAttributes: { antialias: true, stencil: true } },
    xr: {
      layers: true,
      texture: { width: 160, height: 64 },
      environmentBlendMode: 'opaque',
      enabledFeatures: ['local-floor', 'depth-sensing', 'camera-access', 'hand-tracking'],
      depthUsage: 'gpu-optimized',
      depth: { near: 0.2, far: 20, from: 1 },
      cameraAccess: true,
      inputSources: [{ handedness: 'left', grip: true }, { handedness: 'right', hand: true }, { handedness: 'none', grip: true }],
    },
    rig: true,
  });
}
