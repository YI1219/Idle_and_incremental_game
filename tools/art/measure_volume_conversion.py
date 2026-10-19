"""Blender read-only geometry diagnosis, not another art variant or bake."""
import hashlib
import json
from pathlib import Path
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/review/terrain_fidelity/2026-10-20/volume_diagnosis'
SOURCE = ROOT / 'art/work/volume_patch/2026-10-19/source.bin'

def read(path):
    return np.fromfile(path, dtype='<f4').reshape(-1, 3, 3).astype(float)

def tree(triangles):
    points = [Vector(p) for p in triangles.reshape(-1, 3)]
    return BVHTree.FromPolygons(points, [(i,i+2,i+1) for i in range(0,len(points),3)], all_triangles=True)

def distances(probes, target):
    values = np.array([target.find_nearest(Vector(p))[3] for p in probes])
    return {'samples':len(values),'mean_m':float(values.mean()),'p95_m':float(np.percentile(values,95)),
            'max_m':float(values.max()),'over_0125m':int(np.count_nonzero(values>.125))}

def run():
    converted = OUT/'converted_unedited.bin'
    source = read(SOURCE)
    output = read(converted)
    source_tree, output_tree = tree(source), tree(output)
    evidence = json.loads((ROOT/'art/work/volume_patch/2026-10-19/sampling.json').read_text())
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == evidence['source_triangles_sha256']
    source_probes = np.concatenate([np.unique(source.reshape(-1,3),axis=0), source.mean(axis=1)])
    output_probes = np.concatenate([np.unique(output.reshape(-1,3),axis=0), output.mean(axis=1)])
    report = {'source_triangles':len(source),'converted_triangles':len(output),
              'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              'converted_sha256':hashlib.sha256(converted.read_bytes()).hexdigest(),
              'source_to_converted':distances(source_probes,output_tree),
              'converted_to_source':distances(output_probes,source_tree),
              'scope':'Finite bidirectional vertex+triangle-centroid distances on unedited conversion. Not a continuous Hausdorff bound, normal-map comparison, user art acceptance or performance test. No source modified.'}
    (OUT/'conversion_distance.json').write_text(json.dumps(report,indent=2)+'\n')
    print('VOLUME CONVERSION DISTANCE:',json.dumps(report),flush=True)

if __name__ == '__main__':
    run()
