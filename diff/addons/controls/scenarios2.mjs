// Scenarios for Fly, FirstPerson, PointerLock, Trackball, Drag, Transform and Arcball.
import { pe, key, wheel, drag } from './scenarios.mjs';

function perspective( A, x, y, z ) {

	const camera = A.perspective( 60, 800 / 600, 0.1, 1000 );
	A.set_name( camera, 'camera' );
	A.set_vec( camera, 'position', x, y, z );
	return camera;

}

function fly( A, S, env ) {

	const camera = perspective( A, 0, 1, 10 );
	const c = A.create( 'fly', camera, env.element );
	S.listen( c, 'fly', [ 'change' ] );
	const D = ( l ) => S.dump( l, c, 'fly', [ camera ] );
	const U = ( d ) => {

		A.call( c, 'fly', 'update', d === undefined ? [] : [ d ] );
		D( 'update ' + d );

	};

	D( 'init' );
	U( 0.1 );
	for ( const code of [ 'KeyW', 'KeyQ', 'ArrowLeft', 'ArrowUp', 'KeyR', 'ShiftLeft', 'KeyD' ] ) {

		S.log( [ 'step', 'keydown ' + code ] );
		env.fire( 'win', 'keydown', key( code ) );
		U( 0.1 );

	}

	env.fire( 'win', 'keydown', key( 'KeyS', { altKey: true } ) );
	U( 0.05 );
	for ( const code of [ 'KeyW', 'KeyQ', 'ShiftRight', 'ArrowUp' ] ) {

		env.fire( 'win', 'keyup', key( code ) );
		U( 0.1 );

	}

	S.log( [ 'step', 'pointer' ] );
	env.fire( 'el', 'pointermove', pe( { x: 200, y: 150 } ) );
	U( 0.1 );
	env.fire( 'el', 'pointerdown', pe( { button: 0 } ) );
	U( 0.1 );
	env.fire( 'el', 'pointerup', pe( { button: 0 } ) );
	env.fire( 'el', 'pointerdown', pe( { button: 2 } ) );
	U( 0.1 );
	env.fire( 'el', 'pointercancel', pe( {} ) );
	U( 0.1 );
	env.fire( 'el', 'contextmenu', {} );
	S.log( [ 'step', 'drag to look' ] );
	A.set( c, 'fly', 'dragToLook', true );
	env.fire( 'el', 'pointermove', pe( { x: 700, y: 500 } ) );
	U( 0.1 );
	env.fire( 'el', 'pointerdown', pe( { button: 0 } ) );
	env.fire( 'el', 'pointermove', pe( { x: 600, y: 100 } ) );
	U( 0.1 );
	env.fire( 'el', 'pointerup', pe( {} ) );
	U( 0.1 );
	env.fire( 'el', 'pointerdown', pe( {} ) );
	env.fire( 'el', 'pointercancel', pe( {} ) );
	U( 0.1 );
	S.log( [ 'step', 'auto forward' ] );
	A.set( c, 'fly', 'autoForward', true );
	A.set( c, 'fly', 'movementSpeed', 3 );
	A.set( c, 'fly', 'rollSpeed', 0.5 );
	env.fire( 'win', 'keydown', key( 'KeyE' ) );
	U( 0.2 );
	env.fire( 'win', 'keydown', key( 'KeyS' ) );
	U( 0.2 );
	env.fire( 'win', 'keyup', key( 'KeyS' ) );
	U( 0.2 );
	U( 0 );
	U();
	S.log( [ 'step', 'disabled' ] );
	A.set( c, 'fly', 'enabled', false );
	env.fire( 'win', 'keydown', key( 'KeyF' ) );
	env.fire( 'el', 'pointerdown', pe( {} ) );
	env.fire( 'el', 'pointermove', pe( { x: 10, y: 10 } ) );
	env.fire( 'el', 'contextmenu', {} );
	U( 0.1 );
	A.set( c, 'fly', 'enabled', true );
	U( 0.1 );
	A.call( c, 'fly', 'dispose', [] );
	D( 'dispose' );

}

function firstPerson( A, S, env ) {

	const camera = perspective( A, 0, 1, 5 );
	A.set_vec( camera, 'rotation', 0.1, 0.4, 0 );
	const c = A.create( 'firstperson', camera, env.element );
	const D = ( l ) => S.dump( l, c, 'firstperson', [ camera ] );
	const U = ( d ) => {

		A.call( c, 'firstperson', 'update', [ d ] );
		D( 'update ' + d );

	};

	D( 'init' );
	A.call( c, 'firstperson', 'lookAt', [ 0, 0, 0 ] );
	D( 'lookAt xyz' );
	A.call( c, 'firstperson', 'lookAt', [ [ 1, 2, - 3 ] ] );
	D( 'lookAt vec' );
	U( 0.1 );
	for ( const code of [ 'KeyW', 'KeyA', 'KeyR', 'ArrowDown', 'ArrowRight', 'KeyF', 'KeyZ' ] ) {

		env.fire( 'win', 'keydown', key( code ) );
		U( 0.1 );

	}

	for ( const code of [ 'ArrowUp', 'KeyA', 'KeyR', 'KeyS', 'KeyD', 'KeyF' ] ) {

		env.fire( 'win', 'keyup', key( code ) );
		U( 0.1 );

	}

	S.log( [ 'step', 'mouse look' ] );
	env.fire( 'el', 'pointerdown', pe( { x: 300, y: 300 } ) );
	U( 0.05 );
	env.fire( 'doc', 'pointermove', pe( { x: 350, y: 250 } ) );
	U( 0.05 );
	env.fire( 'doc', 'pointermove', pe( { x: 200, y: 400 } ) );
	U( 0.05 );
	env.fire( 'doc', 'pointerup', pe( {} ) );
	U( 0.05 );
	env.fire( 'doc', 'pointermove', pe( { x: 100, y: 100 } ) );
	U( 0.05 );
	env.fire( 'el', 'pointerdown', pe( { button: 2 } ) );
	U( 0.05 );
	env.fire( 'doc', 'pointerup', pe( { button: 2 } ) );
	S.log( [ 'step', 'key blocks pointer forward' ] );
	env.fire( 'win', 'keydown', key( 'KeyW' ) );
	env.fire( 'el', 'pointerdown', pe( { button: 0 } ) );
	U( 0.05 );
	env.fire( 'doc', 'pointerup', pe( { button: 0 } ) );
	env.fire( 'win', 'keyup', key( 'KeyW' ) );
	S.log( [ 'step', 'touch' ] );
	env.fire( 'el', 'pointerdown', pe( { pointerType: 'touch', pointerId: 5, x: 100, y: 100 } ) );
	U( 0.05 );
	env.fire( 'el', 'pointerdown', pe( { pointerType: 'touch', pointerId: 6, x: 200, y: 100 } ) );
	U( 0.05 );
	env.fire( 'doc', 'pointermove', pe( { pointerType: 'touch', pointerId: 6, x: 240, y: 130 } ) );
	U( 0.05 );
	env.fire( 'doc', 'pointercancel', pe( { pointerType: 'touch', pointerId: 6 } ) );
	U( 0.05 );
	env.fire( 'doc', 'pointerup', pe( { pointerType: 'touch', pointerId: 5 } ) );
	U( 0.05 );
	S.log( [ 'step', 'options' ] );
	A.set( c, 'firstperson', 'heightSpeed', true );
	A.set( c, 'firstperson', 'heightCoef', 2 );
	A.set( c, 'firstperson', 'heightMin', 0.5 );
	A.set( c, 'firstperson', 'heightMax', 3 );
	A.set( c, 'firstperson', 'autoForward', true );
	U( 0.2 );
	A.set( c, 'firstperson', 'constrainVertical', true );
	A.set( c, 'firstperson', 'verticalMin', 1 );
	A.set( c, 'firstperson', 'verticalMax', 2 );
	A.set( c, 'firstperson', 'lookVertical', false );
	env.fire( 'el', 'pointerdown', pe( { x: 300, y: 300 } ) );
	env.fire( 'doc', 'pointermove', pe( { x: 360, y: 200 } ) );
	U( 0.2 );
	A.set( c, 'firstperson', 'lookVertical', true );
	A.set( c, 'firstperson', 'movementSpeed', 4 );
	A.set( c, 'firstperson', 'lookSpeed', 0.02 );
	A.set( c, 'firstperson', 'dampingFactor', 0.5 );
	U( 0.2 );
	env.fire( 'doc', 'pointerup', pe( {} ) );
	U( 0.2 );
	env.fire( 'el', 'contextmenu', {} );
	A.set( c, 'firstperson', 'constrainVertical', false );
	env.fire( 'el', 'pointerdown', pe( { x: 300, y: 300 } ) );
	env.fire( 'doc', 'pointermove', pe( { x: 300, y: - 3000 } ) );
	for ( let i = 0; i < 4; i ++ ) U( 1 );
	env.fire( 'doc', 'pointermove', pe( { x: 300, y: 5000 } ) );
	for ( let i = 0; i < 6; i ++ ) U( 1 );
	env.fire( 'doc', 'pointerup', pe( {} ) );
	A.call( c, 'firstperson', 'handleResize', [] );
	A.set( c, 'firstperson', 'enabled', false );
	U( 0.2 );
	env.fire( 'el', 'contextmenu', {} );
	A.call( c, 'firstperson', 'dispose', [] );
	D( 'dispose' );

}

function pointerLock( A, S, env ) {

	const camera = perspective( A, 0, 1.6, 4 );
	const c = A.create( 'pointerlock', camera, env.element );
	S.listen( c, 'pointerlock', [ 'change', 'lock', 'unlock' ] );
	const D = ( l ) => S.dump( l, c, 'pointerlock', [ camera ] );
	const M = ( mx, my ) => {

		env.fire( 'doc', 'mousemove', { movementX: mx, movementY: my } );
		D( 'move ' + mx + ',' + my );

	};

	D( 'init' );
	M( 10, 5 );
	A.call( c, 'pointerlock', 'lock', [] );
	A.call( c, 'pointerlock', 'lock', [ true ] );
	env.document.pointerLockElement = env.element;
	env.fire( 'doc', 'pointerlockchange', {} );
	D( 'locked' );
	M( 10, 5 );
	M( - 300, 900 );
	M( 50, - 2000 );
	A.set( c, 'pointerlock', 'pointerSpeed', 2.5 );
	A.set( c, 'pointerlock', 'minPolarAngle', 0.5 );
	A.set( c, 'pointerlock', 'maxPolarAngle', 2.5 );
	M( 40, 300 );
	M( - 40, - 900 );
	A.call( c, 'pointerlock', 'moveForward', [ 2 ] );
	A.call( c, 'pointerlock', 'moveRight', [ - 1.5 ] );
	D( 'moved' );
	A.update_matrix_world( camera );
	A.call( c, 'pointerlock', 'moveForward', [ 2 ] );
	A.call( c, 'pointerlock', 'moveRight', [ - 1.5 ] );
	S.log( [ 'direction', A.call( c, 'pointerlock', 'getDirection', [] ) ] );
	D( 'moved 2' );
	env.fire( 'doc', 'pointerlockerror', {} );
	A.call( c, 'pointerlock', 'unlock', [] );
	env.document.pointerLockElement = null;
	env.fire( 'doc', 'pointerlockchange', {} );
	M( 10, 10 );
	A.set( c, 'pointerlock', 'enabled', false );
	A.call( c, 'pointerlock', 'moveForward', [ 2 ] );
	D( 'disabled' );
	A.call( c, 'pointerlock', 'dispose', [] );
	D( 'dispose' );

}

function trackball( ortho ) {

	return ( A, S, env ) => {

		let camera;
		if ( ortho ) {

			camera = A.ortho( - 4, 4, 3, - 3, 0.1, 100 );
			A.set_name( camera, 'camera' );
			A.set_vec( camera, 'position', 2, 3, 9 );

		} else camera = perspective( A, 3, 4, 10 );

		const c = A.create( 'trackball', camera, env.element );
		S.listen( c, 'trackball', [ 'change', 'start', 'end' ] );
		const D = ( l ) => S.dump( l, c, 'trackball', [ camera ] );
		const U = ( l ) => {

			A.call( c, 'trackball', 'update', [] );
			D( l );

		};

		D( 'init' );
		drag( S, env, 'rotate', 'el', 'doc', {}, [ [ 300, 300 ], [ 340, 280 ], [ 400, 250 ] ], U );
		for ( let i = 0; i < 4; i ++ ) U( 'coast ' + i );
		drag( S, env, 'zoom', 'el', 'doc', { button: 1 }, [ [ 300, 300 ], [ 300, 340 ], [ 300, 200 ] ], U );
		for ( let i = 0; i < 3; i ++ ) U( 'zoom coast ' + i );
		drag( S, env, 'pan', 'el', 'doc', { button: 2 }, [ [ 300, 300 ], [ 330, 350 ] ], U );
		for ( let i = 0; i < 3; i ++ ) U( 'pan coast ' + i );
		drag( S, env, 'button 3', 'el', 'doc', { button: 3 }, [ [ 300, 300 ], [ 330, 350 ] ], U );
		A.set( c, 'trackball', 'staticMoving', true );
		drag( S, env, 'static rotate', 'el', 'doc', {}, [ [ 300, 300 ], [ 340, 330 ] ], U );
		drag( S, env, 'static zoom', 'el', 'doc', { button: 1 }, [ [ 300, 300 ], [ 300, 360 ] ], U );
		drag( S, env, 'static pan', 'el', 'doc', { button: 2 }, [ [ 300, 300 ], [ 360, 330 ] ], U );
		A.set( c, 'trackball', 'staticMoving', false );
		for ( const [ mode, dy ] of [ [ 0, 120 ], [ 1, - 3 ], [ 2, 1 ] ] ) {

			env.fire( 'el', 'wheel', wheel( { deltaMode: mode, deltaY: dy } ) );
			U( 'wheel ' + mode );

		}

		S.log( [ 'step', 'keys' ] );
		env.fire( 'win', 'keydown', key( 'KeyS' ) );
		env.fire( 'win', 'keydown', key( 'KeyA' ) );
		D( 'key S' );
		drag( S, env, 'key zoom drag', 'el', 'doc', {}, [ [ 300, 300 ], [ 300, 260 ] ], U );
		env.fire( 'win', 'keyup', key( 'KeyS' ) );
		env.fire( 'win', 'keydown', key( 'KeyD' ) );
		drag( S, env, 'key pan drag', 'el', 'doc', {}, [ [ 300, 300 ], [ 340, 260 ] ], U );
		env.fire( 'win', 'keyup', key( 'KeyD' ) );
		env.fire( 'win', 'keydown', key( 'KeyX' ) );
		env.fire( 'win', 'keyup', key( 'KeyX' ) );
		D( 'keys done' );
		S.log( [ 'step', 'touch' ] );
		A.set( c, 'trackball', 'multiTouchRoll', true );
		const t = ( type, target, id, x, y ) => {

			env.fire( target, type, pe( { pointerType: 'touch', pointerId: id, x, y } ) );
			U( type + ' ' + id );

		};

		t( 'pointerdown', 'el', 7, 200, 200 );
		t( 'pointermove', 'doc', 7, 230, 210 );
		t( 'pointerdown', 'el', 8, 400, 300 );
		t( 'pointermove', 'doc', 8, 420, 330 );
		t( 'pointermove', 'doc', 7, 210, 190 );
		t( 'pointermove', 'doc', 8, 380, 350 );
		t( 'pointerdown', 'el', 9, 600, 100 );
		t( 'pointermove', 'doc', 9, 610, 120 );
		t( 'pointerup', 'doc', 9, 610, 120 );
		t( 'pointerup', 'doc', 8, 380, 350 );
		t( 'pointermove', 'doc', 7, 250, 230 );
		t( 'pointerup', 'doc', 7, 250, 230 );
		for ( let i = 0; i < 3; i ++ ) U( 'roll coast ' + i );
		t( 'pointerdown', 'el', 13, 400, 300 );
		t( 'pointerdown', 'el', 14, 200, 299 );
		t( 'pointermove', 'doc', 14, 200, 301 );
		t( 'pointermove', 'doc', 14, 200, 297 );
		t( 'pointerup', 'doc', 14, 200, 297 );
		t( 'pointerup', 'doc', 13, 400, 300 );
		t( 'pointerdown', 'el', 11, 200, 200 );
		t( 'pointerdown', 'el', 12, 300, 200 );
		t( 'pointercancel', 'el', 12, 300, 200 );
		t( 'pointerup', 'doc', 11, 300, 200 );
		S.log( [ 'step', 'limits' ] );
		A.set( c, 'trackball', 'minDistance', 8 );
		A.set( c, 'trackball', 'maxDistance', 9 );
		drag( S, env, 'limit zoom', 'el', 'doc', { button: 1 }, [ [ 300, 300 ], [ 300, 100 ] ], U );
		drag( S, env, 'limit zoom 2', 'el', 'doc', { button: 1 }, [ [ 300, 300 ], [ 300, 600 ] ], U );
		A.set( c, 'trackball', 'minZoom', 0.8 );
		A.set( c, 'trackball', 'maxZoom', 1.2 );
		env.fire( 'el', 'wheel', wheel( { deltaY: - 4000 } ) );
		U( 'zoom limit wheel' );
		A.set( c, 'trackball', 'noRotate', true );
		A.set( c, 'trackball', 'noPan', true );
		drag( S, env, 'no rotate', 'el', 'doc', {}, [ [ 300, 300 ], [ 340, 330 ] ], U );
		A.set( c, 'trackball', 'noZoom', true );
		env.fire( 'el', 'wheel', wheel() );
		U( 'no zoom wheel' );
		A.set( c, 'trackball', 'noRotate', false );
		A.set( c, 'trackball', 'noPan', false );
		A.set( c, 'trackball', 'noZoom', false );
		A.set( c, 'trackball', 'target', [ 1, 0, - 1 ] );
		U( 'target' );
		A.call( c, 'trackball', 'reset', [] );
		D( 'reset' );
		A.set( c, 'trackball', 'enabled', false );
		drag( S, env, 'disabled', 'el', 'doc', {}, [ [ 300, 300 ], [ 340, 330 ] ], U );
		env.fire( 'win', 'keydown', key( 'KeyA' ) );
		env.fire( 'win', 'keyup', key( 'KeyA' ) );
		env.fire( 'el', 'contextmenu', {} );
		env.fire( 'el', 'wheel', wheel() );
		A.set( c, 'trackball', 'enabled', true );
		env.fire( 'el', 'contextmenu', {} );
		A.call( c, 'trackball', 'handleResize', [] );
		A.call( c, 'trackball', 'dispose', [] );
		D( 'dispose' );

	};

}

function dragScene( A ) {

	const scene = A.scene();
	A.set_name( scene, 'scene' );
	const group = A.group();
	A.set_name( group, 'group' );
	A.set_vec( group, 'position', 0.5, 0, 0 );
	A.set_vec( group, 'rotation', 0, 0.3, 0 );
	A.add_child( scene, group );
	const a = A.box_mesh( 1, 1, 1 );
	A.set_name( a, 'a' );
	A.set_vec( a, 'position', - 1.5, 0, 0 );
	A.add_child( group, a );
	const b = A.box_mesh( 1, 2, 1 );
	A.set_name( b, 'b' );
	A.set_vec( b, 'position', 1.5, 0.5, 0 );
	A.add_child( group, b );
	const d = A.box_mesh( 0.5, 0.5, 0.5 );
	A.set_name( d, 'd' );
	A.set_vec( d, 'position', 0, - 2, 1 );
	A.add_child( scene, d );
	return { scene, group, a, b, d };

}

function dragControls( A, S, env ) {

	const { scene, group, a, b, d } = dragScene( A );
	const camera = perspective( A, 0, 0, 10 );
	A.update_matrix_world( camera );
	A.update_matrix_world( scene );
	const c = A.create( 'drag', camera, env.element, { objects: [ group, d ] } );
	S.listen( c, 'drag', [ 'dragstart', 'drag', 'dragend', 'hoveron', 'hoveroff' ] );
	const D = ( l ) => {

		A.update_matrix_world( scene );
		S.dump( l, c, 'drag', [ a, b, d, group ] );

	};

	const at = ( type, x, y, o = {} ) => {

		S.log( [ 'step', type + ' ' + x + ',' + y ] );
		env.fire( 'el', type, pe( { x, y, ...o } ) );
		D( type );

	};

	D( 'init' );
	// screen centre is ( 410, 320 ); a is left of centre, b right of it, d below
	for ( const [ x, y ] of [ [ 50, 50 ], [ 330, 320 ], [ 335, 322 ], [ 520, 290 ], [ 410, 435 ], [ 50, 50 ], [ 520, 290 ] ] ) at( 'pointermove', x, y, { button: - 1 } );
	at( 'pointerdown', 520, 290 );
	at( 'pointermove', 560, 300, { button: - 1 } );
	at( 'pointermove', 600, 200, { button: - 1 } );
	at( 'pointerup', 600, 200 );
	at( 'pointerdown', 330, 320, { button: 2 } );
	at( 'pointermove', 360, 300, { button: - 1 } );
	at( 'pointermove', 300, 360, { button: - 1 } );
	at( 'pointerleave', 300, 360 );
	at( 'pointerdown', 410, 435, { button: 1 } );
	at( 'pointermove', 420, 445, { button: - 1 } );
	at( 'pointerup', 420, 445 );
	at( 'pointerdown', 410, 435, { button: 4 } );
	at( 'pointerup', 410, 435 );
	at( 'pointermove', 410, 435, { button: - 1, pointerType: 'pen' } );
	at( 'pointerdown', 410, 435, { pointerType: 'touch', pointerId: 3 } );
	at( 'pointermove', 380, 410, { pointerType: 'touch', pointerId: 3 } );
	at( 'pointerup', 380, 410, { pointerType: 'touch', pointerId: 3 } );
	at( 'pointermove', 700, 600, { pointerType: 'touch', pointerId: 3 } );
	S.log( [ 'step', 'transform group' ] );
	A.set( c, 'drag', 'transformGroup', true );
	at( 'pointerdown', 330, 320 );
	at( 'pointermove', 360, 300, { button: - 1 } );
	at( 'pointerup', 360, 300 );
	at( 'pointerdown', 330, 320, { button: 2 } );
	at( 'pointermove', 360, 280, { button: - 1 } );
	at( 'pointerup', 360, 280 );
	A.set( c, 'drag', 'transformGroup', false );
	A.set( c, 'drag', 'recursive', false );
	at( 'pointermove', 520, 290, { button: - 1 } );
	at( 'pointerdown', 520, 290 );
	A.set( c, 'drag', 'recursive', true );
	A.set( c, 'drag', 'rotateSpeed', 3 );
	A.set( c, 'drag', 'mouseButtons', { LEFT: 1, MIDDLE: 2, RIGHT: 0 } );
	at( 'pointerdown', 410, 435 );
	at( 'pointermove', 440, 410, { button: - 1 } );
	at( 'pointerup', 440, 410 );
	A.set( c, 'drag', 'touches', { ONE: 0 } );
	at( 'pointerdown', 410, 435, { pointerType: 'touch', pointerId: 4 } );
	at( 'pointermove', 440, 410, { pointerType: 'touch', pointerId: 4 } );
	at( 'pointerup', 440, 410, { pointerType: 'touch', pointerId: 4 } );
	env.fire( 'el', 'contextmenu', {} );
	A.set( c, 'drag', 'enabled', false );
	at( 'pointermove', 520, 290, { button: - 1 } );
	at( 'pointerdown', 520, 290 );
	env.fire( 'el', 'contextmenu', {} );
	at( 'pointerup', 520, 290 );
	A.set( c, 'drag', 'enabled', true );
	at( 'pointermove', 50, 50, { button: - 1 } );
	A.call( c, 'drag', 'dispose', [] );
	D( 'dispose' );

}

const TC_EVENTS = [ 'change', 'mouseDown', 'mouseUp', 'objectChange', 'camera-changed', 'object-changed', 'enabled-changed', 'axis-changed',
	'mode-changed', 'translationSnap-changed', 'rotationSnap-changed', 'scaleSnap-changed', 'space-changed', 'size-changed',
	'dragging-changed', 'showX-changed', 'showY-changed', 'showZ-changed', 'showXY-changed', 'showYZ-changed', 'showXZ-changed',
	'showXYZE-changed', 'showE-changed', 'minX-changed', 'maxX-changed', 'minY-changed', 'maxY-changed', 'minZ-changed', 'maxZ-changed',
	'rotationAngle-changed', 'worldPosition-changed', 'eye-changed' ];

function transformControls( variant ) {

	return ( A, S, env ) => {

		const scene = A.scene();
		A.set_name( scene, 'scene' );
		const parent = A.group();
		A.set_name( parent, 'parent' );
		A.set_vec( parent, 'position', 0.3, - 0.2, 0.1 );
		A.set_vec( parent, 'rotation', 0.2, 0.5, - 0.1 );
		A.set_vec( parent, 'scale', 1.5, 1, 0.8 );
		A.add_child( scene, parent );
		const box = A.box_mesh( 1, 1, 1 );
		A.set_name( box, 'box' );
		A.set_vec( box, 'position', 0.2, 0.1, - 0.3 );
		A.set_vec( box, 'rotation', 0.3, - 0.2, 0.4 );
		A.add_child( parent, box );
		let camera;
		if ( variant === 'ortho' ) {

			camera = A.ortho( - 4, 4, 3, - 3, 0.1, 100 );
			A.set_name( camera, 'camera' );
			A.set_vec( camera, 'position', 3, 4, 6 );

		} else if ( variant === 'aligned' ) camera = perspective( A, 6, 0.4, 0.25 );
		else camera = perspective( A, 3, 4, 6 );

		A.look_at( camera, 0, 0, 0 );
		const c = A.create( 'transform', camera, env.element );
		S.listen( c, 'transform', TC_EVENTS );
		const helper = A.call( c, 'transform', 'getHelper', [] );
		A.add_child( scene, helper );
		const render = () => A.update_matrix_world( scene );
		const D = ( l, full ) => {

			S.dump( l, c, full ? 'transform_full' : 'transform', [ box ] );

		};

		render();
		D( 'init', true );
		A.call( c, 'transform', 'attach', [ box ] );
		render();
		D( 'attached', true );
		const probe = () => {

			// hover a grid of points and remember the first one per axis
			const found = {};
			for ( let y = 120; y <= 540; y += 14 ) for ( let x = 210; x <= 620; x += 14 ) {

				env.fire( 'el', 'pointermove', pe( { x, y, button: - 1 } ) );
				const axis = A.get( c, 'transform', 'axis' );
				if ( axis !== null && found[ axis ] === undefined ) found[ axis ] = [ x, y ];

			}

			S.log( [ 'probe', JSON.stringify( found ) ] );
			return found;

		};

		const dragFrom = ( label, [ x, y ], moves ) => {

			render();
			env.fire( 'el', 'pointermove', pe( { x, y, button: - 1 } ) );
			S.log( [ 'step', label + ' down' ] );
			env.fire( 'el', 'pointerdown', pe( { x, y } ) );
			render();
			D( label + ' down' );
			for ( const [ dx, dy ] of moves ) {

				env.fire( 'el', 'pointermove', pe( { x: x + dx, y: y + dy, button: - 1 } ) );
				render();
				D( label + ' move' );

			}

			env.fire( 'el', 'pointerup', pe( { x: x + moves[ moves.length - 1 ][ 0 ], y: y + moves[ moves.length - 1 ][ 1 ] } ) );
			render();
			D( label + ' up', true );
			A.set_vec( box, 'position', 0.2, 0.1, - 0.3 );
			A.set_vec( box, 'rotation', 0.3, - 0.2, 0.4 );
			A.set_vec( box, 'scale', 1, 1, 1 );
			render();

		};

		const moves = [ [ 25, 8 ], [ 60, - 30 ], [ - 45, 35 ] ];
		const configs = variant === 'snap' ?
			[ [ 'translate', 'world' ], [ 'translate', 'local' ], [ 'rotate', 'world' ], [ 'rotate', 'local' ], [ 'scale', 'local' ] ] :
			[ [ 'translate', 'world' ], [ 'translate', 'local' ], [ 'rotate', 'world' ], [ 'rotate', 'local' ], [ 'scale', 'world' ], [ 'scale', 'local' ] ];
		if ( variant === 'snap' ) {

			A.call( c, 'transform', 'setTranslationSnap', [ 0.25 ] );
			A.call( c, 'transform', 'setRotationSnap', [ Math.PI / 12 ] );
			A.call( c, 'transform', 'setScaleSnap', [ 0.2 ] );

		}

		for ( const [ mode, space ] of configs ) {

			A.call( c, 'transform', 'setMode', [ mode ] );
			A.call( c, 'transform', 'setSpace', [ space ] );
			render();
			D( mode + ' ' + space, true );
			const found = probe();
			render();
			D( 'probed', true );
			for ( const axis of Object.keys( found ).sort() ) dragFrom( mode + ' ' + space + ' ' + axis, found[ axis ], moves );

		}

		if ( variant === 'snap' ) {

			// shrink to (almost) zero so the snapped scale falls back to scaleSnap
			A.call( c, 'transform', 'setMode', [ 'scale' ] );
			render();
			const f = probe();
			for ( const axis of [ 'X', 'Y', 'Z', 'XYZ' ] ) {

				if ( f[ axis ] === undefined || f.XYZ === undefined ) continue;
				const [ cx, cy ] = f.XYZ, [ ax, ay ] = f[ axis ];
				const tx = cx - ax, ty = cy - ay;
				dragFrom( 'shrink ' + axis, f[ axis ], [ [ tx * 0.5, ty * 0.5 ], [ tx * 0.97, ty * 0.97 ], [ tx * 1.02, ty * 1.02 ] ] );

			}

		}

		if ( variant === 'snap' || variant === 'aligned' ) return;
		S.log( [ 'step', 'reset during drag' ] );
		A.call( c, 'transform', 'setMode', [ 'translate' ] );
		render();
		const found = probe();
		const start = found.X || found.Y || found.Z;
		env.fire( 'el', 'pointermove', pe( { x: start[ 0 ], y: start[ 1 ], button: - 1 } ) );
		env.fire( 'el', 'pointerdown', pe( { x: start[ 0 ], y: start[ 1 ] } ) );
		env.fire( 'el', 'pointermove', pe( { x: start[ 0 ] + 40, y: start[ 1 ] + 10, button: - 1 } ) );
		A.call( c, 'transform', 'reset', [] );
		D( 'reset' );
		env.fire( 'el', 'pointermove', pe( { x: start[ 0 ] + 50, y: start[ 1 ] + 20, button: - 1 } ) );
		env.fire( 'el', 'pointerup', pe( { x: start[ 0 ] + 50, y: start[ 1 ] + 20, button: 2 } ) );
		D( 'up wrong button' );
		env.fire( 'el', 'pointerup', pe( { x: start[ 0 ] + 50, y: start[ 1 ] + 20 } ) );
		render();
		D( 'up' );
		S.log( [ 'step', 'options' ] );
		A.set( c, 'transform', 'showX', false );
		A.set( c, 'transform', 'showXY', false );
		A.set( c, 'transform', 'showE', false );
		A.call( c, 'transform', 'setSize', [ 1.7 ] );
		A.call( c, 'transform', 'setColors', [ 0x112233, 0x445566, 0x778899, 0xaabbcc ] );
		A.set( c, 'transform', 'minX', - 0.1 );
		A.set( c, 'transform', 'maxZ', 0.05 );
		A.set( c, 'transform', 'mode', 'translate' );
		render();
		D( 'options', true );
		const f2 = probe();
		for ( const axis of Object.keys( f2 ).sort() ) dragFrom( 'clamped ' + axis, f2[ axis ], moves );
		A.set( c, 'transform', 'mode', 'rotate' );
		render();
		const f3 = probe();
		for ( const axis of Object.keys( f3 ).sort() ) dragFrom( 'rotate hidden ' + axis, f3[ axis ], moves );
		S.log( [ 'step', 'viewport' ] );
		A.set( c, 'transform', 'viewport', { x: 100, y: 50, z: 500, w: 400 } );
		render();
		probe();
		A.set( c, 'transform', 'viewport', null );
		S.log( [ 'step', 'pointer lock' ] );
		env.document.pointerLockElement = env.element;
		env.fire( 'el', 'pointermove', pe( { x: 100, y: 100, button: - 1 } ) );
		env.fire( 'el', 'pointerdown', pe( { x: 100, y: 100 } ) );
		env.fire( 'el', 'pointerup', pe( { x: 100, y: 100 } ) );
		D( 'locked' );
		env.document.pointerLockElement = null;
		S.log( [ 'step', 'direct api' ] );
		A.call( c, 'transform', 'pointerHover', [ { x: 0.01, y: 0.02, button: - 1 } ] );
		A.call( c, 'transform', 'pointerDown', [ { x: 0.01, y: 0.02, button: 0 } ] );
		A.call( c, 'transform', 'pointerMove', [ { x: 0.1, y: 0.05, button: - 1 } ] );
		A.call( c, 'transform', 'pointerMove', [ null ] );
		A.call( c, 'transform', 'pointerUp', [ null ] );
		D( 'direct' );
		S.log( [ 'getMode', A.call( c, 'transform', 'getMode', [] ) ] );
		A.set( c, 'transform', 'enabled', false );
		env.fire( 'el', 'pointermove', pe( { x: 400, y: 300, button: - 1 } ) );
		env.fire( 'el', 'pointerdown', pe( { x: 400, y: 300 } ) );
		env.fire( 'el', 'pointerup', pe( { x: 400, y: 300 } ) );
		A.call( c, 'transform', 'reset', [] );
		A.set( c, 'transform', 'enabled', true );
		render();
		D( 'enabled again', true );
		A.call( c, 'transform', 'detach', [] );
		render();
		D( 'detached', true );
		env.fire( 'el', 'pointermove', pe( { x: 400, y: 300, button: - 1 } ) );
		env.fire( 'el', 'pointerdown', pe( { x: 400, y: 300 } ) );
		A.call( c, 'transform', 'dispose', [] );
		D( 'dispose' );

	};

}

function arcballScene( A ) {

	const scene = A.scene();
	A.set_name( scene, 'scene' );
	const box = A.box_mesh( 2, 2, 2 );
	A.set_name( box, 'box' );
	A.set_vec( box, 'position', 0.5, 0.2, 0 );
	A.add_child( scene, box );
	A.update_matrix_world( scene );
	return scene;

}

function arcball( variant ) {

	return ( A, S, env ) => {

		const scene = arcballScene( A );
		let camera;
		if ( variant === 'ortho' ) {

			camera = A.ortho( - 4, 4, 3, - 3, 0.1, 100 );
			A.set_name( camera, 'camera' );
			A.set_vec( camera, 'position', 1, 2, 9 );

		} else camera = perspective( A, 1, 2, 9 );

		const c = A.create( 'arcball', camera, env.element, { scene } );
		S.listen( c, 'arcball', [ 'change', 'start', 'end' ] );
		const D = ( l ) => {

			A.update_matrix_world( scene );
			A.update_matrix_world( camera );
			S.dump( l, c, 'arcball', [ camera ] );

		};

		const step = ( ms ) => {

			env.now += ms;

		};

		const ev = ( target, type, o ) => {

			S.log( [ 'step', type + ' ' + JSON.stringify( o ) ] );
			env.fire( target, type, pe( o ) );
			D( type );

		};

		const frames = ( n, dt = 16 ) => {

			for ( let i = 0; i < n; i ++ ) {

				step( dt );
				env.frame( env.now );
				D( 'frame ' + i );

			}

		};

		D( 'init' );
		env.fire( 'el', 'contextmenu', {} );
		S.log( [ 'step', 'rotate with animation' ] );
		ev( 'el', 'pointerdown', { x: 300, y: 300 } );
		for ( const [ x, y ] of [ [ 320, 290 ], [ 350, 270 ], [ 390, 260 ] ] ) {

			step( 16 );
			ev( 'win', 'pointermove', { x, y, button: - 1 } );

		}

		step( 16 );
		ev( 'win', 'pointerup', { x: 390, y: 260 } );
		frames( 8, 40 );
		S.log( [ 'step', 'interrupt animation with pan' ] );
		ev( 'el', 'pointerdown', { x: 300, y: 300 } );
		step( 16 );
		ev( 'win', 'pointermove', { x: 330, y: 320, button: - 1 } );
		step( 200 );
		ev( 'win', 'pointerup', { x: 330, y: 320 } );
		frames( 2 );
		S.log( [ 'step', 'pan with grid' ] );
		A.set( c, 'arcball', 'enableGrid', true );
		ev( 'el', 'pointerdown', { x: 400, y: 300, button: 2 } );
		step( 16 );
		ev( 'win', 'pointermove', { x: 430, y: 330, button: - 1 } );
		ev( 'win', 'pointermove', { x: 470, y: 310, button: - 1, shiftKey: true } );
		ev( 'win', 'pointermove', { x: 480, y: 300, button: - 1, ctrlKey: true } );
		ev( 'win', 'pointerup', { x: 480, y: 300, button: 2 } );
		S.log( [ 'step', 'ctrl pan' ] );
		ev( 'el', 'pointerdown', { x: 400, y: 300, ctrlKey: true } );
		ev( 'win', 'pointermove', { x: 380, y: 280, button: - 1, ctrlKey: true } );
		ev( 'win', 'pointermove', { x: 360, y: 270, button: - 1 } );
		step( 300 );
		ev( 'win', 'pointerup', { x: 360, y: 270 } );
		frames( 1 );
		S.log( [ 'step', 'zoom drag' ] );
		ev( 'el', 'pointerdown', { x: 400, y: 300, button: 1 } );
		ev( 'win', 'pointermove', { x: 400, y: 340, button: - 1 } );
		ev( 'win', 'pointermove', { x: 400, y: 250, button: - 1 } );
		ev( 'win', 'pointermove', { x: 400, y: 250, button: - 1, shiftKey: true } );
		ev( 'win', 'pointermove', { x: 400, y: 200, button: - 1, shiftKey: true } );
		ev( 'win', 'pointerup', { x: 400, y: 200, button: 1 } );
		S.log( [ 'step', 'fov drag' ] );
		ev( 'el', 'pointerdown', { x: 400, y: 300, button: 1, shiftKey: true } );
		ev( 'win', 'pointermove', { x: 400, y: 360, button: - 1, shiftKey: true } );
		ev( 'win', 'pointermove', { x: 400, y: 150, button: - 1, shiftKey: true } );
		ev( 'win', 'pointerup', { x: 400, y: 150, button: 1 } );
		S.log( [ 'step', 'wheel' ] );
		for ( const o of [ { deltaY: 125 }, { deltaY: - 300 }, { deltaY: 0 }, { deltaY: 125, shiftKey: true }, { deltaY: - 250, shiftKey: true },
			{ deltaY: 0, deltaX: 125, shiftKey: true }, { deltaY: 125, ctrlKey: true } ] ) {

			S.log( [ 'step', 'wheel ' + JSON.stringify( o ) ] );
			env.fire( 'el', 'wheel', wheel( o ) );
			D( 'wheel' );

		}

		A.set( c, 'arcball', 'cursorZoom', true );
		env.fire( 'el', 'wheel', wheel( { clientX: 600, clientY: 100, deltaY: - 125 } ) );
		D( 'cursor zoom' );
		env.fire( 'el', 'wheel', wheel( { clientX: 100, clientY: 500, deltaY: 250 } ) );
		D( 'cursor zoom 2' );
		A.set( c, 'arcball', 'enableGrid', false );
		S.log( [ 'step', 'double tap (animated focus)' ] );
		step( 1000 );
		ev( 'el', 'pointerdown', { x: 420, y: 330 } );
		step( 50 );
		ev( 'win', 'pointerup', { x: 420, y: 330 } );
		step( 100 );
		ev( 'el', 'pointerdown', { x: 422, y: 331 } );
		step( 50 );
		ev( 'win', 'pointerup', { x: 422, y: 331 } );
		frames( 6, 120 );
		S.log( [ 'step', 'double tap (no animation)' ] );
		A.set( c, 'arcball', 'enableAnimations', false );
		step( 1000 );
		ev( 'el', 'pointerdown', { x: 400, y: 320 } );
		step( 50 );
		ev( 'win', 'pointerup', { x: 400, y: 320 } );
		step( 100 );
		ev( 'el', 'pointerdown', { x: 401, y: 321 } );
		step( 50 );
		ev( 'win', 'pointerup', { x: 401, y: 321 } );
		S.log( [ 'step', 'slow clicks' ] );
		step( 1000 );
		ev( 'el', 'pointerdown', { x: 400, y: 320 } );
		step( 400 );
		ev( 'win', 'pointerup', { x: 400, y: 320 } );
		ev( 'el', 'pointerdown', { x: 400, y: 320 } );
		step( 50 );
		ev( 'win', 'pointerup', { x: 400, y: 320 } );
		step( 500 );
		ev( 'el', 'pointerdown', { x: 400, y: 320 } );
		step( 50 );
		ev( 'win', 'pointerup', { x: 400, y: 320 } );
		A.set( c, 'arcball', 'enableAnimations', true );
		S.log( [ 'step', 'touch' ] );
		const t = ( target, type, id, x, y ) => {

			step( 16 );
			ev( target, type, { pointerType: 'touch', pointerId: id, x, y, isPrimary: id === 20, button: type === 'pointermove' ? - 1 : 0 } );

		};

		t( 'el', 'pointerdown', 20, 300, 300 );
		t( 'win', 'pointermove', 20, 330, 310 );
		t( 'el', 'pointerdown', 21, 500, 300 );
		t( 'win', 'pointermove', 21, 520, 340 );
		t( 'win', 'pointermove', 20, 310, 290 );
		t( 'el', 'pointerdown', 22, 400, 450 );
		t( 'win', 'pointermove', 22, 410, 420 );
		t( 'win', 'pointermove', 20, 300, 280 );
		t( 'win', 'pointerup', 22, 410, 420 );
		t( 'win', 'pointerup', 21, 520, 340 );
		t( 'win', 'pointerup', 20, 300, 280 );
		t( 'el', 'pointerdown', 20, 300, 300 );
		t( 'el', 'pointerdown', 21, 400, 300 );
		t( 'win', 'pointermove', 21, 440, 330 );
		t( 'win', 'pointermove', 20, 280, 310 );
		t( 'win', 'pointerup', 21, 440, 330 );
		t( 'win', 'pointermove', 20, 285, 312 );
		t( 'win', 'pointermove', 20, 330, 360 );
		t( 'win', 'pointermove', 20, 350, 380 );
		t( 'win', 'pointerup', 20, 350, 380 );
		frames( 3 );
		t( 'el', 'pointerdown', 25, 300, 300 );
		t( 'el', 'pointerdown', 26, 340, 300 );
		t( 'win', 'pointermove', 26, 310, 305 );
		t( 'win', 'pointermove', 25, 302, 296 );
		t( 'win', 'pointermove', 26, 360, 330 );
		t( 'win', 'pointerup', 26, 360, 330 );
		t( 'win', 'pointerup', 25, 302, 296 );
		t( 'el', 'pointerdown', 30, 300, 300 );
		t( 'el', 'pointercancel', 30, 300, 300 );
		D( 'cancel' );
		S.log( [ 'step', 'mouse actions' ] );
		S.log( [ 'set', A.call( c, 'arcball', 'setMouseAction', [ 'ROTATE', 'WHEEL' ] ) ] );
		S.log( [ 'set', A.call( c, 'arcball', 'setMouseAction', [ 'JUMP', 0 ] ) ] );
		S.log( [ 'set', A.call( c, 'arcball', 'setMouseAction', [ 'PAN', 3 ] ) ] );
		S.log( [ 'set', A.call( c, 'arcball', 'setMouseAction', [ 'PAN', 0, 'ALT' ] ) ] );
		S.log( [ 'set', A.call( c, 'arcball', 'setMouseAction', [ 'ZOOM', 0, 'SHIFT' ] ) ] );
		S.log( [ 'set', A.call( c, 'arcball', 'setMouseAction', [ 'FOV', 2 ] ) ] );
		S.log( [ 'unset', A.call( c, 'arcball', 'unsetMouseAction', [ 1, 'SHIFT' ] ) ] );
		S.log( [ 'unset', A.call( c, 'arcball', 'unsetMouseAction', [ 1, 'CTRL' ] ) ] );
		D( 'actions' );
		ev( 'el', 'pointerdown', { x: 400, y: 300, button: 2 } );
		ev( 'win', 'pointermove', { x: 400, y: 380, button: - 1 } );
		ev( 'win', 'pointerup', { x: 400, y: 380, button: 2 } );
		ev( 'el', 'pointerdown', { x: 400, y: 300, button: 0, shiftKey: true } );
		ev( 'win', 'pointermove', { x: 400, y: 260, button: - 1, shiftKey: true } );
		ev( 'win', 'pointerup', { x: 400, y: 260 } );
		S.log( [ 'unset', A.call( c, 'arcball', 'unsetMouseAction', [ 2 ] ) ] );
		env.fire( 'el', 'contextmenu', {} );
		S.log( [ 'step', 'state' ] );
		A.call( c, 'arcball', 'saveState', [] );
		D( 'saved' );
		A.call( c, 'arcball', 'copyState', [] );
		ev( 'el', 'pointerdown', { x: 300, y: 300 } );
		ev( 'win', 'pointermove', { x: 200, y: 200, button: - 1 } );
		step( 500 );
		ev( 'win', 'pointerup', { x: 200, y: 200 } );
		A.call( c, 'arcball', 'reset', [] );
		D( 'reset' );
		A.call( c, 'arcball', 'pasteState', [] );
		D( 'pasted' );
		A.call( c, 'arcball', 'setStateFromJSON', [ '{"other":1}' ] );
		A.call( c, 'arcball', 'setGizmosVisible', [ false ] );
		A.call( c, 'arcball', 'setTbRadius', [ 0.5 ] );
		D( 'gizmos' );
		A.set( c, 'arcball', 'target', [ 1, - 1, 0.5 ] );
		A.call( c, 'arcball', 'update', [] );
		D( 'target update' );
		A.set( c, 'arcball', 'minDistance', 12 );
		A.set( c, 'arcball', 'minZoom', 1.5 );
		A.set( c, 'arcball', 'minFov', 70 );
		A.call( c, 'arcball', 'update', [] );
		D( 'limits update' );
		A.set( c, 'arcball', 'minDistance', 0 );
		A.set( c, 'arcball', 'maxDistance', 6 );
		A.set( c, 'arcball', 'maxZoom', 2 );
		A.set( c, 'arcball', 'minFov', 5 );
		A.set( c, 'arcball', 'adjustNearFar', true );
		env.fire( 'el', 'wheel', wheel( { deltaY: - 500 } ) );
		D( 'adjust near far' );
		A.set( c, 'arcball', 'adjustNearFar', false );
		env.fire( 'el', 'wheel', wheel( { deltaY: 125 } ) );
		D( 'restore near far' );
		env.fire( 'win', 'resize', {} );
		D( 'resize' );
		A.set( c, 'arcball', 'enabled', false );
		ev( 'el', 'pointerdown', { x: 300, y: 300 } );
		ev( 'win', 'pointermove', { x: 330, y: 300, button: - 1 } );
		ev( 'win', 'pointerup', { x: 330, y: 300 } );
		env.fire( 'el', 'wheel', wheel() );
		env.fire( 'el', 'contextmenu', {} );
		A.set( c, 'arcball', 'enabled', true );
		A.set( c, 'arcball', 'enablePan', false );
		A.set( c, 'arcball', 'enableZoom', false );
		A.set( c, 'arcball', 'enableRotate', false );
		ev( 'el', 'pointerdown', { x: 300, y: 300 } );
		ev( 'win', 'pointermove', { x: 330, y: 300, button: - 1 } );
		ev( 'win', 'pointerup', { x: 330, y: 300 } );
		A.set( c, 'arcball', 'enableRotate', true );
		A.set( c, 'arcball', 'enableZoom', true );
		t( 'el', 'pointerdown', 40, 300, 300 );
		t( 'el', 'pointerdown', 41, 400, 300 );
		t( 'win', 'pointermove', 41, 450, 350 );
		t( 'win', 'pointerup', 41, 450, 350 );
		t( 'win', 'pointerup', 40, 300, 300 );
		A.call( c, 'arcball', 'dispose', [] );
		D( 'dispose' );

	};

}

function arcballNoScene( A, S, env ) {

	const camera = perspective( A, 0, 0, 5 );
	A.set_vec( camera, 'up', 0, 0.6, 0.8 );
	const c = A.create( 'arcball', camera, null, null );
	S.listen( c, 'arcball', [ 'change', 'start', 'end' ] );
	const D = ( l ) => S.dump( l, c, 'arcball', [ camera ] );
	D( 'init' );
	A.call( c, 'arcball', 'connect', [ env.element ] );
	D( 'connected' );
	env.fire( 'el', 'pointerdown', pe( { x: 300, y: 300 } ) );
	env.fire( 'win', 'pointermove', pe( { x: 360, y: 340, button: - 1 } ) );
	env.now += 500;
	env.fire( 'win', 'pointerup', pe( { x: 360, y: 340 } ) );
	D( 'rotated' );
	env.fire( 'el', 'pointerdown', pe( { x: 300, y: 300, button: 2 } ) );
	env.fire( 'win', 'pointermove', pe( { x: 360, y: 340, button: - 1 } ) );
	env.fire( 'win', 'pointerup', pe( { x: 360, y: 340, button: 2 } ) );
	D( 'panned' );
	A.call( c, 'arcball', 'copyState', [] );
	A.call( c, 'arcball', 'setCamera', [ camera ] );
	D( 'set camera' );
	A.call( c, 'arcball', 'dispose', [] );
	D( 'dispose' );

}

function arcballFocus( variant ) {

	return ( A, S, env ) => {

		const scene = arcballScene( A );
		let camera;
		if ( variant === 'ortho' ) {

			camera = A.ortho( - 4, 4, 3, - 3, 0.1, 100 );
			A.set_name( camera, 'camera' );
			A.set_vec( camera, 'position', 1, 2, 9 );

		} else camera = perspective( A, 1, 2, 9 );

		const c = A.create( 'arcball', camera, env.element, { scene } );
		S.listen( c, 'arcball', [ 'change', 'start', 'end' ] );
		const D = ( l ) => {

			A.update_matrix_world( scene );
			A.update_matrix_world( camera );
			S.dump( l, c, 'arcball', [ camera ] );

		};

		const tap = ( x, y ) => {

			env.now += 1000;
			for ( let i = 0; i < 2; i ++ ) {

				env.fire( 'el', 'pointerdown', pe( { x: x + i, y } ) );
				env.now += 40;
				env.fire( 'win', 'pointerup', pe( { x: x + i, y } ) );
				env.now += 60;

			}

			D( 'tapped' );

		};

		D( 'init' );
		tap( 410, 320 );
		D( 'tapped again' );
		for ( let i = 0; i < 7; i ++ ) {

			env.now += 90;
			env.frame( env.now );
			D( 'focus frame ' + i );

		}

		S.log( [ 'step', 'interrupted focus' ] );
		tap( 380, 300 );
		env.now += 30;
		env.frame( env.now );
		env.fire( 'el', 'pointerdown', pe( { x: 300, y: 300, button: 2 } ) );
		env.frame( env.now + 16 );
		env.fire( 'win', 'pointerup', pe( { x: 300, y: 300, button: 2 } ) );
		D( 'interrupted' );
		A.set( c, 'arcball', 'enableAnimations', false );
		tap( 410, 320 );
		A.set( c, 'arcball', 'enableZoom', false );
		tap( 400, 330 );
		A.set( c, 'arcball', 'enableFocus', false );
		tap( 410, 320 );
		A.set( c, 'arcball', 'enableFocus', true );
		tap( 10, 10 );
		A.call( c, 'arcball', 'dispose', [] );
		D( 'dispose' );

	};

}

export const moreScenarios = {
	arcball_focus_perspective: arcballFocus( 'perspective' ),
	arcball_focus_ortho: arcballFocus( 'ortho' ),
	fly,
	first_person: firstPerson,
	pointer_lock: pointerLock,
	trackball_perspective: trackball( false ),
	trackball_ortho: trackball( true ),
	drag: dragControls,
	transform_perspective: transformControls( 'perspective' ),
	transform_ortho: transformControls( 'ortho' ),
	transform_snap: transformControls( 'snap' ),
	transform_aligned: transformControls( 'aligned' ),
	arcball_perspective: arcball( 'perspective' ),
	arcball_ortho: arcball( 'ortho' ),
	arcball_no_scene: arcballNoScene,
};
