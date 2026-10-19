"""Blender: reproducibly sample an existing closed source, never invent geometry."""
import importlib.util
import json
import hashlib
import time
from pathlib import Path
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'art/work/volume_patch/2026-10-19'

def module(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result

def run():
    started = time.time()
    source = WORK / 'source.bin'
    points = np.fromfile(source, dtype='<f4').reshape(-1, 3).astype(float)
    sampler = module('volume_source_sampler', 'tools/art/sample_tripo_master.py')
    geometry = module('volume_source_topology', 'tools/art/sample_cliff_representation.py')
    topology = geometry.topology([Vector(v) for v in points])
    assert topology['non_two_use_edges'] == 0 and topology['signed_volume'] > 0, topology
    records, evidence = sampler.sample_geometry(points)
    low = np.floor((points.min(0) - .75) / .25).astype(int)
    high = np.ceil((points.max(0) + .75) / .25).astype(int)
    size = high - low + 1
    density = np.full((size[2], size[1], size[0]), .5, dtype='<f4')
    for record in records:
        density[record['z']-low[2], record['y']-low[1], record['x']-low[0]] = record['density']
    density.tofile(WORK / 'density.bin')
    evidence.update(low=low.tolist(), size=size.tolist(), input_topology=topology,
                    seconds=time.time()-started, source_triangles_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                    density_sha256=hashlib.sha256(density.tobytes()).hexdigest(),
                    bake_scope='Signed-distance conversion only. Existing material maps are reused; no high-poly normal bake has been made.')
    (WORK / 'sampling.json').write_text(json.dumps(evidence, indent=2)+'\n')
    print('VOLUME PATCH SAMPLE:', json.dumps(evidence), flush=True)

if __name__ == '__main__':
    run()
