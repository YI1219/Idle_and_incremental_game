"""Finite checks of native PCG meshes. Run with Blender Python.

No zero-crossing count establishes arbitrary edit robustness or art acceptance.
The existing detector excludes coplanar and shared-position pairs.
"""
import importlib.util
import json
from pathlib import Path
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'art/work/pcg_cliff/2026-10-18'


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tools/art' / filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def run():
    sample = module('pcg_sample', 'sample_cliff_representation.py')
    crossing = module('pcg_crossing', 'check_cliff_dual_intersections.py')
    report = {'scope': 'Finite 1e-5 position-weld topology/vertex-link checks and zero-epsilon BVH with float64 strict segment/triangle crossing checks. Shared-position and coplanar overlaps excluded. Not an exact global proof.', 'stages': {}}
    for stage in ['control', 'pcg_shape', 'pcg_seed7319', 'pcg_layout', 'pcg_carved']:
        file = WORK / f'{stage}.bin'
        if not file.exists():
            continue
        points = np.fromfile(file, dtype='<f4').reshape(-1, 3)
        topology = sample.topology([Vector(v) for v in points])
        topology['vertex_link_defects'] = crossing.vertex_link_defects(points)
        intersections = crossing.inspect_file(file)
        passed = (np.isfinite(points).all() and
                  all(topology[k] == 0 for k in ['non_two_use_edges', 'directed_edge_pair_defects', 'degenerate_index_faces', 'vertex_link_defects']) and
                  len(topology['vertex_components']) == 1 and topology['signed_volume'] > 0 and
                  intersections['strict_crossing_pairs_at_least'] == 0)
        report['stages'][stage] = {'topology': topology, 'crossings': intersections, 'finite_gate_passes': bool(passed)}
        print('PCG GEOMETRY', stage, passed, topology, 'crossings', intersections['strict_crossing_pairs_at_least'], flush=True)
        (WORK / 'geometry_checks.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    run()
