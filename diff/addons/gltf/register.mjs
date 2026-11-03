// `node --import ../register.mjs run.mjs`: resolves the bare specifiers the upstream
// add-ons use against the upstream checkout (THREE_UPSTREAM, default .repos/three.js),
// as upstream's package.json exports do: 'three' -> src/Three.js, 'three/addons/*' ->
// examples/jsm/*.
import { register } from 'node:module';
register( './three_loader.mjs', import.meta.url );
