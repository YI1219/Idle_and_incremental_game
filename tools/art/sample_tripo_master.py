"""One bounded conversion of the downloaded source into production .25m densities.

Run in Blender after capture_tripo_master.gd exports aligned original triangles.
This samples source geometry; it does not create a new rock design.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/work/cliff_master/2026-10-18'


def sample_geometry(data):
    """Return ordinary .25m records without mutating the source or any files."""
    spec = importlib.util.spec_from_file_location('source_sample', ROOT / 'tools/art/sample_cliff_representation.py')
    sample = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(sample)
    tree = sample.tree_for([Vector(v) for v in data])
    lo = np.floor((data.min(0)-.75)/.25).astype(int)
    hi = np.ceil((data.max(0)+.75)/.25).astype(int)
    rays = [Vector(v).normalized() for v in [(.8731,.3817,.3039),(-.429,.791,.436),(.265,-.413,.872)]]
    records, disagreements, crosschecks = [], [], 0
    keys = ((x,y,z) for z in range(lo[2],hi[2]+1) for y in range(lo[1],hi[1]+1) for x in range(lo[0],hi[0]+1))
    for index, key in enumerate(keys):
        at = Vector(tuple(float(v)*.25 for v in key))
        distance = tree.find_nearest(at)[3]
        votes = []
        for ray in rays:
            origin, winding = at+ray*1e-6, 0
            for _ in range(128):
                hit = tree.ray_cast(origin,ray,100)
                if hit[0] is None: break
                dot = hit[1].dot(ray)
                winding += (dot>1e-6)-(dot< -1e-6)
                origin = hit[0]+ray*1e-5
            else: raise RuntimeError('source BVH traversal exhausted')
            votes.append(winding>0)
        if distance>1e-4 and (len(set(votes))>1 or index%41==0):
            exact = [sample.analytic_inside(data.reshape(-1,3,3),at,ray) for ray in rays]
            assert len(set(exact))==1, (list(at),exact)
            crosschecks += 1
            if len(set(votes))>1: disagreements.append({'point':list(at),'bvh':votes,'exact':exact})
            votes = exact
        value = round(max(-.5,min(.5,(-1 if sum(votes)>=2 else 1)*distance)),5)
        if abs(value)<.00001: value=.00002
        if value<.5: records.append(dict(x=int(key[0]),y=int(key[1]),z=int(key[2]),density=value))
    report = {'grid_step':.25,
              'sample_records':len(records),'analytic_three_ray_crosschecks':crosschecks,
              'bvh_disagreements_resolved':disagreements,'bounds':[data.min(0).tolist(),data.max(0).tolist()],
              'scope':'One original-model conversion; every grid node uses three BVH rays, disagreement/every41st crosschecked in float64. Not art, editing robustness or target-hardware acceptance.'}
    return records, report


def run():
    source = OUT / 'tripo_original.bin'
    data = np.fromfile(source, dtype='<f4').reshape(-1, 3).astype(float)
    records, report = sample_geometry(data)
    report['source_sha256'] = hashlib.sha256(source.read_bytes()).hexdigest()
    (OUT/'samples.json').write_text(json.dumps(records,separators=(',',':'))+'\n')
    (OUT/'sampling.json').write_text(json.dumps(report,indent=2)+'\n')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'art/source/cliff_master/2026-10-18/tripo/cliff_master_white_v1.glb'))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'tripo_original_inspection.blend'))
    print('TRIPO MASTER SAMPLE:',json.dumps(report),flush=True)


if __name__ == '__main__': run()
