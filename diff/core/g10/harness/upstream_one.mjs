// Runs one upstream scenario in this (fresh) process and prints its log as JSON.
//   node upstream_one.mjs <name>
import fs from 'node:fs';
import { load, align } from './common.mjs';
import { scenarios } from './scenarios.mjs';
const name = process.argv[ 2 ];
await load();
align();
const origError = console.error, origWarn = console.warn, origLog = console.log;
const messages = [];
console.error = ( ...a ) => messages.push( 'error ' + a.join( ' ' ) );
console.warn = ( ...a ) => messages.push( 'warn ' + a.join( ' ' ) );
let log;
try {

	log = await scenarios[ name ]();

} catch ( e ) {

	log = [ 'exception ' + String( e && e.message ) ];
	origError( e.stack );

}

console.error = origError; console.warn = origWarn;
if ( process.env.G10_MESSAGES ) origError( messages.join( '\n' ) );
fs.writeSync( 1, '\n' + JSON.stringify( log ) + '\n' );
process.exit( 0 );
