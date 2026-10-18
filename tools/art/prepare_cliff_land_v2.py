"""Sample the preserved second Tripo master for a bounded native contact proof."""
import hashlib
import importlib.util
import json
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'art/work/cliff_land_v2/2026-10-18/contact'
SOURCE = OUT.parent/'new.bin'


def run():
    OUT.mkdir(parents=True, exist_ok=True)
    original = SOURCE.read_bytes()
    points = np.frombuffer(original, dtype='<f4').reshape(-1, 3).astype(float)
    points *= 11.0/6.5
    shift = 3.25-float(points[:, 1].max())
    points[:, 1] += shift
    points = points.astype('<f4').astype(float)
    points.astype('<f4').tofile(OUT/'master_source.bin')
    spec = importlib.util.spec_from_file_location('land_sampler', ROOT/'tools/art/sample_tripo_master.py')
    sampler = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(sampler)
    records, report = sampler.sample_geometry(points)
    (OUT/'samples.json').write_text(json.dumps(records, separators=(',', ':'))+'\n')
    report.update({'source_sha256':hashlib.sha256(original).hexdigest(),
                   'trial_points_sha256':hashlib.sha256((OUT/'master_source.bin').read_bytes()).hexdigest(),
                   'uniform_scale_from_6_5m':11.0/6.5,'translation_y':shift,
                   'scope':'Unchanged second Tripo source, rigid alignment/uniform11m width/upper peak3.25; production .25m samples. No shape edits, arbitrary contour compiler, grass or editor acceptance.'})
    assert SOURCE.read_bytes() == original
    (OUT/'source_report.json').write_text(json.dumps(report, indent=2)+'\n')
    print('LAND SOURCE:', json.dumps(report), flush=True)


if __name__ == '__main__':run()
