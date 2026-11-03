// Upstream side of the adapter interface main/main.mbt exports.
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { upstreamURL } from '../../lib/env.mjs';
import { copyUpstream } from './copy_upstream.mjs';

export async function makeUpstream() {

	const THREE = await import( upstreamURL( 'src/Three.js' ) );
	const dir = copyUpstream();
	const load = async ( n ) => ( await import( pathToFileURL( path.join( dir, n + '.js' ) ) ) );
	const M = {
		...( await load( 'OrbitControls' ) ), ...( await load( 'MapControls' ) ),
		...( await load( 'FlyControls' ) ), ...( await load( 'FirstPersonControls' ) ),
		...( await load( 'PointerLockControls' ) ), ...( await load( 'TrackballControls' ) ),
		...( await load( 'DragControls' ) ), ...( await load( 'TransformControls' ) ),
		...( await load( 'ArcballControls' ) ),
	};

	const norm = ( v ) => {

		if ( v === null || v === undefined || typeof v !== 'object' ) return v;
		if ( v.isVector3 ) return [ v.x, v.y, v.z ];
		if ( v.isVector2 ) return [ v.x, v.y ];
		if ( v.isQuaternion ) return [ v.x, v.y, v.z, v.w ];
		if ( v.isMatrix4 ) return Array.from( v.elements );
		if ( v.isEuler ) return [ v.x, v.y, v.z ];
		if ( v.isObject3D ) return 'obj:' + v.name;
		if ( 'radius' in v && 'phi' in v && 'theta' in v ) return [ v.radius, v.phi, v.theta ];
		if ( Array.isArray( v ) ) return v.map( norm );
		return v;

	};

	const positions = ( o ) => Object.keys( o ).map( Number ).sort( ( a, b ) => a - b )
		.map( ( k ) => fmtNum( k ) + ':[' + fmtNum( o[ k ].x ) + ',' + fmtNum( o[ k ].y ) + ']' ).join( ';' );
	const fmtNum = ( v ) => Object.is( v, - 0 ) ? '-0' : String( v );

	const f3 = ( v ) => [ v.x, v.y, v.z ].map( fmtNum ).join( ',' );
	const fq = ( v ) => [ v.x, v.y, v.z, v.w ].map( fmtNum ).join( ',' );
	const fm = ( m ) => Array.from( m.elements ).map( fmtNum ).join( ',' );
	const symName = ( table, v ) => Object.keys( table ).find( ( k ) => table[ k ] === v );
	const getPath = ( o, path ) => {

		if ( o._gizmo !== undefined && o._plane !== undefined ) {

			if ( path === 'object' ) return o.object === undefined ? undefined : 'obj:' + o.object.name;
			if ( path === 'camera' ) return 'obj:' + o.camera.name;
			if ( path === 'handles' ) {

				const out = [];
				for ( const group of [ o._gizmo.picker, o._gizmo.gizmo, o._gizmo.helper ] ) for ( const mode of [ 'translate', 'rotate', 'scale' ] ) {

					const g = group[ mode ];
					out.push( `${mode} group visible=${g.visible}` );
					for ( const h of g.children ) {

						const m = h.material, c = m.color;
						out.push( `${h.name} v=${h.visible} p=${f3( h.position )} q=${fq( h.quaternion )} s=${f3( h.scale )} c=${fmtNum( c.r )},${fmtNum( c.g )},${fmtNum( c.b )} o=${fmtNum( m.opacity )} mw=${fm( h.matrixWorld )}` );

					}

				}

				return out;

			}

		}

		if ( o.isArcballControls === undefined && o._tbRadius !== undefined ) {

			if ( path === '_state' ) return symName( M.__STATE, o._state );
			if ( path === '_input' ) return symName( M.__INPUT, o._input );
			if ( path === '_touchStart' || path === '_touchCurrent' ) return o[ path ].map( ( e ) => e.pointerId );
			if ( path === '_downEvents' ) return o._downEvents.map( ( e ) => e.timeStamp );
			if ( path === '_grid' ) return o._grid === null ? null : 'grid ' + f3( o._grid.position ) + ' ' + fq( o._grid.quaternion );
			if ( path === '_gizmos' ) {

				const g = o._gizmos;
				const parts = [ `v=${g.visible} p=${f3( g.position )} q=${fq( g.quaternion )} s=${f3( g.scale )} m=${fm( g.matrix )}` ];
				for ( const ch of g.children ) {

					const pos = ch.geometry.getAttribute( 'position' );
					parts.push( `o=${fmtNum( ch.material.opacity )} n=${pos.count} r=${fq( ch.quaternion )} x0=${fmtNum( pos.getX( 1 ) )}` );

				}

				return parts.join( ' | ' );

			}

			if ( path === 'mouseActions' ) return o.mouseActions.map( ( a ) => `${a.operation}:${a.mouse}:${a.key}:${symName( M.__STATE, a.state )}` );

		}

		if ( path === '_moveState' ) {

			const m = o._moveState;
			return [ m.up, m.down, m.left, m.right, m.forward, m.back, m.pitchUp, m.pitchDown, m.yawLeft, m.yawRight, m.rollLeft, m.rollRight ];

		}

		if ( path === 'screen' ) return [ o.screen.left, o.screen.top, o.screen.width, o.screen.height ];
		if ( path === '_pointers' && o._pointers.length && typeof o._pointers[ 0 ] === 'object' ) return o._pointers.map( ( e ) => e.pointerId );

		if ( path === '_pointerPositions' ) return positions( o._pointerPositions );
		if ( path === 'mouseButtons' ) return [ o.mouseButtons.LEFT, o.mouseButtons.MIDDLE, o.mouseButtons.RIGHT ].map( ( x ) => x ?? - 99 );
		if ( path === 'touches' ) return [ o.touches.ONE, o.touches.TWO ].map( ( x ) => x ?? - 99 );
		if ( path === 'cursorStyle' ) return o.cursorStyle;
		if ( path === 'domElement' ) return o.domElement;
		let v = o;
		for ( const p of path.split( '.' ) ) v = v[ p ];
		return norm( v );

	};

	return {
		THREE, M, norm,
		perspective: ( fov, aspect, near, far ) => new THREE.PerspectiveCamera( fov, aspect, near, far ),
		ortho: ( l, r, t, b, n, f ) => new THREE.OrthographicCamera( l, r, t, b, n, f ),
		set_vec: ( o, which, x, y, z ) => o[ which ].set( x, y, z ),
		look_at: ( o, x, y, z ) => o.lookAt( x, y, z ),
		update_matrix_world: ( o ) => o.updateMatrixWorld(),
		add_child: ( p, c ) => p.add( c ),
		set_name: ( o, n ) => {

			o.name = n;

		},
		obj_name: ( o ) => o.name,
		scene: () => new THREE.Scene(),
		group: () => new THREE.Group(),
		box_mesh: ( w, h, d ) => new THREE.Mesh( new THREE.BoxGeometry( w, h, d ), new THREE.MeshBasicMaterial() ),
		obj_state( o ) {

			const out = {
				position: norm( o.position ), quaternion: norm( o.quaternion ), scale: norm( o.scale ),
				up: norm( o.up ), visible: o.visible, matrixWorld: norm( o.matrixWorld ),
			};
			if ( o.isPerspectiveCamera ) Object.assign( out, { zoom: o.zoom, fov: o.fov, near: o.near, far: o.far, projectionMatrix: norm( o.projectionMatrix ) } );
			if ( o.isOrthographicCamera ) Object.assign( out, { zoom: o.zoom, near: o.near, far: o.far, projectionMatrix: norm( o.projectionMatrix ) } );
			return out;

		},
		create( kind, camera, dom, extra ) {

			dom = dom ?? null;
			switch ( kind ) {

				case 'orbit': return new M.OrbitControls( camera, dom );
				case 'map': return new M.MapControls( camera, dom === null ? undefined : dom );
				case 'fly': return new M.FlyControls( camera, dom );
				case 'firstperson': return new M.FirstPersonControls( camera, dom );
				case 'pointerlock': return new M.PointerLockControls( camera, dom );
				case 'trackball': return new M.TrackballControls( camera, dom );
				case 'drag': return new M.DragControls( extra.objects, camera, dom );
				case 'transform': return new M.TransformControls( camera, dom );
				case 'arcball': return new M.ArcballControls( camera, dom, extra && extra.scene ? extra.scene : null );

			}

			throw new Error( kind );

		},
		listen( ctrl, kind, type, cb ) {

			ctrl.addEventListener( type, ( e ) => cb( e.type, globalThis.__describe( 'value' in e ? e.value : 'mode' in e ? e.mode : e.object ) ) );

		},
		set( ctrl, kind, prop, value ) {

			if ( prop === 'target' || prop === 'cursor' ) ctrl[ prop ].set( value[ 0 ], value[ 1 ], value[ 2 ] );
			else if ( prop === 'viewport' ) ctrl.viewport = value === null ? null : new THREE.Vector4( value.x, value.y, value.z, value.w );
			else ctrl[ prop ] = value;

		},
		call( ctrl, kind, method, args ) {

			if ( kind === 'transform' && method === 'getHelper' ) return ctrl.getHelper();
			if ( kind === 'pointerlock' && method === 'getDirection' ) return norm( ctrl.getDirection( new THREE.Vector3( 9, 9, 9 ) ) );
			if ( kind === 'firstperson' && method === 'lookAt' && args.length === 1 ) return norm( ctrl.lookAt( new THREE.Vector3( ...args[ 0 ] ) ) ) && undefined;
			if ( kind !== 'orbit' && kind !== 'map' && kind !== 'transform' && kind !== 'pointerlock' && kind !== 'arcball' ) {

				ctrl[ method ]( ...args );
				return undefined;

			}

			if ( kind === 'arcball' && ! [ 'setMouseAction', 'unsetMouseAction' ].includes( method ) ) {

				ctrl[ method ]( ...args );
				return undefined;

			}

			if ( kind === 'transform' && method !== 'getMode' ) {

				ctrl[ method ]( ...args );
				return undefined;

			}

			return norm( ctrl[ method ]( ...args ) );

		},
		get( ctrl, kind, path ) {

			return getPath( ctrl, path );

		},
	};

}
