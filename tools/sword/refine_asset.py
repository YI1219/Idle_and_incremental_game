"""Refine the user's Tripo original; never constructs replacement geometry."""
from pathlib import Path
import bpy,bmesh,json,math,hashlib
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'art/source/sword/2026-09-20/tripo/jian_3d_model.glb'
WORK=ROOT/'art/work/sword';REVIEW=ROOT/'art/review/sword'
WORK.mkdir(parents=True,exist_ok=True);REVIEW.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SRC))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH');o.name='StarterJian';bpy.context.view_layer.objects.active=o;o.select_set(True)
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bm=bmesh.new();bm.from_mesh(o.data)
before={'vertices':len(bm.verts),'faces':len(bm.faces),'boundary_edges':sum(e.is_boundary for e in bm.edges)}
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
boundary=[e for e in bm.edges if e.is_boundary]
filled=bmesh.ops.holes_fill(bm,edges=boundary,sides=0)['faces']
# A concave planar guard socket is skipped by holes_fill; triangulate its rim.
remaining=[e for e in bm.edges if e.is_boundary]
if remaining:
 bmesh.ops.triangle_fill(bm,edges=remaining,use_beauty=True)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
bmesh.ops.triangulate(bm,faces=list(bm.faces))
# Material bands follow existing blade/guard/grip geometry in source Z.
for f in bm.faces:
 z=f.calc_center_median().z
 f.material_index=0 if z>.28 else (2 if .058<z<.198 else 1)
# Model length 0.90m; origin at center of existing grip; blade +Z authoring.
rot=Matrix.Rotation(math.pi/2,3,'Z');scale=.90/.99951171875
for v in bm.verts:v.co=rot@(v.co-Vector((0,0,.128)))*scale
bm.normal_update()
after={'vertices':len(bm.verts),'triangles':len(bm.faces),'boundary_edges':sum(e.is_boundary for e in bm.edges),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),'degenerate_faces':sum(f.calc_area()<1e-12 for f in bm.faces)}
print('POST_REPAIR',after,flush=True)
assert after['boundary_edges']==0 and after['nonmanifold_edges']==0 and after['degenerate_faces']==0
bm.to_mesh(o.data);bm.free();o.data.update()
material_indices=[p.material_index for p in o.data.polygons]
o.data.materials.clear()
for name,color,metal,rough in [('Blade',(.28,.38,.49,1),.35,.42),('MutedJade',(.12,.28,.24,1),.1,.65),('CharcoalGrip',(.045,.055,.061,1),0,.9)]:
 m=bpy.data.materials.new(name);m.diffuse_color=color;m.use_nodes=True;n=m.node_tree.nodes.get('Principled BSDF');n.inputs['Base Color'].default_value=color;n.inputs['Metallic'].default_value=metal;n.inputs['Roughness'].default_value=rough;o.data.materials.append(m)
for p,mi in zip(o.data.polygons,material_indices):
 p.use_smooth=False;p.material_index=mi
bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
export=WORK/'sword_candidate.glb';bpy.ops.export_scene.gltf(filepath=str(export),export_format='GLB',use_selection=True,export_apply=True)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=700;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('ReviewWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.18,.21,1)
center=Vector((0,0,(.5-.128)*scale))
for pos,power in [((2,-3,3),260),((-2,-1,1),140)]:
 bpy.ops.object.light_add(type='AREA',location=pos);l=bpy.context.object;l.data.energy=power;l.data.size=3;l.rotation_euler=(center-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();c=bpy.context.object;c.data.type='ORTHO';c.data.ortho_scale=1.04;scene.camera=c
for name,direction in [('front',(0,-3,0)),('back',(0,3,0)),('oblique',(1.5,-3,.15))]:
 c.location=center+Vector(direction);c.rotation_euler=(center-c.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(REVIEW/f'candidate_{name}.png');bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'sword_candidate.blend'))
# Reimport exported file in a clean scene to confirm transport, materials, dimensions.
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(export));meshes=[x for x in bpy.context.scene.objects if x.type=='MESH'];assert len(meshes)==1
x=meshes[0];assert len(x.data.materials)==3
assert abs(max(x.dimensions)-.90)<.0001
report={'source':str(SRC.relative_to(ROOT)),'source_sha256':hashlib.sha256(SRC.read_bytes()).hexdigest(),'before':before,'after':after,'holes_fill_caps':len(filled),'additional_concave_rim_edges':len(remaining),'length_m':.90,'authoring_axis':'Blender +Z blade; origin at grip center. GLB exports blade +Y.','materials':'Three constant PBR color blocks; no image textures needed for this candidate.','reimport':{'meshes':len(meshes),'materials':len(x.data.materials),'dimensions':list(x.dimensions)},'status':'refined_candidate_not_yet_integrated_or_animated','limitations':['Separate original mesh shells capped; no boolean union or self-intersection proof.','Hand fitting and gameplay silhouette still need runtime review.']}
(REVIEW/'refinement_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False))
