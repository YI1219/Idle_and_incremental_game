"""Offline local fit of existing robe vertices across sampled Godot poses.
No runtime simulation: the output remains the existing mesh with four skin weights.
Conservative leg capsules guide fit; final triangle/capture checks remain necessary.
"""
from pathlib import Path
import bpy,json,sys,numpy as np
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(Path(__file__).parent))
from preserve_garment_tracks import read,raw
j,buf=read(ROOT/'art/work/garment_v06/pre_clearance.glb');skin=j['skins'][0];names=[j['nodes'][i]['name'] for i in skin['joints']]
ibm=np.frombuffer(raw(j,buf,skin['inverseBindMatrices']),dtype='<f4').reshape(-1,4,4).transpose(0,2,1)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/work/garment_v06/pre_clearance.blend'));robe=bpy.data.objects['Robe']
original=np.array([(v.co.x,v.co.z,-v.co.y) for v in robe.data.vertices],dtype=float);points=original.copy();count=len(points)
joints=np.zeros((count,4),dtype=int);weights=np.zeros((count,4))
for v in robe.data.vertices:
 groups=sorted([g for g in v.groups if robe.vertex_groups[g.group].name in names and g.weight>0],key=lambda g:g.weight,reverse=True)[:4]
 for k,g in enumerate(groups):joints[v.index,k]=names.index(robe.vertex_groups[g.group].name);weights[v.index,k]=g.weight
 weights[v.index]/=weights[v.index].sum()
samples=json.loads((ROOT/'art/review/garment_v06/fit_input_poses.json').read_text());poses=[]
for s in samples:
 mats=[];capsules=[]
 for n in names:
  d=s['bones'][n];m=np.eye(4);m[:3,:3]=np.array(d[:9]).reshape(3,3).T;m[:3,3]=d[9:];mats.append(m)
 for side in ['L','R']:
  for a,b,radius in [('Thigh.','Shin.',.054),('Shin.','Foot.',.038)]:
   capsules.append((np.array(s['bones'][a+side][9:]),np.array(s['bones'][b+side][9:]),radius,a=='Shin.'))
 poses.append((np.array(mats)@ibm,capsules))
# Keep sleeve/bodice untouched. Fade the fit above the upper thigh.
mask=np.clip((.555-original[:,1])/.085,0,1)
neighbors=[set() for _ in range(count)]
for e in robe.data.edges:
 a,b=e.vertices;neighbors[a].add(b);neighbors[b].add(a)
# Preserve thin shell pairing and split material seams by sharing near-point moves.
from mathutils.kdtree import KDTree
kd=KDTree(count)
for i,p in enumerate(original):kd.insert(p,i)
kd.balance()
for i,p in enumerate(original):neighbors[i].update(k for _,k,_ in kd.find_range(p,.002))
report=[]
for iteration in range(7):
 corrections=np.zeros_like(points);worst=np.zeros(count);p4=np.column_stack([points,np.ones(count)])
 for mats,capsules in poses:
  blend=(mats[joints]*weights[:,:,None,None]).sum(1);deform=np.einsum('nij,nj->ni',blend,p4)[:,:3]
  for start,end,radius,taper in capsules:
   line=end-start;t=np.clip((deform-start)@line/(line@line),0,1);closest=start+t[:,None]*line;radial=deform-closest;dist=np.linalg.norm(radial,axis=1)
   radii=radius*(1-.25*t) if taper else np.full(count,radius)
   depth=(radii-dist)*mask;select=depth>worst
   if not select.any():continue
   # Invert just selected blended skin matrices; reject ill-conditioned extremes.
   inv=np.linalg.pinv(blend[select,:3,:3]);world=radial[select]/np.maximum(dist[select,None],.00001)*depth[select,None]
   corrections[select]=np.einsum('nij,nj->ni',inv,world);worst[select]=depth[select]
 step=corrections*.6
 # Smooth the displacement field, not the garment itself, preserving folds.
 smoothed=np.array([.7*step[i]+.3*np.mean(step[list(ns)],axis=0) if ns else step[i] for i,ns in enumerate(neighbors)])
 candidate=points+smoothed
 displacement=candidate-original;length=np.linalg.norm(displacement,axis=1);displacement*=np.minimum(1,.048/np.maximum(length,1e-9))[:,None]
 points=original+displacement*mask[:,None]
 report.append({'iteration':iteration,'inside_vertices':int((worst>.001).sum()),'worst_capsule_penetration_m':float(worst.max())});print(report[-1],flush=True)
for v,p in zip(robe.data.vertices,points):v.co=(p[0],-p[2],p[1])
robe.data.update();length=np.linalg.norm(points-original,axis=1)
report={'accepted_for_runtime':False,'reason':'Rejected for damaged fold/seam finish in Godot; experimental outputs only.','method':'offline worst-pose capsule-guided rest-vertex fit; shell/seam displacement smoothing; no removed faces','poses':len(poses),'max_displacement_m':float(length.max()),'changed_vertices':int((length>1e-6).sum()),'iterations':report}
(ROOT/'art/review/garment_v06/clearance_fit.json').write_text(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/work/garment_v06/clearance_trial.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'art/work/garment_v06/clearance_trial.glb'),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True)
