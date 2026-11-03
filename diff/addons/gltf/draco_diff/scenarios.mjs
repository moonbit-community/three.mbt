// Scenarios run identically on both sides through the adapter `api` (see side.mjs).
import fs from 'node:fs';
import { fnv, EXAMPLES } from '../env.mjs';

const ATTRIBUTES = { POSITION: 'position', NORMAL: 'normal', TANGENT: 'tangent', TEXCOORD_0: 'uv', TEXCOORD_1: 'uv1', TEXCOORD_2: 'uv2', TEXCOORD_3: 'uv3', COLOR_0: 'color', WEIGHTS_0: 'skinWeight', JOINTS_0: 'skinIndex' };
const TYPES = { 5120: 'Int8Array', 5121: 'Uint8Array', 5122: 'Int16Array', 5123: 'Uint16Array', 5125: 'Uint32Array', 5126: 'Float32Array' };
export const GLBS = ['duck.glb', 'gears.glb', 'tennyson-bust.glb', 'ShaderBall2.glb', 'ferrari.glb', 'LittlestTokyo.glb', 'kira.glb', 'rolex.glb', 'pool.glb', 'AVIFTest/forest_house.glb', 'bath_day.glb', 'IridescentDishWithOlives.glb', 'nemetona.glb', 'venice_mask.glb', 'CarbonFrameBike.glb'];

function readBuffer(rel) {
	const b = fs.readFileSync(EXAMPLES + rel);
	return b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength);
}

// The Draco primitives of a GLB, with the attribute maps GLTFLoader builds.
export function dracoPrimitives(rel) {
	const file = readBuffer('models/gltf/' + rel);
	const dv = new DataView(file);
	const jsonLen = dv.getUint32(12, true);
	const json = JSON.parse(new TextDecoder().decode(new Uint8Array(file, 20, jsonLen)));
	const binStart = 20 + jsonLen + 8;
	const out = [];
	json.meshes.forEach((mesh, mi) => mesh.primitives.forEach((primitive, pi) => {
		const ext = primitive.extensions && primitive.extensions.KHR_draco_mesh_compression;
		if (!ext) return;
		const bv = json.bufferViews[ext.bufferView];
		const start = binStart + (bv.byteOffset || 0);
		const dracoAttributes = ext.attributes;
		const gltfAttributeMap = primitive.attributes;
		const types = [];
		const ids = [];
		for (const attributeName in dracoAttributes) {
			const threeAttributeName = ATTRIBUTES[attributeName] || attributeName.toLowerCase();
			if (gltfAttributeMap[attributeName] === undefined) continue;
			const accessorDef = json.accessors[primitive.attributes[attributeName]];
			types.push([threeAttributeName, TYPES[accessorDef.componentType]]);
		}
		for (const attributeName in gltfAttributeMap) {
			const threeAttributeName = ATTRIBUTES[attributeName] || attributeName.toLowerCase();
			if (dracoAttributes[attributeName] !== undefined) ids.push([threeAttributeName, dracoAttributes[attributeName]]);
		}
		out.push({ tag: mi + '.' + pi, buffer: () => file.slice(start, start + bv.byteLength), ids, types });
	}));
	return out;
}

function arr(a) {
	return { type: a.constructor.name, length: a.length, byteOffset: a.byteOffset, bufLen: a.buffer.byteLength, hash: fnv(new Uint8Array(a.buffer, a.byteOffset, a.byteLength)) };
}

export function sum(api, g) {
	if (!g) return null;
	const s = api.summary(g);
	return {
		type: s.type, groups: s.groups,
		index: s.index && { ...s.index, array: arr(s.index.array) },
		attributes: s.attributes.map((a) => ({ ...a, array: arr(a.array) })),
	};
}

function desc(e) {
	if (e === undefined) return 'undefined';
	if (e && typeof e === 'object' && 'message' in e && typeof e.message === 'string') return { name: e.name, message: e.message.replace(/blob:nodedata:[0-9a-f-]+/g, 'blob:<url>') };
	try { return JSON.parse(JSON.stringify(e)); } catch (x) { return String(e); }
}

function decodeP(api, log, l, tag, buf, ids, types, cs) {
	// Settles once the returned promise has, so the callers' continuations run at a fixed point.
	return new Promise((resolve) => {
		let p, result = null;
		try {
			p = api.decode(l, buf, (g) => { log('callback', tag); result = g; }, ids, types, cs, (e) => { log('onError', tag, desc(e)); });
		} catch (e) {
			log('threw', tag, desc(e));
			resolve(null);
			return;
		}
		p.then((v) => { log('promise.fulfilled', tag, v === undefined ? 'undefined' : typeof v); resolve(result); });
	});
}

const tick = (n = 5) => new Promise((r) => setTimeout(r, n));

export const scenarios = {

	async bunny_load(api, log, BASE) {
		const l = api.newLoader();
		api.setDecoderPath(l, BASE + 'jsm/libs/draco/');
		const g = await new Promise((res) => api.load(l, BASE + 'models/draco/bunny.drc', (g) => { log('onLoad'); res(g); }, (e) => { log('onError', desc(e)); res(null); }));
		log('geometry', sum(api, g));
		api.debug(l);
		const missing = await new Promise((res) => api.load(l, BASE + 'models/draco/missing.drc', (g) => res(g), (e) => { log('onError', desc(e)); res(null); }));
		log('missing', missing === null);
		api.dispose(l);
	},

	async parse_and_cache(api, log, BASE) {
		const l = api.newLoader();
		api.setDecoderPath(l, BASE + 'jsm/libs/draco/');
		const buf = readBuffer('models/draco/bunny.drc');
		const p1 = new Promise((res) => api.parse(l, buf, (g) => { log('parse1'); res(g); }, (e) => { log('onError', desc(e)); res(null); }));
		const p2 = new Promise((res) => api.parse(l, buf, (g) => { log('parse2'); res(g); }, (e) => { log('onError', desc(e)); res(null); }));
		const [g1, g2] = await Promise.all([p1, p2]);
		log('same geometry', g1 === g2, buf.byteLength);
		log('geometry', sum(api, g1));
		// same config again after transfer: cached
		const g3 = await new Promise((res) => api.parse(l, buf, (g) => res(g), (e) => { log('onError', desc(e)); res(null); }));
		log('cached after transfer', g3 === g1);
		// different config on a transferred buffer: synchronous throw
		try { api.parse; api.decode(l, buf, () => log('unexpected'), null, null, undefined, (e) => log('onError', desc(e))); log('no throw'); } catch (e) { log('threw', desc(e)); }
		// different config before the transfer: a second task, whose postMessage fails
		const buf2 = readBuffer('models/draco/bunny.drc');
		const a = decodeP(api, log, l, 'linear', buf2, null, null, undefined);
		const b = decodeP(api, log, l, 'srgb', buf2, null, null, 'srgb');
		const [ga, gb] = await Promise.all([a, b]);
		log('ga', sum(api, ga), 'gb', gb === null);
		api.debug(l);
		api.dispose(l);
	},

	async errors(api, log, BASE) {
		const l = api.newLoader();
		api.setDecoderPath(l, BASE + 'jsm/libs/draco/');
		const bunny = new Uint8Array(readBuffer('models/draco/bunny.drc'));
		const random = new Uint8Array(4096);
		let s = 12345;
		for (let i = 0; i < random.length; i++) { s = (Math.imul(s, 1103515245) + 12345) >>> 0; random[i] = s >>> 24; }
		const randomCopy = random.slice();
		const cases = {
			random: random.buffer,
			truncated: bunny.slice(0, 2000).buffer,
			header_only: bunny.slice(0, 16).buffer,
			flipped: (() => { const c = bunny.slice(); for (let i = 200; i < c.length; i += 7) c[i] ^= 0x5a; return c.buffer; })(),
			empty: new ArrayBuffer(0),
		};
		for (const [tag, buf] of Object.entries(cases)) {
			const g = await decodeP(api, log, l, tag, buf, null, null, undefined);
			log('result', tag, sum(api, g));
		}
		// parse() path: onError receives the worker's message
		const g = await new Promise((res) => api.parse(l, randomCopy.buffer, (g) => res(g), (e) => { log('parse.onError', desc(e)); res(null); }));
		log('parse.result', g === null);
		api.debug(l);
		api.dispose(l);
	},

	async colors(api, log, BASE) {
		const l = api.newLoader();
		api.setDecoderPath(l, BASE + 'jsm/libs/draco/gltf/');
		const withColor = (f) => dracoPrimitives(f).filter((p) => p.ids.some(([n]) => n === 'color')).slice(0, 2);
		const prims = [...withColor('kira.glb'), ...withColor('rolex.glb'), ...withColor('ShaderBall2.glb'), ...withColor('CarbonFrameBike.glb')];
		for (const p of prims) {
			// glTF-style (unique IDs, linear)
			log('gltf', p.tag, sum(api, await decodeP(api, log, l, p.tag + ':gltf', p.buffer(), p.ids, p.types, undefined)));
			// parse(): default IDs, sRGB conversion
			const g = await new Promise((res) => api.parse(l, p.buffer(), (g) => res(g), (e) => { log('onError', desc(e)); res(null); }));
			log('parse', p.tag, sum(api, g));
			// unique IDs with sRGB and integer color types (interleaved for 3 x Uint8 / 3 x Uint16)
			for (const t of ['Uint8Array', 'Uint16Array', 'Int16Array']) {
				const types = p.types.map(([n, v]) => [n, n === 'color' ? t : v]);
				log('srgb.' + t, p.tag, sum(api, await decodeP(api, log, l, p.tag + ':' + t, p.buffer(), p.ids, types, 'srgb')));
			}
		}
		// 3-component colors (the normal attribute read as 'color'): sRGB conversion on
		// Float32 and on interleaved integer attributes.
		for (const p of [...dracoPrimitives('duck.glb'), ...dracoPrimitives('gears.glb').slice(0, 1)]) {
			const normalId = p.ids.find(([n]) => n === 'normal')[1];
			const ids = p.ids.map(([n, v]) => [n === 'normal' ? 'color' : n, v]);
			for (const t of ['Float32Array', 'Uint8Array', 'Int8Array', 'Int16Array', 'Uint16Array', 'Uint32Array']) {
				const types = p.types.map(([n, v]) => (n === 'normal' ? ['color', t] : [n, v]));
				for (const cs of ['srgb', undefined]) {
					log('color3.' + t + '.' + cs, p.tag, normalId, sum(api, await decodeP(api, log, l, p.tag + ':c3:' + t, p.buffer(), ids, types, cs)));
				}
			}
		}
		api.dispose(l);
	},

	async interleaved_types(api, log, BASE) {
		const l = api.newLoader();
		api.setDecoderPath(l, BASE + 'jsm/libs/draco/');
		const variants = [
			[['position', 'Int16Array'], ['normal', 'Uint8Array']],
			[['position', 'Uint8Array'], ['normal', 'Int8Array']],
			[['position', 'Uint32Array'], ['normal', 'Int32Array']],
			[['position', 'Float32Array'], ['normal', 'Uint16Array']],
		];
		for (const v of variants) {
			const types = [...v, ['color', 'Float32Array'], ['uv', 'Float32Array']];
			const g = await decodeP(api, log, l, JSON.stringify(v), readBuffer('models/draco/bunny.drc'), null, types, 'srgb');
			log('variant', sum(api, g));
		}
		// unique IDs on the default-attribute bunny (ids 0, 1)
		const g = await decodeP(api, log, l, 'bunny-ids', readBuffer('models/draco/bunny.drc'), [['position', 0]], [['position', 'Float32Array']], undefined);
		log('bunny-ids', sum(api, g));
		api.dispose(l);
	},

	async worker_order_1(api, log, BASE) { await workerOrder(api, log, BASE, 1); },
	async worker_order_2(api, log, BASE) { await workerOrder(api, log, BASE, 2); },
	async worker_order_4(api, log, BASE) { await workerOrder(api, log, BASE, 4); },

	async dispose_then_decode(api, log, BASE) {
		const l = api.newLoader();
		api.setDecoderPath(l, BASE + 'jsm/libs/draco/');
		log('first', sum(api, await decodeP(api, log, l, 'first', readBuffer('models/draco/bunny.drc'), null, null, undefined)));
		api.dispose(l);
		api.dispose(l);
		log('after', sum(api, await decodeP(api, log, l, 'after', readBuffer('models/draco/bunny.drc'), null, null, undefined)));
		api.debug(l);
	},

	async js_decoder(api, log, BASE) {
		const l = api.newLoader();
		api.setDecoderPath(l, BASE + 'jsm/libs/draco/');
		api.setDecoderConfig(l, { type: 'js' });
		const g = await decodeP(api, log, l, 'js', readBuffer('models/draco/bunny.drc'), null, null, 'srgb');
		log('js', sum(api, g));
		api.dispose(l);
		// custom paths with the JS decoder: synchronous throw
		const l2 = api.newLoader();
		api.setDecoderPathConfig(l2, BASE + 'jsm/libs/draco/gltf/draco_wasm_wrapper.js', BASE + 'jsm/libs/draco/gltf/draco_decoder.wasm');
		api.setDecoderConfig(l2, { type: 'js' });
		await decodeP(api, log, l2, 'custom-js', readBuffer('models/draco/bunny.drc'), null, null, undefined);
		try { api.preload(l2); log('preload no throw'); } catch (e) { log('preload threw', desc(e)); }
		api.dispose(l2);
	},

	async custom_paths(api, log, BASE) {
		const l = api.newLoader();
		api.setDecoderPathConfig(l, BASE + 'jsm/libs/draco/gltf/draco_wasm_wrapper.js', BASE + 'jsm/libs/draco/gltf/draco_decoder.wasm');
		api.preload(l);
		api.preload(l);
		await tick(20);
		const [p] = dracoPrimitives('duck.glb');
		log('duck', sum(api, await decodeP(api, log, l, 'duck', p.buffer(), p.ids, p.types, undefined)));
		api.dispose(l);
		const c = api.gltfConfig;
		log('gltf config', c.js.slice(c.js.indexOf('libs/draco/')), c.wasm.slice(c.wasm.indexOf('libs/draco/')));
		// missing decoder: the library request fails
		const l3 = api.newLoader();
		api.setDecoderPath(l3, BASE + 'jsm/libs/nothing/');
		await decodeP(api, log, l3, 'missing-decoder', readBuffer('models/draco/bunny.drc'), null, null, undefined);
		api.dispose(l3);
	},
};

async function workerOrder(api, log, BASE, limit) {
	const l = api.newLoader();
	api.setDecoderPath(l, BASE + 'jsm/libs/draco/gltf/');
	api.setWorkerLimit(l, limit);
	const prims = [...dracoPrimitives('gears.glb'), ...dracoPrimitives('duck.glb'), ...dracoPrimitives('ShaderBall2.glb'), ...dracoPrimitives('tennyson-bust.glb'), ...dracoPrimitives('gears.glb')];
	// Wave 1 starts the workers; their wasm modules load concurrently, so with more than
	// one worker the reply order is up to the engine: those entries are compared as a set.
	if (limit > 1) log('racy.begin');
	const ps = prims.map((p, i) => decodeP(api, log, l, i + ':' + p.tag, p.buffer(), p.ids, p.types, undefined));
	api.debug(l);
	const gs = await Promise.all(ps);
	if (limit > 1) log('racy.end');
	api.debug(l);
	// Wave 2: warm workers, more tasks than workers, so the pool is sorted by task load.
	for (const wave of [prims, prims.slice(0, 3), [...prims].reverse()]) {
		const ps2 = wave.map((p, i) => decodeP(api, log, l, 'w2:' + i + ':' + p.tag, p.buffer(), p.ids, p.types, undefined).then((g) => { api.debug(l); return g; }));
		api.debug(l);
		await tick(0);
		api.debug(l);
		await Promise.all(ps2);
		api.debug(l);
	}
	gs.forEach((g, i) => log('g', i, sum(api, g)));
	api.dispose(l);
}

for (const f of GLBS) {
	scenarios['glb:' + f] = async (api, log, BASE) => {
		const l = api.newLoader();
		api.setDecoderPath(l, BASE + 'jsm/libs/draco/gltf/');
		const prims = dracoPrimitives(f);
		log('racy.begin');
		const gs = await Promise.all(prims.map((p) => decodeP(api, log, l, p.tag, p.buffer(), p.ids, p.types, undefined)));
		log('racy.end');
		gs.forEach((g, i) => log('g', prims[i].tag, sum(api, g)));
		api.dispose(l);
	};
}
