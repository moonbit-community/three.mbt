// `node --import ./register_three.mjs ...`: installs three_hooks.mjs (a6, objects add-ons).
import { register } from 'node:module';
register( './three_hooks.mjs', import.meta.url );
