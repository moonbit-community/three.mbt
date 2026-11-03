// WebXR: an 'alpha-blend' environment blend mode (WebGLBackground clears to transparent
// black over the scene's Color background, which still forces the clear), WebXR Layers
// with an antialiased context and a camera rig.
// See harness/xr_util.mjs.
import { runXR } from '../xr_util.mjs';

export async function run(ctx) {
  return runXR(ctx, {
    gl: { contextAttributes: { antialias: true } },
    xr: {
      layers: true,
      texture: { width: 160, height: 64 },
      environmentBlendMode: 'alpha-blend',
      enabledFeatures: ['local-floor'],
      inputSources: [{ handedness: 'left', grip: true }, { handedness: 'right', hand: true, grip: true }, { handedness: 'none', grip: true }],
    },
    rig: true,
    background: 0x804020,
  });
}
