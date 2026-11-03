# Writes src/addons/libs/zstddec.mbt with examples/jsm/libs/zstddec.module.js embedded
# verbatim; only the trailing ES export becomes a `return`, as a bundler rewrites it.
#   python3 gen_zstddec.py [--check]   (--check: exit 1 if the file is out of date)
# The output is formatted with `moonfmt -w`, as the committed file is.
import os, subprocess, sys, tempfile
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../../..'))
from lib.env import REPO, UPSTREAM  # noqa: E402
check = '--check' in sys.argv
target = REPO / 'src/addons/libs/zstddec.mbt'
src = (UPSTREAM / 'examples/jsm/libs/zstddec.module.js').read_text()
assert '\n' not in src.rstrip('\n'), 'expected a one-line module'
src = src.rstrip('\n')
export = 'export{Q as ZSTDDecoder};'
assert src.endswith(export) and src.count('export{') == 1
body = src[: -len(export)] + 'return {ZSTDDecoder: Q};'
out = f'''// Upstream examples/jsm/libs/zstddec.module.js: zstd decoding in WebAssembly, bound
// through JS. Upstream KTX2Loader imports the module statically, so it is part of the
// bundle; the module text is embedded verbatim (written by the ktx2_diff tools/
// gen_zstddec.py script), with its ES `export` turned into a `return`, as a bundler
// does. It is evaluated on first use.

///|
/// A zstd decoder instance (upstream `ZSTDDecoder`).
#external
pub type ZSTDDecoder

///|
/// The module body; returns its exports.
extern "js" fn zstd_evaluate_module() -> @core.JsValue =
  #|() => {{
  #|{body}
  #|}}

///|
let zstd_exports : Ref[@core.JsValue?] = Ref(None)

///|
fn zstd_decoder_class() -> @core.JsValue {{
  match zstd_exports.val {{
    Some(exports) => exports.get("ZSTDDecoder")
    None => {{
      let exports = zstd_evaluate_module()
      zstd_exports.val = Some(exports)
      exports.get("ZSTDDecoder")
    }}
  }}
}}

///|
extern "js" fn zstd_new(cls : @core.JsValue) -> ZSTDDecoder = "(C) => new C()"

///|
extern "js" fn zstd_init(decoder : ZSTDDecoder) -> @core.JsValue = "(d) => d.init()"

///|
extern "js" fn zstd_decode(
  decoder : ZSTDDecoder,
  array : @core.TypedArray,
  uncompressed_size : Double,
) -> @core.TypedArray = "(d, a, n) => d.decode(a, n)"

///|
/// `new ZSTDDecoder()`.
pub fn ZSTDDecoder::new() -> ZSTDDecoder {{
  zstd_new(zstd_decoder_class())
}}

///|
/// `decoder.init()`: a JS `Promise` resolved once the WebAssembly module is instantiated.
pub fn ZSTDDecoder::init(self : ZSTDDecoder) -> @core.JsValue {{
  zstd_init(self)
}}

///|
/// `decoder.decode( array, uncompressedSize )`; throws (JS) before `init` resolved.
pub fn ZSTDDecoder::decode(
  self : ZSTDDecoder,
  array : @core.TypedArray,
  uncompressed_size? : Double = 0.0,
) -> @core.TypedArray {{
  zstd_decode(self, array, uncompressed_size)
}}
'''
with tempfile.TemporaryDirectory() as d:
    tmp = os.path.join(d, 'zstddec.mbt')
    open(tmp, 'w').write(out)
    subprocess.run(['moonfmt', '-w', tmp], check=True)
    out = open(tmp).read()
if check:
    if target.read_text() != out:
        sys.exit(f'{target.relative_to(REPO)} is out of date (run diff/addons/gltf/ktx2_diff/tools/gen_zstddec.py)')
    print(target.relative_to(REPO), 'is up to date')
else:
    target.write_text(out)
    print(target.relative_to(REPO), 'written')
