// The upstream side of the mock fetch / Image scenarios. Each scenario has `routes`
// (what the mock fetch and Image answer) and `run( T, note )`, which drives upstream
// loaders; the MoonBit side (dev/src/harness/scenarios.mbt) does the same steps.
// Labels and values passed to `note` must match between the two.

const text = (body, extra = {}) => ({ status: 200, chunks: Array.isArray(body) ? body : [body], headers: { 'Content-Length': String((Array.isArray(body) ? body.join('') : body).length) }, ...extra });

function managerWithLog(T, note, name) {
  const m = new T.LoadingManager(
    () => note(name + '.onLoad', ''),
    (url, loaded, total) => note(name + '.onProgress', `${url} ${loaded}/${total}`),
    (url) => note(name + '.onError', url),
  );
  m.onStart = (url, loaded, total) => note(name + '.onStart', `${url} ${loaded}/${total}`);
  return m;
}

const sceneJson = JSON.stringify({
  metadata: { version: 4.7, type: 'Object', generator: 'Object3D.toJSON' },
  images: [{ uuid: 'img-1', url: 'tex/a.png' }, { uuid: 'img-2', url: ['tex/px.png', 'https://cdn.example/nx.png', 'data:image/png;base64,QQ'] }],
  textures: [{ uuid: 'tex-1', image: 'img-1' }, { uuid: 'tex-2', image: 'img-2' }],
  materials: [{ uuid: 'mat-1', type: 'MeshBasicMaterial', map: 'tex-1' }],
  geometries: [{ uuid: 'geo-1', type: 'BoxGeometry', width: 1, height: 1, depth: 1 }],
  object: { uuid: 'obj-1', type: 'Mesh', geometry: 'geo-1', material: 'mat-1', matrix: [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1] },
});

export const scenarios = {
  file_basic: {
    routes: { 'base/a.txt': text(['hello ', 'world']), 'base/b.txt': text('second', { delay: 30 }) },
    run(T, note) {
      const manager = managerWithLog(T, note, 'm');
      const loader = new T.FileLoader(manager);
      loader.setPath('base/').setRequestHeader({ 'X-Test': 'yes', Accept: 'text/plain' }).setWithCredentials(true).setPriority('high').setCache('no-store');
      loader.load('a.txt', (d) => note('a.onLoad', d), (e) => note('a.onProgress', e), (e) => note('a.onError', e));
      loader.load('a.txt', (d) => note('a2.onLoad', d), (e) => note('a2.onProgress', e), (e) => note('a2.onError', e));
      loader.load('b.txt', (d) => note('b.onLoad', d));
      note('sync end', '');
    },
  },
  file_response_types: {
    routes: {
      'r/ab.bin': text('ABCD'), 'r/data.json': text('{"x":[1,2]}'), 'r/blob.bin': text('12345'),
      'r/doc.xml': text('<a/>'), 'r/latin.txt': { status: 200, chunks: [[104, 233, 108, 108, 111]] }, 'r/plain.txt': text('plain'),
    },
    run(T, note) {
      const m = managerWithLog(T, note, 'm');
      new T.FileLoader(m).setResponseType('arraybuffer').load('r/ab.bin', (d) => note('ab', d));
      new T.FileLoader(m).setResponseType('json').load('r/data.json', (d) => note('json', d));
      new T.FileLoader(m).setResponseType('blob').load('r/blob.bin', (d) => note('blob', d));
      new T.FileLoader(m).setResponseType('document').setMimeType('text/xml').load('r/doc.xml', (d) => note('doc', d));
      new T.FileLoader(m).setMimeType('text/plain; charset="ISO-8859-1"').load('r/latin.txt', (d) => note('latin', d));
      new T.FileLoader(m).setMimeType('text/plain').load('r/plain.txt', (d) => note('plain', d));
    },
  },
  file_errors: {
    routes: { 'e/404.txt': { status: 404, statusText: 'Not Found', chunks: ['nope'] }, 'e/net.txt': { networkError: true }, 'e/zero.txt': { status: 0, chunks: ['z'] }, 'e/nolen.txt': { status: 200, chunks: ['ab', 'cd'], headers: { 'X-File-Size': '4' } }, 'e/nobody.txt': { status: 200, noBody: true } },
    run(T, note) {
      const m = managerWithLog(T, note, 'm');
      const l = new T.FileLoader(m);
      l.load('e/404.txt', (d) => note('404.onLoad', d), undefined, (e) => note('404.onError', e));
      l.load('e/net.txt', (d) => note('net.onLoad', d), undefined, (e) => note('net.onError', e));
      l.load('e/zero.txt', (d) => note('zero.onLoad', d), (e) => note('zero.onProgress', e));
      l.load('e/nolen.txt', (d) => note('nolen.onLoad', d), (e) => note('nolen.onProgress', e));
      l.load('e/nobody.txt', (d) => note('nobody.onLoad', d), (e) => note('nobody.onProgress', e));
      l.load('e/missing.txt', undefined, undefined, undefined);
    },
  },
  file_cache_and_abort: {
    routes: { 'c/x.txt': text('cached'), 'c/slow.txt': text('slow', { delay: 50 }), 'c/slow2.txt': text('slow2', { delay: 50 }) },
    run(T, note) {
      T.Cache.enabled = true;
      const m = managerWithLog(T, note, 'm');
      const l = new T.FileLoader(m);
      l.load('c/x.txt', (d) => {
        note('x1', d);
        note('cached?', T.Cache.get('file:c/x.txt'));
        l.load('c/x.txt', (d2) => { note('x2', d2); T.Cache.enabled = false; T.Cache.clear(); });
        note('after second load', '');
      });
    },
  },
  file_abort: {
    routes: { 'c/slow.txt': text('slow', { delay: 50 }), 'c/slow2.txt': text('slow2', { delay: 50 }), 'c/after.txt': text('after') },
    run(T, note) {
      const m = managerWithLog(T, note, 'm');
      const slow = new T.FileLoader(m);
      slow.load('c/slow.txt', (d) => note('slow.onLoad', d), undefined, (e) => note('slow.onError', e));
      slow.abort();
      slow.load('c/after.txt', (d) => note('after.onLoad', d), undefined, (e) => note('after.onError', e));
      const viaManager = new T.FileLoader(m);
      viaManager.load('c/slow2.txt', (d) => note('slow2.onLoad', d), undefined, (e) => note('slow2.onError', e));
      m.abort();
      note('aborted', '');
      new T.FileLoader(m).load('c/after.txt', (d) => note('after2.onLoad', d), undefined, (e) => note('after2.onError', e));
    },
  },
  file_load_async: {
    awaited: ['ok.resolved', 'ok.rejected', 'bad.resolved', 'bad.rejected'],
    routes: { 'p/ok.txt': text('async ok'), 'p/bad.txt': { status: 500, statusText: 'Server Error', chunks: ['x'] } },
    run(T, note) {
      const l = new T.FileLoader(managerWithLog(T, note, 'm'));
      l.loadAsync('p/ok.txt', (e) => note('ok.progress', e)).then((d) => note('ok.resolved', d), (e) => note('ok.rejected', e));
      l.loadAsync('p/bad.txt').then((d) => note('bad.resolved', d), (e) => note('bad.rejected', e));
    },
  },
  image_loader: {
    routes: { 'img/a.png': { width: 8, height: 4 }, 'img/slow.png': { delay: 30 }, 'img/missing.png': {} },
    run(T, note) {
      T.Cache.enabled = true;
      const m = managerWithLog(T, note, 'm');
      const l = new T.ImageLoader(m).setPath('img/').setCrossOrigin('use-credentials').setPriority('low');
      const a = l.load('a.png', (i) => note('a.onLoad', i), undefined, (e) => note('a.onError', e));
      note('returned', a);
      const s1 = l.load('slow.png', (i) => {
        note('slow1.onLoad', i);
        l.load('slow.png', (i2) => { note('slow3.onLoad', i2); T.Cache.enabled = false; T.Cache.clear(); });
      });
      const s2 = l.load('slow.png', (i) => note('slow2.onLoad', i));
      note('same element', s1 === s2);
      l.load('missing.png', (i) => note('missing.onLoad', i), undefined, (e) => note('missing.onError', e));
      new T.ImageLoader(m).load('data:image/png;base64,AA', (i) => note('data.onLoad', i));
    },
  },
  texture_loader: {
    awaited: ['async image'],
    routes: { 't/a.png': { width: 16, height: 8 }, 't/missing.png': {} },
    run(T, note) {
      const m = managerWithLog(T, note, 'm');
      const l = new T.TextureLoader(m).setPath('t/');
      const tex = l.load('a.png', (t) => { note('onLoad same', t === tex); note('image', t.image); note('version', t.version); note('size', `${t.image.width}x${t.image.height}`); });
      note('initial image', tex.image);
      note('initial version', tex.version);
      l.load('missing.png', (t) => note('missing.onLoad', t.image), undefined, (e) => note('missing.onError', e));
      l.loadAsync('a.png').then((t) => note('async image', t.image));
    },
  },
  cube_texture_loader: {
    routes: { 'cube/px.png': { delay: 80 }, 'cube/nx.png': { delay: 40 }, 'cube/py.png': {}, 'cube/ny.png': { delay: 60 }, 'cube/pz.png': {}, 'cube/nz.png': { delay: 20 } },
    run(T, note) {
      const m = managerWithLog(T, note, 'm');
      const l = new T.CubeTextureLoader(m).setPath('cube/');
      const tex = l.load(['px.png', 'nx.png', 'py.png', 'ny.png', 'pz.png', 'nz.png'], (t) => {
        note('onLoad', t === tex);
        note('images', t.images.map((i) => i.src).join(','));
        note('version', t.version);
        note('colorSpace', t.colorSpace);
      });
      note('initial images', tex.images.length);
      new T.CubeTextureLoader(m).setPath('cube/').load(['px.png', 'missing.png'], (t) => note('never', t), undefined, (e) => note('cube.onError', e));
    },
  },
  image_bitmap_loader: {
    routes: { 'bm/a.png': text('PNGDATA'), 'bm/empty.png': { status: 200, chunks: [] } },
    run(T, note) {
      T.Cache.enabled = true;
      const m = managerWithLog(T, note, 'm');
      const l = new T.ImageBitmapLoader(m);
      l.setOptions({ imageOrientation: 'flipY', premultiplyAlpha: 'premultiply' }).setCrossOrigin('use-credentials').setRequestHeader({ R: '1' });
      l.load('bm/a.png', (b) => {
        note('a.onLoad', b);
        l.load('bm/a.png', (b2) => { note('a3.onLoad', b2); T.Cache.enabled = false; T.Cache.clear(); });
      }, undefined, (e) => note('a.onError', e));
      l.load('bm/a.png', (b) => note('a2.onLoad', b));
      l.load('bm/empty.png', (b) => note('empty.onLoad', b), undefined, (e) => note('empty.onError', e));
      l.load('bm/empty.png', (b) => note('empty2.onLoad', b), undefined, (e) => note('empty2.onError', e));
    },
  },
  json_loaders: {
    awaited: ['async scene', 'async scene error'],
    routes: {
      'j/geo.json': text(JSON.stringify({ metadata: {}, data: { attributes: { position: { itemSize: 3, type: 'Float32Array', array: [0, 0, 0, 1, 2, 3], normalized: false } } } })),
      'j/mat.json': text(JSON.stringify({ uuid: 'm-uuid', type: 'MeshPhongMaterial', color: 255, shininess: 10 })),
      'j/bad.json': text('{ not json'),
      'j/scene.json': text(sceneJson), 'j/tex/a.png': {}, 'j/tex/px.png': { delay: 30 }, 'https://cdn.example/nx.png': {},
      'j/geometry.json': text(JSON.stringify({ metadata: { type: 'Geometry' } })),
    },
    run(T, note) {
      const m = managerWithLog(T, note, 'm');
      new T.BufferGeometryLoader(m).load('j/geo.json', (g) => note('geo', Array.from(g.attributes.position.array).join(',')));
      new T.BufferGeometryLoader(m).load('j/bad.json', (g) => note('never', g), undefined, (e) => note('bad.onError', e.name));
      new T.MaterialLoader(m).load('j/mat.json', (mat) => note('mat', `${mat.type} ${mat.uuid} ${mat.color.getHex()} ${mat.shininess}`));
      new T.ObjectLoader(m).load('j/scene.json', (o) => {
        note('scene.onLoad', `${o.type} ${o.uuid} ${o.material.map.image.src}`);
        note('cube images', o.material.map ? '' : '');
      }, undefined, (e) => note('scene.onError', e));
      new T.ObjectLoader(m).load('j/bad.json', (o) => note('never', o), undefined, (e) => note('badscene.onError', e.name));
      new T.ObjectLoader(m).load('j/geometry.json', (o) => note('never', o), undefined, (e) => note('geometry.onError', e));
      new T.ObjectLoader(m).loadAsync('j/scene.json').then((o) => note('async scene', `${o.uuid} ${o.material.map.image.src}`), (e) => note('async scene error', e));
    },
  },
  data_texture_loader: {
    routes: { 'd/a.bin': text('0123'), 'd/b.bin': text('bad') },
    run(T, note) {
      const m = managerWithLog(T, note, 'm');
      const l = new T.DataTextureLoader(m);
      l.parse = (buffer) => {
        if (buffer.byteLength === 3) throw new Error('parse failed');
        return { width: 1, height: 1, data: new Uint8Array(buffer), flipY: true, format: T.RedFormat, minFilter: T.NearestFilter, mipmapCount: 1, generateMipmaps: false };
      };
      const tex = l.load('d/a.bin', (t, td) => note('onLoad', `${t === tex} ${t.image.width}x${t.image.height} ${Array.from(t.image.data).join(',')} ${t.minFilter} ${t.magFilter} ${t.wrapS} ${t.flipY} ${t.format} ${t.version} ${t.generateMipmaps} ${td.width}`));
      l.load('d/b.bin', (t) => note('never', t), undefined, (e) => note('b.onError', e));
    },
  },
  audio_loader: {
    routes: { 'au/a.mp3': text('AUDIO'), 'au/empty.mp3': { status: 200, chunks: [] } },
    run(T, note) {
      const m = managerWithLog(T, note, 'm');
      const l = new T.AudioLoader(m);
      l.load('au/a.mp3', (b) => note('a.onLoad', b), undefined, (e) => note('a.onError', e));
      l.load('au/empty.mp3', (b) => note('empty.onLoad', b), undefined, (e) => note('empty.onError', e));
    },
  },
  loading_manager: {
    routes: { 'mod/x.txt': text('modified') },
    run(T, note) {
      const m = managerWithLog(T, note, 'm');
      m.setURLModifier((url) => 'mod/' + url);
      note('resolve', m.resolveURL('café.txt'));
      new T.FileLoader(m).load('x.txt', (d) => note('x', d));
      const loader = new T.Loader();
      m.addHandler(/\.jpg$/i, loader);
      m.addHandler(/\.png$/gi, new T.Loader());
      note('jpg', m.getHandler('foo.jpg') === loader);
      note('png', m.getHandler('foo.png') !== null);
      note('png again', m.getHandler('foo.png') !== null);
      note('none', m.getHandler('foo.gif'));
      m.removeHandler(/\.jpg$/i);
      note('still', m.getHandler('foo.jpg') === loader);
      note('extract', T.LoaderUtils.extractUrlBase('/a/b/c.glb') + ' ' + T.LoaderUtils.extractUrlBase('c.glb'));
      note('resolveURL', [T.LoaderUtils.resolveURL('/x.png', 'https://h.com/a/b/'), T.LoaderUtils.resolveURL('x.png', 'a/'), T.LoaderUtils.resolveURL('data:a,b', 'a/'), T.LoaderUtils.resolveURL('blob:x', 'a/'), T.LoaderUtils.resolveURL('//h/x', 'a/'), T.LoaderUtils.resolveURL('', 'a/')].join(' '));
    },
  },
};
