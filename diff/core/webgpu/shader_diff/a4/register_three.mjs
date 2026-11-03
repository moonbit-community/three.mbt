// `node --import ./register_three.mjs ...`: installs three_hooks.mjs.
import { register } from 'node:module';
register( './three_hooks.mjs', import.meta.url );
