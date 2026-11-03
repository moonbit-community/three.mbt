// WebGLTextures: DOM image sources with fake DOM classes (same source as the MoonBit
// side): resizing to the max texture size, canvas reuse, ImageBitmap, natural sizes and
// VideoFrame display sizes (group 1).
const INSTALL_DOM = `(gl) => {
  let n = 0;
  const id = (o) => (o && o.__mock ? o.__mock + '#' + o.__id : 'object');
  class HTMLCanvasElement { constructor(w, h) { this.__mock = 'Canvas'; this.__id = ++n; this.width = w; this.height = h; }
    getContext(t) { const c = this; gl.__log.push('getContext(' + t + ') on ' + id(c)); return { drawImage(i, x, y, w, h) { gl.__log.push('drawImage(' + id(i) + ', ' + [x, y, w, h].join(', ') + ') on ' + id(c) + ' ' + c.width + 'x' + c.height); } }; } }
  class HTMLImageElement { constructor(nw, nh, w, h) { this.__mock = 'Image'; this.__id = ++n; this.naturalWidth = nw; this.naturalHeight = nh; this.width = w; this.height = h; } }
  class ImageBitmap { constructor(w, h) { this.__mock = 'Bitmap'; this.__id = ++n; this.width = w; this.height = h; } }
  class VideoFrame { constructor(w, h) { this.__mock = 'Frame'; this.__id = ++n; this.displayWidth = w; this.displayHeight = h; } }
  const saved = { document: globalThis.document };
  globalThis.HTMLCanvasElement = HTMLCanvasElement;
  globalThis.HTMLImageElement = HTMLImageElement;
  globalThis.ImageBitmap = ImageBitmap;
  globalThis.VideoFrame = VideoFrame;
  globalThis.document = { createElementNS(ns, name) { gl.__log.push('createElementNS(' + name + ')'); return new HTMLCanvasElement(300, 150); } };
  return {
    canvas: (w, h) => new HTMLCanvasElement(w, h),
    image: (nw, nh, w, h) => new HTMLImageElement(nw, nh, w, h),
    bitmap: (w, h) => new ImageBitmap(w, h),
    frame: (w, h) => new VideoFrame(w, h),
    uninstall: () => { delete globalThis.HTMLCanvasElement; delete globalThis.HTMLImageElement; delete globalThis.ImageBitmap; delete globalThis.VideoFrame; if (saved.document === undefined) delete globalThis.document; else globalThis.document = saved.document; },
  };
}`;
export async function run({ src, createMockGL }) {
  const { WebGLExtensions } = await import(src + '/renderers/webgl/WebGLExtensions.js');
  const { WebGLUtils } = await import(src + '/renderers/webgl/WebGLUtils.js');
  const { WebGLCapabilities } = await import(src + '/renderers/webgl/WebGLCapabilities.js');
  const { WebGLState } = await import(src + '/renderers/webgl/WebGLState.js');
  const { WebGLProperties } = await import(src + '/renderers/webgl/WebGLProperties.js');
  const { WebGLInfo } = await import(src + '/renderers/webgl/WebGLInfo.js');
  const { WebGLTextures } = await import(src + '/renderers/webgl/WebGLTextures.js');
  const T = await import(src + '/Three.Core.js');
  const gl = createMockGL({ parameters: { MAX_TEXTURE_SIZE: 4, MAX_CUBE_MAP_TEXTURE_SIZE: 2 } });
  const dom = (0, eval)(INSTALL_DOM)(gl);
  const extensions = new WebGLExtensions(gl);
  const utils = new WebGLUtils(gl, extensions);
  const capabilities = new WebGLCapabilities(gl, extensions, {}, utils);
  const state = new WebGLState(gl, extensions);
  const properties = new WebGLProperties();
  const info = new WebGLInfo(gl);
  const textures = new WebGLTextures(gl, extensions, state, properties, capabilities, utils, info);
  gl.__clear();
  const upload = (image, slot) => { const t = new T.Texture(image); t.needsUpdate = true; textures.setTexture2D(t, slot); return t; };
  gl.__note('step', 'canvas too big');
  upload(dom.canvas(8, 4), 0);
  gl.__note('step', 'fractional scale');
  upload(dom.canvas(10, 3), 0);
  gl.__note('step', 'image: natural size, shared canvas');
  upload(dom.image(16, 16, 1, 1), 1);
  gl.__note('step', 'image without natural size');
  upload(dom.image(0, 0, 2, 2), 2);
  gl.__note('step', 'image bitmap');
  upload(dom.bitmap(2, 2), 3);
  gl.__note('step', 'video frame');
  upload(dom.frame(8, 2), 4);
  gl.__note('step', 'small canvas');
  const t = upload(dom.canvas(2, 2), 5);
  t.mipmaps = [dom.image(4, 4, 4, 4), dom.canvas(2, 2)];
  t.needsUpdate = true;
  textures.setTexture2D(t, 5);
  gl.__note('step', 'plain object with data');
  upload({ width: 8, height: 8, data: null }, 6);
  gl.__note('step', 'data texture too big');
  const d = new T.DataTexture(new Uint8Array(4), 8, 8);
  d.needsUpdate = true;
  textures.setTexture2D(d, 7);
  gl.__note('step', 'cube faces get their own canvases');
  const k = new T.CubeTexture([0, 1, 2, 3, 4, 5].map(() => dom.canvas(4, 4)));
  k.needsUpdate = true;
  textures.setTextureCube(k, 8);
  dom.uninstall();
  return gl.__log;
}
