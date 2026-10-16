"""Unaccepted, bounded density conversions of the retained body/crown sources.

Iterative oriented-ray classification is unreliable on this composite, even
after voxel remeshing. The explicit vertical hull avoids that classifier but
fills overhang air too; it is not an exact CSG union. Originals stay intact.
"""
import bpy
import bmesh
import hashlib
import json
import sys
from array import array
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/work/rendered_island/2026-10-17'
BASE=ROOT/'art/work/exposed_bedrock/2026-10-17'
VERSION=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'v1'
assert VERSION in ['v1','closed','envelope','envelopecap']
IS_ENVELOPE=VERSION in ['envelope','envelopecap']
source=json.loads((OUT/'source.json').read_text())
grid=json.loads((BASE/'source.json').read_text())
payload=json.loads((BASE/'base_save.json').read_text())
assert source['cells']==payload['cells']
lo,hi,step=grid['lo'],grid['hi'],grid['step'];nx,ny,nz=[hi[k]-lo[k]+1 for k in range(3)]
nodes=array('f');nodes.frombytes((BASE/'base_nodes.bin').read_bytes())
bpy.ops.wm.read_factory_settings(use_empty=True)
points=[];triangles=[]
for component in source['components']:
    data=(OUT/component['path']).read_bytes()
    assert hashlib.sha256(data.hex().encode()).hexdigest()==component['sha256_hex']
    values=array('f');values.frombytes(data)
    start=len(points);points.extend(tuple(values[i:i+3]) for i in range(0,len(values),3))
    triangles.extend((start+i,start+i+2,start+i+1) for i in range(0,len(values)//3,3))
mesh=bpy.data.meshes.new('ActualRenderedBody_GodotYUp');mesh.from_pydata(points,[],triangles)
bm=bmesh.new();bm.from_mesh(mesh)
# Preserve actual face winding on the composite/open draw components.
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
bm.normal_update();bm.to_mesh(mesh);bm.free();mesh.update()
obj=bpy.data.objects.new(mesh.name,mesh);bpy.context.collection.objects.link(obj)
source_state={}
if VERSION=='closed':
    bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    obj.data.remesh_voxel_size=.10
    bpy.ops.object.voxel_remesh()
bm=bmesh.new();bm.from_mesh(obj.data);bm.normal_update()
source_state=dict(triangles=sum(len(f.verts)-2 for f in bm.faces),nonmanifold_edges=sum(not e.is_manifold for e in bm.edges),volume=bm.calc_volume(signed=True))
if VERSION=='closed':assert source_state['nonmanifold_edges']==0 and source_state['volume']>0
tree=BVHTree.FromBMesh(bm,epsilon=0);bm.free()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'actual_rendered_body_{VERSION}.blend'))
rays=[Vector(v).normalized() for v in [(.8731,.3817,.3039),(-.429,.791,.436),(.265,-.413,.872)]]
column_cache={}
if IS_ENVELOPE:
    # This is an explicit vertical hull of the retained draw geometry, not a
    # claimed CSG union of its overlapping/open shells. No ray-step ambiguity.
    tri=np.asarray(points,dtype=np.float64)[np.asarray(triangles)]
    bounds_lo=tri[:,:,[0,2]].min(axis=1);bounds_hi=tri[:,:,[0,2]].max(axis=1)
    for iz in range(nz):
        z=(lo[2]+iz)*step
        for ix in range(nx):
            x=(lo[0]+ix)*step
            mask=(bounds_lo[:,0]<=x)&(bounds_hi[:,0]>=x)&(bounds_lo[:,1]<=z)&(bounds_hi[:,1]>=z)
            t=tri[mask];a=t[:,0];b=t[:,1]-a;c=t[:,2]-a
            den=b[:,0]*c[:,2]-b[:,2]*c[:,0]
            valid=np.abs(den)>1e-12
            t=t[valid];a=a[valid];b=b[valid];c=c[valid];den=den[valid]
            u=((x-a[:,0])*c[:,2]-(z-a[:,2])*c[:,0])/den
            v=(b[:,0]*(z-a[:,2])-b[:,2]*(x-a[:,0]))/den
            valid=(u>=-1e-9)&(v>=-1e-9)&(u+v<=1+1e-9)
            heights=(a[:,1]+u*b[:,1]+v*c[:,1])[valid]
            column_cache[(x,z)]=(float(heights.min()),float(heights.max())) if len(heights) else None
disagreements=0;queries=0;cap_ties=0
def density(p):
    global disagreements,queries,cap_ties
    nearest=tree.find_nearest(p);assert nearest[0] is not None
    if IS_ENVELOPE:
        queries+=1
        heights=column_cache[(p.x,p.z)]
        if VERSION=='envelopecap' and heights is not None and heights[1]-heights[0]>.7 and abs(p.y-heights[1])<=.35:
            delta=p.y-heights[1]
            return max(.002,delta) if delta>=-1e-6 else delta
        inside=heights is not None and heights[0]+1e-6<p.y<heights[1]-1e-6
        return (-1 if inside else 1)*max(.002,min(.5,nearest[3]))
    if VERSION=='closed' and abs(p.y-3.5)<.000001 and nearest[3]<.00001 and nearest[1].y>.98:
        cap_ties+=1;return .002
    votes=[]
    for ray in rays:
        origin=p+ray*.00001;winding=0
        for _ in range(256):
            hit=tree.ray_cast(origin,ray,150)
            if hit[0] is None:break
            direction=hit[1].dot(ray)
            if direction>.000001:winding+=1
            elif direction<-.000001:winding-=1
            origin=hit[0]+ray*.0001
        else:raise RuntimeError('Ray traversal exhausted')
        votes.append(winding>0)
    queries+=1
    if len(set(votes))>1:disagreements+=1
    distance=min(.5,nearest[3])
    if distance<.002:distance=.002
    return -distance if sum(votes)>=2 else distance
def ease(a,b,v):
    t=max(0,min(1,(v-a)/(b-a)));return t*t*(3-2*t)
records=[]
for iz in range(nz):
    z=(lo[2]+iz)*step
    for ix in range(nx):
        x=(lo[0]+ix)*step
        weight=ease(-22,-20.5,x)*(1-ease(-10,-8,x))*ease(-3,-1,z)*(1-ease(7.5,9,z))
        if weight<=0:continue
        for iy in range(ny):
            y=(lo[1]+iy)*step;index=(iz*ny+iy)*nx+ix;old=nodes[index]
            value=round(old*(1-weight)+density(Vector((x,y,z)))*weight,5)
            if abs(value-old)<.000001:continue
            if abs(value)<.002:value=.002 if value>=0 else -.002
            records.append(dict(x=lo[0]+ix,y=lo[1]+iy,z=lo[2]+iz,density=value))
payload['rocks']=records;save=OUT/f'rendered_body_{VERSION}.json'
save.write_text(json.dumps(payload,separators=(',',':'))+'\n')
report=dict(samples=len(records),source_sha256=hashlib.sha256((OUT/'source.json').read_bytes()).hexdigest(),
    save_sha256=hashlib.sha256(save.read_bytes()).hexdigest(),queries=queries,ray_vote_disagreements=disagreements,source_state=source_state,flat_cap_air_ties=cap_ties,
    operation='Actual original visible terrain body surfaces plus42closed retained crowns. Three oriented-winding rays classify composite union; nearest actual face distance, bounded ordinary v4density replacement. No source stretching, new rock face source or runtime model overlay.',
    stage='Unaccepted local conversion, not proof of source closure or default art acceptance.')
if VERSION=='closed':report['operation']+=' Before density conversion, Blender.10m voxel-remesh of the preserved composite source, with zero nonmanifold source edges required. Original flat upper cap ties belong to air. Closure alone is not art acceptance.'
if IS_ENVELOPE:
    report['operation']='Bounded vertical-envelope density of retained body/crown draw geometry. At each .25m XZ node, analytic float64 triangle intersections supply min/max Y; fill that entire interval, including visible air below overhangs. Nearest original face sets bounded magnitude. This is not a shape-preserving or exact CSG conversion. Outcrop props are excluded from the source and disappear in this unified study. Exact upper/lower ties belong to air. No new model or runtime overlay.'
    report['nonempty_columns']=sum(h is not None for h in column_cache.values())
    report['ray_vote_disagreements']=None
    report['ray_vote_note']='Not applicable: this version does not classify points with rays.'
    if VERSION=='envelopecap':report['operation']+=' Within .35m of a cap above a >.7m column, use vertical cap distance rather than nearest composite internal face, keeping the cap interpolation uniform.'
(OUT/f'report_{VERSION}.json').write_text(json.dumps(report,indent=2)+'\n')
print('RENDERED BODY BAKE:',json.dumps(report))
