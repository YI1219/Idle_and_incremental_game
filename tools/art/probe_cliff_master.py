"""Route2: refine a preserved closed union, then measure density conversion.

No original geometry or official model is created. The preserved source is
linearly subdivided and deformed; source/control/original hashes stay intact.
Run in Blender for the BVH and a reviewable .blend copy.
"""
import bpy
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/work/pcg_fracture/2026-10-18/route2'
SOURCE = ROOT / 'art/work/cliff_representation/2026-10-17/union.bin'


def load_helper():
    spec = importlib.util.spec_from_file_location('master_sample', ROOT / 'tools/art/sample_cliff_representation.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def subdivide(tri):
    a, b, c = tri[:, 0], tri[:, 1], tri[:, 2]
    ab, bc, ca = (a+b)*.5, (b+c)*.5, (c+a)*.5
    return np.stack([np.stack(t, axis=1) for t in [(a, ab, ca), (ab, b, bc), (ca, bc, c), (ab, bc, ca)]]).reshape(-1, 3, 3)


def run():
    OUT.mkdir(parents=True, exist_ok=True)
    before = SOURCE.read_bytes()
    source_hash = hashlib.sha256(before).hexdigest()
    raw = np.frombuffer(before, dtype='<f4').reshape(-1, 3, 3).astype(float)
    raw += np.array([15., 0., -3.])
    raw.astype('<f4').tofile(OUT / 'master_source.bin')
    tri = subdivide(raw)
    p = tri.reshape(-1, 3).copy()
    x, y, z = p[:, 0].copy(), p[:, 1].copy(), p[:, 2].copy()
    depth = np.clip((3.5-y)/3.5, 0, 1)
    easing = depth*depth*(3-2*depth)
    p[:, 0] = x*(1-.24*easing)+.22*depth*np.sin(x*.65)
    p[:, 2] = z*(1-.20*easing)+.30*depth*(1-depth)*np.sin(x*.8)-.18*depth
    p[:, 1] = 3.5-(3.5-y)*(1.70+.22*np.sin(.63*x)+.10*np.sin(.9*z))
    # Keep all real original cap vertices exact, including translated XZ.
    cap = np.abs(y-3.5) < 1e-5
    assert np.array_equal(p[cap], tri.reshape(-1, 3)[cap])
    p.astype('<f4').tofile(OUT / 'master_warp.bin')
    sample = load_helper()
    points = [Vector(v) for v in p]
    tree = sample.tree_for(points)
    lo = np.floor((p.min(0)-.75)/.25).astype(int)
    hi = np.ceil((p.max(0)+.75)/.25).astype(int)
    rays = [Vector(v).normalized() for v in [(.8731,.3817,.3039),(-.429,.791,.436),(.265,-.413,.872)]]
    records, disagreements, crosschecks = [], [], 0
    for index, key in enumerate((x,y,z) for z in range(lo[2],hi[2]+1) for y in range(lo[1],hi[1]+1) for x in range(lo[0],hi[0]+1)):
        at = Vector(tuple(float(v)*.25 for v in key))
        distance = tree.find_nearest(at)[3]
        votes = []
        for direction in rays:
            origin, winding = at+direction*1e-6, 0
            for _ in range(128):
                hit = tree.ray_cast(origin,direction,100)
                if hit[0] is None:break
                dot = hit[1].dot(direction)
                winding += (dot>1e-6)-(dot< -1e-6)
                origin = hit[0]+direction*1e-5
            else:raise RuntimeError('master BVH traversal exhausted')
            votes.append(winding>0)
        if distance>1e-4 and (len(set(votes))>1 or index%127==0):
            exact = [sample.analytic_inside(p.reshape(-1,3,3),at,direction) for direction in rays]
            assert len(set(exact))==1, (list(at),exact)
            crosschecks += 1
            if len(set(votes))>1:disagreements.append({'point':list(at),'bvh':votes,'exact':exact})
            votes = exact
        value = round(max(-.5,min(.5,(-1 if sum(votes)>=2 else 1)*distance)),5)
        if abs(value)<.00001:value=.00002
        if value<.5:records.append(dict(x=int(key[0]),y=int(key[1]),z=int(key[2]),density=value))
    (OUT/'samples.json').write_text(json.dumps(records,separators=(',',':'))+'\n')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for label, values in [('source',raw.reshape(-1,3)),('candidate',p)]:
        vertices, faces = np.unique(values.astype('<f4'),axis=0,return_inverse=True)
        mesh = bpy.data.meshes.new(label)
        mesh.from_pydata(vertices.tolist(),[],faces.reshape(-1,3)[:,[0,2,1]].tolist());mesh.update()
        obj = bpy.data.objects.new(label,mesh);bpy.context.collection.objects.link(obj)
        obj.hide_viewport=label=='source';obj.hide_render=label=='source'
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'existing_master_refinement.blend'))
    report = {'source':str(SOURCE.relative_to(ROOT)),'source_sha256':source_hash,
              'control_triangles':len(raw),'candidate_triangles':len(p)//3,
              'translation':[15,0,-3],'subdivision':'one linear midpoint split before deformation',
              'cap_vertex_occurrences_preserved':int(cap.sum()),'sample_records':len(records),
              'grid_step':.25,'analytic_three_ray_crosschecks':crosschecks,'bvh_disagreements':disagreements,
              'candidate_bounds':[p.min(0).tolist(),p.max(0).tolist()],
              'scope':'Unaccepted master candidate from existing closed source; no new original model. Direct mesh and sampled density must be judged separately. No production integration, grass support or target art acceptance.'}
    assert SOURCE.read_bytes()==before
    (OUT/'master_report.json').write_text(json.dumps(report,indent=2)+'\n')
    print('MASTER SOURCE:',json.dumps(report),flush=True)


if __name__=='__main__':run()
