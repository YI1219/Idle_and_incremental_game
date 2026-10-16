extends SceneTree
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const Contours=preload('res://scripts/terrain_editor/contour_terrain.gd')
const MeshBuilder=preload('res://scripts/terrain_editor/rock_sculpt_mesh.gd')
var checks:=0;var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred('run')
func run():
 var d=Data.new()
 for z in range(-4,4):
  for x in range(-5,5):d.cells[Vector2i(x,z)]={'height':3.5,'water':-1}
 if not d.has_method('set_sculpt_base'):
  check(false,'Existing terrain cannot be directly sculpted as one volume');quit(1);return
 check(d.set_sculpt_base(true),'Base conversion succeeds through authoritative data')
 check(d.rocks.value_at(Vector3(0,3,0))<0,'Existing ground belongs to sculpted solid')
 check(d.rocks.value_at(Vector3(0,4,0))>0,'Air remains outside the base')
 var before=d.serialize()
 d.begin_stroke();d.apply_rock_brush(Vector3(0,3.5,0),1,'rock_cut');d.end_stroke()
 check(d.rocks.value_at(Vector3(0,3.3,0))>0,'Carving removes existing terrain rather than an overlay')
 var field=Contours.new();field.refresh(d)
 check(field.surfaces.grass.vertices.is_empty() and field.surfaces.cliff.vertices.is_empty(),'No old cap or wall remains behind the sculpted skin')
 check(field.surfaces.sculpted_terrain.vertices.size()>100,'One surface supplies the edited base')
 var ground:Dictionary=field.surface_at(Vector2.ZERO)
 check(not ground.is_empty() and ground.height<2.7,'Support queries follow the carved surface')
 var edges:Dictionary={};var bad:=0;var grass:=0;var stone:=0
 var surface=field.surfaces.sculpted_terrain
 for i in range(0,surface.vertices.size(),3):
  for j in 3:
   var p:Vector3=surface.vertices[i+j];var q:Vector3=surface.vertices[i+(j+1)%3]
   var a:=Vector3i((p*100000).round());var b:=Vector3i((q*100000).round());var key:Array=[a,b] if a<b else [b,a]
   edges[key]=edges.get(key,0)+1
   if surface.colors[i+j].r>.8:grass+=1
   elif surface.colors[i+j].r<.2:stone+=1
 for uses:int in edges.values():
  if uses!=2:bad+=1
 check(bad==0,'Edited cap, cliff and bottom form a closed skin')
 check(grass>100 and stone>100,'The same skin carries grass and exposed-rock coverage')
 check(d.undo() and d.serialize()==before,'Undo restores exact terrain sculpt state')
 var copy=Data.new();check(copy.deserialize(JSON.parse_string(JSON.stringify(before))),'Converted terrain saves and loads')
 copy.ensure_sculpt_base()
 check(copy.rocks.value_at(Vector3(0,3,0))<0,'Loaded terrain rebuilds the same solid')
 check(d.set_sculpt_base(false) and d.rocks.base==null,'Conversion can be switched off')
 var remote=Data.new();remote.cells[Vector2i(-1024,0)]={'height':3.5,'water':-1};remote.cells[Vector2i(1024,0)]={'height':3.5,'water':-1}
 var unchanged=remote.serialize()
 check(not remote.set_sculpt_base(true) and remote.serialize()==unchanged,'Oversized derived base is rejected before allocation without changing data')
 d.set_sculpt_base(true);var compact=d.serialize()
 d.begin_stroke();var count=d.apply_brush(Vector2(1000,.5),1,'expand',false,12,3);d.end_stroke()
 check(count==0 and d.serialize()==compact,'A distant terrain brush cannot exceed the converted-base budget')
 var bad_payload=unchanged.duplicate(true);bad_payload.version=3;bad_payload.sculpt_base=true;bad_payload.rocks=[]
 check(not d.deserialize(bad_payload) and d.serialize()==compact,'Oversized unified layout load is atomic')
 var history=Data.new();history.cells[Vector2i.ZERO]={'height':3.5,'water':-1};history.cells[Vector2i(1000,1000)]={'height':3.5,'water':-1}
 history.begin_stroke();history.apply_brush(Vector2(1000.5,1000.5),.6,'contract',false,3.5,3);history.end_stroke()
 check(history.set_sculpt_base(true),'A contracted legacy layout can enter unified mode')
 var contracted=history.serialize()
 check(not history.undo() and history.serialize()==contracted,'Undo cannot restore an oversized unified base or consume the history entry')
 check(history.set_sculpt_base(false) and history.undo() and history.cells.size()==2,'Rejected history is still available in legacy mode')
 history.undo();history.begin_stroke();history.apply_brush(Vector2(1000.5,1000.5),.6,'contract',false,3.5,3);history.end_stroke()
 history.begin_stroke();history.apply_brush(Vector2(1000.5,1000.5),.6,'expand',false,3.5,3);history.end_stroke();history.undo()
 history.set_sculpt_base(true);contracted=history.serialize()
 check(not history.redo() and history.serialize()==contracted,'Redo also checks the unified base budget atomically')
 var modes=Data.new();modes.cells[Vector2i.ZERO]={'height':3.5,'water':-1}
 modes.begin_stroke();modes.apply_rock_brush(Vector3(.5,3.5,.5),.5,'rock_add');modes.end_stroke();var separate=modes.serialize();modes.undo();modes.set_sculpt_base(true)
 var converted=modes.serialize()
 check(not modes.redo() and modes.serialize()==converted,'Separate-volume rock history cannot be replayed against a different base')
 check(modes.set_sculpt_base(false) and modes.redo() and modes.serialize()==separate,'Rock history remains available in its original authoring mode')
 var thin=Data.new();thin.cells[Vector2i(3,0)]={'height':1.0,'water':-1};thin.set_sculpt_base(true)
 thin.begin_stroke();thin.apply_rock_brush(Vector3(3.17,1.12,.11),.45,'rock_add');thin.apply_rock_brush(Vector3(3.22,1.17,.16),.45,'rock_cut');thin.end_stroke()
 var skin=MeshBuilder.build(thin.rocks);var misses:=0;var probes:=0
 for z in range(-26,-18):
  for x in range(295,317,2):
   var p:=Vector2(x*.01,z*.01);var top:=-INF
   for i in range(0,skin.vertices.size(),3):
    var hit=Geometry3D.ray_intersects_triangle(Vector3(p.x,20,p.y),Vector3.DOWN,skin.vertices[i],skin.vertices[i+1],skin.vertices[i+2])
    if hit!=null:top=maxf(top,hit.y)
   if top==-INF:continue
   probes+=1;var h:float=thin.rocks.height_at(p)
   if is_nan(h) or absf(top-h)>.001:misses+=1
 check(probes>20 and misses==0,'Thin carved ledges have the same support height as actual mesh intersections')
 print('THIN SCULPT SUPPORT: probes=',probes,' mismatches=',misses)
 print('SCULPT BASE: ',checks-failures,'/',checks,' vertices=',surface.vertices.size(),' invalid_edges=',bad)
 quit(1 if failures else 0)
