import fs from 'fs';
const [, , sPath, aPath, bPath] = process.argv;
const scenarios = JSON.parse(fs.readFileSync(sPath, 'utf8'));
const a = JSON.parse(fs.readFileSync(aPath, 'utf8'));
const b = JSON.parse(fs.readFileSync(bPath, 'utf8'));
const stats = {};
function firstDiff(x, y, path) {
  if (typeof x !== typeof y || (x === null) !== (y === null)) return `${path}: ${JSON.stringify(x)?.slice(0, 120)} vs ${JSON.stringify(y)?.slice(0, 120)}`;
  if (x && typeof x === 'object') {
    if (Array.isArray(x) !== Array.isArray(y)) return `${path}: array mismatch`;
    const keys = new Set([...Object.keys(x), ...Object.keys(y)]);
    for (const k of keys) { const d = firstDiff(x[k], y[k], `${path}.${k}`); if (d) return d; }
    return null;
  }
  return x === y ? null : `${path}: ${x} vs ${y}`;
}
let values = 0;
const countValues = (x) => { if (x && typeof x === 'object') { for (const k in x) countValues(x[k]); } else values++; };
const shown = {};
a.forEach((r, i) => {
  const k = scenarios[i].kind + (scenarios[i].node ? ':' + scenarios[i].node.type : '');
  stats[k] ??= { n: 0, diff: 0 };
  stats[k].n++;
  countValues(r);
  const d = firstDiff(r, b[i], '');
  if (d) { stats[k].diff++; shown[k] = (shown[k] || 0) + 1; if (shown[k] <= 3) console.log(`[${i}] ${k} ${d}`); }
});
const hitCount = {};
scenarios.forEach((s, i) => { if (s.kind === 'raycast') { const k = s.node.type; hitCount[k] ??= { rays: 0, hit: 0, hits: 0, nan: 0 }; for (const h of a[i].hits) { hitCount[k].rays++; if (h.length) hitCount[k].hit++; hitCount[k].hits += h.length; for (const x of h) if (x.distance === '@NaN') hitCount[k].nan++; } }
 if (s.kind === 'sprite') { const k = 'spriteCam'; hitCount[k] ??= { rays: 0, hit: 0, hits: 0, nan: 0 }; for (const h of a[i].hits) { hitCount[k].rays++; if (h.hit.length) hitCount[k].hit++; hitCount[k].hits += h.hit.length; } } });
console.table(hitCount);
const bools = {}; scenarios.forEach((s, i) => { if (s.kind === 'frustum') { const v = String(a[i].direct); bools[v] = (bools[v] || 0) + 1; } }); console.log('frustum results', bools);
console.table(stats);
console.log('compared scalar values:', values, 'scenarios', a.length, 'lengths', a.length, b.length);
const diffs = Object.values(stats).reduce((n, s) => n + s.diff, 0);
const same = a.length === b.length && a.length === scenarios.length;
console.log(`${a.length - diffs}/${scenarios.length} scenarios identical, ${values} scalar values compared${same ? '' : ` (lengths ${a.length} ${b.length})`}`);
process.exit(diffs || !same ? 1 : 0);
