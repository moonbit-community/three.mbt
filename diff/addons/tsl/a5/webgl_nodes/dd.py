# python3 dd.py <scenario> [n]: the first n differing runs of one scenario's logs, from the
# last run.mjs (OUT/addons_a5_webgl_nodes/last_{up,mb}.json).
import json,sys,difflib,pathlib
sys.path.insert(0, str(next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'lib/env.py').exists())))
from lib.env import OUT
D = OUT / 'addons_a5_webgl_nodes'
name=sys.argv[1]
u=json.load(open(D / 'last_up.json'))[name]; m=json.load(open(D / 'last_mb.json'))[name]
cut=lambda s: s if len(s)<300 else s[:300]+'...'
sm=difflib.SequenceMatcher(None,u,m,autojunk=False)
n=0
for tag,i1,i2,j1,j2 in sm.get_opcodes():
    if tag=='equal': continue
    print(tag,i1,i2,j1,j2)
    for x in u[i1:i2][:6]: print('  up:',cut(x))
    for x in m[j1:j2][:6]: print('  mb:',cut(x))
    n+=1
    if n>int(sys.argv[2] if len(sys.argv)>2 else 10): break
