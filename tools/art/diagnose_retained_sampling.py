"""Locate repeated native BVH ray hits before changing this study's sampler."""
import importlib.util,json
from pathlib import Path
import numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art/work/retained_island/2026-10-18'
spec=importlib.util.spec_from_file_location('sample',ROOT/'tools/art/sample_cliff_representation.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
data=np.fromfile(WORK/'crown_00.bin',dtype='<f4').reshape(-1,3).astype(float)
tree=module.tree_for([Vector(v) for v in data])
lo=np.floor((data.min(0)-.75)/.25).astype(int);hi=np.ceil((data.max(0)+.75)/.25).astype(int)
rays=[Vector(v).normalized() for v in [(.8731,.3817,.3039),(-.429,.791,.436),(.265,-.413,.872)]]
for z in range(lo[2],hi[2]+1):
 for y in range(lo[1],hi[1]+1):
  for x in range(lo[0],hi[0]+1):
   at=Vector((x*.25,y*.25,z*.25))
   for ray in rays:
    origin=at+ray*1e-6;hits=[]
    for step in range(128):
     hit=tree.ray_cast(origin,ray,100)
     if hit[0] is None:break
     hits.append({'position':list(hit[0]),'face':hit[2],'distance':hit[3],'origin':list(origin)})
     origin=hit[0]+ray*1e-5
    else:
     report={'point':list(at),'ray':list(ray),'nearest_distance':tree.find_nearest(at)[3],'hits_first12':hits[:12],'hits_last3':hits[-3:],'float64_inside_votes':[module.analytic_inside(data.reshape(-1,3,3),at,r) for r in rays],'finding':'Native BVH ray traversal exhausted; exact traces recorded for diagnosis, no conversion accepted.'}
     (WORK/'sampling_failure.json').write_text(json.dumps(report,indent=2)+'\n')
     print(json.dumps(report),flush=True)
     raise SystemExit()
print('No repeated traversal reproduced')
