import { spawnSync } from 'node:child_process';
for (const n of process.argv.slice(2)) {
  const r = spawnSync(process.execPath, ['upstream_one.mjs', n], { encoding: 'utf8', maxBuffer: 1 << 28, timeout: 60000, env: { ...process.env, G10_MESSAGES: '1' } });
  const lines = (r.stdout || '').trim().split('\n');
  let l; try { l = JSON.parse(lines[lines.length - 1]); } catch (e) { console.log(n, 'PARSE ERROR', (r.stderr||'').slice(0, 500)); continue; }
  const counts = {};
  for (const x of l) { const k = x.split('(')[0]; counts[k] = (counts[k] || 0) + 1; }
  console.log('==', n, l.length, (r.stderr || '').split('\n').filter(x=>x).slice(0,4).join(' | ').slice(0, 400));
  console.log('   notes:', l.filter((x) => x.startsWith('#') && !x.startsWith('# getContext') && !x.startsWith('# canvas')).slice(-8).join(' ; ').slice(0, 600));
  console.log('   ', Object.entries(counts).filter(([k, v]) => /draw|Query|query|blit|copy|readPixels|clear|viewport|scissor|delete|lose|TransformFeedback|getBufferSubData/i.test(k)).map(([k, v]) => k + ':' + v).join(' '));
}
