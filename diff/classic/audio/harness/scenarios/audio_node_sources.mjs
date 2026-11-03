import { setup } from '../common.mjs';
export async function run(env) {
  const { ctx, Audio, AudioListener, finish, note } = await setup(env);
  const listener = new AudioListener();
  const sound = new Audio(listener);
  const osc = ctx.createOscillator();
  sound.setNodeSource(osc);
  note('sourceType', sound.sourceType);
  note('hasPlaybackControl', sound.hasPlaybackControl);
  note('source', sound.source);
  sound.play();
  sound.pause();
  sound.stop();
  sound.setPlaybackRate(2);
  note('getLoop', sound.getLoop());
  sound.setLoop(true);
  sound.setDetune(5);
  note('getDetune', sound.getDetune());
  const element = new Audio(listener);
  element.setMediaElementSource(ctx.__mediaElement());
  note('sourceType', element.sourceType);
  note('source', element.source);
  const stream = new Audio(listener);
  stream.setMediaStreamSource(ctx.__mediaStream());
  note('sourceType', stream.sourceType);
  stream.setFilters([ctx.createBiquadFilter()]);
  stream.disconnect();
  return finish();
}
