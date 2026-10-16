"""Finite actual-skin connectivity evidence, separate from art acceptance."""
import json
import sys
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'art/work/cliff_volume/2026-10-16'
version = sys.argv[1] if len(sys.argv)>1 else 'v1'
vertices = np.fromfile(WORK/f'volume_{version}_skin.bin', dtype='<f4').reshape(-1,3)
assert np.isfinite(vertices).all() and len(vertices)%3 == 0
points, inverse = np.unique(vertices, axis=0, return_inverse=True)
triangles = inverse.reshape(-1,3)
parent = np.arange(len(points))
def find(i):
    while parent[i] != i:
        parent[i] = parent[parent[i]]
        i = parent[i]
    return i
for triangle in triangles:
    a, b, c = [find(int(i)) for i in triangle]
    parent[b] = a
    parent[c] = a
owners = np.array([find(i) for i in range(len(points))])
face_owners = owners[triangles[:,0]]
roots, counts = np.unique(face_owners, return_counts=True)
edges = np.sort(np.concatenate([triangles[:,[0,1]], triangles[:,[1,2]], triangles[:,[2,0]]]), axis=1)
_, incidence = np.unique(edges, axis=0, return_counts=True)
components = []
for root, count in sorted(zip(roots,counts), key=lambda pair:-pair[1]):
    subset = points[owners==root]
    components.append(dict(triangles=int(count), vertices=len(subset), lo=subset.min(axis=0).tolist(), hi=subset.max(axis=0).tolist()))
report = dict(version=version, triangles=len(triangles), vertices=len(points), components=components,
    non_two_use_edges=int((incidence!=2).sum()),
    scope='Exact actual source-skin vertices, before chunk clipping. Does not establish props, arbitrary edits, publication, performance or art acceptance.')
OUT=ROOT/'art/review/terrain_fidelity/2026-10-16/cliff_volume'
OUT.mkdir(parents=True,exist_ok=True)
(OUT/f'connectivity_{version}.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
