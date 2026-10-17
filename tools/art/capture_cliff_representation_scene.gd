extends 'res://tests/capture_rim_round.gd'
const DIR='res://art/work/cliff_representation/2026-10-17/'
const Probe=preload('res://tools/art/probe_cliff_manifold.gd')
var cap_counts:Dictionary={}
func side_mesh(shape:String)->ArrayMesh:
 var points:PackedVector3Array=Probe.read_points(DIR+shape+'.bin')
 var sides:=PackedVector3Array();var omitted:=0
 for i in range(0,points.size(),3):
  var a:Vector3=points[i];var b:Vector3=points[i+1];var c:Vector3=points[i+2]
  # Production crowns expose walls only; their closed boolean-input lids
  # must not be drawn coplanar with the unchanged authoritative grass cap.
  if maxf(absf(a.y-3.5),maxf(absf(b.y-3.5),absf(c.y-3.5)))<.0001 and absf((b-a).cross(c-a).normalized().y)>.99999:
   omitted+=1;continue
  sides.append_array(PackedVector3Array([a,b,c]))
 cap_counts[shape]={'lid_triangles_not_drawn':omitted,'side_triangles_drawn':sides.size()/3}
 return preload('res://scripts/terrain_editor/stone_normals.gd').soften(Probe.mesh_from_points(sides),65.0,1.0)
func run():
 OUT='res://art/review/terrain_fidelity/2026-10-17/cliff_representation/'
 viewport=SubViewport.new();viewport.size=Vector2i(1671,941);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 editor=load('res://scenes/terrain_editor.tscn').instantiate();viewport.add_child(editor)
 editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
 for spec in [['water','water_time'],['lake_bed','caustic_time'],['waterfall','flow_time'],['bank','foam_time']]:editor.renderer.materials[spec[0]].set_shader_parameter(spec[1],1.25)
 var data_hash:String=JSON.stringify(editor.data.serialize()).sha256_text()
 var targets:Array=[]
 for index in [36,37,38]:
  var col:Dictionary=editor.renderer.decoration._columns[index]
  targets.append({'kind':col.kind,'pose':col.pose*editor.renderer.decoration.assets[col.kind][0].pose})
 var slots:Array=[]
 for chunk:Node in editor.renderer.chunks.values():
  for node:Node in chunk.get_children():
   if not node is MultiMeshInstance3D or not str(node.name).begins_with('cliff_column'):continue
   for i in node.multimesh.instance_count:
    var pose:Transform3D=node.multimesh.get_instance_transform(i)
    for target:Dictionary in targets:
     if str(node.name).begins_with(target.kind+'_') and pose.is_equal_approx(target.pose):slots.append([node,i,pose])
 assert(slots.size()==3,'Must isolate exactly the three original source instances')
 var replacement:=MeshInstance3D.new();replacement.visible=false;viewport.add_child(replacement)
 var material:=ShaderMaterial.new();material.shader=preload('res://tools/art/cliff_probe_contact.gdshader');preload('res://scripts/terrain_editor/material_detail.gd').bind(material);replacement.material_override=material
 for shape:String in ['original','assembly','union','sampled']:
  for slot:Array in slots:
   var pose:Transform3D=slot[2]
   if shape!='original':pose.basis=Basis.from_scale(Vector3.ONE*.000001)
   slot[0].multimesh.set_instance_transform(slot[1],pose)
  replacement.visible=shape!='original'
  if replacement.visible:replacement.mesh=side_mesh(shape)
  frame(Vector2(-14,4),8,16,30);await capture('scene_'+shape+'_close')
  editor.camera.position=Vector3(-12.4,7.1,11.0);editor.camera.look_at(Vector3(-14.5,3.0,3.3));await capture('scene_'+shape+'_grass')
  editor.camera.position=Vector3(-27,7,-7);editor.camera.look_at(Vector3(-15,2.5,3));await capture('scene_'+shape+'_reverse')
  frame(Vector2(0,-1),32,16,27);await capture('scene_'+shape+'_far')
 assert(data_hash==JSON.stringify(editor.data.serialize()).sha256_text())
 FileAccess.open(OUT+'scene_captures.json',FileAccess.WRITE).store_string(JSON.stringify({'captures':captures,'replaced_source_instances':slots.size(),'cap_draw_controls':cap_counts,'authoritative_data_sha256':data_hash,'unchanged_authoritative_data':true,'water_phase':1.25,'scope':'Tool-only replacement of three draw instances, same common material and crease normals across assembly/union/sampled. As with production walls, horizontal lids under authoritative grass are not drawn; all closed input/measurement geometry stays intact. Original includes production per-instance tone/shading, so is context only. Existing grass, backing, trees, buildings and props retained. No collision/picking/support/editor publication change or acceptance. Cloud/mist live.'},'\t'))
 print('CLIFF REPRESENTATION SCENE: ',captures.size(),' native frames, exactly3draw instances, data unchanged');quit()
