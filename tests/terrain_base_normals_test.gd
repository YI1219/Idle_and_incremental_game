extends SceneTree
## The continuous base must not acquire flat triangle seams when rim union
## rebuilds the original smoothed shell. Hard geological turns stay sharp.
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const Field=preload('res://scripts/terrain_editor/contour_terrain.gd')
const Deco=preload('res://scripts/terrain_editor/terrain_decoration.gd')
func _initialize():call_deferred('run')
func run():
 var data:=Data.new();data.make_preset(0)
 var reports:=[];var passed:=true
 for state:String in ['default','expand','contract','lower']:
  if state!='default':
   if state!='expand':data.undo()
   data.begin_stroke();data.apply_brush(Vector2(18.6,4.4),2.2,state,false,1.5,3);data.end_stroke()
  var result:=probe(data);result.state=state;reports.append(result);passed=passed and result.passed
 print('BASE NORMALS: ',JSON.stringify(reports))
 quit(0 if passed else 1)
func probe(data:Data)->Dictionary:
 var field:=Field.new();field.refresh(data)
 var deco:=Deco.new();deco.load_assets();deco._column_layout(field,data.seed)
 var shell=field.surfaces.cliff
 var groups:Dictionary={}
 for i in range(0,shell.vertices.size(),3):
  var face:Vector3=-(shell.vertices[i+1]-shell.vertices[i]).cross(shell.vertices[i+2]-shell.vertices[i]).normalized()
  for j in 3:
   var key:=Vector3i((shell.vertices[i+j]*100000).round())
   if not groups.has(key):groups[key]=[]
   groups[key].append({'face':face,'normal':shell.normals[i+j]})
 var gentle:=0;var seams:=0;var sharp:=0;var erased:=0;var invalid:=0
 for group:Array in groups.values():
  var maximum_turn:=0.0;var maximum_shading:=0.0
  for a:Dictionary in group:
   if not a.normal.is_finite() or absf(a.normal.length()-1.0)>.001 or a.normal.dot(a.face)<.5:invalid+=1
   for b:Dictionary in group:
    maximum_turn=maxf(maximum_turn,a.face.angle_to(b.face))
    maximum_shading=maxf(maximum_shading,a.normal.angle_to(b.normal))
  if maximum_turn>deg_to_rad(2) and maximum_turn<deg_to_rad(41):
   gentle+=1
   if maximum_shading>deg_to_rad(1):seams+=1
  if maximum_turn>deg_to_rad(80):
   sharp+=1
   if maximum_shading<deg_to_rad(40):erased+=1
 var passed:=gentle>100 and sharp>10 and seams==0 and erased==0 and invalid==0
 return {'gentle_joins':gentle,'artificial_seams':seams,'sharp_joins':sharp,'erased_corners':erased,'invalid':invalid,'passed':passed}
