// Prints the upstream log of one scenario: node show_log.mjs <name>
import * as mock from './mock_env.mjs';
import { scenarios } from './scenarios_upstream.mjs';
mock.install();
import { upstreamURL } from '../../lib/env.mjs';
const T = await import(upstreamURL('src/Three.js'));
const s = scenarios[process.argv[2]];
mock.reset(s.routes);
console.warn = console.error = () => {};
s.run(T, mock.note);
await mock.settle();
console.log(mock.log.join('\n'));
