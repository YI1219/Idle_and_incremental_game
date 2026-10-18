"""One explicitly bounded repair/projection COPY; preserve returned original.

Local code geometry is the constraint, not a claim that Tripo accepted code.
Vertex distance bound does not prove triangle embedding; finite gate required.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/work/code_guided_result/2026-10-18'


def run():
    source=OUT/'new.bin';before=source.read_bytes()
    raw=np.frombuffer(before,dtype='<f4').reshape(-1,3)
    guide=np.fromfile(ROOT/'art/work/cliff_guides/2026-10-18/broad_turn_7301.bin',dtype='<f4').reshape(-1,3).astype(float)
    guide=(guide-(guide.min(0)+guide.max(0))*.5)*(11./np.ptp(guide[:,0]))
    guide.astype('<f4').tofile(OUT/'guide.bin')
    vertices,indices=np.unique(raw,axis=0,return_inverse=True)
    bm=bmesh.new();verts=[bm.verts.new(v) for v in vertices];bm.verts.ensure_lookup_table()
    for f in indices.reshape(-1,3):bm.faces.new([verts[i] for i in f[::-1]])
    boundary=[e for e in bm.edges if e.is_boundary];boundary_count=len(boundary)
    bmesh.ops.holes_fill(bm,edges=boundary,sides=0)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    if bm.calc_volume(signed=True)<0:bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
    mesh=bpy.data.meshes.new('closed_before_constraint');bm.to_mesh(mesh);bm.free()
    pre=np.array([[mesh.vertices[i].co[:] for i in list(p.vertices)[::-1]] for p in mesh.polygons],dtype='<f4')
    pre.tofile(OUT/'closed.bin')
    spec=importlib.util.spec_from_file_location('constraint_bvh',ROOT/'tools/art/sample_cliff_representation.py')
    helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
    tree=helper.tree_for([Vector(p) for p in guide])
    points=np.array([v.co[:] for v in mesh.vertices],float)
    distances=[];band=.15
    for i,p in enumerate(points):
        hit=tree.find_nearest(Vector(p));q=np.array(hit[0]);distance=float(np.linalg.norm(p-q));distances.append(distance)
        if distance>band:points[i]=q+(p-q)*(band/distance)
    tri=np.array([[points[i] for i in list(p.vertices)[::-1]] for p in mesh.polygons],dtype='<f4')
    tri.tofile(OUT/'constrained.bin')
    finite=np.isfinite(tri).all();assert finite
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name,p in [('returned',raw.reshape(-1,3,3)),('constrained',tri)]:
        values,faces=np.unique(p.reshape(-1,3),axis=0,return_inverse=True)
        data=bpy.data.meshes.new(name);data.from_pydata(values.tolist(),[],faces.reshape(-1,3)[:,[0,2,1]].tolist());data.update()
        obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
        obj.rotation_euler.x=np.pi/2;obj.hide_viewport=name=='returned';obj.hide_render=name=='returned'
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'guided_constraint_copy.blend'))
    assert source.read_bytes()==before
    report={'source_sha256':hashlib.sha256(before).hexdigest(),'boundary_edges_before':boundary_count,'triangles_closed':len(pre),'closed_sha256':hashlib.sha256((OUT/'closed.bin').read_bytes()).hexdigest(),'constrained_sha256':hashlib.sha256((OUT/'constrained.bin').read_bytes()).hexdigest(),'guide_uniform_width':11.,'guide_alignment':'Both bounding centers zero; guide uniformly normalized11mwidth','vertex_distance_band':band,'vertices_outside_band_before':sum(d>band for d in distances),'max_before_distance':max(distances),'scope':'One repaired/projected copy of returned model, vertices within.15m of canonical code surface. Does NOT prove triangle-distance bound, nonintersections, art or editor acceptance. Original unchanged.'}
    (OUT/'constraint.json').write_text(json.dumps(report,indent=2)+'\n');print('GUIDED CONSTRAINT:',json.dumps(report),flush=True)


if __name__=='__main__':run()
