extends SceneTree
var failures:=0
var checks:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred('run')
func run():
 var Data=preload('res://scripts/terrain_editor/terrain_data.gd')
 var path:='res://art/work/pcg_fracture/2026-10-18/route2/master_sampled.layout'
 var data=Data.new();check(data.deserialize(JSON.parse_string(FileAccess.get_file_as_string(path))),'actual sampled master loads through ordinary production API')
 var before:Dictionary=data.serialize();var copy=Data.new()
 check(copy.deserialize(before) and copy.serialize()==before,'actual master density/cells survive exact ordinary save/load')
 check(not data.sculpt_base_enabled and data.rocks.base==null,'master uses explicit saved densities without hidden generator')
 var finite:=true
 for value:float in data.rocks.samples.values():finite=finite and is_finite(value) and absf(value)<=.5
 check(finite and data.rocks.samples.size()<data.rocks.MAX_SAMPLES,'master records finite and below capacity')
 var hit:=Vector3.ZERO;var best:=-INF
 for key:Vector3i in data.rocks.samples:
  if key.y==5 and data.rocks.samples[key]<0 and key.z>best:hit=Vector3(key)*.25;best=key.z
 check(is_finite(best),'actual master has a solid below-cap probe')
 data.begin_stroke();var count:int=data.apply_rock_brush(hit,1.1,'rock_cut',Vector3.FORWARD);data.end_stroke()
 check(count>0,'public carve changes actual sampled master')
 var edited:Dictionary=data.serialize()
 check(data.undo() and data.serialize()==before,'master undo restores original density records')
 check(data.redo() and data.serialize()==edited,'master redo restores edited density records')
 check(copy.deserialize(edited) and copy.serialize()==edited,'edited master reloads byte-equivalent records')
 print('MASTER DATA: ',checks-failures,'/',checks,' passed');quit(1 if failures else 0)
