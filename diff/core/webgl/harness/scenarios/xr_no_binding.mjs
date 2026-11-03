// WebXR: no XRWebGLBinding at all (XRWebGLLayer only, no fixedFoveation on the layer),
// camera access requested but unavailable without a binding, no enabledFeatures, the
// camera without a parent. See harness/xr_util.mjs.
import { runXR } from '../xr_util.mjs';

export async function run(ctx) {
  return runXR(ctx, {
    xr: {
      binding: false,
      environmentBlendMode: 'opaque',
      cameraAccess: true,
      inputSources: [{ handedness: 'left', grip: true }, { handedness: 'right', hand: true, grip: true }, { handedness: 'none', grip: true }],
    },
  });
}
