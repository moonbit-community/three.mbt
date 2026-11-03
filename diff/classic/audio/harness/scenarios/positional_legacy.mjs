import { setup } from '../common.mjs';
export async function run(env) {
  const { ctx, AudioListener, PositionalAudio, Object3D, finish } = await setup(env, { listenerParams: false, pannerParams: false });
  const listener = new AudioListener();
  const root = new Object3D();
  root.add(listener);
  const pa = new PositionalAudio(listener);
  root.add(pa);
  pa.position.set(5, 0.25, -1);
  pa.quaternion.set(0.3, -0.5, 0.1, 0.8).normalize();
  pa.scale.set(1, -2, 0.5);
  pa.setBuffer(ctx.__buffer(10));
  ctx.__setTime(3);
  ctx.__setNow(100);
  pa.play();
  root.updateMatrixWorld();
  pa.lookAt(0, 0, 0);
  root.updateMatrixWorld(true);
  return finish();
}
