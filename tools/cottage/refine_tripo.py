"""Refine received Tripo cottage; source geometry retained, no replacement building."""
import bpy,bmesh,json,hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[2];OUT=R/'art/work/cottage';REV=R/'art/review/cottage/tripo_v01';SRC=R/'art/source/cottage/2026-09-20/tripo/cottage_raw_v01_with_color.glb'
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(SRC))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH');o.name='CottageTripoCandidate';bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
# Override timber geometry with one uniform matte color; keep Tripo roof/wall UVs.
m=bpy.data.materials.new('Timber_corrected');m.diffuse_color=(.12,.073,.045,1);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=m.diffuse_color;m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85;o.data.materials.append(m)
for name,color in [('Plaster_corrected',(.72,.67,.56,1)),('Stone_corrected',(.34,.34,.32,1))]:
 m=bpy.data.materials.new(name);m.diffuse_color=color;m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=color;m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9;o.data.materials.append(m)
bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
seen=set();cs=[]
for v in bm.verts:
 if v in seen:continue
 todo=[v];seen.add(v);vs=[]
 while todo:
  q=todo.pop();vs.append(q)
  for e in q.link_edges:
   w=e.other_vert(q)
   if w not in seen:seen.add(w);todo.append(w)
 cs.append(vs)
# Verify component identities against measured bounds before changing them.
assert len(cs)==32 and len(cs[0])==41
for i,vs in enumerate(cs):
 if i not in [0,1,15,16,17,21,22]:
  for f in {f for v in vs for f in v.link_faces}:f.material_index=1
for i,mi in [(0,2),(17,3),(22,3)]:
 for f in {f for v in cs[i] for f in v.link_faces}:f.material_index=mi;f.smooth=False
# Door jambs move outwards, existing lintel widens to match; retain source topology.
assert len(cs[5])==16 and len(cs[6])==16
for v in cs[5]:v.co.y-=.064
for v in cs[6]:v.co.y+=.067
for v in cs[4]:v.co.y=.102+(v.co.y-.102)*1.62
# Split only the wall shell at doorway sides/head/threshold then remove infill.
layer=bm.faces.layers.int.new('wall_selection')
wall_faces=set(f for v in cs[0] for f in v.link_faces)
for f in wall_faces:f[layer]=1
for co,no in [((0,-.030,0),(0,1,0)),((0,.238,0),(0,1,0)),((0,0,-.350),(0,0,1)),((0,0,-.0435),(0,0,1))]:
 fs=[f for f in bm.faces if f[layer]==1];es=set(e for f in fs for e in f.edges);vs=set(v for f in fs for v in f.verts)
 bmesh.ops.bisect_plane(bm,geom=list(vs)+list(es)+fs,plane_co=co,plane_no=no,dist=1e-7)
remove=[f for f in bm.faces if f[layer]==1 and f.calc_center_median().x>.25 and -.03001<f.calc_center_median().y<.23801 and -.35001<f.calc_center_median().z<-.04349]
assert remove,'No doorway infill found'
bmesh.ops.delete(bm,geom=remove,context='FACES')
# Ground level at existing plinth top, 6m max roof width. Front stays +X.
for v in bm.verts:v.co=Vector((v.co.x*6,v.co.y*6,(v.co.z+.3484)*6))
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.normal_update()
# Actual passage tests through the front wall, within widened clear opening.
bvh=BVHTree.FromBMesh(bm);blocked=[]
for y in [.03,.08,.13,.18]:
 for z in [.04,.10,.18,.27]:
  start=Vector((.46*6,y*6,z*6));hit=bvh.ray_cast(start,Vector((-1,0,0)),.35*6)
  if hit[0] is not None:blocked.append({'y':y*6,'z':z*6,'hit':list(hit[0])})
report={'source_sha256':hashlib.sha256(SRC.read_bytes()).hexdigest(),'removed_door_faces':len(remove),'triangles':len(bm.faces),'boundary_edges':sum(e.is_boundary for e in bm.edges),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),'passage_rays':16,'blocked_rays':blocked,'door_nominal_clear_width_m':1.608,'door_nominal_clear_height_m':1.8294,'status':'candidate_pending_visual_review_and_game_integration','notes':['Original wall shell is single-sided/open; no blanket hole filling.','No new visible primitives; only source mesh split, infill removal, jamb/lintel adjustment and material correction.']}
bm.to_mesh(o.data);bm.free();o.data.update()
o.data.set_sharp_from_angle(angle=.55)
mod=o.modifiers.new('Preserve broad surface normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=50
bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
OUT.mkdir(parents=True,exist_ok=True);bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
bpy.ops.export_scene.gltf(filepath=str(OUT/'cottage_tripo_candidate.glb'),export_format='GLB',use_selection=True)
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24;s.render.resolution_x=1000;s.render.resolution_y=850;s.render.resolution_percentage=100;s.world=bpy.data.worlds.new('World');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.3,.3,.3,1)
center=Vector((0,0,2.1))
for pos in [(8,-10,12),(-8,6,8)]:
 bpy.ops.object.light_add(type='AREA',location=pos);l=bpy.context.object;l.data.energy=2000;l.data.size=8;l.rotation_euler=(center-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();c=bpy.context.object;c.data.type='ORTHO';c.data.ortho_scale=8.5;s.camera=c
for name,pos in [('refined_front',(12,-16,10)),('refined_back',(-12,16,10)),('refined_door',(16,.65,2.0))]:
 c.location=pos;c.rotation_euler=(center-c.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(REV/f'{name}.png');bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cottage_tripo_candidate.blend'))
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(OUT/'cottage_tripo_candidate.glb'));ms=[o for o in bpy.context.scene.objects if o.type=='MESH'];assert len(ms)==1;report['reimport']={'mesh_count':len(ms),'materials':len(ms[0].data.materials),'dimensions':list(ms[0].dimensions)}
(REV/'refinement.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False));assert not blocked,'Door passage blocked'
