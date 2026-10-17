"""Read-only finite proper-crossing review. Run inside Blender's Python.

Reproduction:
  blender --background --factory-startup --python tools/art/check_cliff_dual_intersections.py

BVH provides candidates only. Float64 segment/triangle equations independently
confirm strict, non-coplanar interior crossings; pairs sharing a 1e-5-position
vertex are excluded. This is a lower bound, not a proof that other faces are safe.
"""
import hashlib,json
from pathlib import Path
import numpy as np
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
IN=ROOT/'art/work/cliff_dual/2026-10-17'
OUT=IN/'intersections.json'

def hit(a,b,tri):
    ray=b-a;e1=tri[1]-tri[0];e2=tri[2]-tri[0]
    h=np.cross(ray,e2);det=float(e1@h)
    if abs(det)<1e-12:return None
    s=a-tri[0];u=float(s@h/det);q=np.cross(s,e1)
    v=float(ray@q/det);t=float(e2@q/det)
    if min(u,v,t,1-t,1-u-v)>1e-7:
        return {'segment_fraction':t,'triangle_barycentric':[1-u-v,u,v],
                'position':list(map(float,a+t*ray))}
    return None

report={'method':'Blender zero-epsilon triangle BVH candidates; independent float64 strict Moller-Trumbore segment/triangle validation; excludes every pair sharing a position rounded to 5 decimals.',
        'strict_parameter_margin':1e-7,'determinant_threshold':1e-12,
        'scope':'Finite proper-crossing lower bound only. Adjacent, coplanar, near-touch and non-candidate pairs are not validated. Not an exhaustive exact-predicate self-intersection proof.',
        'stages':{}}
for stage in ['dc_field','dc_hermite','dc_field_edited','dc_hermite_edited','union','sampled','sampled_edited']:
    file=(ROOT/'art/work/cliff_representation/2026-10-17' if stage in ['union','sampled'] else IN)/(stage+'.bin')
    tris=np.fromfile(file,dtype='<f4').reshape(-1,3,3).astype(float)
    keys={};faces=[];rounded=[{tuple(v) for v in np.round(tri,5)} for tri in tris]
    for tri in tris:
        f=[]
        for v in tri:
            k=tuple(v);keys.setdefault(k,len(keys));f.append(keys[k])
        faces.append(f)
    tree=BVHTree.FromPolygons(list(keys),faces,all_triangles=True,epsilon=0)
    pairs=sorted({(min(i,j),max(i,j)) for i,j in tree.overlap(tree) if i!=j and not (rounded[i]&rounded[j])})
    proper=[]
    for i,j in pairs:
        hits=[]
        for k in range(3):
            for x,y in [(i,j),(j,i)]:
                found=hit(tris[x,k],tris[x,(k+1)%3],tris[y])
                if found is not None:
                    found.update({'edge_face':x,'edge_corner':k,'interior_face':y});hits.append(found)
        if hits:proper.append({'zero_based_faces':[i,j],'hits':hits})
    report['stages'][stage]={'mesh_sha256':hashlib.sha256(file.read_bytes()).hexdigest(),
        'triangles':len(tris),'disjoint_position_bvh_pairs':len(pairs),
        'strict_crossing_pairs_at_least':len(proper),'crossings':proper}
    print(stage,len(pairs),len(proper),flush=True)
OUT.write_text(json.dumps(report,indent=2)+'\n')
