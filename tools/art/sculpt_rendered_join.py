"""Offline local three-dimensional closing study of the retained island.

The drawn body is open/overlapping, so three analytic axis classifications
are deliberately combined by majority as a reconstruction, not exact CSG.
Closing is spatial and only changes concavities below the original crowns.
No production geometry, source model, or player brush is replaced.
"""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
sys.path.insert(0, '/tmp/yunlu-cliff-scipy')
from scipy.ndimage import distance_transform_edt

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/work/rendered_island/2026-10-17/complete'
BASE = ROOT / 'art/work/exposed_bedrock/2026-10-17'
OUT = ROOT / 'art/work/rendered_join/2026-10-17'
CAP_FIX = '--cap-fix' in sys.argv
if CAP_FIX:
    OUT = OUT / 'cap_fix'
OUT.mkdir(parents=True, exist_ok=True)
source = json.loads((SOURCE / 'source.json').read_text())
grid = json.loads((BASE / 'source.json').read_text())
triangles, groups = [], []
for i, component in enumerate(source['components']):
    blob = (SOURCE / component['path']).read_bytes()
    assert hashlib.sha256(blob.hex().encode()).hexdigest() == component['sha256_hex']
    t = np.frombuffer(blob, dtype='<f4').reshape(-1, 3, 3).astype(np.float64)[:, [0, 2, 1]]
    triangles.append(t)
    groups.extend([max(0, i - 5)] * len(t))
t = np.concatenate(triangles)
group = np.asarray(groups)
a = t[:, 0]
b = t[:, 1] - a
c = t[:, 2] - a
normal = np.cross(b, c)

# A padded fine grid; x,y,z ndarray order. Runtime samples remain .25m.
step = .125
lower = np.array([-23., -6.5, -4.])
upper = np.array([-7., 6.5, 10.])
coords = [np.arange(lower[k], upper[k] + step / 2, step) for k in range(3)]
votes = np.zeros(tuple(len(x) for x in coords), dtype=np.uint8)
flat_cap = np.zeros((len(coords[0]), len(coords[2])), dtype=bool)
negative_columns = []
for axis in range(3):
    uax, vax = [k for k in range(3) if k != axis]
    den = b[:, uax] * c[:, vax] - b[:, vax] * c[:, uax]
    active = np.abs(den) > 1e-10
    projected_lo, projected_hi = t.min(axis=1), t.max(axis=1)
    negatives = 0
    for iu, raw_u in enumerate(coords[uax]):
        # Break shared-edge ties consistently without skipping near surfaces.
        u = raw_u + 1.37e-6
        strip = np.where(active & (projected_lo[:, uax] <= u) & (projected_hi[:, uax] >= u))[0]
        for iv, raw_v in enumerate(coords[vax]):
            v = raw_v + 2.91e-6
            ids = strip[(projected_lo[strip, vax] <= v) & (projected_hi[strip, vax] >= v)]
            aa, bb, cc, dd = a[ids], b[ids], c[ids], den[ids]
            uu = ((u-aa[:, uax])*cc[:, vax]-(v-aa[:, vax])*cc[:, uax])/dd
            vv = (bb[:, uax]*(v-aa[:, vax])-bb[:, vax]*(u-aa[:, uax]))/dd
            hit = (uu >= 0) & (vv >= 0) & (uu+vv <= 1)
            heights = (aa[:, axis]+uu*bb[:, axis]+vv*cc[:, axis])[hit]
            ids = ids[hit]
            if axis == 1 and len(heights):
                flat_cap[iu,iv] = abs(float(heights.max())-3.5) < 1e-5
            inside = np.zeros(len(coords[axis]), dtype=bool)
            for g in np.unique(group[ids]):
                mask = group[ids] == g
                wind = ((heights[mask, None] > coords[axis][None, :]+1e-7) * np.sign(normal[ids[mask], axis, None])).sum(axis=0)
                negatives += int(np.any(wind < 0))
                inside |= wind > 0
            key = [slice(None)] * 3
            key[uax], key[vax] = iu, iv
            votes[tuple(key)] += inside
    negative_columns.append(negatives)
    print('AXIS COMPLETE:', axis, 'negative-winding columns', negatives, flush=True)

inside = votes >= 2
np.save(OUT / 'votes.npy', votes)
def sdf(mask):
    # Center-sampled Euclidean signed distance; the midpoint locates the skin.
    outside = distance_transform_edt(~mask)
    interior = distance_transform_edt(mask)
    return np.where(mask, -(interior-.5)*step, (outside-.5)*step)

raw_sdf = sdf(inside)
radius = 1.25 if CAP_FIX else .625
dilated = distance_transform_edt(~inside)*step <= radius
closed = distance_transform_edt(dilated)*step > radius
# Preserve input at the cropped boundary rather than delete rock there.
# The cap-fix radius exceeds the minimum XZ padding (.25m beyond the 1m
# margin), so finite-domain influence is not proven absent near the feather.
closed |= inside
closed_sdf = sdf(closed)
np.save(OUT / 'raw_sdf.npy', raw_sdf)
np.save(OUT / 'closed_sdf.npy', closed_sdf)

def ease(lo, hi, x):
    v = np.clip((x-lo)/(hi-lo), 0., 1.)
    return v*v*(3-2*v)

lo, hi = grid['lo'], grid['hi']
nx, ny, nz = [hi[k]-lo[k]+1 for k in range(3)]
base = np.fromfile(BASE / 'base_nodes.bin', dtype='<f4').reshape(nz, ny, nx).astype(np.float64)
payload = json.loads((SOURCE / 'rendered_body_complete.json').read_text())
original = base.copy()
for row in payload['rocks']:
    original[row['z']-lo[2], row['y']-lo[1], row['x']-lo[0]] = row['density']
reports = {}
for version in ['raw', 'closed']:
    values = original.copy()
    modified, added = 0, 0
    for iz in range(nz):
        z = (lo[2]+iz)*.25
        for ix in range(nx):
            x = (lo[0]+ix)*.25
            weight = ease(-22, -20.5, x)*(1-ease(-10, -8, x))*ease(-3, -1, z)*(1-ease(7.5, 9, z))
            if weight <= 0:
                continue
            for iy in range(ny):
                y = (lo[1]+iy)*.25
                index = tuple(np.rint((np.array([x,y,z])-lower)/step).astype(int))
                candidate = raw_sdf[index]
                if version == 'closed':
                    # Leave the whole crown/ground zone unchanged between studies.
                    w = ease(-4.5, -3.5, y)*(1-ease(1.4, 2.5, y))
                    candidate = candidate*(1-w)+closed_sdf[index]*w
                    added += int(closed_sdf[index] < raw_sdf[index]-1e-8 and w > 0)
                # Upper source cap ties must not make a checkerboard roof.
                if abs(y-3.5) < 1e-6 and inside[index] == 0 and votes[index] >= 1 and abs(candidate) <= .13:
                    candidate = .002
                if CAP_FIX and flat_cap[index[0],index[2]] and 3.0 <= y <= 3.75:
                    # Use the actual highest original source section. This
                    # fixes center-sampled EDT cap shrink, not a new grey lip.
                    candidate = y-3.5 if y < 3.5 else max(.002,y-3.5)
                candidate = float(np.clip(candidate, -.5, .5))
                value = round(original[iz,iy,ix]*(1-weight)+candidate*weight, 5)
                if abs(value) < .002:
                    value = .002 if value >= 0 else -.002
                values[iz,iy,ix] = value
                modified += int(value != original[iz,iy,ix])
    rows = [dict(x=int(lo[0]+ix), y=int(lo[1]+iy), z=int(lo[2]+iz), density=round(float(values[iz,iy,ix]), 5)) for iz,iy,ix in np.argwhere(abs(values-base) > 1e-6)]
    p = dict(payload, rocks=rows)
    dest = OUT / f'join_{version}.json'
    dest.write_text(json.dumps(p, separators=(',', ':'))+'\n')
    reports[version] = dict(samples=len(rows), changed_complete_nodes=modified, lower_closing_nodes=added, sha256=hashlib.sha256(dest.read_bytes()).hexdigest())
report = dict(source_sha256=hashlib.sha256((SOURCE/'source.json').read_bytes()).hexdigest(), step=step, lower=lower.tolist(), upper=upper.tolist(), ambiguous_nodes=int(np.count_nonzero((votes>0)&(votes<3))), total_nodes=votes.size, negative_winding_columns=negative_columns, closing_radius=radius, added_fine_nodes=int(np.count_nonzero(closed & ~inside)), versions=reports, operation='Three exact analytic axis intersections of the original grouped body and closed crown/outcrop surfaces; majority vote reconstructs the imperfect draw input. True spatial Euclidean closing, only blended below Y2.5. Not an exact CSG or original-shape-preservation claim. No profile extrusion/source stretch/model overlay. Ordinary v4 editable files, unchanged cells; unaccepted until native comparison.')
report['flat_cap_distance_fix'] = CAP_FIX
report['source_flat_cap_columns'] = int(flat_cap.sum())
(OUT/'report.json').write_text(json.dumps(report, indent=2)+'\n')
print('RENDERED JOIN STUDY:', json.dumps(report))
