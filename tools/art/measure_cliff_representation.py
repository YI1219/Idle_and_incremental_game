"""Finite geometry fidelity measurements, independent of viewport shading."""
import hashlib, importlib.util, json
from pathlib import Path
import numpy as np
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('cliff_sample',ROOT/'tools/art/sample_cliff_representation.py')
sample=importlib.util.module_from_spec(spec);spec.loader.exec_module(sample)
OUT=sample.OUT

def distribution(values):
    a=np.asarray(values)
    return {'count':len(a),'mean':float(a.mean()),'p95':float(np.quantile(a,.95)),'maximum_sampled':float(a.max())}

def probes(points):
    # Vertices, triangle centers and deterministic barycentric samples. This
    # is a measured sample error, not an exact Hausdorff-distance bound.
    p=np.asarray([list(p) for p in points]).reshape(-1,3,3)
    selected=p[::max(1,len(p)//4000)]
    result=np.concatenate([selected.reshape(-1,3),selected.mean(1),selected[:,0]*.2+selected[:,1]*.3+selected[:,2]*.5])
    return [Vector(p) for p in result]

def main():
    shapes={name:sample.read(name) for name in ['assembly','union','sampled','union_clip']}
    trees={name:sample.tree_for(p) for name,p in shapes.items()}
    topology={name:sample.topology(p) for name,p in shapes.items()}
    for name in ['union','sampled','union_clip']:
        t=topology[name]
        assert t['non_two_use_edges']==0 and t['directed_edge_pair_defects']==0 and t['degenerate_index_faces']==0 and len(t['vertex_components'])==1 and t['signed_volume']>0,(name,t)
    errors={}
    for source,target in [('union','sampled'),('sampled','union')]:
        errors[source+'_to_'+target]=distribution([trees[target].find_nearest(p)[3] for p in probes(shapes[source])])
    # Source input contains buried overlap faces; compare only union's exposed
    # skin to assembly, never pretend assembly's internal triangles disappeared
    # because of reconstruction error.
    errors['union_to_assembly']=distribution([trees['assembly'].find_nearest(p)[3] for p in probes(shapes['union'])])
    print('PRECHECK SURFACE ERRORS:',json.dumps(errors))
    worst=sorted([(trees['assembly'].find_nearest(p)[3],list(p)) for p in probes(shapes['union'])],reverse=True)[:10]
    (OUT/'fidelity_diagnostic.json').write_text(json.dumps({'errors':errors,'worst_union_to_assembly':worst},indent=2)+'\n')
    # Native float meshes and float BVH nearest queries are not exact math.
    # Gate at 1mm and report the measured value, rather than call it bit-exact.
    assert errors['union_to_assembly']['maximum_sampled']<.001
    height_bytes_equal={name:hashlib.sha256((OUT/'height_maps'/name).read_bytes()).hexdigest()==hashlib.sha256((ROOT/'assets/textures/terrain'/name).read_bytes()).hexdigest() for name in ['stone_detail.png','ground_detail.png']}
    assert all(height_bytes_equal.values())
    report={'topology':topology,'surface_error_m':errors,'sampled_volume_change_fraction':topology['sampled']['signed_volume']/topology['union']['signed_volume']-1,'source_height_maps_regenerated_byte_identical':height_bytes_equal,'scope':'Finite local geometry samples; 1e-5 position weld for topology. Not global surface bounds, shape beauty, edit latency or target device acceptance.'}
    (OUT/'measurements.json').write_text(json.dumps(report,indent=2)+'\n');print('CLIFF REPRESENTATION MEASURE:',json.dumps(report))

if __name__=='__main__':main()
