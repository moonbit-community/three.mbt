// One side of the DRACOLoader differential test:
//   node --import ./register.mjs side.mjs up|mbt [scenario ...]
// Prints one JSON log (array of entries) to stdout. Both sides run scenarios.mjs
// through an adapter; env.mjs is instrumented so worker traffic, Blob URLs, fetches and
// console output are logged too.
import { install, BASE, fnv, stats } from '../env.mjs';
import { scenarios } from './scenarios.mjs';
install();

const side = process.argv[2];
const only = process.argv.slice(3);
const LOG = [];
const log = (...e) => LOG.push(e);

// --- instrumentation -------------------------------------------------------
const W = globalThis.Worker;
let workerIds = 0;
function describeMsg(m) {
	if (!m || typeof m !== 'object') return m;
	const o = {};
	for (const k of Object.keys(m)) {
		const v = m[k];
		if (v instanceof ArrayBuffer) o[k] = 'ArrayBuffer(' + v.byteLength + ',' + fnv(new Uint8Array(v)) + ')';
		else if (k === 'taskConfig') o[k] = JSON.stringify(v);
		else if (k === 'decoderConfig') o[k] = Object.keys(v).map((kk) => kk + '=' + (v[kk] instanceof ArrayBuffer ? 'ArrayBuffer(' + v[kk].byteLength + ',' + fnv(new Uint8Array(v[kk])) + ')' : JSON.stringify(v[kk]))).join(';');
		else if (k === 'geometry') o[k] = { index: v.index ? v.index.array.length : null, attributes: v.attributes.map((a) => a.name + ':' + a.array.constructor.name + ':' + a.itemSize + ':' + a.stride + ':' + a.count + ':' + (a.vertexColorSpace ?? '-')) };
		else o[k] = v;
	}
	return o;
}
globalThis.Worker = class extends W {
	constructor(url) {
		const known = String(url) === currentBlob;
		log('worker.new', known ? 'current-blob' : 'other-url');
		super(url);
		this.__id = workerIds++;
	}
	postMessage(msg, transfer) {
		log('worker.post', this.__id, describeMsg(msg), (transfer || []).length);
		super.postMessage(msg, transfer);
	}
	_deliver(event) {
		if (!this._terminated) log('worker.recv', this.__id, describeMsg(event.data));
		super._deliver(event);
	}
	terminate() { log('worker.terminate', this.__id); super.terminate(); }
};
let currentBlob = null;
const createURL = URL.createObjectURL;
URL.createObjectURL = (blob) => {
	const url = createURL(blob);
	currentBlob = url;
	log('blob.create', blob.__bytes.length, fnv(blob.__bytes));
	return url;
};
const revokeURL = URL.revokeObjectURL;
URL.revokeObjectURL = (url) => { log('blob.revoke', url === currentBlob ? 'current-blob' : 'other'); revokeURL(url); };
const fetch0 = globalThis.fetch;
globalThis.fetch = (input, init) => { log('fetch', typeof input === 'string' ? input : input.url); return fetch0(input, init); };
for (const k of ['log', 'warn', 'error']) {
	console[k] = (...a) => log('console.' + k, a.map((x) => (x instanceof Error ? 'Error: ' + x.message : typeof x === 'object' ? JSON.stringify(x) : String(x))).join(' '));
}

// --- adapters --------------------------------------------------------------
function summarizeUp(g) {
	const attributes = [];
	for (const name of Object.keys(g.attributes)) {
		const a = g.attributes[name];
		if (a.isInterleavedBufferAttribute) attributes.push({ name, interleaved: true, array: a.data.array, stride: a.data.stride, offset: a.offset, itemSize: a.itemSize, count: a.count, normalized: a.normalized, attrName: a.name });
		else attributes.push({ name, interleaved: false, array: a.array, itemSize: a.itemSize, count: a.count, normalized: a.normalized, attrName: a.name });
	}
	const index = g.index ? { array: g.index.array, itemSize: g.index.itemSize, count: g.index.count, normalized: g.index.normalized } : null;
	return { attributes, index, type: g.type, groups: g.groups.length };
}

async function makeApi() {
	if (side === 'up') {
		const { DRACOLoader, DRACO_GLTF_CONFIG } = await import('three/addons/loaders/DRACOLoader.js');
		const obj = (pairs) => (pairs === null ? null : Object.fromEntries(pairs));
		return {
			gltfConfig: DRACO_GLTF_CONFIG,
			newLoader: () => new DRACOLoader(),
			setDecoderPath: (l, p) => l.setDecoderPath(p),
			setDecoderPathConfig: (l, js, wasm) => l.setDecoderPath({ js, wasm }),
			setDecoderConfig: (l, c) => l.setDecoderConfig(c),
			setWorkerLimit: (l, n) => l.setWorkerLimit(n),
			preload: (l) => l.preload(),
			load: (l, url, onLoad, onError) => l.load(url, onLoad, undefined, onError),
			parse: (l, buf, onLoad, onError) => l.parse(buf, onLoad, onError),
			decode: (l, buf, cb, ids, types, cs, onError) => l.decodeDracoFile(buf, cb, obj(ids), obj(types), cs, onError),
			dispose: (l) => l.dispose(),
			debug: (l) => l.debug(),
			summary: summarizeUp,
		};
	}
	const m = await import('./_build/js/debug/build/dracodiff/real/harness/harness.js');
	return {
		gltfConfig: m.gltf_config(),
		newLoader: () => m.new_loader(),
		setDecoderPath: (l, p) => m.set_decoder_path(l, p),
		setDecoderPathConfig: (l, js, wasm) => m.set_decoder_path_gltf(l, js, wasm),
		setDecoderConfig: (l, c) => m.set_decoder_config(l, c),
		setWorkerLimit: (l, n) => m.set_worker_limit(l, n),
		preload: (l) => m.preload(l),
		load: (l, url, onLoad, onError) => m.load(l, url, onLoad, onError),
		parse: (l, buf, onLoad, onError) => m.parse(l, buf, onLoad, onError),
		decode: (l, buf, cb, ids, types, cs, onError) => m.decode(l, buf, cb, ids, types, cs, onError),
		dispose: (l) => m.dispose(l),
		debug: (l) => m.debug(l),
		summary: (g) => m.summary(g),
	};
}

const api = await makeApi();
for (const [name, f] of Object.entries(scenarios)) {
	if (only.length && !only.includes(name)) continue;
	log('scenario', name);
	try {
		await f(api, log, BASE);
	} catch (e) {
		log('scenario.threw', String(e && e.message || e));
	}
}
process.stdout.write(JSON.stringify(LOG));
