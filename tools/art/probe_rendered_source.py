"""Trace closed-source ray consistency before trusting a density conversion."""
import bpy,bmesh,json
import numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/work/rendered_island/2026-10-17'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'actual_rendered_body_closed.blend'))
obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
bm=bmesh.new();bm.from_mesh(obj.data);bm.normal_update()
bad_winding=sum(len(e.link_loops)==2 and e.link_loops[0].vert==e.link_loops[1].vert for e in bm.edges)
tree=BVHTree.FromBMesh(bm,epsilon=0)
report={'bad_adjacent_winding':bad_winding,'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),'traces':[]}
for p in [(-15,2,3),(-15,2,0),(-15,4,3),(-15,-2,2),(-15,-5,3)]:
 for direction in [(.8731,.3817,.3039),(-.429,.791,.436),(.265,-.413,.872)]:
  ray=Vector(direction).normalized();origin=Vector(p)+ray*.00001;hits=[]
  for _ in range(128):
   hit=tree.ray_cast(origin,ray,150)
   if hit[0] is None:break
   hits.append({'point':list(hit[0]),'dot':hit[1].dot(ray),'distance':hit[3],'face':hit[2]})
   origin=hit[0]+ray*.0001
  report['traces'].append({'point':p,'direction':direction,'hits':hits,'parity':len(hits)%2,'winding':sum(1 if h['dot']>0 else -1 for h in hits)})
mesh=obj.data;mesh.calc_loop_triangles()
verts=np.asarray([v.co[:] for v in mesh.vertices],dtype=np.float64)
tris=verts[np.asarray([t.vertices[:] for t in mesh.loop_triangles])]
a=tris[:,0];e1=tris[:,1]-a;e2=tris[:,2]-a;normals=np.cross(e1,e2)
report['analytic_traces']=[]
# Independent float64 intersections do not advance past coincident surfaces.
for p in [(-15,2,3),(-15,2,0),(-15,4,3),(-15,-2,2),(-15,-5,3)]:
 for direction in [(.8731,.3817,.3039),(-.429,.791,.436),(.265,-.413,.872)]:
  ray=np.asarray(direction,dtype=np.float64);ray/=np.linalg.norm(ray)
  h=np.cross(ray,e2);det=np.einsum('ij,ij->i',e1,h);valid=np.abs(det)>1e-10
  f=np.zeros(len(det));f[valid]=1/det[valid];s=np.asarray(p)-a
  u=f*np.einsum('ij,ij->i',s,h);q=np.cross(s,e1)
  v=f*np.einsum('j,ij->i',ray,q);distance=f*np.einsum('ij,ij->i',e2,q)
  ids=np.where(valid&(u>=0)&(v>=0)&(u+v<=1)&(distance>1e-5))[0]
  report['analytic_traces'].append({'point':p,'direction':direction,
   'winding':int(np.sum(np.sign(normals[ids]@ray))),
   'hits':[{'triangle':int(i),'distance':float(distance[i]),'signed_dot':float(normals[i]@ray)} for i in ids]})
report['finding']='Opposite-facing coincident cap surfaces cancel analytic winding, but iterative BVH rays step past the second surface. Zero nonmanifold edges is insufficient to establish a reliable solid union. Do not use closed conversion as accepted density.'
(OUT/'ray_diagnostic.json').write_text(json.dumps(report,indent=2)+'\n')
print('RENDERED SOURCE DIAG:',json.dumps(report))
