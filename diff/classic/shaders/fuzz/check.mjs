// node check.mjs <built main.js> <expected.json>: the strings the module returns must be
// the generated cases, exactly.
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
const { all } = await import(pathToFileURL(process.argv[2]).href);
const got = all(), exp = JSON.parse(fs.readFileSync(process.argv[3], 'utf8'));
let bad = 0; if (got.length !== exp.length) bad++;
exp.forEach((e, i) => { if (got[i] !== e) { if (bad++ < 10) console.log('DIFF', i, JSON.stringify(e), JSON.stringify(got[i])); } });
console.log(`${exp.length} cases, ${bad} differ`); process.exit(bad ? 1 : 0);
