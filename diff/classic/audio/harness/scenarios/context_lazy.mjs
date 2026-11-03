import { setup } from '../common.mjs';
export async function run(env) {
  const { ctx, AudioContext, AudioListener, finish, note } = await setup(env);
  AudioContext.setContext(undefined);
  ctx.__installWindow('standard');
  const a = AudioContext.getContext();
  const b = AudioContext.getContext();
  note('same', a === b);
  note('isMock', a === ctx);
  AudioContext.setContext(undefined);
  ctx.__installWindow('webkit');
  const c = AudioContext.getContext();
  note('webkit', c === ctx);
  AudioContext.setContext(ctx);
  const listener = new AudioListener();
  note('listener.context', listener.context === ctx);
  note('type', listener.type);
  return finish();
}
