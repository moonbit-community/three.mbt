#!/usr/bin/env python3
# Transliterates test/unit/src/extras/curves/*.tests.js to src/extras/*_test.mbt (the
# generator of those committed tests; it overwrites them, then `moonfmt -w` them).
import re, sys, pathlib
sys.path.insert(0, str(next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'lib/env.py').exists())))
from lib.env import REPO, UPSTREAM  # noqa: E402
UP=str(UPSTREAM / 'test/unit/src/extras/curves') + '/'
OUT=str(REPO / 'src/extras') + '/'
FILES={'LineCurve':'line_curve','LineCurve3':'line_curve3','QuadraticBezierCurve':'quadratic_bezier_curve','QuadraticBezierCurve3':'quadratic_bezier_curve3',
 'CubicBezierCurve':'cubic_bezier_curve','CubicBezierCurve3':'cubic_bezier_curve3','EllipseCurve':'ellipse_curve','SplineCurve':'spline_curve','CatmullRomCurve3':'catmull_rom_curve3','ArcCurve':'arc_curve'}
KIND={'LineCurve':'Line','LineCurve3':'Line','QuadraticBezierCurve':'QuadraticBezier','QuadraticBezierCurve3':'QuadraticBezier','CubicBezierCurve':'CubicBezier','CubicBezierCurve3':'CubicBezier','EllipseCurve':'Ellipse','ArcCurve':'Ellipse','SplineCurve':'Spline','CatmullRomCurve3':'CatmullRom'}
def dbl(tok):
    tok=tok.strip()
    if re.fullmatch(r'\d+',tok): return tok+'.0'
    m=re.fullmatch(r'(\d+)(e[-+]?\d+)',tok)
    if m: return m.group(1)+'.0'+m.group(2)
    return tok
def num_expr(e):
    e=e.strip()
    # Math.sqrt( a ), possibly nested in a product
    e=re.sub(r'Math\.PI','test_pi()',e)
    e=re.sub(r'Math\.sqrt\(\s*([^()]*?)\s*\)',lambda m:'('+num_expr(m.group(1))+').sqrt()',e)
    e=re.sub(r'-\s+(?=[\d(])','-',e)
    e=re.sub(r'(?<![\w.])(\d+(?:\.\d+)?(?:e[-+]?\d+)?)(?![\w.]*\()',lambda m:dbl(m.group(1)),e)
    return e
def split_args(s):
    out=[];d=0;cur=''
    for c in s:
        if c in '([': d+=1
        if c in ')]': d-=1
        if c==',' and d==0: out.append(cur);cur=''
        else: cur+=c
    if cur.strip(): out.append(cur)
    return out
def vec_ctor(m):
    args=[num_expr(a) for a in split_args(m.group(2))]
    n=m.group(1)
    if not args: args=['0.0']*int(n)
    return ('vec2(' if n=='2' else 'vec3(')+', '.join(args)+')'
def conv_expr(l):
    l=re.sub(r'new Vector([23])\(\s*((?:[^()]|\([^()]*\)|\((?:[^()]|\([^()]*\))*\))*?)\s*\)',vec_ctor,l)
    return l
def conv_call(l):
    l=l.replace('expectedPoints','expected_points').replace('expectedTangents','expected_tangents').replace('expectedLengths','expected_lengths').replace('expectedLength','expected_length').replace('expectedSomewhere','expected_somewhere').replace('expectedTangent','expected_tangent').replace('curveRev','curve_rev')
    l=re.sub(r'\.length\b(?!\()','.length()',l)
    l=re.sub(r'\.reverse\(\)','.rev()',l)
    l=re.sub(r'\.getPoints\(\s*\)','.get_points()',l)
    l=re.sub(r'\.getPoints\(\s*(.*?)\s*\)(?=;|$| \)|,)',lambda m:'.get_points(divisions='+m.group(1)+')',l)
    l=re.sub(r'\.getSpacedPoints\(\s*\)','.get_spaced_points()',l)
    l=re.sub(r'\.getSpacedPoints\(\s*(.*?)\s*\)(?=;|$| \)|,)',lambda m:'.get_spaced_points(divisions='+m.group(1)+')',l)
    l=re.sub(r'\.getLengths\(\s*(.*?)\s*\)(?=;|$| \)|,)',lambda m:'.get_lengths(divisions='+m.group(1)+')',l)
    l=l.replace('.getLength()','.get_length()')
    def tgt(name):
        def f(m):
            return '.%s(%s, optional_target=%s)'%(name,num_expr(m.group(1)),m.group(2))
        return f
    for js,mb in (('getPointAt','get_point_at'),('getPoint','get_point'),('getTangentAt','get_tangent_at'),('getTangent','get_tangent')):
        l=re.sub(r'\.'+js+r'\(\s*([^,()]+?),\s*(vec[23]\([^()]*\)|\w+)\s*\)',tgt(mb),l)
        l=re.sub(r'\.'+js+r'\(\s*([^,()]+?)\s*\)',lambda m,mb=mb:'.%s(%s)'%(mb,num_expr(m.group(1))),l)
    l=re.sub(r'\.getUtoTmapping\(\s*([^,]+?),\s*(.+?)\s*\)(?=;|$)',lambda m:'.get_uto_tmapping(%s, distance=%s)'%(num_expr(m.group(1)),num_expr(m.group(2))),l)
    l=re.sub(r'\.computeFrenetFrames\(\s*(\d+),\s*false\s*\)',lambda m:'.compute_frenet_frames(%s, closed=false)'%m.group(1),l)
    return l
CTOR_LABELS={'LineCurve':['v1','v2'],'LineCurve3':['v1','v2'],'QuadraticBezierCurve':['v0','v1','v2'],'QuadraticBezierCurve3':['v0','v1','v2'],'CubicBezierCurve':['v0','v1','v2','v3'],'CubicBezierCurve3':['v0','v1','v2','v3'],'EllipseCurve':['a_x','a_y','x_radius','y_radius','a_start_angle','a_end_angle','a_clockwise','a_rotation'],'SplineCurve':['points'],'CatmullRomCurve3':['points','closed','curve_type','tension']}
def ctor(cls,args):
    a=split_args(args); ls=CTOR_LABELS[cls]
    out=[]
    for i,x in enumerate(a):
        x=x.strip()
        x=re.sub(r'^\[\s*','[',x)
        if ls[i] in ('a_x','a_y','x_radius','y_radius','a_start_angle','a_end_angle','a_rotation','tension'): x=num_expr(x)
        if x in ('_points[ 0 ]','_points[ 1 ]','_points[ 2 ]','_points[ 3 ]'): x=x.replace('[ ','[').replace(' ]',']')
        x=x.replace("'",'"')
        out.append('%s=%s'%(ls[i],x))
    return cls+'::new('+', '.join(out)+')'
def body(cls,src,fix):
    t=src
    # forEach blocks become helper calls
    t=re.sub(r'points\.forEach\( function \( point, i \) \{.*?\n\t\t\t\t\} \);','assert_num_points(points, expected_points);',t,flags=re.S)
    t=re.sub(r'expectedPoints\.forEach\( function \( exp, i \) \{.*?\n\t\t\t\t\} \);','assert_num_points(points, expected_points);',t,flags=re.S)
    t=re.sub(r'expectedTangents\.forEach\( function \( exp, i \) \{.*?\n\t\t\t\t\} \);','assert_num_points(tangents, expected_tangents);',t,flags=re.S)
    t=re.sub(r'tangents\.forEach\( function \( tangent, i \) \{.*?\n\t\t\t\t\} \);','assert_num_points(tangents, expected_tangent);',t,flags=re.S)
    t=re.sub(r'lengths\.forEach\( function \( segment, i \) \{.*?\n\t\t\t\t\} \);','assert_num_list(lengths, expected_lengths);',t,flags=re.S)
    t=re.sub(r'Object\.keys\( expected \)\.forEach\(.*?\n\t\t\t\t\} \);','assert_frames(frames, expected);',t,flags=re.S)
    t=re.sub(r'for \( const val in expected \) \{.*?\n\t\t\t\t\}','assert_num_points([frames.tangents[0]], expected.tangents);\nassert_num_points([frames.normals[0]], expected.normals);\nassert_num_points([frames.binormals[0]], expected.binormals);',t,flags=re.S)
    t=re.sub(r'testValues\.forEach\( function \( val \) \{.*?\n\t\t\t\t\} \);','__ELLIPSE_VALUES__',t,flags=re.S)
    # frenet literals
    t=re.sub(r'const expected = \{\s*binormals: \[(.*?)\],\s*normals: \[(.*?)\],\s*tangents: \[(.*?)\]\s*\};',lambda m:'let expected = FrenetFrames::{ binormals: [%s], normals: [%s], tangents: [%s] };'%(m.group(1),m.group(2),m.group(3)),t,flags=re.S)
    t=re.sub(r'const expected = \{\s*binormals: (new Vector3\(.*?\)),\s*normals: (new Vector3\(.*?\)),\s*tangents: (new Vector3\(.*?\))\s*\};',lambda m:'let expected = FrenetFrames::{ binormals: [%s], normals: [%s], tangents: [%s] };'%m.groups(),t,flags=re.S)
    t=re.sub(r'//.*','',t)
    t=conv_expr(t)
    # statements
    t=re.sub(r"(assert\.\w+)\(\s*(.*?),\s*'[^']*'\s*\);",lambda m:m.group(1)+'('+m.group(2)+');',t,flags=re.S)
    t=re.sub(r"assert\.numEqual\(\s*(.*?)\s*,\s*'[^']*' \+.*?\);",lambda m:'assert.numEqual('+m.group(1)+');',t)
    out=[]
    for st in t.split('\n'):
        out.append(st)
    t='\n'.join(out)
    t=re.sub(r'(?m)^\s*const curve = _curve;\s*$','',t)
    t=re.sub(r'(?m)^\s*let curve = _curve;\s*$','let mut curve = __FIX__;',t)
    t=re.sub(r'(?m)^\s*let tangent = vec3\(0.0, 0.0, 0.0\);$','let mut tangent = vec3(0.0, 0.0, 0.0);',t)
    t=re.sub(r'const (\w+) =',lambda m:'let '+snake(m.group(1))+' =',t)
    t=re.sub(r'let (expectedPoints|expectedTangents|points|tangents) =',lambda m:'let mut '+snake(m.group(1))+' =',t)
    def cv(m):
        return ctor(m.group(1),m.group(2))
    t=re.sub(r'new ('+'|'.join(CTOR_LABELS)+r')\(\s*((?:[^()\[\]]|\[(?:[^\[\]]|\((?:[^()]|\([^()]*\))*\))*\]|\((?:[^()]|\([^()]*\))*\))*?)\s*\)',lambda m:cv(m) if m.group(2).strip() else m.group(1)+'::new()',t,flags=re.S)
    t=conv_call(t)
    t=t.replace('_curve','__FIX__')
    t=re.sub(r'\bcurve\.curveType = \'(\w+)\';','set_curve_type(curve, "\\1");',t)
    t=re.sub(r'\bcurve\.closed = true;','set_closed(curve, true);',t)
    t=re.sub(r'assert\.strictEqual\(\s*(.*?),\s*(.*?)\s*\);',lambda m:'assert_eq(%s, %s);'%(m.group(1),num_lit(m.group(2))),t)
    t=re.sub(r'assert\.numEqual\(\s*(.*?),\s*(.*?)\s*\);',lambda m:'assert_num(%s, %s);'%(m.group(1),num_expr(m.group(2))),t)
    t=re.sub(r'assert\.deepEqual\(\s*points,\s*(.*?)\s*\);',lambda m:'assert_exact_points(points, %s);'%m.group(1),t,flags=re.S)
    t=re.sub(r'assert\.deepEqual\(\s*lengths,\s*(.*?)\s*\);',lambda m:'assert_exact_list(lengths, %s);'%m.group(1),t)
    t=re.sub(r'assert\.equal\(\s*(.*?),\s*(.*?)\s*\);',lambda m:'assert_eq(%s, %s);'%(m.group(1),m.group(2)),t)
    t=re.sub(r'assert\.ok\(\s*(.*?)\s*\);',lambda m:'assert_true(%s);'%m.group(1),t)
    t=re.sub(r'curve\.points\[\s*(\d)\s*\]','spline_points(curve)[\\1]',t)
    t=t.replace('curve.points','spline_points(curve)')
    t=re.sub(r'(\w+)::new\(v0=curve\.v(\d), v1=curve\.v(\d), v2=curve\.v(\d), v3=curve\.v(\d)\)',lambda m:'%s::new(v0=cubic_v(curve, %s), v1=cubic_v(curve, %s), v2=cubic_v(curve, %s), v3=cubic_v(curve, %s))'%m.groups(),t)
    t=re.sub(r'(\w+)::new\(v0=curve\.v(\d), v1=curve\.v(\d), v2=curve\.v(\d)\)',lambda m:'%s::new(v0=quadratic_v(curve, %s), v1=quadratic_v(curve, %s), v2=quadratic_v(curve, %s))'%m.groups(),t)
    t=t.replace('__ELLIPSE_VALUES__','''for val in test_values {
  let expected_x = @cmath.cos(val * test_pi() * 2.0) * 10.0
  let expected_y = @cmath.sin(val * test_pi() * 2.0) * 10.0
  ignore(curve.get_point(val, optional_target=p))
  ignore(curve.get_point_at(val, optional_target=a))
  assert_num(p.x, expected_x)
  assert_num(p.y, expected_y)
  assert_num(a.x, expected_x)
  assert_num(a.y, expected_y)
}''')
    t=t.replace('let test_values = [ 0, 0.3, 0.5, 0.7, 1 ];','let test_values = [0.0, 0.3, 0.5, 0.7, 1.0];')
    t=t.replace('let p = vec2(0.0, 0.0);','let p = vec2(0.0, 0.0);')
    t=re.sub(r'\[\s*0\.0,','[0.0,',t)
    t=re.sub(r'let expected_lengths = \[(.*?)\];',lambda m:'let expected_lengths : Array[Double] = ['+', '.join(num_expr(x) for x in split_args(m.group(1)))+'];',t,flags=re.S)
    t=t.replace('__FIX__','curve')
    t=re.sub(r'Math\.sqrt\(\s*([^()]*?)\s*\)',lambda m:'('+num_expr(m.group(1))+').sqrt()',t)
    t=re.sub(r'(?m)^(\s*)(curve\.get_\w+\(.*\));?\s*$',lambda m:m.group(0) if 'optional_target=vec' in m.group(2) else m.group(1)+'ignore('+m.group(2)+')',t)
    for v in ('points','tangents','expected_points','expected_tangents'):
        if not re.search(r'(?m)^\s*'+v+r' =',t): t=t.replace('let mut '+v+' =','let '+v+' =')
    if not re.search(r'(?m)^\s*curve =',t): t=t.replace('let mut curve =','let curve =')
    t=t.replace('});','})')
    t=re.sub(r';\s*$','',t,flags=re.M)
    t=re.sub(r'^\s*let\s*$','',t,flags=re.M)
    return t
def num_lit(s):
    s=s.strip()
    if re.fullmatch(r'-?\s*\d+(\.\d+)?',s) : return '__N__'+s
    return s
def snake(s): return re.sub(r'([A-Z])',lambda m:'_'+m.group(1).lower(),s)
def gen(cls,mb):
    src=open(UP+cls+'.tests.js').read()
    fix=None
    m=re.search(r'hooks\.before\( function \(\) \{(.*?)\n\t\t\t\} \);',src,re.S)
    head=m.group(1) if m else ''
    dims='3' if cls.endswith('3') else '2'
    # fixture
    pts=re.search(r'_points = \[(.*?)\];',head,re.S)
    pts=conv_expr(pts.group(1)) if pts else None
    cur=re.search(r'(?:_curve|curve) = new (\w+)\(\s*(.*?)\s*\);\s*$',head,re.S|re.M)
    if cls=='CatmullRomCurve3':
        pos=re.search(r'const positions = \[(.*?)\];',src,re.S).group(1)
        pts=None
    out=['// Port of upstream test/unit/src/extras/curves/%s.tests.js.\n'%cls]
    tests=re.findall(r"QUnit\.test\( '([^']+)', \( assert \) => \{(.*?)\n\t\t\t\} \);",src,re.S)
    if pts:
        out.append('///|\nfn %s_points() -> Array[@math.Vector%s] {\n  [%s]\n}\n'%(mb,dims,pts))
    if cur:
        a=conv_expr(cur.group(2))
        a=re.sub(r'_points\[ (\d) \]',lambda m:'%s_points()[%s]'%(mb,m.group(1)),a)
        c=ctor(cls,a) if cls!='EllipseCurve' else 'EllipseCurve::new(a_x=0.0, a_y=0.0, x_radius=10.0, y_radius=10.0, a_start_angle=0.0, a_end_angle=2.0 * test_pi(), a_clockwise=false, a_rotation=0.0)'
        out.append('///|\nfn %s_curve() -> @extras.Curve[@math.Vector%s] {\n  @extras.%s\n}\n'%(mb,dims,c))
    if cls=='CatmullRomCurve3':
        out.append('///|\nfn catmull_positions() -> Array[@math.Vector3] {\n  [%s]\n}\n'%conv_expr(pos))
    for name,b in tests:
        if name=='Extending':
            out.append('///|\ntest "%s extends Curve" {\n  let object : @extras.Curve[@math.Vector%s] = @extras.%s::new()\n  ignore(object)\n}\n'%(cls,dims,cls)); continue
        if name=='Instancing':
            if cls=='ArcCurve': pass
            out.append('///|\ntest "%s instancing" {\n  ignore(@extras.%s::new())\n}\n'%(cls,cls)); continue
        if name=='type':
            out.append('///|\ntest "%s type" {\n  assert_eq(@extras.%s::new().type_, "%s")\n}\n'%(cls,cls,cls)); continue
        if name.startswith('is'):
            out.append('///|\ntest "%s %s" {\n  assert_true(@extras.%s::new().kind is %s(_))\n}\n'%(cls,name,cls,KIND[cls])); continue
        t=body(cls,b,None)
        # names
        t=t.replace('positions','catmull_positions()')
        t=re.sub(r'\b_points\[(\d)\]',lambda m:'%s_points()[%s]'%(mb,m.group(1)),t)
        t=re.sub(r'\b_points\[ (\d) \]',lambda m:'%s_points()[%s]'%(mb,m.group(1)),t)
        for k in CTOR_LABELS: t=re.sub(r'(?<![\w.])'+k+'::new','@extras.'+k+'::new',t)
        t=t.replace('FrenetFrames::{','@extras.FrenetFrames::{')
        pre=''
        if cur and not re.search(r'let (mut )?curve =',t): pre='let curve = %s_curve()\n'%mb
        if cur: t=re.sub(r'let mut curve = curve$','let mut curve = %s_curve()'%mb,t,flags=re.M)
        t=re.sub(r'__N__(-?\s*\d+)',lambda m:num_context(t,m),t)
        out.append('///|\ntest "%s %s" {\n%s%s\n}\n'%(cls,name,pre,t))
    return '\n'.join(out)
def num_context(t,m):
    return m.group(1)
if __name__=='__main__':
    for cls,mb in FILES.items():
        s=gen(cls,mb)
        s=re.sub(r'assert_eq\((start|end), (\d+)\)',lambda m:'assert_eq(%s, %s.0)'%(m.group(1),m.group(2)),s)
        s=re.sub(r'assert_true\(curve\.get_point_at\(([\d.]+), optional_target=point\)\.equals\(',lambda m:'assert_true(curve.get_point_at(%s, optional_target=point).equals('%m.group(1),s)
        open(OUT+mb+'_test.mbt','w').write(s)
