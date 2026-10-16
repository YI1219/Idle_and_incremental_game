extends SceneTree
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func stroke(data,tool:String,at:Vector3,radius:float,normal:=Vector3.UP):
 data.begin_stroke();data.apply_rock_brush(at,radius,tool,normal);data.end_stroke()
func _initialize():call_deferred('run')
func run():
 var path='res://scripts/terrain_editor/rock_sculpt.gd'
 if not ResourceLoader.exists(path):
  check(false,'Direct rock volume sculpting is unavailable');quit(1);return
 var d=Data.new()
 stroke(d,'rock_add',Vector3(-.8,2,0),1.35)
 stroke(d,'rock_add',Vector3(.8,2,0),1.35)
 check(d.rocks.value_at(Vector3(0,2,0))<0,'Neighboring strokes directly share one solid interior')
 check(d.rocks.value_at(Vector3(0,5,0))>0,'No automatic extra geometry outside the authored volume')
 inspect(load('res://scripts/terrain_editor/rock_sculpt_mesh.gd').build(d.rocks),d.rocks,'joined strokes')
 var shape=d.serialize()
 stroke(d,'rock_cut',Vector3(0,3,0),.8)
 check(d.rocks.value_at(Vector3(0,3,0))>0,'Subtraction carves the actual volume')
 check(d.undo() and d.serialize()==shape,'Undo restores exact sculpt samples')
 check(d.redo() and d.rocks.value_at(Vector3(0,3,0))>0,'Redo restores carving')
 d.undo()
 stroke(d,'rock_plane',Vector3(0,2.6,0),4,Vector3.UP)
 check(d.rocks.value_at(Vector3(0,2.9,0))>0 and d.rocks.value_at(Vector3(0,2.4,0))<0,'Plane brush cuts only its selected side')
 var saved=d.serialize();var copy=Data.new()
 check(copy.deserialize(JSON.parse_string(JSON.stringify(saved))),'Rock and terrain layout JSON loads')
 check(copy.serialize()==saved,'Sculpt sample roundtrip is exact')
 var before=copy.serialize()
 check(copy.apply_rock_brush(Vector3(NAN,0,0),1,'rock_add')==0,'Nonfinite brush rejected')
 check(copy.apply_rock_brush(Vector3.ZERO,INF,'rock_add')==0,'Nonfinite radius rejected')
 check(copy.apply_rock_brush(Vector3.ZERO,1,'rock_plane',Vector3.ZERO)==0,'Zero cutting normal rejected')
 check(copy.serialize()==before,'Invalid strokes leave the field unchanged')
 var bad=saved.duplicate(true);bad.rocks[0].density=NAN
 check(not copy.deserialize(bad) and copy.serialize()==before,'Invalid sample load is atomic')
 var legacy=Data.new();legacy.make_preset(2)
 check(copy.deserialize(legacy.serialize()) and copy.rocks.samples.is_empty(),'Legacy layouts load with an empty sculpt field')
 d=Data.new();d.begin_stroke()
 d.apply_brush(Vector2(.5,.5),.49,'expand',true,1.5,3)
 d.apply_rock_brush(Vector3(0,1,0),1,'rock_add')
 d.end_stroke();var mixed=d.serialize()
 check(d.undo() and d.cells.is_empty() and d.rocks.samples.is_empty(),'Mixed terrain/sculpt stroke undoes atomically')
 check(d.redo() and d.serialize()==mixed,'Mixed stroke redo is exact')
 check(not d.dirty_chunks.is_empty(),'Sculpt strokes invalidate visible chunks')
 var mesh_script=load('res://scripts/terrain_editor/rock_sculpt_mesh.gd')
 var surface=mesh_script.build(d.rocks)
 inspect(surface,d.rocks,'initial')
 stroke(d,'rock_cut',Vector3(.8,1,0),.75)
 inspect(mesh_script.build(d.rocks),d.rocks,'carved')
 var limited=load('res://scripts/terrain_editor/rock_sculpt.gd').new()
 for i in limited.MAX_SAMPLES:limited.samples[Vector3i(i%400,(i/400)%100,i/40000)]=-.25
 check(limited.brush(Vector3(500,2,0),1,'rock_add').is_empty() and limited.samples.size()==limited.MAX_SAMPLES,'Capacity failure is atomic')
 check(limited.brush(Vector3(1024,2,0),1,'rock_add').is_empty(),'World boundary rejects a truncated brush')
 var oversized:Array=[];oversized.resize(limited.MAX_SAMPLES+1)
 check(not copy.rocks.load_records(oversized),'Oversized sample loads rejected before iteration')
 print('ROCK SCULPT: ',checks-failures,'/',checks)
 quit(1 if failures else 0)
func inspect(surface,field,label:String,normal_probe:float=.04):
 var edges={};var normals=0;var finite=0
 for i in range(0,surface.vertices.size(),3):
  var a:Vector3=surface.vertices[i];var b:Vector3=surface.vertices[i+1];var c:Vector3=surface.vertices[i+2]
  var normal=-(b-a).cross(c-a).normalized();var center=(a+b+c)/3
  if field.value_at(center+normal*normal_probe)<field.value_at(center-normal*normal_probe)-.0001:normals+=1
  for j in 3:
   var p:Vector3=surface.vertices[i+j];var q:Vector3=surface.vertices[i+(j+1)%3]
   if not p.is_finite() or not surface.normals[i+j].is_finite() or surface.normals[i+j].length()<.99:finite+=1
   var ka=Vector3i((p*100000).round());var kb=Vector3i((q*100000).round())
   var key=[ka,kb] if ka<kb else [kb,ka]
   edges[key]=edges.get(key,0)+1
 var open_edges=0
 for uses in edges.values():
  if uses!=2:open_edges+=1
 check(surface.vertices.size()>100,label+': meaningful actual sculpt mesh')
 check(open_edges==0,label+': closed connected surface edges')
 check(normals==0 and finite==0,label+': finite outward geometry and shading')
 print('SCULPT MESH ',label,': vertices=',surface.vertices.size(),' open=',open_edges,' inward=',normals)
