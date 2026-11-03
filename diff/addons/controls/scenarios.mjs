// Event scripts. Each scenario runs once per side with a fresh DOM stub; `A` is the
// side's adapter, `S.dump` logs the camera, the controls' fields (FIELDS) and the
// registered DOM listeners.

const ORBIT_FIELDS = [ 'enabled', 'state', 'target', 'cursor', 'target0', 'position0', 'zoom0', 'cursorStyle',
	'enablePan', 'enableZoom', 'zoomToCursor', '_spherical', '_sphericalDelta', '_scale', '_panOffset',
	'_rotateStart', '_rotateEnd', '_rotateDelta', '_panStart', '_panEnd', '_panDelta', '_dollyStart', '_dollyEnd',
	'_dollyDelta', '_dollyDirection', '_mouse', '_performCursorZoom', '_pointers', '_pointerPositions',
	'_controlActive', '_lastPosition', '_lastQuaternion', '_lastTargetPosition', '_quat', '_quatInverse',
	'mouseButtons', 'touches' ];

export const FIELDS = {
	orbit: ORBIT_FIELDS,
	map: [ ...ORBIT_FIELDS, '_panWorldStart' ],
	fly: [ 'enabled', 'movementSpeedMultiplier', '_moveState', '_moveVector', '_rotationVector', '_lastQuaternion', '_lastPosition', '_status' ],
	firstperson: [ 'enabled', 'mouseDragOn', '_velocity', '_pointerX', '_pointerY', '_pointerDownX', '_pointerDownY', '_pointerCount',
		'_keyForward', '_keyBackward', '_pointerForward', '_pointerBackward', '_moveLeft', '_moveRight', '_moveUp', '_moveDown',
		'_lat', '_lon', '_lonVelocity', '_latVelocity' ],
	pointerlock: [ 'enabled', 'isLocked' ],
	trackball: [ 'enabled', 'state', 'screen', 'keyState', 'target', '_lastPosition', '_lastUp', '_lastZoom', '_touchZoomDistanceStart',
		'_touchZoomDistanceEnd', '_touchRollAngle', '_touchRollPointerIds', '_lastAngle', '_lastRollAngle', '_eye', '_movePrev',
		'_moveCurr', '_lastAxis', '_zoomStart', '_zoomEnd', '_panStart', '_panEnd', '_pointers', '_pointerPositions', '_target0',
		'_position0', '_up0', '_zoom0', 'mouseButtons' ],
	drag: [ 'enabled', 'state', 'recursive', 'transformGroup', 'raycaster.ray.origin', 'raycaster.ray.direction', 'mouseButtons', 'touches' ],
	transform: [ 'enabled', 'object', 'camera', 'axis', 'mode', 'translationSnap', 'rotationSnap', 'scaleSnap', 'space', 'size', 'dragging',
		'showX', 'showE', 'minX', 'maxZ', 'worldPosition', 'worldPositionStart', 'worldQuaternion', 'worldQuaternionStart', 'cameraPosition',
		'cameraQuaternion', 'pointStart', 'pointEnd', 'rotationAxis', 'rotationAngle', 'eye', '_offset', '_startNorm', '_endNorm',
		'_cameraScale', '_parentPosition', '_parentQuaternion', '_parentQuaternionInv', '_parentScale', '_worldScaleStart',
		'_worldQuaternionInv', '_worldScale', '_positionStart', '_quaternionStart', '_scaleStart', '_root.visible', '_root.matrixWorld',
		'_plane.position', '_plane.quaternion', '_plane.matrixWorld', '_gizmo.mode', '_gizmo.axis', '_gizmo.dragging',
		'_gizmo.rotationAngle', '_plane.space', '_plane.axis' ],
	transform_full: null,
	arcball: [ 'enabled', 'target', '_currentTarget', 'radiusFactor', '_state', '_input', '_mouseOp', '_rotationAxis', '_cameraMatrixState',
		'_cameraProjectionState', '_fovState', '_upState', '_zoomState', '_nearPos', '_farPos', '_gizmoMatrixState', '_up0', '_zoom0',
		'_fov0', '_initialNear', '_nearPos0', '_initialFar', '_farPos0', '_cameraMatrixState0', '_gizmoMatrixState0', '_target0',
		'_button', '_touchStart', '_touchCurrent', '_startFingerDistance', '_currentFingerDistance', '_startFingerRotation',
		'_currentFingerRotation', '_devPxRatio', '_downValid', '_nclicks', '_downEvents', '_downStart', '_clickStart',
		'_currentCursorPosition', '_startCursorPosition', '_grid', '_gridPosition', '_gizmos', '_timeStart', '_animationId',
		'_timePrev', '_timeCurrent', '_anglePrev', '_angleCurrent', '_cursorPosPrev', '_cursorPosCurr', '_wPrev', '_wCurr',
		'_tbRadius', 'mouseActions' ],
};
FIELDS.transform_full = [ ...FIELDS.transform, 'handles' ];

let pointerTime = 0;

// A pointer event; page coordinates are offset from client ones like a scrolled page.
function pe( o = {} ) {

	const clientX = o.x ?? 100, clientY = o.y ?? 100;
	const e = {
		pointerId: 1, pointerType: 'mouse', button: 0, buttons: 1, isPrimary: true,
		clientX, clientY, pageX: clientX + 3, pageY: clientY + 5,
		ctrlKey: false, metaKey: false, shiftKey: false, altKey: false,
		movementX: 0, movementY: 0,
	};
	for ( const k of Object.keys( o ) ) if ( k !== 'x' && k !== 'y' ) e[ k ] = o[ k ];
	pointerTime ++;
	return e;

}

const key = ( code, o = {} ) => Object.assign( { code, key: code, ctrlKey: false, metaKey: false, shiftKey: false, altKey: false }, o );
const wheel = ( o = {} ) => Object.assign( { clientX: 300, clientY: 200, deltaX: 0, deltaY: 100, deltaMode: 0, ctrlKey: false, metaKey: false, shiftKey: false }, o );

// A drag: down on `downTarget`, moves and up on `moveTarget`.
function drag( S, env, label, downTarget, moveTarget, o, points, after ) {

	S.log( [ 'step', label + ' down' ] );
	env.fire( downTarget, 'pointerdown', pe( { ...o, x: points[ 0 ][ 0 ], y: points[ 0 ][ 1 ] } ) );
	after( label + ' down' );
	for ( let i = 1; i < points.length; i ++ ) {

		S.log( [ 'step', label + ' move ' + i ] );
		env.fire( moveTarget, 'pointermove', pe( { ...o, button: - 1, x: points[ i ][ 0 ], y: points[ i ][ 1 ] } ) );
		after( label + ' move ' + i );

	}

	S.log( [ 'step', label + ' up' ] );
	const last = points[ points.length - 1 ];
	env.fire( moveTarget, 'pointerup', pe( { ...o, x: last[ 0 ], y: last[ 1 ] } ) );
	after( label + ' up' );

}

function orbitCamera( A ) {

	const camera = A.perspective( 50, 800 / 600, 0.1, 1000 );
	A.set_name( camera, 'camera' );
	A.set_vec( camera, 'position', 3, 4, 10 );
	return camera;

}

function orthoCamera( A ) {

	const camera = A.ortho( - 4, 4, 3, - 3, 0.1, 100 );
	A.set_name( camera, 'camera' );
	A.set_vec( camera, 'position', 2, 5, 8 );
	return camera;

}

function orbitMouse( kind ) {

	return ( A, S, env ) => {

		const camera = orbitCamera( A );
		const c = A.create( kind, camera, env.element );
		S.listen( c, kind, [ 'change', 'start', 'end' ] );
		const D = ( l ) => S.dump( l, c, kind, [ camera ] );
		D( 'init' );
		S.log( [ 'step', 'contextmenu' ] );
		env.fire( 'el', 'contextmenu', {} );
		drag( S, env, 'left', 'el', 'doc', {}, [ [ 100, 100 ], [ 150, 120 ], [ 220, 60 ] ], D );
		drag( S, env, 'left+shift', 'el', 'doc', { shiftKey: true }, [ [ 300, 300 ], [ 320, 280 ], [ 280, 330 ] ], D );
		drag( S, env, 'right', 'el', 'doc', { button: 2 }, [ [ 400, 300 ], [ 420, 310 ] ], D );
		drag( S, env, 'right+ctrl', 'el', 'doc', { button: 2, ctrlKey: true }, [ [ 400, 300 ], [ 380, 250 ] ], D );
		drag( S, env, 'middle', 'el', 'doc', { button: 1 }, [ [ 400, 300 ], [ 400, 340 ], [ 400, 250 ], [ 400, 250 ] ], D );
		drag( S, env, 'button3', 'el', 'doc', { button: 3 }, [ [ 400, 300 ], [ 410, 310 ] ], D );
		S.log( [ 'step', 'second mouse pointer while dragging' ] );
		env.fire( 'el', 'pointerdown', pe( { pointerId: 1, x: 10, y: 10 } ) );
		env.fire( 'el', 'pointerdown', pe( { pointerId: 1, x: 12, y: 10 } ) );
		env.fire( 'doc', 'pointerup', pe( { pointerId: 1 } ) );
		D( 'dup' );
		for ( const [ mode, dy ] of [ [ 0, 100 ], [ 0, - 40 ], [ 1, 3 ], [ 2, - 1 ], [ 0, 0 ] ] ) {

			S.log( [ 'step', 'wheel ' + mode + ' ' + dy ] );
			env.fire( 'el', 'wheel', wheel( { deltaMode: mode, deltaY: dy } ) );
			D( 'wheel' );

		}

		S.log( [ 'step', 'pinch wheel' ] );
		env.fire( 'el', 'wheel', wheel( { ctrlKey: true, deltaY: - 5 } ) );
		D( 'pinch' );
		S.log( [ 'step', 'control key down' ] );
		env.fire( 'doc', 'keydown', key( 'ControlLeft', { key: 'Control' } ) );
		env.fire( 'el', 'wheel', wheel( { ctrlKey: true, deltaY: - 5 } ) );
		D( 'ctrl wheel' );
		env.fire( 'doc', 'keyup', key( 'ControlLeft', { key: 'Shift' } ) );
		env.fire( 'doc', 'keyup', key( 'ControlLeft', { key: 'Control' } ) );
		D( 'ctrl up' );
		S.log( [ 'step', 'keys before listen' ] );
		env.fire( 'win', 'keydown', key( 'ArrowUp' ) );
		D( 'keys' );
		A.call( c, kind, 'listenToKeyEvents', [ env.window ] );
		for ( const [ code, o ] of [ [ 'ArrowUp', {} ], [ 'ArrowDown', {} ], [ 'ArrowLeft', {} ], [ 'ArrowRight', {} ],
			[ 'ArrowUp', { shiftKey: true } ], [ 'ArrowDown', { ctrlKey: true } ], [ 'ArrowLeft', { metaKey: true } ],
			[ 'ArrowRight', { shiftKey: true } ], [ 'KeyA', {} ] ] ) {

			S.log( [ 'step', 'key ' + code + JSON.stringify( o ) ] );
			env.fire( 'win', 'keydown', key( code, o ) );
			D( 'key' );

		}

		A.set( c, kind, 'keys', { LEFT: 'KeyA', UP: 'KeyW', RIGHT: 'KeyD', BOTTOM: 'KeyS' } );
		env.fire( 'win', 'keydown', key( 'KeyW' ) );
		env.fire( 'win', 'keydown', key( 'ArrowUp' ) );
		D( 'custom keys' );
		A.call( c, kind, 'stopListenToKeyEvents', [] );
		env.fire( 'win', 'keydown', key( 'KeyW' ) );
		D( 'stopped keys' );
		S.log( [ 'step', 'save state' ] );
		A.call( c, kind, 'saveState', [] );
		drag( S, env, 'left2', 'el', 'doc', {}, [ [ 100, 100 ], [ 300, 400 ] ], D );
		S.log( [ 'step', 'reset' ] );
		A.call( c, kind, 'reset', [] );
		D( 'reset' );
		S.log( [ 'step', 'programmatic' ] );
		A.call( c, kind, 'pan', [ 10, - 5 ] );
		A.call( c, kind, 'dollyIn', [ 1.2 ] );
		A.call( c, kind, 'dollyOut', [ 1.1 ] );
		A.call( c, kind, 'rotateLeft', [ 0.3 ] );
		A.call( c, kind, 'rotateUp', [ - 0.2 ] );
		S.log( [ 'getters', A.call( c, kind, 'getDistance', [] ), A.call( c, kind, 'getPolarAngle', [] ), A.call( c, kind, 'getAzimuthalAngle', [] ) ] );
		D( 'programmatic' );
		S.log( [ 'step', 'damping' ] );
		A.set( c, kind, 'enableDamping', true );
		A.set( c, kind, 'dampingFactor', 0.1 );
		drag( S, env, 'damped', 'el', 'doc', {}, [ [ 100, 100 ], [ 140, 130 ], [ 180, 150 ] ], D );
		drag( S, env, 'damped pan', 'el', 'doc', { button: 2 }, [ [ 100, 100 ], [ 140, 130 ] ], D );
		for ( let i = 0; i < 6; i ++ ) {

			S.log( [ 'update', A.call( c, kind, 'update', [] ) ] );
			D( 'damped update ' + i );

		}

		S.log( [ 'step', 'auto rotate' ] );
		A.set( c, kind, 'enableDamping', false );
		A.set( c, kind, 'autoRotate', true );
		A.set( c, kind, 'autoRotateSpeed', 3 );
		S.log( [ 'update', A.call( c, kind, 'update', [] ) ] );
		S.log( [ 'update', A.call( c, kind, 'update', [ 0.5 ] ) ] );
		S.log( [ 'update', A.call( c, kind, 'update', [ null ] ) ] );
		D( 'auto' );
		A.set( c, kind, 'autoRotate', false );
		S.log( [ 'step', 'limits' ] );
		A.set( c, kind, 'minAzimuthAngle', - 0.5 );
		A.set( c, kind, 'maxAzimuthAngle', 0.5 );
		A.set( c, kind, 'minPolarAngle', 0.8 );
		A.set( c, kind, 'maxPolarAngle', 1.6 );
		A.set( c, kind, 'minDistance', 6 );
		A.set( c, kind, 'maxDistance', 9 );
		S.log( [ 'update', A.call( c, kind, 'update', [] ) ] );
		D( 'limits' );
		A.set( c, kind, 'minAzimuthAngle', 3 );
		A.set( c, kind, 'maxAzimuthAngle', - 3 );
		drag( S, env, 'wrap', 'el', 'doc', {}, [ [ 100, 100 ], [ 500, 100 ], [ 900, 100 ] ], D );
		A.set( c, kind, 'minAzimuthAngle', - 7 );
		A.set( c, kind, 'maxAzimuthAngle', 7 );
		S.log( [ 'update', A.call( c, kind, 'update', [] ) ] );
		A.set( c, kind, 'minTargetRadius', 0.5 );
		A.set( c, kind, 'maxTargetRadius', 1 );
		A.set( c, kind, 'cursor', [ 1, 0, 0 ] );
		A.call( c, kind, 'pan', [ 300, 200 ] );
		D( 'target radius' );
		S.log( [ 'step', 'cursor style' ] );
		A.set( c, kind, 'cursorStyle', 'grab' );
		drag( S, env, 'grab', 'el', 'doc', {}, [ [ 100, 100 ], [ 110, 100 ] ], D );
		A.set( c, kind, 'cursorStyle', 'auto' );
		S.log( [ 'step', 'disabled' ] );
		A.set( c, kind, 'enabled', false );
		drag( S, env, 'disabled', 'el', 'doc', {}, [ [ 100, 100 ], [ 200, 100 ] ], D );
		env.fire( 'el', 'wheel', wheel() );
		env.fire( 'el', 'contextmenu', {} );
		A.set( c, kind, 'enabled', true );
		S.log( [ 'step', 'disabled features' ] );
		A.set( c, kind, 'enableRotate', false );
		A.set( c, kind, 'enablePan', false );
		A.set( c, kind, 'enableZoom', false );
		drag( S, env, 'no rotate', 'el', 'doc', {}, [ [ 100, 100 ], [ 200, 100 ] ], D );
		drag( S, env, 'no pan', 'el', 'doc', { button: 2 }, [ [ 100, 100 ], [ 200, 100 ] ], D );
		drag( S, env, 'no zoom', 'el', 'doc', { button: 1 }, [ [ 100, 100 ], [ 200, 140 ] ], D );
		env.fire( 'el', 'wheel', wheel() );
		D( 'no zoom wheel' );
		A.set( c, kind, 'enableRotate', true );
		A.set( c, kind, 'enablePan', true );
		A.set( c, kind, 'enableZoom', true );
		S.log( [ 'step', 'mouse buttons' ] );
		A.set( c, kind, 'mouseButtons', { LEFT: 2, MIDDLE: null, RIGHT: 0 } );
		drag( S, env, 'remapped left', 'el', 'doc', {}, [ [ 100, 100 ], [ 200, 100 ] ], D );
		drag( S, env, 'remapped middle', 'el', 'doc', { button: 1 }, [ [ 100, 100 ], [ 200, 100 ] ], D );
		S.log( [ 'step', 'reconnect' ] );
		A.call( c, kind, 'connect', [ env.element ] );
		D( 'reconnect' );
		S.log( [ 'step', 'dispose' ] );
		A.call( c, kind, 'dispose', [] );
		D( 'dispose' );
		drag( S, env, 'after dispose', 'el', 'doc', {}, [ [ 100, 100 ], [ 200, 100 ] ], D );

	};

}

function orbitTouch( kind, two ) {

	return ( A, S, env ) => {

		const camera = orbitCamera( A );
		const c = A.create( kind, camera, env.element );
		S.listen( c, kind, [ 'change', 'start', 'end' ] );
		if ( two !== undefined ) A.set( c, kind, 'touches', { ONE: 0, TWO: two } );
		const D = ( l ) => S.dump( l, c, kind, [ camera ] );
		const t = ( type, target, id, x, y ) => {

			S.log( [ 'step', type + ' ' + id ] );
			env.fire( target, type, pe( { pointerType: 'touch', pointerId: id, x, y, isPrimary: id === 10 } ) );
			D( type + ' ' + id );

		};

		t( 'pointerdown', 'el', 10, 100, 100 );
		t( 'pointermove', 'doc', 10, 130, 90 );
		t( 'pointermove', 'doc', 10, 150, 95 );
		t( 'pointerdown', 'el', 11, 300, 300 );
		t( 'pointermove', 'doc', 11, 320, 330 );
		t( 'pointermove', 'doc', 10, 120, 80 );
		t( 'pointermove', 'doc', 11, 250, 260 );
		t( 'pointerdown', 'el', 12, 500, 100 );
		t( 'pointermove', 'doc', 12, 510, 110 );
		t( 'pointermove', 'doc', 10, 110, 70 );
		t( 'pointerup', 'doc', 12, 510, 110 );
		t( 'pointermove', 'doc', 11, 240, 250 );
		t( 'pointerup', 'doc', 11, 240, 250 );
		t( 'pointermove', 'doc', 10, 160, 120 );
		t( 'pointerup', 'doc', 10, 160, 120 );
		S.log( [ 'step', 'pointercancel' ] );
		t( 'pointerdown', 'el', 20, 100, 100 );
		t( 'pointerdown', 'el', 21, 200, 100 );
		t( 'pointercancel', 'el', 21, 200, 100 );
		t( 'pointermove', 'doc', 20, 150, 150 );
		t( 'pointercancel', 'el', 20, 150, 150 );
		S.log( [ 'step', 'zoomToCursor touch' ] );
		A.set( c, kind, 'zoomToCursor', true );
		t( 'pointerdown', 'el', 30, 100, 100 );
		t( 'pointerdown', 'el', 31, 300, 200 );
		t( 'pointermove', 'doc', 31, 400, 300 );
		t( 'pointerup', 'doc', 31, 400, 300 );
		t( 'pointerup', 'doc', 30, 100, 100 );
		S.log( [ 'step', 'disabled touch' ] );
		A.set( c, kind, 'enableRotate', false );
		A.set( c, kind, 'enablePan', false );
		t( 'pointerdown', 'el', 40, 100, 100 );
		t( 'pointermove', 'doc', 40, 140, 100 );
		A.set( c, kind, 'enableZoom', false );
		t( 'pointerdown', 'el', 41, 200, 100 );
		t( 'pointermove', 'doc', 41, 260, 100 );
		t( 'pointerup', 'doc', 41, 260, 100 );
		t( 'pointerup', 'doc', 40, 140, 100 );
		A.set( c, kind, 'touches', { ONE: 2, TWO: 0 } );
		A.set( c, kind, 'enableRotate', true );
		A.set( c, kind, 'enablePan', true );
		A.set( c, kind, 'enableZoom', true );
		t( 'pointerdown', 'el', 50, 100, 100 );
		t( 'pointerdown', 'el', 51, 200, 100 );
		t( 'pointermove', 'doc', 51, 260, 100 );
		t( 'pointerup', 'doc', 51, 260, 100 );
		t( 'pointerup', 'doc', 50, 140, 100 );

	};

}

function orbitOrtho( kind ) {

	return ( A, S, env ) => {

		const camera = orthoCamera( A );
		const c = A.create( kind, camera, env.element );
		S.listen( c, kind, [ 'change', 'start', 'end' ] );
		const D = ( l ) => S.dump( l, c, kind, [ camera ] );
		D( 'init' );
		for ( const dy of [ 100, - 300, 20 ] ) {

			env.fire( 'el', 'wheel', wheel( { deltaY: dy } ) );
			D( 'wheel ' + dy );

		}

		drag( S, env, 'pan', 'el', 'doc', { button: 2 }, [ [ 100, 100 ], [ 150, 160 ] ], D );
		drag( S, env, 'rotate', 'el', 'doc', {}, [ [ 100, 100 ], [ 150, 160 ] ], D );
		drag( S, env, 'dolly', 'el', 'doc', { button: 1 }, [ [ 100, 100 ], [ 100, 160 ], [ 100, 40 ] ], D );
		A.set( c, kind, 'minZoom', 0.5 );
		A.set( c, kind, 'maxZoom', 1.5 );
		for ( const dy of [ - 3000, 3000 ] ) {

			env.fire( 'el', 'wheel', wheel( { deltaY: dy } ) );
			D( 'clamped wheel ' + dy );

		}

		A.set( c, kind, 'zoomToCursor', true );
		for ( const [ x, y, dy ] of [ [ 500, 400, - 200 ], [ 100, 50, 150 ] ] ) {

			env.fire( 'el', 'wheel', wheel( { clientX: x, clientY: y, deltaY: dy } ) );
			D( 'cursor wheel' );

		}

		drag( S, env, 'cursor dolly', 'el', 'doc', { button: 1 }, [ [ 600, 100 ], [ 600, 160 ] ], D );
		A.set( c, kind, 'screenSpacePanning', false );
		env.fire( 'el', 'wheel', wheel( { clientX: 200, clientY: 500, deltaY: - 100 } ) );
		D( 'cursor wheel plane' );
		A.call( c, kind, 'saveState', [] );
		A.call( c, kind, 'reset', [] );
		D( 'reset' );

	};

}

function orbitZoomToCursor( kind ) {

	return ( A, S, env ) => {

		const camera = orbitCamera( A );
		A.set_vec( camera, 'up', 0, 0, 1 );
		const c = A.create( kind, camera, env.element );
		S.listen( c, kind, [ 'change', 'start', 'end' ] );
		const D = ( l ) => S.dump( l, c, kind, [ camera ] );
		A.set( c, kind, 'zoomToCursor', true );
		for ( const ssp of [ true, false ] ) {

			A.set( c, kind, 'screenSpacePanning', ssp );
			for ( const [ x, y, dy ] of [ [ 500, 400, - 200 ], [ 100, 50, 150 ], [ 410, 320, - 50 ] ] ) {

				env.fire( 'el', 'wheel', wheel( { clientX: x, clientY: y, deltaY: dy } ) );
				D( 'cursor wheel ' + ssp );

			}

			drag( S, env, 'cursor dolly ' + ssp, 'el', 'doc', { button: 1 }, [ [ 600, 100 ], [ 600, 160 ], [ 600, 90 ] ], D );

		}

		A.set( c, kind, 'minDistance', 4 );
		A.set( c, kind, 'maxDistance', 5 );
		env.fire( 'el', 'wheel', wheel( { clientX: 10, clientY: 30, deltaY: - 2000 } ) );
		D( 'clamped' );
		A.set( c, kind, 'enableDamping', true );
		env.fire( 'el', 'wheel', wheel( { clientX: 10, clientY: 30, deltaY: 300 } ) );
		for ( let i = 0; i < 3; i ++ ) S.log( [ 'update', A.call( c, kind, 'update', [] ) ] );
		D( 'damped' );

	};

}

function orbitLate( kind ) {

	return ( A, S, env ) => {

		const camera = orbitCamera( A );
		A.set_vec( camera, 'up', 1, 0, 0 );
		const c = A.create( kind, camera, null );
		S.listen( c, kind, [ 'change', 'start', 'end' ] );
		const D = ( l ) => S.dump( l, c, kind, [ camera ] );
		D( 'no dom' );
		A.call( c, kind, 'update', [] );
		A.call( c, kind, 'connect', [ env.element ] );
		D( 'connected' );
		drag( S, env, 'left', 'el', 'doc', {}, [ [ 100, 100 ], [ 150, 120 ] ], D );
		drag( S, env, 'pan', 'el', 'doc', { button: 2 }, [ [ 100, 100 ], [ 150, 120 ] ], D );
		A.call( c, kind, 'disconnect', [] );
		D( 'disconnected' );

	};

}

import { moreScenarios } from './scenarios2.mjs';
export { pe, key, wheel, drag };
function orbitUnknownCamera( A, S, env ) {

	const object = A.group();
	A.set_name( object, 'object' );
	A.set_vec( object, 'position', 1, 2, 3 );
	const c = A.create( 'orbit', object, env.element );
	S.listen( c, 'orbit', [ 'change', 'start', 'end' ] );
	const D = ( l ) => S.dump( l, c, 'orbit', [ object ] );
	D( 'init' );
	drag( S, env, 'rotate', 'el', 'doc', {}, [ [ 100, 100 ], [ 150, 120 ] ], D );
	drag( S, env, 'pan', 'el', 'doc', { button: 2 }, [ [ 100, 100 ], [ 150, 120 ] ], D );
	env.fire( 'el', 'wheel', wheel() );
	D( 'wheel' );
	A.set( c, 'orbit', 'enableZoom', true );
	A.set( c, 'orbit', 'zoomToCursor', true );
	env.fire( 'el', 'wheel', wheel() );
	D( 'cursor wheel' );
	A.call( c, 'orbit', 'saveState', [] );
	A.call( c, 'orbit', 'reset', [] );
	D( 'not reached' );

}

export const scenarios = {
	orbit_unknown_camera: orbitUnknownCamera,
	orbit_mouse: orbitMouse( 'orbit' ),
	orbit_touch: orbitTouch( 'orbit' ),
	orbit_touch_dolly_rotate: orbitTouch( 'orbit', 3 ),
	orbit_ortho: orbitOrtho( 'orbit' ),
	orbit_zoom_to_cursor: orbitZoomToCursor( 'orbit' ),
	orbit_late_connect: orbitLate( 'orbit' ),
	map_mouse: orbitMouse( 'map' ),
	map_touch: orbitTouch( 'map' ),
	map_ortho: orbitOrtho( 'map' ),
	map_zoom_to_cursor: orbitZoomToCursor( 'map' ),
	map_late_connect: orbitLate( 'map' ),
	...moreScenarios,
};
