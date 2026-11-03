// Prints the upstream log of one scenario: node harness/dump.mjs <name>
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { upstreamURL } from '../../../lib/env.mjs';
const here = path.dirname(fileURLToPath(import.meta.url));
const body = fs.readFileSync(path.join(here, 'mock_audio_body.js'), 'utf8');
const { createMockAudio } = new Function(body + '\nreturn { createMockAudio };')();
const src = upstreamURL('src');
const mod = await import(pathToFileURL(path.join(here, 'scenarios', process.argv[2] + '.mjs')).href);
for (const l of await mod.run({ src, createMockAudio })) console.log(l);
