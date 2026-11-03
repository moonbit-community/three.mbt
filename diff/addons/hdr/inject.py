#!/usr/bin/env python3
"""Bug injection: applies one plausible bug at a time to the port's real files
(src/addons/loaders, src/addons/libs), rebuilds the harness module (mod/), runs the check
that should catch it, and restores the file (diff/lib/inject.py; also on Ctrl-C).
    python3 inject.py [name ...]      # all bugs, or the named ones
    INJECT_DRY_RUN=1 python3 inject.py   # only check that every pattern still occurs
Do not run it while other harnesses use the same tree.
"""
import subprocess, sys, pathlib
sys.path.insert(0, str(next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'lib/env.py').exists())))
from lib.env import REPO  # noqa: E402
from lib.inject import patched, DRY_RUN, InjectionNotApplied  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
EXR = 'src/addons/loaders/exr_loader.mbt'
HDR = 'src/addons/loaders/hdr_loader.mbt'
UHDR = 'src/addons/loaders/ultra_hdr_loader.mbt'
CUBE = 'src/addons/loaders/hdr_cube_texture_loader.mbt'
FF = 'src/addons/libs/fflate_module.mbt'
UNIT = ('repo', ['moon', 'test', '--target', 'js', '-p', 'moonbit-community/three/addons/loaders'])
run_exr = lambda f: ['node', 'run.mjs', '--only', 'exr', '--filter', f]
BUGS = [
  ('piz-wavelet', EXR, 'let ai = ls + (hi & 1) + (hi >> 1)', 'let ai = ls + (hi >> 1)', run_exr(r'memorial|rgb_half_big\.piz')),
  ('piz-wdec16', EXR, 'let bb = (m - (d >> 1)) & EXR_MOD_MASK', 'let bb = (m - (d >> 2)) & EXR_MOD_MASK', run_exr(r'rgb_ramp_big\.piz')),
  ('huffman-canonical', EXR, 'hcode[i] = l | (buffer[l] << 6)\n      buffer[l] += 1', 'buffer[l] += 1\n      hcode[i] = l | (buffer[l] << 6)', run_exr(r'memorial|y_half\.piz')),
  ('huffman-run', EXR, 'cs = cs & 0xff', 'cs = cs & 0x7f', run_exr(r'rgb_flat_big\.piz')),
  ('huffman-run-value', EXR, 'let s = out_buffer[out_buffer_offset.val - 1]', 'let s = out_buffer[out_buffer_offset.val - 2]', run_exr(r'rgb_flat_big\.piz|memorial')),
  ('half-decode-float32', EXR, '@core.to_half_float(exr_parse_float32(data_view, offset))', '@core.to_half_float(exr_parse_float32(data_view, offset) * 1.0001)', run_exr(r'rgb_float\.(none|zip)')),
  ('exr-rle-run', EXR, 'for i in 0..<(count + 1) {', 'for i in 0..<count {', run_exr(r'\.rle\.|gen_rle')),
  ('exr-predictor', EXR, 'source.get_int(t) - 128', 'source.get_int(t) - 127', run_exr(r'gen_zips|\.zip\.orig')),
  ('exr-interleave', EXR, '''    out[s] = source[t1]
    s += 1
    t1 += 1''', '''    out[s] = source[t2]
    s += 1
    t1 += 1''', run_exr(r'rgba_mixed\.gen_zip|rgb_half_big\.zips|040full')),
  ('pxr24-shift', EXR, '(raw_buffer.get_int(ptr[1]) << 16)', '(raw_buffer.get_int(ptr[1]) << 15)', run_exr(r'pxr24')),
  ('b44-sign', EXR, '''            block[i] = (if (t[i] & 0x8000) != 0 {
              t[i] & 0x7fff
            } else {
              t[i].lnot() & 0xffff
            }).to_double()''', '''            block[i] = (if (t[i] & 0x8000) != 0 {
              t[i] & 0x7fff
            } else {
              t[i] & 0xffff
            }).to_double()''', run_exr(r'\.b44\.')),
  ('b44a-flat', EXR, 'src_offset += 3', 'src_offset += 2', run_exr(r'\.b44a\.')),
  ('b44-plinear', EXR, '@core.to_half_float(8.0 * exr_math_log(f))', '@core.to_half_float(8.0 * exr_math_log(f) + 0.01)', run_exr(r'rgb_plinear\.b44')),
  ('dwa-csc709', EXR, 'data[0][i] = y + 1.5747 * cr', 'data[0][i] = y + 1.5748 * cr', run_exr(r'rgb_half_big\.dwa')),
  ('dwa-rounding', EXR, 'let r = a + 0xfff + ((a >> 13) & 1)', 'let r = a + 0xfff', run_exr(r'\.dwa')),
  ('dwa-zigzag', EXR, '0, 1, 5, 6, 14, 15, 27, 28, 2, 4,', '0, 1, 5, 6, 14, 15, 28, 27, 2, 4,', run_exr(r'rgb_half_big\.dwaa\.half')),
  ('ycbcr', EXR, 'let g = (y - r * 0.2126 - b * 0.0722) / 0.7152', 'let g = (y - r * 0.2127 - b * 0.0722) / 0.7152', run_exr(r'yc_full\.(zip|none)\.orig')),
  ('tiles-x', EXR, '(x.to_double() + start_x)', 'x.to_double()', run_exr(r'tiled_one_zip')),
  ('mipmap-levels', EXR, 'num = exr_round_log2(', 'num = 1.0 + exr_round_log2(', run_exr(r'tiled_mip_(down|up)_zip')),
  ('deep-composite', EXR, 'composited[c_off] = composited[c_off] + value * factor', 'composited[c_off] = composited[c_off] + value', run_exr(r'deep_rgba\.none')),
  ('multipart-skip', EXR, 'offset.val += EXR_INT32_SIZE // skip part number', 'offset.val += 0 // skip part number', run_exr(r'multipart')),
  ('header-chlist', EXR, 'offset.val += 3 // reserved, three chars', 'offset.val += 2 // reserved, three chars', run_exr(r'rgba_half\.gen_none')),
  ('expand-y', EXR, 'byte_array[i + 2] = byte_array[i + 1]', 'byte_array[i + 2] = 0', run_exr(r'y_half\.gen_none')),
  ('hdr-exponent', HDR, 'let scale = hdr_math_pow(2.0, e - 128.0) / 255.0\n  // clamping', 'let scale = hdr_math_pow(2.0, e - 127.0) / 255.0\n  // clamping', ['node', 'run.mjs', '--only', 'hdr', '--filter', 'spot1Lux']),
  ('hdr-rle', HDR, 'count -= 128', 'count -= 127', ['node', 'run.mjs', '--only', 'hdr', '--filter', 'memorial']),
  ('hdr-gamma-parse', HDR, 'header.gamma = hdr_parse_float(hdr_match_group(m, 1))', 'header.gamma = hdr_parse_int(hdr_match_group(m, 1))', UNIT),
  ('cube-type', CUBE, 'data_texture.type_ = texture.type_', 'data_texture.type_ = @core.HalfFloatType', ['node', 'run.mjs', '--only', 'cube']),
  ('ultra-boost', UHDR, '1.8,\n', '2.0,\n', ['node', 'run.mjs', '--only', 'ultra', '--filter', 'none']),
  ('ultra-iso-offset', UHDR, 'offset_sdr = offset_sdr_n / offset_sdr_d * 255.0', 'offset_sdr = offset_sdr_n / offset_sdr_d * 256.0', ['node', 'run.mjs', '--only', 'ultra', '--filter', 'none']),
  ('ultra-srgb', UHDR, 'if value < 10.31475 {', 'if value <= 10.31475 + 1.0 {', ['node', 'run.mjs', '--only', 'ultra', '--filter', 'none']),
  ('fflate-length-extra', FF, 'if sym > 264 {', 'if sym > 265 {', ['node', 'fflate_diff.mjs', '200']),
  ('fflate-dist-error', FF, '''          if shift + bt < 0 {
            fflate_err(3)''', '''          if shift + bt < 0 {
            fflate_err(2)''', ['node', 'fflate_diff.mjs', '200']),
  ('fflate-stored', FF, 'let t = s + l', 'let t = s + l + 1', ['node', 'fflate_diff.mjs', '200']),
]

def sh(cmd):
    """Runs a check; returns (exit code, output)."""
    cwd = HERE
    if isinstance(cmd, tuple):  # ('repo' | 'mod', argv): run in the repository root / mod/
        cwd, cmd = (REPO if cmd[0] == 'repo' else HERE / cmd[0]), cmd[1]
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=900)
        return p.returncode, p.stdout + p.stderr
    except subprocess.TimeoutExpired:
        return -1, 'TIMEOUT'


names = sys.argv[1:]
results = []
for name, path, old, new, check in BUGS:
    if names and name not in names:
        continue
    text = (REPO / path).read_text()
    if text.count(old) != 1:
        results.append((name, 'SKIP: pattern found %d times' % text.count(old)))
        print(results[-1], flush=True)
        continue
    try:
        with patched(path, old, new):
            if DRY_RUN:
                results.append((name, 'pattern found'))
                continue
            code, out = sh(('mod', ['moon', 'build', '--target', 'js']))
            if code != 0:
                results.append((name, 'BUILD FAILED'))
                continue
            code, out = sh(check)
    except InjectionNotApplied as e:
        results.append((name, 'SKIP: %s' % e))
        continue
    lines = out.splitlines()
    tail = [l for l in lines if 'identical' in l or 'passed' in l or 'MISMATCH' in l or 'failed' in l.lower()]
    mism = sum(1 for l in lines if l.startswith('MISMATCH'))
    results.append((name, ('CAUGHT' if code != 0 else 'MISSED') + ' (%d mismatching cases) %s' % (mism, (tail[-1] if tail else '').strip())))
    print(results[-1], flush=True)
if not DRY_RUN:
    sh(('mod', ['moon', 'build', '--target', 'js']))
    print('rebuilt clean')
for r in results:
    print('%-22s %s' % r)
