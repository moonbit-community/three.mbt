// Browser stand-in for Node, shared by the upstream side and the MoonBit side of every
// a2_gltf differential test: fetch (files from disk), createImageBitmap (a fake bitmap
// with width/height read from the PNG/JPEG header and an FNV hash of the bytes), Blob
// URLs readable synchronously, and an in-process Worker that runs a worker body (from a
// Blob URL) inside `with ( scope )`, delivering messages with structuredClone (transfers
// detach, as in a real worker) on a macrotask.
//
//   import { install, BASE } from './env.mjs'; install();
//   URLs: BASE + 'models/gltf/duck.glb' reads <three.js>/examples/models/gltf/duck.glb.
import fs from 'node:fs';
import path from 'node:path';
import { UPSTREAM, outDir } from '../../lib/env.mjs';

export const EXAMPLES = path.join(UPSTREAM, 'examples') + '/';
export const BASE = 'http://local/';
// Synthetic glTF assets, written by gltf_diff/gen_fixtures.mjs (run.mjs runs it first).
export const FIXTURES = outDir('addons_gltf', 'fixtures');

const blobParts = new Map(); // object URL -> Uint8Array
const realCreateObjectURL = URL.createObjectURL.bind(URL);
const realRevokeObjectURL = URL.revokeObjectURL.bind(URL);
export const stats = { fetches: [], workers: 0, bitmaps: 0, revoked: 0 };

function partsToBytes(parts) {
  const chunks = parts.map((p) => {
    if (typeof p === 'string') return new TextEncoder().encode(p);
    if (p instanceof ArrayBuffer) return new Uint8Array(p.slice(0));
    if (ArrayBuffer.isView(p)) return new Uint8Array(p.buffer.slice(p.byteOffset, p.byteOffset + p.byteLength));
    if (p && p.__bytes) return p.__bytes;
    throw new Error('env: unsupported Blob part ' + Object.prototype.toString.call(p));
  });
  const n = chunks.reduce((a, c) => a + c.length, 0);
  const out = new Uint8Array(n);
  let o = 0;
  for (const c of chunks) { out.set(c, o); o += c.length; }
  return out;
}

class RecBlob extends Blob {
  constructor(parts = [], options) {
    super(parts, options);
    this.__bytes = partsToBytes(parts);
  }
}

export function fnv(bytes) {
  let h = 0x811c9dc5;
  for (let i = 0; i < bytes.length; i++) { h ^= bytes[i]; h = Math.imul(h, 0x01000193) >>> 0; }
  return h.toString(16).padStart(8, '0');
}

function imageSize(b) {
  // PNG
  if (b[0] === 0x89 && b[1] === 0x50) return [(b[16] << 24 | b[17] << 16 | b[18] << 8 | b[19]) >>> 0, (b[20] << 24 | b[21] << 16 | b[22] << 8 | b[23]) >>> 0];
  // JPEG: scan for SOFn
  if (b[0] === 0xff && b[1] === 0xd8) {
    let i = 2;
    while (i + 9 < b.length) {
      if (b[i] !== 0xff) { i++; continue; }
      const m = b[i + 1];
      const len = b[i + 2] << 8 | b[i + 3];
      if (m >= 0xc0 && m <= 0xcf && m !== 0xc4 && m !== 0xc8 && m !== 0xcc) return [b[i + 7] << 8 | b[i + 8], b[i + 5] << 8 | b[i + 6]];
      i += 2 + len;
    }
  }
  return [1, 1];
}

function bytesFor(url) {
  if (url.startsWith('blob:')) {
    const bytes = blobParts.get(url);
    if (!bytes) return null;
    return bytes;
  }
  if (url.startsWith(BASE + '__fixtures__/')) {
    const file = path.join(FIXTURES, decodeURIComponent(url.slice((BASE + '__fixtures__/').length).split(/[?#]/)[0]));
    if (!fs.existsSync(file)) return null;
    return new Uint8Array(fs.readFileSync(file));
  }
  if (url.startsWith(BASE)) {
    const file = path.join(EXAMPLES, decodeURIComponent(url.slice(BASE.length).split(/[?#]/)[0]));
    if (!fs.existsSync(file)) return null;
    return new Uint8Array(fs.readFileSync(file));
  }
  if (url.startsWith('data:')) {
    const comma = url.indexOf(',');
    const meta = url.slice(5, comma);
    const data = url.slice(comma + 1);
    return meta.endsWith(';base64') ? new Uint8Array(Buffer.from(data, 'base64')) : new TextEncoder().encode(decodeURIComponent(data));
  }
  return null;
}

class FakeResponse {
  constructor(url, bytes) {
    this.url = url;
    this.status = bytes ? 200 : 404;
    this.statusText = bytes ? 'OK' : 'Not Found';
    this.ok = !!bytes;
    this.headers = new Headers();
    this.body = undefined;
    this._bytes = bytes || new TextEncoder().encode('missing');
  }
  arrayBuffer() { return Promise.resolve(this._bytes.slice().buffer); }
  text() { return Promise.resolve(new TextDecoder().decode(this._bytes)); }
  json() { return this.text().then((t) => JSON.parse(t)); }
  blob() { return Promise.resolve(new RecBlob([this._bytes])); }
}

function fakeFetch(input, init) {
  const url = typeof input === 'string' ? input : input.url;
  stats.fetches.push(url);
  const bytes = bytesFor(url);
  return Promise.resolve(new FakeResponse(url, bytes));
}

function fakeCreateImageBitmap(blob, options) {
  stats.bitmaps++;
  const bytes = blob.__bytes || null;
  const go = (b) => {
    const [w, h] = imageSize(b);
    return { __bitmap: true, width: w, height: h, hash: fnv(b), byteLength: b.length, options: options || {}, close() {} };
  };
  if (bytes) return Promise.resolve(go(bytes));
  return blob.arrayBuffer().then((ab) => go(new Uint8Array(ab)));
}

const WORKER_GLOBALS = ['Float32Array', 'Float64Array', 'Int8Array', 'Int16Array', 'Int32Array', 'Uint8Array',
  'Uint8ClampedArray', 'Uint16Array', 'Uint32Array', 'BigInt64Array', 'BigUint64Array', 'ArrayBuffer', 'DataView',
  'WebAssembly', 'console', 'Promise', 'Error', 'Math', 'Object', 'Array', 'setTimeout', 'clearTimeout', 'TextDecoder', 'TextEncoder'];

class FakeWorker {
  constructor(url) {
    stats.workers++;
    const bytes = blobParts.get(String(url));
    if (!bytes) throw new Error('env: Worker source not found for ' + url);
    const source = new TextDecoder().decode(bytes);
    this._listeners = [];
    this.onmessage = null;
    this._terminated = false;
    const worker = this;
    const scope = { onmessage: null, _listeners: [] };
    for (const k of WORKER_GLOBALS) scope[k] = globalThis[k];
    scope.self = scope;
    scope.location = { href: String(url) };
    scope.process = undefined;
    scope.window = undefined;
    scope.document = undefined;
    scope.require = undefined;
    scope.module = undefined;
    scope.exports = undefined;
    scope.importScripts = function () { throw new Error('env: importScripts is not supported'); };
    scope.addEventListener = (type, f) => { if (type === 'message') scope._listeners.push(f); };
    scope.postMessage = (msg, transfer) => {
      const data = structuredClone(msg, { transfer: transfer || [] });
      setTimeout(() => worker._deliver({ data }), 0);
    };
    this._scope = scope;
    // eslint-disable-next-line no-new-func
    const run = new Function('__scope', 'with (__scope) {\n' + source + '\n}');
    run(scope);
  }
  _deliver(event) {
    if (this._terminated) return;
    if (this.onmessage) this.onmessage(event);
    for (const f of this._listeners) f(event);
  }
  addEventListener(type, f) { if (type === 'message') this._listeners.push(f); }
  removeEventListener(type, f) { this._listeners = this._listeners.filter((g) => g !== f); }
  postMessage(msg, transfer) {
    const data = structuredClone(msg, { transfer: transfer || [] });
    const scope = this._scope;
    setTimeout(() => {
      if (this._terminated) return;
      const event = { data };
      if (scope.onmessage) scope.onmessage(event);
      for (const f of scope._listeners) f(event);
    }, 0);
  }
  terminate() { this._terminated = true; }
}

let installed = false;
export function install() {
  if (installed) return;
  installed = true;
  globalThis.self = globalThis;
  globalThis.Blob = RecBlob;
  URL.createObjectURL = (blob) => {
    const url = realCreateObjectURL(blob);
    blobParts.set(url, blob.__bytes || partsToBytes([blob]));
    return url;
  };
  URL.revokeObjectURL = (url) => { stats.revoked++; blobParts.delete(url); realRevokeObjectURL(url); };
  globalThis.fetch = fakeFetch;
  globalThis.createImageBitmap = fakeCreateImageBitmap;
  globalThis.Worker = FakeWorker;
  if (typeof globalThis.ProgressEvent === 'undefined') {
    globalThis.ProgressEvent = class ProgressEvent { constructor(type, o = {}) { this.type = type; Object.assign(this, o); } };
  }
}

// Runs `f` with console.warn / console.error captured; returns { value, warnings }.
export function captureConsole(f) {
  const out = [];
  const w = console.warn, e = console.error;
  console.warn = (...a) => out.push('warn: ' + a.map(String).join(' '));
  console.error = (...a) => out.push('error: ' + a.map(String).join(' '));
  try { return { value: f(), warnings: out }; } finally { console.warn = w; console.error = e; }
}

// Waits until `predicate()` or the timeout.
export async function settle(predicate, ms = 60000) {
  const t0 = Date.now();
  while (!predicate()) {
    if (Date.now() - t0 > ms) throw new Error('settle: timeout');
    await new Promise((r) => setTimeout(r, 1));
  }
}
