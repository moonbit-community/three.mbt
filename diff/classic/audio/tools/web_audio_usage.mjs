// Derives the Web Audio members upstream src/audio uses, from the source itself.
//
// Types come from upstream's JSDoc (`@type` on constructor fields, `@return` on methods,
// `@param`) and from TypeScript's lib.dom.d.ts for the Web Audio interfaces, so the
// receiver of every member access is typed without a hand-written list. Every access on a
// DOM-typed receiver is recorded as `Interface.member get|set|call`, with the interface that
// declares the member. Accesses whose member is not on the declared type (upstream's
// `this.source` is a `?AudioNode` but is used as an `AudioBufferSourceNode`) are recorded
// with `downcast` and the subtypes that declare the member.
//
// Usage: node tools/web_audio_usage.mjs <three.js/src/audio> <lib.dom.d.ts> [--json out.json]
import fs from 'node:fs';
import path from 'node:path';

const [audioDir, libDom] = process.argv.slice(2);
const jsonOut = process.argv.includes('--json') ? process.argv[process.argv.indexOf('--json') + 1] : null;

// ---- lib.dom.d.ts: interfaces, their parents and member types
const dom = fs.readFileSync(libDom, 'utf8');
const ifaces = {};
for (const m of dom.matchAll(/^interface (\w+)(?:<[^>]*>)?(?: extends ([^{]+))? \{\n([\s\S]*?)^\}/gm)) {
  const [, name, ext, body] = m;
  const it = ifaces[name] ?? (ifaces[name] = { parents: [], members: Object.create(null) });
  if (ext) it.parents.push(...ext.split(',').map((s) => s.trim().replace(/<.*$/, '')));
  for (const line of body.split('\n')) {
    let mm = /^\s+(readonly )?(\w+)\??: ([^;]+);/.exec(line);
    if (mm) { it.members[mm[2]] ??= { kind: 'prop', type: mm[3], readonly: !!mm[1] }; continue; }
    mm = /^\s+(\w+)\(.*\): ([^;]+);/.exec(line);
    if (mm) it.members[mm[1]] ??= { kind: 'method', type: mm[2] };
  }
}
function findMember(type, member) {
  const it = ifaces[type];
  if (!it) return null;
  if (it.members[member]) return { owner: type, ...it.members[member] };
  for (const p of it.parents) { const r = findMember(p, member); if (r) return r; }
  return null;
}
function isSubtype(type, base) {
  if (type === base) return true;
  return (ifaces[type]?.parents ?? []).some((p) => isSubtype(p, base));
}
const domType = (t) => {
  t = (t ?? '').replace(/^\?/, '').replace(/ \| null$/, '').trim();
  return ifaces[t] ? t : null;
};

// ---- upstream classes: JSDoc field / return / param types
const THREE = {};
const files = fs.readdirSync(audioDir).filter((f) => f.endsWith('.js')).sort();
const sources = {};
for (const f of files) {
  const src = fs.readFileSync(path.join(audioDir, f), 'utf8');
  sources[f] = src;
  const cls = /class (\w+)(?: extends (\w+))? \{/.exec(src);
  const c = (THREE[cls[1]] = { parent: cls[2] ?? null, fields: Object.create(null), returns: Object.create(null), file: f });
  for (const m of src.matchAll(/@type \{([^}]+)\}[\s\S]*?\*\/\s*this\.(\w+) =/g)) c.fields[m[2]] = m[1];
  for (const m of src.matchAll(/@return \{([^}]+)\}[\s\S]*?\*\/\s*(?:static )?(\w+)\(/g)) c.returns[m[2]] = m[1];
}
// JSDoc names that are upstream classes refer to them, except AudioContext: upstream's
// class is static-only, so `{AudioContext}` on a field is the native context.
const threeType = (t) => {
  t = (t ?? '').replace(/^\?/, '').split('|')[0].trim();
  if (t === 'AudioContext' || t === 'Window.AudioContext') return { dom: 'AudioContext' };
  if (THREE[t]) return { three: t };
  const arr = /^Array<(\w+)>$/.exec(t);
  if (arr) return { array: resolveJsDoc(arr[1]) };
  if (domType(t)) return { dom: t };
  return null;
};
const resolveJsDoc = (t) => threeType(t);
function threeMember(cls, name) {
  for (let c = cls; c && THREE[c]; c = THREE[c].parent) {
    if (THREE[c].fields[name]) return { kind: 'field', type: resolveJsDoc(THREE[c].fields[name]) };
    if (THREE[c].returns[name]) return { kind: 'method', type: resolveJsDoc(THREE[c].returns[name]) };
  }
  return null;
}

// ---- scan member chains
const strip = (s) => s.replace(/\/\*[\s\S]*?\*\//g, (m) => m.replace(/[^\n]/g, ' ')).replace(/\/\/.*$/gm, '').replace(/'[^'\n]*'/g, "''");
function matching(s, i, open, close) {
  let d = 0;
  for (let j = i; j < s.length; j++) { if (s[j] === open) d++; else if (s[j] === close && --d === 0) return j; }
  return s.length;
}
const usage = new Map();
const record = (key, info) => { if (!usage.has(key)) usage.set(key, { ...info, sites: [] }); usage.get(key).sites.push(info.site); };

for (const f of files) {
  const src = strip(sources[f]);
  const cls = Object.keys(THREE).find((k) => THREE[k].file === f);
  // methods: one tab of indentation inside the class
  const methods = [...src.matchAll(/^\t(?:static )?(\w+)\(([^)]*)\) \{$/gm)].map((m) => ({ name: m[1], params: m[2], start: m.index }));
  methods.forEach((m, i) => (m.end = i + 1 < methods.length ? methods[i + 1].start : src.length));
  const raw = sources[f];
  for (const m of methods) {
    const body = src.slice(m.start, m.end);
    const env = Object.assign(Object.create(null), { this: { three: cls }, window: { window: true } });
    // @param types from the JSDoc just before the method in the raw source
    const doc = raw.slice(0, m.start).split('/**').pop();
    for (const pm of doc.matchAll(/@param \{([^}]+)\} \[?(\w+)/g)) if (m.params.includes(pm[2])) env[pm[2]] = resolveJsDoc(pm[1]);
    const evalChain = (startIdx, text) => {
      // parse root identifier
      const rm = /^[A-Za-z_$][\w$]*/.exec(text.slice(startIdx));
      let i = startIdx + rm[0].length;
      let type = env[rm[0]] ?? null;
      let label = rm[0];
      for (;;) {
        const rest = text.slice(i);
        const mm = /^\s*\.\s*([A-Za-z_$][\w$]*)/.exec(rest);
        if (mm) {
          const name = mm[1];
          const after = text.slice(i + mm[0].length);
          const isCall = /^\s*\(/.test(after);
          const isSet = /^\s*=(?!=)/.test(after);
          const access = isCall ? 'call' : isSet ? 'set' : 'get';
          let next = null;
          if (type?.window) {
            record(`window.${name} ${access}`, { iface: 'window', member: name, access, site: `${f}:${m.name}` });
          } else if (type?.dom) {
            const found = findMember(type.dom, name);
            if (found) {
              record(`${found.owner}.${name} ${access}`, { iface: found.owner, member: name, access, site: `${f}:${m.name}` });
              next = domType(found.type) ? { dom: domType(found.type) } : null;
            } else {
              const subs = Object.keys(ifaces).filter((k) => k !== type.dom && isSubtype(k, type.dom) && /Node$/.test(k) && findMember(k, name)).map((k) => findMember(k, name).owner);
              const owners = [...new Set(subs)].sort();
              record(`${owners.join('|')}.${name} ${access} downcast`, { iface: owners.join('|'), member: name, access, downcast: type.dom, site: `${f}:${m.name}` });
              const t = owners.length ? findMember(owners[0], name).type : null;
              next = domType(t) ? { dom: domType(t) } : null;
            }
          } else if (type?.three) {
            const tm = threeMember(type.three, name);
            next = tm?.type ?? null;
          }
          label += '.' + name;
          i += mm[0].length;
          type = next;
          continue;
        }
        const pm = /^\s*\(/.exec(rest);
        if (pm) { i = matching(text, i + pm[0].length - 1, '(', ')') + 1; continue; }
        const bm = /^\s*\[/.exec(rest);
        if (bm) { i = matching(text, i + bm[0].length - 1, '[', ']') + 1; type = type?.array ?? null; continue; }
        break;
      }
      return { type, end: i };
    };
    // locals: `const x = <chain>` / `let x = <chain>` take the chain's type
    for (const lm of body.matchAll(/(?:const|let) (\w+) = (?=[A-Za-z_$])/g)) {
      const r = evalChain(lm.index + lm[0].length, body);
      if (r.type) env[lm[1]] = r.type;
    }
    for (const cm of body.matchAll(/(?<![\w$.])[A-Za-z_$][\w$]*/g)) {
      if (!(cm[0] in env)) continue;
      evalChain(cm.index, body);
    }
  }
}

const list = [...usage.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([key, v]) => ({ key, ...v, sites: [...new Set(v.sites)] }));
for (const u of list) console.log(`${u.key.padEnd(58)} ${u.sites.join(', ')}`);
console.log(`${list.length} members`);
if (jsonOut) fs.writeFileSync(jsonOut, JSON.stringify(list, null, 1));
