"""Blender finite geometry gates; no screenshot can override a failed gate."""
import importlib.util,json
from pathlib import Path
import numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/work/cliff_kernel/2026-10-17'
def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'tools/art'/file)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
sample=module('cliff_sample','sample_cliff_representation.py')
cross=module('cliff_cross','check_cliff_dual_intersections.py')
measure=module('cliff_measure','measure_cliff_representation.py')
def run():
    report={'scope':'Finite1e-5position weld topology, vertex links and nonadjacent strict triangle crossings; zero detected crossings is not an exact/global self-intersection proof. Surface errors use deterministic triangle samples, not area weighting/global bounds.','stages':{}}
    original=sample.read('union');reference_tree=sample.tree_for(original)
    for file in sorted(OUT.glob('*.bin')):
        if not file.stem.startswith(('boundary','libfive_')):continue
        points=np.fromfile(file,dtype='<f4').reshape(-1,3)
        topology=sample.topology([Vector(p) for p in points]);topology['nonmanifold_vertex_links']=cross.vertex_link_defects(points)
        crossings=cross.inspect_file(file)
        accepted=all(topology[k]==0 for k in ['non_two_use_edges','directed_edge_pair_defects','degenerate_index_faces','nonmanifold_vertex_links']) and len(topology['vertex_components'])==1 and topology['signed_volume']>0 and crossings['strict_crossing_pairs_at_least']==0
        entry={'topology':topology,'crossings':crossings,'finite_geometry_gate_passes':accepted}
        if not file.stem.endswith('_edited'):
            tree=sample.tree_for([Vector(p) for p in points])
            entry['source_to_result_m']=measure.distribution([tree.find_nearest(p)[3] for p in measure.probes(original)])
            entry['result_to_source_m']=measure.distribution([reference_tree.find_nearest(p)[3] for p in measure.probes(points)])
        report['stages'][file.stem]=entry
        print('KERNEL VALIDATION',file.stem,accepted,topology['triangles'],crossings['strict_crossing_pairs_at_least'],flush=True)
        (OUT/'geometry_validation.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':run()
