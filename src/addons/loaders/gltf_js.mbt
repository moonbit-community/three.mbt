// JS bindings GLTFLoader needs. The glTF JSON stays the JS object `JSON.parse`
// returns, as upstream (the parser reads and annotates it, and `extras` objects are
// assigned into `userData` as they are); these helpers read it with JS semantics.

///|
using @utils {type AddonPromise}

///|
/// `a[ i ]`.
extern "js" fn gltf_at(array : JsValue, index : Int32) -> JsValue = "(a, i) => a[i]"

///|
/// `a.length`.
extern "js" fn gltf_length(array : JsValue) -> Int32 = "(a) => a.length"

///|
/// `!! v`.
extern "js" fn gltf_truthy(value : JsValue) -> Bool = "(v) => !!v"

///|
/// `v !== undefined`.
fn gltf_defined(value : JsValue) -> Bool {
  !value.is_undefined()
}

///|
/// The keys `for ( const k in o )` visits.
extern "js" fn gltf_keys(object : JsValue) -> Array[String] =
  #|(o) => { const r = []; if (o === undefined || o === null) return r; for (const k in o) r.push(k); return r; }

///|
/// `Array.isArray( v )`.
extern "js" fn gltf_is_array(value : JsValue) -> Bool = "(v) => Array.isArray(v)"

///|
/// `a || b`.
extern "js" fn gltf_or(a : JsValue, b : JsValue) -> JsValue = "(a, b) => a || b"

///|
/// `v === n`, with `v` any JS value.
extern "js" fn gltf_equals_number(value : JsValue, n : Double) -> Bool = "(v, n) => v === n"

///|
/// `v === s`.
extern "js" fn gltf_equals_string(value : JsValue, s : String) -> Bool = "(v, s) => v === s"

///|
/// `v === true`.
extern "js" fn gltf_is_true(value : JsValue) -> Bool = "(v) => v === true"

///|
/// `String( v )`, as `+` concatenation writes a value.
extern "js" fn gltf_string(value : JsValue) -> String = "(v) => String(v)"

///|
/// `typeof v === 'string'`.
extern "js" fn gltf_is_string(value : JsValue) -> Bool = "(v) => typeof v === 'string'"

///|
/// `v instanceof ArrayBuffer`.
extern "js" fn gltf_is_array_buffer(value : JsValue) -> Bool = "(v) => v instanceof ArrayBuffer"

///|
/// `JSON.parse( text )` (throws as upstream).
extern "js" fn gltf_json_parse(text : JsValue) -> JsValue = "(t) => JSON.parse(t)"

///|
/// `new TextDecoder().decode( new Uint8Array( buffer, offset, length ) )`.
extern "js" fn gltf_decode_text(
  buffer : JsValue,
  offset : Int32,
  length : Int32,
) -> String = "(b, o, l) => new TextDecoder().decode(new Uint8Array(b, o, l))"

///|
/// `new TextDecoder().decode( data )` on a whole `ArrayBuffer`.
extern "js" fn gltf_decode_all(buffer : JsValue) -> String = "(b) => new TextDecoder().decode(b)"

///|
/// `textDecoder.decode( new Uint8Array( data.slice( 0, 4 ) ) )`.
extern "js" fn gltf_decode_magic(buffer : JsValue) -> String = "(b) => new TextDecoder().decode(new Uint8Array(b.slice(0, 4)))"

///|
/// `new DataView( buffer, offset ).getUint32( index, true )`.
extern "js" fn gltf_get_uint32(
  buffer : JsValue,
  offset : Int32,
  index : Int32,
) -> Double = "(b, o, i) => new DataView(b, o).getUint32(i, true)"

///|
/// `buffer.byteLength`.
extern "js" fn gltf_byte_length(buffer : JsValue) -> Int32 = "(b) => b.byteLength"

///|
/// `buffer.slice( begin, end )` on an `ArrayBuffer`.
extern "js" fn gltf_slice(
  buffer : JsValue,
  begin : Int32,
  end : Int32,
) -> JsValue = "(b, s, e) => b.slice(s, e)"

///|
/// `json.asset === undefined || json.asset.version[ 0 ] < 2`.
extern "js" fn gltf_unsupported_asset(json : JsValue) -> Bool = "(j) => j.asset === undefined || j.asset.version[0] < 2"

///|
/// `Object.assign( userData, extras )` with upstream's type check.
extern "js" fn gltf_assign_extras(user_data : JsValue, def : JsValue) -> Unit =
  #|(userData, def) => {
  #|  if (def.extras !== undefined) {
  #|    if (typeof def.extras === 'object') {
  #|      Object.assign(userData, def.extras);
  #|    } else {
  #|      console.warn('THREE.GLTFLoader: Ignoring primitive type .extras, ' + def.extras);
  #|    }
  #|  }
  #|}

///|
/// `userData.gltfExtensions = userData.gltfExtensions || {}; userData.gltfExtensions[ name ] = value`.
extern "js" fn gltf_add_user_extension(
  user_data : JsValue,
  name : String,
  value : JsValue,
) -> Unit =
  #|(u, n, v) => { u.gltfExtensions = u.gltfExtensions || {}; u.gltfExtensions[n] = v; }

///|
/// `delete o[ key ]`.
extern "js" fn gltf_delete(object : JsValue, key : String) -> Unit = "(o, k) => { delete o[k]; }"

///|
/// `( a ) + ':' + ( b )` with JS concatenation.
extern "js" fn gltf_concat_key(a : JsValue, b : JsValue) -> String = "(a, b) => a + ':' + b"

///|
/// `Object.keys( o ).sort()`.
extern "js" fn gltf_sorted_keys(object : JsValue) -> Array[String] = "(o) => Object.keys(o).sort()"

///|
/// `getImageURIMimeType( uri )`.
extern "js" fn gltf_image_uri_mime_type(uri : JsValue) -> String =
  #|(uri) => {
  #|  if (uri.search(/\.jpe?g($|\?)/i) > 0 || uri.search(/^data\:image\/jpeg/) === 0) return 'image/jpeg';
  #|  if (uri.search(/\.webp($|\?)/i) > 0 || uri.search(/^data\:image\/webp/) === 0) return 'image/webp';
  #|  if (uri.search(/\.ktx2($|\?)/i) > 0 || uri.search(/^data\:image\/ktx2/) === 0) return 'image/ktx2';
  #|  return 'image/png';
  #|}

///|
/// The browser checks of the `GLTFParser` constructor: whether to use `TextureLoader`.
extern "js" fn gltf_use_texture_loader() -> Bool =
  #|() => {
  #|  let isSafari = false;
  #|  let safariVersion = - 1;
  #|  let isFirefox = false;
  #|  let firefoxVersion = - 1;
  #|  if (typeof navigator !== 'undefined' && typeof navigator.userAgent !== 'undefined') {
  #|    const userAgent = navigator.userAgent;
  #|    isSafari = /^((?!chrome|android).)*safari/i.test(userAgent) === true;
  #|    const safariMatch = userAgent.match(/Version\/(\d+)/);
  #|    safariVersion = isSafari && safariMatch ? parseInt(safariMatch[1], 10) : - 1;
  #|    isFirefox = userAgent.indexOf('Firefox') > - 1;
  #|    firefoxVersion = isFirefox ? userAgent.match(/Firefox\/([0-9]+)\./)[1] : - 1;
  #|  }
  #|  return typeof createImageBitmap === 'undefined' || (isSafari && safariVersion < 17) || (isFirefox && firefoxVersion < 98);
  #|}

///|
/// `URL.createObjectURL( new Blob( [ bufferView ], { type: mimeType } ) )`, with
/// `self.URL || self.webkitURL`.
extern "js" fn gltf_create_object_url(
  buffer : JsValue,
  mime_type : JsValue,
) -> String =
  #|(b, t) => { const URL = self.URL || self.webkitURL; return URL.createObjectURL(new Blob([b], { type: t })); }

///|
/// `URL.revokeObjectURL( url )`.
extern "js" fn gltf_revoke_object_url(url : JsValue) -> Unit =
  #|(u) => { const URL = self.URL || self.webkitURL; URL.revokeObjectURL(u); }

///|
/// `console.error( message, value )`.
extern "js" fn gltf_console_error2(message : String, value : JsValue) -> Unit = "(m, v) => console.error(m, v)"

///|
/// `console.error( value )`.
extern "js" fn gltf_console_error(value : JsValue) -> Unit = "(v) => console.error(v)"

///|
/// `console.warn( message )`.
extern "js" fn gltf_console_warn(message : String) -> Unit = "(m) => console.warn(m)"

///|
/// `console.warn( format, value )`.
extern "js" fn gltf_console_warn2(message : String, value : JsValue) -> Unit = "(m, v) => console.warn(m, v)"

///|
extern "js" fn gltf_js_string(value : String) -> JsValue = "(s) => s"

///|
extern "js" fn gltf_js_number(value : Double) -> JsValue = "(n) => n"

///|
/// `Math.floor`.
extern "js" fn gltf_floor(value : Double) -> Double = "Math.floor"

///|
/// `Math.max` with JS NaN semantics.
extern "js" fn gltf_max(a : Double, b : Double) -> Double = "Math.max"

///|
/// `Math.abs`.
extern "js" fn gltf_abs(a : Double) -> Double = "Math.abs"

///|
/// `Math.cos`.
extern "js" fn gltf_cos(a : Double) -> Double = "Math.cos"

///|
/// `Math.sin`.
extern "js" fn gltf_sin(a : Double) -> Double = "Math.sin"

// --- JS objects and maps ---------------------------------------------------------

///|
/// A JS `Map` keyed by object identity, as upstream's `associations`.
#external
priv type GltfJsMap

///|
extern "js" fn GltfJsMap::new() -> GltfJsMap = "() => new Map()"

///|
extern "js" fn GltfJsMap::get(self : GltfJsMap, key : JsValue) -> JsValue = "(m, k) => m.get(k)"

///|
extern "js" fn GltfJsMap::set(
  self : GltfJsMap,
  key : JsValue,
  value : JsValue,
) -> Unit = "(m, k, v) => { m.set(k, v); }"

///|
extern "js" fn GltfJsMap::has(self : GltfJsMap, key : JsValue) -> Bool = "(m, k) => m.has(k)"

///|
extern "js" fn GltfJsMap::size(self : GltfJsMap) -> Int32 = "(m) => m.size"

///|
/// `Array.from( map.values() )`.
extern "js" fn GltfJsMap::values(self : GltfJsMap) -> Array[JsValue] = "(m) => Array.from(m.values())"

///|
/// `sanitizedName in this.nodeNamesUsed` on a plain object, as upstream.
extern "js" fn gltf_in(object : JsValue, key : String) -> Bool = "(o, k) => k in o"

///|
/// `++ o[ key ]`.
extern "js" fn gltf_pre_increment(object : JsValue, key : String) -> JsValue = "(o, k) => ++o[k]"

// --- meshopt decoder ---------------------------------------------------------------

///|
/// `! decoder || ! decoder.supported`.
extern "js" fn gltf_meshopt_unsupported(decoder : JsValue) -> Bool = "(d) => !d || !d.supported"

///|
/// `decoder.decodeGltfBufferAsync` is set.
extern "js" fn gltf_meshopt_has_async(decoder : JsValue) -> Bool = "(d) => d.decodeGltfBufferAsync ? true : false"

///|
/// `decoder.decodeGltfBufferAsync( count, stride, source, mode, filter )`.
extern "js" fn gltf_meshopt_decode_async(
  decoder : JsValue,
  count : JsValue,
  stride : JsValue,
  source : JsValue,
  mode : JsValue,
  filter : JsValue,
) -> AddonPromise = "(d, c, s, src, m, f) => d.decodeGltfBufferAsync(c, s, src, m, f)"

///|
/// `decoder.ready`.
extern "js" fn gltf_meshopt_ready(decoder : JsValue) -> AddonPromise = "(d) => d.ready"

///|
/// `const result = new ArrayBuffer( count * stride ); decoder.decodeGltfBuffer( new Uint8Array( result ), ... ); return result;`.
extern "js" fn gltf_meshopt_decode_sync(
  decoder : JsValue,
  count : JsValue,
  stride : JsValue,
  source : JsValue,
  mode : JsValue,
  filter : JsValue,
) -> JsValue =
  #|(d, count, stride, source, mode, filter) => {
  #|  const result = new ArrayBuffer(count * stride);
  #|  d.decodeGltfBuffer(new Uint8Array(result), count, stride, source, mode, filter);
  #|  return result;
  #|}

///|
/// `new Uint8Array( buffer, byteOffset, byteLength )`.
extern "js" fn gltf_uint8_view(
  buffer : JsValue,
  offset : Int32,
  length : Int32,
) -> JsValue = "(b, o, l) => new Uint8Array(b, o, l)"

///|
/// `res.buffer`.
extern "js" fn gltf_buffer_of(value : JsValue) -> JsValue = "(v) => v.buffer"
