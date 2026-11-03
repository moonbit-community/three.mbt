// Three BufferGeometry gaps vs upstream: toJSON of transformed parametric geometries,
// copy() between geometry classes, and live (lazily serialized) parameters.
const sum = ( out ) => {

	let cases = 0, match = 0, both = 0, mismatch = 0;
	for ( const m of out.matchAll( /^\w+: cases=(\d+) match=(\d+) \(bothThrow=(\d+)\) mismatch=(\d+)/gm ) ) {

		cases += + m[ 1 ]; match += + m[ 2 ]; both += + m[ 3 ]; mismatch += + m[ 4 ];

	}

	const total = /TOTAL mismatch=(\d+)/.exec( out );
	return total ? `cases=${cases} match=${match} (bothThrow=${both}) mismatch=${mismatch}, TOTAL mismatch=${total[ 1 ]}` : undefined;

};

export default [
	{
		name: 'geometry_gaps',
		area: 'classic',
		order: 41,
		title: 'geometry gaps',
		build: [ '.' ],
		cmd: [ 'node', 'run.mjs' ],
		env: { SKIP_BUILD: '1' },
		summary: sum,
		expect: 'cases=1468 match=1468 (bothThrow=375) mismatch=0, TOTAL mismatch=0',
		timeout: 600,
	},
];
