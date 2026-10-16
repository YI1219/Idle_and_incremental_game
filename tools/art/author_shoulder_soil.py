"""Local authoritative topsoil lobes, connected to existing lawn and rock."""
import hashlib,json
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art/work/cliff_finish/2026-10-17'
BASE=ROOT/'art/work/exposed_bedrock/2026-10-17'
source=ROOT/'art/work/rendered_join/2026-10-17/exposed_cleft/exposed_cleft_v1.json'
anchors=WORK/'cluster_anchors.json'
payload=json.loads(source.read_text());groups=json.loads(anchors.read_text())['cluster_centers']
grid=json.loads((BASE/'source.json').read_text());lo,hi,step=grid['lo'],grid['hi'],grid['step'];nx,ny,nz=[hi[k]-lo[k]+1 for k in range(3)]
base=np.fromfile(BASE/'base_nodes.bin',dtype='<f4').reshape(nz,ny,nx).astype(float);old=base.copy()
for r in payload['rocks']:old[r['z']-lo[2],r['y']-lo[1],r['x']-lo[0]]=r['density']
values=old.copy();changed=0;used=0
support_y=round(3.0/step)-lo[1]
for iz in range(nz):
 for ix in range(nx):
  # Keep all fill within the existing Y3.0 solid-column footprint, rather
  # than create soil above open air outside the source island's shoulder.
  if old[iz,support_y,ix]>=0:continue
  p=np.array([(lo[0]+ix)*step,(lo[2]+iz)*step]);distance=np.inf
  for g in groups:
   a=np.array([g['x'],g['z']]);b=np.array([g['lawn_x'],g['lawn_z']]);edge=b-a
   t=np.clip((p-a)@edge/max(edge@edge,1e-12),0,1)
   distance=min(distance,float(np.linalg.norm(p-a-edge*t))-.30)
  if distance>=0:continue
  used+=1
  for iy in range(ny):
   y=(lo[1]+iy)*step
   if y<3.0 or y>3.5:continue
   # Vertical cap distances preserve a real flat top, instead of an EDT
   # interpolation grey bevel. This is volume fill, not green wall paint.
   candidate=max(y-3.5,2.95-y)
   if abs(candidate)<.002:candidate=.002 if candidate>=0 else -.002
   value=round(min(old[iz,iy,ix],candidate),5)
   if value!=old[iz,iy,ix]:values[iz,iy,ix]=value;changed+=1
rows=[dict(x=int(lo[0]+ix),y=int(lo[1]+iy),z=int(lo[2]+iz),density=round(float(values[iz,iy,ix]),5)) for iz,iy,ix in np.argwhere(abs(values-base)>1e-6)]
payload['rocks']=rows;dest=WORK/'shoulder_soil_v1.json';dest.write_text(json.dumps(payload,separators=(',',':'))+'\n')
report=dict(input_save_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),anchors_sha256=hashlib.sha256(anchors.read_bytes()).hexdigest(),save_sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),groups=len(groups),filled_columns=used,rounded_write_attempts=changed,changed_nodes=int(np.count_nonzero(abs(values-old)>1e-6)),added_sign_nodes=int(np.count_nonzero((old>0)&(values<0))),removed_sign_nodes=int(np.count_nonzero((old<0)&(values>0))),samples=len(rows),operation='Ordinary shared editable volume fill of14sparse .30m-radius XZ capsules from actual sloping shoulder groups to their nearby real lawn cap. FillY3.0..3.5 only where originalY3.0node is already solid. Fixed vertical cap distance keeps new upper plane at grade. Existing solids/upper rocks remain; no separate decorative ground, source asset or green side-paint. Quarter-grid result is unaccepted until actual native review. changed_nodes counts effective differences>1e-6; rounded_write_attempts also includes sub-threshold rounding of existing values.')
(WORK/'soil_report.json').write_text(json.dumps(report,indent=2)+'\n')
print('SHOULDER SOIL STUDY:',json.dumps(report))
