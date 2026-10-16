"""One offline 3D crown-to-body bridge study, based on retained geometry.

Patch ownership uses actual crown tangent/outward frames and body face normals.
The old lower body is locally retreated as bridges replace its exposed seam;
this is not an additive hull blanket or a new player-facing feature.
"""
import hashlib,json,sys
from pathlib import Path
import numpy as np
sys.path.insert(0,'/tmp/yunlu-cliff-scipy')
from scipy.spatial import ConvexHull
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'art/work/rendered_island/2026-10-17/complete'
WORK=ROOT/'art/work/rendered_join/2026-10-17'
BASE=ROOT/'art/work/exposed_bedrock/2026-10-17'
OUT=WORK/'crown_roots';OUT.mkdir(exist_ok=True)
VERSION='v3' if '--v3' in sys.argv else ('v2' if '--v2' in sys.argv else 'v1')
if VERSION!='v1':OUT=OUT/VERSION;OUT.mkdir(exist_ok=True)
source=json.loads((SOURCE/'source.json').read_text())
frames=json.loads((WORK/'crown_frames.json').read_text())
body=np.fromfile(SOURCE/'cliff.bin',dtype='<f4').reshape(-1,3,3).astype(float)[:,[0,2,1]]
centers=body.mean(axis=1)
n=np.cross(body[:,1]-body[:,0],body[:,2]-body[:,0]);n/=np.maximum(np.linalg.norm(n,axis=1,keepdims=True),1e-12)
scores=np.full((len(body),len(frames)),np.inf)
for i,f in enumerate(frames):
    edge=np.array([f['edge'][0],0,f['edge'][1]])
    delta=centers-edge;out=np.array(f['outward']);tangent=np.array(f['tangent'])
    along=delta@tangent;depth=delta@out
    eligible=(n@out>.2)&(abs(along)<f['width']*.7)&(depth>-5)&(depth<1)&(centers[:,1]<-1)
    scores[eligible,i]=abs(along[eligible])/(f['width']*.7)+abs(depth[eligible])/5
owner=np.argmin(scores,axis=1);owned=np.isfinite(scores.min(axis=1))
hulls=[];reports=[]
for index in [36,37,38]:
    comp=next(c for c in source['components'] if c['kind']=='crown_'+str(index))
    triangles=np.fromfile(SOURCE/comp['path'],dtype='<f4').reshape(-1,3,3).astype(float)
    section=[];height=1.6
    for t in triangles:
        for i in range(3):
            a,b=t[i],t[(i+1)%3]
            if (a[1]-height)*(b[1]-height)<0:
                section.append(a+(b-a)*(height-a[1])/(b[1]-a[1]))
    section=np.unique(np.round(section,6),axis=0)
    assigned=body[owned&(owner==index)]
    assert len(section)>5 and len(assigned)>3
    floor=float(np.quantile(assigned[:,:,1],.35))
    root=np.unique(assigned[assigned[:,:,1]<=floor],axis=0)
    assert len(root)>5
    points=np.concatenate([section,root])
    hull=ConvexHull(points)
    equations=hull.equations
    assert np.all(equations[:,:3]@points.mean(axis=0)+equations[:,3]<1e-6)
    hulls.append(equations)
    record=dict(crown=index,section_height=height,section_points=section.tolist(),assigned_triangles=len(assigned),root_y_quantile=floor,root_points=root.tolist(),hull_vertices=points[hull.vertices].tolist(),hull_equations=equations.tolist(),triangles=len(hull.simplices),volume=float(hull.volume),outward=frames[index]['outward'],tangent=frames[index]['tangent'])
    reports.append(record)

grid=json.loads((BASE/'source.json').read_text());lo,hi,step=grid['lo'],grid['hi'],grid['step'];nx,ny,nz=[hi[k]-lo[k]+1 for k in range(3)]
base=np.fromfile(BASE/'base_nodes.bin',dtype='<f4').reshape(nz,ny,nx).astype(float)
payload=json.loads((WORK/'cap_fix/join_raw.json').read_text())
raw=base.copy()
for r in payload['rocks']:raw[r['z']-lo[2],r['y']-lo[1],r['x']-lo[0]]=r['density']
def ease(a,b,x):
    v=np.clip((x-a)/(b-a),0,1);return v*v*(3-2*v)
def sample(p):
    q=p/step-lo;low=np.floor(q).astype(int);f=q-low;value=0
    for dx in range(2):
        for dy in range(2):
            for dz in range(2):
                key=np.clip(low+[dx,dy,dz],0,[nx-1,ny-1,nz-1]);w=np.prod([f[k] if d else 1-f[k] for k,d in enumerate([dx,dy,dz])]);value+=raw[key[2],key[1],key[0]]*w
    return float(value)
values=raw.copy();changed=0;added=removed=0
for iz in range(nz):
 z=(lo[2]+iz)*step
 for ix in range(nx):
  x=(lo[0]+ix)*step
  weight=ease(-22,-20.5,x)*(1-ease(-10,-8,x))*ease(-3,-1,z)*(1-ease(7.5,9,z))
  if weight<=0:continue
  p0=np.array([x,0,z]);best=None
  for f in [frames[i] for i in [36,37,38]]:
   delta=p0-np.array([f['edge'][0],0,f['edge'][1]]);along=abs(delta@f['tangent']);depth=delta@f['outward']
   if along>=f['width']*.85 or depth<=-5 or depth>=2:continue
   score=along/f['width']+abs(depth)/6
   if best is None or score<best[0]:best=(score,f,along,depth)
  if best is None:continue
  _,f,along,depth=best
  local=(1-ease(f['width']*.50,f['width']*.85,along))*ease(-5,-3.5,depth)*(1-ease(.75,2,depth))
  for iy in range(ny):
   y=(lo[1]+iy)*step
   # Do not retire saved nodes above the bridge. The .25m runtime
   # interpolation can still extend the transition up to Y1.75.
   upper=1-ease(1.0,1.6,y) if VERSION!='v1' else 1-ease(1.4,2.5,y)
   w=weight*local*ease(-4.5,-3.5,y)*upper
   if w<=0:continue
   p=np.array([x,y,z]);core=sample(p+np.array(f['outward'])*.8)
   bridge=min(float((eq[:,:3]@p+eq[:,3]).max()) for eq in hulls)
   candidate=min(core,bridge)
   value=round(float(raw[iz,iy,ix]*(1-w)+np.clip(candidate,-.5,.5)*w),5)
   if VERSION=='v3':
    # Unequal bounded clefts follow the true 3D bridge interfaces. The
    # normalized plane difference measures distance to each local bisector.
    for ia,ib,width,depth in [(2,1,.12,.55),(1,0,.075,.40)]:
     ea,eb=hulls[ia],hulls[ib];va=ea[:,:3]@p+ea[:,3];vb=eb[:,:3]@p+eb[:,3]
     ka,kb=int(np.argmax(va)),int(np.argmax(vb));da,db=va[ka],vb[kb]
     gradient=np.linalg.norm(ea[ka,:3]-eb[kb,:3])
     if gradient<.25:continue
     cut=min(width-abs(da-db)/gradient,depth+min(da,db))
     amount=weight*local*ease(-3.4,-2.8,y)*(1-ease(.9,1.6,y))
     value=round(float(value*(1-amount)+max(value,cut)*amount),5)
   if abs(value)<.002:value=.002 if value>=0 else -.002
   old=raw[iz,iy,ix];values[iz,iy,ix]=value
   changed+=int(value!=old);added+=int(old>0 and value<0);removed+=int(old<0 and value>0)
rows=[dict(x=int(lo[0]+ix),y=int(lo[1]+iy),z=int(lo[2]+iz),density=round(float(values[iz,iy,ix]),5)) for iz,iy,ix in np.argwhere(abs(values-base)>1e-6)]
payload['rocks']=rows;dest=OUT/f'crown_roots_{VERSION}.json';dest.write_text(json.dumps(payload,separators=(',',':'))+'\n')
report=dict(hulls=reports,source_sha256=hashlib.sha256((SOURCE/'source.json').read_bytes()).hexdigest(),frames_sha256=hashlib.sha256((WORK/'crown_frames.json').read_bytes()).hexdigest(),input_save_sha256=hashlib.sha256((WORK/'cap_fix/join_raw.json').read_bytes()).hexdigest(),save_sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),changed_nodes=changed,added_sign_nodes=added,removed_sign_nodes=removed,samples=len(rows),operation='Three actual original crown sections atY1.6 connect by 3D convex bridges to unequal existing lower-body patches. Body triangles assigned by actual outward-facing normal, tangent-width/depth bounds and nearest normalized local frame. Lowest35percent Y points form individual roots. Retire old lower frontage by .8m inward sampling, unite bridge volumes; feather belowY2.5 and aboveY-4.5. Upper density and cells unchanged from cap-corrected reconstruction. Not exact original preservation, a new source asset, or a player brush; native acceptance required.')
report['version']=VERSION
report['preserved_saved_node_y_at_or_above']=2.5 if VERSION=='v1' else 1.6
report['continuous_interpolation_may_reach_y']=2.5 if VERSION=='v1' else 1.75
report['sampling_note']='Core samples p+outward*.8, moving the zero surface inward. Upper preservation is a saved-node guarantee; it is not exact continuous-plane preservation.'
if VERSION!='v1':report['operation']=report['operation'].replace('belowY2.5','below the actual bridge capY1.6 (fadeY1.0–1.6)')
if VERSION=='v3':report['operation']+=' Two unequal local bisector clefts (halfwidth.12/.075, depth.55/.40) follow actual neighboring hull plane interfaces, reject near-parallel gradients<.25 and fade into the common core atY-3.4 and original crown atY1.6. Not an art acceptance.'
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print('CROWN ROOT BRIDGES:',json.dumps({k:v for k,v in report.items() if k!='hulls'}))
