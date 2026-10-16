"""Tool-only source-plane normal transfer on the actual local-lead skin."""
import bmesh,hashlib,json,math
from array import array
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art/work/cliff_finish/2026-10-17'
SOURCE=ROOT/'art/work/rendered_island/2026-10-17/complete'
source=json.loads((SOURCE/'source.json').read_text())
points=[];triangles=[]
for c in source['components']:
    blob=(SOURCE/c['path']).read_bytes();assert hashlib.sha256(blob.hex().encode()).hexdigest()==c['sha256_hex']
    values=array('f');values.frombytes(blob)
    start=len(points);points.extend(tuple(values[i:i+3]) for i in range(0,len(values),3))
    triangles.extend((start+i,start+i+2,start+i+1) for i in range(0,len(values)//3,3))
tree=BVHTree.FromPolygons(points,triangles,all_triangles=True)
roots=ROOT/'art/work/rendered_join/2026-10-17/crown_roots/v2/report.json'
hulls=json.loads(roots.read_text())['hulls']
positions=array('f');positions.frombytes((WORK/'vertices.bin').read_bytes())
normals=array('f');normals.frombytes((WORK/'normals.bin').read_bytes())
assert len(positions)==len(normals)
result=array('f',normals);cache={};kinds={'original':0,'bridge':0};changed=0
def ease(a,b,v):
    t=max(0,min(1,(v-a)/(b-a)));return t*t*(3-2*t)
for i in range(0,len(positions),3):
    p=Vector(positions[i:i+3]);normal=Vector(normals[i:i+3])
    key=tuple(p)+tuple(normal)
    if key not in cache:
        new=normal;kind=None
        local=ease(-22,-20.5,p.x)*(1-ease(-10,-8,p.x))*ease(-3,-1,p.z)*(1-ease(7.5,9,p.z))*(1-ease(3.15,3.45,p.y))
        candidates=[]
        if local>.05:
            nearest=tree.find_nearest(p)
            if nearest[0] is not None and nearest[3]<.18 and nearest[1].dot(normal)>.72:
                candidates.append((nearest[3],nearest[1], 'original'))
            if p.y<1.0:
                for hull in hulls:
                    equations=hull['hull_equations']
                    scores=[sum(eq[k]*p[k] for k in range(3))+eq[3] for eq in equations]
                    j=max(range(len(scores)),key=scores.__getitem__);n=Vector(equations[j][:3])
                    if abs(scores[j])<.18 and n.dot(normal)>.72 and n.dot(Vector(hull['outward']))>.3:
                        candidates.append((abs(scores[j]),n,'bridge'))
        if candidates:
            distance,n,kind=min(candidates,key=lambda e:e[0])
            weight=.65*local*(1-ease(.025,.18,distance))*ease(.72,.94,n.dot(normal))
            new=normal.lerp(n,weight).normalized()
            if (new-normal).length<1e-6:kind=None
        cache[key]=(new,kind)
    new,kind=cache[key]
    if kind is not None:
        changed+=1;kinds[kind]+=1
        result[i:i+3]=array('f',new)
(WORK/'plane_normals.bin').write_bytes(result.tobytes())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
report=dict(vertices=len(positions)//3,normal_occurrences_changed=changed,unique_input_samples=len(cache),source_kind_counts=kinds,input_vertex_sha256=sha(WORK/'vertices.bin'),input_normal_sha256=sha(WORK/'normals.bin'),output_normal_sha256=sha(WORK/'plane_normals.bin'),original_source_sha256=sha(SOURCE/'source.json'),root_source_sha256=sha(roots),operation='Nearest real original triangle planes or exposed bridge halfspace planes, only within.18m and normal agreement>.72. Distance/angular confidence blends at most.65; cap fadeY3.15–3.45. Bridge transfer only belowY1 and facing its original outward frame. No density/vertices/colors/UV/material/decor change. Not a crease-angle sweep or geometry improvement claim; actual native isolation required.')
(WORK/'plane_report.json').write_text(json.dumps(report,indent=2)+'\n')
print('CLIFF SOURCE PLANES:',json.dumps(report))
