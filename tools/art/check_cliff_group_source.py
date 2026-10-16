"""Independent finite ray checks of the closed scan copy, not art acceptance."""
import bpy,bmesh,json,random,sys,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/work/cliff_group_volume/2026-10-17'
version=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'v1'
assert version in ['v1','v2'];suffix='' if version=='v1' else '_v2'
bpy.ops.wm.open_mainfile(filepath=str(OUT/f'closed_source{suffix}.blend'))
mesh=next(o.data for o in bpy.context.scene.objects if o.type=='MESH')
bm=bmesh.new();bm.from_mesh(mesh);bm.normal_update();tree=BVHTree.FromBMesh(bm,epsilon=0)
unseen=set(bm.verts);components=[]
while unseen:
 stack=[unseen.pop()];part=[]
 while stack:
  v=stack.pop();part.append(v)
  for edge in v.link_edges:
   other=edge.other_vert(v)
   if other in unseen:unseen.remove(other);stack.append(other)
 faces={f for v in part for f in v.link_faces}
 components.append({'vertices':len(part),'triangles':len(faces),'lo':[min(v.co[k] for v in part) for k in range(3)],'hi':[max(v.co[k] for v in part) for k in range(3)]})
verts=np.asarray([v.co[:] for v in bm.verts],dtype=np.float64);bm.verts.index_update()
tri=verts[np.asarray([[v.index for v in f.verts] for f in bm.faces])]
a=tri[:,0];e1=tri[:,1]-a;e2=tri[:,2]-a;norm=np.cross(e1,e2)
rays=[np.asarray(v,dtype=np.float64) for v in [(.8731,.3817,.3039),(-.429,.791,.436),(.265,-.413,.872)]]
for r in rays:r/=np.linalg.norm(r)
rng=random.Random(1729);lower=verts.min(axis=0)-.5;upper=verts.max(axis=0)+.5
mismatches=[];disagreements=[];tested=0
for i in range(500):
 p=np.asarray([rng.uniform(lower[k],upper[k]) for k in range(3)])
 if tree.find_nearest(Vector(p))[3]<1e-4:continue
 tested+=1;votes=[]
 for ray in rays:
  h=np.cross(ray,e2);det=np.einsum('ij,ij->i',e1,h);valid=np.abs(det)>1e-10
  f=np.zeros(len(det));f[valid]=1/det[valid];s=p-a;u=f*np.einsum('ij,ij->i',s,h);q=np.cross(s,e1)
  v=f*np.einsum('j,ij->i',ray,q);distance=f*np.einsum('ij,ij->i',e2,q)
  ids=np.where(valid&(u>=0)&(v>=0)&(u+v<=1)&(distance>1e-5))[0]
  analytic=int(np.sum(np.sign(norm[ids]@ray)));pos=Vector(p)+Vector(ray)*1e-5;winding=0
  for _ in range(128):
   hit=tree.ray_cast(pos,Vector(ray),150)
   if hit[0] is None:break
   d=hit[1].dot(Vector(ray))
   if d>1e-6:winding+=1
   elif d< -1e-6:winding-=1
   pos=hit[0]+Vector(ray)*.0001
  else:raise RuntimeError('Ray traversal exhausted')
  if (analytic>0)!=(winding>0):mismatches.append({'point':p.tolist(),'analytic':analytic,'bvh':winding})
  votes.append(analytic>0)
 if len(set(votes))>1:disagreements.append(p.tolist())
report={'source_blend_sha256':hashlib.sha256((OUT/f'closed_source{suffix}.blend').read_bytes()).hexdigest(),'sampled_points':tested,'rays_per_point':3,'analytic_bvh_sign_mismatches':len(mismatches),'analytic_direction_disagreements':len(disagreements),'mismatches':mismatches,'disagreements':disagreements,'components':sorted(components,key=lambda p:-p['triangles']),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),'degenerate_triangles':int((np.linalg.norm(norm,axis=1)<1e-10).sum()),'scope':'Seeded500point/three-direction comparison of BVH traversal with independent float64 triangle intersections on closed source, before world transform/density extraction. Not proof for arbitrary points, self-intersections, final skin, editing or art.'}
(OUT/f'source_checks{suffix}.json').write_text(json.dumps(report,indent=2)+'\n');print('CLIFF GROUP SOURCE CHECK:',json.dumps(report))
assert tested==500 and not mismatches and not disagreements and not report['nonmanifold_edges'] and not report['degenerate_triangles']
