// The G9 harness setup (diff/core/g9/harness/common.mjs, reused as is) plus a
// deterministic performance.now (1000, +16 per call), which the `time` node, NodeFrame's
// deltaTime and the renderer's info read, so both sides see the same clock.
import { setup as g9setup, flush, TARGETS, SRC } from '../../../core/g9/harness/common.mjs';
export { flush, TARGETS, SRC };
export function setup() {
	const mock = g9setup( {} );
	let t = 1000;
	performance.now = () => ( t += 16 );
	return mock;
}
