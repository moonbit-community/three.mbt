# Regenerates mbt/harness/harness.mbt (from harness.tpl) and keys.json from the Material
# struct in src/core/types_materials.mbt. run.sh runs it before every build.
import re,json,os
HERE=os.path.dirname(os.path.abspath(__file__))
REPO=os.path.normpath(os.path.join(HERE,'../../..'))
types=open(os.path.join(REPO,'src/core/types_materials.mbt')).read()
body=types[types.index('pub(all) struct Material {'):]
fields=[(n,t.strip()) for n,t in re.findall(r'^\s+(?:mut )?(\w+) : ([^\n(]+|\($)',body,re.M)]
def camel(n):
    sp={'iridescence_ior':'iridescenceIOR','index0_attribute_name':'index0AttributeName','_alpha_test':'alphaTest','type_':'type'}
    if n in sp: return sp[n]
    n=n.lstrip('_'); p=n.split('_')
    return p[0]+''.join(x.capitalize() for x in p[1:])
skip={'id','dispatcher','material_type','extension','uuid','on_before_render','on_before_compile','custom_program_cache_key'}
lines=[];keys=[]
for n,t in fields:
    if n in skip: continue
    k=camel(n); keys.append(k)
    acc=f'm.{n}'
    if n=='reflectivity': acc='m.reflectivity()'
    conv={'Int32':'jint','Double':'jnum','Bool':'Json::boolean','String':'Json::string','Int32?':'ojint','Double?':'ojnum','Bool?':'ojbool','String?':'ojstr',
     '@math.Color':'jcolor','@math.Color?':'ojcolor','@math.Vector2?':'ojv2','@math.Euler?':'ojeuler','Texture?':'ojtex','Array[@math.Plane]?':'ojplanes',
     'Map[String, Json]?':'ojdefines','Map[String, Uniform]?':'ojuniforms','Array[UniformsGroup]?':'ojgroups','ShaderExtensions?':'ojext','Map[String, Array[Double]]?':'ojattrs','JsValue':'juser'}
    conv={a.replace('Uniform]','@core.Uniform]').replace('UniformsGroup]','@core.UniformsGroup]'):b for a,b in conv.items()}
    t2=t
    if t not in {x.replace('@core.','') for x in conv}: raise Exception(t)
    f={x.replace('@core.',''):y for x,y in conv.items()}[t]
    lines.append(f'  o["{k}"] = {f}({acc})')
json.dump(keys,open(os.path.join(HERE,'keys.json'),'w'))
tpl=open(os.path.join(HERE,'harness.tpl')).read().replace('@@DUMP@@','\n'.join(lines))
out=os.path.join(HERE,'mbt/harness/harness.mbt')
old=open(out).read() if os.path.exists(out) else None
if old!=tpl: open(out,'w').write(tpl)
