// Runs one upstream scenario in this (fresh) process and prints its log as JSON.
//   node upstream_one.mjs <name>
import { load } from './common.mjs';
import { scenarios } from './scenarios.mjs';
const name = process.argv[ 2 ];
await load();
const log = [];
const origError = console.error, origWarn = console.warn;
console.error = () => {}; console.warn = () => {};
try {

	await scenarios[ name ]( log );

} catch ( e ) {

	log.push( [ 'exception', String( e && e.message ) ] );
	origError( e.stack );

}

console.error = origError; console.warn = origWarn;
process.stdout.write( JSON.stringify( log ) + '\n' );
process.exit( 0 );
