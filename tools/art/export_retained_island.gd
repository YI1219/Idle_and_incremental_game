extends SceneTree
## Existing closed source operands + authoritative baseline, not overlapping
## render props as a claimed final surface. Offline scalar union follows.
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const Decoration=preload('res://scripts/terrain_editor/terrain_decoration.gd')
const Contours=preload('res://scripts/terrain_editor/contour_terrain.gd')
var OUT:='res://art/work/retained_island/2026-10-18/'
func _initialize():call_deferred('run')
func digest(bytes:PackedByteArray)->String:
 var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes);return context.finish().hex_encode()
func run():
 var seed_value:=7301
 var layout_kind:='courtyard'
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with('--output='):OUT=arg.trim_prefix('--output=')
  elif arg.begins_with('--seed='):seed_value=int(arg.trim_prefix('--seed='))
  elif arg.begins_with('--layout='):layout_kind=arg.trim_prefix('--layout=')
 assert(layout_kind in ['courtyard','bay'])
 DirAccess.make_dir_recursive_absolute(OUT)
 var data:=Data.new();data.seed=seed_value
 for z in range(-13,3):
  for x in range(-19,-3):
   var q:=(Vector2(x+.5,z+.5)-Vector2(-11,-5))/Vector2(7.3,6.4)
   if q.length_squared()>.98+.07*sin(float(x)*.8+float(z)*.5):continue
   if layout_kind=='bay' and x< -14 and z>= -1:continue
   data.cells[Vector2i(x,z)]={'height':3.5,'water':-1}
 if layout_kind=='bay':
  for z in range(-6,-1):
   for x in range(-6,-2):data.cells[Vector2i(x,z)]={'height':3.5,'water':-1}
 # Retain the two authored tree anchors with real dry footprints in every
 # contour/seed case. No force-visible or visual-only root pedestal.
 for anchor:Vector2i in [Vector2i(-16,-3),Vector2i(-5,-8)]:
  for z in range(anchor.y-1,anchor.y+1):
   for x in range(anchor.x-1,anchor.x+1):data.cells[Vector2i(x,z)]={'height':3.5,'water':-1}
 var contours:=Contours.new();contours.refresh(data)
 var decoration:=Decoration.new();decoration.load_assets();decoration._column_layout(contours,seed_value)
 var pieces:Array=[]
 for i in decoration._columns.size():
  var column:Dictionary=decoration._columns[i]
  var asset:Dictionary=decoration.assets[column.kind][0]
  var points:=PackedVector3Array();var pose:Transform3D=column.pose*asset.pose
  for p:Vector3 in asset.mesh.get_faces():points.append(pose*p)
  var file:='crown_%02d.bin'%i
  FileAccess.open(OUT+file,FileAccess.WRITE).store_buffer(points.to_byte_array())
  pieces.append({'stage':'crown_%02d'%i,'file':file,'kind':column.kind,'triangles':points.size()/3,'sha256':digest(points.to_byte_array()),'pose':str(pose)})
 assert(data.set_sculpt_base(true));assert(data.ensure_sculpt_base())
 var base=data.rocks.base
 FileAccess.open(OUT+'base_values.bin',FileAccess.WRITE).store_buffer(base.values.to_byte_array())
 FileAccess.open(OUT+'horizontal_distance.bin',FileAccess.WRITE).store_buffer(base.horizontal_distances[0].to_byte_array())
 FileAccess.open(OUT+'control.layout',FileAccess.WRITE).store_string(JSON.stringify(data.serialize(),'\t',true,true))
 var report:={'source':'Actual retained closed crown meshes for compact editable cells. Not a final combined mesh. No asset geometry edit.','layout_kind':layout_kind,'seed':seed_value,'cells':data.cells.size(),'pieces':pieces,'base_low':[base.low.x,base.low.y,base.low.z],'base_size':[base.size.x,base.size.y,base.size.z],'base_values_sha256':digest(base.values.to_byte_array()),'layout':'control.layout','density_step':.25,'scope':'Operands must pass finite gates before scalar union. Same baseline local-derived volume and standard version4cells/rocks; no save-format change.'}
 FileAccess.open(OUT+'operands.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'))
 print('RETAINED OPERANDS: ',pieces.size(),' closed source copies; ',data.cells.size(),'actual cells; grid',base.size)
 quit()
