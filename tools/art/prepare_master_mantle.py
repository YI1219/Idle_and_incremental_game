"""Bounded source-defined ground prototype, not a new original rock model.

Preserve source and earlier .25m outputs. Uniform11m strip uses existing source
major planes at roughly2m each. Emit source samples and measured upper heights;
the native probe builds its physical soil layer in the SAME editable records.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'art/work/master_mantle/2026-10-18'
SOURCE = ROOT/'art/work/cliff_master/2026-10-18/tripo_original.bin'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name,ROOT/path)
    module = importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module


def run():
    OUT.mkdir(parents=True,exist_ok=True)
    sampler = load('mantle_sampler','tools/art/sample_tripo_master.py')
    helper = load('mantle_ray','tools/art/sample_cliff_representation.py')
    raw = np.fromfile(SOURCE,dtype='<f4').reshape(-1,3).astype(float)
    # Meaningful regression: shared sampler extraction must preserve old records.
    previous, _ = sampler.sample_geometry(raw)
    old_file = SOURCE.parent/'samples.json'
    serialized = json.dumps(previous,separators=(',',':'))+'\n'
    assert serialized == old_file.read_text(),'original-model sampling changed'
    points = raw*2.0
    shift = 3.25-float(points[:,1].max())
    points[:,1] += shift
    points = points.astype('<f4').astype(float)
    points.astype('<f4').tofile(OUT/'master_source.bin')
    records, report = sampler.sample_geometry(points)
    (OUT/'samples.json').write_text(json.dumps(records,separators=(',',':'))+'\n')
    tree = helper.tree_for([Vector(p) for p in points])
    roof = []
    lo = np.floor((points.min(0)-.5)/.25).astype(int)
    hi = np.ceil((points.max(0)+.5)/.25).astype(int)
    for z in range(lo[2],hi[2]+1):
        for x in range(lo[0],hi[0]+1):
            hit = tree.ray_cast(Vector((x*.25,20,z*.25)),Vector((0,-1,0)),50)
            if hit[0] is not None:roof.append({'x':x,'z':z,'height':hit[0].y})
    (OUT/'roof.json').write_text(json.dumps(roof,separators=(',',':'))+'\n')
    report.update({'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                   'trial_points_sha256':hashlib.sha256((OUT/'master_source.bin').read_bytes()).hexdigest(),
                   'uniform_scale_from_5_5m_control':2.0,'translation_y':shift,
                   'old_sampler_records_byte_identical':True,'roof_nodes':len(roof),
                   'scope':'One source-defined strip at11mwidth, original proportions. Sampling regression retained. No claim of arbitrary cell-contour compiler or complete editor integration.'})
    (OUT/'source_report.json').write_text(json.dumps(report,indent=2)+'\n')
    print('MASTER MANTLE SOURCE:',json.dumps(report),flush=True)


if __name__=='__main__':run()
