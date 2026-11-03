// Synthetic UltraHDR containers for paths the example files do not reach: ISO 21496-1
// metadata (common and separate denominators), XMP variants, and failure cases.
const be16 = (v) => [(v >> 8) & 255, v & 255];
const be32 = (v) => [(v >>> 24) & 255, (v >>> 16) & 255, (v >>> 8) & 255, v & 255];
const le32 = (v) => [v & 255, (v >>> 8) & 255, (v >>> 16) & 255, (v >>> 24) & 255];
const seg = (marker, body) => [0xff, marker, ...be16(body.length + 2), ...body];
const ascii = (s) => [...new TextEncoder().encode(s)];
const fakeJpeg = (w, h, extra = []) => [0xff, 0xd8, ...extra, ...seg(0xc0, [8, ...be16(h), ...be16(w), 3, 1, 0x11, 0, 2, 0x11, 1, 3, 0x11, 1]), 0xff, 0xd9];
const xmp = (attrs) => seg(0xe1, ascii('http://ns.adobe.com/xap/1.0/\0<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF><rdf:Description ' + Object.entries(attrs).map(([k, v]) => `hdrgm:${k}="${v}"`).join(' ') + '/></rdf:RDF></x:xmpmeta>'));
const container = seg(0xe1, ascii('http://ns.adobe.com/xap/1.0/\0<x:xmpmeta><rdf:RDF><rdf:Description><Container:Directory><rdf:Seq/></Container:Directory></rdf:Description></rdf:RDF></x:xmpmeta>'));
function iso(common, backward, vals) {
  const ns = ascii('urn:iso:std:iso:ts:21496:-1\0');
  const b = [0, 0, 0, 0, (common ? 8 : 0) | (backward ? 4 : 0)];
  if (common) { b.push(...be32(vals.d)); for (const v of vals.n) b.push(...be32(v >>> 0)); }
  else for (const [n, d] of vals.nd) b.push(...be32(n >>> 0), ...be32(d));
  // upstream compares the namespace from section[ 2 ], the segment length field, so the
  // length must read as 'ur' (0x7572) for the ISO branch to run
  const out = [0xff, 0xe2, ...ns, ...b];
  while (out.length < 2 + 0x7572) out.push(0);
  return out;
}
// MPF with offsets patched once the layout is known
function assemble(metaSegs, primaryW, primaryH, gain, opts = {}) {
  const mpfBody = () => { const b = [...ascii('MPF\0'), 0x49, 0x49, 0x2a, 0]; while (b.length < 58) b.push(0); return b; };
  const build = (pSize, gOff, gSize) => {
    const body = mpfBody();
    body.push(...le32(pSize), ...le32(0), 0, 0, 0, 0, ...le32(0), ...le32(gSize), ...le32(gOff), 0, 0, 0, 0);
    return seg(0xe2, body);
  };
  let mpf = build(0, 0, 0);
  const pre = [0xff, 0xd8, ...metaSegs.flat()];
  const mpfPos = pre.length;
  const primaryRest = fakeJpeg(primaryW, primaryH).slice(2);
  let primary = [...pre, ...mpf, ...primaryRest];
  const gOffAbs = primary.length;
  const sectionOffset = mpfPos + 2;
  mpf = build(primary.length, gOffAbs - sectionOffset - 6 + (opts.gainShift || 0), gain.length);
  primary = [...pre, ...mpf, ...primaryRest];
  return new Uint8Array([...primary, ...gain]);
}
export function build() {
  const good = { Version: '1.0', GainMapMin: '0.1', GainMapMax: '3.5', Gamma: '2.2', OffsetSDR: '0.015625', OffsetHDR: '0.015625', HDRCapacityMin: '0', HDRCapacityMax: '3.5' };
  return {
    xmp_gamma: assemble([container, xmp(good)], 24, 16, [0xff, 0xd8, ...xmp(good).slice(0), ...fakeJpeg(12, 8).slice(2)]),
    xmp_defaults: assemble([xmp({ Version: '1.0' })], 20, 20, fakeJpeg(10, 10)),
    xmp_hdr_base: assemble([xmp({ ...good, BaseRenditionIsHDR: 'True', Gamma: '1' })], 16, 8, fakeJpeg(16, 8)),
    iso_common: assemble([iso(true, false, { d: 1000, n: [0, 3000, -500, 4000, 1000, 15, 15] })], 32, 16, fakeJpeg(8, 4)),
    iso_separate: assemble([iso(false, true, { nd: [[1, 2], [7, 2], [-1, 4], [9, 2], [22, 10], [1, 64], [1, 64]] })], 18, 12, fakeJpeg(9, 6)),
    no_version: assemble([container], 16, 16, fakeJpeg(8, 8)),
    no_mpf: new Uint8Array([0xff, 0xd8, ...xmp(good), ...fakeJpeg(8, 8).slice(2)]),
    aspect: assemble([xmp(good)], 32, 16, fakeJpeg(10, 10)),
    bad_gainmap: assemble([xmp(good)], 16, 16, [0xff, 0xd8, 0xff, 0xd9]),
    short_app2: new Uint8Array([0xff, 0xd8, 0xff, 0xe2, 0, 1, 0xff, 0xd9]),
    mpf_oob: assemble([xmp(good)], 16, 16, fakeJpeg(8, 8), { gainShift: 100000 }),
    empty: new Uint8Array(0),
  };
}
