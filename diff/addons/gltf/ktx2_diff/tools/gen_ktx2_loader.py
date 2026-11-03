# Writes src/addons/loaders/ktx2_loader.mbt from ktx2_loader.template.mbt, splicing in
# upstream's KTX2Loader.BasisWorker function source verbatim as `#|` lines.
#   python3 gen_ktx2_loader.py [--check]   (--check: exit 1 if the file is out of date)
import os, re, sys
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(here, '../../../..'))
from lib.env import REPO, UPSTREAM, out_dir  # noqa: E402
check = '--check' in sys.argv
target = REPO / 'src/addons/loaders/ktx2_loader.mbt'
lines = (UPSTREAM / 'examples/jsm/loaders/KTX2Loader.js').read_text().split('\n')
start = lines.index('KTX2Loader.BasisWorker = function () {')
end = start + lines[start:].index('};')
fn_lines = ['function () {'] + lines[start + 1:end] + ['}']
spliced = '\n'.join('  #|' + l for l in fn_lines)
tpl = open(os.path.join(here, 'ktx2_loader.template.mbt')).read()
assert tpl.count('@@BASIS_WORKER@@') == 1
generated = tpl.replace('@@BASIS_WORKER@@', spliced)
if check:
    if target.read_text() != generated:
        sys.exit(f'{target.relative_to(REPO)} is out of date (run diff/addons/gltf/ktx2_diff/tools/gen_ktx2_loader.py)')
else:
    target.write_text(generated)
# also write the expected function source (for reading; run.mjs compares the live one)
(out_dir('addons_ktx2') / 'basis_worker_expected.js').write_text('\n'.join(fn_lines))
# check FORMAT_MAP / TYPE_MAP against upstream
src = '\n'.join(lines)
for name, mname in (('FORMAT_MAP', 'ktx2_format_map'), ('TYPE_MAP', 'ktx2_type_map')):
    up = re.search(r'const ' + name + r' = \{(.*?)\n\};', src, re.S).group(1)
    up_pairs = re.findall(r'\[ (VK_FORMAT_\w+) \]: (\w+),', up)
    mine = re.search(r'let ' + mname + r' : Map\[Int(?:32)?, Int(?:32)?\] = Map::from_array\(\[(.*?)\n\]\)', tpl, re.S).group(1)
    my_pairs = re.findall(r'\(@libs\.(VK_FORMAT_\w+), @core\.(\w+)\),', mine)
    assert up_pairs == my_pairs, (name, set(up_pairs) ^ set(my_pairs))
    print(name, len(up_pairs), 'pairs identical')
print(len(fn_lines), 'worker lines;', target.relative_to(REPO), 'is up to date' if check else 'written')
