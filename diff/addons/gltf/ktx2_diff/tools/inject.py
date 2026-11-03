# Bug injection: applies one plausible bug at a time to the port, rebuilds the harness,
# runs run.mjs and checks that it fails; always restores the file.
import subprocess, sys, pathlib
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(next(p for p in HERE.parents if (p / 'lib/env.py').exists())))
from lib.env import REPO  # noqa: E402
from lib.inject import patched, DRY_RUN  # noqa: E402
# INJECT_DRY_RUN=1 only checks that every pattern applies; after a hard kill,
# `python3 diff/lib/inject.py --restore` restores the patched file.
R = 'src/addons/'
H = HERE.parent
BUGS = [
  ('ktx-parse scan keeps the NUL in the value', 'libs/ktx_parse.mbt', '  if i < t {\n    self.offset += 1\n  }', '  if i < 0 {\n    self.offset += 1\n  }'),
  ('ktx-parse signed sample bounds inverted', 'libs/ktx_parse.mbt', '(64 & e.channel_type) != 0', '(64 & e.channel_type) == 0'),
  ('3D level depth without Math.max(1, ...)', 'loaders/ktx2_loader.mbt', 'ktx2_max1(container.pixel_depth >> level_index)', '(container.pixel_depth >> level_index)'),
  ('Display P3 transfer swapped', 'loaders/ktx2_loader.mbt', '      @addon_math.DisplayP3ColorSpace\n    } else {\n      @addon_math.LinearDisplayP3ColorSpace', '      @addon_math.LinearDisplayP3ColorSpace\n    } else {\n      @addon_math.DisplayP3ColorSpace'),
  ('Basis minFilter test inverted', 'loaders/ktx2_loader.mbt', 'get("mipmaps")) ==\n    1 {', 'get("mipmaps")) !=\n    1 {'),
  ('raw cube face length rounded to Int', 'loaders/ktx2_loader.mbt', 'let face_length = data.length().to_double() / 6.0', 'let face_length = (data.length() / 6).to_double()'),
  ('WorkerPool queue LIFO', 'utils/worker_pool.mbt', 'self.queue.remove(0)', 'self.queue.pop().unwrap()'),
  ('WorkerPool one worker too many', 'utils/worker_pool.mbt', 'for i in 0..<self.pool {', 'for i in 0..<=self.pool {'),
  ('ASTC HDR support ignored', 'loaders/ktx2_loader.mbt', '(is_basis_hdr && !self.worker_config.unwrap().astc_hdr_supported)', 'is_basis_hdr'),
  ('extra microtask on the transcoder path', 'loaders/ktx2_loader.mbt', 'resolve(texture_pending.to_js())', 'resolve(texture_pending.then_(fn(x : @core.JsValue) { x }).to_js())'),
  ('P3 primaries not shared', 'math/color_spaces.mbt', '  primaries: color_spaces_p3_primaries,\n  white_point: color_spaces_d65,\n  transfer: @math.LinearTransfer,', '  primaries: color_spaces_p3_primaries.copy(),\n  white_point: color_spaces_d65,\n  transfer: @math.LinearTransfer,'),
  ('await _zstd takes an extra tick', 'loaders/ktx2_loader.mbt', '        ktx2_zstd.val\n        .unwrap()\n        .then_(', '        ktx2_zstd.val\n        .unwrap()\n        .then_(fn(z : @core.JsValue) { z })\n        .then_('),
  ('ktx-parse identifier check skips the last byte', 'libs/ktx_parse.mbt', 'for k in 0..<12 {', 'for k in 0..<11 {'),
  ('Linux override keeps ETC2', 'loaders/ktx2_loader.mbt', '    config.etc2_supported = false\n', ''),
  ('WEBKIT pvrtc prefix ignored', 'loaders/ktx2_loader.mbt', ' ||\n    extensions.has("WEBKIT_WEBGL_compressed_texture_pvrtc")', ''),
  ('generateMipmaps always true for data textures', 'loaders/ktx2_loader.mbt', 'texture.generate_mipmaps = container.level_count == 0', 'texture.generate_mipmaps = true'),
]
only = sys.argv[1:]
results = []
for i, (name, f, old, new) in enumerate(BUGS):
  if only and str(i) not in only: continue
  path = R + f
  src = (REPO / path).read_text()
  assert src.count(old) == 1, (name, src.count(old))
  with patched(path, old, new):
    if DRY_RUN:
      results.append((name, 'applies (dry run)')); print(results[-1], flush=True); continue
    b = subprocess.run(['moon', 'build', '--target', 'js'], cwd=H, capture_output=True, text=True)
    if b.returncode != 0:
      results.append((name, 'BUILD FAILED')); print(b.stdout[-800:], b.stderr[-800:]); continue
    r = subprocess.run(['node', '--import', '../register.mjs', 'run.mjs'], cwd=H, capture_output=True, text=True, timeout=600)
    fails = [l for l in r.stdout.split('\n') if l.startswith('FAIL')]
    detail = '; '.join(x[5:] for x in fails)[:300] if fails else 'crash: ' + (r.stderr.strip().split('\n') or [''])[-1][:200] + ' / ' + ' | '.join([l for l in r.stderr.split('\n') if 'Error' in l][:2])[:300]
    results.append((name, ('caught: ' + detail) if r.returncode != 0 else 'MISSED'))
  print(results[-1], flush=True)
if not DRY_RUN:
  subprocess.run(['moon', 'build', '--target', 'js'], cwd=H, capture_output=True)
print('\n'.join(f'{n}: {s}' for n, s in results))
