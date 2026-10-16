extends SceneTree
## Actual legacy body surfaces and closed retained crowns, no outcrop props.
const BASE_OUT='res://art/work/rendered_island/2026-10-17/'
func _initialize():call_deferred('run')
func run():
 var complete:bool=OS.get_cmdline_user_args().has('complete')
 var OUT:String=BASE_OUT+('complete/' if complete else '')
 DirAccess.make_dir_recursive_absolute(OUT)
 var data=preload('res://scripts/terrain_editor/terrain_data.gd').new();data.make_preset(0)
 var field=preload('res://scripts/terrain_editor/contour_terrain.gd').new();field.refresh(data)
 var deco=preload('res://scripts/terrain_editor/terrain_decoration.gd').new();deco.load_assets();deco._column_layout(field,data.seed)
 var records:Array=[]
 for kind:String in ['grass','cliff','stone_mantle','bank','shore','lake_bed']:
  var surface=field.surfaces.get(kind)
  if surface==null or surface.vertices.is_empty():continue
  FileAccess.open(OUT+kind+'.bin',FileAccess.WRITE).store_buffer(surface.vertices.to_byte_array())
  records.append({'kind':kind,'path':kind+'.bin','vertices':surface.vertices.size(),'sha256_hex':surface.vertices.to_byte_array().hex_encode().sha256_text()})
 for i in deco._columns.size():
  var col:Dictionary=deco._columns[i];var vertices:=PackedVector3Array()
  for p:Vector3 in deco.assets[col.kind][0].mesh.get_faces():vertices.append(col.pose*p)
  var name:='crown_'+str(i)
  FileAccess.open(OUT+name+'.bin',FileAccess.WRITE).store_buffer(vertices.to_byte_array())
  records.append({'kind':name,'path':name+'.bin','vertices':vertices.size(),'sha256_hex':vertices.to_byte_array().hex_encode().sha256_text()})
 if complete:
  for i in deco._outcrops.size():
   var rock:Dictionary=deco._outcrops[i];var vertices:=PackedVector3Array()
   for p:Vector3 in deco.assets[rock.kind][0].mesh.get_faces():vertices.append(rock.pose*p)
   var name:='outcrop_'+str(i)
   FileAccess.open(OUT+name+'.bin',FileAccess.WRITE).store_buffer(vertices.to_byte_array())
   records.append({'kind':rock.kind,'path':name+'.bin','vertices':vertices.size(),'sha256_hex':vertices.to_byte_array().hex_encode().sha256_text()})
 FileAccess.open(OUT+'source.json',FileAccess.WRITE).store_string(JSON.stringify({'components':records,'cells':data.serialize().cells,'outcrops_included':complete,'stage':'Actual original legacy body/cliff/shore/bed plus closed source crowns'+(' and all retained high outcrop/shelf meshes' if complete else '')+'; no vegetation, furniture, tree or building. Internal overlaps remain input evidence, not a closed-union claim.'},'\t'))
 print('RENDERED ISLAND EXPORT: components=',records.size(),' crowns=',deco._columns.size(),' outcrops=',deco._outcrops.size() if complete else 0);quit()
