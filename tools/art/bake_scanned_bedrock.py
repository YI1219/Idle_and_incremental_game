"""One closed CC0 scan-derived mass in ordinary editable terrain density."""
import bpy
import bmesh
import hashlib
import json
import sys
from array import array
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'art/work/exposed_bedrock/2026-10-17'
OUT=ROOT/'art/work/polyhaven_rocks/2026-10-17'
VERSION=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'v1'
assert VERSION in ['v1','v2','v3','single','replace','fitcap']
source_path=OUT/('boulder_01/boulder_01_study_4k.blend' if VERSION in ['single','replace','fitcap'] else 'namaqualand_boulder_02/namaqualand_boulder_02_closed_study.blend')
bpy.ops.wm.open_mainfile(filepath=str(source_path))
obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
bm=bmesh.new();bm.from_mesh(obj.data)
low=Vector([min(v.co[k] for v in bm.verts) for k in range(3)])
high=Vector([max(v.co[k] for v in bm.verts) for k in range(3)])
center=(low+high)*.5;size=high-low
def rigid(p):
    q=(p-center)*3.0
    return Vector((q.x,.894427191*q.y-.447213595*q.z,.447213595*q.y+.894427191*q.z))
cap_fit={}
if VERSION=='fitcap':
    y_bias=4.1-max(rigid(v.co).y for v in bm.verts)
    cap_points=[]
    for edge in bm.edges:
        a,b=[rigid(v.co)+Vector((0,y_bias,0)) for v in edge.verts]
        if (a.y-3.5)*(b.y-3.5)<0:cap_points.append(a.lerp(b,(3.5-a.y)/(b.y-a.y)))
    assert len(cap_points)>=3
    out_bias=.45-max(p.z for p in cap_points)
    cap_fit=dict(y_bias=y_bias,out_bias=out_bias,along_min=min(p.x for p in cap_points),along_max=max(p.x for p in cap_points),cap_front=.45)
for vertex in bm.verts:
    p=vertex.co.copy()
    x=-14.5+p.x*4.2;y=3.5-(p.z-.10)*5.3
    z=3.3+.40*(x+14.5)-p.y*3.0-(1.15 if VERSION=='v1' else 0.0)+.40*(y-3.5)
    if VERSION=='v3':
        # Preserve the scan's upright geological shoulders. The earlier
        # inversion turned its real top slopes into hanging ledges.
        y=-1.3+(p.z-.10)*7.0
        depth=max(0,3.5-y)
        z=3.3+.40*(x+14.5)-p.y*3.0+.8-.75*depth-.80*(depth/5.0)**3
    if VERSION in ['single','replace']:
        u=(p.x-center.x)/size.x*3.8;v=-(p.y-center.y)/size.y*3.6
        y=(1.8 if VERSION=='replace' else .9)+(p.z-center.z)/size.z*5.4
        depth=3.5-y;out=v-.5-.50*depth
        x=-15.62+.94*u-.342*out;z=3.94+.342*u+.94*out
    if VERSION=='fitcap':
        q=rigid(p);y=q.y+y_bias;out=q.z+out_bias
        x=-15.62+.94*q.x-.342*out;z=3.94+.342*q.x+.94*out
    vertex.co=Vector((x,y,z))
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
if bm.calc_volume(signed=True)<0:bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
bm.normal_update();assert all(e.is_manifold for e in bm.edges)
tree=BVHTree.FromBMesh(bm,epsilon=0)
lower=Vector([min(v.co[k] for v in bm.verts) for k in range(3)])
upper=Vector([max(v.co[k] for v in bm.verts) for k in range(3)])
bm.to_mesh(obj.data);bm.free();obj.data.update();obj.name='ClosedScan_EditableStudy_GodotYUp'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'scanned_bedrock_world_{VERSION}.blend'))
source=json.loads((BASE/'source.json').read_text());payload=json.loads((BASE/'base_save.json').read_text())
lo,hi,step=source['lo'],source['hi'],source['step'];nx,ny,nz=[hi[k]-lo[k]+1 for k in range(3)]
nodes=array('f');nodes.frombytes((BASE/'base_nodes.bin').read_bytes())
columns=array('f');columns.frombytes((BASE/'base_columns.bin').read_bytes())
assert len(nodes)==nx*ny*nz
rays=[Vector(v).normalized() for v in [(.8731,.3817,.3039),(-.429,.791,.436),(.265,-.413,.872)]]
def distance(p):
    if any(p[k]<lower[k]-.6 or p[k]>upper[k]+.6 for k in range(3)):return .5
    nearest=tree.find_nearest(p);assert nearest[0] is not None
    votes=0
    for ray in rays:
        origin=p+ray*1e-7;hits=0
        for _ in range(64):
            hit=tree.ray_cast(origin,ray,100)
            if hit[0] is None:break
            hits+=1;origin=hit[0]+ray*.00001
        else:raise RuntimeError('Unbounded parity traversal')
        votes+=hits%2
    return -nearest[3] if votes>=2 else nearest[3]
def ease(a,b,v):
    t=max(0,min(1,(v-a)/(b-a)));return t*t*(3-2*t)
records=[]
back_cache={}
for iz in range(nz):
    z=(lo[2]+iz)*step
    for ix in range(nx):
        x=(lo[0]+ix)*step
        weight=ease(-21,-19.3,x)*(1-ease(-10,-8.2,x))*ease(-2.8,-.5,z)*(1-ease(6.8,8.7,z))
        if VERSION in ['replace','fitcap']:
            along=(x+15.62)*.94+(z-3.94)*.342
            weight*=ease(-3,-1.6,along)*(1-ease(1.6,3,along))
        if weight<=0:continue
        column=(iz*nx+ix)*(len(source['levels'])+1);height=columns[column];d=columns[column+1]
        if d< -6 or d>2:continue
        retreat=0.0
        if VERSION=='fitcap':
            along=(x+15.62)*.94+(z-3.94)*.342
            key=round(along,5)
            if key not in back_cache:
                origin=Vector((-15.62+.94*along+3.42,3.499,3.94+.342*along-9.4))
                hit=tree.ray_cast(origin,Vector((-.342,0,.94)),20)
                back_cache[key]=max(0,-((hit[0].x+15.62)*(-.342)+(hit[0].z-3.94)*.94)) if hit[0] is not None else 0.0
            retreat=back_cache[key]*ease(cap_fit['along_min'],cap_fit['along_min']+.35,along)*(1-ease(cap_fit['along_max']-.35,cap_fit['along_max'],along))
        for iy in range(ny):
            y=(lo[1]+iy)*step;index=(iz*ny+iy)*nx+ix;old=nodes[index]
            depth=max(0,height-y)
            behind=old if VERSION in ['v3','single','replace','fitcap'] else max(old,d+max(0,depth-.35)*.95)
            if VERSION=='replace':
                inset=max(0,depth-1.4)*.55+1.25*(1-ease(3,5.5,depth))
                behind=max(old,d+inset)
            if VERSION=='fitcap':behind=max(old,d+max(0,depth-1.4)*.55+retreat*(1-ease(3,5.5,depth)))
            stone=distance(Vector((x,y,z)))
            candidate=min(behind,stone)
            if VERSION in ['replace','fitcap']:
                radius=.45*ease(1.8,4.0,depth)
                if radius>.00001:
                    t=max(0,min(1,.5+.5*(stone-behind)/radius))
                    candidate=stone*(1-t)+behind*t-radius*t*(1-t)
            # Only preserve the original dry footprint at the cap itself;
            # real source shoulders/clefts continue below it in all three axes.
            cap=min(max(columns[column+1+k]-.02-1.5*ease(0,.6,depth),y-h) for k,h in enumerate(source['levels']))
            if VERSION not in ['v3','single','replace','fitcap']:candidate=max(candidate,cap)
            value=round(old*(1-weight)+max(-.5,min(.5,candidate))*weight,5)
            if abs(value-old)<.000001:continue
            if abs(value)<.002:value=.002 if value>=0 else -.002
            records.append(dict(x=lo[0]+ix,y=lo[1]+iy,z=lo[2]+iz,density=value))
payload['rocks']=records;save=OUT/f'scanned_bedrock_{VERSION}.json';save.write_text(json.dumps(payload,separators=(',',':'))+'\n')
report=dict(source=str(source_path.relative_to(ROOT)),source_sha256=hashlib.sha256(source_path.read_bytes()).hexdigest(),
    samples=len(records),world_lower=list(lower),world_upper=list(upper),save_sha256=hashlib.sha256(save.read_bytes()).hexdigest(),version=VERSION,
    outward_correction=-.5 if VERSION in ['single','replace'] else (.8 if VERSION=='v3' else (0.0 if VERSION=='v1' else 1.15)),
    operation=('One closed Boulder01 source, centerY1.8 and same3.8x5.4x3.6m fit. Original base/cap recedes1.25m within one six-metre tangent strip; extra recession fades out by5.5m depth. Source actual cross-section controls local rim; .45m lower-only union, no cap clipping. Cell records unchanged, actual local ground edge intentionally changes.' if VERSION=='replace' else ('One already-closed Boulder01 source:3.8m tangent width,5.4m height,3.6m depth, centerY.9; fit along actual edge with .5m inward center setback and .5m/m lower inward shear. Hard union into unchanged base, no cap clipping or core recession.' if VERSION=='single' else ('Upright closed source, .8m upper exposure and inward lower return into the unchanged original base. No cap clipping or core recession; upper geological shoulders retain source orientation. Three-ray parity distance and hard union.' if VERSION=='v3' else 'One closed source-derived rock mass inverted under its repaired flat base, affine fit/shear along the actual front-left edge; source outer shape retained. Three-ray parity distance; hard union with a locally receded derived base; original cap footprint guard. Ordinary saved density only.'))),
    stage='Unaccepted small cap/adjacent-face/lower-return study. No automatic runtime rock assembly, new player brush or default promotion.')
if VERSION=='fitcap':
    report['cap_fit']=cap_fit
    report['outward_correction']=out_bias
    report['operation']='Source01 true proportions: uniform3x scale and rigid long-axis rotation, highest point4.1m. Actual3D cap cross-section front aligned.45m outside edge; BVH cap-back intersections determine local ground recession, fading into original lower body. No anisotropic stretch or arbitrary ground-gap width. Lower-only .45m union; ordinary saved density.'
(OUT/f'scanned_bedrock_report_{VERSION}.json').write_text(json.dumps(report,indent=2)+'\n')
print('SCANNED BEDROCK BAKE:',json.dumps(report))
