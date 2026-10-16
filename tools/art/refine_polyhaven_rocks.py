"""Inspect CC0 sources, then make conservative source-derived LOD copies.

No original geometry is synthesized. Any source holes remain explicit in the
report; these meshes are not accepted editable-volume templates yet.
"""
import bpy
import bmesh
import hashlib
import json
import sys
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art/work/polyhaven_rocks/2026-10-17'
slugs=sys.argv[1+sys.argv.index('--'):] if '--' in sys.argv else ['namaqualand_boulder_02','rock_face_02']
assert all(slug in ['namaqualand_boulder_02','rock_face_02','boulder_01'] for slug in slugs)
report_path=WORK/'refinement_report.json'
reports=[r for r in json.loads(report_path.read_text()) if r['slug'] not in slugs] if report_path.exists() else []
for slug in slugs:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    source=WORK/slug/(slug+'_geometry.gltf')
    bpy.ops.import_scene.gltf(filepath=str(source))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];assert len(objects)==1
    obj=objects[0];bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    lower=Vector([min(v.co[k] for v in bm.verts) for k in range(3)])
    upper=Vector([max(v.co[k] for v in bm.verts) for k in range(3)])
    before=dict(vertices=len(bm.verts),triangles=sum(len(f.verts)-2 for f in bm.faces),
        boundary_edges=sum(e.is_boundary for e in bm.edges),nonmanifold_edges=sum(not e.is_manifold for e in bm.edges),
        lower=list(lower),upper=list(upper),signed_volume=bm.calc_volume(signed=True))
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    decimate=obj.modifiers.new('Source silhouette reduction','DECIMATE')
    decimate.ratio=min(1,4000/before['triangles'])
    decimate.use_collapse_triangulate=True
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    bm=bmesh.new();bm.from_mesh(obj.data)
    # An open scan has no unambiguous outward volume. Preserve its source
    # winding here; recalculation can flip the visible shell inside-out.
    after=dict(vertices=len(bm.verts),triangles=sum(len(f.verts)-2 for f in bm.faces),
        boundary_edges=sum(e.is_boundary for e in bm.edges),nonmanifold_edges=sum(not e.is_manifold for e in bm.edges))
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    for polygon in obj.data.polygons:polygon.use_smooth=True
    obj.name=slug+'_study_4k';obj.data.materials.clear()
    blend=WORK/slug/(slug+'_study_4k.blend');glb=WORK/slug/(slug+'_study_4k.glb')
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_materials='NONE',export_animations=False)
    reports.append(dict(slug=slug,source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),before=before,after=after,
        blend=str(blend.relative_to(ROOT)),glb=str(glb.relative_to(ROOT)),glb_sha256=hashlib.sha256(glb.read_bytes()).hexdigest(),
        operation='Weld1e-6 and Blender collapse decimation toward4000triangles; preserve open-source face winding. Shape sources preserved; no backing invented or holes silently filled.',
        stage='Unaccepted neutral shape/LOD study; not a runtime asset or performance acceptance.'))
(WORK/'refinement_report.json').write_text(json.dumps(reports,indent=2)+'\n')
print('POLY HAVEN REFINEMENT:',json.dumps(reports))
