#!/usr/bin/env python3
# A4 blur-group bug injection (Gaussian blur, depth of field, sharpen): each bug is applied,
# then the shader harness (group blur) and the blur mock-GPU scenarios run; restored after.
#   python3 diff/addons/tsl/a4/inject_blur.py [index ...]   (INJECT_DRY_RUN=1: check patterns)
import pathlib, subprocess, sys
sys.path.insert(0, str(next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'lib/env.py').exists())))
from lib.env import REPO, DIFF  # noqa: E402
from lib.inject import patched, DRY_RUN  # noqa: E402
TSL = 'src/addons/tsl/'                   # the A4 sources (repo-relative)
SD = DIFF / 'core/webgpu/shader_diff'     # run_a4.mjs --group <g>: WGSL/GLSL byte-diff
G9 = DIFF / 'core/g9'                     # mbt/ (MoonBit side) and harness/run_a4.mjs: mock GPU
bugs=[
 ('display_gaussian_blur_node.mbt','    sum += 2.0 * w\n','    sum += w\n','coefficient normalization'),
 ('display_gaussian_blur_node.mbt','gaussian_blur_node_math_round(width * self.resolution_scale)','gaussian_blur_node_math_round(width)','setSize ignores resolutionScale (width)'),
 ('display_depth_of_field_node.mbt','acc.div_assign(64)','acc.div_assign(63)','blur64 average divisor'),
 ('display_depth_of_field_node.mbt','if i % 5 == 0 {','if i % 4 == 0 {','Vogel kernel split'),
 ('display_sharpen_node.mbt','@nodes.float(0.25 - 1.0 / 16.0)','@nodes.float(0.25 - 1.0 / 8.0)','RCAS limit'),
 ('display_depth_of_field_node.mbt','depth_of_field_node_math_round(width / 2.0)','depth_of_field_node_math_round(width / 4.0)','half resolution blur targets'),
 ('display_depth_of_field_node.mbt','    Some(self._coc_rt.textures[1]),\n','    Some(self._coc_rt.textures[0]),\n','far field CoC texture'),
]
which=[int(a) for a in sys.argv[1:]] or range(len(bugs))
def run(cmd,cwd):
    r=subprocess.run(cmd,cwd=cwd,shell=True,capture_output=True,text=True)
    return r.stdout+r.stderr
for i in which:
    f,old,new,desc=bugs[i]
    s=(REPO / TSL / f).read_text()
    if s.count(old)!=1:
        print(i,'PATTERN COUNT',s.count(old),desc); continue
    with patched(TSL + f, old, new):
        if DRY_RUN:
            print(i, 'pattern ok:', desc); continue
        sh=run('node run_a4.mjs --group blur',SD)
        shl=sh.strip().split('\n')[-1]
        b=run('moon build --target js',G9 / 'mbt')
        mk=run('node run_a4.mjs --quiet a4_blur_gaussian a4_blur_gaussian_premultiplied a4_blur_dof a4_blur_sharpen',G9 / 'harness')
        mkl=mk.strip().split('\n')[-1]
        if 'Error' in b and 'failed' in b: mkl='BUILD FAILED '+mkl
        print(f'{i} [{desc}] shader: {shl} | mock: {mkl}',flush=True)
if not DRY_RUN: run('moon build --target js',G9 / 'mbt')
