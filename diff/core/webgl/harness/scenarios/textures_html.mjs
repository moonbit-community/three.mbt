// WebGLTextures: HTMLTexture uploads through texElementImage2D, with a canvas that
// records the HTML-in-Canvas calls (group 1).
export async function run({ src, createMockGL }) {
  const { WebGLExtensions } = await import(src + '/renderers/webgl/WebGLExtensions.js');
  const { WebGLUtils } = await import(src + '/renderers/webgl/WebGLUtils.js');
  const { WebGLCapabilities } = await import(src + '/renderers/webgl/WebGLCapabilities.js');
  const { WebGLState } = await import(src + '/renderers/webgl/WebGLState.js');
  const { WebGLProperties } = await import(src + '/renderers/webgl/WebGLProperties.js');
  const { WebGLInfo } = await import(src + '/renderers/webgl/WebGLInfo.js');
  const { WebGLTextures } = await import(src + '/renderers/webgl/WebGLTextures.js');
  const T = await import(src + '/Three.Core.js');
  const gl = createMockGL({});
  const attrs = {};
  const canvas = gl.canvas;
  canvas.hasAttribute = (n) => { gl.__log.push('canvas.hasAttribute(' + n + ')'); return n in attrs; };
  canvas.setAttribute = (n, v) => { gl.__log.push('canvas.setAttribute(' + n + ', ' + v + ')'); attrs[n] = v; };
  canvas.appendChild = (e) => { gl.__log.push('canvas.appendChild(' + e.id + ')'); e.parentNode = canvas; };
  canvas.requestPaint = () => { gl.__log.push('canvas.requestPaint()'); };
  const extensions = new WebGLExtensions(gl);
  const utils = new WebGLUtils(gl, extensions);
  const capabilities = new WebGLCapabilities(gl, extensions, {}, utils);
  const state = new WebGLState(gl, extensions);
  const properties = new WebGLProperties();
  const info = new WebGLInfo(gl);
  const textures = new WebGLTextures(gl, extensions, state, properties, capabilities, utils, info);
  gl.__clear();
  const e1 = { id: 1, width: 4, height: 4, parentNode: null };
  const e2 = { id: 2, width: 8, height: 8, parentNode: null };
  const h1 = new T.HTMLTexture(e1);
  const h2 = new T.HTMLTexture(e2);
  gl.__note('version', [h1.version, h2.version]);
  textures.setTexture2D(h1, 0);
  textures.setTexture2D(h2, 1);
  textures.setTexture2D(h1, 0);
  gl.__note('version', [h1.version, h2.version]);
  canvas.onpaint({ changedElements: [e2] });
  gl.__note('version', [h1.version, h2.version]);
  textures.setTexture2D(h2, 1);
  textures.setTexture2D(h1, 0);
  // the Chrome 150+ form
  gl.texElementImage2D = function (a, b, c) { gl.__log.push('texElementImage2D(' + a + ', ' + b + ', ' + c.id + ')'); };
  canvas.onpaint({ changedElements: [e1, e2] });
  gl.__note('version', [h1.version, h2.version]);
  textures.setTexture2D(h1, 0);
  textures.setTexture2D(h2, 1);
  h2.dispose();
  gl.__note('onpaint', canvas.onpaint === null ? 'null' : typeof canvas.onpaint);
  // no HTML-in-Canvas support
  delete gl.texElementImage2D;
  h1.needsUpdate = true;
  textures.setTexture2D(h1, 0);
  gl.__note('memory', info.memory.textures);
  return gl.__log;
}
