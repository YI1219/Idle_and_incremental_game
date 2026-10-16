"""One bounded subtractive shoulder cut from an actual upper skin plane."""
import hashlib,json,sys
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art/work/actual_shoulder/2026-10-17';WORK.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'art/work/rendered_join/2026-10-17/exposed_cleft/exposed_cleft_v1.json'
SKIN=ROOT/'art/work/cliff_finish/2026-10-17/vertices.bin'
FRAMES=ROOT/'art/work/rendered_join/2026-10-17/crown_frames.json'
frame=json.loads(FRAMES.read_text())[37]
origin=np.array([frame['edge'][0],0,frame['edge'][1]])
out=np.array(frame['outward']);tangent=np.array(frame['tangent'])
tri=np.fromfile(SKIN,dtype='<f4').reshape(-1,3,3).astype(float)-origin
a=np.stack([tri[:,0,1],tri[:,0]@tangent],axis=1)
b=np.stack([tri[:,1,1]-tri[:,0,1],(tri[:,1]-tri[:,0])@tangent],axis=1)
c=np.stack([tri[:,2,1]-tri[:,0,1],(tri[:,2]-tri[:,0])@tangent],axis=1)
den=b[:,0]*c[:,1]-b[:,1]*c[:,0];valid=abs(den)>1e-10
a,b,c,den,depth=a[valid],b[valid],c[valid],den[valid],(tri@out)[valid]
def front(y,along):
 u=((y-a[:,0])*c[:,1]-(along-a[:,1])*c[:,0])/den
 v=(b[:,0]*(along-a[:,1])-b[:,1]*(y-a[:,0]))/den
 hit=(u>=-1e-9)&(v>=-1e-9)&(u+v<=1+1e-9)
 ds=(depth[:,0]+u*(depth[:,1]-depth[:,0])+v*(depth[:,2]-depth[:,0]))[hit]
 assert len(ds)
 return float(ds.max())
alongs=np.linspace(-.85,.45,27);upper=np.array([front(3.49,s) for s in alongs])
slope,intercept=np.polyfit(alongs,upper,1)
fit_error=float(np.max(abs(upper-(slope*alongs+intercept))))
assert fit_error<.015,'Actual grass edge must support a real dominant plane, not an invented straight border'
BASE=ROOT/'art/work/exposed_bedrock/2026-10-17'
grid=json.loads((BASE/'source.json').read_text());lo,hi,step=grid['lo'],grid['hi'],grid['step']
nx,ny,nz=[hi[k]-lo[k]+1 for k in range(3)]
base=np.fromfile(BASE/'base_nodes.bin',dtype='<f4').reshape(nz,ny,nx).astype(float)
payload=json.loads(SOURCE.read_text());old=base.copy()
for r in payload['rocks']:old[r['z']-lo[2],r['y']-lo[1],r['x']-lo[0]]=r['density']
values=old.copy();cleanup='--remove-orphan' in sys.argv
def ease(a,b,x):
 t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
for iz in range(nz):
 for ix in range(nx):
  x,z=(lo[0]+ix)*step,(lo[2]+iz)*step
  d=np.array([x,0,z])-origin;along=float(d@tangent);outward=float(d@out)
  mask=ease(-1.35,-.85,along)*(1-ease(.45,1.0,along))
  if mask<=0 or outward<-.7 or outward>1.7:continue
  for iy in range(ny):
   y=(lo[1]+iy)*step
   if y<2.0 or y>3.5:continue
   # Only retire the actual outboard grey shoulder; smoothly release the
   # cut into the original side below Y2.0..3.0. No soil/cap volume fill.
   release=.45*(1-ease(2.0,3.0,y))
   plane=(outward-(slope*along+intercept)-release)/np.sqrt(1+slope*slope)
   value=float(max(old[iz,iy,ix],old[iz,iy,ix]*(1-mask)+np.clip(plane,-.5,.5)*mask))
   if abs(value-old[iz,iy,ix])<1e-6:continue
   value=round(value,5)
   if abs(value)<.002:value=.002 if value>=0 else -.002
   values[iz,iy,ix]=value
orphan_nodes=[]
if cleanup:
 # Exact raw skin already establishes this tiny disconnected positive-volume
 # component. Remove only its four isolated negative knots, never main-body
 # triangles or a visual-only mesh component. Same ordinary editable volume.
 topology=json.loads((WORK/'connectivity_actualshoulder.json').read_text())
 assert len(topology['components'])==2 and topology['components'][1]['triangles']==96
 detached=topology['components'][1];detached_lower=np.floor(np.array(detached['lo'])/step).astype(int);detached_upper=np.ceil(np.array(detached['hi'])/step).astype(int)
 for iz in range(detached_lower[2],detached_upper[2]+1):
  for iy in range(detached_lower[1],detached_upper[1]+1):
   for ix in range(detached_lower[0],detached_upper[0]+1):
    if values[iz-lo[2],iy-lo[1],ix-lo[0]]<0:orphan_nodes.append((ix,iy,iz))
 assert len(orphan_nodes)==4
 for ix,iy,iz in orphan_nodes:
  for dx in [-1,0,1]:
   for dy in [-1,0,1]:
    for dz in [-1,0,1]:
     key=(ix+dx,iy+dy,iz+dz)
     assert key in orphan_nodes or values[key[2]-lo[2],key[1]-lo[1],key[0]-lo[0]]>0,'Do not erase a knot adjacent to the main body'
 for ix,iy,iz in orphan_nodes:values[iz-lo[2],iy-lo[1],ix-lo[0]]=abs(values[iz-lo[2],iy-lo[1],ix-lo[0]])
rows=[dict(x=int(lo[0]+ix),y=int(lo[1]+iy),z=int(lo[2]+iz),density=round(float(values[iz,iy,ix]),5)) for iz,iy,ix in np.argwhere(abs(values-base)>1e-6)]
payload['rocks']=rows;dest=WORK/('shoulder_cut_clean.json' if cleanup else 'shoulder_cut_v1.json');dest.write_text(json.dumps(payload,separators=(',',':'))+'\n')
assert len(upper)==len(alongs)==27
report=dict(source_save_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),source_skin_sha256=hashlib.sha256(SKIN.read_bytes()).hexdigest(),frames_sha256=hashlib.sha256(FRAMES.read_bytes()).hexdigest(),save_sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),crown=37,origin=origin.tolist(),outward=out.tolist(),tangent=tangent.tolist(),upper_plane_y=3.49,along_samples=alongs.tolist(),upper_front_samples=upper.tolist(),slope=float(slope),intercept=float(intercept),fit_max_error=fit_error,front_before={str(y):[front(y,s) for s in [-.85,-.5,0,.45]] for y in [3.49,3.25,3.,2.5,2.]},changed_nodes=int(np.count_nonzero(abs(values-old)>1e-6)),sign_nodes_removed=int(np.count_nonzero((old<0)&(values>0))),sign_nodes_added=int(np.count_nonzero((old>0)&(values<0))),samples=len(rows),operation='One subtractive plane follows the actual upper skin grass-edge direction of crown37, fitY3.49 over along-.85..45 with max error<.015m. Bounded along-1.35..1.0, fade into original lower sideY2..3 by.45m release. No ground fill, painted grey cover, whole-perimeter extrusion or source-asset change. Ordinary shared editable density save, tool-only authoring study; native/support/topology/art acceptance unproven.')
if cleanup:
 report['orphan_negative_knots_removed']=[list(k) for k in orphan_nodes]
 report['orphan_source_topology_sha256']=hashlib.sha256((WORK/'connectivity_actualshoulder.json').read_bytes()).hexdigest()
 report['operation']+=' Remove only four negative density knots of the inherited96triangle orphan; each26-neighbor is either in this isolated knot set or positive. Not a visual-only component deletion; final actual-skin topology still requires verification.'
(WORK/('clean_report.json' if cleanup else 'report.json')).write_text(json.dumps(report,indent=2)+'\n')
print('ACTUAL SHOULDER CUT:',json.dumps({k:v for k,v in report.items() if k not in ['upper_front_samples','along_samples']}))
