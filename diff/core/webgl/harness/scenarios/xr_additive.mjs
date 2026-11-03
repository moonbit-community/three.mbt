// WebXR: an 'additive' environment blend mode (WebGLBackground clears to opaque black
// whatever the scene asks), with a Color background so that the forced clear path runs
// too; XRWebGLLayer without a binding. See harness/xr_util.mjs.
import { runXR } from '../xr_util.mjs';

export async function run(ctx) {
  return runXR(ctx, {
    xr: {
      binding: false,
      environmentBlendMode: 'additive',
      inputSources: [{ handedness: 'left', grip: true }, { handedness: 'right', hand: true }, { handedness: 'none' }],
    },
    background: 0x336699,
  });
}
