extends 'res://tests/terrain_rock_sculpt_test.gd'
func run():
 var d=Data.new();var center:=Vector3(0,2,0)
 stroke(d,'rock_shoulder',center,1.0,Vector3.BACK)
 check(not d.rocks.samples.is_empty(),'Player volume API supports the authored stone shoulder brush')
 check(d.rocks.value_at(center)<0,'Shoulder has a solid interior')
 check(d.rocks.value_at(center+Vector3(0,0,.60))<0,'Upper face projects from the core')
 check(d.rocks.value_at(center+Vector3(0,-1,.60))>0 and d.rocks.value_at(center+Vector3(0,-1,-.40))<0,'Lower foot recedes inward instead of ending as a hanging slab')
 # Short probes stay in the face's local neighborhood at oblique corners;
 # a4cm offset can cross a neighboring face and leave the solid again.
 var before=d.serialize();inspect(load('res://scripts/terrain_editor/rock_sculpt_mesh.gd').build(d.rocks),d.rocks,'shoulder',.001)
 check(d.undo() and d.rocks.samples.is_empty() and d.redo() and d.serialize()==before,'Shoulder history restores exact volume samples')
 var copy=Data.new();check(copy.deserialize(JSON.parse_string(JSON.stringify(before))) and copy.serialize()==before,'Shoulder uses the ordinary saved editable field')
 var turn=Data.new();stroke(turn,'rock_shoulder',center,1.0,Vector3.RIGHT)
 check(turn.rocks.value_at(center+Vector3(.60,-1,0))>0 and turn.rocks.value_at(center+Vector3(-.40,-1,0))<0,'Surface direction rotates the receding foot')
 check(copy.apply_rock_brush(Vector3(1023,2,0),2,'rock_shoulder',Vector3.BACK)==0 and copy.serialize()==before,'World-edge shoulder rejection is atomic')
 check(copy.apply_rock_brush(center,1,'rock_shoulder',Vector3(NAN,0,0))==0 and copy.serialize()==before,'Invalid shoulder orientation is rejected atomically')
 var limited=load('res://scripts/terrain_editor/rock_sculpt.gd').new()
 for i in limited.MAX_SAMPLES:limited.samples[Vector3i(i%400,(i/400)%100,i/40000)]=-.25
 check(limited.brush(Vector3(500,2,0),1,'rock_shoulder',Vector3.BACK).is_empty() and limited.samples.size()==limited.MAX_SAMPLES and limited.value_at(Vector3(500,2,0))>0,'Shoulder sample-capacity rejection leaves the original field intact')
 var cover=Data.new();cover.cells[Vector2i.ZERO]={'height':3.5,'water':-1};cover.set_sculpt_base(true)
 check(cover.rocks.base.tag(Vector3(1.4,3.5,.5),Vector3.UP).color.r<.01,'New outboard stone cannot inherit paint from nearby original grass')
 check(cover.rocks.base.tag(Vector3(.93,3.5,.5),Vector3.UP).color.r>.8,'Original grass lip retains coverage without a grey outline')
 print('ROCK SHOULDER: ',checks-failures,'/',checks);quit(1 if failures else 0)
