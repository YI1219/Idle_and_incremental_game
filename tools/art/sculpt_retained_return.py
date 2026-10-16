"""Local lower-return shape study on the retained complete-source density.

Uses actual upper and lower cross-sections, not added rock instances. Rejected
unless native comparison establishes an improvement; no runtime tool change.
"""
import hashlib,json
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/work/rendered_island/2026-10-17/complete'
BASE=ROOT/'art/work/exposed_bedrock/2026-10-17'
source=json.loads((OUT/'source.json').read_text())
payload=json.loads((OUT/'rendered_body_complete.json').read_text())
grid=json.loads((BASE/'source.json').read_text());lo,hi,step=grid['lo'],grid['hi'],grid['step']
nx,ny,nz=[hi[k]-lo[k]+1 for k in range(3)]
nodes=np.fromfile(BASE/'base_nodes.bin',dtype='<f4').reshape(nz,ny,nx).astype(np.float64)
original=nodes.copy()
for row in payload['rocks']:nodes[row['z']-lo[2],row['y']-lo[1],row['x']-lo[0]]=row['density']
tris=np.concatenate([np.fromfile(OUT/c['path'],dtype='<f4').reshape(-1,3,3) for c in source['components']]).astype(np.float64)
a=tris[:,0];b=tris[:,1]-a;c=tris[:,2]-a;den=b[:,0]*c[:,1]-b[:,1]*c[:,0]
valid=np.abs(den)>1e-10;a=a[valid];b=b[valid];c=c[valid];den=den[valid]
def front(x,y):
 u=((x-a[:,0])*c[:,1]-(y-a[:,1])*c[:,0])/den
 v=(b[:,0]*(y-a[:,1])-b[:,1]*(x-a[:,0]))/den
 valid=(u>=-1e-9)&(v>=-1e-9)&(u+v<=1+1e-9)
 z=(a[:,2]+u*b[:,2]+v*c[:,2])[valid]
 return float(z.max()) if len(z) else None
def ease(a,b,v):
 t=max(0,min(1,(v-a)/(b-a)));return t*t*(3-2*t)
sections={};changed=0
for ix in range(nx):
 x=(lo[0]+ix)*step
 wx=ease(-20,-18.5,x)*(1-ease(-12,-10.5,x))
 if wx<=0:continue
 upper,lower=front(x,1.5),front(x,-3.5)
 if upper is None or lower is None or upper-lower<.2:continue
 sections[str(x)]=[upper,lower]
 for iy in range(ny):
  y=(lo[1]+iy)*step
  wy=ease(-3.5,-2.75,y)*(1-ease(1,1.5,y))
  if wy<=0:continue
  t=(1.5-y)/5;target=upper-(upper-lower)*t**1.4
  for iz in range(nz):
   z=(lo[2]+iz)*step
   w=wx*wy*ease(lower-1,lower,z)*(1-ease(7.5,9,z))
   if w<=0:continue
   old=nodes[iz,iy,ix];new=round(old*(1-w)+max(-.5,min(.5,z-target))*w,5)
   if abs(new)<.002:new=.002 if new>=0 else -.002
   if new!=old:changed+=1;nodes[iz,iy,ix]=new
rows=[]
for iz,iy,ix in np.argwhere(np.abs(nodes-original)>1e-6):
 rows.append({'x':int(lo[0]+ix),'y':int(lo[1]+iy),'z':int(lo[2]+iz),'density':round(float(nodes[iz,iy,ix]),5)})
payload['rocks']=rows;p=OUT/'retained_return_v1.json';p.write_text(json.dumps(payload,separators=(',',':'))+'\n')
report={'samples':len(rows),'changed_existing_nodes':changed,'save_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
 'input_save_sha256':hashlib.sha256((OUT/'rendered_body_complete.json').read_bytes()).hexdigest(),'sections':sections,
 'operation':'Bounded lower front replacement between actual complete-source front sections atY1.5 andY-3.5, inward t^1.4 return; feathered endpoints and upper/lower joins. Ground, upper rock faces and source high outcrops untouched by this operation. No added instances or new player brush.',
 'stage':'Unaccepted local shape study; native comparison required.'}
(OUT/'retained_return_report_v1.json').write_text(json.dumps(report,indent=2)+'\n')
print('RETAINED RETURN:',json.dumps(report))
