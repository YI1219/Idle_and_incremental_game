extends SceneTree
## Mature installed Manifold reference: existing mesh minus a bounded half-ball.
const OUT='res://art/work/cliff_kernel/2026-10-17/'
const SOURCE='res://art/work/cliff_representation/2026-10-17/union.bin'
const Probe=preload('res://tools/art/probe_cliff_manifold.gd')
var source_mesh:ArrayMesh
func _initialize():call_deferred('run')
func rebuild(commands:Array)->CSGCombiner3D:
 var combined:=CSGCombiner3D.new();root.add_child(combined)
 var source:=CSGMesh3D.new();source.mesh=source_mesh;combined.add_child(source)
 for command:Dictionary in commands:
  var values:Array=command.center;var center:=Vector3(values[0],values[1],values[2]);var radius:float=command.radius
  if command.tool=='rock_plane':
   var brush:=CSGCombiner3D.new();brush.operation=CSGShape3D.OPERATION_SUBTRACTION;brush.position=center;combined.add_child(brush)
   var sphere:=CSGSphere3D.new();sphere.radius=radius;sphere.radial_segments=128;sphere.rings=64;brush.add_child(sphere)
   var n:Array=command.normal;var normal:=Vector3(n[0],n[1],n[2]).normalized()
   var halfspace:=CSGBox3D.new();halfspace.operation=CSGShape3D.OPERATION_INTERSECTION;halfspace.size=Vector3.ONE*(radius+1)*2;halfspace.position=normal*(radius+1);halfspace.quaternion=Quaternion(Vector3.UP,normal);brush.add_child(halfspace)
  else:
   var sphere:=CSGSphere3D.new();sphere.radius=radius;sphere.position=center;sphere.radial_segments=128;sphere.rings=64;sphere.operation=CSGShape3D.OPERATION_UNION if command.tool=='rock_add' else CSGShape3D.OPERATION_SUBTRACTION;combined.add_child(sphere)
 return combined
func export_mesh(combiner:CSGCombiner3D,name:String)->Dictionary:
 combiner._update_shape()
 var result:Array=combiner.get_meshes();assert(result.size()==2)
 var points:=PackedVector3Array()
 for p:Vector3 in result[1].get_faces():points.append(result[0]*p)
 assert(not points.is_empty())
 FileAccess.open(OUT+name+'.bin',FileAccess.WRITE).store_buffer(points.to_byte_array())
 return {'triangles':points.size()/3,'sha256_hex_algorithm':points.to_byte_array().hex_encode().sha256_text()}
func run():
 DirAccess.make_dir_recursive_absolute(OUT)
 var original:PackedVector3Array=Probe.read_points(SOURCE);source_mesh=Probe.mesh_from_points(original)
 var root_csg:=rebuild([])
 await process_frame
 var report:Dictionary={'engine':Engine.get_version_info(),'before':export_mesh(root_csg,'boundary'),'scope':'Tool-only installed Manifold reference, not a runtime backend or edit-history implementation. Bounded public brush zero-set, sphere represented by a finite polygonal approximation.'}
 root_csg.free()
 var commands:Array=[{'tool':'rock_plane','center':[-15.0,3.25,3.0],'radius':4.0,'normal':[0.0,1.0,0.0]}]
 root_csg=rebuild(commands)
 await process_frame
 report['after']=export_mesh(root_csg,'boundary_edited');report['sphere_radial_segments']=128;report['sphere_rings']=64;report['brush_center']=[-15,3.25,3];report['brush_radius']=4.;report['plane_normal']=[0,1,0]
 var best:=INF;var anchor:=Vector3.ZERO;var normal:=Vector3.ZERO
 for i in range(0,original.size(),3):
  var a:Vector3=original[i];var b:Vector3=original[i+1];var c:Vector3=original[i+2];var p:Vector3=(a+b+c)/3.;var n:Vector3=-(b-a).cross(c-a).normalized()
  if p.y<1.2 or p.y>2.5 or n.z<.5 or absf(n.y)>.5:continue
  var score:float=p.distance_squared_to(Vector3(-15,1.6,5))
  if score<best:best=score;anchor=p;normal=n
 assert(is_finite(best))
 var add_center:Vector3=anchor-normal*.15;var cut_center:Vector3=anchor+normal*.45
 commands.append({'tool':'rock_add','center':[add_center.x,add_center.y,add_center.z],'radius':.8})
 root_csg.free();root_csg=rebuild(commands);await process_frame
 report['grown']=export_mesh(root_csg,'boundary_grown')
 var grown_bytes:=FileAccess.get_file_as_bytes(OUT+'boundary_grown.bin')
 commands.append({'tool':'rock_cut','center':[cut_center.x,cut_center.y,cut_center.z],'radius':.55})
 root_csg.free();root_csg=rebuild(commands);await process_frame
 report['carved']=export_mesh(root_csg,'boundary_carved')
 var carved_bytes:=FileAccess.get_file_as_bytes(OUT+'boundary_carved.bin')
 var last:Dictionary=commands.pop_back();root_csg.free();root_csg=rebuild(commands);await process_frame
 export_mesh(root_csg,'boundary_undo');assert(FileAccess.get_file_as_bytes(OUT+'boundary_undo.bin')==grown_bytes)
 commands.append(last);root_csg.free();root_csg=rebuild(commands);await process_frame
 export_mesh(root_csg,'boundary_redo');assert(FileAccess.get_file_as_bytes(OUT+'boundary_redo.bin')==carved_bytes)
 var recipe:Dictionary={'version':1,'source':SOURCE,'source_sha256':FileAccess.get_sha256(SOURCE),'commands':commands,'scope':'Tool-only source-plus-command recipe, not a TerrainData save.'}
 FileAccess.open(OUT+'boundary_recipe.json',FileAccess.WRITE).store_string(JSON.stringify(recipe,'\t',true,true))
 var loaded:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+'boundary_recipe.json'))
 # JSON decimal parsing can differ by one double ULP. Geometry parameters
 # use the engine's Vector3 precision; canonicalize that operational type.
 for command:Dictionary in loaded.commands:
  for key:String in ['center','normal']:
   if command.has(key):
    var values:Array=command[key];var vector:=Vector3(values[0],values[1],values[2]);command[key]=[vector.x,vector.y,vector.z]
 assert(loaded.commands==commands)
 assert(loaded.source_sha256==FileAccess.get_sha256(SOURCE))
 root_csg.free();root_csg=rebuild(loaded.commands);await process_frame
 export_mesh(root_csg,'boundary_reload');assert(FileAccess.get_file_as_bytes(OUT+'boundary_reload.bin')==carved_bytes)
 report['commands']=commands;report['undo_mesh_bytes_equal']=true;report['redo_mesh_bytes_equal']=true;report['reload_mesh_bytes_equal']=true;report['recipe_vector_values_equal_at_engine_precision']=true;report['scope']='Tool-only installed Manifold source-plus-command sequence: bounded plane, grow, carve, undo/redo/reload. Same zero-set operations as public field brushes, finite polygonal spheres. Not TerrainData/player pointer/history/publication/support/collision integration or performance acceptance.'
 var local_center:Vector3=anchor-normal*.08;var local_radius:float=minf(1.0,3.25-local_center.y)
 assert(local_radius>=.25 and local_center.y+local_radius<3.4)
 var local_commands:Array=[{'tool':'rock_plane','center':[local_center.x,local_center.y,local_center.z],'radius':local_radius,'normal':[normal.x,normal.y,normal.z]}]
 root_csg.free();root_csg=rebuild(local_commands);await process_frame
 report['localcut']=export_mesh(root_csg,'boundary_localcut');report['localcut_commands']=local_commands;report['localcut_brush_max_y']=local_center.y+local_radius
 FileAccess.open(OUT+'boundary_localcut_recipe.json',FileAccess.WRITE).store_string(JSON.stringify({'version':1,'source':SOURCE,'source_sha256':FileAccess.get_sha256(SOURCE),'commands':local_commands,'scope':'Single bounded side-face chisel; brush strictly below the unchanged grass cap. Tool-only draw comparison, not production editor integration.'},'\t'))
 FileAccess.open(OUT+'boundary.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print('CLIFF KERNEL BOOLEAN: ',JSON.stringify(report));quit()
