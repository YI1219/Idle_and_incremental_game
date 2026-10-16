"""Replace a bounded old side by the actual existing crown front sections.

Tool-only volume spike: no source stretch, new official geometry or assembly
system. The visible side, cap and return share one sampled front envelope.
"""
import bpy
import bmesh
import hashlib
import json
import math
import sys
from array import array
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'art/work/exposed_bedrock/2026-10-17'
OUT=ROOT/'art/work/cliff_face_replacement/2026-10-17'
OUT.mkdir(parents=True,exist_ok=True)
VERSION=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'v1'
assert VERSION in ['v1','v2','scan','scan2','scan3','scan4','scan5','scan6']
IS_SCAN=VERSION.startswith('scan')
source=json.loads((ROOT/'art/work/cliff_volume/2026-10-16/source.json').read_text())
grid=json.loads((BASE/'source.json').read_text())
payload=json.loads((BASE/'base_save.json').read_text())
lo,hi,step=grid['lo'],grid['hi'],grid['step']
nx,ny,nz=[hi[k]-lo[k]+1 for k in range(3)]
nodes=array('f');nodes.frombytes((BASE/'base_nodes.bin').read_bytes())
columns=array('f');columns.frombytes((BASE/'base_columns.bin').read_bytes())
assert len(nodes)==nx*ny*nz
bpy.ops.wm.read_factory_settings(use_empty=True)
trees=[]
for index,crown in enumerate(source['crowns']):
    points=crown['world_faces'];mesh=bpy.data.meshes.new(crown['kind'])
    mesh.from_pydata(points,[],[(i,i+2,i+1) for i in range(0,len(points),3)])
    bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges)
    trees.append(BVHTree.FromBMesh(bm,epsilon=0))
    bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(f'OriginalCrown_{index}_GodotYUp',mesh)
    bpy.context.collection.objects.link(obj)
scan_source=None
if IS_SCAN:
    scan_source=ROOT/'art/work/polyhaven_rocks/2026-10-17/rock_face_02/rock_face_02_study_4k.blend'
    bpy.ops.wm.open_mainfile(filepath=str(scan_source))
    obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    bm=bmesh.new();bm.from_mesh(obj.data)
    normal=sum((f.normal*f.calc_area() for f in bm.faces),Vector()).normalized()
    full_normal=normal.copy()
    normal=Vector((normal.x,normal.y,0)).normalized()
    tangent=Vector((normal.y,-normal.x,0))
    center=sum((v.co for v in bm.verts),Vector())/len(bm.verts)
    up=Vector((0,0,1));cut=1.5
    if VERSION!='scan':
        # Remove the scan's overall forward lean by a rigid orientation, not
        # by stretching/dragging its lower vertices into an outboard shelf.
        normal=full_normal
        tangent=Vector((0,0,1)).cross(normal).normalized()
        up=normal.cross(tangent).normalized()
        if VERSION in ['scan5','scan6']:tangent,up=up,-tangent
        minimum=min(v.co.dot(up) for v in bm.verts)
        maximum=max(v.co.dot(up) for v in bm.verts)
        cut=minimum+(maximum-minimum)*.68
    for v in bm.verts:
        scale=6.0 if VERSION=='scan4' else 3.0
        p=v.co.copy();u=(p-center).dot(tangent)*scale;out=(p-center).dot(normal)*scale
        # Source Z stays vertical; no portrait rotation or anisotropic fit.
        v.co=Vector((-15.62+.94*u-.342*out,3.5+(p.dot(up)-cut)*scale,3.94+.342*u+.94*out))
    trees=[BVHTree.FromBMesh(bm,epsilon=0)]
    bm.to_mesh(obj.data);bm.free();obj.data.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'existing_source_sections_{VERSION}.blend'))

def ease(a,b,v):
    t=max(0,min(1,(v-a)/(b-a)));return t*t*(3-2*t)

def front(x,y):
    hits=[]
    for tree in trees:
        hit=tree.ray_cast(Vector((x,y,12)),Vector((0,0,-1)),24)
        if hit[0] is not None:hits.append(hit[0].z)
    return max(hits) if hits else None

# Sample the actual side at twice the density resolution. Below the last real
# section, continue inward; do not preserve the old broad exterior backing.
profiles={};cap_samples={}
for ix in range(nx):
    x=(lo[0]+ix)*step
    rows=[(j*.125,front(x,j*.125)) for j in range(-40 if IS_SCAN else -8,29)]
    rows=[(y,z) for y,z in rows if z is not None]
    if not rows:continue
    if IS_SCAN:
        cap=front(x,3.499)
        if cap is None:continue
        offsets=[];level=grid['levels'].index(3.5)
        for iz in range(nz-1):
            a=columns[(iz*nx+ix)*(len(grid['levels'])+1)+1+level]
            b=columns[((iz+1)*nx+ix)*(len(grid['levels'])+1)+1+level]
            if a<0<=b:offsets.append((lo[2]+iz+a/(a-b))*step)
        if not offsets:continue
        cap_samples[ix]=cap
        shift=max(offsets)-cap
        rows=[(y,z+shift) for y,z in rows]
    profiles[ix]=rows
cap_variations={}
if VERSION=='scan6':
    # Keep the scan's actual cap relief after removing only its overall plane
    # trend. Per-column anchoring alone erased the main stone silhouettes.
    xs=[(lo[0]+i)*step for i in cap_samples]
    ys=list(cap_samples.values());mx=sum(xs)/len(xs);my=sum(ys)/len(ys)
    slope=sum((x-mx)*(y-my) for x,y in zip(xs,ys))/sum((x-mx)**2 for x in xs)
    for ix,value in cap_samples.items():
        variation=max(-.6,min(.6,value-(my+slope*((lo[0]+ix)*step-mx))))
        cap_variations[ix]=variation
        profiles[ix]=[(y,z+variation) for y,z in profiles[ix]]
profile_low=(lo[0]+min(profiles))*step
profile_high=(lo[0]+max(profiles))*step

def envelope(ix,y):
    rows=profiles[ix]
    if y<=rows[0][0]:return rows[0][1]-(rows[0][0]-y)*1.1
    if y>=rows[-1][0]:return rows[-1][1]
    for (a,za),(b,zb) in zip(rows,rows[1:]):
        if a<=y<=b:return za+(zb-za)*(y-a)/(b-a)
    raise AssertionError('Missing section')

def replacement(ix,y):
    if VERSION=='v1' or IS_SCAN or y>=1.5:return envelope(ix,y)
    # Keep the main real face; replace its abrupt scanned/source foot by one
    # continuous inward return instead of a ledge over the old backing wall.
    depth=1.5-y
    return envelope(ix,1.5)-.20*depth-.22*depth*depth

records=[]
for iz in range(nz):
    z=(lo[2]+iz)*step
    for iy in range(ny):
        y=(lo[1]+iy)*step
        for ix in range(nx):
            if ix not in profiles:continue
            x=(lo[0]+ix)*step
            weight=ease(-21,-19.5,x)*(1-ease(-11,-9.5,x))*ease(-1,1,z)
            if VERSION in ['scan5','scan6']:weight*=ease(profile_low,profile_low+.75,x)*(1-ease(profile_high-.75,profile_high,x))
            if weight<=0:continue
            index=(iz*ny+iy)*nx+ix;old=nodes[index]
            boundary=replacement(ix,min(y,3.499))
            if VERSION in ['scan3','scan4','scan5','scan6']:
                return_weight=ease(2.5,6.0,3.5-y)
                if return_weight>=.99999:continue
                if return_weight>0:
                    crossings=[]
                    for zi in range(nz-1):
                        a=nodes[(zi*ny+iy)*nx+ix];b=nodes[((zi+1)*ny+iy)*nx+ix]
                        if a<0<=b:crossings.append((lo[2]+zi+a/(a-b))*step)
                    if not crossings:continue
                    boundary=boundary*(1-return_weight)+max(crossings)*return_weight
            # A continuous half-space from the real front fills only inboard;
            # the original body still supplies the common bottom/back closure.
            # Above .5m, fill the former core/front gap up to the real cap.
            rock=max(y-3.5,z-boundary)
            candidate=max(old,z-boundary)
            if y>=.5:candidate=min(candidate,rock)
            if VERSION=='v2' or IS_SCAN:
                floor=min(-4.5,min(grid['levels'])-1.4)+.12*math.sin(x*.37+z*.17)+.07*math.sin(z*.46-x*.13)
                candidate=max(rock,floor-y)
                col=(iz*nx+ix)*(len(grid['levels'])+1)
                allowance=1.5*ease(0,1.0,max(0,3.5-y))
                cap=min(max(columns[col+1+k]-allowance,y-h) for k,h in enumerate(grid['levels']))
                if VERSION=='v2':candidate=max(candidate,cap)
            value=round(old*(1-weight)+max(-.5,min(.5,candidate))*weight,5)
            if abs(value-old)<.000001:continue
            if abs(value)<.002:value=.002 if value>=0 else -.002
            records.append(dict(x=lo[0]+ix,y=lo[1]+iy,z=lo[2]+iz,density=value))
payload['rocks']=records
save=OUT/f'face_replacement_{VERSION}.json'
save.write_text(json.dumps(payload,separators=(',',':'))+'\n')
report=dict(samples=len(records),source_sha256=hashlib.sha256((ROOT/'art/work/cliff_volume/2026-10-16/source.json').read_bytes()).hexdigest(),
    save_sha256=hashlib.sha256(save.read_bytes()).hexdigest(),
    sections={str((lo[0]+i)*step):rows for i,rows in profiles.items()},
    operation='Unchanged existing closed crown faces; true front intersections at.125m vertical intervals. Replace core exterior by shared cap/side envelope; below last real section continue inward1.1m/m into original common bottom. Ordinary editable density, no stretch/source instances.',
    stage='Unaccepted local volume spike, not a player brush or default promotion.')
if VERSION=='v2':report['operation']='Existing source main front faces aboveY1.5; one continuous inward lower return from that actual section (.20d+.22d²), same canonical bottom plane. Complete side density replaces former core exterior; original dry-cap footprint guard releases over1m depth. No added rock instances or source stretch.'
if IS_SCAN:
    report['operation']='Existing RockFace02 open source only supplies front ray intersections. Uniform3x scale, source Z remains vertical. Each x-section translates depth to original dry edge at cap; actual lower face supplies relief/returns, then inward1.1m/m continuation into canonical bottom. Whole bounded density side replaces core; no open runtime patch, source instances or anisotropic scale.'
    report['scan_source']=str(scan_source.relative_to(ROOT))
    report['scan_sha256']=hashlib.sha256(scan_source.read_bytes()).hexdigest()
    if VERSION!='scan':report['operation']='RockFace02 front intersections, same envelope replacement. Uniform3x scale and rigid frame aligns the complete area-weighted source normal outward; source Up is perpendicular to that normal. Cap cuts at68% source vertical extent, each section anchored to original dry-edge cap. Actual lower face then inward continuation to canonical bottom.'
    if VERSION in ['scan3','scan4','scan5','scan6']:report['operation']+=' Below2.5m depth blend the geometric front position into the actual original base-front crossings; at6m depth leave base nodes untouched.'
    if VERSION=='scan4':report['operation']=report['operation'].replace('Uniform3x','Uniform6x')
    if VERSION in ['scan5','scan6']:report['operation']+=' Rigid90degree face-plane rotation converts source horizontal strata to vertical clefts; feather actual source-supported x interval over.75m.'
    if VERSION=='scan6':
        report['operation']+=' Preserve real detrended source cap variation, bounded to +/-.6m; actual visible footprint changes locally while canonical cells remain unchanged. Requires actual-skin cap coverage study, not production grass acceptance.'
        report['cap_variations']=cap_variations
(OUT/f'report_{VERSION}.json').write_text(json.dumps(report,indent=2)+'\n')
print('CLIFF FACE REPLACEMENT:',json.dumps({k:v for k,v in report.items() if k!='sections'}))
