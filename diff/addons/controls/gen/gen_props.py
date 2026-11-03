# Generates the TransformControls property plumbing (upstream's defineProperty).
import re
props = [
 ('camera','obj'),('object','optobj'),('enabled','bool'),('axis','optstr'),('mode','str'),
 ('translationSnap','optnum'),('rotationSnap','optnum'),('scaleSnap','optnum'),('space','str'),('size','num'),
 ('dragging','bool'),('showX','bool'),('showY','bool'),('showZ','bool'),('showXY','bool'),('showYZ','bool'),
 ('showXZ','bool'),('showXYZE','bool'),('showE','bool'),('minX','num'),('maxX','num'),('minY','num'),('maxY','num'),
 ('minZ','num'),('maxZ','num'),('worldPosition','vec3'),('worldPositionStart','vec3'),('worldQuaternion','quat'),
 ('worldQuaternionStart','quat'),('cameraPosition','vec3'),('cameraQuaternion','quat'),('pointStart','vec3'),
 ('pointEnd','vec3'),('rotationAxis','vec3'),('rotationAngle','num'),('eye','vec3'),
]
def snake(n):
    s = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', n)
    s = re.sub(r'([A-Z])([A-Z])', r'\1_\2', s) if False else s
    return s.lower()
names = {'showXY':'show_xy','showYZ':'show_yz','showXZ':'show_xz','showXYZE':'show_xyze','showE':'show_e','showX':'show_x','showY':'show_y','showZ':'show_z'}
ty = {'obj':'@core.Object3D','optobj':'@core.Object3D?','bool':'Bool','optstr':'String?','str':'String','optnum':'Double?','num':'Double','vec3':'@math.Vector3','quat':'@math.Quaternion'}
out = []
# state struct
out.append('///|\n/// The properties `TransformControls` passes down to its gizmo and plane (upstream\'s\n/// `defineProperty`); `camera` is `None` for a gizmo or plane made on its own.\npub(all) struct TransformControlsState {')
for n,k in props:
    f = names.get(n, snake(n))
    t = '@core.Object3D?' if n=='camera' else ty[k]
    out.append(f'  mut {f} : {t}')
out.append('}\n')
# copy into state
out.append('///|\n/// `plane[ propName ] = value; gizmo[ propName ] = value` for every property.\nfn TransformControls::_copy_props_to(self : TransformControls, state : TransformControlsState) -> Unit {')
for n,k in props:
    f = names.get(n, snake(n))
    v = f'Some(self.{f})' if n=='camera' else f'self.{f}'
    out.append(f'  state.{f} = {v}')
out.append('}\n')
# setters
def jsval(k, v):
    return {'obj':f'@core.JsValue::of({v})','optobj':f'match {v} {{ Some(v) => @core.JsValue::of(v); None => @core.JsValue::undefined() }}',
            'bool':f'@core.JsValue::of({v})','str':f'@core.JsValue::of({v})','num':f'@core.JsValue::of({v})',
            'optstr':f'match {v} {{ Some(v) => @core.JsValue::of(v); None => @core.JsValue::null() }}',
            'optnum':f'match {v} {{ Some(v) => @core.JsValue::of(v); None => @core.JsValue::null() }}',
            'vec3':f'@core.JsValue::of({v})','quat':f'@core.JsValue::of({v})'}[k]
def neq(k, a, b):
    if k in ('obj','vec3','quat'): return f'!physical_equal({a}, {b})'
    if k == 'optobj': return f'!transform_same_object({a}, {b})'
    return f'{a} != {b}'
skip_doc = {'mode':'`setMode( mode )`: `"translate"`, `"rotate"` or `"scale"`.','space':'`setSpace( space )`: `"world"` or `"local"`.',
  'size':'`setSize( size )`.','translationSnap':'`setTranslationSnap( snap )`.','rotationSnap':'`setRotationSnap( snap )`.','scaleSnap':'`setScaleSnap( snap )`.'}
for n,k in props:
    f = names.get(n, snake(n))
    doc = skip_doc.get(n, f'`controls.{n} = value`; fires `{n}-changed` and `change` when it changes.')
    extra = '    self.base.enabled = value\n' if n=='enabled' else ''
    pv = 'Some(value)' if n=='camera' else 'value'
    out.append(f'''///|
/// {doc}
pub fn TransformControls::set_{f}(self : TransformControls, value : {ty[k]}) -> Unit {{
  if {neq(k, f'self.{f}', 'value')} {{
    self.{f} = value
{extra}    self._plane_state.{f} = {pv}
    self._gizmo_state.{f} = {pv}
    self.dispatch_event(
      @core.Event::new("{n}-changed", data={jsval(k, 'value')}),
    )
    self.dispatch_event(_transform_change_event)
  }}
}}
''')
import os, sys; sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))
from lib.env import out_dir
OUTD = out_dir('addons_controls', 'gen')
open(OUTD / 'props.mbt','w').write('\n'.join(out))
# struct field lines for TransformControls
open(OUTD / 'fields.txt','w').write('\n'.join(f"  mut {names.get(n, snake(n))} : {ty[k]}" for n,k in props))
