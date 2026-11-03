// Upstream side of the shader differential test. Each scenario builds a node graph with
// upstream TSL and runs it through a NodeBuilder exactly as the MoonBit scenario of the
// same name in src/nodes/shader_diff_test.mbt does. `record( builder, flow )` is the
// shared output format; keep it identical to `shader_record` in the MoonBit file.
//
//   import { runUpstream } from './upstream.mjs'; const records = await runUpstream( src );

export async function runUpstream( src ) {

	const TSL = await import( src + '/nodes/tsl/TSLCore.js' );
	const T = await import( src + '/Three.TSL.js' );
	const { default: NodeBuilder } = await import( src + '/nodes/core/NodeBuilder.js' );
	const { WebGPURenderer } = await import( src + '/Three.WebGPU.js' );

	// The renderer the MoonBit side mirrors with `Renderer::foundation_stub()`.
	const canvas = { style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } };
	const renderer = new WebGPURenderer( { canvas } );
	renderer._bindings = undefined;

	const { float, int, uint, bool, vec2, vec3, vec4, color, mat3, uniform, property, context, array, Fn, If, convert } = T;

	const scenarios = {
		const_float: () => float( 1.5 ),
		const_small: () => float( 1e-7 ),
		const_negative_zero: () => float( - 0 ),
		vec3_numbers: () => vec3( 1, 2, 3 ),
		vec3_splat: () => vec3( 0.5 ),
		vec3_join_var: () => vec3( float( 1 ).toVar(), 2, 3 ),
		vec4_convert: () => vec4( vec3( 1, 2, 3 ).toVar() ),
		color_hex: () => color( 0xff8800 ),
		mat3_identity: () => mat3(),
		int_of_var: () => int( float( 2.5 ).toVar() ),
		uint_bool: () => vec2( uint( 3 ), bool( 1 ) ),
		swizzle_chain: () => vec4( 1, 2, 3, 4 ).toVar().zyx.xy,
		swizzle_rgba: () => vec4( 1, 2, 3, 4 ).toVar( 'c' ).bgr,
		set_flip: () => vec3( 1, 2, 3 ).toVar().setY( 5 ).flipX(),
		var_named_reuse: () => {

			const v = float( 2 ).toVar( 'v' );
			return vec2( v, v );

		},
		const_named: () => vec3( 1 ).toConst( 'k' ),
		var_shared_expression: () => {

			const s = vec3( float( 1 ).toVar(), 2, 3 );
			return vec2( s.x, s.y );

		},
		uniforms: () => vec2( uniform( 1.0 ), uniform( 2 ).setName( 'scale' ) ),
		uniform_color: () => uniform( color( 0x336699 ) ),
		element_index: () => vec4( 1, 2, 3, 4 ).toVar()[ 1 ],
		element_float: () => vec4( 1, 2, 3, 4 ).toVar().element( 2 ),
		convert_types: () => convert( vec2( 1, 2 ).toVar(), 'vec3' ),
		array_values: () => array( [ float( 1 ), float( 2 ), float( 3 ) ] ),
		context_plain: () => context( vec3( 1, 2, 3 ).toVar(), {} ),
		fn_inline: () => Fn( ( [ a ] ) => {

			const v = a.toVar();
			v.assign( vec3( 1 ) );
			return v;

		} )( vec3( 1, 2, 3 ) ),
		fn_assign_property: () => Fn( () => {

			const p = property( 'vec3', 'Foo' );
			p.assign( vec3( 4, 5, 6 ) );
			return p.yz;

		} )(),
		fn_default_parameter: () => Fn( ( [ a = float( 7 ) ] ) => a.toVar( 'd' ) )(),
	};

	const records = {};
	for ( const [ name, make ] of Object.entries( scenarios ) ) {

		const builder = new NodeBuilder( null, renderer );
		builder.setShaderStage( 'fragment' );
		const flow = builder.flowStagesNode( make() );
		records[ name ] = record( builder, flow );

	}

	return records;

}

// The record compared byte for byte: flow code, result snippet, vars, and the uniforms.
export function record( builder, flow ) {

	const uniforms = [];
	for ( const stage of [ 'vertex', 'fragment', 'compute' ] ) {

		for ( const u of builder.uniforms[ stage ] ) uniforms.push( `${stage}:${u.name}:${u.type}` );

	}

	return { code: flow.code, result: typeof flow.result === 'string' ? flow.result : '', vars: flow.vars ?? '', uniforms };

}
