// node run.mjs [scenario ...] (side.mjs runs under ../register.mjs): runs both sides (separate processes) and compares logs.
import { execFileSync } from 'node:child_process';
const args = process.argv.slice(2);
const dir = new URL('.', import.meta.url).pathname;
function side(s) {
	const out = execFileSync('node', ['--import', dir + '../register.mjs', dir + 'side.mjs', s, ...args], { cwd: dir, maxBuffer: 1 << 30, stdio: ['ignore', 'pipe', 'inherit'] });
	return JSON.parse(out.toString());
}
// Entries between 'racy.begin' and 'racy.end' are compared as a multiset (sorted).
function canon(logs) {
	const out = [];
	let racy = null;
	for (const e of logs) {
		if (e[0] === 'racy.begin') { racy = []; out.push(e); continue; }
		if (e[0] === 'racy.end') { racy.sort((a, b) => (JSON.stringify(a) < JSON.stringify(b) ? -1 : 1)); out.push(...racy, e); racy = null; continue; }
		(racy || out).push(e);
	}
	return out;
}
const up = canon(side('up'));
const mbt = canon(side('mbt'));
let scen = '', checks = 0, fails = 0, perScen = {};
const n = Math.max(up.length, mbt.length);
for (let i = 0; i < n; i++) {
	const a = JSON.stringify(up[i]), b = JSON.stringify(mbt[i]);
	if (up[i] && up[i][0] === 'scenario') scen = up[i][1];
	perScen[scen] = perScen[scen] || { entries: 0, fails: 0 };
	perScen[scen].entries++;
	checks++;
	if (a !== b) {
		fails++;
		perScen[scen].fails++;
		if (fails <= 5) console.log('MISMATCH #' + i + ' in ' + scen + '\n  up : ' + (a || '').slice(0, 600) + '\n  mbt: ' + (b || '').slice(0, 600));
	}
}
for (const [k, v] of Object.entries(perScen)) console.log((v.fails ? 'FAIL ' : 'ok   ') + k + ' (' + v.entries + ' entries' + (v.fails ? ', ' + v.fails + ' mismatches' : '') + ')');
const geoms = up.reduce((n, e) => n + (JSON.stringify(e).match(/"type":"BufferGeometry"/g) || []).length, 0);
console.log(`${checks} log entries compared (${geoms} geometry summaries), ${fails} mismatches`);
process.exit(fails ? 1 : 0);
