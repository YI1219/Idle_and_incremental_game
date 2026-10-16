"""Bounded cuts rooted in real exposed upper clefts, never hull interiors."""
import hashlib,json,sys
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art/work/rendered_join/2026-10-17'
OUT=WORK/'exposed_cleft';OUT.mkdir(exist_ok=True)
source=WORK/'crown_roots/v2/crown_roots_v2.json'
skin=WORK/'crown_roots/v2/crownroots2_skin.bin'
tri=np.fromfile(skin,dtype='<f4').reshape(-1,3,3).astype(float)
frames=json.loads((WORK/'crown_frames.json').read_text())
paths=[]
for pair,width,depth in [([38,37],.24,.42),([37,36],.18,.32)]:
    fa,fb=[frames[i] for i in pair]
    origin=(np.array([fa['edge'][0],0,fa['edge'][1]])+np.array([fb['edge'][0],0,fb['edge'][1]]))*.5
    out=np.array(fa['outward'])+fb['outward'];out/=np.linalg.norm(out)
    tangent=np.array([out[2],0,-out[0]])
    q=tri-origin
    u=q[:,:,1];v=q@tangent;o=q@out
    a=np.stack([u[:,0],v[:,0]],axis=1);b=np.stack([u[:,1]-u[:,0],v[:,1]-v[:,0]],axis=1);c=np.stack([u[:,2]-u[:,0],v[:,2]-v[:,0]],axis=1)
    den=b[:,0]*c[:,1]-b[:,1]*c[:,0];valid=abs(den)>1e-10
    a,b,c,den,o=a[valid],b[valid],c[valid],den[valid],o[valid]
    def front(y,along):
        uu=((y-a[:,0])*c[:,1]-(along-a[:,1])*c[:,0])/den
        vv=(b[:,0]*(along-a[:,1])-b[:,1]*(y-a[:,0]))/den
        hit=(uu>=-1e-9)&(vv>=-1e-9)&(uu+vv<=1+1e-9)
        heights=(o[:,0]+uu*(o[:,1]-o[:,0])+vv*(o[:,2]-o[:,0]))[hit]
        assert len(heights)
        return float(heights.max())
    alongs=np.linspace(-.7,.7,29);upper=np.array([front(2.5,s) for s in alongs]);residual=upper-np.linspace(upper[0],upper[-1],len(upper))
    at=int(np.argmin(residual[2:-2]))+2
    if residual[at]>-.05:
        print('NO DISTINCT UPPER CLEFT:',pair,float(residual[at]),flush=True)
        continue
    along=float(alongs[at]);rows=[]
    for y in np.arange(-3.25,1.501,.25):rows.append([float(y),front(float(y),along)])
    paths.append(dict(pair=pair,origin=origin.tolist(),outward=out.tolist(),tangent=tangent.tolist(),along=along,upper_y=2.5,upper_depth_vs_chord=float(residual[at]),upper_samples=np.stack([alongs,upper],axis=1).tolist(),halfwidth=width,depth=depth,front_rows=rows))
assert paths,'No grounded cleft was found; do not invent an arbitrary scar'
payload=json.loads(source.read_text());base_path=ROOT/'art/work/exposed_bedrock/2026-10-17';grid=json.loads((base_path/'source.json').read_text());lo,hi,step=grid['lo'],grid['hi'],grid['step'];nx,ny,nz=[hi[k]-lo[k]+1 for k in range(3)]
base=np.fromfile(base_path/'base_nodes.bin',dtype='<f4').reshape(nz,ny,nx).astype(float);values=base.copy()
for r in payload['rocks']:values[r['z']-lo[2],r['y']-lo[1],r['x']-lo[0]]=r['density']
original=values.copy();changed=0
def ease(a,b,v):
    t=np.clip((v-a)/(b-a),0,1);return t*t*(3-2*t)
for iz in range(nz):
 for ix in range(nx):
  x,z=(lo[0]+ix)*step,(lo[2]+iz)*step
  mask=ease(-22,-20.5,x)*(1-ease(-10,-8,x))*ease(-3,-1,z)*(1-ease(7.5,9,z))
  if mask<=0:continue
  for iy in range(ny):
   y=(lo[1]+iy)*step
   if y<=-3.25 or y>=1.5:continue
   p=np.array([x,y,z]);old=values[iz,iy,ix];new=old
   for path in paths:
    d=p-path['origin'];along=float(d@path['tangent'])-path['along']
    envelope=ease(-3.25,-2.6,y)*(1-ease(.8,1.5,y))
    width=path['halfwidth']*envelope
    if abs(along)>=width:continue
    front_value=path['front_rows'][int(round((y+3.25)/step))][1]
    cut=min(width-abs(along),path['depth']*envelope-(front_value-float(d@path['outward'])))
    new=max(new,old*(1-mask)+cut*mask)
   new=round(float(new),5)
   if abs(new)<.002:new=.002 if new>=0 else -.002
   if new!=old:values[iz,iy,ix]=new;changed+=1
rows=[dict(x=int(lo[0]+ix),y=int(lo[1]+iy),z=int(lo[2]+iz),density=round(float(values[iz,iy,ix]),5)) for iz,iy,ix in np.argwhere(abs(values-base)>1e-6)]
payload['rocks']=rows;dest=OUT/'exposed_cleft_v1.json';dest.write_text(json.dumps(payload,separators=(',',':'))+'\n')
report=dict(paths=paths,input_save_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),skin_sha256=hashlib.sha256(skin.read_bytes()).hexdigest(),save_sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),samples=len(rows),changed_nodes=changed,sign_nodes_removed=int(np.count_nonzero((original<0)&(values>0))),sign_nodes_added=int(np.count_nonzero((original>0)&(values<0))),operation='Locate an actual upper exposed-skin indentation atY2.5 between neighboring crown frames, require at least.05m depth below local chord. Follow the real frontmost skin intersection in its outward direction at each lower Y. Subtract unequal air-connected grooves only in that outer frontage, taper Y-3.25/-2.6 andY.8/1.5. No whole-hull/back interface carving. Protected upper saved nodes, not exact continuous upper-plane preservation. Unaccepted native study, no runtime feature.')
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print('EXPOSED CLEFT STUDY:',json.dumps({k:v for k,v in report.items() if k!='paths'}))
