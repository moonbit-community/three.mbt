export async function run({ src, createMockGL, createMockAnimationContext }) {
  const { WebGLAnimation } = await import(src + '/renderers/webgl/WebGLAnimation.js');
  const gl = createMockGL({});
  const ctx = createMockAnimationContext(gl);
  const anim = new WebGLAnimation();
  anim.start();
  anim.setAnimationLoop((time, frame) => gl.__note('frame', [time, frame === undefined ? 'undefined' : frame]));
  anim.start();
  anim.setContext(ctx);
  anim.start();
  anim.start();
  ctx.__tick(16);
  ctx.__tick(32);
  anim.stop();
  anim.stop();
  anim.start();
  ctx.__tick(48);
  return gl.__log;
}
