// Round trip of tools/gen_shaders.mjs's string encoding: generate the fuzz module (gen.mjs)
// under $THREE_DIFF_OUT/classic_shaders/fuzz, build it, compare the strings (check.mjs).
//   node run.mjs
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { outDir } from '../../../lib/env.mjs';
const here = path.dirname(fileURLToPath(import.meta.url));
const dir = outDir('classic_shaders', 'fuzz');
const sh = (cmd, args, cwd) => execFileSync(cmd, args, { cwd, stdio: ['ignore', 'pipe', 'pipe'], encoding: 'utf8' });
try {
  process.stdout.write(sh('node', [path.join(here, 'gen.mjs'), dir, 'fmt'], here));
  sh('moon', ['build', '--target', 'js'], dir);
  process.stdout.write(sh('node', [path.join(here, 'check.mjs'), path.join(dir, '_build/js/debug/build/main/main.js'), path.join(dir, 'expected.json')], here));
} catch (e) {
  console.log(String(e.stdout ?? '') + String(e.stderr ?? e.message));
  process.exit(1);
}
