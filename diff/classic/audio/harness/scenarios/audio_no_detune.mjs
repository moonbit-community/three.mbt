import { setup } from '../common.mjs';
export async function run(env) {
  const { ctx, Audio, AudioListener, finish, noteState } = await setup(env, { detune: false });
  const listener = new AudioListener();
  const sound = new Audio(listener);
  sound.setBuffer(ctx.__buffer(1.5));
  sound.detune = 30;
  ctx.__setTime(0.5);
  sound.play();
  sound.setDetune(12);
  sound.setPlaybackRate(0.5);
  noteState('a', sound);
  return finish();
}
