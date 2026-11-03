#!/usr/bin/env python3
# A4 ssr-group bug injection (SSR, recurrent denoise): one bug at a time; each must be caught
# by the shader diff (group ssr) or the mock-GPU harness. The file is restored after.
#   python3 diff/addons/tsl/a4/inject_ssr.py [index ...]   (INJECT_DRY_RUN=1: check patterns)
import pathlib, subprocess, sys
sys.path.insert(0, str(next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'lib/env.py').exists())))
from lib.env import REPO, DIFF  # noqa: E402
from lib.inject import patched, DRY_RUN  # noqa: E402
TSL = 'src/addons/tsl/'                   # the A4 sources (repo-relative)
SD = DIFF / 'core/webgpu/shader_diff'     # run_a4.mjs --group <g>: WGSL/GLSL byte-diff
G9 = DIFF / 'core/g9'                     # mbt/ (MoonBit side) and harness/run_a4.mjs: mock GPU
BUGS = [
  ('vogel disk golden angle truncated', 'display_recurrent_denoise_node.mbt', 'i.add(0.5).mul(2.399827721492203)', 'i.add(0.5).mul(2.399827721492)', 'shader'),
  ('mirror attenuation not squared', 'display_ssr_node.mbt', 'let attenuation = ratio.mul(ratio).to_var()', 'let attenuation = ratio.to_var()', 'shader'),
  ('module Fns map_ao / hit-dist factor created out of order (fn<id> names)', 'display_recurrent_denoise_node.mbt', None, None, 'shader'),
  ('ortho camera uses perspectiveDepthToViewZ', 'display_ssr_node.mbt', '@nodes.orthographic_depth_to_view_z.call([', '@nodes.perspective_depth_to_view_z.call([', 'shader'),
  ('blur mip loop skips the copy level', 'display_ssr_node.mbt', 'for i = 0; i < blur_render_target.texture().mipmaps.length(); i = i + 1 {', 'for i = 1; i < blur_render_target.texture().mipmaps.length(); i = i + 1 {', 'mock'),
  ('noise index advances by 2', 'display_ssr_node.mbt', 'a4_uniform_number(self._noise_index) + 1.0', 'a4_uniform_number(self._noise_index) + 2.0', 'mock'),
  ('denoise restart clear skipped', 'display_recurrent_denoise_node.mbt', 'if needs_restart == true {', 'if needs_restart == false {', 'mock'),
  ('specular dominant factor drops roughness', 'display_ssr_node.mbt', '.call([ggx_sample.get("NdotV"), roughness])', '.call([ggx_sample.get("NdotV"), metalness])', 'shader'),
]
def one(i):
  name, f, old, new, kind = BUGS[i]
  src = (REPO / TSL / f).read_text()
  if old is None:
    # swap the statements creating map_ao and compute_hit_dist_factor
    a = src.index('  // Maps world-space SSR ray length')
    b = src.index('  // Maps an AO factor')
    c = src.index('  // Specular dominant direction.')
    old, new = src[a:c], src[b:c] + src[a:b]
  else:
    assert src.count(old) == 1, (name, src.count(old))
  with patched(TSL + f, old, new):
    if DRY_RUN:
      print(f'[{i}] pattern ok: {name}'); return
    if kind == 'shader':
      r = subprocess.run(['node', 'run_a4.mjs', '--group', 'ssr'], cwd=SD, capture_output=True, text=True)
      out = r.stdout.strip().split('\n')
      summary = out[-1]
      mism = [l for l in out if l.startswith('MISMATCH') or l.startswith('MISSING')]
    else:
      subprocess.run(['moon', 'build', '--target', 'js'], cwd=G9 / 'mbt', capture_output=True, text=True)
      r = subprocess.run(['node', 'run_a4.mjs', 'a4_ssr_mirror', 'a4_ssr_stochastic_denoise', 'a4_ssr_env_refine', 'a4_ssr_denoise_diffuse_ao'], cwd=G9 / 'harness', capture_output=True, text=True)
      out = r.stdout.strip().split('\n')
      summary = out[-1]
      mism = [l[:120] for l in out if l.startswith('DIFF') or l.startswith('FAIL')]
    caught = r.returncode != 0
    print(f'[{i}] {name}: {"CAUGHT" if caught else "MISSED"} ({summary}); {mism[:4]}', flush=True)
  return kind
kinds = [one(i) for i in ([int(a) for a in sys.argv[1:]] or range(len(BUGS)))]
if 'mock' in kinds: subprocess.run(['moon', 'build', '--target', 'js'], cwd=G9 / 'mbt', capture_output=True)
