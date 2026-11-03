// A recording browser stand-in for node: fetch/Request/Headers, Image elements,
// createImageBitmap, ProgressEvent, DOMParser and AudioContext. Both the upstream
// scenarios and the MoonBit ones run against it; every observable step goes to `log`.

export const log = [];
const RealHeaders = globalThis.Headers;
let routes = {};
let pendingTimers = 0;

export function describe(v) {
  if (v === undefined) return 'undefined';
  if (v === null) return 'null';
  if (typeof v === 'string') return JSON.stringify(v);
  if (typeof v === 'number' || typeof v === 'boolean') return String(v);
  if (v instanceof MockImage) return `img(${v.src})`;
  if (v instanceof MockProgressEvent) return `progress(${v.lengthComputable},${v.loaded},${v.total})`;
  if (v instanceof ArrayBuffer) return `ArrayBuffer(${v.byteLength}:${Array.from(new Uint8Array(v)).join(',')})`;
  if (typeof Blob !== 'undefined' && v instanceof Blob) return `Blob(${v.size})`;
  if (v instanceof Error) return `${v.name}(${v.message}${v.response ? ' status=' + v.response.status : ''})`;
  if (v && v.__bitmap) return `bitmap(${v.size},${JSON.stringify(v.options)})`;
  if (v && v.__audioBuffer) return `audio(${v.length})`;
  if (v && v.__doc) return `doc(${v.mime},${v.text})`;
  if (v && v.__event) return `event(${v.type})`;
  try { return 'json:' + JSON.stringify(v); } catch (e) { return String(v); }
}

export function note(label, value) { log.push(`${label} ${describe(value)}`); }

class MockHeaders {
  constructor(init) {
    this.map = new Map();
    if (init instanceof MockHeaders) init = Object.fromEntries(init.map);
    if (init) for (const k of Object.keys(init)) this.map.set(k.toLowerCase(), String(init[k]));
  }
  get(k) { const v = this.map.get(k.toLowerCase()); return v === undefined ? null : v; }
  toString() { return JSON.stringify(Object.fromEntries(this.map)); }
}

class MockRequest {
  constructor(url, init = {}) {
    this.url = url;
    this.headers = init.headers instanceof MockHeaders ? init.headers : new MockHeaders(init.headers);
    this.credentials = init.credentials;
    this.priority = init.priority;
    this.cache = init.cache;
    this.signal = init.signal;
  }
}

function makeResponse(route) {
  const headers = new RealHeaders(route.headers || {});
  const chunks = (route.chunks || []).map((c) => (typeof c === 'string' ? new TextEncoder().encode(c) : new Uint8Array(c)));
  const body = route.noBody ? null : new ReadableStream({
    start(controller) {
      for (const c of chunks) controller.enqueue(c);
      controller.close();
    },
  });
  const r = new Response(body, { status: route.status === 0 ? 200 : (route.status || 200), statusText: route.statusText || 'OK', headers });
  if (route.status === 0) Object.defineProperty(r, 'status', { value: 0 });
  Object.defineProperty(r, 'url', { value: route.url });
  return r;
}

function mockFetch(input, init) {
  const req = input instanceof MockRequest ? input : new MockRequest(input, init);
  const signal = req.signal;
  const headers = req.headers instanceof MockHeaders ? req.headers.toString() : JSON.stringify(req.headers);
  log.push(`fetch ${req.url} credentials=${req.credentials} cache=${req.cache} priority=${req.priority} headers=${headers} aborted=${signal ? signal.aborted : 'none'}`);
  const route = routes[req.url] || { status: 404, statusText: 'Not Found', chunks: ['missing'] };
  return new Promise((resolve, reject) => {
    if (route.networkError) { pendingTimers++; setTimeout(() => { pendingTimers--; reject(new TypeError('Failed to fetch')); }, route.delay || 0); return; }
    let done = false;
    if (signal) signal.addEventListener('abort', () => { if (!done) { done = true; log.push(`fetch aborted ${req.url}`); reject(new DOMException('This operation was aborted', 'AbortError')); } });
    pendingTimers++;
    setTimeout(() => { pendingTimers--; if (done) return; done = true; resolve(makeResponse({ ...route, url: req.url })); }, route.delay || 0);
  });
}

class MockProgressEvent {
  constructor(type, init) { this.type = type; this.lengthComputable = init.lengthComputable; this.loaded = init.loaded; this.total = init.total; }
}

export class MockImage {
  constructor() { this.listeners = {}; this.complete = false; this._src = ''; this.width = 0; this.height = 0; }
  addEventListener(t, f) { (this.listeners[t] ||= []).push(f); }
  removeEventListener(t, f) { const a = this.listeners[t] || []; const i = a.indexOf(f); if (i !== -1) a.splice(i, 1); }
  set crossOrigin(v) { log.push(`img.crossOrigin ${v}`); this._co = v; }
  get crossOrigin() { return this._co; }
  set fetchPriority(v) { log.push(`img.fetchPriority ${v}`); this._fp = v; }
  get fetchPriority() { return this._fp; }
  get src() { return this._src; }
  set src(url) {
    this._src = url;
    log.push(`img.src ${url}`);
    const route = routes[url] || {};
    const fail = route.imageError || /missing/.test(url);
    pendingTimers++;
    setTimeout(() => {
      pendingTimers--;
      if (fail) { log.push(`img.error ${url}`); this.fire('error', { __event: true, type: 'error' }); }
      else { this.complete = true; this.width = route.width || 4; this.height = route.height || 2; log.push(`img.load ${url}`); this.fire('load', { __event: true, type: 'load' }); }
    }, route.delay || 0);
  }
  fire(t, e) { for (const f of (this.listeners[t] || []).slice()) f.call(this, e); }
}

class MockAudioContext {
  decodeAudioData(buffer, ok) {
    log.push(`decodeAudioData ${buffer.byteLength}`);
    return new Promise((resolve, reject) => {
      pendingTimers++;
      setTimeout(() => {
        pendingTimers--;
        if (buffer.byteLength === 0) { reject(new Error('Unable to decode audio data')); return; }
        const b = { __audioBuffer: true, length: buffer.byteLength };
        ok(b); resolve(b);
      }, 0);
    });
  }
}

export function install() {
  globalThis.Request = MockRequest;
  globalThis.Headers = MockHeaders;
  globalThis.fetch = mockFetch;
  globalThis.ProgressEvent = MockProgressEvent;
  globalThis.HTMLImageElement = MockImage;
  globalThis.document = {
    createElementNS(ns, name) {
      if (name === 'img') return new MockImage();
      throw new Error('mock document: no ' + name);
    },
  };
  globalThis.createImageBitmap = (blob, options) => {
    log.push(`createImageBitmap ${blob.size} ${JSON.stringify(options)}`);
    return new Promise((resolve, reject) => {
      pendingTimers++;
      setTimeout(() => { pendingTimers--; if (blob.size === 0) reject(new Error('bad image')); else resolve({ __bitmap: true, size: blob.size, options }); }, 0);
    });
  };
  globalThis.DOMParser = class { parseFromString(text, mime) { log.push(`DOMParser ${mime}`); return { __doc: true, text, mime }; } };
  globalThis.window = globalThis;
  globalThis.AudioContext = MockAudioContext;
  globalThis.__note = note;
}

export function reset(newRoutes) {
  log.length = 0;
  routes = newRoutes || {};
}

// Waits until the mock has no pending timers and the microtask queue has drained.
export async function settle() {
  for (let i = 0; i < 200; i++) {
    await new Promise((r) => setTimeout(r, 2));
    if (pendingTimers === 0) {
      await new Promise((r) => setTimeout(r, 5));
      if (pendingTimers === 0) return;
    }
  }
  throw new Error('settle: timers still pending');
}
