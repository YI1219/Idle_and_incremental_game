extends 'res://tests/terrain_rock_sculpt_test.gd'
func run():
 var d=Data.new();stroke(d,'rock_add',Vector3(0,2,0),2.0)
 var before=d.serialize()
 stroke(d,'rock_cleave',Vector3(.6,2,.9),1.1,Vector3.BACK)
 check(d.serialize()!=before and d.rocks.value_at(Vector3(.6,2,.9))>0,'Geological cleave removes its actual convex interior')
 check(d.rocks.value_at(Vector3(-1,2,-.5))<0,'Rock outside the geological cutting volume is retained')
 inspect(load('res://scripts/terrain_editor/rock_sculpt_mesh.gd').build(d.rocks),d.rocks,'geological cleave',.001)
 var after=d.serialize()
 check(d.undo() and d.serialize()==before and d.redo() and d.serialize()==after,'Geological cutting has exact ordinary history')
 var copy=Data.new();check(copy.deserialize(JSON.parse_string(JSON.stringify(after))) and copy.serialize()==after,'Geological cuts persist as ordinary samples')
 check(copy.apply_rock_brush(Vector3(1023,2,0),2,'rock_cleave',Vector3.BACK)==0 and copy.serialize()==after,'Large geological cutter rejects world truncation atomically')
 check(copy.apply_rock_brush(Vector3(0,2,0),1,'rock_cleave',Vector3.ZERO)==0 and copy.serialize()==after,'Invalid cutter orientation is rejected atomically')
 var empty=load('res://scripts/terrain_editor/rock_sculpt.gd').new()
 empty.brush(Vector3.ZERO,1,'rock_cleave',Vector3.BACK)
 check(load('res://scripts/terrain_editor/rock_sculpt_mesh.gd').build(empty).vertices.is_empty(),'A geological cut cannot create stray solid in empty air')
 var orientations:Array=[]
 for direction:Vector3 in [Vector3.BACK,Vector3.RIGHT]:
  var turned=Data.new();stroke(turned,'rock_add',Vector3(0,2,0),3.0)
  stroke(turned,'rock_cleave',Vector3(0,2,0),1.0,direction)
  orientations.append(turned.rocks.value_at(Vector3(0,1.4,.6)))
 check(orientations[0]<0 and orientations[1]>0,'Cutter orientation rotates the unequal lower return')
 var limited=load('res://scripts/terrain_editor/rock_sculpt.gd').new()
 var base=load('res://scripts/terrain_editor/rock_terrain_base.gd').new()
 base.configure({Vector2i(500,0):{'height':3.5,'water':-1}},'local');limited.base=base
 for i in limited.MAX_SAMPLES:limited.samples[Vector3i(i%400,(i/400)%100,i/40000)]=-.25
 check(limited.brush(Vector3(500.5,3.0,.5),1,'rock_cleave').is_empty() and limited.samples.size()==limited.MAX_SAMPLES and limited.node_value(Vector3i(2002,12,2))<0,'Derived-body cutter rejects new overrides at capacity without partial carving')
 print('ROCK CLEAVE: ',checks-failures,'/',checks);quit(1 if failures else 0)
