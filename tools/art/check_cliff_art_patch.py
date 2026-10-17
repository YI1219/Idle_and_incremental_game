"""Blender finite checks for an existing-source art refinement."""
import importlib.util,json
from pathlib import Path
import numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'art/work/cliff_art_patch/2026-10-18'
def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'tools/art'/file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
sample=module('sample','sample_cliff_representation.py');cross=module('cross','check_cliff_dual_intersections.py')
def run():
    report={}
    for name in ['baseline','cage_36','cage_37','cage_38','cage','seated_36','seated_37','seated_38','seated']:
        file=OUT/(name+'.bin');p=np.fromfile(file,dtype='<f4').reshape(-1,3)
        topology=sample.topology([Vector(v) for v in p]);topology['vertex_link_defects']=cross.vertex_link_defects(p)
        intersections=cross.inspect_file(file)
        passed=all(topology[k]==0 for k in ['non_two_use_edges','directed_edge_pair_defects','degenerate_index_faces','vertex_link_defects']) and len(topology['vertex_components'])==1 and topology['signed_volume']>0 and intersections['strict_crossing_pairs_at_least']==0
        report[name]={'topology':topology,'intersections':intersections,'finite_gate_passes':passed};print(name,passed,topology,intersections['strict_crossing_pairs_at_least'],flush=True)
    (OUT/'geometry_checks.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':run()
