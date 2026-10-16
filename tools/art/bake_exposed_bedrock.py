"""Expose existing whole shoulders in the same editable terrain volume.

Unlike the rejected source-volume route, there is no lower stretching, inward
warp, receding wall or slot subtraction. First isolate the actual cap decision.
"""
import bpy
import bmesh
import hashlib
import json
from array import array
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/work/exposed_bedrock/2026-10-17'
source=json.loads((OUT/'source.json').read_text())
payload=json.loads((OUT/'base_save.json').read_text())
lo,hi,step=source['lo'],source['hi'],source['step']
nx,ny,nz=[hi[i]-lo[i]+1 for i in range(3)]
nodes=array('f');nodes.frombytes((OUT/'base_nodes.bin').read_bytes())
assert len(nodes)==nx*ny*nz
bpy.ops.wm.read_factory_settings(use_empty=True)
solids=[];reports=[]
for i,crown in enumerate(source['crowns']):
    faces=crown['world_faces']
    mesh=bpy.data.meshes.new(crown['kind'])
    mesh.from_pydata(faces,[],[(j,j+2,j+1) for j in range(0,len(faces),3)])
    bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    if bm.calc_volume(signed=True)<0:bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
    bm.normal_update()
    bad=sum(not edge.is_manifold for edge in bm.edges)
    assert bad==0 and bm.calc_volume(signed=True)>0
    lower=Vector([min(v.co[k] for v in bm.verts) for k in range(3)])
    upper=Vector([max(v.co[k] for v in bm.verts) for k in range(3)])
    solids.append((BVHTree.FromBMesh(bm,epsilon=0),lower,upper))
    reports.append(dict(kind=crown['kind'],nonmanifold_edges=bad,triangles=len(bm.faces),
        lower=list(lower),upper=list(upper),above_cap_vertex_occurrences=crown['above_cap_vertex_occurrences']))
    bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(crown['kind']+'_OriginalWhole_GodotYUp',mesh);bpy.context.collection.objects.link(obj)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'whole_sources.blend'))
ray=Vector((.8731,.3817,.3039)).normalized()
def distance(solid,p):
    tree,lower,upper=solid
    if any(p[k]<lower[k]-.7 or p[k]>upper[k]+.7 for k in range(3)):return .5
    nearest=tree.find_nearest(p);assert nearest[0] is not None
    origin=p+ray*1e-7;hits=0
    for _ in range(32):
        hit=tree.ray_cast(origin,ray,100)
        if hit[0] is None:break
        hits+=1;origin=hit[0]+ray*.00001
    else:raise RuntimeError('Unbounded parity ray')
    return -nearest[3] if hits%2 else nearest[3]
def ease(a,b,value):
    t=max(0,min(1,(value-a)/(b-a)));return t*t*(3-2*t)
def join(a,b):
    radius=.14;t=max(0,min(1,.5+.5*(b-a)/radius))
    return b*(1-t)+a*t-radius*t*(1-t)
records=[]
for iz in range(nz):
    z=(lo[2]+iz)*step
    for iy in range(ny):
        y=(lo[1]+iy)*step
        for ix in range(nx):
            x=(lo[0]+ix)*step
            weight=ease(-22,-21.5,x)*(1-ease(-8.5,-8,x))*ease(-3,-2.5,z)*(1-ease(8.5,9,z))
            if weight<=0:continue
            index=(iz*ny+iy)*nx+ix;old=nodes[index];candidate=old;p=Vector((x,y,z))
            for solid in solids:
                stone=distance(solid,p)
                if stone<.5:candidate=join(candidate,stone)
            value=round(old*(1-weight)+max(-.5,min(.5,candidate))*weight,5)
            if abs(value-old)<.000001:continue
            if abs(value)<.002:value=.002 if value>=0 else -.002
            records.append(dict(x=lo[0]+ix,y=lo[1]+iy,z=lo[2]+iz,density=value))
payload['rocks']=records
save=OUT/'exposed_v1.json';save.write_text(json.dumps(payload,separators=(',',':'))+'\n')
report=dict(sources=reports,samples=len(records),save_sha256=hashlib.sha256(save.read_bytes()).hexdigest(),
    input_sha256=hashlib.sha256((OUT/'source.json').read_bytes()).hexdigest(),
    operation='Original complete source solids in exact existing crown normalization/poses. .14m smooth union into unchanged local base; no source warp, cap clipping, core recession or fracture subtraction.',
    stage='Unaccepted cap-decision isolation; not a default asset or a new player brush.')
(OUT/'report_v1.json').write_text(json.dumps(report,indent=2)+'\n')
print('EXPOSED BEDROCK BAKE:',json.dumps(report))
