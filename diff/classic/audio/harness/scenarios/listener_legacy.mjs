import { setup } from '../common.mjs';
export async function run(env) {
  const { ctx, AudioListener, Object3D, finish, note } = await setup(env, { listenerParams: false });
  const listener = new AudioListener();
  const parent = new Object3D();
  parent.add(listener);
  parent.quaternion.set(0.1, 0.2, 0.3, 0.9).normalize();
  parent.scale.set(1.5, 1.5, 1.5);
  listener.position.set(-4, 0.5, 7);
  ctx.__setTime(2);
  ctx.__setNow(5);
  parent.updateMatrixWorld();
  note('timeDelta', listener.timeDelta);
  listener.lookAt(10, -3, 2);
  ctx.__setNow(21.75);
  parent.updateMatrixWorld();
  note('timeDelta', listener.timeDelta);
  return finish();
}
