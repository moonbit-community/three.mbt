// Upstream side of the G1 (nodes/math, utils, code, geometry, procedural, shapes, fog)
// shader scenarios. The MoonBit side is src/nodes/g1_shader_diff_test.mbt; scenario
// names start with `g1_`.
//
// The base NodeBuilder leaves the backend methods abstract, so both sides build with
// `G1Builder`, a NodeBuilder subclass whose backend methods print their arguments
// (`getBitcastMethod`, the float packing methods, `getTernary`, `getInstanceIndex`),
// whose `buildFunctionCode` writes a layout function in a WGSL-like form, and whose
// parser (`G1Function`) reads that form back. A scenario runs with `wgsl` (the WebGPU
// renderer stub, WebGPU coordinate system) or `glsl` (the same renderer with
// `backend.isWebGPUBackend = false`, the WebGL coordinate system and `getFunctionOperator`
// mapping `^^` to `xor_fn`). Each record also has `codes`, the function code the build
// registered. The JS helpers between the `@@G1 shared` markers are copied verbatim into
// the MoonBit file.

// @@G1 shared begin
const g1ParseFunction = ( source ) => {

	const m = /^fn (\w+)\( (.*?) \) -> (\w+) \{/.exec( source );
	const inputs = m[ 2 ] === '' ? [] : m[ 2 ].split( ', ' ).map( ( p ) => p.split( ' : ' ) );
	return [ m[ 1 ], m[ 3 ], inputs ];

};

const g1FunctionCode = ( source, name, newName ) => source.replace( 'fn ' + name + '(', 'fn ' + newName + '(' );
// @@G1 shared end

export async function runUpstream( src ) {

	const T = await import( src + '/Three.TSL.js' );
	const THREE = await import( src + '/Three.WebGPU.js' );
	const { default: NodeBuilder } = await import( src + '/nodes/core/NodeBuilder.js' );
	const { default: NodeFunction } = await import( src + '/nodes/core/NodeFunction.js' );
	const { default: NodeFunctionInput } = await import( src + '/nodes/core/NodeFunctionInput.js' );
	const { default: NodeParser } = await import( src + '/nodes/core/NodeParser.js' );
	const { WebGPURenderer, WebGLCoordinateSystem, Vector3, Color } = THREE;
	const { cubeMapNode } = await import( src + '/nodes/utils/CubeMapNode.js' );

	class G1Function extends NodeFunction {

		constructor( source ) {

			const [ name, type, params ] = g1ParseFunction( source );
			super( type, params.map( ( [ n, t ] ) => new NodeFunctionInput( t, n ) ), name );
			this.source = source;

		}

		getCode( name = this.name ) {

			return g1FunctionCode( this.source, this.name, name );

		}

	}

	class G1Parser extends NodeParser {

		parseFunction( source ) {

			return new G1Function( source );

		}

	}

	const fmt = ( v ) => v === null || v === undefined ? '-' : String( v );

	class G1Builder extends NodeBuilder {

		constructor( object, renderer, glsl, storage ) {

			super( object, renderer, new G1Parser() );
			this.glsl = glsl;
			this.storage = storage;

		}

		isAvailable( name ) {

			return this.storage && name === 'storageBuffer';

		}

		generateTexture( texture, p, uv, depth, offset ) {

			return `tex(${ p }, ${ uv }, ${ fmt( depth ) }, ${ fmt( offset ) })`;

		}

		generateTextureLevel( texture, p, uv, level, depth, offset ) {

			return `texLevel(${ p }, ${ uv }, ${ level }, ${ fmt( depth ) }, ${ fmt( offset ) })`;

		}

		generateTextureLoad( texture, p, uv, level, depth, offset ) {

			return `texLoad(${ p }, ${ uv }, ${ fmt( level ) }, ${ fmt( depth ) }, ${ fmt( offset ) })`;

		}

		generateTextureSize( texture, p, level ) {

			return `size(${ p }, ${ level })`;

		}

		registerTransform() {}

		getFunctionOperator( op ) {

			return this.glsl && op === '^^' ? 'xor_fn' : null;

		}

		getTernary( c, a, b ) {

			return `select( ${ b }, ${ a }, ${ c } )`;

		}

		getBitcastMethod( type, inputType ) {

			return `bitcast<${ type }:${ inputType }>`;

		}

		getFloatPackingMethod( encoding, layout ) {

			return `pack_${ encoding }_${ layout }`;

		}

		getFloatUnpackingMethod( encoding, layout ) {

			return `unpack_${ encoding }_${ layout }`;

		}

		getInstanceIndex() {

			return 'instance_index';

		}

		buildFunctionCode( shaderNode ) {

			const layout = shaderNode.layout;
			const flowData = this.flowShaderNode( shaderNode );
			const parameters = layout.inputs.map( ( input ) => input.name + ' : ' + this.getType( input.type ) );
			let code = `fn ${ layout.name }( ${ parameters.join( ', ' ) } ) -> ${ this.getType( layout.type ) } {\n${ flowData.vars }\n${ flowData.code }\n`;
			if ( flowData.result ) code += `\treturn ${ flowData.result };\n`;
			code += '\n}\n';
			return code;

		}

	}

	const canvas = { style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } };
	const wgslRenderer = new WebGPURenderer( { canvas } );
	wgslRenderer._bindings = undefined;
	const glslRenderer = new WebGPURenderer( { canvas } );
	glslRenderer._bindings = undefined;
	glslRenderer.backend.isWebGPUBackend = false;
	Object.defineProperty( glslRenderer.backend, 'coordinateSystem', { get: () => WebGLCoordinateSystem } );

	const { float, int, uint, bool, vec2, vec3, vec4, ivec2, ivec3, uvec2, uvec3, uvec4, ivec4, bvec2, bvec3, mat2, mat3, mat4, uniform, Fn, If, Loop, Break, Continue, Discard, Return } = T;

	const fv = ( v ) => float( v ).toVar();
	const v3 = () => vec3( 1, 2, 3 ).toVar();
	const v2 = () => vec2( 1, 2 ).toVar();
	const v4 = () => vec4( 1, 2, 3, 4 ).toVar();
	const iv = ( v ) => int( v ).toVar();
	const uv_ = ( v ) => uint( v ).toVar();
	const m3 = () => mat3( 1, 0, 0, 0, 1, 0, 0, 0, 1 ).toVar();
	const m4 = () => mat4().toVar();
	const m2 = () => mat2( 1, 2, 3, 4 ).toVar();

	// [ name, stage, glsl, make, reversed ]
	const scenarios = [];
	const add = ( name, make, { glsl = false, stage = 'fragment', reversed = false, mesh = false, storage = false } = {} ) => scenarios.push( [ 'g1_' + name, stage, glsl, make, reversed, mesh, storage ] );
	const both = ( name, make, opts = {} ) => {

		add( name, make, opts );
		add( name + '_glsl', make, { ...opts, glsl: true } );

	};

	// --- OperatorNode
	both( 'op_add_float', () => T.add( fv( 1 ), 2 ) );
	both( 'op_add_variadic', () => T.add( fv( 1 ), 2, fv( 3 ), 4 ) );
	both( 'op_sub_vec3_float', () => v3().sub( fv( 1 ) ) );
	both( 'op_mul_vec2_vec3', () => v2().mul( v3() ) );
	both( 'op_div_int_float', () => iv( 4 ).div( 2.5 ) );
	both( 'op_div_int_int', () => iv( 4 ).div( iv( 2 ) ) );
	both( 'op_mul_uint_weak', () => uv_( 3 ).mul( 2 ) );
	both( 'op_mul_uint_negative', () => uv_( 3 ).mul( - 2 ) );
	both( 'op_mul_uint_int', () => uv_( 3 ).mul( iv( 2 ) ) );
	both( 'op_add_bool_weak', () => bool( true ).toVar().add( 1 ) );
	both( 'op_mod_float', () => fv( 5 ).mod( 2 ) );
	both( 'op_mod_vec3_float', () => v3().mod( fv( 2 ) ) );
	both( 'op_mod_int', () => iv( 5 ).mod( iv( 2 ) ) );
	both( 'op_equal_float', () => fv( 1 ).equal( 2 ) );
	both( 'op_not_equal_vec3', () => v3().notEqual( v3() ) );
	both( 'op_less_than_vec2_float', () => v2().lessThan( fv( 1 ) ) );
	both( 'op_greater_than_int_uint', () => iv( 1 ).greaterThan( uv_( 2 ) ) );
	both( 'op_less_than_equal', () => fv( 1 ).lessThanEqual( 2 ) );
	both( 'op_greater_than_equal_vec4', () => v4().greaterThanEqual( vec4( 0 ) ) );
	both( 'op_and', () => bool( true ).toVar().and( bool( false ).toVar() ) );
	both( 'op_and_variadic', () => T.and( bool( true ).toVar(), bool( false ).toVar(), bool( true ).toVar() ) );
	both( 'op_and_bvec', () => bvec2( true, false ).toVar().and( bvec2( false, true ).toVar() ) );
	both( 'op_or', () => fv( 1 ).greaterThan( 0 ).or( fv( 2 ).lessThan( 3 ) ) );
	both( 'op_not', () => bool( true ).toVar().not() );
	both( 'op_not_vec3', () => bvec3( true, false, true ).toVar().not() );
	both( 'op_xor', () => bool( true ).toVar().xor( bool( false ).toVar() ) );
	both( 'op_bit_and_int', () => iv( 6 ).bitAnd( 3 ) );
	both( 'op_bit_or_uint', () => uv_( 6 ).bitOr( uv_( 1 ) ) );
	both( 'op_bit_xor_ivec', () => ivec2( 1, 2 ).toVar().bitXor( ivec2( 3, 4 ) ) );
	both( 'op_bit_and_float', () => fv( 6 ).bitAnd( 3 ) );
	both( 'op_bit_not', () => iv( 6 ).bitNot() );
	both( 'op_shift_left_int', () => iv( 1 ).shiftLeft( iv( 3 ) ) );
	both( 'op_shift_right_uvec', () => uvec3( 8, 16, 32 ).toVar().shiftRight( 2 ) );
	both( 'op_mat3_vec3', () => m3().mul( v3() ) );
	both( 'op_vec3_mat3', () => v3().mul( m3() ) );
	both( 'op_mat4_mat4', () => m4().mul( m4() ) );
	both( 'op_mat3_float', () => m3().mul( fv( 2 ) ) );
	both( 'op_float_mat2', () => fv( 2 ).mul( m2() ) );
	both( 'op_mat4_vec3', () => m4().mul( v3() ) );
	both( 'op_mat2_mat3', () => m2().add( m3() ) );
	add( 'op_void_statement', () => Fn( () => {

		const v = fv( 1 );
		v.add( 2 );
		T.mul( v, v );
		return v;

	} )() );
	both( 'op_assign_ops', () => Fn( () => {

		const v = fv( 1 );
		v.addAssign( 2 );
		v.subAssign( 1 );
		v.mulAssign( 3 );
		v.divAssign( 2 );
		v.modAssign( 5 );
		const i = iv( 3 );
		i.bitAndAssign( 1 );
		i.bitOrAssign( 2 );
		i.bitXorAssign( 7 );
		i.shiftLeftAssign( 1 );
		i.shiftRightAssign( 1 );
		return v.add( float( i ) );

	} )() );
	add( 'op_increment', () => Fn( () => {

		const i = iv( 0 );
		i.increment();
		i.decrement();
		i.incrementBefore();
		i.decrementBefore();
		const j = iv( 2 );
		const prev = T.increment( j );
		return prev.add( j );

	} )() );

	// --- MathNode
	const one = [ 'radians', 'degrees', 'exp', 'exp2', 'log', 'log2', 'sqrt', 'inverseSqrt', 'floor', 'ceil', 'normalize', 'fract', 'sin', 'sinh', 'cos', 'cosh', 'tan', 'tanh', 'asin', 'asinh', 'acos', 'acosh', 'atan', 'atanh', 'abs', 'sign', 'length', 'lengthSq', 'negate', 'oneMinus', 'dFdx', 'dFdy', 'round', 'reciprocal', 'trunc', 'fwidth', 'saturate', 'cbrt', 'pow2', 'pow3', 'pow4' ];
	for ( const m of one ) {

		add( 'math_' + m + '_float', () => fv( 0.5 )[ m ]() );
		add( 'math_' + m + '_vec3', () => v3()[ m ]() );

	}

	for ( const m of one ) add( 'math_' + m + '_int', () => iv( 2 )[ m ]() );
	add( 'math_two_int', () => vec4( T.step( iv( 1 ), iv( 2 ) ), T.reflect( iv( 1 ), iv( 2 ) ), T.distance( iv( 1 ), iv( 2 ) ), T.difference( iv( 1 ), iv( 2 ) ) ).add( vec4( T.cross( ivec3( 1, 2, 3 ).toVar(), ivec3( 3, 2, 1 ) ), T.atan( iv( 1 ), iv( 2 ) ) ) ) );
	add( 'math_three_int', () => vec3( T.refract( iv( 1 ), iv( 2 ), iv( 3 ) ), T.smoothstep( iv( 0 ), iv( 1 ), iv( 2 ) ), T.faceForward( iv( 1 ), iv( 2 ), iv( 3 ) ) ).add( T.clamp( iv( 5 ), iv( 0 ), iv( 3 ) ) ).add( T.min( iv( 1 ), iv( 2 ) ) ) );
	for ( const m of [ 'abs', 'oneMinus' ] ) add( 'math_' + m + '_uvec2', () => uvec2( 1, 2 ).toVar()[ m ]() );
	add( 'math_dfdx_vertex', () => fv( 1 ).dFdx(), { stage: 'vertex' } );
	add( 'math_dfdy_compute', () => v2().dFdy(), { stage: 'compute' } );
	add( 'math_all_any', () => T.all( bvec3( true, false, true ).toVar() ).and( bvec2( true, true ).toVar().any() ) );
	add( 'math_transpose', () => m3().transpose() );
	add( 'math_determinant', () => m3().determinant() );
	add( 'math_inverse', () => m4().inverse() );
	add( 'math_mat_methods_mat2', () => m2().transpose().mul( m2().inverse() ).mul( m2().determinant() ) );
	both( 'math_min_float', () => T.min( fv( 1 ), 2 ) );
	both( 'math_min_vec3_float', () => v3().min( fv( 1 ) ) );
	both( 'math_max_variadic', () => T.max( fv( 1 ), fv( 2 ), 3, fv( 4 ) ) );
	both( 'math_max_int', () => iv( 1 ).max( iv( 3 ) ) );
	both( 'math_max_uint_weak', () => uv_( 1 ).max( 3 ) );
	both( 'math_step_float_vec3', () => T.step( fv( 0.5 ), v3() ) );
	both( 'math_step_chain', () => v3().step( fv( 0.5 ) ) );
	both( 'math_reflect', () => T.reflect( v3(), v3().normalize() ) );
	both( 'math_distance', () => T.distance( v3(), vec3( 0 ) ) );
	both( 'math_difference', () => T.difference( fv( 1 ), 3 ) );
	both( 'math_dot_vec2', () => v2().dot( vec2( 1, 1 ) ) );
	both( 'math_cross', () => v3().cross( vec3( 0, 1, 0 ) ) );
	both( 'math_pow_int', () => iv( 2 ).pow( 3 ) );
	both( 'math_pow_vec3_float', () => v3().pow( fv( 2 ) ) );
	both( 'math_atan2', () => T.atan( fv( 1 ), fv( 2 ) ) );
	both( 'math_atan2_chain', () => v2().atan( vec2( 1, 2 ) ) );
	both( 'math_transform_direction', () => T.transformDirection( v3(), m4() ) );
	both( 'math_transform_direction_mat_first', () => T.transformDirection( m4(), v3() ) );
	both( 'math_transform_normal', () => v3().transformNormalByViewMatrix( m4() ).add( v3().transformNormalByInverseViewMatrix( m4() ) ) );
	both( 'math_mix_float', () => T.mix( fv( 0 ), fv( 1 ), 0.5 ) );
	both( 'math_mix_vec3_float_t', () => T.mix( v3(), vec3( 0 ), fv( 0.5 ) ) );
	both( 'math_mix_vec3_vec3_t', () => T.mix( v3(), vec3( 0 ), v3() ) );
	both( 'math_mix_chain', () => fv( 0.25 ).mix( v3(), vec3( 1 ) ) );
	both( 'math_clamp_default', () => T.clamp( v3() ) );
	both( 'math_clamp_low', () => fv( 3 ).clamp( 1 ) );
	both( 'math_clamp_int', () => iv( 3 ).clamp( iv( 0 ), 2 ) );
	both( 'math_refract', () => T.refract( v3(), vec3( 0, 1, 0 ), fv( 1.5 ) ) );
	both( 'math_smoothstep', () => T.smoothstep( 0, 1, fv( 0.3 ) ) );
	both( 'math_smoothstep_chain', () => v3().smoothstep( 0, fv( 2 ) ) );
	both( 'math_face_forward', () => T.faceForward( v3(), v3(), vec3( 0, 0, 1 ) ) );
	both( 'math_faceforward_alias', () => T.faceforward( v3(), v3(), v3() ).add( T.inversesqrt( fv( 4 ) ) ) );
	add( 'math_rand', () => T.rand( v2() ) );
	add( 'math_rand_chain_twice', () => v2().rand().add( vec2( 3, 4 ).toVar().rand() ) );
	add( 'math_constants', () => vec4( T.PI, T.TWO_PI, T.HALF_PI, T.EPSILON ).add( T.INFINITY ) );
	add( 'math_mix_element', () => T.mixElement( fv( 0.5 ), v3(), vec3( 2 ) ).add( T.smoothstepElement( fv( 0.5 ), 0, 1 ) ).add( T.stepElement( fv( 0.5 ), 0.2 ) ) );

	// --- MathUtils
	add( 'math_utils', () => T.parabola( fv( 0.5 ), 2 ).add( T.gain( fv( 0.25 ), 3 ) ).add( T.pcurve( fv( 0.5 ), 2, 3 ) ).add( T.sinc( fv( 0.5 ), fv( 2 ) ) ) );

	// --- ConditionalNode
	both( 'cond_select_float', () => T.select( fv( 1 ).greaterThan( 0 ), 1.5, fv( 2 ) ) );
	add( 'cond_select_no_else', () => fv( 1 ).greaterThan( 0 ).select( v3() ) );
	add( 'cond_select_uniform_flow', () => T.select( fv( 1 ).greaterThan( 0 ), fv( 2 ), 3 ).uniformFlow() );
	add( 'cond_select_vector_cond', () => T.select( v3().greaterThan( vec3( 1 ) ), v3(), vec3( 0 ) ) );
	add( 'cond_select_vector_cond_no_else', () => T.select( bvec2( true, false ).toVar(), v2() ) );
	add( 'cond_select_vector_cond_scalar_values', () => T.select( bvec3( true, false, true ).toVar(), fv( 1 ), fv( 2 ) ) );
	add( 'cond_select_type_from_else', () => T.select( bool( true ).toVar(), fv( 1 ), v4() ) );
	add( 'cond_if_else', () => Fn( () => {

		const r = fv( 0 );
		const x = fv( 2 );
		If( x.greaterThan( 1 ), () => {

			r.assign( 1 );

		} ).ElseIf( x.lessThan( 0 ), () => {

			r.assign( 2 );

		} ).Else( () => {

			r.assign( 3 );

		} );
		return r;

	} )() );
	add( 'cond_if_const_guard', () => Fn( () => {

		const r = fv( 0 );
		const c = bool( true ).toConst();
		If( c, () => {

			r.assign( 1 );

		} );
		If( c, () => {

			r.addAssign( 2 );

		} );
		return r;

	} )() );
	add( 'cond_return_in_layout', () => Fn( ( [ x ] ) => {

		If( x.greaterThan( 1 ), () => {

			return x.mul( 2 );

		} );
		return x;

	}, { x: 'float', return: 'float' } )( fv( 3 ) ) );
	add( 'cond_return_inline', () => Fn( ( [ x ] ) => {

		If( x.greaterThan( 1 ), () => {

			return x.mul( 2 );

		} ).Else( () => {

			return x;

		} );
		return x;

	} )( fv( 3 ) ) );
	add( 'cond_switch', () => Fn( () => {

		const r = fv( 0 );
		const i = iv( 2 );
		T.Switch( i ).Case( 0, () => {

			r.assign( 1 );

		} ).Case( 1, 2, () => {

			r.assign( 2 );

		} ).Default( () => {

			r.assign( 3 );

		} );
		return r;

	} )() );

	// --- LoopNode
	add( 'loop_count', () => Fn( () => {

		const s = fv( 0 );
		Loop( 4, ( { i } ) => {

			s.addAssign( float( i ) );

		} );
		return s;

	} )() );
	add( 'loop_shared_count', () => Fn( () => {

		const s = fv( 0 );
		Loop( 3, ( { i } ) => {

			s.addAssign( float( i ) );

		} );
		return s;

	} )() );
	add( 'loop_node_count', () => Fn( () => {

		const s = fv( 0 );
		const n = iv( 5 );
		Loop( n, iv( 2 ), ( { i, j } ) => {

			s.addAssign( float( i.add( j ) ) );

		} );
		return s;

	} )() );
	add( 'loop_while', () => Fn( () => {

		const s = fv( 0 );
		Loop( s.lessThan( 10 ), () => {

			s.addAssign( 1 );

		} );
		return s;

	} )() );
	add( 'loop_forever_break', () => Fn( () => {

		const s = fv( 0 );
		Loop( () => {

			s.addAssign( 1 );
			If( s.greaterThan( 3 ), () => {

				Break();

			} );
			Continue();

		} );
		return s;

	} )() );
	add( 'loop_ranges', () => Fn( () => {

		const s = fv( 0 );
		Loop( { start: 10, end: 0 }, ( { i } ) => {

			s.addAssign( float( i ) );

		} );
		Loop( { start: float( 0 ), end: float( 3 ), type: 'float', condition: '<=', name: 'x' }, ( { x } ) => {

			s.addAssign( x );

		} );
		Loop( { start: 4 }, ( { i } ) => {

			s.addAssign( float( i ) );

		} );
		Loop( { end: iv( 6 ), type: 'uint' }, ( { i } ) => {

			s.addAssign( float( i ) );

		} );
		Loop( { start: 0, end: 8, update: 2 }, ( { i } ) => {

			s.addAssign( float( i ) );

		} );
		Loop( { start: 8, end: 0, condition: '>', update: '-= 2' }, ( { i } ) => {

			s.addAssign( float( i ) );

		} );
		Loop( { start: 0, end: 10, update: iv( 3 ) }, ( { i } ) => {

			s.addAssign( float( i ) );

		} );
		Loop( { start: 1, end: 100, update: ( { i } ) => {

			i.mulAssign( 2 );

		} }, ( { i } ) => {

			s.addAssign( float( i ) );

		} );
		return s;

	} )() );
	add( 'loop_bad_update', () => Fn( () => {

		const s = fv( 0 );
		Loop( { start: 0, end: 2, update: true }, () => {

			s.addAssign( 1 );

		} );
		return s;

	} )() );

	// --- Code
	add( 'code_expression', () => Fn( () => {

		T.expression( 'doSomething()' ).toStack();
		return T.expression( 'myValue', 'vec3' ).add( 1 );

	} )() );
	const wgslAdd = T.wgslFn( 'fn addThree( a : vec3, b : float ) -> vec3 { return a + b; }' );
	add( 'code_wgsl_fn', () => wgslAdd( v3(), fv( 2 ) ) );
	add( 'code_wgsl_fn_named', () => wgslAdd( { b: fv( 2 ), a: v3() } ) );
	add( 'code_wgsl_fn_missing', () => wgslAdd( { a: v3() } ) );
	add( 'code_wgsl_fn_too_few', () => wgslAdd( v3() ) );
	add( 'code_wgsl_fn_too_many', () => wgslAdd( v3(), fv( 1 ), fv( 2 ) ) );
	const helper = T.code( '// helper code' );
	const wgslIncl = T.glslFn( 'fn useHelper( x : float ) -> float { return x; }', [ helper ] );
	add( 'code_fn_includes', () => wgslIncl( fv( 1 ) ) );
	add( 'code_call_chain', () => T.call( wgslAdd, v3(), fv( 3 ) ) );
	const wgslHelper = T.wgsl( '// wgsl helper' );
	const fnIncludes = T.wgslFn( 'fn useHelpers( x : float ) -> float { return x; }', [ T.js( '// js helper' ), wgslHelper, T.glsl( '// glsl helper', [ wgslHelper ] ) ] );
	add( 'code_js_wgsl_glsl', () => fnIncludes( fv( 2 ) ) );

	// --- Bitcast, packing
	add( 'bitcast', () => T.bitcast( fv( 1 ), 'uint' ).add( T.floatBitsToInt( v2() ).x ).add( T.intBitsToFloat( iv( 3 ) ) ).add( T.uintBitsToFloat( uv_( 4 ) ) ) );
	add( 'bitcast_vec', () => T.floatBitsToUint( v3() ) );
	add( 'pack_float', () => vec4( T.packSnorm2x16( v2() ), T.packUnorm2x16( v2() ), T.packHalf2x16( v2() ), T.packSnorm4x8( v4() ) ).add( T.packUnorm4x8( v4() ) ) );
	add( 'unpack_float', () => T.unpackSnorm2x16( uv_( 1 ) ).add( T.unpackUnorm2x16( uv_( 2 ) ) ).add( T.unpackHalf2x16( uv_( 3 ) ) ).xyxy.add( T.unpackSnorm4x8( uv_( 4 ) ) ).add( T.unpackUnorm4x8( uv_( 5 ) ) ) );
	add( 'packed4x8', () => vec4( T.dot4U8Packed( uv_( 1 ), uv_( 2 ) ), T.dot4I8Packed( uv_( 3 ), uv_( 4 ) ), T.pack4xI8( ivec4( 1, 2, 3, 4 ).toVar() ), T.pack4xU8( uvec4( 1, 2, 3, 4 ).toVar() ) ) );
	add( 'packed4x8_clamp_unpack', () => vec4( T.pack4xI8Clamp( ivec4( 1, 2, 3, 4 ).toVar() ), T.pack4xU8Clamp( uvec4( 1, 2, 3, 4 ).toVar() ), 0, 0 ).add( vec4( T.unpack4xI8( uv_( 7 ) ) ) ).add( vec4( T.unpack4xU8( uv_( 8 ) ) ) ) );
	both( 'bitcount', () => vec3( T.countTrailingZeros( uv_( 8 ) ), T.countLeadingZeros( iv( 8 ) ), T.countOneBits( uv_( 7 ) ) ) );
	add( 'bitcount_vec_glsl', () => vec3( T.countOneBits( ivec3( 1, 2, 3 ).toVar() ) ).add( vec3( T.countTrailingZeros( uvec3( 1, 2, 3 ).toVar() ) ) ), { glsl: true } );

	// --- Hash, noise, rotate, UV utils, remap
	add( 'hash', () => T.hash( uv_( 3 ) ).add( T.hash( fv( 2 ) ) ) );
	add( 'tri_noise3d', () => T.triNoise3D( v3(), fv( 1 ), fv( 0.5 ) ) );
	add( 'rotate_vec2', () => T.rotate( v2(), fv( 1 ) ) );
	add( 'rotate_vec3', () => T.rotate( v3(), v3() ) );
	add( 'rotate_vec3_zyx', () => T.rotate( v3(), v3(), 'ZYX' ) );
	add( 'rotate_set_order', () => T.rotate( v3(), v3() ).setOrder( 'YXZ' ) );
	add( 'rotate_uv', () => T.rotateUV( v2(), fv( 1 ) ).add( T.rotateUV( v2(), fv( 1 ), vec2( 0.25 ) ) ) );
	add( 'spherize_uv', () => T.spherizeUV( v2(), fv( 1 ) ) );
	add( 'remap', () => T.remap( fv( 0.5 ), 0, 1 ).add( fv( 0.5 ).remap( 0, 1, 2, 3 ) ).add( fv( 0.5 ).remap( 0, 1, 2, 3, true ) ) );
	add( 'remap_clamp', () => T.remapClamp( fv( 0.5 ), 0, 1 ).add( v3().remapClamp( 0, 2, - 1, 1 ) ) );

	// --- Timer, oscillators, packing
	add( 'timer', () => vec3( T.time, T.deltaTime, float( T.frameId ) ) );
	add( 'oscillators', () => vec4( T.oscSine(), T.oscSquare(), T.oscTriangle(), T.oscSawtooth( fv( 2 ) ) ) );
	add( 'packing', () => T.packNormalToRGB( v3() ).add( T.unpackRGBToNormal( v3() ) ).add( T.unpackNormal( v2() ) ) );

	// --- Discard, debug, events, overloading, range, max mip level
	add( 'discard', () => Fn( () => {

		const x = fv( 1 );
		Discard( x.greaterThan( 2 ) );
		x.lessThan( 0 ).discard();
		If( x.equal( 5 ), () => {

			Discard();

		} );
		Return();
		return x;

	} )() );
	add( 'debug', () => {

		const snippets = [];
		const d = T.debug( v3().add( 1 ), ( builder, snippet ) => snippets.push( snippet ) );
		return d.mul( 2 );

	} );
	add( 'events', () => Fn( () => {

		T.OnObjectUpdate( () => {} );
		T.OnMaterialUpdate( () => {} );
		T.OnFrameUpdate( () => {} );
		T.OnBeforeObjectUpdate( () => {} );
		T.OnAfterObjectUpdate( () => {} );
		T.OnBeforeMaterialUpdate( () => {} );
		T.OnBeforeFrameUpdate( () => {} );
		T.OnBeforeRenderPipeline( () => {} );
		T.OnAfterRenderPipeline( () => {} );
		return fv( 1 );

	} )() );
	const ovFloat = Fn( ( [ a ] ) => a.mul( 2 ), { a: 'float', return: 'float' } ).setLayout( { name: 'ovFloat', type: 'float', inputs: [ { name: 'a', type: 'float' } ] } );
	const ovVec3 = Fn( ( [ a ] ) => a.mul( 3 ) ).setLayout( { name: 'ovVec3', type: 'vec3', inputs: [ { name: 'a', type: 'vec3' } ] } );
	const ovPair = Fn( ( [ a, b ] ) => a.add( b ) ).setLayout( { name: 'ovPair', type: 'vec3', inputs: [ { name: 'a', type: 'vec3' }, { name: 'b', type: 'float' } ] } );
	const overloaded = T.overloadingFn( [ ovFloat, ovVec3, ovPair ] );
	add( 'overloading', () => vec3( overloaded( fv( 1 ) ) ).add( overloaded( v3() ) ).add( overloaded( v3(), fv( 2 ) ) ) );
	add( 'range', () => T.range( 0, 1 ).add( T.range( new Vector3( 0, 1, 2 ), new Vector3( 1, 2, 3 ) ).x ).add( T.range( new Color( 1, 0, 0 ), new Color( 0, 0, 1 ) ).y ) );
	add( 'range_vec_mix', () => T.range( 0, vec3( 1, 2, 3 ) ) );


	// --- More type combinations
	both( 'op_add_int_float_var', () => iv( 1 ).add( fv( 2 ) ) );
	both( 'op_mod_ivec_uvec', () => ivec2( 5, 6 ).toVar().mod( 4 ).add( ivec2( uvec2( 7, 8 ).toVar().mod( uvec2( 3, 3 ) ) ) ) );
	both( 'op_shift_ivec', () => ivec3( 1, 2, 3 ).toVar().shiftLeft( ivec3( 1, 1, 1 ).toVar() ) );
	both( 'op_color_float', () => T.color( 0xff0000 ).toVar().mul( fv( 2 ) ) );
	both( 'op_compare_int_float', () => iv( 1 ).lessThan( fv( 2 ) ) );
	both( 'op_compare_bvec_glsl_eq', () => bvec2( true, false ).toVar().equal( bvec2( true, true ) ) );
	both( 'op_mat_void_statement', () => Fn( () => {

		const m = m3();
		m.mul( fv( 2 ) );
		m.mul( m );
		return m;

	} )() );
	add( 'op_void_operand', () => Fn( () => {

		T.add( T.expression( 'foo()' ), fv( 1 ) );
		return fv( 2 );

	} )() );
	both( 'math_mix_int', () => T.mix( iv( 1 ), iv( 2 ), 0.5 ) );
	both( 'math_dot_ivec2', () => ivec2( 1, 2 ).toVar().dot( ivec2( 3, 4 ) ) );
	both( 'math_cross_vec2', () => v2().cross( vec2( 0, 1 ) ) );
	add( 'math_abs_mat3', () => m3().abs() );
	both( 'math_min_uvec_int', () => uvec2( 1, 2 ).toVar().min( iv( 1 ) ) );
	both( 'math_pow_vec3_int', () => v3().pow( iv( 2 ) ) );
	add( 'cond_uniform_flow_no_else', () => fv( 1 ).greaterThan( 0 ).select( fv( 3 ) ).uniformFlow() );
	add( 'cond_type_before_setup', () => T.transformDirection( T.select( bool( true ).toVar(), m4(), m4() ), v3() ) );
	add( 'loop_float_count', () => Fn( () => {

		const s = fv( 0 );
		Loop( fv( 3 ), uv_( 2 ), ( { i, j } ) => {

			s.addAssign( float( i.add( j ) ) );

		} );
		return s;

	} )() );
	add( 'loop_nested', () => Fn( () => {

		const s = fv( 0 );
		Loop( 2, ( { i } ) => {

			Loop( { start: iv( 0 ), end: i, name: 'k' }, ( { k } ) => {

				s.addAssign( float( k ) );

			} );

		} );
		return s;

	} )() );
	const ptrFn = T.wgslFn( 'fn usePtr( p : pointer, s : float ) -> float { return s; }' );
	add( 'code_pointer_param', () => ptrFn( fv( 1 ), fv( 2 ) ) );
	const getOne = T.wgslFn( 'fn getOne(  ) -> float { return 1.0; }' );
	add( 'code_function_node_value', () => vec2( getOne, getOne() ) );
	add( 'bitcast_vec_conversion', () => T.bitcast( v3(), 'uint' ).add( T.bitcast( ivec2( 1, 2 ).toVar(), 'vec2' ).x ) );
	add( 'bitcount_trailing_int_glsl', () => T.countTrailingZeros( iv( 4 ) ).add( T.countLeadingZeros( uvec2( 1, 2 ).toVar() ).x ), { glsl: true } );
	add( 'max_mip_level', () => T.maxMipLevel( T.uniform( 1 ) ).add( 1 ) );
	both( 'pp_view_position', () => T.getViewPosition( v2(), fv( 0.5 ), m4() ) );
	add( 'pp_view_position_reversed', () => T.getViewPosition( v2(), fv( 0.5 ), m4() ), { glsl: true, reversed: true } );
	add( 'pp_background_depth', () => vec2( T.isBackgroundDepth( fv( 1 ) ), 0 ) );
	add( 'pp_background_depth_reversed', () => vec2( T.isBackgroundDepth( fv( 0 ) ), 0 ), { reversed: true } );
	add( 'pp_screen_position', () => T.getScreenPosition( v3(), m4() ).add( T.getScreenPositionFromClip( v4() ) ) );
	add( 'pp_noise_vogel', () => T.vogelDiskSample( iv( 1 ), iv( 8 ), fv( 0.5 ) ).mul( T.interleavedGradientNoise( v2() ) ) );


	// --- Nodes built on accessors (a mesh, a camera and the node material context)
	const tex = () => {

		const t = new THREE.Texture();
		t.name = 'tex';
		return t;

	};

	const m = { mesh: true };
	add( 'equirect_uv', () => T.equirectUV().add( T.equirectUV( v3() ) ), m );
	add( 'equirect_direction', () => T.equirectDirection().add( T.equirectDirection( v2() ) ), m );
	add( 'matcap_uv', () => T.matcapUV, m );
	add( 'spritesheet_uv', () => T.spritesheetUV( vec2( 4, 2 ).toVar() ).add( T.spritesheetUV( vec2( 4, 2 ), v2(), fv( 3 ) ) ), m );
	add( 'triplanar_one', () => T.triplanarTextures( T.texture( tex() ) ), m );
	add( 'triplanar_three', () => T.triplanarTexture( T.texture( tex() ), T.texture( tex() ), T.texture( tex() ), fv( 2 ), v3(), v3() ), m );
	add( 'billboarding', () => T.billboarding(), { mesh: true, stage: 'vertex' } );
	add( 'billboarding_rotation', () => T.billboarding( { horizontalRotation: true } ), { mesh: true, stage: 'vertex' } );
	add( 'billboarding_position', () => T.billboarding( { position: v3(), horizontal: false, vertical: true } ), { mesh: true, stage: 'vertex' } );
	add( 'checker', () => T.checker().add( T.checker( v2() ) ), m );
	add( 'sample_node', () => T.sample( ( uv ) => uv.mul( 2 ) ), m );
	add( 'replace_default_uv', () => T.replaceDefaultUV( () => vec2( 0.25, 0.75 ), T.texture( tex() ) ), m );
	add( 'fog_factors', () => vec3( T.rangeFogFactor( 1, 10 ), T.densityFogFactor( fv( 0.1 ) ), T.exponentialHeightFogFactor( fv( 0.1 ), fv( 2 ) ) ), m );
	add( 'fog_view_z', () => T.context( T.rangeFogFactor( 1, 10 ), { getViewZ: () => fv( 5 ) } ), m );
	add( 'fog_color', () => T.fog( T.color( 0x888888 ), fv( 0.5 ) ), m );
	add( 'normal_from_depth', () => T.getNormalFromDepth( v2(), T.texture( tex() ), m4() ), m );
	add( 'storage_element', () => T.storageElement( T.storage( new THREE.StorageBufferAttribute( 4, 4 ), 'vec4', 4 ), iv( 1 ) ), { mesh: true, storage: true } );
	add( 'storage_element_no_storage', () => T.storageElement( T.storage( new THREE.StorageBufferAttribute( 4, 4 ), 'vec4', 4 ), iv( 1 ) ), m );

	const cubeTex = () => {

		const t = new THREE.CubeTexture();
		t.name = 'cube';
		return t;

	};

	const equirect = () => {

		const t = new THREE.Texture();
		t.mapping = THREE.EquirectangularReflectionMapping;
		return t;

	};

	add( 'cube_map_cube', () => cubeMapNode( T.cubeTexture( cubeTex() ) ), m );
	add( 'cube_map_equirect_not_ready', () => cubeMapNode( T.texture( equirect() ) ), m );

	add( 'cond_guard_var_reuse', () => Fn( () => {

		const r = fv( 0 );
		const c = bool( true ).toConst();
		let v;
		If( c, () => {

			v = fv( 5 ).toVar();
			r.assign( v );

		} ).Else( () => {

			r.assign( v.add( 1 ) );

		} );
		If( c, () => {

			r.addAssign( v );

		} );
		return r;

	} )() );
	// added by G6 once screenUV and the renderer were available
	add( 'viewport_safe_uv_arg', () => T.viewportSafeUV( T.screenUV.mul( 0.5 ) ), m );
	// no argument: `[ uv = null ]`, so the depth texture samples its default uv()
	add( 'viewport_safe_uv_none', () => T.viewportSafeUV(), m );
	add( 'shape_circle', () => T.shapeCircle(), m );
	add( 'shape_circle_coord', () => T.shapeCircle( T.uv().mul( 2 ) ), m );

	const records = {};
	const geometry = new THREE.BufferGeometry();
	for ( const [ name, itemSize ] of [ [ 'position', 3 ], [ 'normal', 3 ], [ 'uv', 2 ] ] ) {

		geometry.setAttribute( name, new THREE.BufferAttribute( new Float32Array( 24 * itemSize ), itemSize ) );

	}

	// The callbacks a node material puts in the context, as in upstream_g2.mjs.
	const materialContext = ( builder ) => {

		builder.context.setupPositionView = () => T.modelViewMatrix.mul( T.positionLocal ).xyz;
		builder.context.setupModelViewProjection = () => T.cameraProjectionMatrix.mul( T.positionView );
		builder.context.setupNormal = () => T.subBuild( T.normalViewGeometry, 'NORMAL', 'vec3' );

	};

	for ( const [ name, stage, glsl, make, reversed, mesh, storage ] of scenarios ) {

		const renderer = glsl ? glslRenderer : wgslRenderer;
		renderer.reversedDepthBuffer = reversed;
		const object = mesh ? new THREE.Mesh( geometry, new THREE.MeshBasicMaterial() ) : null;
		const builder = new G1Builder( object, renderer, glsl, storage );
		if ( mesh ) {

			builder.camera = new THREE.PerspectiveCamera();
			materialContext( builder );

		}

		builder.setShaderStage( stage );
		const flow = builder.flowStagesNode( make() );
		renderer.reversedDepthBuffer = false;
		const uniforms = [];
		for ( const s of [ 'vertex', 'fragment', 'compute' ] ) {

			for ( const u of builder.uniforms[ s ] ) uniforms.push( `${s}:${u.name}:${u.type}` );

		}

		records[ name ] = { code: flow.code, result: typeof flow.result === 'string' ? flow.result : '', vars: flow.vars ?? '', uniforms, codes: builder.getCodes( stage ) };

	}

	return records;

}
