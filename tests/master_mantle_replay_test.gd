extends SceneTree
## Replay the EXACT captured public edit and compare actual mesh bytes,
## rather than inferring mesh stability from density/history checks alone.
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const Mesher=preload('res://scripts/terrain_editor/rock_sculpt_mesh.gd')
var work:='res://art/work/master_mantle/2026-10-18/'
var failures:=0
var checks:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message)
func matches_mesh(data,name:String)->bool:
 return Mesher.build(data.rocks).vertices.to_byte_array()==FileAccess.get_file_as_bytes(work+name+'.bin')
func _initialize():call_deferred('run')
func run():
 var at:=Vector3(-4,-.5,4);var expected_count:=324
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with('--work='):work=arg.trim_prefix('--work=')
  elif arg.begins_with('--capture='):
   var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix('--capture=')))
   var operation:Dictionary=report.stages.carve_operation
   at=str_to_var('Vector3'+operation.center);expected_count=operation.changed
 var before:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(work+'contact.layout'))
 var after:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(work+'carved.layout'))
 var data=Data.new();var copy=Data.new()
 check(data.deserialize(before),'captured contact layout loads')
 # JSON parses every number as float; ordinary loading restores index/seed/
 # water types. Compare authoritative loaded records, not raw JSON variants.
 before=data.serialize()
 var expected=Data.new();check(expected.deserialize(after),'captured carved layout loads')
 after=expected.serialize()
 check(matches_mesh(data,'contact'),'loaded contact rebuilds exact captured triangles')
 data.begin_stroke();var count:int=data.apply_rock_brush(at,1.1,'rock_cut',Vector3.FORWARD);data.end_stroke()
 check(count==expected_count,'exact captured public operation changes expected node count')
 check(data.serialize()==after,'exact edit reproduces captured carved records')
 check(matches_mesh(data,'carved'),'exact edit reproduces captured carved triangles')
 check(data.undo() and data.serialize()==before,'undo restores all captured source records/cells')
 check(matches_mesh(data,'contact'),'undo restores captured source triangle bytes')
 check(data.redo() and data.serialize()==after,'redo restores captured edited records/cells')
 check(matches_mesh(data,'carved'),'redo restores captured edited triangle bytes')
 check(copy.deserialize(data.serialize()) and copy.serialize()==after,'edited records/cells reload exactly')
 check(matches_mesh(copy,'carved'),'edited reload restores captured triangle bytes')
 print('MASTER MANTLE REPLAY: ',checks-failures,'/',checks,' passed');quit(1 if failures else 0)
