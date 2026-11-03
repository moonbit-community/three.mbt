#!/usr/bin/env python3
# A4 basic-group bug injection: one bug at a time in src/addons/tsl, run the shader harness
# (group basic) and, for bugs only uniforms show, the mock-GPU scenario; the file is restored
# after each (diff/lib/inject.py).
#   python3 diff/addons/tsl/a4/inject_basic.py [index ...]   (INJECT_DRY_RUN=1: check patterns)
import pathlib, subprocess, sys
sys.path.insert(0, str(next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'lib/env.py').exists())))
from lib.env import REPO, DIFF  # noqa: E402
from lib.inject import patched, DRY_RUN  # noqa: E402
TSL = 'src/addons/tsl/'                   # the A4 sources (repo-relative)
SD = DIFF / 'core/webgpu/shader_diff'     # run_a4.mjs --group <g>: WGSL/GLSL byte-diff
G9 = DIFF / 'core/g9'                     # mbt/ (MoonBit side) and harness/run_a4.mjs: mock GPU
BUGS = [
  ('display_fxaa_node.mbt', 'Number(1.5),', 'Number(1.25),', 'FXAA edge step 1.5 -> 1.25', None),
  ('display_sobel_operator_node.mbt', '[-1, 0, 1, -2, 0, 2, -1, 0, 1]', '[-1, 0, 1, 2, 0, 2, -1, 0, 1]', 'Sobel Gy kernel sign', None),
  ('display_dot_screen_node.mbt', '.mul(@nodes.sin(point.y())).mul(4)', '.mul(@nodes.sin(point.y())).mul(3)', 'DotScreen pattern gain 4 -> 3', None),
  ('display_rgb_shift_node.mbt', 'sample_texture(uv_node.sub(offset))', 'sample_texture(uv_node.add(offset))', 'RGBShift blue offset sign', None),
  ('display_depth_aware_blend.mbt', '@nodes.float(0.05).mul(correct_depth)', '@nodes.float(0.5).mul(correct_depth)', 'depthAwareBlend depth threshold', None),
  ('display_radial_blur.mbt', '@nodes.int(32)', '@nodes.int(31)', 'radialBlur default count', None),
  ('display_crt.mbt', '@nodes.float(1.42), smoothness', '@nodes.float(1.41), smoothness', 'CRT vignette radius', None),
  ('display_sobel_operator_node.mbt', '1.0 / map.image().height(),', '1.0 / map.image().width(),', 'Sobel texel size uses width for y', 'a4_sobel'),
  ('display_fxaa_node.mbt', 'self.texture_node.bias(-100)', 'self.texture_node.bias(-10)', 'FXAA mip bias -100 -> -10', None),
  ('display_bleach_bypass.mbt', 'a4_arg_or(inputs, 1, Number(1.0))', 'a4_arg_or(inputs, 1, Number(0.5))', 'bleach default opacity 1 -> 0.5', None),
]
only = [int(a) for a in sys.argv[1:]]
built = False
for i, (f, old, new, desc, mock) in enumerate(BUGS):
  if only and i not in only: continue
  with patched(TSL + f, old, new):
    if DRY_RUN:
      print(f'{i}: pattern ok: {desc}'); continue
    r = subprocess.run(['node', 'run_a4.mjs', '--group', 'basic'], cwd=SD, capture_output=True, text=True)
    out = r.stdout
    mism = out.count('MISMATCH'); missing = out.count('MISSING')
    res = f'shader: {mism} mismatched, {missing} missing'
    if mock:
      subprocess.run(['moon', 'build', '--target', 'js'], cwd=G9 / 'mbt', capture_output=True)
      built = True
      m = subprocess.run(['node', 'run_a4.mjs', mock], cwd=G9 / 'harness', capture_output=True, text=True)
      res += '; mock: ' + m.stdout.strip().split('\n')[-1]
    print(f'{i}: {desc}: {res}', flush=True)
if built: subprocess.run(['moon', 'build', '--target', 'js'], cwd=G9 / 'mbt', capture_output=True)
