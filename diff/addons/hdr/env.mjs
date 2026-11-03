// Shared Node stand-ins for both sides: fetch/Request serving files (or in-memory
// buffers), ProgressEvent, and the texture/texData describer used for comparison.
import crypto from 'node:crypto';
import fs from 'node:fs';

export const routes = new Map(); // url -> Uint8Array
class MockRequest {
  constructor(url, init = {}) { this.url = url; this.headers = init.headers; this.credentials = init.credentials; this.signal = init.signal; }
}
class MockProgressEvent { constructor(type, init) { Object.assign(this, init); this.type = type; } }
export function install() {
  globalThis.Request = MockRequest;
  globalThis.ProgressEvent = MockProgressEvent;
  globalThis.fetch = (req) => {
    const url = req.url || req;
    let bytes = routes.get(url);
    if (!bytes && fs.existsSync(url)) bytes = new Uint8Array(fs.readFileSync(url));
    if (!bytes) return Promise.resolve(new Response('missing', { status: 404, statusText: 'Not Found' }));
    return Promise.resolve(new Response(bytes, { status: 200 }));
  };
  globalThis.__describe = (t, e) => ({ texture: describeTexture(t), texData: describeTexData(e) });
  globalThis.__describeTexture = (t) => describeTexture(t);
}

export function hashData(d) {
  if (d === undefined) return 'undefined';
  if (d === null) return 'null';
  if (!ArrayBuffer.isView(d)) return 'non-typed:' + typeof d;
  const h = crypto.createHash('sha256').update(new Uint8Array(d.buffer, d.byteOffset, d.byteLength)).digest('hex');
  return `${d.constructor.name}[${d.length}]:${h.slice(0, 24)}`;
}

export function describeImage(img) {
  if (img === undefined || img === null) return String(img);
  if (Array.isArray(img)) return Array.from(img, (x) => describeImage(x)); // holes read as undefined, the port's NoImage
  if (img.isTexture) return describeTexture(img);
  if (img.image !== undefined && img.format !== undefined) return describeTexture(img);
  return { width: img.width, height: img.height, data: hashData(img.data) };
}

export function describeTexture(t) {
  return {
    image: describeImage(t.image), format: t.format, type: t.type, colorSpace: t.colorSpace, flipY: t.flipY,
    minFilter: t.minFilter, magFilter: t.magFilter, wrapS: t.wrapS, wrapT: t.wrapT, mapping: t.mapping,
    anisotropy: t.anisotropy, generateMipmaps: t.generateMipmaps,
    mipmaps: typeof t.mipmaps === 'number' ? t.mipmaps : (t.mipmaps ? t.mipmaps.length : 0), version: t.version,
  };
}

export function describeTexData(e) {
  if (!e) return e;
  const out = {};
  for (const k of Object.keys(e).sort()) {
    if (e[k] === undefined) continue;
    out[k] = k === 'data' ? hashData(e[k]) : e[k];
  }
  return JSON.parse(JSON.stringify(out));
}

// --- UltraHDR stand-ins: createImageBitmap reads the JPEG SOF size and fills pixels
// from a hash of the bytes; the 2D canvas scales with nearest neighbour; DOMParser is a
// tiny tag/attribute matcher. Both sides run against the same objects.
function jpegSize(b) {
  let o = 2;
  while (o + 9 < b.length) {
    if (b[o] !== 0xff) { o++; continue; }
    const m = b[o + 1];
    if (m >= 0xc0 && m <= 0xcf && m !== 0xc4 && m !== 0xc8 && m !== 0xcc) return { h: (b[o + 5] << 8) | b[o + 6], w: (b[o + 7] << 8) | b[o + 8] };
    if (m === 0xd8 || (m >= 0xd0 && m <= 0xd7) || m === 0x01) { o += 2; continue; }
    o += 2 + ((b[o + 2] << 8) | b[o + 3]);
  }
  return null;
}
export const bitmapLog = [];
export function installUltra(opts = {}) {
  globalThis.createImageBitmap = async (blob) => {
    const b = new Uint8Array(await blob.arrayBuffer());
    const s = jpegSize(b);
    bitmapLog.push(`bitmap ${blob.type} ${b.length} ${s ? s.w + 'x' + s.h : 'none'}`);
    if (!s) throw new Error('stub: undecodable image');
    let h = 2166136261 >>> 0;
    for (let i = 0; i < b.length; i += 97) h = Math.imul(h ^ b[i], 16777619) >>> 0;
    const scale = opts.scale || 1;
    return { width: Math.max(1, Math.round(s.w / scale)), height: Math.max(1, Math.round(s.h / scale)), seed: h, close() {} };
  };
  const pix = (img, x, y, c) => { let t = (img.seed ^ Math.imul(x + 1, 73856093) ^ Math.imul(y + 1, 19349663) ^ Math.imul(c + 1, 83492791)) >>> 0; t = Math.imul(t ^ (t >>> 15), 2246822507) >>> 0; t = Math.imul(t ^ (t >>> 13), 3266489909) >>> 0; return ((t ^ (t >>> 16)) >>> 0) & 255; };
  globalThis.document = {
    createElement(name) {
      if (name !== 'canvas') throw new Error('stub document: ' + name);
      const canvas = { width: 300, height: 150 };
      let buf = null;
      const ensure = () => { if (!buf || buf.w !== canvas.width || buf.h !== canvas.height) buf = { w: canvas.width, h: canvas.height, d: new Uint8ClampedArray(canvas.width * canvas.height * 4) }; };
      canvas.getContext = (type, options) => {
        bitmapLog.push(`getContext ${type} ${JSON.stringify(options)}`);
        return {
          drawImage(img, sx, sy, sw, sh, dx, dy, dw, dh) {
            ensure();
            if (sw === undefined) { sw = img.width; sh = img.height; dw = img.width; dh = img.height; }
            bitmapLog.push(`drawImage ${img.width}x${img.height} -> ${dw}x${dh}`);
            for (let y = 0; y < Math.min(dh, buf.h); y++) for (let x = 0; x < Math.min(dw, buf.w); x++) {
              const ix = Math.min(img.width - 1, Math.floor((x + 0.5) * sw / dw)), iy = Math.min(img.height - 1, Math.floor((y + 0.5) * sh / dh));
              for (let c = 0; c < 4; c++) buf.d[(y * buf.w + x) * 4 + c] = c === 3 ? 255 : pix(img, ix, iy, c);
            }
          },
          getImageData(x, y, w, h, settings) { ensure(); bitmapLog.push(`getImageData ${w}x${h} ${JSON.stringify(settings)}`); return { data: new Uint8ClampedArray(buf.d.slice(0, w * h * 4)), width: w, height: h }; },
        };
      };
      return canvas;
    },
  };
  class El {
    constructor(tag, attrs) { this.tag = tag; this.attrs = attrs; }
    getAttribute(n) { return Object.prototype.hasOwnProperty.call(this.attrs, n) ? this.attrs[n] : null; }
  }
  globalThis.DOMParser = class {
    parseFromString(text, mime) {
      bitmapLog.push(`DOMParser ${mime} ${text.length}`);
      return {
        getElementsByTagName(tag) {
          const out = [];
          const re = new RegExp('<' + tag.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '(\\s[^>]*?)?/?>', 'g');
          let m;
          while ((m = re.exec(text))) {
            const attrs = {};
            const ar = /([\w:.-]+)\s*=\s*"([^"]*)"/g; let a;
            while ((a = ar.exec(m[1] || ''))) attrs[a[1]] = a[2];
            out.push(new El(tag, attrs));
          }
          return out;
        },
      };
    }
  };
}
