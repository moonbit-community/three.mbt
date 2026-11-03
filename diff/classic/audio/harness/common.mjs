// Upstream side of a scenario: a fresh mock installed as the shared context, performance.now()
// at 0, and three.js warnings recorded in the log (as MoonBit's mock_audio does).
export async function setup({ src, createMockAudio }, options = {}) {
  const imp = (p) => import(`${src}/${p}`);
  const [{ Audio }, { AudioListener }, { PositionalAudio }, { AudioAnalyser }, { AudioContext }, { Object3D }, utils] = await Promise.all([
    imp('audio/Audio.js'), imp('audio/AudioListener.js'), imp('audio/PositionalAudio.js'), imp('audio/AudioAnalyser.js'),
    imp('audio/AudioContext.js'), imp('core/Object3D.js'), imp('utils.js'),
  ]);
  const ctx = createMockAudio(options);
  AudioContext.setContext(ctx);
  ctx.__setNow(0);
  utils.setConsoleFunction((type, message) => ctx.__warn(message));
  const finish = () => { utils.setConsoleFunction(null); return ctx.__finish().slice(); };
  const note = (label, value) => ctx.__note(label, value);
  const noteState = (label, a) => {
    note(label + '.isPlaying', a.isPlaying);
    note(label + '._progress', a._progress);
    note(label + '._startedAt', a._startedAt);
    note(label + '._connected', a._connected);
  };
  return { ctx, Audio, AudioListener, PositionalAudio, AudioAnalyser, AudioContext, Object3D, finish, note, noteState };
}
