extends SceneTree
## Independent topology evidence for the whole authored source skin.
var parents:=PackedInt32Array()
func root_of(id:int)->int:
 var result:=id
 while parents[result]!=result:result=parents[result]
 while parents[id]!=id:
  var next:=parents[id];parents[id]=result;id=next
 return result
func _initialize():call_deferred('run')
func run():
 var data=load('res://scripts/terrain_editor/terrain_data.gd').new();data.make_preset(0)
 var original:Dictionary=data.cells.duplicate(true)
 data.set_sculpt_base(true)
 var recess:=OS.get_cmdline_user_args().has('recess')
 if recess:load('res://tools/art/author_unified_cliff_recess.gd').author(data)
 else:load('res://tools/art/author_unified_cliff_cutstone.gd').full_island(data)
 var skin=load('res://scripts/terrain_editor/rock_sculpt_mesh.gd').build(data.rocks)
 var ids:Dictionary={};var edges:Dictionary={};var bad_vertices:=0
 for i in range(0,skin.vertices.size(),3):
  var triangle:Array[int]=[]
  for j in 3:
   var p:Vector3=skin.vertices[i+j]
   if not p.is_finite():bad_vertices+=1
   if not ids.has(p):ids[p]=parents.size();parents.append(parents.size())
   triangle.append(ids[p])
  for j in 3:
   var a:int=triangle[j];var b:int=triangle[(j+1)%3]
   var key:Vector2i=Vector2i(mini(a,b),maxi(a,b))
   edges[key]=edges.get(key,0)+1
   parents[root_of(a)]=root_of(b)
 var components:Dictionary={};var bad_edges:=0
 for id in parents.size():components[root_of(id)]=true
 for count:int in edges.values():
  if count!=2:bad_edges+=1
 var report:={'vertices':skin.vertices.size(),'unique_positions':ids.size(),'connected_components':components.size(),'invalid_edges':bad_edges,'invalid_vertices':bad_vertices,'original_cells_unchanged':data.cells==original,'profile':data.sculpt_base_profile,'save_version':data.serialize().version,'overrides':data.rocks.samples.size()}
 var output:='res://art/review/terrain_fidelity/2026-10-16/solid_smoothing/recess_volume.json' if recess else 'res://art/review/terrain_fidelity/2026-10-16/plane_sculpt/whole_volume_checks.json'
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,'\t'))
 print('WHOLE SCULPT SOURCE: ',report)
 quit(0 if components.size()==1 and bad_edges==0 and bad_vertices==0 and data.cells==original else 1)
