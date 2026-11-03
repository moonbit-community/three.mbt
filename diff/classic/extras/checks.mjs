// The TOTAL row of driver.mjs's table: values compared, cases where both sides threw, mismatches.
const total = ( out ) => {

	const m = /^TOTAL\s+(\d+)\s+(\d+)\s+(\d+)/m.exec( out );
	return m ? `${m[ 1 ]} compared, ${m[ 2 ]} both threw, ${m[ 3 ]} mismatches` : undefined;

};

export default [ {
	name: 'extras',
	area: 'classic',
	order: 50,
	title: 'extras (curves, earcut, ShapeUtils, fonts, DataUtils, ...)',
	build: [ '.' ],
	cmd: [ 'node', 'driver.mjs', '1', '1' ],
	summary: total,
	expect: '233633 compared, 5584 both threw, 0 mismatches',
} ];
