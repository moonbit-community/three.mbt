// Generated from the `wgslPolyfill` sources of WGSLNodeBuilder.js (verbatim).

///|
/// `wgslPolyfill.tsl_xor`.
let _wgsl_polyfill_code_tsl_xor : String =
  #|fn tsl_xor( a : bool, b : bool ) -> bool { return ( a || b ) && !( a && b ); }

///|
/// `wgslPolyfill.mod_float`.
let _wgsl_polyfill_code_mod_float : String =
  #|fn tsl_mod_float( x : f32, y : f32 ) -> f32 { return x - y * floor( x / y ); }

///|
/// `wgslPolyfill.mod_vec2`.
let _wgsl_polyfill_code_mod_vec2 : String =
  #|fn tsl_mod_vec2( x : vec2f, y : vec2f ) -> vec2f { return x - y * floor( x / y ); }

///|
/// `wgslPolyfill.mod_vec3`.
let _wgsl_polyfill_code_mod_vec3 : String =
  #|fn tsl_mod_vec3( x : vec3f, y : vec3f ) -> vec3f { return x - y * floor( x / y ); }

///|
/// `wgslPolyfill.mod_vec4`.
let _wgsl_polyfill_code_mod_vec4 : String =
  #|fn tsl_mod_vec4( x : vec4f, y : vec4f ) -> vec4f { return x - y * floor( x / y ); }

///|
/// `wgslPolyfill.equals_bool`.
let _wgsl_polyfill_code_equals_bool : String =
  #|fn tsl_equals_bool( a : bool, b : bool ) -> bool { return a == b; }

///|
/// `wgslPolyfill.equals_bvec2`.
let _wgsl_polyfill_code_equals_bvec2 : String =
  #|fn tsl_equals_bvec2( a : vec2f, b : vec2f ) -> vec2<bool> { return vec2<bool>( a.x == b.x, a.y == b.y ); }

///|
/// `wgslPolyfill.equals_bvec3`.
let _wgsl_polyfill_code_equals_bvec3 : String =
  #|fn tsl_equals_bvec3( a : vec3f, b : vec3f ) -> vec3<bool> { return vec3<bool>( a.x == b.x, a.y == b.y, a.z == b.z ); }

///|
/// `wgslPolyfill.equals_bvec4`.
let _wgsl_polyfill_code_equals_bvec4 : String =
  #|fn tsl_equals_bvec4( a : vec4f, b : vec4f ) -> vec4<bool> { return vec4<bool>( a.x == b.x, a.y == b.y, a.z == b.z, a.w == b.w ); }

///|
/// `wgslPolyfill.repeatWrapping_float`.
let _wgsl_polyfill_code_repeat_wrapping_float : String =
  #|fn tsl_repeatWrapping_float( coord: f32 ) -> f32 { return fract( coord ); }

///|
/// `wgslPolyfill.mirrorWrapping_float`.
let _wgsl_polyfill_code_mirror_wrapping_float : String =
  #|fn tsl_mirrorWrapping_float( coord: f32 ) -> f32 { let mirrored = fract( coord * 0.5 ) * 2.0; return 1.0 - abs( 1.0 - mirrored ); }

///|
/// `wgslPolyfill.clampWrapping_float`.
let _wgsl_polyfill_code_clamp_wrapping_float : String =
  #|fn tsl_clampWrapping_float( coord: f32 ) -> f32 { return clamp( coord, 0.0, 1.0 ); }

///|
/// `wgslPolyfill.inverse_mat2`.
let _wgsl_polyfill_code_inverse_mat2 : String =
  #|
  #|fn tsl_inverse_mat2( m : mat2x2<f32> ) -> mat2x2<f32> {
  #|
  #|	let det = m[ 0 ][ 0 ] * m[ 1 ][ 1 ] - m[ 0 ][ 1 ] * m[ 1 ][ 0 ];
  #|
  #|	return mat2x2<f32>(
  #|		m[ 1 ][ 1 ], - m[ 0 ][ 1 ],
  #|		- m[ 1 ][ 0 ], m[ 0 ][ 0 ]
  #|	) * ( 1.0 / det );
  #|
  #|}
  #|

///|
/// `wgslPolyfill.inverse_mat3`.
let _wgsl_polyfill_code_inverse_mat3 : String =
  #|
  #|fn tsl_inverse_mat3( m : mat3x3<f32> ) -> mat3x3<f32> {
  #|
  #|	let a00 = m[ 0 ][ 0 ]; let a01 = m[ 0 ][ 1 ]; let a02 = m[ 0 ][ 2 ];
  #|	let a10 = m[ 1 ][ 0 ]; let a11 = m[ 1 ][ 1 ]; let a12 = m[ 1 ][ 2 ];
  #|	let a20 = m[ 2 ][ 0 ]; let a21 = m[ 2 ][ 1 ]; let a22 = m[ 2 ][ 2 ];
  #|
  #|	let b01 = a22 * a11 - a12 * a21;
  #|	let b11 = - a22 * a10 + a12 * a20;
  #|	let b21 = a21 * a10 - a11 * a20;
  #|
  #|	let det = a00 * b01 + a01 * b11 + a02 * b21;
  #|
  #|	return mat3x3<f32>(
  #|		b01, ( - a22 * a01 + a02 * a21 ), ( a12 * a01 - a02 * a11 ),
  #|		b11, ( a22 * a00 - a02 * a20 ), ( - a12 * a00 + a02 * a10 ),
  #|		b21, ( - a21 * a00 + a01 * a20 ), ( a11 * a00 - a01 * a10 )
  #|	) * ( 1.0 / det );
  #|
  #|}
  #|

///|
/// `wgslPolyfill.inverse_mat4`.
let _wgsl_polyfill_code_inverse_mat4 : String =
  #|
  #|fn tsl_inverse_mat4( m : mat4x4<f32> ) -> mat4x4<f32> {
  #|
  #|	let a00 = m[ 0 ][ 0 ]; let a01 = m[ 0 ][ 1 ]; let a02 = m[ 0 ][ 2 ]; let a03 = m[ 0 ][ 3 ];
  #|	let a10 = m[ 1 ][ 0 ]; let a11 = m[ 1 ][ 1 ]; let a12 = m[ 1 ][ 2 ]; let a13 = m[ 1 ][ 3 ];
  #|	let a20 = m[ 2 ][ 0 ]; let a21 = m[ 2 ][ 1 ]; let a22 = m[ 2 ][ 2 ]; let a23 = m[ 2 ][ 3 ];
  #|	let a30 = m[ 3 ][ 0 ]; let a31 = m[ 3 ][ 1 ]; let a32 = m[ 3 ][ 2 ]; let a33 = m[ 3 ][ 3 ];
  #|
  #|	let b00 = a00 * a11 - a01 * a10;
  #|	let b01 = a00 * a12 - a02 * a10;
  #|	let b02 = a00 * a13 - a03 * a10;
  #|	let b03 = a01 * a12 - a02 * a11;
  #|	let b04 = a01 * a13 - a03 * a11;
  #|	let b05 = a02 * a13 - a03 * a12;
  #|	let b06 = a20 * a31 - a21 * a30;
  #|	let b07 = a20 * a32 - a22 * a30;
  #|	let b08 = a20 * a33 - a23 * a30;
  #|	let b09 = a21 * a32 - a22 * a31;
  #|	let b10 = a21 * a33 - a23 * a31;
  #|	let b11 = a22 * a33 - a23 * a32;
  #|
  #|	let det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;
  #|
  #|	return mat4x4<f32>(
  #|		a11 * b11 - a12 * b10 + a13 * b09,
  #|		a02 * b10 - a01 * b11 - a03 * b09,
  #|		a31 * b05 - a32 * b04 + a33 * b03,
  #|		a22 * b04 - a21 * b05 - a23 * b03,
  #|		a12 * b08 - a10 * b11 - a13 * b07,
  #|		a00 * b11 - a02 * b08 + a03 * b07,
  #|		a32 * b02 - a30 * b05 - a33 * b01,
  #|		a20 * b05 - a22 * b02 + a23 * b01,
  #|		a10 * b10 - a11 * b08 + a13 * b06,
  #|		a01 * b08 - a00 * b10 - a03 * b06,
  #|		a30 * b04 - a31 * b02 + a33 * b00,
  #|		a21 * b02 - a20 * b04 - a23 * b00,
  #|		a11 * b07 - a10 * b09 - a12 * b06,
  #|		a00 * b09 - a01 * b07 + a02 * b06,
  #|		a31 * b01 - a30 * b03 - a32 * b00,
  #|		a20 * b03 - a21 * b01 + a22 * b00
  #|	) * ( 1.0 / det );
  #|
  #|}
  #|

///|
/// `wgslPolyfill.biquadraticTexture`.
let _wgsl_polyfill_code_biquadratic_texture : String =
  #|
  #|fn tsl_biquadraticTexture( map : texture_2d<f32>, coord : vec2f, iRes : vec2u, level : u32 ) -> vec4f {
  #|
  #|	let res = vec2f( iRes );
  #|
  #|	let uvScaled = coord * res;
  #|	let uvWrapping = ( ( uvScaled % res ) + res ) % res;
  #|
  #|	// https://www.shadertoy.com/view/WtyXRy
  #|
  #|	let uv = uvWrapping - 0.5;
  #|	let iuv = floor( uv );
  #|	let f = fract( uv );
  #|
  #|	let rg1 = textureLoad( map, vec2u( iuv + vec2( 0.5, 0.5 ) ) % iRes, level );
  #|	let rg2 = textureLoad( map, vec2u( iuv + vec2( 1.5, 0.5 ) ) % iRes, level );
  #|	let rg3 = textureLoad( map, vec2u( iuv + vec2( 0.5, 1.5 ) ) % iRes, level );
  #|	let rg4 = textureLoad( map, vec2u( iuv + vec2( 1.5, 1.5 ) ) % iRes, level );
  #|
  #|	return mix( mix( rg1, rg2, f.x ), mix( rg3, rg4, f.x ), f.y );
  #|
  #|}
  #|

///|
/// `wgslPolyfill.biquadraticTextureArray`.
let _wgsl_polyfill_code_biquadratic_texture_array : String =
  #|
  #|fn tsl_biquadraticTexture_array( map : texture_2d_array<f32>, coord : vec2f, iRes : vec2u, layer : u32, level : u32 ) -> vec4f {
  #|
  #|	let res = vec2f( iRes );
  #|
  #|	let uvScaled = coord * res;
  #|	let uvWrapping = ( ( uvScaled % res ) + res ) % res;
  #|
  #|	// https://www.shadertoy.com/view/WtyXRy
  #|
  #|	let uv = uvWrapping - 0.5;
  #|	let iuv = floor( uv );
  #|	let f = fract( uv );
  #|
  #|	let rg1 = textureLoad( map, vec2u( iuv + vec2( 0.5, 0.5 ) ) % iRes, layer, level );
  #|	let rg2 = textureLoad( map, vec2u( iuv + vec2( 1.5, 0.5 ) ) % iRes, layer, level );
  #|	let rg3 = textureLoad( map, vec2u( iuv + vec2( 0.5, 1.5 ) ) % iRes, layer, level );
  #|	let rg4 = textureLoad( map, vec2u( iuv + vec2( 1.5, 1.5 ) ) % iRes, layer, level );
  #|
  #|	return mix( mix( rg1, rg2, f.x ), mix( rg3, rg4, f.x ), f.y );
  #|
  #|}
  #|

///|
/// The keys of `wgslPolyfill`, in upstream order, with their sources.
let _wgsl_polyfill_sources : Array[(String, String)] = [
  ("tsl_xor", _wgsl_polyfill_code_tsl_xor),
  ("mod_float", _wgsl_polyfill_code_mod_float),
  ("mod_vec2", _wgsl_polyfill_code_mod_vec2),
  ("mod_vec3", _wgsl_polyfill_code_mod_vec3),
  ("mod_vec4", _wgsl_polyfill_code_mod_vec4),
  ("equals_bool", _wgsl_polyfill_code_equals_bool),
  ("equals_bvec2", _wgsl_polyfill_code_equals_bvec2),
  ("equals_bvec3", _wgsl_polyfill_code_equals_bvec3),
  ("equals_bvec4", _wgsl_polyfill_code_equals_bvec4),
  ("repeatWrapping_float", _wgsl_polyfill_code_repeat_wrapping_float),
  ("mirrorWrapping_float", _wgsl_polyfill_code_mirror_wrapping_float),
  ("clampWrapping_float", _wgsl_polyfill_code_clamp_wrapping_float),
  ("inverse_mat2", _wgsl_polyfill_code_inverse_mat2),
  ("inverse_mat3", _wgsl_polyfill_code_inverse_mat3),
  ("inverse_mat4", _wgsl_polyfill_code_inverse_mat4),
  ("biquadraticTexture", _wgsl_polyfill_code_biquadratic_texture),
  ("biquadraticTextureArray", _wgsl_polyfill_code_biquadratic_texture_array),
]
