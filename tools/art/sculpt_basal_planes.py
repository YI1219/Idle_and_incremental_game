"""Two unequal real bridge-face planes return into the shared editable core."""
import hashlib,json,sys
from pathlib import Path
import numpy as np
sys.path.insert(0,'/tmp/yunlu-cliff-scipy')
from scipy.spatial import ConvexHull

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/work/basal_planes/2026-10-17';OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'art/work/actual_shoulder/2026-10-17/shoulder_cut_clean.json'
HULLS=ROOT/'art/work/rendered_join/2026-10-17/crown_roots/v2/report.json'
FRAMES=ROOT/'art/work/rendered_join/2026-10-17/crown_frames.json'
frames=json.loads(FRAMES.read_text());source_hulls=json.loads(HULLS.read_text())['hulls']
planes=[]
for crown,extra_slope in [(36,.16),(37,.22)]:
 h=next(h for h in source_hulls if h['crown']==crown)
 p=np.array(h['hull_vertices']);hull=ConvexHull(p);tri=p[hull.simplices]
 areas=np.linalg.norm(np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]),axis=1)*.5
 groups={}
 for area,eq in zip(areas,hull.equations):
  if eq[:3]@h['outward']<=.65 or eq[1]>=-.25:continue
  key=tuple(np.round(eq,4))
  if key not in groups:groups[key]=[0,eq]
  groups[key][0]+=float(area)
 area,old_plane=max(groups.values(),key=lambda v:v[0]);plane=old_plane.copy()
 horizontal=np.linalg.norm(plane[[0,2]]);pivot_y=1.2
 plane[1]-=extra_slope*horizontal;plane[3]+=extra_slope*horizontal*pivot_y
 plane/=np.linalg.norm(plane[:3])
 f=frames[crown]
 planes.append(dict(crown=crown,original_equation=old_plane.tolist(),new_equation=plane.tolist(),actual_face_area=area,extra_inward_slope=extra_slope,pivot_y=pivot_y,edge=[f['edge'][0],0,f['edge'][1]],outward=f['outward'],tangent=f['tangent'],width=f['width']))
BASE=ROOT/'art/work/exposed_bedrock/2026-10-17';grid=json.loads((BASE/'source.json').read_text());lo,hi,step=grid['lo'],grid['hi'],grid['step']
nx,ny,nz=[hi[k]-lo[k]+1 for k in range(3)]
base=np.fromfile(BASE/'base_nodes.bin',dtype='<f4').reshape(nz,ny,nx).astype(float)
payload=json.loads(SOURCE.read_text());old=base.copy()
for r in payload['rocks']:old[r['z']-lo[2],r['y']-lo[1],r['x']-lo[0]]=r['density']
values=old.copy()
union='--union' in sys.argv
raw=base.copy()
if union:
 raw_source=ROOT/'art/work/rendered_join/2026-10-17/cap_fix/join_raw.json'
 for r in json.loads(raw_source.read_text())['rocks']:raw[r['z']-lo[2],r['y']-lo[1],r['x']-lo[0]]=r['density']
 bounded_hulls=[]
 for h in source_hulls:
  eq=np.array(h['hull_equations'])
  selected=next((p for p in planes if p['crown']==h['crown']),None)
  if selected is not None:eq=np.concatenate([eq,np.array([selected['new_equation']])])
  bounded_hulls.append(eq)
def ease(a,b,v):
 t=np.clip((v-a)/(b-a),0,1);return t*t*(3-2*t)
def sample(p):
 q=p/step-lo;low=np.floor(q).astype(int);f=q-low;value=0.0
 for dx in range(2):
  for dy in range(2):
   for dz in range(2):
    key=np.clip(low+[dx,dy,dz],0,[nx-1,ny-1,nz-1]);weight=np.prod([f[k] if d else 1-f[k] for k,d in enumerate([dx,dy,dz])]);value+=raw[key[2],key[1],key[0]]*weight
 return float(value)
for iz in range(nz):
 for ix in range(nx):
  x,z=(lo[0]+ix)*step,(lo[2]+iz)*step
  local=ease(-22,-20.5,x)*(1-ease(-10,-8,x))*ease(-3,-1,z)*(1-ease(7.5,9,z))
  if local<=0:continue
  for iy in range(ny):
   y=(lo[1]+iy)*step
   if y>=1.6:continue
   p=np.array([x,y,z]);value=old[iz,iy,ix]
   if union:
    best=None
    for f in [frames[i] for i in [36,37,38]]:
     delta=p-np.array([f['edge'][0],0,f['edge'][1]]);along=abs(float(delta@f['tangent']));depth=float(delta@f['outward'])
     if along>=f['width']*.85 or depth<=-5 or depth>=2:continue
     score=along/f['width']+abs(depth)/6
     if best is None or score<best[0]:best=(score,f,along,depth)
    if best is None:continue
    _,f,along,depth=best
    mask=local*(1-ease(f['width']*.50,f['width']*.85,along))*ease(-5,-3.5,depth)*(1-ease(.75,2,depth))*ease(-4.5,-3.5,y)*(1-ease(1.0,1.6,y))
    if mask<=0:continue
    core=sample(p+np.array(f['outward'])*.8)
    bridge=min(float((eq[:,:3]@p+eq[:,3]).max()) for eq in bounded_hulls)
    candidate=min(core,bridge)
    # Rebuild the original root operator with individually bounded clipped
    # hulls BEFORE union. Keep every later cleft/shoulder/orphan subtraction.
    value=max(value,raw[iz,iy,ix]*(1-mask)+np.clip(candidate,-.5,.5)*mask)
   else:
    for h in planes:
     along=abs(float((p-h['edge'])@h['tangent']))
     mask=local*(1-ease(h['width']*.40,h['width']*.65,along))*(1-ease(.8,1.6,y))
     if mask<=0:continue
     eq=np.array(h['new_equation']);clip=float(np.clip(eq[:3]@p+eq[3],-.5,.5))
     value=max(value,old[iz,iy,ix]*(1-mask)+clip*mask)
   if abs(value-old[iz,iy,ix])<1e-6:continue
   value=round(value,5)
   if abs(value)<.002:value=.002 if value>=0 else -.002
   values[iz,iy,ix]=value
rows=[dict(x=int(lo[0]+ix),y=int(lo[1]+iy),z=int(lo[2]+iz),density=round(float(values[iz,iy,ix]),5)) for iz,iy,ix in np.argwhere(abs(values-base)>1e-6)]
payload['rocks']=rows;dest=OUT/('basal_planes_union.json' if union else 'basal_planes_v1.json');dest.write_text(json.dumps(payload,separators=(',',':'))+'\n')
report=dict(source_save_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),hulls_sha256=hashlib.sha256(HULLS.read_bytes()).hexdigest(),frames_sha256=hashlib.sha256(FRAMES.read_bytes()).hexdigest(),save_sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),planes=planes,changed_nodes=int(np.count_nonzero(abs(values-old)>1e-6)),sign_nodes_removed=int(np.count_nonzero((old<0)&(values>0))),sign_nodes_added=int(np.count_nonzero((old>0)&(values<0))),samples=len(rows),protected_saved_node_y_at_or_above=1.6,continuous_interpolation_may_reach_y=1.75,operation='Select each actual bridge36/37 largest outward/downward hull face by area. Rotate its halfspace inward below common pivotY1.2 with unequal added slopes.16/.22. Subtract through ordinary scalar density, bounded by actual frame widths and local XZ, release into retained upper sideY.8..1.6; no lower-height cutoff or independent bottom shell. Upper saved nodes>=1.6 preserved, not exact continuous-plane preservation. No fill, source asset, material or new player brush. Native/topology/edit/art acceptance unproven.')
if union:
 report['raw_root_source_sha256']=hashlib.sha256(raw_source.read_bytes()).hexdigest()
 report['operation']='Same two tilted real face planes, but intersect each with its OWN actual3Dhull before union with all three original bridge hulls and the original inward-retreated core. Replay exactly root-v2 ownership/fade; keep all later shoulder/cleft/orphan subtractions by maximum with the current cleaned field. This is not intersecting both infinite cut planes against neighboring stone. Lower fade remains original root-v2 Y-4.5..-3.5; upper saved nodes>=1.6 preserved, continuous interpolation may reach1.75. No fill/source/default/player-brush change. Native/topology/edit/art acceptance unproven.'
(OUT/('union_report.json' if union else 'report.json')).write_text(json.dumps(report,indent=2)+'\n')
print('BASAL PLANES:',json.dumps(report))
