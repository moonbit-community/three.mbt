# MLS-MPM fluid

65,536 particles of liquid in a tilting tank, simulated on the GPU with the material point
method (MLS-MPM). It is a MoonBit port of upstream's `webgpu_compute_particles_fluid`
example, written against the port's `WebGPURenderer` and TSL.

Five TSL compute kernels run every frame:

1. **Clear the grid.**
2. **Scatter momentum** from the particles to a 64³ grid, using fixed-point atomics (WebGPU
   only has integer atomics).
3. **Scatter pressure and viscous stress** from each particle's local density.
4. **Update the grid.**
5. **Gather velocities** and the affine matrix C back to the particles, then apply gravity,
   the mouse and the walls, and advect.

The kernels, the struct buffers, the fixed-point encoding and the rounded-box walls follow
upstream line for line.

Added here:

- **Tilt:** the tank rocks back and forth, and gravity rotates the other way in its frame.
- **Foam:** fast-moving water whitens.
- **Mouse:** the pointer ray is taken into the tank's own frame, so it still pushes the
  water while the tank tilts.
- **Sliders:** tilt and viscosity.

Writing this demo found a port bug. `mat3( 0 )` generated `mat3x3<f32>( 0.0, NaN.0, ... )`,
because upstream's `new Matrix3( 0 )` leaves eight elements `undefined` and its
`generateConst( type, value = null )` prints those as `0.0`. The fix is in
`src/nodes/core_node_utils.mbt`, and the shader harness now covers it with the
`g1_math_mat*_scalar` scenarios.

## Run

```bash
cd examples/fluid && moon build --target js
```

Then serve the repository root (`python3 -m http.server 8000` from it) and open
`http://localhost:8000/examples/fluid/index.html` in a browser with WebGPU. Compute
atomics need WebGPU; there is no WebGL fallback for this one.
