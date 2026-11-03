import { setup } from '../common.mjs';
export async function run(env) {
  const { ctx, Audio, AudioListener, PositionalAudio, AudioAnalyser, finish, note } = await setup(env);
  const listener = new AudioListener();
  const sound = new Audio(listener);
  const an = new AudioAnalyser(sound, 32);
  note('data', an.data);
  note('getFrequencyData', an.getFrequencyData());
  note('getAverageFrequency', an.getAverageFrequency());
  const pa = new PositionalAudio(listener);
  const an2 = new AudioAnalyser(pa);
  note('data.length', an2.data.length);
  note('getAverageFrequency', an2.getAverageFrequency());
  note('getAverageFrequency', an.getAverageFrequency());
  const an3 = new AudioAnalyser(sound, 0);
  note('getAverageFrequency', an3.getAverageFrequency());
  return finish();
}
