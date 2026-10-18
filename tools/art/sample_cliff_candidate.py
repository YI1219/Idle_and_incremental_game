"""Convert one hash-verified finite candidate to ordinary production records."""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[2]


def run():
    parser=argparse.ArgumentParser()
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--gate',type=Path,required=True)
    parser.add_argument('--stage',required=True)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    original=args.source.read_bytes();digest=hashlib.sha256(original).hexdigest()
    gate=json.loads(args.gate.read_text())['stages'][args.stage]
    assert gate['finite_gate_passes'] and gate['source_sha256']==digest,'candidate has no current finite gate'
    points=np.frombuffer(original,dtype='<f4').reshape(-1,3).astype(float)
    shift=3.25-float(points[:,1].max());points[:,1]+=shift
    points=points.astype('<f4').astype(float);args.out.mkdir(parents=True,exist_ok=True)
    points.astype('<f4').tofile(args.out/'master_source.bin')
    spec=importlib.util.spec_from_file_location('candidate_sampler',ROOT/'tools/art/sample_tripo_master.py')
    sampler=importlib.util.module_from_spec(spec);spec.loader.exec_module(sampler)
    records,report=sampler.sample_geometry(points)
    # A signed1e-5 node produced a real8e-6m four-edge hole when the production
    # float32 mesher omitted two below-area-threshold triangles. Keep signs,
    # but regularize ONLY this new proof's near-zero stored densities. Shared
    # sampler/mesher and historical outputs remain unchanged.
    (args.out/'raw_samples.json').write_text(json.dumps(records,separators=(',',':'))+'\n')
    guards=[]
    for record in records:
        if abs(record['density'])<.0002:
            before=record['density'];record['density']=-.0002 if before<0 else .0002
            guards.append({'key':[record[k] for k in ['x','y','z']],'before':before,'after':record['density']})
    report.update({'original_source':str(args.source),'original_source_sha256':digest,'top_translation_y':shift,'sampled_source_sha256':hashlib.sha256((args.out/'master_source.bin').read_bytes()).hexdigest(),'scope':'One finite-gated actual source translated only to peak3.25, unchanged proportions, production.25m records. Not arbitrary contour generation or art acceptance.'})
    report['near_zero_sign_preserving_guard']={'minimum_absolute_density':.0002,'changed':guards,'reason':'Prevent real microscopic omitted faces at float32 area cutoff; finite gates rerun, not a general mesher robustness claim.'}
    (args.out/'samples.json').write_text(json.dumps(records,separators=(',',':'))+'\n')
    (args.out/'sampling.json').write_text(json.dumps(report,indent=2)+'\n')
    assert args.source.read_bytes()==original
    print('CANDIDATE SAMPLING:',json.dumps(report),flush=True)


if __name__=='__main__':run()
