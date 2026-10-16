extends 'res://tests/terrain_rock_sculpt_test.gd'
func run():
 var f=load('res://scripts/terrain_editor/rock_sculpt.gd').new()
 f.samples[Vector3i(0,8,0)]=-.25
 f.samples[Vector3i(12,8,0)]=-.25
 var far:float=f.node_value(Vector3i(12,8,0))
 check(not f.brush(Vector3(0,2,0),.75,'rock_smooth').is_empty(),'Shared brush accepts local solid smoothing')
 check(f.value_at(Vector3(0,2,0))>0,'A one-node needle is removed instead of remaining a sharp residual solid')
 check(f.node_value(Vector3i(12,8,0))==far,'Smoothing leaves out-of-radius solid untouched')
 check(f.node_value(Vector3i(-1,8,0))==f.node_value(Vector3i(1,8,0)) and f.node_value(Vector3i(0,7,0))==f.node_value(Vector3i(0,9,0)) and f.node_value(Vector3i(0,8,-1))==f.node_value(Vector3i(0,8,1)),'A symmetric feature has no traversal-direction bias')
 var flat=load('res://scripts/terrain_editor/rock_sculpt.gd').new()
 for z in range(-4,5):
  for y in range(-4,5):
   for x in range(-4,5):flat.samples[Vector3i(x,y,z)]=.00002 if y==0 else clampf(y*.25,-.5,.5)
 var plane:Array=flat.records()
 flat.brush(Vector3.ZERO,.5,'rock_smooth')
 check(flat.records()==plane,'Flat rock planes remain flat instead of acquiring a rounded brush dent')
 var d=Data.new();stroke(d,'rock_shoulder',Vector3(0,2,0),1.5)
 var before=d.serialize();stroke(d,'rock_smooth',Vector3(0,2,0),2.5)
 var after=d.serialize()
 check(after!=before,'Smoothing acts on actual joined shoulder geometry')
 inspect(load('res://scripts/terrain_editor/rock_sculpt_mesh.gd').build(d.rocks),d.rocks,'smoothed shoulder',.001)
 check(d.undo() and d.serialize()==before and d.redo() and d.serialize()==after,'Smooth stroke has exact undo and redo')
 var copy=Data.new();check(copy.deserialize(JSON.parse_string(JSON.stringify(after))) and copy.serialize()==after,'Smoothed samples use ordinary JSON persistence')
 var saved=copy.serialize()
 check(copy.apply_rock_brush(Vector3(NAN,0,0),1,'rock_smooth')==0 and copy.serialize()==saved,'Invalid smoothing center leaves samples intact')
 check(copy.apply_rock_brush(Vector3.ZERO,INF,'rock_smooth')==0 and copy.serialize()==saved,'Invalid smoothing radius leaves samples intact')
 check(copy.apply_rock_brush(Vector3(1024,2,0),1,'rock_smooth')==0 and copy.serialize()==saved,'World-boundary smoothing rejects atomically')
 var empty=load('res://scripts/terrain_editor/rock_sculpt.gd').new()
 check(empty.brush(Vector3.ZERO,1,'rock_smooth').is_empty() and empty.samples.is_empty(),'Smoothing empty air creates no stray rock')
 var base=Data.new()
 for z in range(-2,2):
  for x in range(-2,2):base.cells[Vector2i(x,z)]={'height':3.5,'water':-1}
 base.set_sculpt_base(true);var cells:Dictionary=base.cells.duplicate(true)
 var original=base.serialize();stroke(base,'rock_smooth',Vector3(1.75,3.5,.5),1.25)
 check(base.serialize()!=original and base.cells==cells,'Player smoothing edits the actual derived cap without replacing authored cells')
 var loaded=Data.new();var payload=base.serialize()
 check(payload.version==4 and loaded.deserialize(JSON.parse_string(JSON.stringify(payload))) and loaded.serialize()==payload,'Unified smoothing preserves the explicit local base profile in v4 JSON')
 inspect(load('res://scripts/terrain_editor/rock_sculpt_mesh.gd').build(base.rocks),base.rocks,'smoothed base',.001)
 var limited=load('res://scripts/terrain_editor/rock_sculpt.gd').new()
 for i in limited.MAX_SAMPLES:limited.samples[Vector3i(i%400,(i/400)%100,i/40000)]=-.25
 limited.samples.erase(Vector3i.ZERO);limited.samples[Vector3i(2000,8,0)]=-.25
 check(limited.brush(Vector3(500,2,0),1,'rock_smooth').is_empty() and limited.samples.size()==limited.MAX_SAMPLES and limited.node_value(Vector3i(2000,8,0))==-.25,'Sample capacity failure does not partly smooth the selected rock')
 print('ROCK SMOOTH: ',checks-failures,'/',checks);quit(1 if failures else 0)
